#= A minimal YAML writer for PALS trees.

General YAML writers quote every string and write every list in block form. PALS files are
easier to read with unquoted names and with BeamLine `line`s in the concise flow form
`[a, b, c]`, so the PALS tree is written here instead. =#

"""
Maximum length of a line in a flow sequence before it is continued on the next line.
"""
const YAML_LINE_WIDTH = 100

"""
Strings that must be quoted since YAML would read them as booleans or null when unquoted.
Compared ignoring case.
"""
const YAML_RESERVED_WORDS = ("true", "false", "yes", "no", "on", "off", "y", "n", "null")

"""
    Internal: yaml_scalar(x) -> String

Returns the YAML representation of the scalar `x`. Strings are left unquoted when
that is unambiguous: they start with a letter or underscore, contain only letters, digits,
underscores, spaces, `.`, `-` and `/`, do not end in a space, and are not reserved words.
Other strings are double-quoted.
"""
yaml_scalar(::Nothing) = "null"
yaml_scalar(x::Bool) = x ? "true" : "false"
yaml_scalar(x::Integer) = string(x)
function yaml_scalar(x::AbstractFloat)
    isnan(x) && return ".nan"
    isinf(x) && return x > 0 ? ".inf" : "-.inf"
    return repr(Float64(x))
end
yaml_scalar(x::Symbol) = yaml_scalar(String(x))
function yaml_scalar(x::AbstractString)
    if occursin(r"^[A-Za-z_][A-Za-z0-9_ .\-/]*$", x) && !endswith(x, " ") &&
       !(lowercase(x) in YAML_RESERVED_WORDS)
        return String(x)
    end
    s = replace(x, "\\" => "\\\\", "\"" => "\\\"", "\n" => "\\n", "\t" => "\\t", "\r" => "\\r")
    return "\"" * s * "\""
end

is_yaml_scalar(x) = !(x isa AbstractDict || x isa AbstractVector)

"""
    Internal: yaml_flow(x) -> String

Returns `x` in YAML flow form: `[a, b]` for vectors and `{k: v}` for dictionaries.
"""
yaml_flow(x) = yaml_scalar(x)
yaml_flow(x::AbstractVector) = "[" * join(map(yaml_flow, x), ", ") * "]"
yaml_flow(x::AbstractDict) = "{" * join(["$(yaml_scalar(k)): $(yaml_flow(v))" for (k, v) in x], ", ") * "}"

"""
    Internal: write_yaml_flow_sequence(io::IO, items::AbstractVector, column::Int, indent::Int)

Writes `items` as a flow sequence `[a, b, ...]` starting at `column`. The sequence is
continued on lines indented by `indent` spaces so no line is longer than
`YAML_LINE_WIDTH`, unless a single item is longer than that.
"""
function write_yaml_flow_sequence(io::IO, items::AbstractVector, column::Int, indent::Int)
    print(io, "[")
    column += 1
    for (i, item) in enumerate(items)
        s = yaml_flow(item) * (i == length(items) ? "]" : ",")
        if i > 1
            if column + 1 + length(s) > YAML_LINE_WIDTH
                print(io, "\n", " "^indent)
                column = indent
            else
                print(io, " ")
                column += 1
            end
        end
        print(io, s)
        column += length(s)
    end
    isempty(items) && print(io, "]")
    println(io)
end

"""
    Internal: write_yaml_value(io::IO, key, value, indent::Int, column::Int)

Writes `value`, the value of the mapping key `key` that is at indentation `indent`. The
cursor is at `column`, just after the `:` following the key. A BeamLine `line` and any
vector of scalars are written in flow form. Other vectors and dictionaries are written in
block form.
"""
function write_yaml_value(io::IO, key, value, indent::Int, column::Int)
    if value isa AbstractDict
        if isempty(value)
            println(io, " {}")
        else
            println(io)
            write_yaml_mapping(io, value, indent + 2)
        end
    elseif value isa AbstractVector
        if key == "line" || all(is_yaml_scalar, value)
            print(io, " ")
            write_yaml_flow_sequence(io, value, column + 1, indent + 2)
        else
            println(io)
            for item in value
                print(io, " "^(indent + 2), "- ")
                if item isa AbstractDict && !isempty(item)
                    write_yaml_mapping(io, item, indent + 4; first_inline=true)
                else
                    println(io, yaml_flow(item))
                end
            end
        end
    else
        println(io, " ", yaml_scalar(value))
    end
end

"""
    Internal: write_yaml_mapping(io::IO, d::AbstractDict, indent::Int; first_inline=false)

Writes `d` as a block mapping with keys indented by `indent` spaces. If `first_inline` is
`true` the first key is written at the current cursor position, as needed for a mapping
that is an item of a block sequence.
"""
function write_yaml_mapping(io::IO, d::AbstractDict, indent::Int; first_inline::Bool=false)
    for (i, (k, v)) in enumerate(d)
        key = yaml_scalar(k)
        (i == 1 && first_inline) || print(io, " "^indent)
        print(io, key, ":")
        write_yaml_value(io, k, v, indent, indent + length(key) + 1)
    end
end

"""
    Internal: write_yaml(io::IO, d::AbstractDict)

Writes the PALS tree `d` to `io` as YAML.
"""
write_yaml(io::IO, d::AbstractDict) = write_yaml_mapping(io, d, 0)
