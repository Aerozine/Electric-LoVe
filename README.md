# LoVe-in-HV

ELEC0041 finite-element model: three-phase subsea HV cable analysed with
electrodynamic (v), magnetoquasistatic (a–v), and coupled magneto-thermal
formulations via Gmsh + GetDP.

## Quick start

```sh
make init          # create Python venv, install gmsh / numpy
make run_all       # mesh + all three solves + field-maxima extraction
make slides        # compile slides.pdf   (requires typst ≥ 0.14)
```

## Configuration — `cable.toml`

All geometry, material, and solver parameters are in `cable.toml`.
Running `generator.py` (called by `make mesh`) writes `generated_common.pro`
and `generated_geometry.geo` from these values.

| Key | Default | Effect |
|---|---|---|
| `general.shield` | `false` | Include/omit steel armour rings |
| `defect.enabled` | `true` | Air bubble in phase-0 XLPE insulation |
| `thermal.nonlinear` | `0` | `1` = Picard iteration with σ(T) |
| `electrical.current` | `1.0` | Per-phase peak current [A] |
| `environment.medium` | `"seawater"` | σ = 4.2→5.0 S/m vertical gradient |

## Workflow

```sh
make mesh          # geometry.py → LoVe.msh + generated_common.pro
make run_elec      # electrodynamic  → res/v.pos, res/em.pos, res/C.dat …
make run_mag       # MQS             → res/az.pos, res/bm.pos, res/Rinds.dat …
make run_therm     # magneto-thermal → res/temperature.pos, res/mt_*.dat …
make postmax       # extract field maxima → res/*_max.dat, res/t_*.dat
make slides        # typst compile slides.typ → slides.pdf
```

Each `run_*` target calls `postmax.py` automatically, so `slides.pdf` always
reflects the latest results after `make slides`.

## Relation to `docs/reference.pro`

The supplied `reference.pro` uses a **stranded-coil** formulation
(`DomainS_Mag`, `Ns[]`, `Sc[]`) for the phase conductors, with
**massive** conductors (`DomainC_Mag`) reserved for the steel pipe.

This model deliberately uses a **massive a–v formulation** for the copper
conductors instead:

- Stranded imposes uniform current density → cannot capture skin effect or
  proximity losses; R_AC = R_DC by construction.
- Massive solves for the actual J distribution inside each conductor →
  R_AC > R_DC from skin/proximity effects, which is the physically correct
  result and one of the quantities asked for in the assignment.

Everything else follows the reference: same v-formulation for electrodynamics,
same `nu[]` / `sigma[]` material functions, same `F_Cos_wt_p[]` time functions.

**Additions beyond reference.pro:**

| Feature | Reference | This model |
|---|---|---|
| Phase conductor type | Stranded (Ns/Sc) | Massive (a–v) |
| Infinite elements | None (plain Vol) | VolSphShell on outer ring |
| Thermal analysis | Not present | Steady-state + Robin BC |
| Nonlinear σ(T) | Not present | Picard iteration |
| Seawater σ | Constant | Vertical salinity gradient |

## File structure

| File | Purpose |
|---|---|
| `cable.toml` | Single source of truth for all parameters |
| `geometry.py` | Gmsh Python geometry and mesh generator |
| `generator.py` | `cable.toml` → `generated_common.pro` + `generated_geometry.geo` |
| `generated_common.pro` | Auto-generated GetDP groups, constants, material laws |
| `Lib_LoVe_Numerics.pro` | Shared Jacobian (VolSphShell) + integration settings |
| `LoVe.pro` | Entry point: constraints + Include dispatch by Flag |
| `LoVe_Electrodynamics.pro` | v-formulation (Flag=0) |
| `LoVe_Magnetoquasistatics.pro` | a–v formulation (Flag=1) |
| `LoVe_Magnetothermal.pro` | Coupled a–v + heat equation (Flag=2) |
| `postmax.py` | Parse `.pos` → scalar `res/*_max.dat` for live slides |
| `slides.typ` | Typst presentation — all values read from `res/*.dat` |

## Visualisation

```sh
make view          # open Gmsh ONELAB GUI
make view_elec     # run_elec then open Gmsh with res/*.pos
make view_mag      # run_mag  then open Gmsh with res/*.pos
make view_therm    # run_therm then open Gmsh with res/*.pos
```
