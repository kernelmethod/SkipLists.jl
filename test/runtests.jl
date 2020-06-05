using Base.Threads: nthreads
using Logging

@info "Running tests with $(nthreads()) threads"

include("test_node.jl")
include("test_list.jl")
