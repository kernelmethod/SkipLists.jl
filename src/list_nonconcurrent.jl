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

            Some(val)
        else
            nothing
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
        while right_if_member ? (next_node < val || val ∈ next_node) : (next_node < val && val ∉ next_node)
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

