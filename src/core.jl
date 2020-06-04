#================================================

Basic typedefs, function / macro defintions, etc. for the module

=================================================#

using Base.Threads

#===========================
Typedefs
===========================#

struct Skiplist{T}
    left_sentinel :: SkiplistNode{T}
    right_sentinel :: SkiplistNode{T}
    height :: Atomic{Int64}
    length :: Atomic{Int64}
end

struct SkiplistNode{T}
    val :: T
    next :: Vector{SkiplistNode{T}}
    lock :: ReentrantLock
end
