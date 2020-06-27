#================================================

Primary code for the implementation of SkipList

=================================================#

using Base.Threads

#===========================
Typedefs
===========================#

mutable struct SkipList{T,M} <: AbstractSkipList{T,M}
    height_p::Float64
    max_height::Int64
    node_capacity::Int64

    predecessor_buffer::Vector{Node{T,M}}
    successor_buffer::Vector{Node{T,M}}

    left_sentinel::Node{T,M}
    right_sentinel::Node{T,M}

    height::Int64
    length::Int64
end

struct ConcurrentSkipList{T,M} <: AbstractSkipList{T,M}
    height_p::Float64
    max_height::Int64

    left_sentinel::ConcurrentNode{T,M}
    right_sentinel::ConcurrentNode{T,M}
    height::Atomic{Int64}
    length::Atomic{Int64}
end

SkipListSet{T} = SkipList{T,:Set}
ConcurrentSkipListSet{T} = ConcurrentSkipList{T,:Set}

#===========================
Shared constructors
===========================#

for list_type in (:SkipList, :ConcurrentSkipList)
    @eval $list_type{T}(args...; kws...) where T = $list_type{T,:List}(args...; kws...)
end

function _check_mode(M)
    if M != :List && M != :Set
        "SkipList mode $M is not recognized. Valid options are :List and :Set" |>
        ErrorException |>
        throw
    end
end

#===========================
SkipList constructors
===========================#

function SkipList{T,M}(;
    max_height = DEFAULT_MAX_HEIGHT,
    p = DEFAULT_P,
    node_capacity = DEFAULT_NODE_CAPACITY,
) where {T,M}

    _check_mode(M)

    left_sentinel = LeftSentinel{T,M}(; max_height=max_height, capacity=node_capacity)
    right_sentinel = RightSentinel{T,M}(; max_height=max_height, capacity=node_capacity)
    predecessors = Vector{Node{T,M}}(undef, max_height)
    successors = Vector{Node{T,M}}(undef, max_height)
    height = 1
    length = 0

    for ii = 1:max_height
        link_nodes!(left_sentinel, right_sentinel, ii)
    end

    SkipList{T,M}(
        p,
        max_height,
        node_capacity,
        predecessors,
        successors,
        left_sentinel,
        right_sentinel,
        height,
        length
    )
end

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
Shared AbstractSkipList API
===========================#

function Base.show(io::IO, list::AbstractSkipList)
    write(io, string(list))
end

Base.string(list::L) where {L <: AbstractSkipList} =
    "$L(length = $(length(list)), height = $(height(list)))"

max_height(list::AbstractSkipList) = list.max_height

height_p(list::AbstractSkipList) = list.height_p

#===========================
SkipList external API
===========================#

height(list::SkipList) = list.height

Base.length(list::SkipList) = list.length

node_capacity(list::SkipList) = list.node_capacity

@generated function Base.insert!(list::SkipList{T,M}, val) where {T,M}
    quote
        level_found, predecessors, successors = find_node(list, val)

        # We insert into the predecessor node from our search that sits in the
        # first level of the skip list. If that node is full, we must split it
        # into two lists.
        insertion_node = predecessors[1]

        if $(M == :Set ? :(level_found == NODE_NOT_FOUND) : :(true))
            insertion_node = begin
                if isfull(insertion_node)
                    # Insertion would overflow the node, so we must first split it into
                    # two nodes.
                    old_node, new_node = split!(
                        insertion_node;
                        max_height=max_height(list),
                        capacity=node_capacity(list),
                        p=height_p(list),
                    )

                    # If the new node has height greater than the old height of the list,
                    # we must increase the size of the list.
                    if height(list) < height(new_node)
                        for ii = height(list)+1:height(new_node)
                            predecessors[ii] = list.left_sentinel
                            successors[ii] = list.right_sentinel
                        end

                        list.height = height(new_node)
                    end

                    # Insert the new node between the predecessor / successor nodes.
                    interpolate_node!(predecessors, successors, new_node)

                    # We insert into the right node if its key is ≤ the insertion value;
                    # otherwise, we insert into the left node.
                    is_sentinel(old_node) || new_node ≤ val ? new_node : old_node
                else
                    insertion_node
                end
            end

            insert!(insertion_node, val)
            list.length += 1
        end
    end
