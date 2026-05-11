#!/usr/bin/env python3
"""
freq_sweep.py
-------------
Sweeps frequency from 1 Hz to 1 kHz and records:
  - C (capacitance, F/m)        -- from Electrodynamics
  - I_c (charging current, A/m) -- from omega C V_phase
  - T_max (deg C)               -- from coupled Magneto-thermal

Outputs:
  res/freq_sweep_em.svg      -- C and charging current vs frequency
  res/freq_sweep_thermal.svg -- relative DeltaT vs frequency

Usage
-----
    ./gmsh/bin/python freq_sweep.py
"""

import os
import re
import math
import subprocess

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

PYTHON = os.environ.get("MESH_PYTHON", "./gmsh/bin/python")
GETDP  = os.environ.get("MESH_GETDP",  "getdp")

# Frequencies to sweep (Hz)
FREQS_EM      = [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000]
FREQS_THERMAL = [50, 100, 200, 500, 1000]   # thermal runs are slower

C_ACCENT = "#0f6e84"
C_GOLD   = "#e8a838"
C_RED    = "#c1121f"
C_NAVY   = "#1a1a2e"
C_GREEN  = "#2d6a4f"


# --- TOML patcher ------------------------------------------------------------
def patch_frequency(text: str, freq: float) -> str:
    return re.sub(
        r'^(frequency\s*=\s*)[\d.e+\-]+',
        rf'\g<1>{freq}',
        text, flags=re.MULTILINE
    )


# --- Helpers -----------------------------------------------------------------
def run_cmd(cmd: str, label: str = "") -> bool:
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"  X {label or cmd[:50]}: {r.stderr[-200:]}")
    return r.returncode == 0


def read_scalar(path: str):
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


# --- Simulation loops --------------------------------------------------------
os.makedirs("slides/graphs", exist_ok=True)

with open("cable.toml") as f:
    orig_toml = f.read()

# Read scalar settings from cable.toml
T_amb = 20.0
V_ll = 3000.0
for line in orig_toml.splitlines():
    m = re.match(r'^\s*ambient_temperature\s*=\s*([\d.e+\-]+)', line)
    if m:
        T_amb = float(m.group(1))
    m = re.match(r'^\s*line_voltage_rms\s*=\s*([\d.e+\-]+)', line)
    if m:
        V_ll = float(m.group(1))
V_phase = V_ll / math.sqrt(3.0)

rows_em      = []   # {freq, C}
rows_thermal = []   # {freq, T_max, delta_T}

print("Meshing once (geometry unchanged across frequencies)...")
run_cmd(f"{PYTHON} geometry.py", "mesh")

try:
    # EM sweep
    for freq in FREQS_EM:
        print(f"\n  f = {freq} Hz")
        with open("cable.toml", "w") as f:
            f.write(patch_frequency(orig_toml, freq))
        run_cmd(f'{PYTHON} -c "from generator import generate_all; generate_all()"',
                "generator")

        row = {"freq": freq}

        if run_cmd(
            f"{GETDP} LoVe.pro -msh LoVe.msh -solve Electrodynamics -pos Post_Ele -v2",
            "electro"
        ):
            row["C"] = read_scalar("res/C.dat")

        rows_em.append(row)

    # Thermal sweep (subset of frequencies, nonlinear=0 for speed)
    for freq in FREQS_THERMAL:
        print(f"\n  Thermal at f = {freq} Hz")
        with open("cable.toml", "w") as f:
            f.write(patch_frequency(orig_toml, freq))
        run_cmd(f'{PYTHON} -c "from generator import generate_all; generate_all()"',
                "generator")

        ok = run_cmd(
            f"{GETDP} LoVe.pro -msh LoVe.msh "
            f"-setnumber Flag_AnalysisType 2 -solve Magnetothermal -pos Post_Thermal -v2",
            f"thermal f={freq}Hz"
        )
        if ok:
            ok = run_cmd(
                f"{GETDP} LoVe.pro -msh LoVe.msh "
                f"-setnumber Flag_AnalysisType 2 -pos Post_MagTher -v2",
                "thermal post"
            )
        if ok:
            run_cmd("python3 postpro/postmax.py", "postmax")
            T_max = read_scalar("res/t_max.dat")
            rows_thermal.append({
                "freq":    freq,
                "T_max":   T_max,
                "delta_T": T_max - T_amb if T_max else None,
            })

