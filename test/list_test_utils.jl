#================================================

Shared testing functions for AbstractSkipList subtypes

================================================#

using Random, SkipLists, Test
using Base.Iterators: partition
using SkipLists: AbstractSkipList

#=========================
AbstractSkipList{T,:List} subtype tests
=========================#

function invariant_tests(list::SkipList)
    # test node widths
    nodes = SkipLists.collect_nodes(list)
    @testset "node widths" begin
        for i in 1:length(nodes)-1
            for level in 1:min(height(nodes[i]), height(list))
                next = i + findfirst(j -> height(nodes[j]) >= level, i+1:length(nodes))
                for lower in 1:level-1
                    @test nodes[i].width[level] == sum(
                            nodes[j].width[lower] for j = i:next-1 if height(nodes[j]) >= lower; init=0)
                end
            end
        end
    end
    # test random access
    @test [list[i] for i=1:length(list)] == collect(list)
end

@generated function test_construct_list(::Type{L}) where {L <: AbstractSkipList}
    quote
        @testset "Construct new $($L)" begin
            list = $L{Int64}()
            @test height(list) == 1
            @test length(list) == 0
            @test eltype(list) == Int64

            buff = IOBuffer()
            show(buff, list)
            seekstart(buff)

            :(
                if L == :SkipList
                    @test String(read(buff)) == "SkipList{Int64}(length = 0, height = 1)"
                end
            )

            # An error should be raised if we attempt to construct a skip list in an
            # invalid mode
            @test_throws ErrorException $L{Int64,:Foo}()

            # Try constructing a set instead
            set = $L{String,:Set}()
            @test height(set) == 1
            @test length(set) == 0
            @test eltype(set) == String

            buff = IOBuffer()
            show(buff, set)
            seekstart(buff)

            :(
                if L == :SkipList
                    @test String(read(buff)) == "SkipListSet{String}(length = 0, height = 1)"
                end
            )
        end
    end
end

@generated function test_insert_into_list(::Type{L}) where {L <: AbstractSkipList}
    quote
        @testset "Insert 1:$n into $($L)" for n = [20, 1000, 100_000]
            # Insert sorted values
            list = $L{Int64}()
            result_success = true
            for ii = 1:n
                result = insert!(list, ii)
                result_success = result_success && (result == Some(ii))
            end

            @test collect(list) == 1:n
            @test isa(collect(list), Vector{Int64})
            @test length(list) == n
            @test result_success
            invariant_tests(list)

            insert!(list, 1)

            @test length(list) == n+1
            @test collect(list) == [1; 1:n]
            invariant_tests(list)

            # Insert shuffled values
            list = $L{Int64}()
            result_success = true
            for ii in shuffle(1:n)
                result = insert!(list, ii)
                result_success = result_success && (result == Some(ii))
            end

            @test collect(list) == 1:n
            @test isa(collect(list), Vector{Int64})
            @test length(list) == n
            @test result_success
            invariant_tests(list)
        end
    end
end

@generated function test_iterate_over_list(::Type{L}) where {L <: AbstractSkipList}
    quote
        @testset "Iterate over $($L)" begin
            vals = shuffle(1:100)
            list = $L{Int64}()
            for ii in vals
                insert!(list, ii)
                invariant_tests(list)
            end

            success = true
            for (x1, x2) in zip(sort(vals), list)
                success = success && x1 == x2
            end

            @test success
        end
    end
end

@generated function test_list_membership(::Type{L}) where {L <: AbstractSkipList}
    quote
        @testset "Test membership in $($L)" begin
            list = $L{Int64}()
            @test 1 ∉ list

            insert!(list, 1)
            @test 1 ∈ list
        end
    end
end

@generated function test_add_duplicate_elements_to_list(::Type{L}) where {L <: AbstractSkipList}
    quote
        @testset "Add duplicate elements to $($L)" begin
            list = $L{Int64}()
            for ii = 1:2
                insert!(list, 1)
                insert!(list, 2)
            end

            @test length(list) == 4
            @test collect(list) == [1, 1, 2, 2]
            @test 1 ∈ list && 2 ∈ list

            delete!(list, 1)
            delete!(list, 2)
            @test length(list) == 2
            @test collect(list) == [1, 2]
            @test 1 ∈ list && 2 ∈ list

            delete!(list, 1)
            delete!(list, 2)
            @test length(list) == 0
            @test collect(list) == []
        end
    end
