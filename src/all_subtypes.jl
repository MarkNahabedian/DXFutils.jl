
using InteractiveUtils

function allsubtypes(t::Type, result=Set())
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

