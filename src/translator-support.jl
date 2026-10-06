"""
    Internal: isdefault(x::Any)

Returns true if `x`'s value is considered a default value in PALS, meaning that
it shouldn't be represented in the final PALS tree, and false otherwise.

This only works off of general defaults, but many parameter groups have exceptions
to these rules, in which case the desired behavior should be handled in the 
respective overlaod of `add_parameter_group!()` for that parameter group.

## Arguments
- `line_element`    -- The `LineElement` being formatted into PALS.
"""
isdefault(::Nothing) = true     
isdefault(x::Number) = x == 0   
isdefault(x::String) = isempty(x)   
isdefault(x::Symbol) = x === Symbol("") 
isdefault(x::AbstractArray) = isempty(x)
isdefault(x::AbstractDict) = isempty(x) 
isdefault(::Any) = false

"""
This maps types of `AbstractParams` to the symbol representing its PALS-format name.
"""
const PARAMETER_TYPES_TO_PALS_NAMES_MAP = Dict{Type{<:AbstractParams}, Symbol}(
    BMultipoleParams => :MagneticMultipoleP,
    ApertureParams => :ApertureP,
    MetaParams => :MetaP,
    AlignmentParams => :BodyShiftP,
    BendParams => :BendP,
    RFParams => :RFP,
    PatchParams => :PatchP,
    InheritParams => :SciBmad_InheritParams,
    MapParams => :SciBmad_MapParams,
    BeamlineParams => :ReferenceP
)

"""
This maps symbols of names of parameter names as they appear in 
SciBmad to the symbol of the name in PALS. If a SciBmad parameter
name isn't in this dictionary, it means that its name in PALS
is the same (or this needs to be updated). Symbols that map to
symbols that have "SciBmad" at the beginning indicate parameters
in SciBmad that don't have an equivalent in PALS.
"""
const SCIBMAD_NAMES_TO_PALS_NAMES_MAP = Dict{Symbol, Symbol}(
    # PatchP...
    :dx => :x_offset,
    :dy => :y_offset,
    :dz => :z_offset,
    :dx_rot => :x_rot,
    :dy_rot => :y_rot,
    :dz_rot => :z_rot,
    :dt => :SciBmad_dt,     # *
    # ApertureP...
    :x1_limit => :x_min,
    :x2_limit => :x_max,
    :y1_limit => :y_min,
    :y2_limit => :y_max,
    :aperture_shape => :shape,
    :aperture_at => :location,
    # BendP...
    :g_ref => :g,
    # (MapParams) [No PALS group]
    :transport_map => :SciBmad_transport_map,   # *
    :transport_map_params => :SciBmad_transport_map_params,     # *
    # (FourPotentialParams) [No PALS group]
    :four_potential => :SciBmad_four_potential,     # *
)

"""
This maps types of `ApertureShape` to the value they should appear
as when translated into a PALS file.
"""
const APERTURE_SHAPES_TO_PALS_MAP = Dict(
    ApertureShape.Rectangular => :RECTANGULAR,
    ApertureShape.Elliptical => nothing,
)

"""
This maps types of `ApertureAt` to the value they should appear
as when translated into a PALS file.
"""
const APERTURE_LOCATIONS_TO_PALS_MAP = Dict(
    ApertureAt.Entrance => nothing,
    ApertureAt.Exit => :EXIT_END,
    ApertureAt.BothEnds => :BOTH_ENDS,
)

"""
This maps types of `PhaseReference` to the value they should appear
as when translated into a PALS file.
"""
const ZERO_PHASE_TO_PALS_MAP = Dict(
    PhaseReference.Accelerating => nothing,
    PhaseReference.BelowTransition => :BELOW_TRANSITION,
    PhaseReference.AboveTransition => :ABOVE_TRANSITION,
)

"""
This maps types of `RateMeaning` to the value they should appear
as when translated into a PALS file.
"""
const RATE_MEANING_TO_PALS_MAP = Dict(
    RateMeaning.RFFrequency => :frequency,
    RateMeaning.Harmon => :harmon,
)