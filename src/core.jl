#================================================

Basic typedefs, function / macro defintions, etc. for the module

=================================================#

using Base.Threads

#===========================
Constants
===========================#

const DEFAULT_P = 0.5
const DEFAULT_MAX_HEIGHT = 64
const DEFAULT_NODE_CAPACITY = 256

const FLAG_IS_LEFT_SENTINEL = 0x80
const FLAG_IS_RIGHT_SENTINEL = 0x40
const IS_SENTINEL = FLAG_IS_LEFT_SENTINEL | FLAG_IS_RIGHT_SENTINEL

const NODE_NOT_FOUND = -1

#===========================
Abstract typedefs
===========================#

abstract type AbstractNode{T,M} end
abstract type AbstractSkipList{T,M} <: AbstractVector{T} end

abstract type LeftSentinel{T,M} end
abstract type RightSentinel{T,M} end

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

function _check_mode(M)
    if M != :List && M != :Set
        "SkipList mode $M is not recognized. Valid options are :List and :Set" |>
        ErrorException |>
        throw
    end
end


