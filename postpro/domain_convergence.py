#!/usr/bin/env python3
"""
domain_convergence.py
---------------------
Varies the outer domain radius R_env and runs the Electrodynamic solve at
each value, showing how the capacitance C (F/m) converges with domain size.

The outer domain must be strictly larger than the cable (outer_sheath_outer_diameter/2
= 21.25 mm).  The reference value is computed at the largest tested radius (150 mm).

Output: slides/graphs/domain_conv.svg
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
# Must exceed outer_sheath_outer_diameter/2 = 21.25 mm
R_ENV_MM = [25, 40, 60, 80, 100, 150]

C_ACCENT = "#0f6e84"
C_RED    = "#c1121f"
C_GOLD   = "#e8a838"
C_NAVY   = "#1a1a2e"


# --- Helpers ------------------------------------------------------------------
def run_cmd(cmd, label=""):
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"  X {label or cmd[:50]}: {r.stderr[-300:]}")
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


# --- TOML patcher: change environment_diameter + scale env mesh sizes --------
def patch_env_radius(text: str, r_env_mm: float) -> str:
    r_ref_mm = 150.0
    text = re.sub(
        r'^(environment_diameter\s*=\s*)[\d.e+\-]+',
        rf'\g<1>{2*r_env_mm}',
        text, flags=re.MULTILINE
    )
    env_base = 0.018
    env_new  = env_base * r_env_mm / r_ref_mm
    text = re.sub(
        r'^(environment_size\s*=\s*)[\d.e+\-]+',
        rf'\g<1>{env_new:.6g}',
        text, flags=re.MULTILINE
    )
    bnd_base = 0.035
    bnd_new  = bnd_base * r_env_mm / r_ref_mm
    text = re.sub(
        r'^(boundary_size\s*=\s*)[\d.e+\-]+',
        rf'\g<1>{bnd_new:.6g}',
        text, flags=re.MULTILINE
    )
    return text


# --- Main loop ----------------------------------------------------------------
os.makedirs("slides/graphs", exist_ok=True)

with open("cable.toml") as f:
    orig_toml = f.read()

results = {}   # {r_mm: C [F/m]}

def run_ele_get_C(r_env_mm):
    """Regenerate mesh + run Electrodynamics, return C [F/m] or None."""
    if not run_cmd(f"{PYTHON} geometry.py", f"mesh R={r_env_mm}mm"):
        return None
    ok = run_cmd(
        f"{GETDP} LoVe.pro -msh LoVe.msh -solve Electrodynamics -pos Post_Ele -v2",
        f"Electro R={r_env_mm}mm"
    )
    if not ok:
        return None
    return read_scalar("res/C.dat")

try:
    for r_mm in R_ENV_MM:
        print(f"\n{'--'*26}\n  R_env = {r_mm} mm\n{'--'*26}")
        with open("cable.toml", "w") as f:
            f.write(patch_env_radius(orig_toml, r_mm))
        C = run_ele_get_C(r_mm)
        results[r_mm] = C
        print(f"  C = {C:.6e} F/m" if C else "  FAILED")

finally:
    with open("cable.toml", "w") as f:
        f.write(orig_toml)
    print("\nRestored cable.toml")
    run_cmd(f"{PYTHON} geometry.py", "restore mesh")
    run_cmd(
        f"{GETDP} LoVe.pro -msh LoVe.msh -solve Electrodynamics -pos Post_Ele -v2",
        "restore electro"
    )


# --- Plot --------------------------------------------------------------------
ref_C = results.get(max(R_ENV_MM))

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(13, 6.0))
fig.patch.set_facecolor("white")

xs = [r for r in R_ENV_MM if results.get(r) is not None]
ys = [results[r] * 1e12 for r in xs]          # pF/m

# -- Left: absolute C (pF/m) --------------------------------------------------
ax1.plot(xs, ys, "o-", color=C_ACCENT, lw=2.3, ms=8,
         label="C  (Electrodynamics)", zorder=3)
if ref_C:
    ax1.axhline(ref_C * 1e12, color="gray", ls=":", lw=1.5,
                label=f"Reference (R={max(R_ENV_MM)} mm)")
for x, y in zip(xs, ys):
    ax1.annotate(f"{x} mm", xy=(x, y), xytext=(0, 9),
                 textcoords="offset points", ha="center",
                 fontsize=8.5, color=C_NAVY)

ax1.set_xlabel("Outer domain radius  R_env  (mm)", fontsize=11)
ax1.set_ylabel("C  (pF/m)", fontsize=11)
ax1.set_title("Capacitance vs domain radius\n(electrodynamic, v-formulation)", fontsize=11,
              fontweight="bold")
ax1.legend(fontsize=9, loc="lower right")
ax1.grid(True, alpha=0.3)
ax1.set_xlim(left=0)

# -- Right: relative error vs reference ---------------------------------------
if ref_C:
    pairs = [(r, abs(results[r] - ref_C) / ref_C * 100)
             for r in xs if results.get(r) and abs(results[r] - ref_C) / ref_C * 100 > 1e-9]

    if pairs:
        xw, yw = zip(*pairs)
        ax2.semilogy(xw, yw, "o-", color=C_ACCENT, lw=2.3, ms=8, label="Relative error vs ref")
        for x, e in pairs:
            ax2.annotate(f"{e:.2f}%", xy=(x, e), xytext=(5, 4),
                         textcoords="offset points", fontsize=9, color=C_NAVY)

    ax2.axhline(0.1, color=C_RED, ls="--", lw=1.3, label="0.1%")
    ax2.axhline(1.0, color=C_RED, ls=":",  lw=1.3, label="1.0%")
    ax2.legend(fontsize=9, loc="upper right")

ax2.set_xlabel("Outer domain radius  R_env  (mm)", fontsize=11)
ax2.set_ylabel("Relative error vs reference (%)", fontsize=11)
ax2.set_title("Truncation error -- domain size effect", fontsize=11, fontweight="bold")
ax2.grid(True, which="both", alpha=0.25)
ax2.set_xlim(left=0)

for ax in (ax1, ax2):
    ax.spines[["top", "right"]].set_visible(False)
    ax.tick_params(labelsize=10)

fig.tight_layout(pad=1.5)
fig.savefig("slides/graphs/domain_conv.svg", format="svg", bbox_inches="tight")
plt.close(fig)
print("\n+ Saved slides/graphs/domain_conv.svg")
