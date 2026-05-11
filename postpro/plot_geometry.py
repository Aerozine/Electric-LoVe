#!/usr/bin/env python3
"""
plot_geometry.py
----------------
Draws the 2-D cross-section of the cable for each analysis formulation
(Electrodynamic, MQS, Thermal) with colour-coded regions and boundary-
condition annotations.

Outputs:
  res/geometry_electro.svg
  res/geometry_mag.svg
  res/geometry_thermal.svg

Each figure has two panels:
  Left  -- full cross-section (cable + seawater environment + VolSphShell ring)
  Right -- zoomed view of the three-phase cable bundle with layer labels

Usage
-----
    python3 plot_geometry.py          # or ./gmsh/bin/python plot_geometry.py
"""

import math
import os
import re

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import Circle, FancyArrowPatch, Arc
from matplotlib.collections import PatchCollection
import matplotlib.patheffects as pe
import numpy as np

os.makedirs("slides/graphs", exist_ok=True)

# --------------------------------------------------------------------------- #
#  Read cable.toml                                                              #
# --------------------------------------------------------------------------- #
def toml_val(text, key):
    m = re.search(rf'^{key}\s*=\s*([\d.e+\-]+)', text, re.MULTILINE)
    return float(m.group(1)) if m else None

with open("cable.toml") as f:
    cfg_text = f.read()

# All in metres
def mm(x): return x * 1e-3

r_cond  = mm(toml_val(cfg_text, "conductor_diameter")              / 2)
r_semi  = mm(toml_val(cfg_text, "semiconductor_outer_diameter")    / 2)
r_ins   = mm(toml_val(cfg_text, "insulation_outer_diameter")       / 2)
r_layup = mm(toml_val(cfg_text, "layup_outer_diameter")            / 2)
r_wrap  = mm(toml_val(cfg_text, "wrapping_outer_diameter")         / 2)
r_is    = mm(toml_val(cfg_text, "inner_sheath_outer_diameter")     / 2)
r_os    = mm(toml_val(cfg_text, "outer_sheath_outer_diameter")     / 2)
r_env   = mm(toml_val(cfg_text, "environment_diameter")            / 2)
r_fibre = mm(toml_val(cfg_text, "fibre_unit_outer_diameter")       / 2)
clr     = mm(toml_val(cfg_text, "core_clearance"))

# VolSphShell outer boundary (25 % beyond environment)
r_inf   = r_env * 1.25

# Phase centre positions (same formula as geometry.py)
pair_radius = (2 * r_ins + clr) / math.sqrt(3)
angles = [math.pi / 2, math.pi / 2 - 2 * math.pi / 3, math.pi / 2 + 2 * math.pi / 3]
centres = [(pair_radius * math.cos(a), pair_radius * math.sin(a)) for a in angles]

PHASE_LABELS = ["A", "B", "C"]
PHASE_VOLTAGES = ["$V_0 e^{j\\cdot 0}$", "$V_0 e^{-j2\\pi/3}$", "$V_0 e^{+j2\\pi/3}$"]
PHASE_CURRENTS = ["$I_A$", "$I_B$", "$I_C$"]

# --------------------------------------------------------------------------- #
#  Colour palette                                                               #
# --------------------------------------------------------------------------- #
COLORS = {
    "seawater":      "#d0eaf7",
    "vss_ring":      "#e8f5ff",   # VolSphShell hatch background
    "outer_sheath":  "#c8c8c8",
    "armour":        "#9e9e9e",
    "inner_sheath":  "#dddddd",
    "filling":       "#f5f0dc",
    "layup_disk":    "#f5f0dc",
    "xlpe":          "#fff8c0",
    "semi":          "#b0b0b0",
    "copper":        "#e07b39",
    "fibre":         "#4a90d9",
    "defect":        "white",
    # BC annotation colours
    "bc_dirichlet":  "#c1121f",
    "bc_neumann":    "#0f6e84",
    "bc_robin":      "#2d6a4f",
    "bc_source":     "#e8a838",
    "bc_current":    "#7b2d8b",
}


