
export groupcode, read_value
export groupcode, groupmatch
export  DXFObject, DXFGroup, RawGroup, StringGroup, IntegerGroup,
    FloatGroup, PointX, PointY, PointZ

abstract type DXFObject end
abstract type DXFGroup <: DXFObject end

DXFGroupCode = Int32

group_code_registry = SortedDict{DXFGroupCode, Type{<:DXFGroup}}()

function show_group_code_registry(io::IO)
    for (key, value) in group_code_registry
        @printf(io, "%4d\t%s\n", key,
                join(pedigree(value), " <: "))
    end
end

function groupmatch(a::DXFGroup, b::DXFGroup)
    groupcode(a) == groupcode(b) && a.value == b.value
end


function defDXFGroup_(group_supertype::Type, code::Integer, name=nothing)
    defDXFGroup_(group_supertype, DXFGroupCode(code), name)
end

function defDXFGroup_(group_supertype::Type, code::DXFGroupCode, name=nothing)
    @assert group_supertype <: DXFGroup
    if name == nothing
        name = Symbol("Group_$code")
    end
    definitions = quote
        struct $name <: $group_supertype
            line::Int
            value::$(valuetype(group_supertype))
        end
        function $name(value::$(valuetype(group_supertype)))
            $name(-1, value)
        end
        if !haskey(group_code_registry, $code)
            group_code_registry[$code] = $name
        end
        function groupcode(::$name)::DXFGroupCode
            return $code
        end
        function groupcode(::Type{$name})::DXFGroupCode
            return $code
        end
        export $name
    end
    return name, definitions
end

function defDXFGroup(group_supertype::Type, code::Integer, name=nothing)
    name, defs = defDXFGroup_(group_supertype, code, name)
    eval(defs)
    eval(name)
end

abstract type RawGroup <: DXFGroup end

function valuetype(::Type{T}) where {T <: RawGroup}
    String
end

function Base.one(t::Type{<:DXFGroup})
    t(one(valuetype(t)))
end

function read_value(group_type::Type{T}, in) where {T <: RawGroup}
    group_type(in.line, readline(in))
end


function lookup_group_code(code::DXFGroupCode)
    if haskey(group_code_registry, code)
        return group_code_registry[code]
    end
    return defDXFGroup(RawGroup, code)
end


abstract type StringGroup <: DXFGroup end

function valuetype(::Type{T}) where {T <: StringGroup}
    String
end

function read_value(group_type::Type{T}, in) where {T <: StringGroup}
    group_type(in.line, strip(readline(in)))
end


# It makes it easier to write the parser if we subtype group 0 for
# each different kind of element type.

abstract type EntityType <: DXFGroup end

export EntityType

function valuetype(::Type{T}) where {T <: EntityType}
    String
end

function ensureEntityType(value)
    etname = Symbol("EntityType_$value")
    if !any([t.name.name == etname
             for t in allsubtypes(EntityType)])
        name, defs = defDXFGroup_(EntityType, 0, etname)
        eval(defs)
    end
    eval(etname)
end

function EntityType(line::Int, value::String)
    Base.invokelatest(ensureEntityType(value), line, value)
end

function EntityType(value::String)
    Base.invokelatest(ensureEntityType(value), value)
end

group_code_registry[0] = EntityType

groupcode(::Type{<:EntityType})::DXFGroupCode = 0
groupcode(::EntityType)::DXFGroupCode = 0

function read_value(group_type::Type{T}, in) where {T <: EntityType}
    value = strip(readline(in))
    Base.invokelatest(ensureEntityType(value),
                      in.line, value)
end

# We need some of these EntityTypes at compile time to compile
# parser.jl:

ensureEntityType("SECTION")
ensureEntityType("ENDSEC")
ensureEntityType("EOF")
ensureEntityType("BLOCK")
ensureEntityType("ENDBLK")

