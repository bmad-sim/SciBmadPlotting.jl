"""
    SciBmadSimUtils

Simulation utilities for the SciBmad ecosystem. Currently this holds the translator from
SciBmad lattices to the PALS lattice standard: see `to_pals` and `write_pals`.
"""
module SciBmadSimUtils

using Beamlines
using Beamlines: BMULTIPOLE_STRENGTH_INVERSE_MAP, BMULTIPOLE_TILT_INVERSE_MAP,
                 EMULTIPOLE_STRENGTH_INVERSE_MAP, EMULTIPOLE_TILT_INVERSE_MAP, Context, ParamDict, RefMeaning,
                 deval, flattened_pdict
using OrderedCollections
using YAML

export to_pals, write_pals

# SciBmad -> PALS translator
include("translator-support.jl")
include("translator-parameter-handling.jl")
include("translator.jl")

end
