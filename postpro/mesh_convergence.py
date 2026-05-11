#!/usr/bin/env python3
"""
mesh_convergence.py
-------------------
Runs Electrodynamic, MQS and Magneto-thermal solves at several mesh densities
and writes SVG convergence plots to graphs/conv_*.svg.

X-axis: relevant interior mesh size for each analysis (mm, log scale):
  - Electrodynamic: semiconductor_size (steepest sigma gradient at Cu/XLPE)
  - MQS:            conductor_size     (J distribution in copper)
  - Thermal:        insulation_size    (steepest kappa gradient in XLPE)

Only interior mesh keys are scaled; environment_size/boundary_size are fixed
so the VolSphShell Jacobian stays valid at all scale factors.
"""

import os
import re
import subprocess

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

PYTHON = os.environ.get("MESH_PYTHON", "./gmsh/bin/python")
GETDP  = os.environ.get("MESH_GETDP",  "getdp")

# Mesh scale multipliers: 1.0 = reference.
# Outer boundary mesh (environment_size, boundary_size) is NOT scaled.
SCALES = [10.0, 6.0, 4.0, 2.5, 1.5, 1.0, 0.75]
FIXED_MESH_KEYS = {"environment_size", "boundary_size"}

C_ACCENT = "#0f6e84"
C_GOLD   = "#e8a838"
C_RED    = "#c1121f"
C_NAVY   = "#1a1a2e"
C_GREEN  = "#2d6a4f"
C_BROWN  = "#8b4513"

os.makedirs("slides/graphs", exist_ok=True)


# --- TOML helpers ------------------------------------------------------------
def patch_mesh_scale(text: str, scale: float) -> str:
    out = []
    in_mesh = False
    for line in text.splitlines():
        s = line.strip()
        if s == "[mesh]":
            in_mesh = True; out.append(line); continue
        if in_mesh and s.startswith("["): in_mesh = False
        if in_mesh:
            m = re.match(r'^(\s*)(\w+)(\s*=\s*)([\d.e+\-]+)(.*)', line)
            if m and m.group(2) not in FIXED_MESH_KEYS:
                val = float(m.group(4)) * scale
                out.append(f"{m.group(1)}{m.group(2)}{m.group(3)}{val:.8g}{m.group(5)}")
                continue
        out.append(line)
    return "\n".join(out)


def extract_val(text: str, key: str) -> float:
    """Extract any scalar value from cable.toml by key name."""
    m = re.search(rf'^{key}\s*=\s*([\d.e+\-]+)', text, re.MULTILINE)
    return float(m.group(1)) if m else 0.0


def extract_mesh_size(text: str, key: str) -> float:
    in_mesh = False
    for line in text.splitlines():
        s = line.strip()
        if s == "[mesh]": in_mesh = True; continue
        if in_mesh and s.startswith("["): break
        if in_mesh:
            m = re.match(rf'^\s*{key}\s*=\s*([\d.e+\-]+)', line)
            if m: return float(m.group(1))
    return 0.0


# --- Helpers -----------------------------------------------------------------
def run_cmd(cmd: str, label: str = "") -> bool:
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"  X {label or cmd[:60]}\n{r.stderr[-400:]}")
        return False
    return True


def read_scalar(path: str):
    if not os.path.exists(path): return None
    with open(path) as f:
        for line in f:
            t = line.strip()
            if t.startswith("#") or not t: continue
            parts = t.split()
            if len(parts) >= 2 and parts[0] == "0":
                return float(parts[1])
    return None


def read_inds_first(path: str):
    """Read first real-part value from Rinds.dat / Linds.dat (skip count line)."""
    if not os.path.exists(path): return None
    past_count = False
    with open(path) as f:
        for line in f:
            t = line.strip()
            if t.startswith("#") or not t: continue
            parts = t.split()
            if not past_count:
                if len(parts) == 1:
                    past_count = True
                continue
            if len(parts) >= 2:
                try:
                    return float(parts[1])
                except ValueError:
                    continue
    return None


