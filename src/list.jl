#================================================

AbstractSkipList API definition, typedefs, and
shared code for child types.

=================================================#

#===========================
Typedefs
===========================#

"""
    SkipList{T,M} <: AbstractSkipList{T,M}

A non-concurrent skip list. `T` is the type of the element that can be stored in the
`SkipList`, while `M` is the list's mode:

- `M == :List`: the same key can be stored in a skip list multiple times.
- `M == :Set`: only one copy of each key is allowed in the skip list. `SkipListSet{T}` is
  an alias for `SkipList{T,:Set}`.

# Examples

```jldoctest; setup = :(using SkipLists)
julia> list = SkipList{Int64}();

julia> insert!(list, 1); insert!(list, 2); insert!(list, 3);

julia> collect(list)
3-element Array{Int64,1}:
 1
 2
 3
```

"""
mutable struct SkipList{T,M} <: AbstractSkipList{T,M}
    # height_p: the parameter used by the geometric distribution for which the height
    # of a newly-created node is sampled. See random_height for more information.
    height_p::Float64

    # The maximum height of a node in the skip list
    max_height::Int64

    # The maximum number of elements that can be stored in a single SkipList node
    node_capacity::Int64

    # predecessor / successor buffers used to store the results found by the find_node
    # function
    predecessor_buffer::Vector{Node{T,M}}
    successor_buffer::Vector{Node{T,M}}

    # left / right sentinel nodes marking the left and right ends of the skip list
    left_sentinel::Node{T,M}
    right_sentinel::Node{T,M}

    # The height of the skip list. This should be an upper bound on the height of all
    # nodes within the skip list
    height::Int64

    # The number of elements in the skip list
    length::Int64
end

"""
    SkipListSet{T}

A non-concurrent skip list that only allows one copy of each key. `SkipListSet{T}` is an alias for
`SkipList{T,:Set}`.
"""
SkipListSet{T} = SkipList{T,:Set}

#===========================
Shared constructors
===========================#

for list_type in (:SkipList,)
    @eval $list_type{T}(args...; kws...) where T = $list_type{T,:List}(args...; kws...)
end

#===========================
Shared AbstractSkipList API
===========================#

function Base.show(io::IO, list::AbstractSkipList)
    write(io, string(list))
end

function Base.string(list::AbstractSkipList{T,M}) where {T,M}
    type_str = if M == :Set
        "SkipListSet{$T}"
    else
        "SkipList{$T}"
    end

    "$type_str(length = $(length(list)), height = $(height(list)))"
end

"""
    max_height(list::AbstractSkipList)

Return the maximum height that a node can attain in the skip list.
"""
max_height(list::AbstractSkipList) = list.max_height

"""
    height_p(list::AbstractSkipList)

Return the `height_p` parameter used by the skip list to sample a random height
for a newly generated node.
"""
height_p(list::AbstractSkipList) = list.height_p

Base.eltype(::AbstractSkipList{T}) where T = T
