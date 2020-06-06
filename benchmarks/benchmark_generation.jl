#============================================

Benchmarks for generating and performing initial insertions into
a Skiplist

============================================#

using BenchmarkTools
using Random
using Skiplists
using UUIDs

function generate_data(N)
    collect(uuid4() for ii = 1:N)
end

Base.zero(::Type{UUID}) = uuid4()

function benchmark_generate_vector(; N = 10_000, kws...)
    function gen_list(X::Vector{T}) where T
        list = Vector{T}(undef, 0)
        for ii in X
            insert_idx = searchsorted(list, ii)
            insert!(list, first(insert_idx), ii)
        end
    end
    @benchmark $gen_list(X) setup=(X = generate_data($N))
end

function benchmark_generate_skiplist(::Type{Skiplist}; N = 10_000, kws...)
    function gen_list(X::Vector{T}) where T
        list = Skiplist{T}(; kws...)
        for ii in X
            insert!(list, ii)
        end
    end
    @benchmark $gen_list(X) setup=(X = generate_data($N))
end