end

function Base.in(val, list::SkipList)
    level_found, predecessors, successors = find_node(list, val; right_if_member = false)
    level_found != NODE_NOT_FOUND
end

function Base.delete!(list::SkipList, val)
    level_found, predecessors, successors = find_node(list, val; right_if_member = false)
    if level_found == NODE_NOT_FOUND
        return nothing
    end

    deletion_node = successors[1]
    result = delete!(deletion_node, val)

    # If the node is empty, we must delete it and remove it from the list
    if isempty(deletion_node) && !is_sentinel(deletion_node)
        for ii = 1:height(deletion_node)
            link_nodes!(predecessors[ii], next(deletion_node, ii), ii)
        end
    end

    list.length -= 1
end

# Implementation of the iteration interface for SkipList

Base.iterate(list::SkipList) = Base.iterate(list, (list.left_sentinel, 1))

function Base.iterate(list::SkipList, state)
    node, ii = state

    if length(node) < ii
        if is_right_sentinel(node)
            nothing
        else
            iterate(list, (next(node, 1), 1))
        end
    else
        node.vals[ii], (node, ii+1)
    end
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

@generated function Base.insert!(list::ConcurrentSkipList{T,M}, node::ConcurrentNode) where {T,M}
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

function Base.delete!(list::ConcurrentSkipList, val)
    marked = false
    node_to_delete = list.left_sentinel

    while true
        level_found, predecessors, successors = find_node(list, val)

        if !marked && (level_found == NODE_NOT_FOUND || !ok_to_delete(successors[1], level_found))
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

# Iteration interface for ConcurrentSkipList

Base.iterate(list::ConcurrentSkipList) = next(list.left_sentinel, 1) |> iterate
Base.iterate(node::ConcurrentNode) = is_right_sentinel(node) ? nothing : (key(node), next(node, 1))
Base.iterate(list::ConcurrentSkipList, node::ConcurrentNode) = iterate(node)

#===========================
ConcurrentSkipList internal API
===========================#

"""
Traverse through a skip list, searching for the input value. Returns

- `level_found`: the first level on which a node was found containing the
  input value.
- `predecessors`: a list of nodes with the property that `predecessors[ii]`
  is the rightmost node whose key is `≤ val` in the `ii`th level.
- `successors`: a list of the nodes that come after the predecessor nodes in
  the `predecessors` list.
"""
function find_node(list::SkipList{T,M}, val; right_if_member = true) where {T,M}
    list_height = height(list)
    predecessors = list.predecessor_buffer
    successors = list.successor_buffer

    level_found = NODE_NOT_FOUND

    current_node = list.left_sentinel
    for ii = list_height:-1:1
        # Move to the right until we reach a node whose key is
        # greater than the value we're searching for
        next_node = next(current_node, ii)
        while next_node < val || (right_if_member && val ∈ next_node)
            current_node = next_node
            next_node = next(current_node, ii)
        end

        # Note to future self: trying to figure out how to delete node. Need
        # to reconsider the < inequality when doing search

        if level_found == NODE_NOT_FOUND
            if (right_if_member || is_left_sentinel(current_node)) && val ∈ current_node
                level_found = ii
            elseif !right_if_member && val ∈ next_node
                level_found = ii
            end
        end
        predecessors[ii] = current_node
        successors[ii] = next_node
    end

    level_found, predecessors, successors
end


function find_node(list::ConcurrentSkipList{T,M}, val) where {T,M}
    list_height = height(list)
    predecessors = Vector{ConcurrentNode{T,M}}(undef, list_height)
    successors = Vector{ConcurrentNode{T,M}}(undef, list_height)

    level_found = NODE_NOT_FOUND

    current_node = list.left_sentinel
    for ii = list_height:-1:1
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

    level_found, predecessors, successors
end

