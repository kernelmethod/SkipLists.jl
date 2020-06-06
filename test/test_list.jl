#=======================================================

Tests for the Skiplist type

=======================================================#

using Random, Skiplists, Test

@testset "Skiplist tests" begin
    Random.seed!(0)

    @testset "Construct Skiplist" begin
        list = Skiplist{Int64}()
        @test height(list) == 1
        @test length(list) == 0
    end

    @testset "Insert into Skiplist" begin
        # Insert sorted values
        list = Skiplist{Int64}()
        for ii = 1:20
            insert!(list, ii)
        end

        @test vec(list) == collect(1:20)
        @test length(list) == 20

        # Insert shuffled values
        list = Skiplist{Int64}()
        for ii in shuffle(1:20)
            insert!(list, ii)
        end

        @test vec(list) == collect(1:20)
        @test length(list) == 20
    end
end