# --------------------------------------------------------------------------- #
#  Drawing helpers                                                              #
# --------------------------------------------------------------------------- #
def draw_full_cross_section(ax, mode="electro"):
    """Draw full cable + environment cross-section.  mode: electro|mag|thermal."""
    ax.set_aspect("equal")
    ax.set_xlim(-r_inf * 1.12, r_inf * 1.12)
    ax.set_ylim(-r_inf * 1.12, r_inf * 1.12)
    ax.set_facecolor(COLORS["seawater"])

    # VolSphShell ring (hatched)
    vss = Circle((0, 0), r_inf, fc=COLORS["vss_ring"], ec="#aaaacc",
                 lw=1.2, ls="--", zorder=1)
    env = Circle((0, 0), r_env, fc=COLORS["seawater"], ec="#555577",
                 lw=1.5, zorder=2)
    ax.add_patch(vss)
    ax.add_patch(env)

    # Inner sheath
    ax.add_patch(Circle((0, 0), r_is, fc=COLORS["inner_sheath"],
                         ec="#888", lw=0.8, zorder=3))
    # Layup / filling disk
    ax.add_patch(Circle((0, 0), r_layup, fc=COLORS["filling"],
                         ec="#aaa", lw=0.8, zorder=4))

    # Each phase
    for i, (cx, cy) in enumerate(centres):
        ax.add_patch(Circle((cx, cy), r_ins,  fc=COLORS["xlpe"],   ec="#c8b400", lw=0.8, zorder=5))
        ax.add_patch(Circle((cx, cy), r_semi, fc=COLORS["semi"],   ec="#666",    lw=0.5, zorder=6))
        ax.add_patch(Circle((cx, cy), r_cond, fc=COLORS["copper"], ec="#a05010", lw=0.7, zorder=7))
        # Phase label
        ax.text(cx, cy, PHASE_LABELS[i], ha="center", va="center",
                fontsize=14, fontweight="bold", color="white", zorder=10)

    # VolSphShell hatch overlay
    theta = np.linspace(0, 2 * math.pi, 200)
    r_h = (r_env + r_inf) / 2
    ax.fill_between(r_env * np.cos(theta), r_env * np.sin(theta),
                    r_inf * np.cos(theta), alpha=0)
    # Draw ring as hatched patch
    ring_patch = mpatches.Wedge((0, 0), r_inf, 0, 360,
                                width=r_inf - r_env,
                                fc="none", ec="#9999cc", lw=0.8,
                                hatch="///", alpha=0.35, zorder=2)
    ax.add_patch(ring_patch)

    # ---------------------------------------------------------------- BCs ----
    if mode == "electro":
        _add_electro_bcs(ax)
    elif mode == "mag":
        _add_mag_bcs(ax)
    elif mode == "thermal":
        _add_thermal_bcs(ax)

    ax.set_xlabel("x  (m)", fontsize=12)
    ax.set_ylabel("y  (m)", fontsize=12)
    ax.tick_params(labelsize=11)
    # Axis format in mm
    from matplotlib.ticker import FuncFormatter
    ax.xaxis.set_major_formatter(FuncFormatter(lambda x, _: f"{x*1000:.0f}"))
    ax.yaxis.set_major_formatter(FuncFormatter(lambda x, _: f"{x*1000:.0f}"))
    ax.set_xlabel("x  (mm)", fontsize=12)
    ax.set_ylabel("y  (mm)", fontsize=12)


def draw_zoomed_cable(ax, mode="electro"):
    """Draw zoomed view of the cable bundle with layer annotations."""
    ax.set_aspect("equal")
    zoom = r_is * 1.15
    ax.set_xlim(-zoom, zoom)
    ax.set_ylim(-zoom, zoom)
    ax.set_facecolor(COLORS["filling"])

    # Inner sheath rim
    ax.add_patch(Circle((0, 0), r_is, fc=COLORS["inner_sheath"],
                         ec="#888", lw=1.0, zorder=2))
    # Filling
    ax.add_patch(Circle((0, 0), r_layup, fc=COLORS["filling"],
                         ec="#aaa", lw=0.8, zorder=3))

    for i, (cx, cy) in enumerate(centres):
        ax.add_patch(Circle((cx, cy), r_ins,  fc=COLORS["xlpe"],   ec="#c8b400", lw=0.8, zorder=4))
        ax.add_patch(Circle((cx, cy), r_semi, fc=COLORS["semi"],   ec="#666",    lw=0.5, zorder=5))
        ax.add_patch(Circle((cx, cy), r_cond, fc=COLORS["copper"], ec="#a05010", lw=0.7, zorder=6))
        ax.text(cx, cy, PHASE_LABELS[i], ha="center", va="center",
                fontsize=14, fontweight="bold", color="white", zorder=10)

    # Layer labels with arrows (phase 0 only to avoid clutter)
    # zoom = r_is * 1.15 ≈ 14.5 mm — all text_xy must stay within ±13 mm
    cx, cy = centres[0]
    _label_arrow(ax, cx, cy,  r_cond * 0.5,  0,
                 "Cu  (r=" + f"{r_cond*1000:.2f}" + " mm)",
                 (-0.012, 0.008), COLORS["copper"])
    _label_arrow(ax, cx, cy,  r_semi,        math.pi / 5,
                 "Semi-\nconductor", (0.0088, 0.0088), COLORS["semi"])
    _label_arrow(ax, cx, cy,  r_ins,         math.pi / 3,
                 "XLPE ins.", (0.0015, 0.013), "#c8a800")
    _label_arrow(ax, 0, 0, r_layup, math.pi * 0.12,
                 "PE filling", (0.010, -0.005), "#a09060")
    _label_arrow(ax, 0, 0, r_is,    math.pi * 0.05,
                 "Inner sheath", (0.008, -0.010), "#888888")

    if mode == "electro":
        _add_zoomed_electro_labels(ax)
    elif mode == "mag":
        _add_zoomed_mag_labels(ax)
    elif mode == "thermal":
        _add_zoomed_thermal_labels(ax)

    from matplotlib.ticker import FuncFormatter
    ax.xaxis.set_major_formatter(FuncFormatter(lambda x, _: f"{x*1000:.0f}"))
    ax.yaxis.set_major_formatter(FuncFormatter(lambda x, _: f"{x*1000:.0f}"))
    ax.set_xlabel("x  (mm)", fontsize=12)
    ax.set_ylabel("y  (mm)", fontsize=12)
    ax.tick_params(labelsize=11)


