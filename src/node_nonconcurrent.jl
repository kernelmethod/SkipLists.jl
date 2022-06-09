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
    width = fill(length(vals), height)
    Node{T,M}(vals, next, width, capacity, flags)
end

LeftSentinel{T,M}(; max_height = DEFAULT_MAX_HEIGHT, kws...) where {T,M} =
    Node{T,M}(Vector{T}(undef,0), max_height; flags = FLAG_IS_LEFT_SENTINEL, kws...)

RightSentinel{T,M}(; max_height = DEFAULT_MAX_HEIGHT, kws...) where {T,M} =
    Node{T,M}(Vector{T}(undef,0), max_height; flags = FLAG_IS_RIGHT_SENTINEL, kws...)

#===========================
Node external API
===========================#

function Base.string(node::Node)
    if is_left_sentinel(node)
        "<left sentinel>"
    elseif is_right_sentinel(node)
        "<right sentinel>"
    else
        result = "$(node.vals), height = $(height(node))"
        "Node($result)"
    end
end

Base.length(node::Node) = length(node.vals)

key(node::Node) = node.vals[1]

capacity(node::Node) = node.capacity
Base.isempty(node::Node) = (length(node) == 0)
isfull(node::Node) = is_sentinel(node) || (length(node) == capacity(node))

Base.in(val, node::Node) = insorted(val, node.vals)

function split!(node::Node{T,M}; kws...) where {T,M}
    median_idx = div(length(node), 2)
    right_vals = splice!(node.vals, median_idx+1:length(node))
    node, Node{T,M}(right_vals; kws...)
end


