var documenterSearchIndex = {"docs":
[{"location":"#SkipLists.jl","page":"SkipLists.jl","title":"SkipLists.jl","text":"","category":"section"},{"location":"#Installation","page":"SkipLists.jl","title":"Installation","text":"","category":"section"},{"location":"","page":"SkipLists.jl","title":"SkipLists.jl","text":"Install SkipLists.jl with","category":"page"},{"location":"","page":"SkipLists.jl","title":"SkipLists.jl","text":"pkg> add SkipLists","category":"page"},{"location":"#Interface","page":"SkipLists.jl","title":"Interface","text":"","category":"section"},{"location":"","page":"SkipLists.jl","title":"SkipLists.jl","text":"The SkipLists.jl package exports two new types:","category":"page"},{"location":"","page":"SkipLists.jl","title":"SkipLists.jl","text":"SkipList\nSkipListSet","category":"page"},{"location":"","page":"SkipLists.jl","title":"SkipLists.jl","text":"SkipList allows multiple copies of a single key in the collection, whereas keys must be unique for SkipListSet.","category":"page"},{"location":"","page":"SkipLists.jl","title":"SkipLists.jl","text":"Construct a new skip list by specifying the type of element that should be stored in the list:","category":"page"},{"location":"","page":"SkipLists.jl","title":"SkipLists.jl","text":"julia> using SkipLists\n\njulia> list = SkipList{Int64}();","category":"page"},{"location":"","page":"SkipLists.jl","title":"SkipLists.jl","text":"The type of key stored in a skip list must support the <= and == comparison operators.","category":"page"},{"location":"#Skip-list-operations","page":"SkipLists.jl","title":"Skip list operations","text":"","category":"section"},{"location":"","page":"SkipLists.jl","title":"SkipLists.jl","text":"Each of the types exported by SkipLists.jl supports three operations:","category":"page"},{"location":"","page":"SkipLists.jl","title":"SkipLists.jl","text":"Insertion: insert a new element into the skip list with insert!:","category":"page"},{"location":"","page":"SkipLists.jl","title":"SkipLists.jl","text":"julia> list = SkipList{Int64}();\n\njulia> length(list)\n0\n\njulia> insert!(list, 1); insert!(list, 2); insert!(list, 3);\n\njulia> length(list)\n3\n\njulia> collect(list)\n3-element Vector{Int64}:\n 1\n 2\n 3","category":"page"},{"location":"","page":"SkipLists.jl","title":"SkipLists.jl","text":"Deletion: delete an element from the skip list with delete!:","category":"page"},{"location":"","page":"SkipLists.jl","title":"SkipLists.jl","text":"julia> list = SkipList{Int64}();\n\njulia> insert!(list, 1); insert!(list, 2); insert!(list, 3);\n\njulia> length(list)\n3\n\njulia> delete!(list, 2);\n\njulia> length(list)\n2\n\njulia> collect(list)\n2-element Vector{Int64}:\n 1\n 3","category":"page"},{"location":"","page":"SkipLists.jl","title":"SkipLists.jl","text":"Test membership: determine whether or not an element is in the skip list using in (or, equivalently, the ∈ operator):","category":"page"},{"location":"","page":"SkipLists.jl","title":"SkipLists.jl","text":"julia> list = SkipList{Int64}();\n\njulia> 1 ∈ list   # Equivalent to in(1, list)\nfalse\n\njulia> insert!(list, 1);\n\njulia> 1 ∈ list\ntrue","category":"page"},{"location":"","page":"SkipLists.jl","title":"SkipLists.jl","text":"Random access: read the ith element using indexing operations:","category":"page"},{"location":"","page":"SkipLists.jl","title":"SkipLists.jl","text":"julia> list = SkipList{Int64}();\n\njulia> insert!(list, 4); insert!(list, 2); insert!(list, 3); \n\njulia> list[2]\n3\n\njulia> collect(list) == [list[i] for i=1:length(list)] == 2:4\ntrue","category":"page"}]
}