#=
ensureEntityType should have defined EntityType_CLASS
ensureEntityType should have defined EntityType_TABLE
ensureEntityType should have defined EntityType_VPORT
ensureEntityType should have defined EntityType_ENDTAB
ensureEntityType should have defined EntityType_LTYPE
ensureEntityType should have defined EntityType_LAYER
ensureEntityType should have defined EntityType_STYLE
ensureEntityType should have defined EntityType_APPID
ensureEntityType should have defined EntityType_DIMSTYLE
ensureEntityType should have defined EntityType_BLOCK_RECORD
ensureEntityType should have defined EntityType_LINE
ensureEntityType should have defined EntityType_DICTIONARY
ensureEntityType should have defined EntityType_ACDBDICTIONARYWDFLT
ensureEntityType should have defined EntityType_XRECORD
ensureEntityType should have defined EntityType_SORTENTSTABLE
ensureEntityType should have defined EntityType_LAYOUT
ensureEntityType should have defined EntityType_MATERIAL
ensureEntityType should have defined EntityType_MLEADERSTYLE
ensureEntityType should have defined EntityType_MLINESTYLE
ensureEntityType should have defined EntityType_ACDBPLACEHOLDER
ensureEntityType should have defined EntityType_SCALE
ensureEntityType should have defined EntityType_TABLESTYLE
ensureEntityType should have defined EntityType_VISUALSTYLE
ensureEntityType should have defined EntityType_DICTIONARYVAR
=#


defDXFGroup(StringGroup, 1, :PrimaryText)
defDXFGroup(StringGroup, 2, :Name)
defDXFGroup(StringGroup, 3, :EntryName)
defDXFGroup(StringGroup, 4)
defDXFGroup(StringGroup, 5, :EntityHandle)
defDXFGroup(StringGroup, 6)
defDXFGroup(StringGroup, 7, :TextStyleName)
defDXFGroup(StringGroup, 8, :LayerName)
defDXFGroup(StringGroup, 9, :HeaderVariableName)


DXFIntegerType = Int64

abstract type IntegerGroup <: DXFGroup end

function valuetype(::Type{T}) where {T <: IntegerGroup}
    DXFIntegerType
end

function read_value(group_type::Type{T}, in) where {T <: IntegerGroup}
    group_type(in.line, parse(Int64, strip(readline(in))))
end


for code in 70:78
    defDXFGroup(IntegerGroup, code)
end


DXFFloatType = Float64

abstract type FloatGroup <: DXFGroup end

function valuetype(::Type{T}) where {T <: FloatGroup}
    DXFFloatType
end

function read_value(group_type::Type{T}, in) where {T <: FloatGroup}
    group_type(in.line, parse(DXFFloatType, strip(readline(in))))
end


abstract type PointX <: FloatGroup end
abstract type PointY <: FloatGroup end
abstract type PointZ <: FloatGroup end

export PointX, PointY, PointZ

for code in 10:18
    defDXFGroup(PointX, code,      Symbol("Point$(code)_X"))
    defDXFGroup(PointY, code + 10, Symbol("Point$(code + 10)_Y"))
    defDXFGroup(PointZ, code + 20, Symbol("Point$(code + 20)_Z"))
end

defDXFGroup(PointX, 210, :ExtrucionDirectionX)
defDXFGroup(PointX, 220, :ExtrucionDirectionY)
defDXFGroup(PointX, 230, :ExtrucionDirectionZ)

for code in 40:47
    defDXFGroup(FloatGroup, code)
end

defDXFGroup(FloatGroup, 48, :LinetypeScale)

for code in 49:59
    defDXFGroup(FloatGroup, code)
end


defDXFGroup(StringGroup, 100, :SubclassMarker)

defDXFGroup(StringGroup, 102, :ADGroupStartEnd)

for code in 110:149
    defDXFGroup(FloatGroup, code)
end

for code in 160:179
    defDXFGroup(IntegerGroup, code)
end

for code in 210:239
    defDXFGroup(FloatGroup, code)
end

for code in 270:289
    defDXFGroup(IntegerGroup, code)
end

abstract type HexIdString <: StringGroup end

for code in 330:369
    defDXFGroup(HexIdString, code)
end

for code in 370:389
    defDXFGroup(IntegerGroup, code)
end

abstract type HexHandleString <: StringGroup end

for code in 390:399
    defDXFGroup(HexHandleString, code)
end

defDXFGroup(StringGroup, 999, :Comment)

