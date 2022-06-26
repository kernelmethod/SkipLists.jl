using Documenter
using SkipLists

DocMeta.setdocmeta!(SkipLists, :DocTestSetup, :(using SkipLists); recursive=true)

makedocs(;
    modules=[SkipLists],
    authors="kernelmethod <17100608+kernelmethod@users.noreply.github.com> and contributors",
    repo="https://github.com/kernelmethod/SkipLists.jl/blob/{commit}{path}#{line}",
    sitename="SkipLists.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://kernelmethod.github.io/SkipLists.jl",
        assets=String[],
    ),
)

deploydocs(
    repo = "github.com/kernelmethod/SkipLists.jl.git",
    devbranch="main",
)
