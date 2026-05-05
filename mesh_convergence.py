#!/usr/bin/env python3
"""
mesh_convergence.py
-------------------
Runs Electrodynamic, MQS and Magneto-thermal solves at four mesh densities
and writes SVG convergence plots to res/conv_*.svg.

Usage
-----
    ./gmsh/bin/python mesh_convergence.py      # recommended
    python3            mesh_convergence.py

Environment variables (override defaults)
    MESH_PYTHON   python executable  (default: ./gmsh/bin/python)
    MESH_GETDP    getdp  executable  (default: getdp)
"""

import os
import re
import subprocess

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

#  Configuration 
PYTHON = os.environ.get("MESH_PYTHON", "./gmsh/bin/python")
GETDP  = os.environ.get("MESH_GETDP",  "getdp")

# Mesh size multipliers: 1.0 = reference, >1 coarser, <1 finer
SCALES = [4.0, 2.0, 1.0, 0.6]

# Cable-theme colours
C_ACCENT = "#0f6e84"
C_GOLD   = "#e8a838"
C_RED    = "#c1121f"
C_NAVY   = "#1a1a2e"


#  TOML mesh-section patcher 
def patch_mesh_scale(text: str, scale: float) -> str:
    """Return cable.toml text with all values in [mesh] scaled by *scale*."""
    out = []
    in_mesh = False
    for line in text.splitlines():
        stripped = line.strip()
        if stripped == "[mesh]":
            in_mesh = True
            out.append(line)
            continue
        if in_mesh and stripped.startswith("["):
            in_mesh = False
        if in_mesh:
            m = re.match(r'^(\s*\w+\s*=\s*)([\d.e+\-]+)(.*)', line)
            if m:
                val = float(m.group(2)) * scale
                out.append(f"{m.group(1)}{val:.8g}{m.group(3)}")
                continue
        out.append(line)
    return "\n".join(out)


#  Helpers 
def run_cmd(cmd: str, label: str = "") -> bool:
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if r.returncode != 0:
        tag = label or cmd[:60]
        print(f"  ✗ {tag}\n{r.stderr[-600:]}")
        return False
    return True


def count_nodes(msh: str = "LoVe.msh") -> int:
    """Parse Gmsh 4.1 $Nodes block header → return total node count."""
    try:
        with open(msh) as f:
            in_nodes = False
            for line in f:
                t = line.strip()
                if t == "$Nodes":
                    in_nodes = True
                    continue
                if in_nodes:
                    parts = t.split()
                    if len(parts) >= 2:
                        return int(parts[1])   # second field = numNodes
    except OSError:
        pass
    return 0


def read_scalar(path: str):
    """Read first ' 0  VALUE  IMAG' line from a GetDP Table .dat file."""
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


#  Convergence loop 
os.makedirs("res", exist_ok=True)

with open("cable.toml") as f:
    orig_toml = f.read()

rows = []   # list of dicts {scale, nodes, C, L, T_max}

try:
    for scale in SCALES:
        print(f"\n{''*52}\n  mesh scale = {scale:.2f}×\n{''*52}")
        with open("cable.toml", "w") as f:
            f.write(patch_mesh_scale(orig_toml, scale))

        if not run_cmd(f"{PYTHON} geometry.py", "geometry"):
            rows.append(dict(scale=scale))
            continue
        nodes = count_nodes()
        print(f"  nodes : {nodes}")
        row = dict(scale=scale, nodes=nodes)

        #  Electrodynamics 
        ok = run_cmd(
            f"{GETDP} LoVe.pro -msh LoVe.msh -solve Electrodynamics -pos Post_Ele -v2",
            "electro solve"
        )
        if ok:
            row["C"] = read_scalar("res/C.dat")
            print(f"  C     = {row['C']:.6e} F/m")

        #  Magnetoquasistatic 
        ok = run_cmd(
            f"{GETDP} LoVe.pro -msh LoVe.msh "
            f"-setnumber Flag_AnalysisType 1 -solve Magnetoquasistatics -pos Post_Mag -v2",
            "MQS solve"
        )
        if ok:
            row["L"] = read_scalar("res/L.dat")
            print(f"  L     = {row['L']:.6e} H/m")

        #  Magneto-thermal 
        ok = run_cmd(
            f"{GETDP} LoVe.pro -msh LoVe.msh "
            f"-setnumber Flag_AnalysisType 2 -solve Magnetothermal -pos Post_Thermal -v2",
            "thermal solve"
        )
        if ok:
            ok = run_cmd(
                f"{GETDP} LoVe.pro -msh LoVe.msh "
                f"-setnumber Flag_AnalysisType 2 -pos Post_MagTher -v2",
                "thermal post"
            )
        if ok:
            run_cmd("python3 postmax.py", "postmax")
            row["T_max"] = read_scalar("res/t_max.dat")
            print(f"  T_max = {row['T_max']:.8f} °C")

        rows.append(row)

