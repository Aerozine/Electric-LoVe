#!/usr/bin/env python3
"""
defect_analysis.py
------------------
FEM study of air bubble breakdown risk in XLPE insulation.

For each bubble radius in R_DEF_UM:
  1. Patch [defect] radius in cable.toml
  2. Regenerate mesh + run Electrodynamics
  3. Extract max |E| inside bubble from res/em.pos ($ElementNodeData)
  4. Scale to rated 33 kV

Output: slides/graphs/defect_field.svg
"""

import os, re, math, subprocess
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

PYTHON = os.environ.get("MESH_PYTHON", "./gmsh/bin/python")
GETDP  = os.environ.get("MESH_GETDP",  "getdp")

R_DEF_UM = [100, 150, 200, 250, 300, 400, 500]   # µm

C_ACCENT = "#0f6e84"
C_RED    = "#c1121f"
C_NAVY   = "#1a1a2e"

os.makedirs("slides/graphs", exist_ok=True)


# --- cable.toml helpers ------------------------------------------------------
def toml_val(text, key):
    m = re.search(rf'^{key}\s*=\s*([\d.e+\-]+)', text, re.MULTILINE)
    return float(m.group(1)) if m else None


def toml_section_val(text, section, key):
    block = re.search(rf'\[{section}\].*?(?=\[|\Z)', text, re.DOTALL)
    if not block:
        return None
    return toml_val(block.group(), key)


with open("cable.toml") as f:
    orig_toml = f.read()

mm = lambda x: x * 1e-3

r_ins   = mm(toml_val(orig_toml, "insulation_outer_diameter") / 2)
r_semi  = mm(toml_val(orig_toml, "semiconductor_outer_diameter") / 2)
clr     = mm(toml_val(orig_toml, "core_clearance"))
rel_r   = toml_section_val(orig_toml, "defect", "relative_radius") or 0.65
d_ang   = toml_section_val(orig_toml, "defect", "angle") or (math.pi / 4)
V_sim   = toml_val(orig_toml, "line_voltage_rms") or 3000.0
V_rated = 33000.0
scale   = V_rated / V_sim    # 11.0

# Phase 0 centre (trefoil geometry, same formula as geometry.py)
pair_radius = (2 * r_ins + clr) / math.sqrt(3)
cx0, cy0    = 0.0, pair_radius

# Defect centre (fixed for all bubble radii)
r_def_pos = r_semi + rel_r * (r_ins - r_semi)
bubble_cx = cx0 + r_def_pos * math.cos(d_ang)
bubble_cy = cy0 + r_def_pos * math.sin(d_ang)


# --- helpers -----------------------------------------------------------------
def run_cmd(cmd, label=""):
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"  X {label}: {r.stderr[-300:]}")
    return r.returncode == 0


def patch_defect_radius(text, r_m):
    """Replace radius value inside [defect] section only."""
    def repl(m):
        return re.sub(
            r'^(\s*radius\s*=\s*)[\d.e+\-]+',
            rf'\g<1>{r_m:.8g}',
            m.group(0), flags=re.MULTILINE,
        )
    return re.sub(r'\[defect\].*?(?=\[|\Z)', repl, text, flags=re.DOTALL)


def parse_em_bubble(path, cx, cy, search_r):
    """
    Parse res/em.pos (MSH2 + $ElementNodeData).
    Return (max |E|, sample_count) among triangle elements whose centroid is within search_r.
    """
    if not os.path.exists(path):
        return None
    with open(path) as f:
        content = f.read()

    # --- nodes ---
    nodes = {}
    in_sec = False
    for line in content.split('\n'):
        t = line.strip()
        if t == '$Nodes':      in_sec = True;  continue
        if t == '$EndNodes':   in_sec = False; continue
        if in_sec:
            p = t.split()
            if len(p) == 4:
                nodes[int(p[0])] = (float(p[1]), float(p[2]))

    # --- triangles (type 2) ---
    tris = {}
    in_sec = False
    for line in content.split('\n'):
        t = line.strip()
        if t == '$Elements':      in_sec = True;  continue
        if t == '$EndElements':   in_sec = False; continue
        if in_sec:
            p = t.split()
            if len(p) >= 5 and p[1] == '2':
                tris[int(p[0])] = (int(p[-3]), int(p[-2]), int(p[-1]))

    # --- first $ElementNodeData block (scalar |E|, real part) ---
    vals = {}
    in_sec = False
    for line in content.split('\n'):
        t = line.strip()
        if t == '$ElementNodeData':
            in_sec = True; continue
        if t == '$EndElementNodeData':
            if vals:
                break          # stop after first non-empty block
            in_sec = False; continue
        if not in_sec:
            continue
        p = t.split()
        # Data rows have exactly 5 tokens: elem_id  3  v0  v1  v2
        if len(p) == 5:
            try:
                eid = int(p[0])
                nn  = int(p[1])
                if nn == 3:
                    v = max(abs(float(p[2])), abs(float(p[3])), abs(float(p[4])))
                    vals[eid] = v
            except ValueError:
                pass

    # --- find max E near bubble centre ---
    max_e = None
    sample_count = 0
    for eid, (n1, n2, n3) in tris.items():
        c1 = nodes.get(n1); c2 = nodes.get(n2); c3 = nodes.get(n3)
        if not (c1 and c2 and c3):
            continue
        tx = (c1[0] + c2[0] + c3[0]) / 3
        ty = (c1[1] + c2[1] + c3[1]) / 3
        if math.sqrt((tx - cx)**2 + (ty - cy)**2) < search_r:
            v = vals.get(eid)
            if v is not None:
                sample_count += 1
                max_e = max(max_e, v) if max_e is not None else v
    return max_e, sample_count


