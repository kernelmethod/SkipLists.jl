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

    @testset "Test membership in Skiplist" begin
        list = Skiplist{Int64}()
        @test 1 ∉ list

        insert!(list, 1)
        @test 1 ∈ list
    end

    @testset "Remove from Skiplist" begin
        list = Skiplist{Int64}()
        insert!(list, 1)
        insert!(list, 2)
        insert!(list, 3)

        delete!(list, 1)
        @test length(list) == 2
        @test 1 ∉ list
        @test vec(list) == collect(2:3)

        delete!(list, 2)
        @test length(list) == 1
        @test 2 ∉ list
        @test vec(list) == collect(3:3)

        delete!(list, 3)
        @test length(list) == 0
        @test 3 ∉ list

        delete!(list, 0)
        @test vec(list) == []
        @test length(list) == 0
    end
end
