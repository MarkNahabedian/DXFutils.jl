# DXF Parser

export Parser, parse, debugparser, showstate
export DXFParseError, IncompleteDXFInput, UnexpectedDXFInput
export DXFDocument, HeaderVariable, DXFPoint, DXFEntity, DXFBlock
export DXFSection, sectiontype, sections, section
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
    trace_disambiguation = false  # trace disambiguation of parseraction methods
end

function Parser(groups::Vector{DXFGroup})
    Parser(groups=groups)
end


function showstate(parser::Parser)
    showstate(stdout, parser)
    nothing
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
        @printf("%8d%s%s %s\n", i, spaces, prefix, summary(t))
        if isstart
            level += 1
        end
    end
    nothing
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
    shift(::Parser)
Shift the next input token from `parser.groups` to `parser.pending`.
"""
function shift(parser::Parser)
    push!(parser.pending, parser.groups[parser.index])
    parser.index += 1
    nothing
end

START_GROUP_TYPES = [
]

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

function reduce(parser::Parser, constructor, fromend=0)
    grabbed = grab(parser; fromend)
    reduction = constructor(grabbed)
    insert!(parser.pending,
            lastindex(parser.pending) + 1 - fromend,
            reduction)
    if parser.trace_parser_actions
        println("Reduced $(length(grabbed)) to $reduction")
    end
end

"""
    grab(::Parser)
Remove the elements pf the pending stack from the topmost start token
to the topmost token and return them.