# --- Convergence loop --------------------------------------------------------
with open("cable.toml") as f:
    orig_toml = f.read()

# Base mesh sizes (m → mm)
base_semi = extract_mesh_size(orig_toml, "semiconductor_size") * 1000
base_cond = extract_mesh_size(orig_toml, "conductor_size")     * 1000
base_ins  = extract_mesh_size(orig_toml, "insulation_size")    * 1000
T_amb     = extract_val(orig_toml, "ambient_temperature")

rows = []

try:
    for scale in SCALES:
        print(f"\n{'--'*26}\n  mesh scale = {scale:.2f}x\n{'--'*26}")
        with open("cable.toml", "w") as f:
            f.write(patch_mesh_scale(orig_toml, scale))

        if not run_cmd(f"{PYTHON} geometry.py", "geometry"):
            rows.append({"scale": scale}); continue

        row = {
            "scale": scale,
            "x_semi": base_semi * scale,
            "x_cond": base_cond * scale,
            "x_ins":  base_ins  * scale,
        }

        if run_cmd(f"{GETDP} LoVe.pro -msh LoVe.msh -solve Electrodynamics -pos Post_Ele -v2", "electro"):
            row["C"]  = read_scalar("res/C.dat")
            row["We"] = read_scalar("res/energy.dat")
            print(f"  C     = {row['C']:.6e} F/m   We = {row['We']:.6e} J/m")

        if run_cmd(f"{GETDP} LoVe.pro -msh LoVe.msh "
                   f"-setnumber Flag_AnalysisType 1 -solve Magnetoquasistatics -pos Post_Mag -v2", "MQS"):
            row["L"] = read_scalar("res/L.dat")
            row["R"] = read_inds_first("res/Rinds.dat")
            print(f"  L     = {row['L']:.6e} H/m")
            if row.get("R"): print(f"  R_AC  = {row['R']:.6e} Ohm/m")

        ok = run_cmd(f"{GETDP} LoVe.pro -msh LoVe.msh "
                     f"-setnumber Flag_AnalysisType 2 -solve Magnetothermal -pos Post_Thermal -v2", "thermal")
        if ok:
            ok = run_cmd(f"{GETDP} LoVe.pro -msh LoVe.msh "
                         f"-setnumber Flag_AnalysisType 2 -pos Post_MagTher -v2", "thermal post")
        if ok:
            run_cmd("python3 postpro/postmax.py", "postmax")
            T = read_scalar("res/t_max.dat")
            row["dT"] = (T - T_amb) if T is not None else None
            print(f"  dT    = {row['dT']:.6e} K")

        rows.append(row)

finally:
    with open("cable.toml", "w") as f:
        f.write(orig_toml)
    print("\nRestored cable.toml")
    run_cmd(f"{PYTHON} geometry.py", "reference mesh")
    for cmd, lbl in [
        (f"{GETDP} LoVe.pro -msh LoVe.msh -solve Electrodynamics -pos Post_Ele -v2", "restore electro"),
        (f"{GETDP} LoVe.pro -msh LoVe.msh -setnumber Flag_AnalysisType 1 -solve Magnetoquasistatics -pos Post_Mag -v2", "restore MQS"),
        (f"{GETDP} LoVe.pro -msh LoVe.msh -setnumber Flag_AnalysisType 2 -solve Magnetothermal -pos Post_Thermal -v2", "restore thermal"),
        (f"{GETDP} LoVe.pro -msh LoVe.msh -setnumber Flag_AnalysisType 2 -pos Post_MagTher -v2", "restore thermal post"),
        ("python3 postpro/postmax.py", "restore postmax"),
    ]:
        run_cmd(cmd, lbl)


