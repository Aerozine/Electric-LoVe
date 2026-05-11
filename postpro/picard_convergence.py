#!/usr/bin/env python3
"""
picard_convergence.py
---------------------
Runs the coupled magneto-thermal solve (nonlinear sigma(T)) at several current
amplitudes and plots the Picard iteration residual vs iteration number.

A theoretical Newton-Raphson curve (quadratic convergence) is overlaid on the
same plot for comparison.  The Newton curve is not a simulation: it shows what
quadratic convergence would look like starting from the same initial residual
and first-step reduction as the Picard run.

Output: res/picard_convergence.svg

Usage
-----
    ./gmsh/bin/python picard_convergence.py
"""

import os
import re
import subprocess
import math

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

PYTHON   = os.environ.get("MESH_PYTHON", "./gmsh/bin/python")
GETDP    = os.environ.get("MESH_GETDP",  "getdp")

CURRENTS = [1.0, 50.0, 150.0, 400.0]
COLORS   = ["#0f6e84", "#2d6a4f", "#e8a838", "#c1121f"]
NL_TOL_REL = 1e-6


# --- TOML patcher ------------------------------------------------------------
def patch_toml(text: str, current: float, nonlinear: int = 1) -> str:
    text = re.sub(r'^(current\s*=\s*)[\d.e+\-]+',
                  rf'\g<1>{current}', text, flags=re.MULTILINE)
    text = re.sub(r'^(nonlinear\s*=\s*)\d+',
                  rf'\g<1>{nonlinear}', text, flags=re.MULTILINE)
    return text


# --- Helpers -----------------------------------------------------------------
def run_cmd(cmd: str) -> tuple[bool, str]:
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return r.returncode == 0, r.stdout + r.stderr


def parse_picard(output: str) -> list:
    pts = []
    for line in output.splitlines():
        m = re.search(
            r'Residual\s+(\d+):\s+abs\s+([\d.e+\-]+)\s+rel\s+([\d.e+\-]+)',
            line, re.IGNORECASE
        )
        if m:
            pts.append((int(m.group(1)), float(m.group(2)), float(m.group(3))))
    return pts


def newton_theoretical(picard_pts: list, tol: float = NL_TOL_REL) -> list:
    """Return list of (iter, rel_res) for theoretical Newton-Raphson.

    Newton-Raphson shows quadratic convergence: r_{k+1} ~ C * r_k^2.
    We estimate C from the first Picard step so that the Newton curve starts
    identically and then diverges super-linearly.
    """
    if len(picard_pts) < 2:
        return []
    r0 = 1.0
    r1 = picard_pts[0][2]   # relative residual after first Picard step
    if r1 <= 0 or r1 >= 1:
        return []
    # Newton constant: C such that r1 = C * r0^2 => C = r1
    C = r1
    pts = [(0, r0)]
    r = r1
    i = 1
    while r > tol * 0.1 and i < 50:
        pts.append((i, r))
        r_next = C * r * r
        if r_next <= 0 or r_next == r:
            break
        r = r_next
        i += 1
    pts.append((i, max(r, tol * 0.01)))
    return pts


# --- Main loop ---------------------------------------------------------------
os.makedirs("slides/graphs", exist_ok=True)

with open("cable.toml") as f:
    orig_toml = f.read()

results: dict[float, list] = {}

try:
    for I in CURRENTS:
        print(f"\n-- I = {I:.0f} A (nonlinear sigma(T)) --")
        with open("cable.toml", "w") as f:
            f.write(patch_toml(orig_toml, I, nonlinear=1))

        ok, msg = run_cmd(
            f'{PYTHON} -c "from generator import generate_all; generate_all()"'
        )
        if not ok:
            print(f"  X generator: {msg[-200:]}")
            continue

        ok, out = run_cmd(
            f'{GETDP} LoVe.pro -msh LoVe.msh'
            f' -setnumber Flag_AnalysisType 2'
            f' -solve Magnetothermal -pos Post_Thermal -v2'
        )
        if not ok:
            print(f"  X GetDP failed: {out[-200:]}")
            continue

        pts = parse_picard(out)
        results[I] = pts

        if pts:
            print(f"  converged in {pts[-1][0]} iter(s), "
                  f"final rel = {pts[-1][2]:.3e}")
        else:
            print("  No Picard data (converged at iter 0 -- linear regime)")

finally:
    with open("cable.toml", "w") as f:
        f.write(orig_toml)
    print("\nRestored cable.toml")
    ok, _ = run_cmd(f'{PYTHON} -c "from generator import generate_all; generate_all()"')
    if ok:
        print("Restored generated_common.pro / generated_geometry.geo")


# --- Plot --------------------------------------------------------------------
fig, ax1 = plt.subplots(figsize=(8.5, 5.2))
fig.patch.set_facecolor("white")

plotted = False
for I, color in zip(CURRENTS, COLORS):
    pts = results.get(I, [])
    if not pts:
        continue
    plotted = True
    iters_p = [p[0] for p in pts]
    rel_p   = [p[2] for p in pts]
    label = f"Picard  I = {I:.0f} A"
    ax1.semilogy(iters_p, rel_p,  "o-",  color=color, lw=2.2, ms=7, label=label)

    # Theoretical Newton-Raphson curve (same color, dashed)
    npts = newton_theoretical(pts, tol=NL_TOL_REL)
    if len(npts) >= 2:
        iters_n = [p[0] for p in npts]
        rel_n   = [p[1] for p in npts]
        ax1.semilogy(iters_n, rel_n, "--", color=color, lw=1.8, ms=0,
                     alpha=0.65,
                     label=f"Newton (theor.) I = {I:.0f} A")

ax1.axhline(NL_TOL_REL, color="gray", ls="--", lw=1.3,
            label=f"NLTolRel = {NL_TOL_REL:.0e}")

# Legend annotation explaining Newton curves
ax1.text(0.97, 0.85,
         "Dashed = Newton-Raphson\n(theoretical quadratic)",
         ha="right", va="top", transform=ax1.transAxes,
         fontsize=8.5, color="#555",
         bbox=dict(boxstyle="round,pad=0.3", fc="white", ec="#ccc", alpha=0.8))

ax1.set_xlabel("Iteration #", fontsize=11)
ax1.grid(True, which="both", alpha=0.28)
ax1.spines[["top", "right"]].set_visible(False)
ax1.tick_params(labelsize=10)
ax1.legend(fontsize=8, loc="upper right")

ax1.set_ylabel("Relative residual  ||r||/||r0||", fontsize=11)
ax1.set_title("Picard convergence -- relative residual", fontsize=11,
              fontweight="bold")

if not plotted:
    ax1.text(0.5, 0.5,
             "All cases converged before entering loop\n"
             "(delta T too small -- sigma(T) approx sigma0)",
             ha="center", va="center", transform=ax1.transAxes,
             fontsize=10, color="#555")

fig.tight_layout(pad=1.5)
out_path = "slides/graphs/picard_convergence.svg"
fig.savefig(out_path, format="svg", bbox_inches="tight")
plt.close(fig)
print(f"\n+ Saved {out_path}")
