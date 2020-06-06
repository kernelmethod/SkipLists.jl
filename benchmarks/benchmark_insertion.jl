#============================================

Benchmarks for insertion into Skiplist

============================================#

using BenchmarkTools
using Random
using Skiplists

function benchmark_insertion(::Type{Skiplist}; N = 10_000)
end

function benchmark_insertion(::Type{SkiplistSet})
end
