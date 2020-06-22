#=======================================================

Tests for the ConcurrentNode type

=======================================================#

using Random, SkipLists, Test
using SkipLists: Node, LeftSentinel, RightSentinel
using SkipLists: ConcurrentNode, ConcurrentLeftSentinel, ConcurrentRightSentinel

@testset "Node tests" begin
    Random.seed!(0)

    @testset "Construct Node" begin
        node = Node{:List}([1, 2, 3]; capacity=10)
        @test isa(node, Node{Int64,:List})
        @test height(node) > 0
        @test SkipLists.key(node) == 1
        @test SkipLists.capacity(node) == 10
        @test 1 ∈ node && 2 ∈ node && 3 ∈ node

        # If the node doesn't have any items in it, isempty(node) should be
        # true
        node = Node{:List}([]; capacity=10)
        @test isempty(node)

        # Construct left and right sentinel nodes
        lsentinel = SkipLists.LeftSentinel{Int64,:List}()
        rsentinel = SkipLists.RightSentinel{Int64,:List}()
        @test SkipLists.is_left_sentinel(lsentinel)
        @test SkipLists.is_right_sentinel(rsentinel)
    end

    @testset "Insert and delete from Node" begin
        node = Node{:List}(1:2:50; capacity=100)

        success = true
        for ii = shuffle(2:2:50)
            insert!(node, ii)
            success = success && ii ∈ node
        end
        @test success

        success = true
        for ii = shuffle(1:2:50)
            delete!(node, ii)
            success = success && ii ∉ node
        end
        @test success

        # If we attempt to insert into a node past its capacity, we should
        # get an error
        node = Node{:List}(1:10; capacity=10)
        @test SkipLists.isfull(node)
        @test_throws ErrorException insert!(node, 11)
    end

    @testset "Split Node" begin
        node = Node{:List}(1:10)

        node, right_node = SkipLists.split!(node; capacity=25)
        @test node.vals == 1:5
        @test right_node.vals == 6:10
        @test SkipLists.capacity(right_node) == 25
    end
end

@testset "ConcurrentNode tests" begin
    Random.seed!(0)

    @testset "Construct ConcurrentNode" begin
        node = ConcurrentNode{:List}(1)
        @test isa(node, ConcurrentNode{Int64,:List})
        @test height(node) > 0
        @test SkipLists.key(node) == 1

        left_sentinel = ConcurrentLeftSentinel{Int64,:List}()
        right_sentinel = ConcurrentRightSentinel{Int64,:List}()
        @test isa(left_sentinel, ConcurrentNode{Int64,:List})
        @test isa(right_sentinel, ConcurrentNode{Int64,:List})
        @test SkipLists.is_sentinel(left_sentinel) && SkipLists.is_left_sentinel(left_sentinel)
        @test SkipLists.is_sentinel(right_sentinel) && SkipLists.is_right_sentinel(right_sentinel)
        @test SkipLists.height(left_sentinel) == SkipLists.DEFAULT_MAX_HEIGHT
        @test SkipLists.height(right_sentinel) == SkipLists.DEFAULT_MAX_HEIGHT

        # A newly constructed ConcurrentNode should not be fully linked, nor
        # should it be marked.
        @test !SkipLists.is_marked_for_deletion(node)
        @test !SkipLists.is_fully_linked(node)

        # If two integers are passed to the ConcurrentNode constructor, the second
        # integer should be used as the node's height.
        @test ConcurrentNode{:List}(1, 30) |> height == 30
        @test ConcurrentNode{:List}(1, 100; max_height=50) |> height == 50

        # Newly constructed sentinels should be marked as fully linked
        @test SkipLists.is_fully_linked(left_sentinel)
        @test SkipLists.is_fully_linked(right_sentinel)
    end

    @testset "Compare ConcurrentNode pairs" begin
        node_1 = ConcurrentNode{:List}(typemin(Int64))
        node_2 = ConcurrentNode{:List}(-1)
        node_3 = ConcurrentNode{:List}(1)
        node_4 = ConcurrentNode{:List}(typemax(Int64))
        left_sentinel = ConcurrentLeftSentinel{Int64,:List}()
        right_sentinel = ConcurrentRightSentinel{Int64,:List}()

        @test left_sentinel ≤ node_1 && !(node_1 ≤ left_sentinel)
        @test node_1 ≤ node_2 && !(node_2 ≤ node_1)
        @test node_2 ≤ node_3 && !(node_3 ≤ node_2)
        @test node_3 ≤ node_4 && !(node_4 ≤ node_3)
        @test node_4 ≤ right_sentinel && !(right_sentinel ≤ node_4)
    end

    @testset "Link ConcurrentNodes" begin
        node_1 = ConcurrentNode{:List}(0)
        node_2 = ConcurrentNode{:List}(1)

        SkipLists.link_nodes!(node_1, node_2, 1)
        @test SkipLists.next(node_1, 1) == node_2
    end

    @testset "Check ConcurrentNode deletability" begin
        node = ConcurrentNode{:List}(1)
    end
end
