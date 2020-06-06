#================================================

Primary code for the implementation of SkiplistNode

=================================================#

using Base.Threads

#===========================
Constructors
===========================#

SkiplistNode(val :: T; kws...) where T =
    SkiplistNode{T}(val; kws...)

SkiplistNode{T}(val; p = DEFAULT_P, max_height = DEFAULT_MAX_HEIGHT, kws...) where T =
    SkiplistNode{T}(val, random_height(p; max_height=max_height); kws...)

function SkiplistNode{T}(val, height; flags = 0x0) where T
    next = Vector{SkiplistNode{T}}(undef, height)
    lock = ReentrantLock()

    SkiplistNode{T}(val, next, false, Condition(), flags, lock)
end

LeftSentinel{T}(; max_height = DEFAULT_MAX_HEIGHT, kws...) where T =
    SkiplistNode{T}(zero(T), max_height; flags = FLAG_IS_LEFT_SENTINEL, kws...)
RightSentinel{T}(; max_height = DEFAULT_MAX_HEIGHT, kws...) where T =
    SkiplistNode{T}(zero(T), max_height; flags = FLAG_IS_RIGHT_SENTINEL, kws...)

#===========================
External API
===========================#

@inline height(node :: SkiplistNode) = length(node.next)
@inline key(node :: SkiplistNode) = node.val
@inline key(val) = val

is_marked(node :: SkiplistNode) = node.marked_for_deletion

Base.string(node :: SkiplistNode) =
    "SkiplistNode($(key(node)), height = $(height(node)))"
Base.show(node :: SkiplistNode) = show(string(node))
Base.display(node :: SkiplistNode) = display(string(node))

function Base.:(<=)(node :: SkiplistNode, val)
    is_sentinel(node) ? is_left_sentinel(node) : (key(node) ≤ val)
end

function Base.:(<=)(val, node :: SkiplistNode)
    is_sentinel(node) ? is_right_sentinel(node) : (val ≤ key(node))
end

function Base.:(<=)(node_1 :: SkiplistNode, node_2 :: SkiplistNode)
    if is_sentinel(node_1)
        is_left_sentinel(node_1) || is_right_sentinel(node_2)
    elseif is_sentinel(node_2)
        is_right_sentinel(node_2)
    else
        key(node_1) ≤ key(node_2)
    end
end

# Node links

function link_nodes!(src, dst, level)
    src.next[level] = dst
end

next(src :: SkiplistNode, level) = src.next[level]

# Flags
@inline has_flag(node, flag) = (node.flags & flag) != 0
@inline is_left_sentinel(node) = has_flag(node, FLAG_IS_LEFT_SENTINEL)
@inline is_right_sentinel(node) = has_flag(node, FLAG_IS_RIGHT_SENTINEL)
@inline is_sentinel(node) = has_flag(node, IS_SENTINEL)

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


