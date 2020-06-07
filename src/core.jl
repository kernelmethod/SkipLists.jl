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

mutable struct SkiplistNode{T,M}
    val :: T
    next :: Vector{SkiplistNode{T}}
    marked_for_deletion :: Bool
    fully_linked :: Bool
    flags :: UInt8
    lock :: ReentrantLock
end

struct Skiplist{T,M}
    height_p :: Float64
    max_height :: Int64

    left_sentinel :: SkiplistNode{T}
    right_sentinel :: SkiplistNode{T}
    height :: Atomic{Int64}
    length :: Atomic{Int64}
end

abstract type LeftSentinel{T,M} end
abstract type RightSentinel{T,M} end

SkiplistSet{T} = Skiplist{T,:Set}

#===========================
Simple function definitions
===========================#

Base.lock(node :: SkiplistNode) = lock(node.lock)
Base.unlock(node :: SkiplistNode) = unlock(node.lock)

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

