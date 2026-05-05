# ELEC0041 Project Answers

This note answers the questions from `project2026.pdf` for the current
LoVe-in-HV model. The checked configuration is a three-phase adaptation of
the datasheet cable, suspended in seawater, with the values currently set in
`cable.toml` (`shield = false`, `defect.enabled = true` at the time of this
run), `f = 50 Hz`, `I = 1 A` peak per phase and
`VrmsLL = 3 kV`.

## Model Definition

The geometry contains three circular copper phase conductors, semiconductor
layers, polyethylene insulation, filling, an inner sheath, two explicit armour
wire rings, an outer sheath, a finite seawater disk and an outer infinite
magnetic shell. The armour rings are modeled as 24 large steel disks and 42
small steel disks when `shield = true`. The active mesh generator is
`geometry.py`, using the Gmsh Python API, OpenCASCADE fragments and
distance/threshold background mesh fields based on Gmsh tutorial `t10.py`.

The cable is suspended in seawater, not buried. The environmental conductivity
is a realistic vertical salinity proxy:

`sigma_water(y) = sigma_surface + (sigma_bottom - sigma_surface) *
((R_environment - y) / (2 R_environment))`

with 34 PSU / 4.2 S/m near the top and 36 PSU / 5.0 S/m near the bottom. The
thermal ambient is 20 degC.

## 1. Electrodynamic Analysis

1. Geometry and materials: copper conductors, semiconductor screens, PE/XLPE-like
insulation and sheaths, steel armour, and conductive seawater are defined in
`cable.toml` and emitted into `generated_common.pro`. The three-core layout is
an assignment-driven simplification of the datasheet, which originally includes
non-power elements.

2. Domain, equations and boundary conditions: the electric problem solves
`div((sigma + j omega epsilon) grad v) = 0` on cable solids plus seawater. The
three conductors are assigned balanced phase voltages; passive conductors and
the outer boundary are grounded. The domain is truncated at the outer seawater
disk.

3. Geometry simplifications: stranded conductors are homogenized as circular
copper disks; small manufacturing details are omitted; the armour is kept as
explicit disks because it materially affects magnetic losses and shielding. This
keeps the important radial field layers without a full CAD-level cable model.

4. Mesh refinement: sizes are set per physical-boundary curve. The finest
settings are used on conductor/semiconductor/defect curves; coarser sizes are
used in seawater and at the outer boundary. The current reference mesh quality
is checked with Gmsh `minSICN`; the pathological tangent slivers were removed by
adding core and armour clearances.

5. Insulation defect: `defect.enabled = true` inserts an air bubble in the
selected insulation. Compare `res/em.pos` and `res/dm.pos` with the default
case. The defect concentrates the electric field at the bubble/insulation
interface; whether it withstands the defect must be decided against the
manufacturer dielectric stress limit for the chosen cable voltage class.

6. Resistive and displacement currents: resistive, displacement and total
electric current density maps are written to `res/jr.pos`, `res/jd.pos`,
`res/jt.pos` and their norm files `res/jrm.pos`, `res/jdm.pos`, `res/jtm.pos`.
Current conservation is enforced by the weak form; the scalar summary reports
the magnetic current-balance residual.

7. Capacitance: the code computes capacitance from electric energy,
`C_phase = 2 We / (3 |V_phase|^2)`, written to `res/C.dat` in F/m. Convert to
uF/km by multiplying by `1e9`. A simple analytical comparison is the coaxial
estimate `C' = 2 pi epsilon / ln(r_insulation/r_semiconductor)`, which assumes
one isolated round core, homogeneous dielectric and a perfect cylindrical
return screen. In linear materials the capacitance is essentially frequency
independent; only the loss tangent/current split changes with frequency.

8. Design improvements: reduce peak electric stress by increasing insulation
thickness, smoothing conductor/screen interfaces, eliminating air voids and
increasing phase spacing. Quantitatively, compare the maximum `|E|` in
`res/em.pos` before and after changing insulation radius or defect size.

## 2. Magnetoquasistatic Analysis

1. Domain, equations and boundary conditions: the magnetic model solves the 2D
`a-v` magnetoquasistatic formulation from the GetDP coupled/circuit tutorials
on cable solids plus seawater. Phase conductors have imposed balanced global
currents; passive conducting regions have zero voltage drop. The local current
density is computed as `j = -sigma (d a / dt + grad v)`, so phase conductors
are not forced to have uniform current density. The outer shell uses the
`VolSphShell` infinite-domain Jacobian and a zero vector-potential constraint
on the outside boundary.

2. Geometry simplifications: conductors are homogenized circular copper
regions; strand-level details are omitted, but the FE formulation still solves
the local current distribution in the copper cross-section. The armour disks
are explicit because they are conductive and magnetic.

3. Mesh quality: Gmsh quality is checked after meshing. The current generator
uses clearances and per-curve sizes to avoid high-aspect-ratio elements near
tangent circles.

4. Magnetic flux density: `res/b.pos` and `res/bm.pos` provide vector and norm
maps of `B` inside and around the cable.

5. Current density: `res/jz_inds.pos` and `res/jm.pos` provide induced/source
current density maps in conducting regions.

6. Joule losses: total, phase-conductor and passive-conductor losses are
written to `res/losses_total.dat`, `res/losses_phase.dat` and
`res/losses_passive.dat` in W/m. Numerically the same value is kW/km.

