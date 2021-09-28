# Delving into parsed DXF files.

export walk, dxffind

"""
    walk(action, object::DXFObject; path=[])
Recursively invoke action on `object and each of its components.
Path is a vector of the `DXFObjects` that contain `object` starting
with the subject of the outermost call to `walk`, and not including
object`itself.
Action is called with both `object` and `path` as arguments.  It's
return value is ignored.
"""
function walk end

WalkPathType = Vector{DXFObject}

function walk(action, o::Nothing; path=WalkPathType())
end

function walk(action, o::DXFGroup; path=WalkPathType())
    action(o, path)
end

function walk(action, o::DXFContentsObject; path=WalkPathType())
    action(o, path)
    for child in o
        walk(action, child; path=[path..., o])
    end
end

function walk(action, o::DocumentStart; path=WalkPathType())
    action(o, path)
end

function walk(action, o::HeaderVariable; path=WalkPathType())
    action(o, path)
    path = (path..., o)
    walk(action, o.name; path=path)
    walk(action, o.value; path=path)
end

function walk(action, o::DXFPoint; path=WalkPathType())
    action(o, path)
    path = (path..., o)
    walk(action, o.pointX; path=path)
    walk(action, o.pointY; path=path)
    walk(action, o.pointZ; path=path)
end



function dxffind(predicate, o::DXFObject)
    found = []
    walk(o) do o, path
        if predicate(o)
            push!(found, (path..., o))
        end
    end
    found
end
    
