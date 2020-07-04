#================================================

AbstractNode API definition, and typedefs for
child types

=================================================#

using Base.Threads

#===========================
Type definitions
===========================#

struct Node{T,M} <: AbstractNode{T,M}
    vals::Vector{T}
    next::Vector{Node{T,M}}
    capacity::Int64
    flags::UInt8
end

#===========================
Shared AbstractNode constructors
===========================#

for dtype in (:Node,)
    @eval begin
        $dtype{M}(val; kws...) where {T,M} =
            $dtype{eltype(val),M}(val; kws...)

        $dtype{M}(val, height; kws...) where {T,M} =
            $dtype{eltype(val),M}(val, height; kws...)

        $dtype{T,M}(val; p = DEFAULT_P, max_height = DEFAULT_MAX_HEIGHT, kws...) where {T,M} =
            $dtype{T,M}(val, random_height(p; max_height=max_height); kws...)
    end
end

#===========================
Shared AbstractNode API
===========================#

height(node::AbstractNode) = length(node.next)

Base.show(io::IO, node::AbstractNode) = write(io, string(node))
Base.display(node::AbstractNode) = println(string(node))

# Node links

function link_nodes!(src, dst, level)
    src.next[level] = dst
end

next(src::AbstractNode, level) = src.next[level]

# Flags

has_flag(node, flag) = (node.flags & flag) != 0
is_left_sentinel(node) = has_flag(node, FLAG_IS_LEFT_SENTINEL)
is_right_sentinel(node) = has_flag(node, FLAG_IS_RIGHT_SENTINEL)
is_sentinel(node) = has_flag(node, IS_SENTINEL)

# Node comparison

Base.:(<)(node::AbstractNode, val) = !(val ≤ node)
Base.:(<)(val, node::AbstractNode) = !(node ≤ val)
Base.:(<)(node_1::AbstractNode, node_2::AbstractNode) = !(node_2 ≤ node_1)

Base.:(<=)(node::AbstractNode, val) =
    is_sentinel(node) ? is_left_sentinel(node) : (key(node) ≤ val)

Base.:(<=)(val, node::AbstractNode) =
    is_sentinel(node) ? is_right_sentinel(node) : (val ≤ key(node))

function Base.:(<=)(node_1::AbstractNode, node_2::AbstractNode)
    if is_sentinel(node_1)
        is_left_sentinel(node_1) || is_right_sentinel(node_2)
    elseif is_sentinel(node_2)
        is_right_sentinel(node_2)
    else
        key(node_1) ≤ key(node_2)
    end
end

Base.:(==)(node::AbstractNode, val) = is_sentinel(node) ? false : key(node) == val
Base.:(==)(val, node::AbstractNode) = (node == val)
Base.:(==)(node_1::AbstractNode, node_2::AbstractNode) =
    (is_sentinel(node_1) || is_sentinel(node_2)) ?
    false :
    key(node_1) == key(node_2)