7. AC resistance: `res/Rinds.dat` gives phase AC resistance in Ohm/m; multiply
by 1000 for Ohm/km. Compare with `Rdc = 1 / (sigma_copper A)` per meter. At
50 Hz and the present small conductor, AC resistance is close to DC resistance;
armour/semiconductor losses are reported separately as induced losses.

8. Inductance: `res/Linds.dat` gives `-Im(U/I)/omega` in H/m; multiply by
`1e6` for mH/km. `res/L.dat` also gives an energy-based inductance. In linear
materials inductance is weakly frequency dependent; it can vary when skin,
proximity and magnetic shielding change the current distribution.

9. Mesh refinement: repeat the solve with smaller conductor, semiconductor and
armour sizes in `[mesh]`; compare `R`, `L`, losses and peak `B`. The final slide
should show convergence of these scalar quantities.

10. Loss-reduction design improvements: increase conductor area, reduce steel
armour conductivity/permeability, increase phase spacing or use nonmagnetic
armour. Quantify by rerunning and comparing `res/losses_*.dat` and
`res/Rinds.dat`.

## 3. Coupled Magneto-Thermal Analysis

1. Equations and heat source: the magnetic problem computes time-averaged Joule
loss density from the same `a-v` current density used in the magnetic solve:
`Q = 0.5 sigma |dA/dt + grad v|^2` in conducting regions. The thermal problem
solves `-div(kappa grad T) = Q` using those losses as heat source. The GetDP
thermal formulation uses `<a>[...]` around magnetic quantities where required.

2. Domain and boundary conditions: the thermal domain is cable solids plus the
finite seawater disk. Cooling is represented by a Robin boundary condition
`-kappa grad(T).n = h (T - T0)` on the finite seawater boundary
`Thermal_boundary`, with `T0 = 20 degC` and `h = 20 W/(m2 K)`. The magnetic
infinite shell is not part of the thermal domain.

3. Mesh refinement: refine heat-source regions first: copper, semiconductors
and armour. Compare temperature fields and total losses between meshes.

4. Cable temperature: `res/temperature.pos` gives the temperature distribution.
The hottest spot should be in or near the main conducting/loss regions. The
default `I = 1 A` case is a numerical reference, not a rated-current thermal
qualification.

5. Surrounding temperature: the same `temperature.pos` includes the seawater
domain. The current 2D disk represents the local water cross-section; a literal
free water surface is not present because the cable is modeled in an unbounded
subsea environment with a vertical salinity gradient.

6. Nonlinear convergence: set `thermal.nonlinear = 1` to use
`sigma(T) = sigma0 / (1 + alpha (T - Tref))`. The Picard loop stops when both
absolute and relative residual criteria satisfy `nl_tol_abs`/`nl_tol_rel`, or
when `nl_iter_max` is reached. Mesh density can affect convergence through
loss localization and thermal gradients.

7. Impact of temperature-dependent conductivity: as temperature rises, copper
and steel conductivity decrease. This increases resistive voltage drop and can
redistribute losses, usually raising the final temperature compared with a
constant-conductivity solve at the same current. Compare nonlinear
`res/mt_*.pos`, `res/mt_Rinds.dat`, `res/mt_Linds.dat` and
`res/mt_losses_total.dat` against the linear run.

## Required Output Checklist

The implemented post-processing targets generate the required maps:

- Electric potential: `res/v.pos`
- Electric field: `res/e.pos`, `res/em.pos`
- Displacement field: `res/dm.pos`
- Resistive, displacement and total current density:
  `res/jrm.pos`, `res/jdm.pos`, `res/jtm.pos`
- Capacitance: `res/C.dat`
- Magnetic flux density: `res/b.pos`, `res/bm.pos`
- Current density: `res/jz_inds.pos`, `res/jm.pos`
- Joule losses: `res/losses_total.dat`, `res/losses_phase.dat`,
  `res/losses_passive.dat`
- AC resistance: `res/Rinds.dat`
- Inductance: `res/Linds.dat`, `res/L.dat`
- Temperature and heat source: `res/temperature.pos`, `res/heat_source.pos`
- Coupled magnetic/thermal fields: `res/mt_*.pos`, `res/mt_*.dat`

Use `make view_elec`, `make view_mag` and `make view_therm` to open the
corresponding visual results in Gmsh. Use `make quantities` to write
`res/summary.md`.

## Current Reference Scalars

After `make clean`, `make run_elec`, `make run_mag` and `make run_therm` with
the default configuration:

- Mesh quality: 9128 triangles, `minSICN = 0.4562`,
  `meanSICN = 0.9085`, 5th percentile `minSICN = 0.7001`.
- Capacitance: `1.434976013312836e-09 F/m = 1.435 uF/km`.
- Average phase AC resistance: `0.00140759 Ohm/m = 1.40759 Ohm/km`.
- Average phase inductance: `3.77023e-07 H/m = 0.377023 mH/km`.
- Total Joule losses: `0.002111378363481502 W/m`, numerically
  `0.002111378363481502 kW/km`.
- Current-balance residual from `res/Iinds.dat`: `4.86e-13 A`.
- Coupled magnetothermal temperature range at `I = 1 A`:
  `20.0001` to `20.0021 degC`.
