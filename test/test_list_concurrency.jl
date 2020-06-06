#=======================================================

Concurrency tests for the Skiplist type

=======================================================#

using Random, Skiplists, Test
using Base.Iterators: partition
using Base.Threads: @spawn

@testset "SkiplistNode concurrency tests" begin
    Random.seed!(0)

    @testset "Multithreaded insert into Skiplist" begin
        list = Skiplist{Int64}()
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

        vl = vec(list)
        @test length(vl) == length(orig)

        success = (vl .== sort(orig))
        if !all(success)
            @error "Failed Skiplist insertion tests"
            @error "vec(list) != sort(orig) in the following indices: $(eachindex(vl)[success])"
        end

        @test all(success)
    end

    @testset "Multithreaded delete from Skiplist" begin
        list = Skiplist{Int64}()

        orig = collect(1:5000)
        for ii in orig
            insert!(list, ii)
        end

        @test vec(list) == orig

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
        @test vec(list) == filter(isodd, orig)
        @test length(list) == filter(isodd, orig) |> length
    end

    @testset "Multithreaded inserts / deletes in Skiplist" begin
        # Pre-populate the Skiplist
        list = Skiplist{Int64}()

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
        @test vec(list) == expected
    end
end



