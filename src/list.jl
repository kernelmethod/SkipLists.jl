#================================================

Primary code for the implementation of Skiplist

=================================================#

using Base.Threads
using Logging

#===========================
Constructors
===========================#

function Skiplist{T}(; max_height = DEFAULT_MAX_HEIGHT, p = DEFAULT_P) where T
    left_sentinel = LeftSentinel{T}(; max_height=max_height)
    right_sentinel = RightSentinel{T}(; max_height=max_height)

    for ii = 1:max_height
        link_nodes!(left_sentinel, right_sentinel, ii)
    end

    Skiplist{T}(
        p,
        max_height,
        left_sentinel,
        right_sentinel,
        Atomic{Int64}(1),
        Atomic{Int64}(0),
    )
end

#===========================
Skiplist external API
===========================#

height(list :: Skiplist) = list.height[]
Base.length(list :: Skiplist) = list.length[]

function Base.vec(list :: Skiplist)
    results = []
    current_node = list.left_sentinel
    current_node = next(current_node, 1)

    while !is_right_sentinel(current_node)
        push!(results, current_node.val)
        current_node = next(current_node, 1)
    end

    results
end

function Base.insert!(list :: Skiplist, val)
    while true
        @debug "Performing insert! for value = $(val)"
        found, predecessors, successors = find_node(list, val)
        new_node = SkiplistNode(val)

        old_height = atomic_max!(list.height, height(new_node))

        for ii = old_height+1:height(new_node)
            push!(predecessors, list.left_sentinel)
            push!(successors, list.right_sentinel)
        end

        # Acquire locks to predecessor nodes to ensure that they're still
        # connected to their corresponding successors
        valid = true
        level = 0
        try
            for ii = 1:height(new_node)
                level = ii
                pred = predecessors[ii]
                succ = successors[ii]
                lock(pred)

                @debug "[insert!(list, $(val))] Acquired lock for level $(level)"

                valid = !is_marked(pred) &&
                        !is_marked(succ) &&
                        next(pred, level) == succ
                if !valid
                    break
                end
            end

            if valid
                # We've acquired all of the locks required to insert the new node
                for ii = 1:height(new_node)
                    link_nodes!(predecessors[ii], new_node, ii)
                    link_nodes!(new_node, successors[ii], ii)
                end
            end
        finally
            for jj = 1:level
                @debug "[insert!(list, $(val))] Released locks for level $(jj)"
                unlock(predecessors[jj])
            end
        end

        if !valid
            continue
        end

        atomic_add!(list.length, 1)
        break
    end
end

#===========================
Skiplist internal API
===========================#

function find_node(list :: Skiplist{T}, val) where T
    h = height(list)
    predecessors = Vector{SkiplistNode{T}}(undef, h)
    successors = Vector{SkiplistNode{T}}(undef, h)

    layer_found = -1

    current_node = list.left_sentinel
    ii = h
    while ii > 0
        next_node = next(current_node, ii)
        if next_node ≤ val
            current_node = next_node
        else
            if layer_found == -1 && key(current_node) == val
                layer_found = ii
            end
            predecessors[ii] = current_node
            successors[ii] = next_node
            ii -= 1
        end
    end

    layer_found, predecessors, successors
end
