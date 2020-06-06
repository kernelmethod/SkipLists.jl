#================================================

Primary code for the implementation of Skiplist

=================================================#

using Base.Threads
using Logging

#===========================
Constructors
===========================#

Skiplist{T}(args...; kws...) where T = Skiplist{T,:List}(args...; kws...)

function Skiplist{T,M}(; max_height = DEFAULT_MAX_HEIGHT, p = DEFAULT_P) where {T,M}
    if M != :List && M != :Set
        "Skiplist mode $M is not recognized. Valid options are :List and :Set" |>
        ErrorException |>
        throw
    end

    left_sentinel = LeftSentinel{T,M}(; max_height=max_height)
    right_sentinel = RightSentinel{T,M}(; max_height=max_height)

    for ii = 1:max_height
        link_nodes!(left_sentinel, right_sentinel, ii)
    end

    Skiplist{T,M}(
        p,
        max_height,
        left_sentinel,
        right_sentinel,
        Atomic{Int64}(1),
        Atomic{Int64}(0),
    )
end

#===========================
Macros
===========================#

macro validate(predecessors, successors, node, expr, type = :(:strong))
    # Strong validation (used by Base.insert!) requires that we check
    # the following:
    # 1. the predecessor node at each level is not marked for deletion;
    # 2. the successor node at each level is not marked for deletion; and
    # 3. the predecessor is still connected to the successor.
    #
    # Weak validation (used by Base.remove!) drops the second condition, since
    # the successor is supposed to be marked for deletion.
    local check_valid = if type == :(:strong)
        :(!is_marked_for_deletion(pred) &&
          !is_marked_for_deletion(succ) &&
          next(pred, level) === succ)
    elseif type == :(:weak)
        :(!is_marked_for_deletion(pred) &&
          next(pred, level) === succ)
    else
        "Validation type '$(type)' is not defined" |>
        ErrorException |>
        throw
    end

    quote
        valid = true
        level = 1

        try
            # Starting from the bottom level, traverse up the height of the node
            # and check that the $check_valid condition is true for each predecessor /
            # successor pair.
            while valid && level ≤ height($(esc(node)))
                pred = $(esc(predecessors))[level]
                succ = $(esc(successors))[level]
                lock(pred)

                valid = $check_valid
                level += 1
            end

            if valid
                # We've acquired all of the locks required by the validation
                # process, so we can now perform the internal expression
                $(esc(expr))
            end
        finally
            for ii = 1:level-1
                unlock($(esc(predecessors))[ii])
            end
        end

        valid
    end
end

#===========================
Skiplist external API
===========================#

height(list :: Skiplist) = list.height[]
Base.length(list :: Skiplist) = list.length[]

Base.string(list :: Skiplist) = "Skiplist(length = $(length(list)), height = $(height(list)))"
Base.show(list :: Skiplist) = println(string(list))
Base.display(list :: Skiplist) = println(string(list))

function Base.in(val, list :: Skiplist)
    level_found, predecessors, successors = find_node(list, val)

    level_found != -1                            &&
        is_fully_linked(successors[level_found]) &&
        !is_marked_for_deletion(successors[level_found])
end

Base.insert!(list :: Skiplist{_,M}, val) where {_,M} =
    insert!(list, SkiplistNode{M}(val; p=list.height_p, max_height=list.max_height))

@generated function Base.insert!(list :: Skiplist{T,M}, node :: SkiplistNode) where {T,M}
    local check_exists = if M == :Set
        quote
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
                return false
            end
        end
    else
        :()
    end

    quote
        while true
            level_found, predecessors, successors = find_node(list, node)

            $check_exists

            # Update the list height.
            #
            # If the height of the list is greater than the old height, then we
            # will need to replace the connections between the left and right
            # sentinel nodes.
            old_height = atomic_max!(list.height, height(node))
            for ii = old_height+1:height(node)
                push!(predecessors, list.left_sentinel)
                push!(successors, list.right_sentinel)
            end

            # Acquire locks to predecessor nodes to ensure that they're still
            # connected to their corresponding successors
            valid = @validate(predecessors, successors, node, begin
                for ii = 1:height(node)
                    link_nodes!(predecessors[ii], node, ii)
                    link_nodes!(node, successors[ii], ii)
                end
                mark_fully_linked!(node)
            end)

            if valid
                atomic_add!(list.length, 1)
                break
            end
        end
    end
end

function Base.delete!(list :: Skiplist, val)
    marked = false
    node_to_delete = list.left_sentinel

    while true
        level_found, predecessors, successors = find_node(list, val)

        if !marked && (level_found == -1 || !ok_to_delete(successors[1], level_found))
            # We didn't find the input value, so there's nothing to delete
            return false
        end

        if !marked
            node_to_delete = successors[1]
            lock(node_to_delete)

            if is_marked_for_deletion(node_to_delete)
                unlock(node_to_delete)
                return false
            end

            marked = true
            mark_for_deletion!(node_to_delete)

            # Now that the node is marked for deletion, we no longer need to hold on
            # to its lock. At this point the node is read-only; no other processes
            # will be able to make any operations on the node.
            unlock(node_to_delete)
        end

        valid = @validate(predecessors, successors, node_to_delete,
        begin
            for level = 1:height(node_to_delete)
                link_nodes!(predecessors[level], next(node_to_delete, level), level)
            end
        end, :weak)

        if valid
            atomic_add!(list.length, -1)
            break
        end
    end
end

# Iteration interface for Skiplist

Base.iterate(list :: Skiplist) = next(list.left_sentinel, 1) |> iterate
Base.iterate(node :: SkiplistNode) = is_right_sentinel(node) ? nothing : (key(node), next(node, 1))
Base.iterate(list :: Skiplist, node :: SkiplistNode) = iterate(node)

#===========================
Skiplist internal API
===========================#

function find_node(list :: Skiplist{T}, val) where T
    predecessors = Vector{SkiplistNode{T}}(undef, height(list))
    successors = Vector{SkiplistNode{T}}(undef, height(list))

    level_found = -1

    current_node = list.left_sentinel
    for ii = height(list):-1:1
        next_node = next(current_node, ii)
        while next_node < val
            current_node = next_node
            next_node = next(current_node, ii)
        end

        if level_found == -1 && next_node == val
            level_found = ii
        end
        predecessors[ii] = current_node
        successors[ii] = next_node
    end

    level_found, predecessors, successors
end
