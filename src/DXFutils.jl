module DXFutils

using DataStructures
using Printf
import Base.parse

# This package:
include("all_subtypes.jl")
include("dxf_groups.jl")
include("reader.jl")
include("parser.jl")

include("explore.jl")

end

