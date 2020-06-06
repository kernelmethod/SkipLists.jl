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
        tasks = []
        for ii = 0:2
            task = @spawn begin
                rng = MersenneTwister(ii)
                for jj = 10ii+1:10(ii+1)
                    insert!(list, jj)
                    sleep(0.1 * rand(rng))
                end
            end
            push!(tasks, task)
        end

        wait.(tasks)
        @test length(list) == 30
        @test vec(list) == collect(1:30)
    end

    @testset "Multithreaded delete from Skiplist" begin
        list = Skiplist{Int64}()

        # Insert 1, 2, ..., 40
        for ii = 1:40
            insert!(list, ii)
        end

        @test vec(list) == collect(1:40)

        # Delete all of the even numbers in separate threads
        to_delete = filter(iseven, shuffle(1:40))
        to_delete = partition(to_delete, 10)
        tasks = []
        for (ii, to_delete_partition) in enumerate(to_delete)
            rng = MersenneTwister(ii)
            task = @spawn begin
                for val in to_delete_partition
                    delete!(list, val)
                    sleep(0.1 * rand(rng))
                end
            end
            push!(tasks, task)
        end

        wait.(tasks)
        @test vec(list) == collect(1:2:40)
        @test length(list) == collect(1:2:40) |> length
    end
end

