using Documenter, Logging, SkipLists, Test
using Base.Threads: nthreads

@info "Running tests with $(nthreads()) threads"

include("list_test_utils.jl")

include("test_node_nonconcurrent.jl")
include("test_node_concurrent.jl")
include("test_list_nonconcurrent.jl")
include("test_list_concurrent.jl")

# Doctests

@testset "SkipLists doctests" begin
    doctest(SkipLists)
end
