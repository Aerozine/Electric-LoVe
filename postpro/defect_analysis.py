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

import os, re, subprocess
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

V_sim   = toml_val(orig_toml, "line_voltage_rms") or 3000.0
V_rated = 33000.0
scale   = V_rated / V_sim    # 11.0


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


BUBBLE_PHYS = 80   # AirBubble physical group tag (PHYS["AIR_BUBBLE"] in generator.py)


def parse_em_bubble(path):
    """
    Parse res/em.pos (MSH2 + $ElementNodeData).
    Return (max |E|, sample_count) among elements in the AirBubble physical group (tag 80).
    """
    if not os.path.exists(path):
        return None, 0
    with open(path) as f:
        content = f.read()

    # --- elements in the AirBubble physical group ---
    bubble_eids = set()
    in_sec = False
    for line in content.split('\n'):
        t = line.strip()
        if t == '$Elements':      in_sec = True;  continue
        if t == '$EndElements':   in_sec = False; continue
        if in_sec:
            p = t.split()
            # MSH2: elm-number elm-type ntags tag1 tag2 ... nodes
            if len(p) >= 5 and p[1] == '2' and int(p[2]) >= 1:
                if int(p[3]) == BUBBLE_PHYS:
                    bubble_eids.add(int(p[0]))

    if not bubble_eids:
        return None, 0

    # --- first $ElementNodeData block (scalar |E|) ---
    vals = {}
    in_sec = False
    headers_seen = 0
    for line in content.split('\n'):
        t = line.strip()
        if t == '$ElementNodeData':
            in_sec = True; headers_seen = 0; continue
        if t == '$EndElementNodeData':
            if vals:
                break
            in_sec = False; continue
        if not in_sec:
            continue
        headers_seen += 1
        if headers_seen <= 5:
            continue
        p = t.split()
        if len(p) == 5:
            try:
                eid = int(p[0])
                nn  = int(p[1])
                if nn == 3:
                    v = max(abs(float(p[2])), abs(float(p[3])), abs(float(p[4])))
                    vals[eid] = v
            except ValueError:
                pass

    # --- max E strictly inside the air bubble ---
    max_e = None
    sample_count = 0
    for eid in bubble_eids:
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

        E_sim, n_samples = parse_em_bubble("res/em.pos")

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
xs            = [r for r in R_DEF_UM if results.get(r) is not None]
ys_rated      = [results[r][0] / 1e6 for r in xs]   # MV/m @ 33 kV
ys_sim        = [v / scale for v in ys_rated]        # MV/m @ V_sim (Gmsh view_elec)
sample_counts = [results[r][1] for r in xs]

fig, ax = plt.subplots(figsize=(10, 6.5))
fig.patch.set_facecolor("white")

if xs:
    ax.plot(xs, ys_sim, "o-", color=C_ACCENT, lw=2.3, ms=8, zorder=3,
            label=f"|E| inside bubble (FEM, {V_sim/1000:.0f} kV sim)")
    for x, y, n in zip(xs, ys_sim, sample_counts):
        label = f"{y:.3f}" if n >= 6 else f"{y:.3f}*"
        ax.annotate(label, xy=(x, y), xytext=(0, 9),
                    textcoords="offset points", ha="center",
                    fontsize=9, color=C_NAVY)

if xs and any(n < 6 for n in sample_counts):
    ax.text(0.05, 0.04, "* mesh-sensitive sample (<6 elements inside bubble)",
            transform=ax.transAxes, fontsize=8.5, color=C_NAVY)

ax.set_xlabel("Bubble radius  (µm)", fontsize=12)
ax.set_ylabel(f"|E| inside bubble  (MV/m)  —  {V_sim/1000:.0f} kV sim", fontsize=11)
ax.set_title(
    f"FEM field inside air bubble vs bubble radius\n"
    f"@ {V_sim/1000:.0f} kV simulation  (make view_elec)",
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
