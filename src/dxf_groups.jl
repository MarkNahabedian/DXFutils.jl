
export groupcode, read_value


abstract type DXFGroup end

DXFGroupCode = Int32

group_code_registry = Dict{DXFGroupCode, Type{<:DXFGroup}}()

value_type_to_group_type = Dict{Type, Type{<:DXFGroup}}()

function defDXFGroup(value_type::Type, code::Integer, name=nothing)
    if name == nothing
        name = Symbol("Group_$code")
    end
    if value_type <: DXFGroup
        group_type = value_type
        value_type = Any
    else
        group_type = value_type_to_group_type[value_type]
    end
    eval(quote
             struct $name <: $group_type
                 value::$value_type
             end
         end)
    eval(quote
             function groupcode(::$name)
                 return $code
             end
         end)
    eval(quote
             function groupcode(::Type{$name})
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

function read_value(group_type::Type{T}, in::IO) where T <: RawGroup
    group_type(readline(in))
end


abstract type StringGroup <: DXFGroup end
value_type_to_group_type[String] = StringGroup

function read_value(group_type::Type{T}, in::IO) where T <: StringGroup
    group_type(strip(readline(in)))
end

defDXFGroup(String, 0, :EntityType)

defDXFGroup(String, 3)

defDXFGroup(String, 1, :PrimaryText)
defDXFGroup(String, 2, :Name)
defDXFGroup(String, 3)
defDXFGroup(String, 4)
defDXFGroup(String, 5, :EntityHandle)
defDXFGroup(String, 6)
defDXFGroup(String, 7, :TextStyleName)
defDXFGroup(String, 8, :LayerName)
defDXFGroup(String, 9, :HeaderVariableNamke)


abstract type IntegerGroup <: DXFGroup end
value_type_to_group_type[Integer] = IntegerGroup

function read_value(group_type::Type{T}, in::IO) where T <: IntegerGroup
    group_type(parse(Integer, strip(readline(in))))
end
