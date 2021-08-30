
export DXFSection, sectionize

struct DXFSection
    groups::Vector{DXFGroup}
end

function sectionize(groups)
    sections = []
    start = nothing
    for (num, group) in enumerate(groups)
        @assert group isa DXFGroup
        if group == EntityType("EOF")
            break
        end
        if start == nothing
            @assert group == EntityType("SECTION")
            start = num
        end
        if group == EntityType("ENDSEC")
            push!(sections, DXFSection(groups[start:num]))
            start = nothing
        end
    end
    sections
end
