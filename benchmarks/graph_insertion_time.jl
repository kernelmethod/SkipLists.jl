#============================================

Graph the amount of time required to insert a new element into
a Skiplist.

============================================#

pushfirst!(LOAD_PATH, joinpath(@__DIR__, ".."))

using BenchmarkTools
using Logging
using PyPlot
using Skiplists

pygui(true)

list_sizes = (100_000, 120_000, 140_000, 160_000)

# Helper functions

function generate_list(N)
    list = ConcurrentSkiplist{Int64}()
    for ii = 1:N
        insert!(list, ii)
    end
    list
end

randint(N) = abs(mod(rand(Int64), N))

# Plotting script

results = []

for N in list_sizes
    push!(results, @benchmark(
        insert!(list, ii),
        setup=(list = generate_list($N); ii = randint($N);),
        seconds=10,
       ))
    @info "Obtained benchmarks for N = $N"
end

@info "Benchmarks completed"

rcParams = PyPlot.PyDict(PyPlot.matplotlib."rcParams")
rcParams["font.size"] = 15

times = [median(r.times) for r in results]
plot(list_sizes, times)
xlabel("List size")
ylabel("Insertion time (μs)")
show()