finally:
    with open("cable.toml", "w") as f:
        f.write(orig_toml)
    print("\nRestored cable.toml")
    print("Regenerating reference mesh …")
    run_cmd(f"{PYTHON} geometry.py", "reference mesh")
    run_cmd(
        f"{GETDP} LoVe.pro -msh LoVe.msh -solve Electrodynamics -pos Post_Ele -v2",
        "restore electro"
    )
    run_cmd(
        f"{GETDP} LoVe.pro -msh LoVe.msh -setnumber Flag_AnalysisType 1 "
        f"-solve Magnetoquasistatics -pos Post_Mag -v2",
        "restore MQS"
    )
    run_cmd(
        f"{GETDP} LoVe.pro -msh LoVe.msh -setnumber Flag_AnalysisType 2 "
        f"-solve Magnetothermal -pos Post_Thermal -v2",
        "restore thermal solve"
    )
    run_cmd(
        f"{GETDP} LoVe.pro -msh LoVe.msh -setnumber Flag_AnalysisType 2 "
        f"-pos Post_MagTher -v2",
        "restore thermal post"
    )
    run_cmd("python3 postmax.py", "restore postmax")


#  SVG plotting 
def convergence_svg(
    outpath: str,
    quantity: str,
    unit: str,
    title: str,
    ys: list,
    nodes: list,
    fmt: str = ".4e",
):
    """Write a two-panel SVG: absolute value (left) + convergence (right)."""
    pts = [(n, y) for n, y in zip(nodes, ys) if n and y is not None]
    if not pts:
        print(f"  No data for {outpath} – skipping")
        return

    xs, ys_v = zip(*pts)
    xs = list(xs)
    ys_v = list(ys_v)

    ref = ys_v[-1]
    rel_err = [abs(y - ref) / abs(ref) * 100 for y in ys_v[:-1]]
    xs_err  = xs[:-1]

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 4.0))
    fig.patch.set_facecolor("white")

    #  Left: absolute value 
    ax1.plot(xs, ys_v, "o-", color=C_ACCENT, lw=2.3, ms=8, zorder=3, clip_on=False)
    ax1.fill_between(xs, min(ys_v) * 0.999, ys_v, alpha=0.07, color=C_ACCENT)
    for x, y in zip(xs, ys_v):
        label_scale = SCALES[xs.index(x)] if x in xs else "?"
        ax1.annotate(
            f"×{label_scale}",
            xy=(x, y), xytext=(0, 9), textcoords="offset points",
            ha="center", fontsize=8.5, color=C_NAVY,
        )
    ax1.annotate(
        f"ref = {ref:{fmt[1:]}}", xy=(xs[-1], ref),
        xytext=(-8, -14), textcoords="offset points",
        ha="right", fontsize=9, color=C_ACCENT,
    )
    ax1.set_xlabel("Mesh nodes", fontsize=11)
    ax1.set_ylabel(f"{quantity}  [{unit}]", fontsize=11)
    ax1.set_title(f"{title} — value", fontsize=11, fontweight="bold")
    ax1.grid(True, alpha=0.3)
    ax1.set_xlim(left=0)

    #  Right: convergence 
    if rel_err:
        ax2.semilogy(xs_err, rel_err, "s-", color=C_GOLD, lw=2.3, ms=8, zorder=3,
                     label="relative diff. vs finest mesh")
        for x, e in zip(xs_err, rel_err):
            ax2.annotate(
                f"{e:.3f}%", xy=(x, e), xytext=(5, 4),
                textcoords="offset points", fontsize=8.5, color=C_NAVY,
            )
    ax2.axhline(0.1, color=C_RED, ls="--", lw=1.5, label="0.1 % threshold")
    ax2.legend(fontsize=9)
    ax2.set_xlabel("Mesh nodes", fontsize=11)
    ax2.set_ylabel("Relative difference vs finest mesh (%)", fontsize=11)
    ax2.set_title("Convergence", fontsize=11, fontweight="bold")
    ax2.grid(True, which="both", alpha=0.25)
    ax2.set_xlim(left=0)

    for ax in (ax1, ax2):
        ax.spines[["top", "right"]].set_visible(False)
        ax.tick_params(labelsize=10)

    fig.tight_layout(pad=1.5)
    fig.savefig(outpath, format="svg", bbox_inches="tight")
    plt.close(fig)
    print(f"  ✓ {outpath}")


nodes_list = [r.get("nodes") for r in rows]
C_list     = [r.get("C")     for r in rows]
L_list     = [r.get("L")     for r in rows]
Tmax_list  = [r.get("T_max") for r in rows]

print("\n Generating SVG plots ")
convergence_svg("res/conv_electro.svg", "C", "F/m",  "Capacitance",  C_list,     nodes_list, ".4e")
convergence_svg("res/conv_mqs.svg",     "L", "H/m",  "Inductance",   L_list,     nodes_list, ".4e")
convergence_svg("res/conv_thermal.svg", "T_max", "°C","T_max", Tmax_list, nodes_list, ".7f")

print("\n [V] mesh_convergence.py done – plots saved to res/")
