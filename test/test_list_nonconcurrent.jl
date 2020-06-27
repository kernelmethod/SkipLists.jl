#=======================================================

Tests for the ConcurrentSkipList and ConcurrentSkipListSet types

=======================================================#

using Random, SkipLists, Test
using Base.Iterators: repeated

@testset "SkipList tests" begin
    Random.seed!(0)

    @testset "Construct SkipList" begin
        list = SkipList{Int64}()
        @test height(list) == 1
        @test length(list) == 0

        # An error should be raised if we attempt to construct a skip list in an
        # invalid mode
        @test_throws ErrorException SkipList{Int64,:Foo}()
    end

    @testset "Insert into SkipList" begin
        # Insert sorted values
        list = SkipList{Int64}()
        insert!(list, 1)

        @test collect(list) == [1]

        for ii = 2:20
            insert!(list, ii)
        end

        @test length(list) == 20
        @test isa(collect(list), Vector{Int64})
        @test collect(list) == collect(1:20)

        # SkipList should accept duplicate values when its mode is :List. When
        # the mode is :Set, it will only be able to accept a single version
        # of a given value.
        insert!(list, 1)

        @test length(list) == 21
        @test collect(list) == cat([1], 1:20; dims=1)

        # Insert shuffled values
        list = SkipList{Int64}()
        for ii in shuffle(1:20)
            insert!(list, ii)
        end

        @test collect(list) == collect(1:20)
        @test length(list) == 20
    end

    @testset "Iterate over SkipList" begin
        vals = shuffle(1:100)
        list = SkipList{Int64}()
        for ii in vals
            insert!(list, ii)
        end

        success = true
        for (x1, x2) in zip(sort(vals), list)
            success = success && x1 == x2
        end

        @test success
    end

    @testset "Test membership in SkipList" begin
        list = SkipList{Int64}()
        @test 1 ∉ list

        insert!(list, 1)
        @test 1 ∈ list
    end

    @testset "Remove from SkipList" begin
        list = SkipList{Int64}()
        insert!(list, 1)
        insert!(list, 2)
        insert!(list, 3)

        delete!(list, 1)
        @test length(list) == 2
        @test 1 ∉ list
        @test collect(list) == collect(2:3)

        delete!(list, 2)
        @test length(list) == 1
        @test 2 ∉ list
        @test collect(list) == collect(3:3)

        delete!(list, 3)
        @test length(list) == 0
        @test 3 ∉ list

        delete!(list, 0)
        @test collect(list) == []
        @test length(list) == 0
    end
end

@testset "SkiplistSet tests" begin
    Random.seed!(0)

    @testset "Insert into SkipListSet" begin
        set = SkipListSet{Int64}()
        for ii = 1:10
            insert!(set, ii)
        end

        @test length(set) == 10
        @test collect(set) == 1:10

        # If we now try to insert a duplicate element into the set, it shouldn't
        # have any effect
        for ii = shuffle(1:10)
            insert!(set, ii)
        end

        @test length(set) == 10
        @test collect(set) == 1:10
    end

    @testset "Remove from SkipListSet" begin
        set = SkipListSet{Int64}()
        orig = 1:100

        for ii in shuffle(orig)
            # Insert every element twice
            insert!(set, ii)
            insert!(set, ii)
        end

        @test length(set) == length(orig)
        @test collect(set) == sort(orig)

        # Remove all of the even elements
        to_remove = filter(iseven, orig)
        remaining = filter(isodd, orig) |> sort
        for ii in shuffle(to_remove)
            delete!(set, ii)
            delete!(set, ii)
        end

        @test length(set) == length(remaining)
        @test collect(set) == remaining

        # Test membership of remaining elements
        success = true
        for ii in remaining
            success = success && ii ∈ set
        end
        @test success
    end

    @testset "Mixed insertion / deletion from SkipListSet" begin
        set = SkipListSet{Int64}()
        N = 10_000
        vals = rand(Int64, 2N)

        for val in vals
            insert!(set, val)
        end

        @test length(set) == 2N
        @test collect(set) == sort(vals)

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
    end
end