`fromend` is a non-negative number counting from `lastindex`..
"""
function grab(parser::Parser; fromend=0)
    range = pop!(parser.starts):(lastindex(parser.pending) - fromend)
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


# Supertype for DXFObjects that have a contents shot:
abstract type DXFContentsObject <: DXFObject end
    
function Base.iterate(o::DXFContentsObject)
    iterate(o.contents)
end

function Base.iterate(o::DXFContentsObject, state)
    iterate(o.contents, state)
end

function Base.summary(io::IO, o::DXFContentsObject)
    print(io, "$(typeof(o)) $(o.contents[1].value)) with $(length(o.contents)) elements")
end

function Base.getproperty(o::DXFContentsObject, p::Symbol)
    if hasfield(typeof(o), p)
        return getfield(o, p)
    end
    if p == :line
        # The line number of a DXFObject is the line number of its
        # first group:
        return o.contents[1].line
    end
    # To get the standard missing field error, since there doesn't
    # seem to be a defined Exception type for this yet:
    getfield(o, p)
end

function Base.propertynames(o::DXFContentsObject, private::Bool)
    [ :line,
      fieldnames(typeof(o, private))... ]
end



"""
DocumentStart is the start token at the beginning of the document.
"""
struct DocumentStart <: DXFObject
end

function Base.getproperty(ds::DocumentStart, p::Symbol)
    if p == :value
        return nothing
    end
    getfield(ds, p)
end

function Base.propertynames(ds::DocumentStart, private::Bool)
    [ :value,
      fieldnames(typeof(ds, private))... ]
end

function Base.summary(io::IO, ds::DocumentStart)
    print(io, "$(typeof(ds))")
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
        shift(parser)
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
    if length(parser.starts) <= 0
        return
    end
    p = pending(parser)
    c = current(parser)
    if parser.trace_parser_actions
        println("parseraction for $p $c")
    end
    try
        parseraction(parser, p, c)
    catch e
        if !(e isa Base.MethodError)
            rethrow(e)
        end
        if e.f != parseraction
            rethrow(e)
        end
        if length(e.args) == 1
            # Do not handle the one argument call to parseraction
            rethrow(e)
        end
        msg = IOBuffer()
        showerror(msg, e)
        msg = String(take!(msg))
        # I wish MethodError had subtypes to distinguish "no
        # applicable method" from "ambiguous methods".
        if !occursin("is ambiguous", msg)
            rethrow(e)
        end
        best = nothing
        for m in methods(parseraction)
            if length(m.sig.parameters) != 4
                continue
            end
            if !all(isa.(e.args, m.sig.parameters[2:length(m.sig.parameters)]))
                # m is not applicable
                continue
            end
            if best == nothing
                best = m
                continue
            end
            # proper subtype?
            better(spec1, spec2) = (spec1 <: spec2) && !(spec2 <: spec1)
            for pos in ((1, 3, 2).+1)   # m.sig[1] is the type of the function.
                mspec = m.sig.parameters[pos]
                bspec = best.sig.parameters[pos]
                if better(bspec, mspec)
                    break
                end
                if better(mspec, bspec)
                    if parser.trace_disambiguation
                        println("@@ $pos: $mspec of $m preferred to\n      $bspec of $best")
                    end
                    best = m
                    break
                end
            end
        end
        if best == nothing
            rethrow(e)
        end
        invoke(e.f,
               Tuple{best.sig.parameters[2:length(best.sig.parameters)]...},
               e.args...)
    end
end

"""
The default behavior is to shift the new token into pending.
Shifting of input DXFGroups happens in `parser`, whiuch shifts
all new tokens before calling `parseraction`.
"""
function parseraction(parser::Parser, pending::DXFGroup, current::DXFObject)
    @tracePA(parser)
    # Just shift, which happened in the caller.
end


# Document

"""
DocumentStart represents an entire DXF document.
"""
struct DXFDocument <: DXFContentsObject
    contents::Vector
end

function sections(doc::DXFDocument)
    sections = []
    for s in doc
        if !isa(s, DXFSection)
            continue
        end
        n = sectiontype(s)
        if n != nothing
            push!(sections, n)
        end
    end
    sections
end

function section(doc::DXFDocument, sect::String)::Union{Nothing, DXFSection}
    for e in doc.contents
        if e isa DXFSection
            if sectiontype(e) == sect
                return e
            end
        end
    end
    return nothing
end

function parseraction(parser::Parser, pending::DocumentStart, current::EntityType_EOF)
    @tracePA(parser)
    reduce(parser, DXFDocument)
    parseraction(parser)
end


# Sections and Entities

struct DXFSection <: DXFContentsObject
    contents::Vector
end

function Base.summary(io::IO, section::DXFSection)
    println(io, "$(typeof(section)) $(sectiontype(section)) with $(length(section.contents)) elements")
end

function sectiontype(sec::DXFSection)
    if sec.contents[2] isa Name
        sec.contents[2].value
    else
        nothing
    end
end


# A section can only follow the document start token or another sectioon:
function parseraction(parser::Parser, ::DocumentStart, ::DXFSection) @tracePA(parser) end
function parseraction(parser::Parser, ::DXFSection, ::DXFSection) @tracePA(parser) end

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
    parseraction(parser)
end


# Non-section entities

# It seems that one entity ends where the next one begins.

struct DXFEntity <: DXFContentsObject
    contents::Vector
end

function parseraction(parser::Parser, pending::EntityType_SECTION, current::EntityType)
    @tracePA(parser)
    start(parser)
end

function parseraction(parser::Parser, pending::EntityType, current::EntityType)
    @tracePA(parser)
    # `current` starts a new entity.  First we must finish the previous one:
    reduce(parser, DXFEntity, 1)
    start(parser)
end

function parseraction(parser::Parser, pending::EntityType, current::EntityType_ENDSEC)
    @tracePA(parser)
    # ENDSEC closes the currently open entity and the section that
    # contains it.
    reduce(parser, DXFEntity, 1)
    parseraction(parser)
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
    print(io, "$(typeof(v)) $(v.name) = $(v.value)")
end

### Maybe make this pending::EntityType_SECTION and test that section is HEADER.
function parseraction(parser::Parser, pending::DXFGroup, current::HeaderVariableName)
    @tracePA(parser)
    start(parser)
end

function parseraction(parser::Parser, pending::HeaderVariableName, current::DXFObject)
    @tracePA(parser)
    reduce(parser, HeaderVariable)
    parseraction(parser)
end

function parseraction(parser::Parser, pending::EntityType_SECTION, current::HeaderVariable)
    @tracePA(parser)
    @assert parser.pending[pendingindex(parser)] == pending
end


# Blocks

struct DXFBlock <: DXFContentsObject
    contents::Vector{DXFObject}
end

function parseraction(parser::Parser, pending::EntityType_BLOCK, current::DXFObject)
    @tracePA(parser)
end

function parseraction(parser::Parser, pending::EntityType_BLOCK, current::EntityType_ENDBLK)
    @tracePA(parser)
    reduce(parser, DXFBlock)
    parseraction(parser)
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

# We need some simple way to distinguish points of different types.
function groupcode(point::DXFPoint)
    groupcode(point.pointX)
end

function Base.summary(io::IO, p::DXFPoint)
    val(x) = if x isa DXFGroup x.value else nothing end
    print(io, "$(typeof(p)) $(val(p.pointX)), $(val(p.pointY)), $(val(p.pointZ))")
end

function parseraction(parser::Parser, pending::DXFGroup, current::PointX)
    @tracePA(parser)
    start(parser)
    if lookahead(parser) isa PointY
        shift(parser)
    end
    if lookahead(parser) isa PointZ
        shift(parser)
    end
    reduce(parser, DXFPoint)
    parseraction(parser)
end

function parseraction(parser::Parser, pending::PointX, current::DXFGroup)
    @tracePA(parser)
    throw(UnexpectedDXFInput(parser, pending, current,
                             "Expected PointY or PointZ after PointX, got $current"))
end


### For now at least DXFPoint can be contained by a DXFSection
function parseraction(parser::Parser, ::EntityType_SECTION, ::DXFPoint)
    @tracePA(parser)
end


struct ADGroup <: DXFContentsObject
    contents
end

function parseraction(parser::Parser, pending::DXFGroup, current::ADGroupStartEnd)
    @tracePA(parser)
    if length(current.value) > 1 && current.value[1] == '{'
        start(parser)
    else
        #=
        # We see ADGroupStartEnd groups that start with neither '{' nor '}'.
        # Until we understand more, just shift them.
        # We might eventually consaume the next entity to produce
        # an ADGroup with a single element, but until we know what that
        # content element can be we can't tell when to reduce.
        throw(UnexpectedDXFInput(parser, pending, current,
                           "non-opening ADGroupStartEnd in unexpected context"))
        =#
    end
end

function parseraction(parser::Parser, pending::ADGroupStartEnd, current::ADGroupStartEnd)
    @tracePA(parser)
    if length(current.value) == 1 && current.value[1] == '}'
        reduce(parser, ADGroup)
        parseraction(parser)
    else
        throw(UnexpectedDXFInput(parser, pending, current,
                           "non-closing ADGroupStartEnd in unexpected context"))
    end        
end

function parseraction(parser::Parser, pending::DXFGroup, current::ADGroup)
    @tracePA(parser)
end

