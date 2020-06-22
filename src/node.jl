#================================================

Primary code for the implementation of ConcurrentNode

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

struct ConcurrentNode{T,M} <: AbstractNode{T,M}
    val::T
    next::Vector{ConcurrentNode{T,M}}
    marked_for_deletion::Atomic{Bool}
    fully_linked::Atomic{Bool}
    flags::UInt8
    lock::ReentrantLock
end

abstract type LeftSentinel{T,M} end
abstract type RightSentinel{T,M} end
abstract type ConcurrentLeftSentinel{T,M} end
abstract type ConcurrentRightSentinel{T,M} end

#===========================
Shared AbstractNode constructors
===========================#

for dtype in (:Node, :ConcurrentNode)
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
ConcurrentNode constructors
===========================#

function ConcurrentNode{T,M}(val, height; flags = 0x0, max_height = DEFAULT_MAX_HEIGHT) where {T,M}
    height = min(height, max_height)
    next = Vector{ConcurrentNode{T,M}}(undef, height)
    lock = ReentrantLock()

    fully_linked = Atomic{Bool}(false)
    marked_for_deletion = Atomic{Bool}(false)

    ConcurrentNode{T,M}(val, next, fully_linked, marked_for_deletion, flags, lock)
end

function ConcurrentLeftSentinel{T,M}(; max_height = DEFAULT_MAX_HEIGHT, kws...) where {T,M}
    node = ConcurrentNode{T,M}(zero(T), max_height; flags = FLAG_IS_LEFT_SENTINEL, kws...)
    mark_fully_linked!(node)
    node
end

function ConcurrentRightSentinel{T,M}(; max_height = DEFAULT_MAX_HEIGHT, kws...) where {T,M}
    node = ConcurrentNode{T,M}(zero(T), max_height; flags = FLAG_IS_RIGHT_SENTINEL, kws...)
    mark_fully_linked!(node)
    node
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

function Base.insert!(node::Node, val)
    if length(node) ≥ capacity(node)
        "Node size exceeds capacity ($(capacity(node)))" |>
        ErrorException |>
        throw
    end

    searchsorted(node.vals, val) |>
    idx -> insert!(node.vals, first(idx), val)
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
    if length(predecessors) != length(successors)
        "predecessor and successor lists have different lengths" |>
        ErrorException |>
        throw
    end

    if length(predecessors) < height(node)
        "predecessor and successor lists must have length ≥ the height of the interpolating node" |>
        ErrorException |>
        throw
    end

    for level = 1:height(node)
        link_nodes!(predecessors[level], node, level)
        link_nodes!(node, successors[level], level)
    end
end


#===========================
ConcurrentNode external API
===========================#

function Base.string(node::ConcurrentNode)
    result = "key = $(key(node)), height = $(height(node)), "
    result *= "marked_for_deletion = $(is_marked_for_deletion(node)), "
    result *= "fully_linked = $(is_fully_linked(node))"
    "ConcurrentNode($result)"
end

Base.lock(node::ConcurrentNode) = lock(node.lock)
Base.unlock(node::ConcurrentNode) = unlock(node.lock)

key(node::ConcurrentNode) = node.val

is_marked_for_deletion(node) = node.marked_for_deletion[]
is_fully_linked(node) = node.fully_linked[]

mark_for_deletion!(node) = atomic_or!(node.marked_for_deletion, true)
mark_fully_linked!(node) = atomic_or!(node.fully_linked, true)

"""
Check that a `ConcurrentNode` is okay to be deleted, meaning that
- it's fully linked,
- unmarked, and
- that it was found at its top layer.
"""
function ok_to_delete(node, level_found)
    height(node) == level_found &&
    is_fully_linked(node) &&
    !is_marked_for_deletion(node)
end

#===========================
Helper functions
===========================#

"""
    random_height(p, args...)

Samples a number from a geometric distribution with parameter ``p`` and uses it
for the height of a new node in a Skiplist.

# Arguments

# Examples
"""
function random_height(p, args...; max_height = DEFAULT_MAX_HEIGHT)
    # This function uses the fact that the c.d.f. of a geometric distribution
    # is 1 - (1 - p)^k. To generate the height for a new node in a skip list,
    # we want it to be distributed as a geometric RV plus one.
    #
    # To perform this sampling, we randomly sample X ∈ [0,1], and find the
    # smallest value of k for which cdf(k) > X. We observe that
    #
    #           1 - (1 - p)^k   ≥    X                          =>
    #           (1 - p)^k       ≤    1 - X                      =>
    #           k log(1 - p)    ≤    log(1 - X)                 =>
    #           k               ≥    log(1 - X) / log(1 - p)
    #
    # (The inequality is flipped in the last step since log(1 - p) is necessarily
    # negative.) We can simplify this further by observing that Y = 1 - X has
    # the same distribution as X (i.e., Uniform([0,1])). As a result, to sample
    # a new random number, all we need to do is find the smallest integer k
    # satisfying k ≥ log(Y) / log(1 - p) for some Y ~ Uniform([0,1]), which
    # implies that
    #
    #           k = ⌈log(Y) / log(1 - p)⌉
    #

    p_scaler = 1 / log(1 - p)
    Y = rand(args...)
    @.(ceil(Int64, log(Y) * p_scaler) |> x -> min(max_height, x))
end


