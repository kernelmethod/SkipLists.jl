#================================================

Primary code for the implementation of Skiplist

=================================================#

using Base.Threads

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
        found, predecessors, successors = find_node(list, val)
        new_node = SkiplistNode(val)

        old_height = atomic_max!(list.height, height(new_node))

        for ii = old_height+1:height(new_node)
            push!(predecessors, list.left_sentinel)
            push!(successors, list.right_sentinel)
        end

        # TODO: make thread-safe
        for ii = 1:height(new_node)
            link_nodes!(predecessors[ii], new_node, ii)
            link_nodes!(new_node, successors[ii], ii)
        end

        atomic_add!(list.length, 1)
        break

        #=
        # Grab locks for all predecessor and successor nodes and confirm that
        # they're still connected
        layer = 0
        for (pred, succ) in zip(predecessors, successors)
            layer += 1
            lock(pred)
            lock(succ)

            # Validate that the predecessor node is still connected to
            # the successor
            if next(pred, layer) != succ
            end
        end
        =#
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





