#=======================================================

Tests for the ConcurrentSkipList and ConcurrentSkipListSet types

=======================================================#

using Random, SkipLists, Test
using Base.Iterators: partition
using Base.Threads: @spawn

@testset "ConcurrentSkipList tests" begin
    Random.seed!(0)

    @testset "Construct ConcurrentSkipList" begin
        list = ConcurrentSkipList{Int64}()
        @test height(list) == 1
        @test length(list) == 0

        # An error should be raised if we attempt to construct a skip list in an
        # invalid mode
        @test_throws ErrorException ConcurrentSkipList{Int64,:Foo}()
    end

    @testset "Insert into ConcurrentSkipList" begin
        # Insert sorted values
        list = ConcurrentSkipList{Int64}()
        for ii = 1:20
            insert!(list, ii)
        end

        @test collect(list) == collect(1:20)
        @test length(list) == 20

        # Insert shuffled values
        list = ConcurrentSkipList{Int64}()
        for ii in shuffle(1:20)
            insert!(list, ii)
        end

        @test collect(list) == collect(1:20)
        @test length(list) == 20

        # All of the nodes should be marked as 'fully linked'
        current_node = list.left_sentinel
        success = SkipLists.is_fully_linked(current_node)
        while success && !SkipLists.is_right_sentinel(current_node)
            current_node = SkipLists.next(current_node, 1)
            success = SkipLists.is_fully_linked(current_node)
        end

        @test success
    end

    @testset "Iterate over ConcurrentSkipList" begin
        vals = shuffle(1:100)
        list = ConcurrentSkipList{Int64}()
        for ii in vals
            insert!(list, ii)
        end

        success = true
        for (x1, x2) in zip(sort(vals), list)
            success = success && x1 == x2
        end

        @test success
    end

    @testset "Test membership in ConcurrentSkipList" begin
        list = ConcurrentSkipList{Int64}()
        @test 1 ∉ list

        insert!(list, 1)
        @test 1 ∈ list
    end

    @testset "Remove from ConcurrentSkipList" begin
        list = ConcurrentSkipList{Int64}()
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

    @testset "Add duplicate elements to ConcurrentSkipList" begin
        list = ConcurrentSkipList{Int64}()
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

@testset "ConcurrentSkipListSet tests" begin
    Random.seed!(0)

    @testset "Insert into ConcurrentSkipListSet" begin
        set = ConcurrentSkipListSet{Int64}()
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

    @testset "Remove from ConcurrentSkipListSet" begin
        set = ConcurrentSkipListSet{Int64}()
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

    @testset "Mixed insertion / deletion from ConcurrentSkipListSet" begin
        set = ConcurrentSkipListSet{Int64}()
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

@testset "ConcurrentSkipList concurrency tests" begin
    Random.seed!(0)

    @testset "Multithreaded insert into ConcurrentSkipList" begin
        list = ConcurrentSkipList{Int64}()
        orig = collect(1:5000)
        to_insert = orig |> copy |> shuffle
        to_insert = partition(to_insert, 10)

        tasks = []
        for (ii, to_insert_partition) in enumerate(to_insert)
            task = @spawn begin
                rng = MersenneTwister(ii)
                for val in to_insert_partition
                    insert!(list, val)
                    sleep(0.05 * rand(rng))
                end
            end
            push!(tasks, task)
        end

        wait.(tasks)
        @test length(list) == length(orig)

        vl = collect(list)
        @test length(vl) == length(orig)

        success = (vl .== sort(orig))
        if !all(success)
            @error "Failed ConcurrentSkipList insertion tests"
            @error "collect(list) != sort(orig) in the following indices: $(eachindex(vl)[success])"
        end

        @test all(success)
    end

    @testset "Multithreaded delete from ConcurrentSkipList" begin
        list = ConcurrentSkipList{Int64}()

        orig = collect(1:5000)
        for ii in orig
            insert!(list, ii)
        end

        @test collect(list) == orig

        # Delete all of the even numbers in separate threads
        to_delete = filter(iseven, shuffle(orig))
        to_delete = partition(to_delete, 10)
        tasks = []
        for (ii, to_delete_partition) in enumerate(to_delete)
            task = @spawn begin
                rng = MersenneTwister(ii)
                for val in to_delete_partition
                    delete!(list, val)
                    sleep(0.05 * rand(rng))
                end
            end
            push!(tasks, task)
        end

        wait.(tasks)
        @test collect(list) == filter(isodd, orig)
        @test length(list) == filter(isodd, orig) |> length
    end

    @testset "Multithreaded inserts / deletes in ConcurrentSkipList" begin
        # Pre-populate the skip list
        list = ConcurrentSkipList{Int64}()

        orig = collect(1:5000)
        for ii in orig
            insert!(list, ii)
        end

        # Now we're going to insert some new numbers into the list. Meanwhile, we'll
        # remove all of the even numbers in orig
        to_insert = collect((:insert, ii) for ii = 5001:10000)
        to_delete = collect((:delete, ii) for ii in filter(iseven, orig))
        expected = cat(5001:10000, filter(isodd, orig); dims=1) |> sort
        ops = cat(to_insert, to_delete; dims=1) |> shuffle
        ops = partition(ops, 10)

        tasks = []
        for (ii, ops_partition) in enumerate(ops)
            task = @spawn begin
                rng = MersenneTwister(ii)
                for (op, val) in ops_partition
                    if op == :insert
                        insert!(list, val)
                    else
                        delete!(list, val)
                    end
                    sleep(rand(rng) * 0.025)
                end
            end
            push!(tasks, task)
        end

        wait.(tasks)
        @test length(list) == length(expected)
        @test collect(list) == expected
    end
end

