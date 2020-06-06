#=======================================================

Tests for the Skiplist and SkiplistSet types

=======================================================#

using Random, Skiplists, Test

@testset "Skiplist tests" begin
    Random.seed!(0)

    @testset "Construct Skiplist" begin
        list = Skiplist{Int64}()
        @test height(list) == 1
        @test length(list) == 0

        # An error should be raised if we attempt to construct a Skiplist in an
        # invalid mode
        @test_throws ErrorException Skiplist{Int64,:Foo}()
    end

    @testset "Insert into Skiplist" begin
        # Insert sorted values
        list = Skiplist{Int64}()
        for ii = 1:20
            insert!(list, ii)
        end

        @test collect(list) == collect(1:20)
        @test length(list) == 20

        # Insert shuffled values
        list = Skiplist{Int64}()
        for ii in shuffle(1:20)
            insert!(list, ii)
        end

        @test collect(list) == collect(1:20)
        @test length(list) == 20

        # All of the nodes should be marked as 'fully linked'
        current_node = list.left_sentinel
        success = Skiplists.is_fully_linked(current_node)
        while success && !Skiplists.is_right_sentinel(current_node)
            current_node = Skiplists.next(current_node, 1)
            success = Skiplists.is_fully_linked(current_node)
        end

        @test success
    end

    @testset "Iterate over Skiplist" begin
        vals = shuffle(1:100)
        list = Skiplist{Int64}()
        for ii in vals
            insert!(list, ii)
        end

        success = true
        for (x1, x2) in zip(sort(vals), list)
            success = success && x1 == x2
        end

        @test success
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

    @testset "Add duplicate elements to Skiplist" begin
        list = Skiplist{Int64}()
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

@testset "SkiplistSet tests" begin
    @testset "Insert into SkiplistSet" begin
        set = SkiplistSet{Int64}()
        for ii = 1:10
            insert!(set, ii)
        end

        @test length(set) == 10
        @test collect(set) == 1:10

        # If we now try to insert a duplicate element into the set, it shouldn't
        # have any effect
        for ii = 1:10
            insert!(set, ii)
        end

        @test length(set) == 10
        @test collect(set) == 1:10
    end
end