def _label_arrow(ax, cx, cy, r, angle, text, text_xy, color):
    """Draw a small arrow from the edge of a circle to a label."""
    px = cx + r * math.cos(angle)
    py = cy + r * math.sin(angle)
    ax.annotate(text, xy=(px, py), xytext=text_xy,
                fontsize=11, color=color, fontweight="bold",
                arrowprops=dict(arrowstyle="->", color=color, lw=0.9),
                bbox=dict(boxstyle="round,pad=0.15", fc="white", ec=color, alpha=0.85, lw=0.7))


# --------------------------------------------------------------------------- #
#  BC annotation helpers                                                        #
# --------------------------------------------------------------------------- #
def _outer_bc_label(ax, text, color, y_offset_frac=0.04, ha="center"):
    """Place a BC label just outside the outer VolSphShell circle."""
    r_label = r_inf * (1.0 + y_offset_frac)
    ax.text(0, r_label, text, ha=ha, va="bottom", fontsize=11,
            color=color, fontweight="bold",
            bbox=dict(boxstyle="round,pad=0.3", fc="white", ec=color, alpha=0.9, lw=1.0))


def _add_electro_bcs(ax):
    # Outer boundary: v = 0
    _outer_bc_label(ax, "$v = 0$  (Dirichlet)", COLORS["bc_dirichlet"])
    # Label outer circle in red
    theta = np.linspace(0, 2 * math.pi, 200)
    ax.plot(r_env * np.cos(theta), r_env * np.sin(theta),
            color=COLORS["bc_dirichlet"], lw=2.0, zorder=8, label="$v=0$ (env. boundary)")

    # Phase conductors: v = V_k
    # Label text placed outside the outer sheath (r_os) in the seawater region
    for i, (cx, cy) in enumerate(centres):
        angle = angles[i] + math.pi  # point outward from centre
        px = cx + r_cond * 1.1 * math.cos(angles[i])
        py = cy + r_cond * 1.1 * math.sin(angles[i])
        lx = r_os * 1.6 * math.cos(angles[i])
        ly = r_os * 1.6 * math.sin(angles[i])
        ax.annotate(PHASE_VOLTAGES[i], xy=(px, py), xytext=(lx, ly),
                    fontsize=14, color=COLORS["bc_source"], fontweight="bold",
                    ha="center", va="center",
                    arrowprops=dict(arrowstyle="->", color=COLORS["bc_source"], lw=1.0),
                    bbox=dict(boxstyle="round,pad=0.2", fc="white",
                              ec=COLORS["bc_source"], alpha=0.9, lw=0.8),
                    zorder=12)
        # Highlight conductor boundary
        circ = Circle((cx, cy), r_cond, fc="none", ec=COLORS["bc_source"],
                      lw=2.2, zorder=9)
        ax.add_patch(circ)

    # VolSphShell label
    ax.text(r_inf * 0.72, r_inf * 0.72,
            "VolSphShell\n(maps to $\\infty$)",
            fontsize=14, color="#5555aa", ha="center", va="center",
            bbox=dict(boxstyle="round,pad=0.2", fc="#eeeeff", ec="#9999cc",
                      alpha=0.85, lw=0.7), zorder=11)


