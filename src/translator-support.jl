#= Tables and helpers used by the SciBmad -> PALS translator. =#

"""
Maps SciBmad element kinds to PALS element kinds. Kinds not in this map have
the same name in PALS.
"""
const SCIBMAD_KIND_TO_PALS_KIND = Dict{String,String}(
    "SBend"   => "Bend",
    "HKicker" => "Kicker",
    "VKicker" => "Kicker",
    "BPM"     => "Instrument",
)

"""
Maps SciBmad parameter group types to PALS parameter group names. Names that begin with
"SciBmad_" are SciBmad extensions with no PALS equivalent. The order of this list is
the order in which the groups are written for an element.
"""
const PARAMS_TO_PALS_GROUP = (
    MetaParams          => "MetaP",
    AlignmentParams     => "BodyShiftP",
    ApertureParams      => "ApertureP",
    BendParams          => "BendP",
    BMultipoleParams    => "MagneticMultipoleP",
    EMultipoleParams    => "ElectricMultipoleP",
    RFParams            => "RFP",
    PatchParams         => "PatchP",
    MapParams           => "SciBmad_MapParams",
    FourPotentialParams => "SciBmad_FourPotentialParams",
    EMFieldParams       => "SciBmad_EMFieldParams",
)

"""
Maps SciBmad parameter names to PALS parameter names for parameter groups whose
parameters are translated one-to-one. A parameter not in the map for its group has the
same name in PALS.
"""
const SCIBMAD_NAME_TO_PALS_NAME = Dict{Type{<:AbstractParams},Dict{Symbol,String}}(
    AlignmentParams => Dict(:tilt => "z_rot"),
    PatchParams => Dict(
        :dx     => "x_offset",
        :dy     => "y_offset",
        :dz     => "z_offset",
        :dx_rot => "x_rot",
        :dy_rot => "y_rot",
        :dz_rot => "z_rot",
        :dt     => "SciBmad_dt",    # PALS PatchP has no time offset
    ),
    BendParams => Dict(),
    MetaParams => Dict(),
)

"""
Maps `ApertureShape` values to PALS `shape` values. `nothing` is the PALS default.
"""
const APERTURE_SHAPE_TO_PALS = Dict(
    ApertureShape.Elliptical  => nothing,
    ApertureShape.Rectangular => "RECTANGULAR",
)

"""
Maps `ApertureAt` values to PALS `location` values. `nothing` is the PALS default.
"""
const APERTURE_AT_TO_PALS = Dict(
    ApertureAt.Entrance => nothing,
    ApertureAt.Exit     => "EXIT_END",
    ApertureAt.BothEnds => "BOTH_ENDS",
)

"""
Maps `PhaseRef` values to PALS `zero_phase` values. `nothing` is the PALS default.
"""
const PHASE_REF_TO_PALS = Dict(
    PhaseRef.Accelerating    => nothing,
    PhaseRef.BelowTransition => "BELOW_TRANSITION",
    PhaseRef.AboveTransition => "ABOVE_TRANSITION",
)

"""
Maps `RateMeaning` values to the name of the PALS `RFP` parameter that holds the rate.
"""
const RATE_MEANING_TO_PALS = Dict(
    RateMeaning.RFFrequency => "frequency",
    RateMeaning.Harmon      => "harmon",
)

"""
    Internal: isdefault(x) -> Bool

Returns `true` if `x` is a default value that does not need to be written to a PALS file.
Parameter groups with other defaults handle them in their `pals_group` method.
"""
isdefault(::Nothing) = true
isdefault(x::Number) = iszero(x)
isdefault(x::AbstractString) = isempty(x)
isdefault(x::Symbol) = x === Symbol("")
isdefault(x::AbstractArray) = isempty(x)
isdefault(x::AbstractDict) = isempty(x)
isdefault(::Any) = false

"""
    Internal: pals_value(x)

Converts the parameter value `x` into a value suitable for writing to a PALS file.
`Float32` values are converted to the `Float64` with the same decimal representation
so that, for example, `0.1f0` is written as `0.1` and not `0.10000000149011612`.
"""
pals_value(x::Float32) = isfinite(x) ? parse(Float64, string(x)) : Float64(x)
pals_value(x::Union{Bool,Integer,Float64}) = x
pals_value(x::Real) = Float64(x)
pals_value(x::Union{AbstractString,Symbol}) = String(x)
pals_value(x::AbstractArray) = map(pals_value, x)
pals_value(x) = error("Unable to translate value $(repr(x)) of type $(typeof(x)) to PALS. " *
                      "Values must be real numbers: use `scalarize` first if needed.")

"""
    Internal: pals_name(name::AbstractString) -> String

Returns `name` modified to be a valid PALS name: it must start with a letter or underscore
and contain only letters, digits and underscores. Invalid characters are replaced by `_`.
"""
function pals_name(name::AbstractString)
    s = replace(name, r"[^A-Za-z0-9_]" => "_")
    return occursin(r"^[A-Za-z_]", s) ? s : "_" * s
end
