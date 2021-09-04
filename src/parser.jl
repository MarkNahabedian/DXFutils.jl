# DXF Parser

export Parser, parse, debugparser, showstate
export DXFParseError, IncompleteDXFInput, UnexpectedDXFInput
export DXFDocument, HeaderVariable, DXFPoint
export tracing_parser


abstract type DXFParseError <: Base.Exception end


Base.@kwdef mutable struct Parser
    groups::Vector{DXFGroup}
    # index is the position in groups of the DXFGroup currently being
    # considered:
    index::Int = 1
    # pending is a stack of "opening" groups and reductions:
    pending::Vector = []
    # starts is a stack of indices into pending of pending "start"
    # DXFGroups for which we have not yet encountered the matching
    # "end" group.
    starts::Vector{Int} = Vector{Int}()

    # Debugging flags
    trace_parser_actions = false  # See @tracePA, start, reduce
    showstate_in_parse = false    # Call showstate in each iteration of parse loop
end

function Parser(groups::Vector{DXFGroup})
    Parser(groups=groups)
end


function showstate(parser::Parser)
    showstate(stdout, parser)
end

function showstate(io::IO, parser::Parser)
    level = 1
    println("\n\nParser has $(length(parser.starts)) starts,")
    println("$(length(parser.pending)) pending tokens.")
    println("input index: $(parser.index)/$(length(parser.groups))")
    println("starts: $(parser.starts)")
    for i in 1:length(parser.pending)
        t = parser.pending[i]
        isstart = level <= length(parser.starts) && parser.starts[level] == i
        spaces = repeat("  ", level)
        prefix = if isstart "[" else " " end
        @printf("%8d%s%s %s\n", i, spaces, prefix, t)
        if isstart
            level += 1
        end
    end
end

"""
    debugparser(::Parser, rt=false) do ... end

If a DXFParseError occurs during the do block then call `showstate` to
display the `pending` buffer of the parser.  If rt is true then
rethrow the DXFParseError.

All other exceptions are rethrown.
"""
function debugparser(body, parser; io=stderr, rt=false)
    try
        body()
    catch e
        if e isa DXFParseError
            showerror(io, e)
            showstate(io, parser)
            if rt
                rethrow(e)
            end
        else
            rethrow(e)
        end
    end
end


struct UnexpectedDXFInput <: DXFParseError
    parser::Parser
    pending::DXFObject
    current::DXFObject
    message::String
end

function Base.showerror(io::IO, e::UnexpectedDXFInput)
    print(io, "UnexpectedDXFInput, $(e.current): $(e.message)")
end


function Parser(path::String)
    Parser(read_dxf_file(path))
end

function Parser(io::IO)
    parser(read_dxf_file(io))
end


"""
    current(::Parser)
Return the object at the top of the `pending` stack.
"""
function current(parser::Parser)
    last(parser.pending)
end

"""
    pendingindex(::Parser)
Return the index of the topmost start token.
"""
function pendingindex(parser::Parser)
    last(parser.starts)
end

"""
    pending(::Parser)
Return the topmost start token from the `pending` stack.
"""
function pending(parser::Parser)
    parser.pending[pendingindex(parser)]
end

"""
    start(::Parser)
Declare that the topmost token of `pending` is a start token
by pushing its index onto the `start` stack.
"""
function start(parser::Parser)
    if parser.trace_parser_actions
        println("start $(last(parser.pending))")
    end
    push!(parser.starts, lastindex(parser.pending))
end

function reduce(parser::Parser, constructor)
    grabbed = grab(parser)
    reduction = constructor(grabbed)
    push!(parser.pending, reduction)
    if parser.trace_parser_actions
        println("Reduced $(length(grabbed)) to $reduction")
    end
    if length(parser.starts) > 0
        parseraction(parser)
    end
end

