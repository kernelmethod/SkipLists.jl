# SkipLists.jl

## Installation

Install SkipLists.jl with

```julia
pkg> add SkipLists
```

## Interface

The SkipLists.jl package exports four new types:

- `SkipList`
- `SkipListSet`
- `ConcurrentSkipList`
- `ConcurrentSkipListSet`

Types prefixed by `Concurrent` are thread- and task-safe, while types suffixed by `Set` only permit one copy of a given key in the collection.

Construct a new skip list by specifying the type of element that should be stored in the list:

```jldoctest
julia> using SkipLists

julia> list = SkipList{Int64}();
```

The type stored in a skip list must satisfy two conditions:

1. The type must support the `<=` and `==` comparison operators.
2. If your list is a `ConcurrentSkipList{T}` or `ConcurrentSkipListSet{T}`, `zero(::Type{T})` must be defined.

### Skip list operations

Each of the types exported by SkipLists.jl supports three operations:

**Insertion:** insert a new element into the skip list with `insert!`:

```jldoctest; setup = :(using SkipLists)
julia> list = SkipList{Int64}();

julia> length(list)
0

julia> insert!(list, 1); insert!(list, 2); insert!(list, 3);

julia> length(list)
3

julia> collect(list)
3-element Array{Int64,1}:
 1
 2
 3
```

**Deletion:** delete an element from the skip list with `delete!`:

```jldoctest; setup = :(using SkipLists)
julia> list = SkipList{Int64}();

julia> insert!(list, 1); insert!(list, 2); insert!(list, 3);

julia> length(list)
3

julia> delete!(list, 2);

julia> length(list)
2

julia> collect(list)
2-element Array{Int64,1}:
 1
 3
```

**Test membership:** determine whether or not an element is in the skip list using `in` (or, equivalently, the `∈` operator):

```jldoctest; setup = :(using SkipLists)
julia> list = SkipList{Int64}();

julia> 1 ∈ list   # Equivalent to in(1, list)
false

julia> insert!(list, 1);

julia> 1 ∈ list
true
```


