#============================================

Profiling for Skiplist generation.

============================================#

pushfirst!(LOAD_PATH, joinpath(@__DIR__, ".."))

using Profile
using Random
using Skiplists

Profile.init(; delay=0.0025)

const OUTPUT_PATH = joinpath("results", "profile_generation.txt")
const N = 1_000_000

list = Skiplist{Int64}()
Profile.clear_malloc_data()

for ii = shuffle(1:N)
    @profile insert!(list, ii)
end

open(OUTPUT_PATH, "w") do f
    Profile.print(IOContext(f, :displaysize => (24,500)); maxdepth=40)
end

println("Output written to $OUTPUT_PATH")
