using DXFutils
using Test


@testset "groupcode" begin
    for (key, value) in DXFutils.group_code_registry
        @test key == groupcode(value)
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
    sections = sectionize(groups)
    @test all([s isa DXFSection for s in sections])
    println("Test found $(length(sections)) DXF sections in sample file.")
end


