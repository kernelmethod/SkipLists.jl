#=======================================================

Tests for the Node type

=======================================================#

using Random, SkipLists, Test
using SkipLists: Node, LeftSentinel, RightSentinel

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

    @testset "Compare nodes" begin
        lsentinel = LeftSentinel{Int64,:List}()
        rsentinel = RightSentinel{Int64,:List}()
        node_1 = Node{Int64}([0])
        node_2 = Node{Int64}(1:10)

        @test lsentinel < node_1     && lsentinel ≤ node_1
        @test node_1 < node_2        && node_1 ≤ node_2
        @test node_2 < rsentinel     && node_2 ≤ rsentinel
        @test lsentinel < rsentinel  && lsentinel ≤ rsentinel
        @test lsentinel ≤ lsentinel && !(lsentinel < lsentinel)
        @test rsentinel ≤ rsentinel && !(rsentinel < rsentinel)

        @test 0 == node_1 == Node{Int64}(0:5:10) == 0
        @test 1 == node_2 == Node{Int64}([1]) == 1
    end
end

