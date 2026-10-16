"""
    Internal: add_parameter_group!(format_dict::OrderedDict, parameter_group::T) where {T<:AbstractParams}

Modifies `format_dict` to have a new entry which stores a dictionary whose keys are parameter
names from `parameter_group` and whose values are the initialized values corresponding
to those parameter names.

This function is used as a helper to `lattice_to_pals()` to create the dictionaries
that store the fields and field values of a parameter group and populate the dictionaries
associated with elements with them.

## Arguments
- `parameter_info`  -- The dictionary to be modified which represents the information about a line element.
- `parameter_group` -- An `AbstractParams` object containing the parameters to extract to `acc`.
"""
function add_parameter_group!(parameter_info::OrderedDict, parameter_group::T) where{T <: AbstractParams}

    acc = OrderedDict() 

    # Populate the accumulator with properties
    for name in propertynames(parameter_group)
        value = getproperty(parameter_group, name)
        
        # If the value is default, skip it
        isdefault(value) && continue
        
        # If the value is a `String`, convert it to a `Symbol`
        if value isa String
            value = Symbol(value)
        end
        
        # Access the PALS name of this parameter group
        pals_name = get(SCIBMAD_NAME_TO_PALS_NAME_MAP, name, name)
        
        # Accumulate
        acc[pals_name] = value
    end
    
    # If the accumulator is empty, do nothing
    isempty(acc) && return
    
    # If the accumulator isn't empty, mutate `parameter_info`
    parameter_info[PARAMTYPES_TO_PALSNAMES_MAP[T]] = acc
end

#= ApertureParams overload =#
function add_parameter_group!(parameter_info::OrderedDict, aperture::ApertureParams)
    acc = OrderedDict()
    
    # Limits
    limits = (
    (:x1_limit, -Inf32, :x_min),
    (:x2_limit, Inf32, :x_max),
    (:y1_limit, -Inf32, :y_min),
    (:y2_limit, Inf32, :y_max),
    )
    
    for (source, default, dest) in limits
        value = getproperty(aperture, source)
        value != default && (acc[dest] = value)
    end
    
    # Shape
    shape = get(APERTURE_SHAPE_TO_PALS_MAP, aperture.aperture_shape, :INVALID)
    
    # If shape is invalid, error
    shape === :INVALID && error("Unsupported aperture shape: $(aperture.aperture_shape)")

    # If shape is nothing, move on
    !isnothing(shape) && (acc[:shape] = shape)
    
    # Location
    location = get(APERTURE_LOCATION_TO_PALS_MAP, aperture.aperture_at, :INVALID)
    
    # If location is invalid, error
    location === :INVALID && error("Unsupported aperture location: $(aperture.aperture_at)")
    
    # If location is nothing, move on
    !isnothing(location) && (acc[:location] = location)
    
    # Non-default booleans
    aperture.aperture_shifts_with_body && (acc[:aperture_shifts_with_body] = true)
    !aperture.aperture_active && (acc[:aperture_active] = false)
    
    # If nothing was added to the accumulator, do nothing
    isempty(acc) || (parameter_info[:ApertureP] = acc)
    return
end

#= RFParams overload =#
function add_parameter_group!(parameter_info::OrderedDict, rf::RFParams)
    acc = OrderedDict()
    
    # Voltage
    !isdefault(rf.voltage) && (acc[:voltage] = rf.voltage)
    
    # Phase (radians -> turns)
    !isdefault(rf.phi0) &&
    (acc[:phase] = rf.phi0 / (2π))
    
    # Zero phase
    zero_phase = get(ZERO_PHASE_TO_PALS_MAP, rf.zero_phase, :INVALID)
    
    # If zero phase is invalid, error
    zero_phase === :INVALID && error("Unsupported zero phase reference: $(rf.zero_phase)")
    
    # If zero phase is nothing, move on
    !isnothing(zero_phase) && (acc[:zero_phase] = zero_phase)
    
    # Frequency / harmonic number
    if (rf.rate != 0 && rf.rate_meaning != RateMeaning.Indeterminate)
        field = get(RATE_MEANING_TO_PALS_MAP, rf.rate_meaning, :INVALID)
        
        # If field is invalid, error
        field === :INVALID && error("Unsupported rate meaning: $(rf.rate_meaning)")
        
        acc[field] = rf.rate
    end
    
    # Cavity type
    rf.traveling_wave && (acc[:cavity_type] = :TRAVELING_WAVE)
    
    isempty(acc) || (parameter_info[:RFP] = acc)
    return
