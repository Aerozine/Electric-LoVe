#!/usr/bin/env python3
"""
picard_convergence.py
Runs the coupled magneto-thermal solve (nonlinear σ(T)) at several current
amplitudes and plots the Picard iteration residual vs iteration number.
Output: res/picard_convergence.svg

Usage
    ./gmsh/bin/python picard_convergence.py
"""

import os
import re
import subprocess

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

PYTHON   = os.environ.get("MESH_PYTHON", "./gmsh/bin/python")
GETDP    = os.environ.get("MESH_GETDP",  "getdp")

# Current amplitudes to test [A peak]
CURRENTS = [1.0, 50.0, 150.0, 400.0]
COLORS   = ["#0f6e84", "#2d6a4f", "#e8a838", "#c1121f"]

#  TOML patcher 
def patch_toml(text: str, current: float, nonlinear: int = 1) -> str:
    text = re.sub(
        r'^(current\s*=\s*)[\d.e+\-]+',
        rf'\g<1>{current}', text, flags=re.MULTILINE
    )
    text = re.sub(
        r'^(nonlinear\s*=\s*)\d+',
        rf'\g<1>{nonlinear}', text, flags=re.MULTILINE
    )
    return text

#  Helpers 
def run_cmd(cmd: str) -> tuple[bool, str]:
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return r.returncode == 0, r.stdout + r.stderr


def parse_picard(output: str) -> list:
    """Extract list of (iter, abs_res, rel_res) from GetDP verbose output."""
    pts = []
    for line in output.splitlines():
        m = re.search(
            r'Residual\s+(\d+):\s+abs\s+([\d.e+\-]+)\s+rel\s+([\d.e+\-]+)',
            line, re.IGNORECASE
        )
        if m:
            pts.append((int(m.group(1)), float(m.group(2)), float(m.group(3))))
    return pts


#  Main loop 
os.makedirs("res", exist_ok=True)

with open("cable.toml") as f:
    orig_toml = f.read()

results: dict[float, list] = {}

try:
    for I in CURRENTS:
        print(f"\n I = {I:.0f} A (nonlinear σ(T)) ")
        with open("cable.toml", "w") as f:
            f.write(patch_toml(orig_toml, I, nonlinear=1))

        # Regenerate .pro files only (no remesh needed — geometry unchanged)
        ok, msg = run_cmd(
            f'{PYTHON} -c "from generator import generate_all; generate_all()"'
        )
        if not ok:
            print(f"  ✗ generator: {msg[-200:]}")
            continue

        # Coupled magneto-thermal solve
        ok, out = run_cmd(
            f'{GETDP} LoVe.pro -msh LoVe.msh'
            f' -setnumber Flag_AnalysisType 2'
            f' -solve Magnetothermal -pos Post_Thermal -v2'
        )
        if not ok:
            print(f"  ✗ GetDP failed: {out[-200:]}")
            continue

        pts = parse_picard(out)
        results[I] = pts

        if pts:
            n_iter = pts[-1][0]
            print(f"  converged in {n_iter} iteration(s), "
                  f"final rel = {pts[-1][2]:.3e}")
        else:
            print("  No Picard data (loop skipped — already converged at iter 0)")
            # GetDP may not print iter-0 if it converges before entering the loop

finally:
    with open("cable.toml", "w") as f:
        f.write(orig_toml)
    print("\nRestored cable.toml")
    ok, _ = run_cmd(f'{PYTHON} -c "from generator import generate_all; generate_all()"')
    if ok:
        print("Restored generated_common.pro / generated_geometry.geo")


#  Plot 
NL_TOL_REL = 1e-6   # from cable.toml

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 4.2))
fig.patch.set_facecolor("white")

plotted = False
for I, color in zip(CURRENTS, COLORS):
    pts = results.get(I, [])
    if not pts:
        # Synthesise iter-0 point at rel=1 so we show something for 1A
        continue
    plotted = True
    iters = [p[0] for p in pts]
    rel   = [p[2] for p in pts]
    abs_  = [p[1] for p in pts]
    label = f"I = {I:.0f} A"
    ax1.semilogy(iters, rel,  "o-", color=color, lw=2.2, ms=8, label=label)
    ax2.semilogy(iters, abs_, "o-", color=color, lw=2.2, ms=8, label=label)

ax1.axhline(NL_TOL_REL, color="gray", ls="--", lw=1.3, label=f"NLTolRel = {NL_TOL_REL:.0e}")

for ax in (ax1, ax2):
    ax.set_xlabel("Picard iteration #", fontsize=11)
    ax.grid(True, which="both", alpha=0.28)
    ax.spines[["top", "right"]].set_visible(False)
    ax.tick_params(labelsize=10)
    ax.legend(fontsize=9, loc="upper right")

ax1.set_ylabel("Relative residual  ||r||/||r₀||", fontsize=11)
ax1.set_title("Picard convergence — relative", fontsize=11, fontweight="bold")
ax2.set_ylabel("Absolute residual  ||r||", fontsize=11)
ax2.set_title("Picard convergence — absolute", fontsize=11, fontweight="bold")

if not plotted:
    ax1.text(0.5, 0.5,
             "All cases converged before entering loop\n"
             "(ΔT too small → σ(T) ≈ σ₀, 0 extra iterations)",
             ha="center", va="center", transform=ax1.transAxes, fontsize=10,
             color="#555")
    ax2.text(0.5, 0.5, "No data — see left panel",
             ha="center", va="center", transform=ax2.transAxes, fontsize=10, color="#555")

fig.tight_layout(pad=1.5)
out_path = "res/picard_convergence.svg"
fig.savefig(out_path, format="svg", bbox_inches="tight")
plt.close(fig)
print(f"\n[V] Saved {out_path}")
