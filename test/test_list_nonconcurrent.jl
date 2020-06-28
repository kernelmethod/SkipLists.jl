#=======================================================

Tests for the ConcurrentSkipList and ConcurrentSkipListSet types

=======================================================#

using Random, SkipLists, Test
using Base.Iterators: repeated

@testset "SkipList tests" begin
    Random.seed!(0)

    test_construct_list(SkipList)
    test_insert_into_list(SkipList)
    test_iterate_over_list(SkipList)
    test_list_membership(SkipList)
    test_add_duplicate_elements_to_list(SkipList)
    test_delete_from_list(SkipList)
end

@testset "SkiplistSet tests" begin
    Random.seed!(0)

    test_insert_into_skip_list_set(SkipListSet)
    test_delete_from_skip_list_set(SkipListSet)
    test_mixed_insert_delete_from_skip_list_set(SkipListSet)
end


