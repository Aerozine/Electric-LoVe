#!/usr/bin/env python3
"""
domain_convergence.py
---------------------
Varies the outer domain radius R_env and runs MQS at each value,
WITH and WITHOUT VolSphShell infinite-element mapping.

Shows that:
  - With VolSphShell: L is accurate at any R ≥ 40 mm (mapping to ∞ removes truncation)
  - Without VolSphShell (plain a=0 BC): needs R >> r_cable for 3-sig-fig accuracy

Output: res/domain_conv.svg
"""

import os
import re
import subprocess

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

PYTHON = os.environ.get("MESH_PYTHON", "./gmsh/bin/python")
GETDP  = os.environ.get("MESH_GETDP",  "getdp")

# Environment radii to test [mm]  (reference = 150 mm)
# minimum must exceed outer_sheath ≈ 21.25 mm
R_ENV_MM = [25, 40, 75, 150]

# Cable lay-up outer radius (half of layup_outer_diameter = 22.5 mm)
R_CABLE_MM = 11.25

C_ACCENT = "#0f6e84"
C_RED    = "#c1121f"
C_GOLD   = "#e8a838"
C_NAVY   = "#1a1a2e"


#  Helpers 
def run_cmd(cmd, label=""):
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"  ✗ {label or cmd[:50]}: {r.stderr[-300:]}")
    return r.returncode == 0


def read_scalar(path):
    if not os.path.exists(path):
        return None
    with open(path) as f:
        for line in f:
            t = line.strip()
            if t.startswith("#") or not t:
                continue
            parts = t.split()
            if len(parts) >= 2 and parts[0] == "0":
                return float(parts[1])
    return None


#  TOML patcher: change environment_diameter + scale env mesh sizes 
def patch_env_radius(text: str, r_env_mm: float) -> str:
    """Set environment_diameter = 2*r_env_mm and scale env/boundary mesh sizes."""
    r_ref_mm = 150.0  # reference radius in mm

    # environment_diameter
    text = re.sub(
        r'^(environment_diameter\s*=\s*)[\d.e+\-]+',
        rf'\g<1>{2*r_env_mm}',
        text, flags=re.MULTILINE
    )
    # environment_size: scale proportionally
    env_base = 0.018  # m at R=150 mm
    env_new  = env_base * r_env_mm / r_ref_mm
    text = re.sub(
        r'^(environment_size\s*=\s*)[\d.e+\-]+',
        rf'\g<1>{env_new:.6g}',
        text, flags=re.MULTILINE
    )
    # boundary_size: scale proportionally
    bnd_base = 0.035  # m at R=150 mm
    bnd_new  = bnd_base * r_env_mm / r_ref_mm
    text = re.sub(
        r'^(boundary_size\s*=\s*)[\d.e+\-]+',
        rf'\g<1>{bnd_new:.6g}',
        text, flags=re.MULTILINE
    )
    return text


#  Numerics lib patcher: disable VolSphShell 
NUMERICS = "Lib_LoVe_Numerics.pro"

with open(NUMERICS) as f:
    orig_numerics = f.read()

_VSS_REGION_BLOCK = re.compile(
    r'\{\s*Region Domain_Inf_Mag;.*?VolSphShell\{[^}]*\};\s*\}\s*',
    re.DOTALL
)

def _no_volsphshell(text: str) -> str:
    """Remove the Domain_Inf_Mag VolSphShell case; it falls through to Vol."""
    return _VSS_REGION_BLOCK.sub("", text)


#  Main loop 
os.makedirs("res", exist_ok=True)

with open("cable.toml") as f:
    orig_toml = f.read()

results_with    = {}   # {r_mm: L}
results_without = {}

def run_mqs_get_L(r_env_mm, use_volsphshell):
    """Regenerate mesh + run MQS, return L [H/m] or None."""
    if not run_cmd(f"{PYTHON} geometry.py", f"mesh R={r_env_mm}mm"):
        return None
    ok = run_cmd(
        f"{GETDP} LoVe.pro -msh LoVe.msh"
        f" -setnumber Flag_AnalysisType 1"
        f" -solve Magnetoquasistatics -pos Post_Mag -v2",
        f"MQS R={r_env_mm}mm {'w/' if use_volsphshell else 'no'} VSS"
    )
    if not ok:
        return None
    return read_scalar("res/L.dat")

try:
    for r_mm in R_ENV_MM:
        print(f"\n{''*52}\n  R_env = {r_mm} mm\n{''*52}")

        # Patch cable.toml
        with open("cable.toml", "w") as f:
            f.write(patch_env_radius(orig_toml, r_mm))

        #  With VolSphShell 
        with open(NUMERICS, "w") as f:
            f.write(orig_numerics)
        L_with = run_mqs_get_L(r_mm, use_volsphshell=True)
        results_with[r_mm] = L_with
        print(f"  With  VolSphShell: L = {L_with:.6e} H/m" if L_with else "  With  VSS: FAILED")

        #  Without VolSphShell 
        with open(NUMERICS, "w") as f:
            f.write(_no_volsphshell(orig_numerics))
        # Regenerate .pro files with same geometry (mesh already built)
        run_cmd(f'{PYTHON} -c "from generator import generate_all; generate_all()"', "gen")
        L_no = run_mqs_get_L(r_mm, use_volsphshell=False)
        results_without[r_mm] = L_no
        print(f"  Without VolSphShell: L = {L_no:.6e} H/m" if L_no else "  No  VSS: FAILED")