"""
    grab(::Parser)
Remove the elements pf the pending stack from the topmost start token
to the topmost token and return them.
"""
function grab(parser::Parser)
    range = pop!(parser.starts):lastindex(parser.pending)
    elts = parser.pending[range]
    deleteat!(parser.pending, range)
    return elts
end

"""
    lookahead(::Parser)
return the next input token or nothing.
A second argument can be passed to specify an offset for additional
lookahead.
"""
function lookahead(parser::Parser, index=0)
    i = parser.index + index
    if i > length(parser.groups)
        nothing
    else
        parser.groups[i]
    end
end


"""
DocumentStart is the start token at the beginning of the document.
"""
struct DocumentStart <: DXFObject
end

function parse(groups::Vector{DXFGroup})
    parse(Parser(groups))
end

struct IncompleteDXFInput <: DXFParseError
    parser::Parser
end

function Base.showerror(io::IO, e::IncompleteDXFInput)
    remaining = length(e.parser.groups) - e.parser.index
    print(io, "parse ended prematurely: starts: $(length(e.parser.starts)), remaining input:$remaining")
end

function parse(parser::Parser)
    push!(parser.pending, DocumentStart())
    start(parser)
    while length(parser.starts) > 0 && parser.index <= length(parser.groups)
        # Shift the next token into pending
        push!(parser.pending, parser.groups[parser.index])
        parser.index += 1
        if parser.showstate_in_parse
            showstate(parser)
        end
        # See if any reductions can be performed
        parseraction(parser)
    end
    if length(parser.starts) > 0 || parser.index <= length(parser.groups)
        remaining = length(parser.groups) - parser.index
        throw(IncompleteDXFInput(parser))
    end
    return parser
end


function tracePA_(frame)
    #=
    function sttest(a::Real, b, c)
        first(stacktrace())
    end

    fieldnames(typeof(sttest(1.2,2,3)))    # Base.StackTraces.StackFrame
    (:func, :file, :line, :linfo, :from_c, :inlined, :pointer)

    fieldnames(typeof(sttest(1.2,2,3).linfo))     # Core.MethodInstance
    (:def, :specTypes, :sparam_vals, :uninferred, :backedges, :callbacks, :cache, :inInference)

    fieldnames(sttest(1.2,2,3).linfo.def)       Method
    (:name, :module, :file, :line, :primary_world, :deleted_world, :sig, :specializations,
    :speckeyset, :slot_syms, :source, :unspecialized, :generator, :roots, :ccallable,
    :invokes, :nargs, :called, :nospecialize, :nkw, :isva, :pure)
    =#
    ip = 3:4   # interesting parameters to show
    psig(t) = fieldtypes(t)[ip]
    @assert frame.func == :parseraction
    println("tracePA: $(frame.func) " *
        "$(psig(frame.linfo.def.sig)) " *
        "$(psig(frame.linfo.specTypes))")
end

macro tracePA(parser_)
    quote
        if ($(esc(parser_))).trace_parser_actions
            tracePA_(first(stacktrace()))
        end
    end
end


"""
Each parseraction is a shift/reduce rule of our DXF parser.
"""
function parseraction end

function parseraction(parser::Parser)
    p = pending(parser)
    c = current(parser)
    if parser.trace_parser_actions
        println("parseraction $p $c")
    end
    parseraction(parser, p, c)
end

"""
The default behavior is to shift the new token into pending.
Shifting of input DXFGroups happens in `parser`, whiuch shifts
all new tokens before calling `parseraction`.
"""
function parseraction(parser::Parser, pending::DXFObject, current::DXFGroup)
    @tracePA(parser)
    # Just shift, which happened in the caller.
end


# Document

"""
DocumentStart represents an entire DXF document.
"""
struct DXFDocument <: DXFObject
    contents::Vector
end

function parseraction(parser::Parser, pending::DocumentStart, current::EntityType_EOF)
    @tracePA(parser)
    reduce(parser, DXFDocument)
end


# Sections and Entities

