#================================================

Node-specific code

=================================================#

#===========================
Node constructors
===========================#

function Node{T,M}(
    vals,
    height;
    flags = 0x0,
    capacity = DEFAULT_NODE_CAPACITY,
    max_height = DEFAULT_MAX_HEIGHT
) where {T,M}

    height = min(height, max_height)
    next = Vector{Node{T,M}}(undef, height)
    Node{T,M}(vals, next, capacity, flags)
end

LeftSentinel{T,M}(; max_height = DEFAULT_MAX_HEIGHT, kws...) where {T,M} =
    Node{T,M}(Vector{T}(undef,0), max_height; flags = FLAG_IS_LEFT_SENTINEL, kws...)

RightSentinel{T,M}(; max_height = DEFAULT_MAX_HEIGHT, kws...) where {T,M} =
    Node{T,M}(Vector{T}(undef,0), max_height; flags = FLAG_IS_RIGHT_SENTINEL, kws...)

#===========================
Node external API
===========================#

function Base.string(node::Node)
    result = "$(node.vals), height = $(height(node))"
    "Node($result)"
end

Base.length(node::Node) = length(node.vals)

key(node::Node) = node.vals[1]

capacity(node::Node) = node.capacity
Base.isempty(node::Node) = (length(node) == 0)
isfull(node::Node) = is_sentinel(node) || (length(node) == capacity(node))

Base.in(val, node::Node) =
    searchsorted(node.vals, val) |>
    idx -> first(idx) ≤ last(idx)

@generated function Base.insert!(node::Node{T,M}, val) where {T,M}
    quote
        if length(node) ≥ capacity(node)
            "Node size exceeds capacity ($(capacity(node)))" |>
            ErrorException |>
            throw
        end

        idx = searchsorted(node.vals, val)

        $(
            if M == :Set
                quote
                    if first(idx) > last(idx)     # Value not found in node
                        insert!(node.vals, first(idx), val)
                    end
                end
            else
                quote
                    insert!(node.vals, first(idx), val)
                end
            end
        )
    end
end

Base.delete!(node::Node, val) =
    searchsorted(node.vals, val) |>
    idx -> if first(idx) ≤ last(idx)
        deleteat!(node.vals, first(idx))
    end

function split!(node::Node{T,M}; kws...) where {T,M}
    median_idx = div(length(node), 2)
    right_vals = splice!(node.vals, median_idx+1:length(node))
    node, Node{T,M}(right_vals; kws...)
end

"""
Insert a new node between a list of predecessor and successor nodes
"""
function interpolate_node!(predecessors, successors, node)
    for level = 1:height(node)
        link_nodes!(predecessors[level], node, level)
        link_nodes!(node, successors[level], level)
    end
end