def _add_mag_bcs(ax):
    # Outer: a_z = 0
    theta = np.linspace(0, 2 * math.pi, 200)
    ax.plot(r_env * np.cos(theta), r_env * np.sin(theta),
            color=COLORS["bc_neumann"], lw=2.0, zorder=8,
            label="$a_z=0$ (Dirichlet B)")
    _outer_bc_label(ax, "$a_z = 0$  (Dirichlet)", COLORS["bc_neumann"])

    # Phase conductors: imposed current I_k
    for i, (cx, cy) in enumerate(centres):
        px = cx + r_cond * 1.1 * math.cos(angles[i])
        py = cy + r_cond * 1.1 * math.sin(angles[i])
        # Keep source labels outside the cable body, matching the electro plot.
        lx = r_os * 1.6 * math.cos(angles[i])
        ly = r_os * 1.6 * math.sin(angles[i])
        ax.annotate(PHASE_CURRENTS[i] + " imposed", xy=(px, py),
                    xytext=(lx, ly),
                    fontsize=14, color=COLORS["bc_current"], fontweight="bold",
                    ha="center", va="center",
                    arrowprops=dict(arrowstyle="->", color=COLORS["bc_current"], lw=1.0),
                    bbox=dict(boxstyle="round,pad=0.2", fc="white",
                              ec=COLORS["bc_current"], alpha=0.9, lw=0.8),
                    zorder=12)
        circ = Circle((cx, cy), r_cond, fc="none", ec=COLORS["bc_current"],
                      lw=2.2, zorder=9)
        ax.add_patch(circ)

    # VolSphShell label
    ax.text(r_inf * 0.72, r_inf * 0.72,
            "VolSphShell\n(maps $\\mathbf{B}\\to 0$ at $\\infty$)",
            fontsize=14, color="#5555aa", ha="center", va="center",
            bbox=dict(boxstyle="round,pad=0.2", fc="#eeeeff", ec="#9999cc",
                      alpha=0.85, lw=0.7), zorder=11)


def _add_thermal_bcs(ax):
    # Outer: Robin BC
    theta = np.linspace(0, 2 * math.pi, 200)
    ax.plot(r_env * np.cos(theta), r_env * np.sin(theta),
            color=COLORS["bc_robin"], lw=2.0, zorder=8,
            label="Robin BC")
    _outer_bc_label(ax,
                    "$\\kappa\\partial_n T + h(T-T_0) = 0$  (Robin)",
                    COLORS["bc_robin"])

    # Conductors: heat source Q
    for i, (cx, cy) in enumerate(centres):
        px = cx + r_cond * 1.1 * math.cos(angles[i])
        py = cy + r_cond * 1.1 * math.sin(angles[i])
        # Keep heat-source labels outside the cable body, matching the electro plot.
        lx = r_os * 1.6 * math.cos(angles[i])
        ly = r_os * 1.6 * math.sin(angles[i])
        ax.annotate("$Q = \\frac{1}{2}\\sigma|\\mathbf{J}|^2$",
                    xy=(px, py), xytext=(lx, ly),
                    fontsize=14, color=COLORS["bc_source"], fontweight="bold",
                    ha="center", va="center",
                    arrowprops=dict(arrowstyle="->", color=COLORS["bc_source"], lw=1.0),
                    bbox=dict(boxstyle="round,pad=0.2", fc="white",
                              ec=COLORS["bc_source"], alpha=0.9, lw=0.8),
                    zorder=12)
        circ = Circle((cx, cy), r_cond, fc="none", ec=COLORS["bc_source"],
                      lw=2.2, zorder=9)
        ax.add_patch(circ)


def _add_zoomed_electro_labels(ax):
    # Mark semiconductor as graded-sigma layer (phase 2 at bottom-left)
    cx, cy = centres[2]
    ax.annotate("$\\sigma = 2$ S/m\n(field grading)", xy=(cx - r_semi*0.7, cy),
                xytext=(-0.011, -0.003),
                fontsize=11, color="#444",
                arrowprops=dict(arrowstyle="->", color="#444", lw=0.7),
                bbox=dict(boxstyle="round,pad=0.1", fc="white", ec="#aaa",
                          alpha=0.85, lw=0.6), zorder=12)


def _add_zoomed_mag_labels(ax):
    # Mark Cu as massive conductor (phase 1 at bottom-right)
    cx, cy = centres[1]
    ax.annotate("Massive Cu\n$\\sigma=5.96\\times10^7$ S/m",
                xy=(cx, cy), xytext=(-0.006, -0.011),
                fontsize=11, color="#444",
                arrowprops=dict(arrowstyle="->", color="#444", lw=0.7),
                bbox=dict(boxstyle="round,pad=0.1", fc="white", ec="#aaa",
                          alpha=0.85, lw=0.6), zorder=12)