# A section can only follow the document start token or another sectioon:
function parseraction(::Parser, ::DocumentStart, ::DXFSection) end
function parseraction(::Parser, ::DXFSection, ::DXFSection) end

function parseraction(parser::Parser, pending::DocumentStart, current::EntityType_SECTION)
    @tracePA(parser)
    start(parser)
end

function parseraction(parser::Parser, pending::DXFGroup, current::EntityType_SECTION)
    @tracePA(parser)
    throw(UnexpectedDXFInput(parser, pending, current,
                             "EntityType is unexpected context"))
end

function parseraction(parser::Parser, pending::EntityType_SECTION, current::EntityType_ENDSEC)
    @tracePA(parser)
    reduce(parser, DXFSection)
end


# Header Variables

struct HeaderVariable <: DXFObject
    name::HeaderVariableName
    value::DXFObject

    function HeaderVariable(contents)
        @assert length(contents) == 2 "length $contents ($(length(contents))) != 2"
        new(contents...)
    end
end

function Base.summary(io::IO, v::HeaderVariable)
    println("$(typeof(v)) $(v.name) = $(v.value)")
end

function parseraction(parser::Parser, pending::DXFObject, current::HeaderVariableName)
    @tracePA(parser)
    start(parser)
end

function parseraction(parser::Parser, pending::HeaderVariableName, current::DXFGroup)
    @tracePA(parser)
    reduce(parser, HeaderVariable)
end

function parseraction(parser::Parser, pending::EntityType_SECTION, current::HeaderVariable)
    @tracePA(parser)
    @assert parser.pending[pendingindex(parser)] == pending
    if !groupmatch(parser.pending[pendingindex(parser) + 1], Name("HEADER"))
        throw(UnexpectedDXFInput(parser, pending, current,
                                 "Header variable not in HEADER section"))
    end
end


# Points

struct DXFPoint <: DXFObject
    pointX::PointX
    pointY::PointY
    pointZ::Union{Nothing, PointZ}

    DXFPoint(contents) = DXFPoint(contents...)

    function DXFPoint(x::PointX, y::PointY, z::PointZ)
        @assert groupcode(x) + 10 == groupcode(y) "$x $(groupcode(x)), $y $(groupcode(y))"
        @assert groupcode(x) + 20 == groupcode(z) "$x $(groupcode(x)), $z $(groupcode(z))"
        new(x, y, z)
    end

    function DXFPoint(x::PointX, y::PointY)
        @assert groupcode(x) + 10 == groupcode(y) "$x $(groupcode(x)), $y $(groupcode(y))"
        new(x, y, nothing)
    end

end

function Base.summary(io::IO, p::DXFPoint)
    println("$(typeof(p)) $(p.poinmtX.value), $p.pointY.value), $(p.pointZ.value)")
end

function parseraction(parser::Parser, pending::HeaderVariableName, current::PointX)
    @tracePA(parser)
    start(parser)
end

function parseraction(parser::Parser, pending::PointX, current::DXFGroup)
    @tracePA(parser)
    throw(UnexpectedDXFInput(parser, pending, current,
                             "Expected PointY or PointZ after PointX, got $current"))
end

function parseraction(parser::Parser, pending::PointX, current::PointY)
    @tracePA(parser)
    # Lookahead to figure out if this is a 2D or 3D point:
    if !isa(lookahead(parser), PointZ)
        reduce(parser, DXFPoint)
    end
end

function parseraction(parser::Parser, pending::PointX, current::PointZ)
    @tracePA(parser)
    reduce(parser, DXFPoint)
end

##### Temporary method to find a bug
function parseraction(parser::Parser, pending::PointX, current::PointX)
    @tracePA(parser)
    throw(UnexpectedDXFInput(parser, pending, current,
                        "PointX in context of PointX"))
end

function parseraction(parser::Parser, pending ::HeaderVariableName, current::DXFPoint)
    @tracePA(parser)
    reduce(parser, HeaderVariable)
end

