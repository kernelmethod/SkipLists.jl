#============================================

Profiling for Skiplist generation.

============================================#

pushfirst!(LOAD_PATH, joinpath(@__DIR__, ".."))

using Logging
using Profile
using Random
using SkipLists

Profile.init(; delay=1e-4)

const OUTPUT_PATH = joinpath("results", "profile_generation.txt")
const N = 1_000_000

# Pre-compile code
list = SkipList{Int64}()
for ii = 1:100
    insert!(list, 0)
end

Profile.clear_malloc_data()

# Perform profiling
for ii = 1:5
    @info "Iteration $ii"
    list = SkipList{Int64}()
    for jj = shuffle(1:N)
        @profile insert!(list, jj)
    end
end

open(OUTPUT_PATH, "w") do f
    for outfile in (f, stdout)
        Profile.print(IOContext(outfile, :displaysize => (24,500)); maxdepth=40)
    end
end

println("Output written to $OUTPUT_PATH")
