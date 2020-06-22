using Pkg

Pkg.activate(joinpath(@__DIR__, "..")); Pkg.instantiate()
Pkg.activate(); Pkg.instantiate();

pushfirst!(LOAD_PATH, joinpath(@__DIR__, ".."))

using Documenter
using SkipLists

makedocs(
    sitename = "SkipLists",
    format = Documenter.HTML(),
    modules = [SkipLists]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(
    repo = "github.com/kernelmethod/SkipLists.jl.git"
)