def _add_zoomed_thermal_labels(ax):
    # Mark XLPE as thermal bottleneck (phase 0 at top, cy ≈ 5.9 mm)
    cx, cy = centres[0]
    ax.annotate("XLPE $\\kappa=0.46$ W/(m$\\cdot$K)\nthermal bottleneck",
                xy=(cx, cy + r_ins * 0.85), xytext=(-0.0125, -0.012),
                fontsize=11, color=COLORS["bc_robin"],
                arrowprops=dict(arrowstyle="->", color=COLORS["bc_robin"], lw=0.8),
                bbox=dict(boxstyle="round,pad=0.1", fc="white",
                          ec=COLORS["bc_robin"], alpha=0.85, lw=0.7), zorder=12)


# --------------------------------------------------------------------------- #
#  Legend helpers                                                               #
# --------------------------------------------------------------------------- #
def make_legend_patches():
    return [
        mpatches.Patch(fc=COLORS["copper"],      ec="#a05010", label="Copper conductor"),
        mpatches.Patch(fc=COLORS["semi"],        ec="#666",    label="Semiconductor ($\\sigma$=2 S/m)"),
        mpatches.Patch(fc=COLORS["xlpe"],        ec="#c8b400", label="XLPE insulation ($\\varepsilon_r$=2.25)"),
        mpatches.Patch(fc=COLORS["filling"],     ec="#aaa",    label="PE filling"),
        mpatches.Patch(fc=COLORS["inner_sheath"],ec="#888",    label="Inner sheath (PE)"),
        mpatches.Patch(fc=COLORS["seawater"],    ec="#555577", label="Seawater ($\\sigma_w$=4--5 S/m)"),
        mpatches.Patch(fc=COLORS["vss_ring"],    ec="#9999cc",
                       label="VolSphShell ring (maps to $\\infty$)", hatch="///"),
    ]


# --------------------------------------------------------------------------- #
#  Main: produce three figures                                                  #
# --------------------------------------------------------------------------- #
TITLES = {
    "electro": "Electrodynamic formulation  (v-formulation)",
    "mag":     "Magnetoquasistatic formulation  (a–v formulation)",
    "thermal": "Magneto-thermal formulation  (coupled)",
}

BC_SUMMARIES = {
    "electro": (
        "BCs: "
        "\\textbf{Dirichlet} $v = V_0 e^{j\\phi_k}$ on Cu conductors "
        "(red border);  "
        "$v = 0$ on outer seawater boundary (red ring).  "
        "VolSphShell (hatched) maps outer ring to $\\infty$."
    ),
    "mag": (
        "BCs: "
        "\\textbf{Dirichlet} $a_z = 0$ on outer boundary (teal ring) -- "
        "ensures $\\mathbf{B}\\to 0$ at $\\infty$ via VolSphShell.  "
        "Current $I_k$ imposed on Cu phases (purple border)."
    ),
    "thermal": (
        "BCs: "
        "\\textbf{Robin} $\\kappa\\partial_n T + h(T-T_0)=0$ on outer boundary (green ring)  "
        "($h$=20 W/(m$^2\\cdot$K), $T_0$=20$^\\circ$C).  "
        "Joule source $Q=\\frac{1}{2}\\sigma|\\mathbf{J}|^2$ in Cu (orange border)."
    ),
}

for mode in ("electro", "mag", "thermal"):
    fig, (ax_full, ax_zoom) = plt.subplots(1, 2, figsize=(15, 7.5))
    fig.patch.set_facecolor("white")
    fig.suptitle(TITLES[mode], fontsize=14, fontweight="bold")

    draw_full_cross_section(ax_full, mode)
    ax_full.set_title("Full cross-section", fontsize=12)

    draw_zoomed_cable(ax_zoom, mode)
    ax_zoom.set_title("Cable bundle (zoomed)", fontsize=12)

    for ax in (ax_full, ax_zoom):
        ax.spines[["top", "right"]].set_visible(False)

    # Legend below panels; rect reserves space at bottom and top
    fig.tight_layout(rect=[0, 0.13, 1, 0.95])
    handles = make_legend_patches()
    fig.legend(handles=handles, loc="lower center", ncol=4, fontsize=8,
               bbox_to_anchor=(0.5, 0.01), frameon=True,
               edgecolor="#ccc", facecolor="white")

    out = f"slides/graphs/geometry_{mode}.svg"
    fig.savefig(out, format="svg", bbox_inches="tight")
    plt.close(fig)
    print(f"+ Saved {out}")

print("\n+ plot_geometry.py done")
