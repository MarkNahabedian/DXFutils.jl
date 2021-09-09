
export DXFSection, sectionize, DXFSection, section, sectiontype

struct DXFSection
    contents::Vector
end

function Base.summary(io::IO, section::DXFSection)
    println("$(typeof(section)) $(sectiontype(section)) with $(length(section.contents)) elements")
end

function sectiontype(sec::DXFSection)
    if sec.contents[2] isa Name
        sec.contents[2].value
    else
        nothing
    end
end

function sectionize(groups::Vector{DXFGroup})
    sections = []
    start = nothing
    for (num, group) in enumerate(groups)
        @assert group isa DXFGroup
        if groupmatch(group, EntityType("EOF"))
            break
        end
        if start == nothing
            @assert groupmatch(group, EntityType("SECTION"))
            start = num
        end
        if groupmatch(group, EntityType("ENDSEC"))
            push!(sections, DXFSection(groups[start:num]))
            start = nothing
        end
    end
    sections
end