# --- SVG plotting ------------------------------------------------------------
def convergence_svg(outpath, quantity, unit, title, ys, xs, xlabel, fmt=".4e"):
    """Single-panel convergence plot (log x-scale).
    Absolute value vs mesh size.
    Coarse mesh (large size) on the LEFT, fine mesh on the RIGHT.
    Reference = finest mesh (rightmost point, smallest size).
    Each non-reference point is annotated with its relative error (%).
    """
    pts = [(x, y, s) for x, y, s in zip(xs, ys, SCALES)
           if x is not None and y is not None]
    if not pts:
        print(f"  No data for {outpath} -- skipping"); return

    # Sort descending: coarse (large x) on left, fine (small x) on right
    pts.sort(key=lambda p: -p[0])

    xs_s     = [p[0] for p in pts]
    ys_v     = [p[1] for p in pts]
    scales_s = [p[2] for p in pts]

    ref = ys_v[-1]           # finest mesh is reference

    fig, ax1 = plt.subplots(1, 1, figsize=(10, 6.5))
    fig.patch.set_facecolor("white")

    # Absolute value (log x-axis)
    ax1.plot(xs_s, ys_v, "o-", color=C_ACCENT, lw=2.3, ms=8, zorder=3)
    for i, (x, y, sc) in enumerate(zip(xs_s, ys_v, scales_s)):
        ax1.annotate(f"x{sc:g}", xy=(x, y), xytext=(0, 10),
                     textcoords="offset points", ha="center",
                     fontsize=8, color=C_NAVY)
        if i < len(xs_s) - 1:   # annotate relative error for all but the finest
            rel = abs(y - ref) / abs(ref) * 100
            ax1.annotate(f"{rel:.2f}%", xy=(x, y), xytext=(0, 22),
                         textcoords="offset points", ha="center",
                         fontsize=8, color=C_RED)
    ax1.annotate(f"ref = {ref:{fmt[1:]}}", xy=(xs_s[-1], ref),
                 xytext=(6, -14), textcoords="offset points",
                 ha="left", fontsize=9, color=C_ACCENT)
    ax1.axhline(ref * (1 + 0.001), color=C_RED, ls="--", lw=1.2, alpha=0.7,
                label="± 0.1 % threshold")
    ax1.axhline(ref * (1 - 0.001), color=C_RED, ls="--", lw=1.2, alpha=0.7)
    ax1.legend(fontsize=9)
    ax1.set_xscale("log")
    ax1.set_xlabel(xlabel + "  (log scale, coarse  →  fine)", fontsize=10)
    ax1.set_ylabel(f"{quantity}  [{unit}]", fontsize=11)
    ax1.set_title(f"{title}", fontsize=11, fontweight="bold")
    ax1.grid(True, which="both", alpha=0.25)
    ax1.invert_xaxis()   # coarse (large) on left, fine (small) on right

    ax1.spines[["top", "right"]].set_visible(False)
    ax1.tick_params(labelsize=10)

    fig.tight_layout(pad=1.8)
    fig.savefig(outpath, format="svg", bbox_inches="tight")
    plt.close(fig)
    print(f"  + {outpath}")


# Build per-quantity lists in SCALES order
x_semi_list = [r.get("x_semi") for r in rows]
x_cond_list = [r.get("x_cond") for r in rows]
x_ins_list  = [r.get("x_ins")  for r in rows]
C_list      = [r.get("C")      for r in rows]
We_list     = [r.get("We")     for r in rows]
L_list      = [r.get("L")      for r in rows]
R_list      = [r.get("R")      for r in rows]
dT_list     = [r.get("dT")     for r in rows]

print("\n-- Generating SVG plots --")
# Electrodynamic: use insulation mesh size — C is a dielectric global quantity
convergence_svg("slides/graphs/conv_electro.svg", "C", "pF/m", "Capacitance (C)",
                [c * 1e12 if c is not None else None for c in C_list],
                x_ins_list, "Insulation mesh size (mm)", ".4e")
convergence_svg("slides/graphs/conv_energy.svg",  "W_e", "nJ/m", "Electric energy (W_e)",
                [w * 1e9 if w is not None else None for w in We_list],
                x_ins_list, "Insulation mesh size (mm)", ".4e")
