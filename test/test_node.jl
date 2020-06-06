#=======================================================

Tests for the SkiplistNode type

=======================================================#

using Random, Skiplists, Test
using Skiplists: SkiplistNode, LeftSentinel, RightSentinel

@testset "SkiplistNode tests" begin
    Random.seed!(0)

    @testset "Construct SkiplistNode" begin
        node = SkiplistNode{:List}(1)
        @test isa(node, SkiplistNode{Int64,:List})
        @test height(node) > 0
        @test Skiplists.key(node) == 1

        left_sentinel = LeftSentinel{Int64,:List}()
        right_sentinel = RightSentinel{Int64,:List}()
        @test isa(left_sentinel, SkiplistNode{Int64,:List})
        @test isa(right_sentinel, SkiplistNode{Int64,:List})
        @test Skiplists.is_sentinel(left_sentinel) && Skiplists.is_left_sentinel(left_sentinel)
        @test Skiplists.is_sentinel(right_sentinel) && Skiplists.is_right_sentinel(right_sentinel)
        @test Skiplists.height(left_sentinel) == Skiplists.DEFAULT_MAX_HEIGHT
        @test Skiplists.height(right_sentinel) == Skiplists.DEFAULT_MAX_HEIGHT

        # A newly constructed SkiplistNode should not be fully linked, nor
        # should it be marked.
        @test !Skiplists.is_marked_for_deletion(node)
        @test !Skiplists.is_fully_linked(node)

        # If two integers are passed to the SkiplistNode constructor, the second
        # integer should be used as the node's height.
        @test SkiplistNode{:List}(1, 30) |> height == 30
        @test SkiplistNode{:List}(1, 100; max_height=50) |> height == 50
    end

    @testset "Compare SkiplistNode pairs" begin
        node_1 = SkiplistNode{:List}(typemin(Int64))
        node_2 = SkiplistNode{:List}(-1)
        node_3 = SkiplistNode{:List}(1)
        node_4 = SkiplistNode{:List}(typemax(Int64))
        left_sentinel = LeftSentinel{Int64,:List}()
        right_sentinel = RightSentinel{Int64,:List}()

        @test left_sentinel ≤ node_1 && !(node_1 ≤ left_sentinel)
        @test node_1 ≤ node_2 && !(node_2 ≤ node_1)
        @test node_2 ≤ node_3 && !(node_3 ≤ node_2)
        @test node_3 ≤ node_4 && !(node_4 ≤ node_3)
        @test node_4 ≤ right_sentinel && !(right_sentinel ≤ node_4)
    end

    @testset "Link SkiplistNodes" begin
        node_1 = SkiplistNode{:List}(0)
        node_2 = SkiplistNode{:List}(1)

        Skiplists.link_nodes!(node_1, node_2, 1)
        @test Skiplists.next(node_1, 1) == node_2
    end

    @testset "Check SkiplistNode deletability" begin
        node = SkiplistNode{:List}(1)
    end
end
