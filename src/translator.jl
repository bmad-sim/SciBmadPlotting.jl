"""
    Internal: element_to_pals(lattice::Lattice, new_file_name::String)

Return a dictionary whose single key is `line_element`'s name, storing another dictionary
whose keys are `line_element`'s fields. This is the format desired by PALS.

This function is used as a helper to `scibmad_to_pals()` to create the entry for a single
accelerator element, along with all parameters associated with it.

## Arguments
- `line_element`    -- The `LineElement` being formatted into PALS.
"""
function element_to_pals(line_element::LineElement)
    # Set up the accumulator
    parameter_info = OrderedDict()
    root = OrderedDict(
        line_element.name => parameter_info
    )

    # Populate `parameter_info`
    for (group_type, group) in getfield(line_element, :pdict)
        # For every group of parameters in the element...

        if (group_type == UniversalParams) 
            # `UniversalParams` are a special case
            parameter_info[:kind] = Symbol(group.kind)
            if (group.L != 0)
                parameter_info[:length] = group.L
            end

        else 
            # Handle parameter groups with their overloads
            add_parameter_group!(parameter_info, group)

        end
    end

    return root
end

"""
    Internal: lattice_to_pals(lattice::Lattice, new_file_name::String)

Creates a YAML file named "`new_file_name`.yaml" in PALS format representing `lattice`

This function converts SciBmad style `Lattice` elements into PALS-formatted YAML files.

## Arguments
- `lattice`         -- The SciBmad `Lattice` that will be turned into a PALS YAML file.
- `new_file_name`   -- The `String` which comes before ".pals.yaml" that the resulting file will be named.
"""
function lattice_to_pals(lattice::Lattice, new_file_name::String) 
    # User-facing variables that are directly used in the translation
    io = open(new_file_name * ".pals.yaml", "w")    # Create a new PALS yaml file in write mode
    pals = OrderedDict( # The root node of the PALS object
        :version => :null
    )    
    facility = []   # The subnode for the components of the accelerator

    # "Support" backend variables
    created_elements = Set{Symbol}()    # Keeps track of element names
    beamlines = []  # An accumulator for the PALS-beamlines

    # Every element in the facility is defined first
    for branch in lattice.branches
        # For every SciBmad-branch/PALS-beamline in the lattice...

        line = [] # Accumulator for the elements in a SciBmad-branch/PALS-beamline
        for beamline in branch.beamlines
            # For every SciBmad-beamline in the branch...

            for line_element in beamline.line
                # For every element in the beamline...

                if (!(line_element.name in created_elements))
                    # Translate the line element into PALS if it hasn't already been
                    formatted_element = element_to_pals(line_element)

                    # Add the element's name to the set of created elements
                    push!(created_elements, line_element.name)

                    # Push the element onto the overall lattice's facility
                    push!(facility, formatted_element)
                end

                # Push the element onto the beamline's line
                push!(line, line_element.name)
            end
        end

        push!(beamlines, scibmad_branch_to_pals_beamline(line, branch))
    end

    # Add all the beamlines after the elements
    for beamline in beamlines
        push!(facility, beamline)
    end

    # Add the lattice after the beamlines

end