convergence_svg("slides/graphs/conv_mqs.svg",     "L", "H/m",  "Inductance (L)",
                L_list,  x_cond_list, "Conductor mesh size (mm)", ".4e")
convergence_svg("slides/graphs/conv_thermal.svg", "dT", "K",   "Temperature rise (dT = T_max - T_amb)",
                dT_list, x_ins_list,  "Insulation mesh size (mm)", ".6e")

# --- Combined 2×2 figure -------------------------------------------------
def convergence_panel(ax, title, unit, ys, xs, xlabel, color=C_ACCENT):
    pts = [(x, y) for x, y in zip(xs, ys) if x is not None and y is not None]
    if not pts:
        ax.text(0.5, 0.5, "No data", transform=ax.transAxes,
                ha="center", va="center", fontsize=9, color="#888")
        ax.set_title(title, fontsize=10, fontweight="bold"); return
    pts.sort(key=lambda p: -p[0])   # coarse (large h) on left
    xs_s = [p[0] for p in pts]
    ys_v = [p[1] for p in pts]
    ref  = ys_v[-1]

    ax.plot(xs_s, ys_v, "o-", color=color, lw=2.0, ms=6, zorder=3)
    for i, (x, y) in enumerate(zip(xs_s, ys_v)):
        if i < len(xs_s) - 1 and ref != 0:
            rel = abs(y - ref) / abs(ref) * 100
            ax.annotate(f"{rel:.1f}%", xy=(x, y), xytext=(0, 8),
                        textcoords="offset points", ha="center",
                        fontsize=7, color=C_RED)
    ax.annotate(f"ref", xy=(xs_s[-1], ref), xytext=(4, -12),
                textcoords="offset points", ha="left", fontsize=8, color=color)
    if ref != 0:
        ax.axhline(ref * (1 + 0.001), color=C_RED, ls="--", lw=0.9, alpha=0.6,
                   label="±0.1%")
        ax.axhline(ref * (1 - 0.001), color=C_RED, ls="--", lw=0.9, alpha=0.6)
        ax.legend(fontsize=7, loc="upper right")
    ax.set_xscale("log")
    ax.invert_xaxis()
    ax.set_xlabel(xlabel + "  (mm, log)", fontsize=8)
    ax.set_ylabel(f"{title}  [{unit}]", fontsize=9)
    ax.set_title(title, fontsize=10, fontweight="bold")
    ax.grid(True, which="both", alpha=0.25)
    ax.spines[["top", "right"]].set_visible(False)
    ax.tick_params(labelsize=8)


fig_c, axes = plt.subplots(2, 2, figsize=(13, 9))
fig_c.patch.set_facecolor("white")
fig_c.suptitle("Mesh convergence — all formulations", fontsize=13,
               fontweight="bold", y=0.99)

convergence_panel(axes[0, 0], "C  [pF/m]", "pF/m",
                  [c * 1e12 if c is not None else None for c in C_list],
                  x_ins_list, "Insulation mesh size", color=C_ACCENT)
convergence_panel(axes[0, 1], "L  [nH/m]", "nH/m",
                  [l * 1e9 if l is not None else None for l in L_list],
                  x_cond_list, "Conductor mesh size", color=C_GOLD)
convergence_panel(axes[1, 0], "R_AC  [mΩ/m]", "mΩ/m",
                  [r * 1e3 if r is not None else None for r in R_list],
                  x_cond_list, "Conductor mesh size", color=C_GREEN)
convergence_panel(axes[1, 1], "ΔT  [K]", "K",
                  dT_list, x_ins_list, "Insulation mesh size", color=C_BROWN)

fig_c.tight_layout(pad=2.0, rect=[0, 0, 1, 0.97])
fig_c.savefig("slides/graphs/conv_combined.svg", format="svg", bbox_inches="tight")
plt.close(fig_c)
print("  + slides/graphs/conv_combined.svg")

print("\n+ mesh_convergence.py done -- plots saved to slides/graphs/")
