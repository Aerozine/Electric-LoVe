# Remarks Fixed

- [x] Inner conductor geometry: the conductor is a true Gmsh OCC disk (`addDisk`). The previous one-layer fan mesh was not a geometry error, but it was too weak as mesh evidence. It has been improved: `geometry.py` now enforces local mesh sizes inside the copper/semiconductor/XLPE regions, and `cable.toml` is back to the finer 0.40 mm copper mesh.
- [x] The `DT`/skin-effect material has been removed from §1.8. That slide now stays in the electrodynamic part: capacitance is frequency-independent, while charging current grows with frequency.
- [x] The `R_AC/R_DC` plot was removed from §1.8. Resistance comparison remains in the MQS section (§2.7), where it belongs.
- [x] The "I imposed" and heat-source labels in the geometry SVGs are now placed outside the cable body, like the voltage labels in §1.2. Regenerated `geometry_mag.svg` and `geometry_thermal.svg`.
- [x] `slides/img/E.png` has been added to §1.8.
- [x] The defect study has been rerun with the refined mesh. The nominal 250 µm bubble is sampled by 58 elements; even the 100 µm bubble has 8 sampled elements. Rated-voltage fields remain above 3 MV/m, so the PD conclusion is not just from the old coarse mesh.
- [x] §1.4 now uses the electrodynamic convergence plot only; the thermal `Delta T` convergence plot is no longer shown inside part 1.
- [x] §3.4 now shows relative temperature-rise increase versus frequency instead of a misleading large scaled `Delta T`.
- [x] §3.7--3.8 now shows relative residual only.
- [x] Numeric display has been tightened to at most 3 decimals in the slide helpers.

## Assignment Coverage Check

All numbered assignment questions are represented in the slide deck:

- §1 covers electrodynamic geometry/materials, domain/equations/BCs, simplifications, mesh refinement, defect study, current densities and conservation, capacitance/frequency dependence, and design improvements.
- §2 covers MQS formulation/domain/BCs, simplifications, mesh quality, B field, current density, Joule losses, AC resistance vs DC resistance, inductance, mesh refinement, and loss-reduction improvements.
- §3 covers magneto-thermal equations/coupling, thermal domain/BCs/cooling, mesh refinement, temperature distribution and hotspot, surrounding temperature boundary, nonlinear conductivity, Picard convergence, and linear/nonlinear impact.

Remaining submission-risk item: the assignment also asks for several explicit field-map figures. The deck includes representative field figures and all scalar results, but a strict reading still expects separate potential, displacement-current, magnetic-flux, current-density, temperature, surrounding-temperature, and nonlinear comparison maps as standalone slides or appendix figures.
