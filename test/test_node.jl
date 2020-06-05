#=======================================================

Tests for the SkiplistNode type

=======================================================#

using Skiplists, Test
using Skiplists: SkiplistNode, LeftSentinel, RightSentinel

@testset "SkiplistNode tests" begin
    @testset "Construct SkiplistNode" begin
        node = SkiplistNode(1)
        @test isa(node, SkiplistNode{Int64})
        @test height(node) > 0

        left_sentinel = LeftSentinel{Int64}()
        right_sentinel = RightSentinel{Int64}()
        @test isa(left_sentinel, SkiplistNode{Int64})
        @test isa(right_sentinel, SkiplistNode{Int64})
        @test Skiplists.is_sentinel(left_sentinel) && Skiplists.is_left_sentinel(left_sentinel)
        @test Skiplists.is_sentinel(right_sentinel) && Skiplists.is_right_sentinel(right_sentinel)
    end

    @testset "Compare SkiplistNode pairs" begin
        node_1 = SkiplistNode(typemin(Int64))
        node_2 = SkiplistNode(-1)
        node_3 = SkiplistNode(1)
        node_4 = SkiplistNode(typemax(Int64))
        left_sentinel = LeftSentinel{Int64}()
        right_sentinel = RightSentinel{Int64}()

        @test left_sentinel ≤ node_1 && !(node_1 ≤ left_sentinel)
        @test node_1 ≤ node_2 && !(node_2 ≤ node_1)
        @test node_2 ≤ node_3 && !(node_3 ≤ node_2)
        @test node_3 ≤ node_4 && !(node_4 ≤ node_3)
        @test node_4 ≤ right_sentinel && !(right_sentinel ≤ node_4)
    end

    @testset "Link SkiplistNodes" begin
        node_1 = SkiplistNode(0)
        node_2 = SkiplistNode(1)

        Skiplists.link_nodes!(node_1, node_2, 1)
        @test Skiplists.next(node_1, 1) == node_2
    end
end
