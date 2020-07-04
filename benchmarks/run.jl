using Pkg

Pkg.activate(joinpath(@__DIR__, "..")); Pkg.instantiate()
Pkg.activate(); Pkg.instantiate();

pushfirst!(LOAD_PATH, joinpath(@__DIR__, ".."))

using SkipLists
using BenchmarkTools

# Run all benchmarks for the module that are contained in this directory

include("benchmark_generation.jl")
display(benchmark_generate_vector())
display(benchmark_generate_skiplist(SkipList))
