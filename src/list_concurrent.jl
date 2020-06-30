#================================================

ConcurrentSkipList- and ConcurrentSkipListSet-specific code.

Concurrency-safe skip lists are implemented using the algorithm described
in "A Lazy Concurrent List-Based Set Algorithm" (Heller et al 2007)

=================================================#

using Base.Threads

#===========================
ConcurrentSkipList constructors
===========================#

function ConcurrentSkipList{T,M}(; max_height = DEFAULT_MAX_HEIGHT, p = DEFAULT_P) where {T,M}
    _check_mode(M)

    left_sentinel = ConcurrentLeftSentinel{T,M}(; max_height=max_height)
    right_sentinel = ConcurrentRightSentinel{T,M}(; max_height=max_height)
    height = Atomic{Int64}(1)
    length = Atomic{Int64}(0)

    for ii = 1:max_height
        link_nodes!(left_sentinel, right_sentinel, ii)
    end

    ConcurrentSkipList{T,M}(
        p,
        max_height,
        left_sentinel,
        right_sentinel,
        height,
        length
    )
end

#===========================
Macros
===========================#

function validate(f, predecessors, successors, node; type = :strong)
    valid = true
    level = 1

    try
        # Starting from the bottom level, traverse up the height of the node
        # and check that the $check_valid condition is true for each predecessor /
        # successor pair.
        while valid && level ≤ height(node)
            pred = predecessors[level]
            succ = successors[level]
            lock(pred)

            # Strong validation (used by Base.insert!) requires that we check
            # the following:
            # 1. the predecessor node at each level is not marked for deletion;
            # 2. the successor node at each level is not marked for deletion; and
            # 3. the predecessor is still connected to the successor.
            #
            # Weak validation (used by Base.remove!) drops the second condition, since
            # the successor is supposed to be marked for deletion.
            valid = if type == :strong
                !is_marked_for_deletion(pred) &&
                !is_marked_for_deletion(succ) &&
                next(pred, level) === succ
            elseif type == :weak
                !is_marked_for_deletion(pred) &&
                next(pred, level) === succ
            else
                "Validation type '$(type)' is not defined" |>
                ErrorException |>
                throw
            end

            level += 1
        end

        if valid
            # We've acquired all of the locks required by the validation
            # process, so we can now run the wrapped function
            f()
        end
    finally
        for ii = 1:level-1
            unlock(predecessors[ii])
        end
    end

    valid
end

#===========================
ConcurrentSkipList external API
===========================#

height(list::ConcurrentSkipList) = list.height[]
Base.length(list::ConcurrentSkipList) = list.length[]

function Base.in(val, list::ConcurrentSkipList)
    level_found, predecessors, successors = find_node(list, val)

    level_found != -1                            &&
        is_fully_linked(successors[level_found]) &&
        !is_marked_for_deletion(successors[level_found])
end

Base.insert!(list::ConcurrentSkipList{T,M}, val) where {T,M} =
    insert!(list, ConcurrentNode{T,M}(val; p=list.height_p, max_height=list.max_height))

function Base.insert!(list::ConcurrentSkipList{T,M}, node::ConcurrentNode) where {T,M}
    search_height = max(height(node), height(list))
    predecessors, successors = create_find_node_buffers(list, search_height)

    while true
        level_found = find_node!(list, node, predecessors, successors)

        if M == :Set
            if level_found != -1
                node_found = successors[level_found]

                # If the node is in the process of being deleted, wait until it
                # is deleted before performing insertion again
                if is_marked_for_deletion(node)
                    # TODO: use Event or Condition to wait until node is deleted?
                    continue
                end

                # If the node is _not_ in the process of being deleted, we wait
                # until it's fully linked before we return.
                while !is_fully_linked(node_found)
                    # TODO: use Event or Condition instead of spinning
                    sleep(0.001)
                end
                return nothing
            end
        end

        # Acquire locks to predecessor nodes to ensure that they're still
        # connected to their corresponding successors
        valid = validate(predecessors, successors, node) do
            for ii = 1:height(node)
                link_nodes!(predecessors[ii], node, ii)
                link_nodes!(node, successors[ii], ii)
            end
            atomic_add!(list.length, 1)
            atomic_max!(list.height, height(node))
            mark_fully_linked!(node)
        end

        if valid
            return Some(key(node))
        end
    end
end

function Base.delete!(list::ConcurrentSkipList, val)
    marked = false
    node_to_delete = list.left_sentinel

    predecessors, successors = create_find_node_buffers(list, height(list))

    while true
        level_found = find_node!(list, val, predecessors, successors)

        if !marked && (level_found == NODE_NOT_FOUND || !ok_to_delete(successors[1], level_found))
            # We didn't find the input value, so there's nothing to delete
            return nothing
        end

        if !marked
            node_to_delete = successors[1]
            lock(node_to_delete)

            if is_marked_for_deletion(node_to_delete)
                unlock(node_to_delete)
                return nothing
            end

            marked = true
            mark_for_deletion!(node_to_delete)

            # Now that the node is marked for deletion, we no longer need to hold on
            # to its lock. At this point the node is read-only; no other processes
            # will be able to make any operations on the node.
            unlock(node_to_delete)
        end

        valid = validate(predecessors, successors, node_to_delete; type = :weak) do
            for level = 1:height(node_to_delete)
                link_nodes!(predecessors[level], next(node_to_delete, level), level)
            end
        end

        if valid
            atomic_add!(list.length, -1)
            return Some(val)
        end
    end
end

# Iteration interface for ConcurrentSkipList

Base.iterate(list::ConcurrentSkipList) = next(list.left_sentinel, 1) |> iterate
Base.iterate(node::ConcurrentNode) = is_right_sentinel(node) ? nothing : (key(node), next(node, 1))
Base.iterate(list::ConcurrentSkipList, node::ConcurrentNode) = iterate(node)

#===========================
ConcurrentSkipList internal API
===========================#

create_find_node_buffers(list::ConcurrentSkipList{T,M}, height) where {T,M} =
    (Vector{ConcurrentNode{T,M}}(undef, height), Vector{ConcurrentNode{T,M}}(undef, height))

find_node(list::ConcurrentSkipList, val) = find_node(list, val, height(list))
find_node(list::ConcurrentSkipList, node::ConcurrentNode) = find_node(list, node, height(node))

function find_node(list::ConcurrentSkipList{T,M}, val, search_height) where {T,M}
    predecessors, successors = create_find_node_buffers(list, search_height)
    level_found = find_node!(list, val, predecessors, successors)

    level_found, predecessors, successors
end

function find_node!(list::ConcurrentSkipList, val, predecessors, successors)
    search_height = length(predecessors)
    level_found = NODE_NOT_FOUND

    current_node = list.left_sentinel
    for ii = search_height:-1:1
        next_node = next(current_node, ii)
        while next_node < val
            current_node = next_node
            next_node = next(current_node, ii)
        end

        if level_found == NODE_NOT_FOUND && next_node == val
            level_found = ii
        end
        predecessors[ii] = current_node
        successors[ii] = next_node
    end

    level_found
end

