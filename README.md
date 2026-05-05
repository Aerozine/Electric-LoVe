# LoVe-in-HV

Finite-element model for the ELEC0041 high-voltage cable assignment. The model
keeps the required three-phase adaptation of the Nexans-style datasheet: three
circular phase cores with semiconductor and insulation layers, filling, inner
sheath, optional circular steel armour/shield disks, outer sheath and a
suspended seawater environment.

The mesh is generated with the Gmsh Python API in `geometry.py`. It uses
OpenCASCADE fragments plus distance/threshold background mesh fields, following
the approach of Gmsh tutorial `t10.py`, so the conductor, semiconductor and
defect interfaces are refined without over-refining the full seawater domain.
Parameters, physical group ids and GetDP material laws are generated from
`cable.toml`.
`model.geo` is kept as a tutorial-style reference, but the active workflow uses
`geometry.py` so the armour disks, defect toggle and per-curve mesh sizes remain
easy to control from Python.

## Configuration

The main switch is:

```toml
[general]
shield = true
```

When `shield = false`, the circular metallic armour/shield layers and outer
sheath are omitted from the geometry and from the conducting magnetic/thermal
loss domains. The three phase cores remain unchanged.

The environment is a suspended subsea cable:

```toml
[environment]
medium = "seawater"
cable_depth = 1.2
water_depth = 30.0
salinity_surface_psu = 34.0
salinity_bottom_psu = 36.0
conductivity_surface = 4.2
conductivity_bottom = 5.0
```

The GetDP material law uses a vertical conductivity gradient between the surface
and bottom values. The cable is not buried in soil.

An optional air bubble defect can be enabled inside one insulation layer:

```toml
[defect]
enabled = false
phase = 0
angle = 0.7853981633974483
relative_radius = 0.65
radius = 0.00025
```

The shield armour is represented by explicit disks:

```toml
[armour]
large_count = 24
small_count = 42
```

## Setup

Install the local Python environment if needed:

```sh
make init
```

Generate `generated_common.pro`, `generated_geometry.geo`, `LoVe.msh`,
`LoVe.step` and `map.csv`:

```sh
make mesh
```

## Solves

```sh
make run_elec
make run_mag
make run_therm
make run_all
make quantities
```

Equivalent explicit GetDP commands are:

```sh
getdp LoVe.pro -msh LoVe.msh -solve Electrodynamics -pos Post_Ele -v2
getdp LoVe.pro -msh LoVe.msh -setnumber Flag_AnalysisType 1 -solve Magnetoquasistatics -pos Post_Mag -v2
getdp LoVe.pro -msh LoVe.msh -setnumber Flag_AnalysisType 2 -solve Magnetothermal -pos Post_Thermal -v2
getdp LoVe.pro -msh LoVe.msh -setnumber Flag_AnalysisType 2 -pos Post_MagTher -v2
```

`make run_therm` solves the coupled linear magneto-thermal case and then
post-processes both thermal and magnetic quantities. Temperature-dependent
conductivity is present in `LoVe.pro`; set `thermal.nonlinear = 1` in
`cable.toml` to use the Picard loop.

`make quantities` reads the `.dat` and `.pos` outputs, converts the requested
project quantities to slide-friendly units and writes `res/summary.md`.

The magnetoquasistatic solve now uses the 2D `a-v` formulation from the GetDP
coupled/circuit tutorials: the balanced phase currents are imposed as global
currents, while the local current density is computed as
`j = -sigma (d a / dt + grad v)`. This keeps skin/proximity interaction in the
phase conductors instead of forcing a uniform current density.

## Visualisation

Open the ONELAB/GetDP problem in Gmsh:

```sh
make view
```

Run and open result views directly:

```sh
make view_elec
make view_mag
make view_therm
```

These targets load `LoVe.msh` with the corresponding `.pos` files from `res/`.
The three phase insulation circles and the 24/42 armour disks can be inspected
directly in `LoVe.msh` or `LoVe.step`.

`HarmonicToTime` exports are not generated yet. The current verified outputs
remain the frequency-domain `.pos` files; add time-domain conversion only after
confirming the exact GetDP syntax for the installed version.

## Files

- `geometry.py`: active Gmsh Python geometry and mesh generator.
- `model.geo`: tutorial-style `.geo` reference kept for comparison.
- `generator.py`: TOML-to-GetDP/Gmsh shared parameter generator.
- `generated_common.pro`: generated GetDP groups, constants and material laws.
- `generated_geometry.geo`: generated Gmsh dimensions, mesh sizes and ids.
- `Lib_LoVe_Numerics.pro`: shared Jacobian and integration settings, including
  the magnetic infinite-shell Jacobian.
- `LoVe.pro`: electrodynamic, magnetoquasistatic and magnetothermal problems.
- `postprocess.py`: result extraction, unit conversion and coherence checks.
- `docs/project_answers.md`: concise answers to the assignment questions.
