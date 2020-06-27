#================================================

AbstractSkipList API definition, typedefs, and
shared code for child types.

=================================================#

using Base.Threads

#===========================
Typedefs
===========================#

mutable struct SkipList{T,M} <: AbstractSkipList{T,M}
    height_p::Float64
    max_height::Int64
    node_capacity::Int64

    predecessor_buffer::Vector{Node{T,M}}
    successor_buffer::Vector{Node{T,M}}

    left_sentinel::Node{T,M}
    right_sentinel::Node{T,M}

    height::Int64
    length::Int64
end

struct ConcurrentSkipList{T,M} <: AbstractSkipList{T,M}
    height_p::Float64
    max_height::Int64

    left_sentinel::ConcurrentNode{T,M}
    right_sentinel::ConcurrentNode{T,M}
    height::Atomic{Int64}
    length::Atomic{Int64}
end

SkipListSet{T} = SkipList{T,:Set}
ConcurrentSkipListSet{T} = ConcurrentSkipList{T,:Set}

#===========================
Shared constructors
===========================#

for list_type in (:SkipList, :ConcurrentSkipList)
    @eval $list_type{T}(args...; kws...) where T = $list_type{T,:List}(args...; kws...)
end

#===========================
Shared AbstractSkipList API
===========================#

function Base.show(io::IO, list::AbstractSkipList)
    write(io, string(list))
end

Base.string(list::L) where {L <: AbstractSkipList} =
    "$L(length = $(length(list)), height = $(height(list)))"

max_height(list::AbstractSkipList) = list.max_height

height_p(list::AbstractSkipList) = list.height_p

