
using InteractiveUtils

export allsubtypes, showsubtypes, pedigree

function allsubtypes(t::Type, result=Vector{Type}())
    push!(result, t)
    for st in subtypes(t)
	allsubtypes(st, result)
    end
    return result
end

function showsubtypes(t::Type, level=0)
    indent1 = "  "
    println("$(repeat(indent1, level))$t")
    for st in subtypes(t)
        showsubtypes(st, level + 1)
    end
end

function pedigree(t::Type, result=Vector{Type}())
    push!(result, t)
    if supertype(t) != t
        pedigree(supertype(t), result)
    end
    result
end

