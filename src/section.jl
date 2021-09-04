
export DXFSection, sectionize, DXFSection

struct DXFSection
    groups::Vector
end

function Base.summary(io::IO, section::DXFSection)
    println("$(typeof(section)) with #(length(section.groups)) elements")
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
