using Pkg

Pkg.activate(joinpath(@__DIR__, "..")); Pkg.instantiate()
Pkg.activate(); Pkg.instantiate();

pushfirst!(LOAD_PATH, joinpath(@__DIR__, ".."))

using Skiplists
using BenchmarkTools

# Run all benchmarks for Skiplists contained in this directory

include("benchmark_generation.jl")
display(benchmark_generate_vector())
display(benchmark_generate_skiplist(ConcurrentSkiplist))

# include("benchmark_insertion.jl")
# benchmark_insertion(Skiplist)
# benchmark_insertion(SkiplistSet)
