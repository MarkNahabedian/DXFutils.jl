using DXFutils
using Test


@testset "groupcode" begin
    for (key, value) in DXFutils.group_code_registry
        @test key == groupcode(value)
        @test key == groupcode(one(value))
    end
end
    
@testset "DXF Groups" begin
    @test DXFutils.group_code_registry[0] == EntityType
    @test groupcode(EntityType) == 0
    grp = DXFutils.EntityType("SECTION")
    @test groupcode(grp) == 0
    @test grp.value == "SECTION"
end

example_file = "c:/Users/Mark Nahabedian/crafts/crafts/TrapezoidalLapJoint/drawings/strut-side-view.dxf"

@testset "read DXF file" begin
    groups = read_dxf_file(example_file)
    @test all([g isa DXFGroup for g in groups])
    open("DXF-groups.txt", "w") do io
        DXFutils.show_group_code_registry(io)
    end
end


@testset "parse empty document" begin
    parser = Parser(Vector{DXFGroup}([ EntityType("EOF") ]))
    debugparser(parser; rt=true) do
        parse(parser)
        if (length(parser.pending) == 1
            && parser.pending[1] isa DXFDocument 
            && length(parser.pending[1].contents) == 2)
            @test true
        else
            showstate(parser)
            @test false
        end
    end
end

@testset "parser reduce to point" begin
    parser = Parser(Vector{DXFGroup}([
        EntityType("SECTION"),
        Name("HEADER"),
        HeaderVariableName("foo"),
        Point10_X(1.0),
        Point20_Y(2.0),
        Point30_Z(3.0) ]))
    debugparser(parser; rt=true) do
        # @test_throws IncompleteDXFInput parse(parser)
        try
            parse(parser)
            @test false     # Did not throw any exception.
        catch e
            if e isa IncompleteDXFInput
                @test true  # expected error was thrown
            else
                rethrow(e)
            end
        end
        if (isa(parser.pending[end], HeaderVariable) &&
            isa(parser.pending[end].value, DXFPoint))
            @test true
        else
            showstate(parser)
            @test false
        end
    end
end

@testset "parser sections" begin
    parser = Parser(Vector{DXFGroup}([
        EntityType("SECTION"),
        Name("HEADER"),
        EntityType("ENDSEC"),
        EntityType("SECTION"),
        Name("CLASSES"),
        EntityType("ENDSEC"),
        EntityType("SECTION"),
        Name("TABLES"),
        EntityType("ENDSEC"),
        EntityType("SECTION"),
        Name("BLOCKS"),
        EntityType("ENDSEC"),
        EntityType("SECTION"),
        Name("ENTITIES"),
        EntityType("ENDSEC"),
        EntityType("SECTION"),
        Name("OBJECTS"),
        EntityType("ENDSEC"),
        EntityType("EOF") ]))
    debugparser(parser; rt=true) do
        parse(parser)
        if last(parser.pending) isa DXFDocument
            @test true
        else
            showstate(parser)
            @test false
        end
    end
end

@testset "parse sample file" begin
    parser = Parser(example_file)
    debugparser(parser; rt=true) do
        parse(parser)
        @test parser isa Parser
        @test length(parser.pending) == 1
        @test parser.pending[1] isa DXFDocument
    end
end


"""
# Hand testing

begin
  parser = Parser(example_file)
  showstate(parse(parser))
  doc = parser.pending[1]
  for s in doc
    println(summary(s))
  end
  println("\n***** Points")
  pointpaths = dxffind(x -> x isa DXFPoint, doc)
  for pp in pointpaths
    println(reverse([summary(x) for x in pp]))
  end
  println("\n***** Lines")
  linepaths = dxffind(doc) do x
    isa(x, DXFutils.DXFEntity) && x.contents[1].value == "LINE"
  end
  for lp in linepaths
    println(reverse([summary(x) for x in lp]))
  end
end

"""