finally:
    with open("cable.toml", "w") as f:
        f.write(orig_toml)
    with open(NUMERICS, "w") as f:
        f.write(orig_numerics)
    print("\nRestored cable.toml and Lib_LoVe_Numerics.pro")
    run_cmd(f"{PYTHON} geometry.py", "restore mesh")
    run_cmd(
        f"{GETDP} LoVe.pro -msh LoVe.msh -setnumber Flag_AnalysisType 1"
        f" -solve Magnetoquasistatics -pos Post_Mag -v2",
        "restore MQS"
    )


#  Plot 
# Use the finest VolSphShell result as reference
ref_L = results_with.get(max(R_ENV_MM))

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 4.2))
fig.patch.set_facecolor("white")

xs_with = [r for r in R_ENV_MM if results_with.get(r) is not None]
ys_with = [results_with[r]*1e9 for r in xs_with]          # nH/m

xs_no = [r for r in R_ENV_MM if results_without.get(r) is not None]
ys_no = [results_without[r]*1e9 for r in xs_no]

#  Left: absolute L (nH/m) 
if xs_with:
    ax1.plot(xs_with, ys_with, "o-", color=C_ACCENT, lw=2.3, ms=8,
             label="With VolSphShell (∞-elements)", zorder=3)
if xs_no:
    ax1.plot(xs_no, ys_no, "s--", color=C_GOLD, lw=2.3, ms=8,
             label="Without VolSphShell (plain a=0)", zorder=3)
if ref_L:
    ax1.axhline(ref_L*1e9, color="gray", ls=":", lw=1.5, label="Reference")

# Mark current operating point
ax1.axvline(150, color=C_NAVY, ls="--", lw=1.2, alpha=0.5, label="Current R = 150 mm")
ax1.set_xlabel("Outer domain radius  R_env  (mm)", fontsize=11)
ax1.set_ylabel("L  (nH/m)", fontsize=11)
ax1.set_title("Inductance vs outer domain radius", fontsize=11, fontweight="bold")
ax1.legend(fontsize=9, loc="lower right")
ax1.grid(True, alpha=0.3)
ax1.set_xlim(left=0)

#  Right: relative error vs reference 
if ref_L:
    err_with = [abs(results_with[r] - ref_L) / ref_L * 100
                for r in xs_with if results_with.get(r)]
    err_no   = [abs(results_without[r] - ref_L) / ref_L * 100
                for r in xs_no if results_without.get(r)]

    xs_with_filt = [r for r in xs_with if results_with.get(r)]
    xs_no_filt   = [r for r in xs_no if results_without.get(r)]

    # Drop the reference point itself (error = 0, causes log issues)
    pairs_with = [(x, e) for x, e in zip(xs_with_filt, err_with) if e > 1e-9]
    pairs_no   = [(x, e) for x, e in zip(xs_no_filt,  err_no)   if e > 1e-9]

    if pairs_with:
        xw, yw = zip(*pairs_with)
        ax2.semilogy(xw, yw, "o-", color=C_ACCENT, lw=2.3, ms=8,
                     label="With VolSphShell")
        for x, e in pairs_with:
            ax2.annotate(f"{e:.3f}%", xy=(x, e), xytext=(5, 4),
                         textcoords="offset points", fontsize=8.5, color=C_NAVY)

    if pairs_no:
        xn, yn = zip(*pairs_no)
        ax2.semilogy(xn, yn, "s--", color=C_GOLD, lw=2.3, ms=8,
                     label="Without VolSphShell")
        for x, e in pairs_no:
            ax2.annotate(f"{e:.2f}%", xy=(x, e), xytext=(5, -12),
                         textcoords="offset points", fontsize=8.5, color=C_GOLD)

    # Target accuracy lines
    ax2.axhline(0.1, color=C_RED, ls="--", lw=1.3, label="0.1% (3 sig. fig.)")
    ax2.axhline(1.0, color=C_RED, ls=":",  lw=1.3, label="1.0% (2 sig. fig.)")
    ax2.axvline(150, color=C_NAVY, ls="--", lw=1.2, alpha=0.5)
    ax2.legend(fontsize=9, loc="upper right")

ax2.set_xlabel("Outer domain radius  R_env  (mm)", fontsize=11)
ax2.set_ylabel("Relative error vs reference (%)", fontsize=11)
ax2.set_title("Truncation error — domain size effect", fontsize=11, fontweight="bold")
ax2.grid(True, which="both", alpha=0.25)
ax2.set_xlim(left=0)

for ax in (ax1, ax2):
    ax.spines[["top", "right"]].set_visible(False)
    ax.tick_params(labelsize=10)

fig.tight_layout(pad=1.5)
fig.savefig("res/domain_conv.svg", format="svg", bbox_inches="tight")
plt.close(fig)
print("\n[V]Saved res/domain_conv.svg")
