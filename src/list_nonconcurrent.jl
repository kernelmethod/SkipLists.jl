#================================================

SkipList- and SkipListSet-specific code

=================================================#

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
    predecessor_offsets = Vector{Int}(undef, max_height)
    height = 1

    for ii = 1:max_height
        link_nodes!(left_sentinel, right_sentinel, ii)
        left_sentinel.width[ii] = 0
    end

    SkipList{T,M}(
        p,
        max_height,
        node_capacity,
        predecessors,
        successors,
        predecessor_offsets,
        left_sentinel,
        right_sentinel,
        height
    )
end

#===========================
SkipList external API
===========================#

height(list::SkipList) = list.height

Base.length(list::SkipList) = list.left_sentinel.width[list.height]

node_capacity(list::SkipList) = list.node_capacity

Base.size(list::SkipList) = (length(list),)
Base.IndexStyle(::Type{SkipList}) = IndexLinear()

function Base.getindex(list::SkipList, i)
    node, k = find_index(list, i)
    node.vals[k]
end

function Base.insert!(list::SkipList{T,M}, val) where {T,M}
    insertion_node, location, predecessors, successors, predecessor_offsets = find_node(list, val)

    # We insert into the predecessor node from our search that sits in the
    # first level of the skip list. If that node is full, we must split it
    # into two lists.
    @assert insertion_node === predecessors[1]
    insertion_index = first(location)

    # If the value was found in the list and we're in :Set mode, we skip over
    # insertion and just return `nothing`
    if M == :Set && !isempty(location) #level_found != NODE_NOT_FOUND
        nothing
    else
        if isfull(insertion_node)
            # Insertion would overflow the node, so we must first split it into
            # two nodes.
            old_node, new_node = split!(
                insertion_node;
                max_height=max_height(list),
                capacity=node_capacity(list),
                p=height_p(list),
            )
            
            # Correct the insertion point if necessary to account for the split
            @assert insertion_node === old_node
            if insertion_index > length(old_node)
                insertion_node = new_node
                insertion_index -= length(old_node)
            end

            # Fix node widths to account for elements removed from `old_node`
            # (`new_node` is still not in the list)
            n_removed = length(new_node)
            for level = 1:height(list)
                @assert level > height(old_node) || predecessors[level] === old_node
                predecessors[level].width[level] -= n_removed
            end

            # Height of list should be kept at least one higher than highest non-sentinel node
            # (since the width of the left sentinel must be correctly maintained at the 
            #  level above the highest non-sentinel).
            # Grow as necessary before inserting the new node.
            if height(list) < height(new_node) + 1
                len = length(list) # == list.left_sentinel.width[height(list)]
                for ii = height(list)+1:height(new_node)+1
                    predecessors[ii] = list.left_sentinel
                    successors[ii] = list.right_sentinel
                    predecessor_offsets[ii] = 0
                    list.left_sentinel.width[ii] = len
                end

                list.height = height(new_node) + 1
            end

            # Insert the new node between the predecessor / successor nodes.
            interpolate_node!(list, new_node, predecessors, successors, predecessor_offsets)
        end

        insert!(insertion_node.vals, insertion_index, val)
        for level = 1:height(insertion_node)
            # `insertion_node` may differ from `predecessor[level]` at these levels 
            # if the original `insertion_node` was split
            insertion_node.width[level] += 1
        end
        for level = height(insertion_node)+1:height(list)
            predecessors[level].width[level] += 1
        end

        Some(val)
    end
end

function Base.in(val, list::SkipList)
    _, location, _... = find_node(list, val)
    !isempty(location)
end

function Base.delete!(list::SkipList{T,M}, val) where {T,M}
    deletion_node, location, predecessors, successors, _ = find_node(list, val; compare_smallest = false)
    @assert deletion_node === successors[1]

    isempty(location) && return nothing # value not in list
    M == :Set && @assert length(location) == 1
    deletion_index = last(location)

    deleteat!(deletion_node.vals, deletion_index)
    for ii = 1:height(deletion_node)
        deletion_node.width[ii] -= 1
    end
    for ii = height(deletion_node)+1:height(list)
        predecessors[ii].width[ii] -= 1
    end

    # If the node is empty, we must delete it and remove it from the list
    if isempty(deletion_node) && !is_sentinel(deletion_node)
        for ii = 1:height(deletion_node)
            link_nodes!(predecessors[ii], next(deletion_node, ii), ii)
            predecessors[ii].width[ii] += deletion_node.width[ii]
        end
    end

    Some(val)
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
SkipList internal API
===========================#

"""
Traverse through a skip list, searching for the input value. Returns

- `node`: a node where the value is found, or where it could be inserted.
- `location`: the range of indexes in `node.vals` where the value is found,
              or an empty range at the insertion index if not found.
- `predecessors`: a list of nodes preceding the value:
    - if `compare_smallest` is `true`, `predecessors[ii]` is the rightmost 
        node in the `ii`th level whose *smallest* element is `≤ val`.
    - if `compare_smallest` is `false`, `predecessors[ii]` is the rightmost 
        node in the `ii`th level whose *largest* element is `< val`.
- `successors`: a list of the nodes that come after the predecessor nodes in
  the `predecessors` list.
"""
function find_node(list::SkipList{T,M}, val; compare_smallest = true) where {T,M}
    list_height = height(list)
    predecessors = list.predecessor_buffer
    successors = list.successor_buffer
    predecessor_offsets = list.predecessor_offset_buffer

    current_node, current_offset = list.left_sentinel, 0
    local next_node
    @assert list_height >= 1
    for ii = list_height:-1:1
        # Move to the right until we reach a node whose key is
        # greater than the value we're searching for
        next_node = next(current_node, ii)
        next_offset = current_offset + current_node.width[ii]
        while compare_smallest ? next_node <= val : !is_right_sentinel(next_node) && next_node.vals[end] < val
            current_node, current_offset = next_node, next_offset
            next_node = next(current_node, ii)
            next_offset = current_offset + current_node.width[ii]
        end

        predecessors[ii] = current_node
        successors[ii] = next_node
        predecessor_offsets[ii] = current_offset
    end

    node = compare_smallest ? current_node : next_node
    location = searchsorted(node.vals, val)

    node, location, predecessors, successors, predecessor_offsets
end

"""
Find `node` and `k` such that `node.vals[k]` is the `i`th list element
"""
function find_index(list::SkipList, i)
    @boundscheck Base.checkbounds(list, i)
    offset = 0
    node = list.left_sentinel
    for level = height(list):-1:1
        while (next_offset = offset + node.width[level]) < i
            node = next(node, level)
            offset = next_offset
        end
    end
    node, i-offset
end

"""
Insert a new node between a list of predecessor and successor nodes.
"""
function interpolate_node!(list, node, predecessors, successors, predecessor_offsets)
    offset = predecessor_offsets[1] + predecessors[1].width[1]
    for level = 1:height(node)
        link_nodes!(predecessors[level], node, level)
        link_nodes!(node, successors[level], level)
        d = offset - predecessor_offsets[level]
        node.width[level] = predecessors[level].width[level] - d + length(node)
        predecessors[level].width[level] = d
    end
    for level = height(node)+1:height(list)
        predecessors[level].width[level] += length(node)
    end
end

function collect_nodes(skiplist)
    current = skiplist.left_sentinel
    res = [current]
    while current !== skiplist.right_sentinel
        current = next(current, 1)
        push!(res, current)
    end
    res
end

