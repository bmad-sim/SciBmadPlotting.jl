# SciBmadSimUtils.jl

[![CI](https://github.com/bmad-sim/SciBmadSimUtils.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/bmad-sim/SciBmadSimUtils.jl/actions/workflows/CI.yml)

Simulation utilities for the [SciBmad](https://github.com/bmad-sim/SciBmad.jl) ecosystem.

Currently this package holds the translator from SciBmad lattices, built with
[Beamlines.jl](https://github.com/bmad-sim/Beamlines.jl), to the
[PALS](https://github.com/pals-project/pals) (Particle Accelerator Lattice Standard) format.

## Installation

```julia
import Pkg
Pkg.add(url="https://github.com/bmad-sim/SciBmadSimUtils.jl")
```

## SciBmad to PALS translation

Two functions are exported:

- `to_pals(x)` returns the PALS tree as a nested dictionary (`OrderedDict`). Use it to inspect
  or modify the result before writing it.
- `write_pals(filename, x)` writes the PALS tree to a YAML file. By convention, PALS files
  have the extension `.pals.yaml`.

`x` can be a `Lattice`, a `Branch` or a `Beamline`.

```julia
using Beamlines, SciBmadSimUtils

qf = Quadrupole(name="qf", L=0.5, Kn1=0.36)
d  = Drift(name="d", L=1.0)
qd = Quadrupole(name="qd", L=0.5, Kn1=-0.36)
b  = SBend(name="b", L=2.0, g_ref=0.01, Kn0=0.01)

fodo = Beamline([qf, d, b, d, qd, d, b, d], species_ref=Species("electron"), E_ref=18e9)
lattice = Lattice([fodo], name="fodo_lattice")

write_pals("fodo.pals.yaml", lattice)
```

This writes:

```yaml
PALS:
  version: ~
  facility:
    - b1_begin:
        kind: "BeginningEle"
        ReferenceP:
          species_ref: "electron"
          E_tot_ref: 1.8e10
    - qf:
        kind: "Quadrupole"
        length: 0.5
        MagneticMultipoleP:
          Kn1: 0.36
    - d:
        kind: "Drift"
        length: 1.0
    - b:
        kind: "Bend"
        length: 2.0
        BendP:
          g_ref: 0.01
        MagneticMultipoleP:
          Kn0: 0.01
    - qd:
        kind: "Quadrupole"
        length: 0.5
        MagneticMultipoleP:
          Kn1: -0.36
    - b1:
        kind: "BeamLine"
        line:
          - "b1_begin"
          - "qf"
          - "d"
          - "b"
          - "d"
          - "qd"
          - "d"
          - "b"
          - "d"
    - fodo_lattice:
        kind: "Lattice"
        branches:
          - "b1"
```

For a `Branch` or `Beamline`, the lattice name can be set with the `lattice_name` keyword
argument. For a `Beamline`, the branch name can also be set with the `name` keyword argument.

### Lattice structure

- Each element is defined once at the start of the `facility`, then each branch becomes a
  PALS `BeamLine`, and the `Lattice` comes last.
- Each branch `BeamLine` starts with a `BeginningEle` element named `<branch>_begin`. It holds
  the reference species and energy of the first `Beamline` of the branch in a `ReferenceP`
  group.
- If a later `Beamline` in a branch sets the reference species or energy, a `ReferenceChange`
  element named `<branch>_ref_change` is put at its start.
- A reference energy given as a magnetic rigidity (`p_over_q_ref`, `dp_over_q_ref`) is written
  as the reference momentum `pc_ref` computed by Beamlines. PALS has no rigidity parameter.
- Unnamed branches are named `b<N>`. A lone `Branch` or `Beamline` defaults to `branch` or
  `beamline`. An unnamed lattice is named `lattice`.

### Element names

- PALS names may contain only letters, digits and underscores and must not start with a
  digit. Other characters are replaced by `_`, so `q.1` becomes `q_1`.
- Unnamed elements get a name from their PALS kind, e.g. `drift`, `drift_1`. Copies of the
  same unnamed element share one name.
- Names must be unique in a PALS file. Where a generated name clashes, `_<N>` is appended.
- Several elements can share a name but have different parameters. The first one is the
  definition. Each later one appears in the `line` with only the parameters that differ.
  Parameters it does not have are set to `null` (unset). For example:

  ```yaml
  line:
    - "d"
    - d:
        length: 2
  ```

### Element kinds

SciBmad kinds become PALS kinds as follows. Any other kind is written unchanged.

| SciBmad              | PALS                                  |
|----------------------|---------------------------------------|
| `SBend`              | `Bend`                                |
| `HKicker`, `VKicker` | `Kicker`                              |
| `BPM`                | `Instrument`                          |
| `CrabCavity`, or `RFParams` with `is_crabcavity` | `CrabCavity` |
| no kind              | `Drift` if the length is nonzero, otherwise `Marker` |

### Parameter groups

| SciBmad                | PALS                        | Notes |
|------------------------|-----------------------------|-------|
| `UniversalParams`      | `kind`, `length`, `TrackingP` | A non-default `tracking_method` goes in `TrackingP: SciBmad:` |
| `MetaParams`           | `MetaP`                     | |
| `AlignmentParams`      | `BodyShiftP`                | `tilt` → `z_rot` |
| `ApertureParams`       | `ApertureP`                 | `x1_limit`, `x2_limit`, `y1_limit`, `y2_limit` → `x_min`, `x_max`, `y_min`, `y_max`. Infinite limits are left out. `aperture_shifts_with_body` is written when `true` since the PALS default is `false`. |
| `BendParams`           | `BendP`                     | If `g_ref` is set but no dipole field (`Kn0`, `Bn0`, `Kn0L`, `Bn0L`), then `Kn0_from_g_ref: false` is written. A SciBmad bend has no field unless one is set. |
| `BMultipoleParams`     | `MagneticMultipoleP`        | Same parameter names (`Kn1`, `Bs2L`, `tilt3`, ...) |
| `EMultipoleParams`     | `ElectricMultipoleP`        | `etiltN` → `tiltN` |
| `RFParams`             | `RFP`                       | `rf_frequency` → `frequency`, `phi0` → `phase` (radians in both), `traveling_wave` → `cavity_type: TRAVELING_WAVE` |
| `PatchParams`          | `PatchP`                    | `dx`, `dy`, `dz`, `dx_rot`, `dy_rot`, `dz_rot` → `x_offset`, `y_offset`, `z_offset`, `x_rot`, `y_rot`, `z_rot`. `user_sets_length: true` is always written since a SciBmad patch length is set by the user. |
| `InitialBeamlineParams` | `ReferenceP` / `ReferenceChangeP` | See [Lattice structure](#lattice-structure) |
| `IgnoreParams`         | `aperture_active`, `SciBmad_ignore_params` | An ignored `ApertureParams` sets `ApertureP.aperture_active: false`. Other ignored groups are listed by their PALS name. |
| `BeamlineParams`       | —                           | Not written. It only records where an element sits in a `Beamline`. |

Parameters with default values are not written.

### SciBmad extensions

Some SciBmad parameters have no PALS equivalent. They are written as
[PALS extensions](https://pals-project.readthedocs.io/en/latest/extensions.html) whose names
start with `SciBmad_`. When any are present, the file declares the prefix in
`extension_labels`. The extensions are:

- `PatchP.SciBmad_dt`: the `dt` time offset of a patch.
- `SciBmad_ignore_params`: the ignored parameter groups (see above).
- `SciBmad_MapParams`, `SciBmad_FourPotentialParams`, `SciBmad_EMFieldParams`: these groups
  hold Julia functions, so only their string representation is written. A lattice with
  these groups cannot be fully reconstructed from the PALS file.

### Deferred expressions

`DefExpr`s are evaluated, using the `Context` of the lattice, when the translation is done.
The PALS file therefore holds numbers, not expressions. Values must be real numbers: for
lattices with GTPSA or automatic differentiation types, use `scalarize` first.
