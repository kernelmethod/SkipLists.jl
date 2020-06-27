using Base.Threads: nthreads
using Logging

@info "Running tests with $(nthreads()) threads"

include("test_node_nonconcurrent.jl")
include("test_node_concurrent.jl")
include("test_list_nonconcurrent.jl")
include("test_list_concurrent.jl")
