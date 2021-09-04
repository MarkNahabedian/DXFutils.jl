
export read_dxf_file

include("line_numbering_io.jl")

struct DXFReadError <: Exception
    line::Int
    e::Exception
end

function Base.showerror(io::IO, e::DXFReadError)
    print(io, "Error while reading DXF at line $(e.line): $(e.e)")
end


function read_dxf_file(in::LineNumberingIO)
    groups = Vector{DXFGroup}()
    while true
        try
            l = readline(in)
            if l == ""
                break
            end
            code = parse(DXFGroupCode, strip(l))
            group_type = lookup_group_code(code)
            push!(groups,
                  # try
                  # read_value(group_type, in)
                  Base.invokelatest(read_value, group_type, in)
                  #=
                  catch e
                  if (e isa Base.MethodError &&
                      e.f == read_value &&
                      e.args[1] == group_type)
                  Base.invokelatest(read_value, group_type, in)
                  else
                  rethrow(e)
                  end
                  end=# )
        catch e
            throw(DXFReadError(in.line, e))
        end
    end
    groups
end

function read_dxf_file(path::String)
    open(io -> read_dxf_file(LineNumberingIO(io)),
         path, "r")
end