# --- main loop ---------------------------------------------------------------
results = {}   # {r_um: (E_rated (V/m), sample_count) or None}

try:
    for r_um in R_DEF_UM:
        r_m = r_um * 1e-6
        print(f"\n{'--'*24}\n  r_def = {r_um} µm\n{'--'*24}")

        with open("cable.toml", "w") as f:
            f.write(patch_defect_radius(orig_toml, r_m))

        if not run_cmd(f"{PYTHON} geometry.py", "geometry"):
            results[r_um] = None; continue
        if not run_cmd(
            f"{GETDP} LoVe.pro -msh LoVe.msh -solve Electrodynamics -pos Post_Ele -v2",
            "Electrodynamics"
        ):
            results[r_um] = None; continue

        search_r = 1.15 * r_m
        E_sim, n_samples = parse_em_bubble("res/em.pos", bubble_cx, bubble_cy, search_r)

        if E_sim is not None:
            E_rated = E_sim * scale
            results[r_um] = (E_rated, n_samples)
            print(
                f"  E_sim = {E_sim:.3e} V/m  ->  E_rated = {E_rated/1e6:.3f} MV/m"
                f"  ({n_samples} elements sampled)"
            )
        else:
            results[r_um] = None
            print("  WARNING: no elements found near bubble")

finally:
    with open("cable.toml", "w") as f:
        f.write(orig_toml)
    print("\nRestored cable.toml")
    run_cmd(f"{PYTHON} geometry.py", "restore geometry")
    run_cmd(
        f"{GETDP} LoVe.pro -msh LoVe.msh -solve Electrodynamics -pos Post_Ele -v2",
        "restore electro"
    )


# --- plot --------------------------------------------------------------------
E_bd_air = 3.0   # MV/m  (air DC breakdown plateau for large gaps)

xs = [r for r in R_DEF_UM if results.get(r) is not None]
ys = [results[r][0] / 1e6 for r in xs]
sample_counts = [results[r][1] for r in xs]

fig, ax = plt.subplots(figsize=(10, 6.5))
fig.patch.set_facecolor("white")

if xs:
    ax.plot(xs, ys, "o-", color=C_ACCENT, lw=2.3, ms=8, zorder=3,
            label="|E| inside bubble (FEM, rated 33 kV)")
    for x, y, n in zip(xs, ys, sample_counts):
        label = f"{y:.2f}" if n >= 6 else f"{y:.2f}*"
        ax.annotate(label, xy=(x, y), xytext=(0, 9),
                    textcoords="offset points", ha="center",
                    fontsize=9, color=C_NAVY)

# Air breakdown threshold
ax.axhline(E_bd_air, color=C_RED, ls="--", lw=2.0,
           label=f"Air breakdown threshold  {E_bd_air:.0f} MV/m")

# Shade PD zone (above threshold)
if xs and any(y > E_bd_air for y in ys):
    ax.fill_between(xs, E_bd_air, [max(y, E_bd_air) for y in ys],
                    where=[y > E_bd_air for y in ys],
                    color=C_RED, alpha=0.10, label="PD zone")

# Find critical radius (first crossing from below)
r_crit = None
for i in range(len(xs) - 1):
    if (ys[i] - E_bd_air) * (ys[i + 1] - E_bd_air) < 0:
        r_crit = 0.5 * (xs[i] + xs[i + 1])
        break
if r_crit is not None:
    ax.axvline(r_crit, color=C_RED, ls=":", lw=1.5,
               label=f"r_crit ≈ {r_crit:.0f} µm")
elif xs and ys[0] > E_bd_air:
    ax.text(0.05, 0.10, "All tested radii in PD zone",
            transform=ax.transAxes, fontsize=10, color=C_RED, style="italic")

if xs and any(n < 6 for n in sample_counts):
    ax.text(0.05, 0.04, "* mesh-sensitive sample (<6 elements inside bubble)",
            transform=ax.transAxes, fontsize=8.5, color=C_NAVY)

ax.set_xlabel("Bubble radius  (µm)", fontsize=12)
ax.set_ylabel("|E| inside bubble  (MV/m)", fontsize=11)
ax.set_title(
    "FEM field inside air bubble vs bubble radius\n@ 33 kV rated line voltage",
    fontsize=12, fontweight="bold",
)
ax.legend(fontsize=10)
ax.grid(True, alpha=0.25)
ax.spines[["top", "right"]].set_visible(False)
ax.tick_params(labelsize=10)

fig.tight_layout(pad=2.0)
fig.savefig("slides/graphs/defect_field.svg", format="svg", bbox_inches="tight")
plt.close(fig)
print("\n+ Saved slides/graphs/defect_field.svg")
