using Pkg

Pkg.activate(joinpath(@__DIR__, "..")); Pkg.instantiate()
Pkg.activate(); Pkg.instantiate();

pushfirst!(LOAD_PATH, joinpath(@__DIR__, ".."))

using Documenter
using Skiplists

makedocs(
    sitename = "Skiplists",
    format = Documenter.HTML(),
    modules = [Skiplists]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(
    repo = "github.com/kernelmethod/Skiplists.jl.git"
)