end

@generated function test_delete_from_list(::Type{L}) where {L <: AbstractSkipList}
    quote
        @testset "Delete from $($L)" begin
            list = $L{Int64}()
            insert!(list, 1)
            insert!(list, 2)
            insert!(list, 3)

            @test delete!(list, 1) == Some(1)
            @test length(list) == 2
            @test 1 ∉ list
            @test collect(list) == collect(2:3)
            invariant_tests(list)

            @test delete!(list, 2) == Some(2)
            @test length(list) == 1
            @test 2 ∉ list
            @test collect(list) == collect(3:3)
            invariant_tests(list)

            @test delete!(list, 3) == Some(3)
            @test length(list) == 0
            @test 3 ∉ list
            invariant_tests(list)

            @test delete!(list, 0) == nothing
            @test collect(list) == []
            @test length(list) == 0
            invariant_tests(list)
        end
    end
end

#=========================
SkipListSet tests
=========================#

@generated function test_insert_into_skip_list_set(::Type{S}) where {S <: AbstractSkipList{T,:Set} where T}
    quote
        @testset "Insert into $($S)" begin
            set = $S{Int64}()
            result_success = true
            for ii = 1:10
                result = insert!(set, ii)
                result_success = result_success && (result == Some(ii))
                invariant_tests(set)
            end

            @test length(set) == 10
            @test collect(set) == 1:10
            @test result_success

            # If we now try to insert a duplicate element into the set, it shouldn't
            # have any effect
            result_success = true
            for ii = shuffle(1:10)
                result = insert!(set, ii)
                result_success = result_success && (result == nothing)
                invariant_tests(set)
            end

            @test length(set) == 10
            @test collect(set) == 1:10
            @test result_success
        end
    end
end

@generated function test_delete_from_skip_list_set(::Type{S}) where {S <: AbstractSkipList{T,:Set} where T}
    quote
        @testset "Remove from $($S)" begin
            set = $S{Int64}()
            orig = 1:100

            result_success = true
            for ii in shuffle(orig)
                # Insert every element twice. The first insertion should return
                # Some(val); the second insertion fails and thus should return Nothing.
                result_success = result_success && (insert!(set, ii) == Some(ii))
                result_success = result_success && (insert!(set, ii) == nothing)
                invariant_tests(set)
            end

            @test length(set) == length(orig)
            @test collect(set) == sort(orig)
            @test result_success

            # Remove all of the even elements
            to_remove = filter(iseven, orig)
            remaining = filter(isodd, orig) |> sort
            result_success = true
            for ii in shuffle(to_remove)
                # Delete the element twice. The first delete should be successful and
                # return Some(ii). The second delete should fail and return Nothing.
                result_success = result_success && (delete!(set, ii) == Some(ii))
                result_success = result_success && (delete!(set, ii) == nothing)
                invariant_tests(set)
            end

            @test length(set) == length(remaining)
            @test collect(set) == remaining
            @test result_success

            # Test membership of remaining elements
            success = true
            for ii in remaining
                success = success && ii ∈ set
            end
            @test success
        end
    end
end

@generated function test_mixed_insert_delete_from_skip_list_set(::Type{S}) where {S <: AbstractSkipList{T,:Set} where T}
    quote
        @testset "Mixed insertion / deletion from $($S)" begin
            set = $S{Int64}()
            N = 10_000
            vals = rand(Int64, 2N)

            for val in vals
                insert!(set, val)
            end

            @test length(set) == 2N
            @test collect(set) == sort(vals)
            invariant_tests(set)

            # Delete the first half of the elements from the vals array, and
            # simultaneously insert new elements into the array
            new_vals = rand(Int64, N)
            vals_to_delete = vals[1:N]

            insert_ops = zip(new_vals, repeated(:insert))
            delete_ops = zip(vals_to_delete, repeated(:delete))
            ops = cat(collect(insert_ops), collect(delete_ops); dims=1)

            success = true
            for (val, op) in ops
                if !success
                    break
                end

                if op == :insert
                    insert!(set, val)
                    success = val ∈ set
                else
                    delete!(set, val)
                    success = val ∉ set
                end
            end

            expected_vals = cat(vals[N+1:end], new_vals; dims=1)

            @test length(set) == 2N
            @test collect(set) == sort(expected_vals)
            @test success
            invariant_tests(set)
        end
    end
end

