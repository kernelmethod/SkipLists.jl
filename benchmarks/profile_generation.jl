#============================================

Profiling for Skiplist generation.

============================================#

pushfirst!(LOAD_PATH, joinpath(@__DIR__, ".."))

using Profile
using Random
using SkipLists

Profile.init(; delay=0.001)

const OUTPUT_PATH = joinpath("results", "profile_generation.txt")
const N = 1_000_000

Profile.clear_malloc_data()

for ii = 1:5
    list = SkipList{Int64}()
    for jj = shuffle(1:N)
        @profile insert!(list, jj)
    end
end

open(OUTPUT_PATH, "w") do f
    Profile.print(IOContext(f, :displaysize => (24,500)); maxdepth=40)
end

println("Output written to $OUTPUT_PATH")
