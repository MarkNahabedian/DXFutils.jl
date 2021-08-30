
export groupcode, read_value
export DXFGroup


abstract type DXFGroup end

DXFGroupCode = Int32

group_code_registry = Dict{DXFGroupCode, Type{<:DXFGroup}}()

function defDXFGroup(group_supertype::Type, code::Integer, name=nothing)
    defDXFGroup(group_supertype, DXFGroupCode(code), name)
end

function defDXFGroup(group_supertype::Type, code::DXFGroupCode, name=nothing)
    @assert group_supertype <: DXFGroup
    if name == nothing
        name = Symbol("Group_$code")
    end
    eval(quote
             struct $name <: $group_supertype
                 line::Int
                 value::$(valuetype(group_supertype))
             end
         end)
    eval(quote
             function $name(value::$(valuetype(group_supertype)))
                 $name(-1, value)
             end
         end)
    eval(quote
             function groupcode(::$name)::DXFGroupCode
                 return $code
             end
         end)
    eval(quote
             function groupcode(::Type{$name})::DXFGroupCode
                 return $code
             end
         end)
    eval(quote
             group_code_registry[$code] = $name
         end)
    eval(quote
             export $name
             end)
    eval(name)
end


abstract type RawGroup <: DXFGroup end

function valuetype(::Type{T}) where {T <: RawGroup}
    String
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

defDXFGroup(StringGroup, 0, :EntityType)

Base.:(==)(a::EntityType, b::EntityType) = a.value == b.value

defDXFGroup(StringGroup, 3)

defDXFGroup(StringGroup, 1, :PrimaryText)
defDXFGroup(StringGroup, 2, :Name)
defDXFGroup(StringGroup, 3)
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

defDXFGroup(PointX, 10, :PrimaryXCoordinate)
defDXFGroup(PointY, 20, :PrimaryYCoordinate)
defDXFGroup(PointZ, 10, :PrimaryZCoordinate)

for code in 10:18
    defDXFGroup(PointX, code)
    defDXFGroup(PointY, code + 10)
    defDXFGroup(PointZ, code + 20)
end

for code in 40:47
    defDXFGroup(PointX, code)
end

defDXFGroup(PointX, 48, :LinetypeScale)