end

#= BMultipoleParams Overload =#
function add_parameter_group!(parameter_info::OrderedDict, parameter_group::BMultipoleParams)
    acc = OrderedDict()
    
    # This code is adapted from the override of `show()` in multipole.jl
    for bm in parameter_group
        if bm.n != 0
            key = BMULTIPOLE_STRENGTH_INVERSE_MAP[(true, bm.order, bm.normalized, bm.integrated)]
            acc[key] = bm.n
        end

        if bm.s != 0
            key = BMULTIPOLE_STRENGTH_INVERSE_MAP[(false, bm.order, bm.normalized, bm.integrated)]
            acc[key] = bm.s
        end

        if bm.tilt != 0
            key = BMULTIPOLE_TILT_INVERSE_MAP[bm.order]
            acc[key] = bm.tilt
        end
    end
    # End adapted code

    # If `acc` is empty, don't do anything
    isempty(acc) || (parameter_info[:MagneticMultipoleP] = acc)

    return
end

#= BMultipoleParams Overload =#
function add_parameter_group!(parameter_info::OrderedDict, parameter_group::BMultipoleParams)
    acc = OrderedDict()
    
    # This code is adapted from the override of `show()` in multipole.jl
    for bm in parameter_group
        if bm.n != 0
            key = BMULTIPOLE_STRENGTH_INVERSE_MAP[(true, bm.order, bm.normalized, bm.integrated)]
            acc[key] = bm.n
        end

        if bm.s != 0
            key = BMULTIPOLE_STRENGTH_INVERSE_MAP[(false, bm.order, bm.normalized, bm.integrated)]
            acc[key] = bm.s
        end

        if bm.tilt != 0
            key = BMULTIPOLE_TILT_INVERSE_MAP[bm.order]
            acc[key] = bm.tilt
        end
    end
    # End adapted code

    # If `acc` is empty, don't do anything
    isempty(acc) || (parameter_info[:MagneticMultipoleP] = acc)

    return
end

"""
    Internal: format_beamline(line::Vector{LineElement}, branch::Branch)

Creates a PALS-formatted nested dictionary with the name of `branch` and a `line`
of the elements of all the SciBmad-beamlines in this SciBmad-branch.

## Arguments
- `line`  -- A vector containing all the `LineElement`s in `branch` in order
- `branch` -- The `Branch` this is trying to format
"""
function scibmad_branch_to_pals_beamline(line::Vector{LineElement}, branch::Branch)
    return OrderedDict(
        Symbol(branch.name) => OrderedDict(
            :kind => :Beamline
            :line => line
        )
    )
end

"""
    Internal: format_beamline(line::Vector{LineElement}, branch::Branch)

Creates a PALS-formatted nested dictionary with the name of `branch` and a `line`
of the elements of all the SciBmad-beamlines in this SciBmad-branch.

## Arguments
- `line`  -- A vector containing all the `LineElement`s in `branch` in order
- `branch` -- The `Branch` this is trying to format
"""
function scibmad_lattice_to_pals_lattice(beamlines::Vector{Branch}, lattice::Lattice)
    branches = []
    ret = OrderedDict(
        Symbol(lattice.name) => OrderedDict(
            :kind => :Lattice
            :branches => branches
        )
    )

    for beamline in beamlines
        push!(branches, Symbol(beamline.name))
    end
end