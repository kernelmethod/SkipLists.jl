#=======================================================

Tests for the ConcurrentSkipList and ConcurrentSkipListSet types

=======================================================#

using Logging, Random, SkipLists, Test, Base.Threads
using Base.Iterators: partition
using Base.Threads: Atomic, @spawn

@testset "ConcurrentSkipList tests" begin
    Random.seed!(0)

    test_construct_list(ConcurrentSkipList)
    test_insert_into_list(ConcurrentSkipList)
    test_iterate_over_list(ConcurrentSkipList)
    test_list_membership(ConcurrentSkipList)
    test_add_duplicate_elements_to_list(ConcurrentSkipList)
    test_delete_from_list(ConcurrentSkipList)
end

@testset "ConcurrentSkipListSet tests" begin
    Random.seed!(0)

    test_insert_into_skip_list_set(ConcurrentSkipListSet)
    test_delete_from_skip_list_set(ConcurrentSkipListSet)
    test_mixed_insert_delete_from_skip_list_set(ConcurrentSkipListSet)
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

    for list_type in (:ConcurrentSkipList, :ConcurrentSkipListSet)
        @eval @testset "Random inserts / deletes into $($list_type)" begin
            @info "Running mixed insert/delete tests for $($list_type)"

            # Randomly insert and delete elements from the skip list from a
            # fixed collection consisting of the numbers 1, 2, ..., N
            list = $list_type{Int64}()
            M = 1000
            N_ITERS = 10_000
            N_THREADS = 10

            counts = [Atomic{Int64}(0) for ii = 1:M]

            tasks = []
            for ii = 1:N_THREADS
                task = @spawn begin
                    rng = MersenneTwister(ii)
                    for jj = 1:N_ITERS
                        if rand(rng) ≤ 0.5
                            # Insert a random element from the `vals` array into the list
                            val = rand(rng, 1:M)
                            if insert!(list, val) != nothing
                                atomic_add!(counts[val], 1)
                            end
                        else
                            # Delete a random element from the `vals` array
                            val = rand(rng, 1:M)
                            if delete!(list, val) != nothing
                                atomic_sub!(counts[val], 1)
                            end
                        end
                    end
                end
                push!(tasks, task)
            end

            # Wait for all the tasks to complete, and then check that the set is in
            # the correct final state based on the in_set array
            wait.(tasks)

            @info "Final list length: $(length(list))"

            $(
                if list_type == :ConcurrentSkipList
                    :(@test all(x[] ≥ 0 for x in counts))
                else
                    :(@test all(x[] ∈ (0,1) for x in counts))
                end
            )

            expected_length = sum(x[] for x in counts)
            @test length(list) == expected_length

            success = true
            for (ii, x) in enumerate(counts)
                if x[] > 0
                    success = success && (ii ∈ list)
                end
            end
            @test success
        end
    end
end



