#=======================================================

Concurrency tests for the Skiplist type

=======================================================#

using Skiplists, Test
using Base.Threads: @spawn

@testset "SkiplistNode concurrency tests" begin
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
end
