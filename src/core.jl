#================================================

Basic typedefs, function / macro defintions, etc. for the module

=================================================#

using Base.Threads

#===========================
Constants
===========================#

const DEFAULT_P = 0.5
const DEFAULT_MAX_HEIGHT = 64

const FLAG_IS_LEFT_SENTINEL = 0x80
const FLAG_IS_RIGHT_SENTINEL = 0x40
const IS_SENTINEL = FLAG_IS_LEFT_SENTINEL | FLAG_IS_RIGHT_SENTINEL

#===========================
Typedefs
===========================#

mutable struct SkiplistNode{T}
    val :: T
    next :: Vector{SkiplistNode{T}}
    marked_for_deletion :: Bool
    fully_linked :: Bool
    flags :: UInt8
    lock :: ReentrantLock
end

struct Skiplist{T}
    height_p :: Float64
    max_height :: Int64

    left_sentinel :: SkiplistNode{T}
    right_sentinel :: SkiplistNode{T}
    height :: Atomic{Int64}
    length :: Atomic{Int64}
end

abstract type LeftSentinel{T} end
abstract type RightSentinel{T} end

#===========================
Simple function definitions
===========================#

function Base.lock(node :: SkiplistNode)
    # Sentinel nodes are immutable, so we don't lock if we encounter them
    if !is_sentinel(node)
        lock(node.lock)
    end
end

function Base.unlock(node :: SkiplistNode)
    # Sentinel nodes are immutable, so we don't lock if we encounter them
    if !is_sentinel(node)
        unlock(node.lock)
    end
end

#===========================
Macros
===========================#

macro with_lock(L, expr)
    quote
        lock($(esc(L)))
        try
            $(esc(expr))
        finally
            unlock($(esc(L)))
        end
    end
end