finally:
    with open("cable.toml", "w") as f:
        f.write(orig_toml)
    print("\nRestored cable.toml")
    run_cmd(f'{PYTHON} -c "from generator import generate_all; generate_all()"',
            "restore generator")
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
        "restore thermal"
    )
    run_cmd(
        f"{GETDP} LoVe.pro -msh LoVe.msh -setnumber Flag_AnalysisType 2 "
        f"-pos Post_MagTher -v2",
        "restore thermal post"
    )
    run_cmd("python3 postpro/postmax.py", "restore postmax")


# --- EM plot -----------------------------------------------------------------
fig, axes = plt.subplots(1, 2, figsize=(12, 5.0))
fig.patch.set_facecolor("white")

# Panel 1: C vs f
C_vals = [r.get("C") for r in rows_em]
C_freqs = [r["freq"] for r in rows_em if r.get("C") is not None]
C_data  = [r["C"] * 1e12 for r in rows_em if r.get("C") is not None]  # pF/m
if C_data:
    axes[0].semilogx(C_freqs, C_data, "o-", color=C_ACCENT, lw=2.2, ms=7)
    axes[0].set_xlabel("Frequency (Hz)", fontsize=11)
    axes[0].set_ylabel("C  (pF/m)", fontsize=11)
    axes[0].set_title("Capacitance vs frequency", fontsize=11, fontweight="bold")
    axes[0].grid(True, which="both", alpha=0.28)
    # Annotate that C is flat -- purely dielectric
    axes[0].text(0.05, 0.92, "Flat: C independent of f\n(XLPE is ideal dielectric)",
                 transform=axes[0].transAxes, fontsize=9, color=C_NAVY,
                 bbox=dict(boxstyle="round,pad=0.3", fc="white", ec="#ccc", alpha=0.85))

# Panel 2: capacitive charging current vs f
Ic_freqs = [r["freq"] for r in rows_em if r.get("C") is not None]
Ic_data = [
    2 * math.pi * r["freq"] * r["C"] * V_phase * 1e6
    for r in rows_em if r.get("C") is not None
]  # microampere/m
if Ic_data:
    axes[1].semilogx(Ic_freqs, Ic_data, "o-", color=C_GREEN, lw=2.2, ms=7)
    axes[1].axvline(50, color=C_NAVY, ls=":", lw=1.2, alpha=0.6, label="50 Hz")
    axes[1].set_xlabel("Frequency (Hz)", fontsize=11)
    axes[1].set_ylabel("Charging current (µA/m)", fontsize=11)
    axes[1].set_title("Capacitive current grows linearly with f",
                      fontsize=11, fontweight="bold")
    axes[1].legend(fontsize=9)
    axes[1].grid(True, which="both", alpha=0.28)

for ax in axes:
    ax.spines[["top", "right"]].set_visible(False)
    ax.tick_params(labelsize=10)

fig.tight_layout(pad=1.5)
fig.savefig("slides/graphs/freq_sweep_em.svg", format="svg", bbox_inches="tight")
plt.close(fig)
print("+ Saved graphs/freq_sweep_em.svg")


# --- Thermal plot ------------------------------------------------------------
fig2, ax_t = plt.subplots(figsize=(10, 5.5))
fig2.patch.set_facecolor("white")

th_freqs = [r["freq"]    for r in rows_thermal if r.get("delta_T") is not None]
th_dT = [r["delta_T"] for r in rows_thermal if r.get("delta_T") is not None]
base_dT = th_dT[0] if th_dT else None
th_rel = [(v / base_dT - 1.0) * 100.0 for v in th_dT] if base_dT else []

if th_rel:
    ax_t.plot(th_freqs, th_rel, "o-", color=C_RED, lw=2.3, ms=8,
              label="FEM relative DeltaT")
    for x, y in zip(th_freqs, th_rel):
        ax_t.annotate(f"{y:.2f}%", xy=(x, y), xytext=(0, 9),
                      textcoords="offset points", ha="center",
                      fontsize=9, color=C_NAVY)

ax_t.axvline(50, color=C_NAVY, ls="--", lw=1.2, alpha=0.6, label="50 Hz (nominal)")
ax_t.set_xlabel("Frequency (Hz)", fontsize=11)
ax_t.set_ylabel("DeltaT increase vs 50 Hz  (%)", fontsize=11)
ax_t.set_title("Relative temperature-rise increase vs frequency",
               fontsize=11, fontweight="bold")
ax_t.legend(fontsize=9)
ax_t.grid(True, alpha=0.28)
ax_t.spines[["top", "right"]].set_visible(False)
ax_t.tick_params(labelsize=10)

fig2.tight_layout(pad=1.5)
fig2.savefig("slides/graphs/freq_sweep_thermal.svg", format="svg", bbox_inches="tight")
plt.close(fig2)
print("+ Saved graphs/freq_sweep_thermal.svg")

print("\n+ freq_sweep.py done")
