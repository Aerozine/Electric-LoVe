"""Extract scalar maxima and min/max from GetDP .pos files into .dat files."""
import os

def parse_pos_max(fname):
    vals = []
    in_data = False
    headers_seen = 0
    with open(fname) as f:
        for line in f:
            t = line.strip()
            if t == "$ElementNodeData":
                in_data = True
                headers_seen = 0
                continue
            if t == "$EndElementNodeData":
                in_data = False
                continue
            if in_data:
                headers_seen += 1
                if headers_seen <= 5:   # skip: name, 1, time, 4, integers
                    continue
                parts = t.split()
                if len(parts) >= 3:
                    try:
                        n = int(parts[1])
                        for v in parts[2:2+n]:
                            vals.append(abs(float(v)))
                    except (ValueError, IndexError):
                        pass
    return max(vals) if vals else 0.0

def parse_pos_minmax(fname):
    vals = []
    in_data = False
    headers_seen = 0
    with open(fname) as f:
        for line in f:
            t = line.strip()
            if t == "$ElementNodeData":
                in_data = True
                headers_seen = 0
                continue
            if t == "$EndElementNodeData":
                in_data = False
                continue
            if in_data:
                headers_seen += 1
                if headers_seen <= 5:
                    continue
                parts = t.split()
                if len(parts) >= 3:
                    try:
                        n = int(parts[1])
                        for v in parts[2:2+n]:
                            vals.append(float(v))
                    except (ValueError, IndexError):
                        pass
    if not vals:
        return 0.0, 0.0
    return min(vals), max(vals)

def write_scalar(path, val):
    with open(path, "w") as f:
        f.write(f" 0 {val:.15e} 0\n")

os.makedirs("res", exist_ok=True)

scalar_max_fields = [
    ("res/em.pos",   "res/em_max.dat"),
    ("res/dm.pos",   "res/dm_max.dat"),
    ("res/jrm.pos",  "res/jrm_max.dat"),
    ("res/jdm.pos",  "res/jdm_max.dat"),
    ("res/jtm.pos",  "res/jtm_max.dat"),
    ("res/bm.pos",   "res/bm_max.dat"),
    ("res/jm.pos",   "res/jm_max.dat"),
    ("res/mt_bm.pos","res/mt_bm_max.dat"),
    ("res/mt_jm.pos","res/mt_jm_max.dat"),
    ("res/mt_losses_density.pos", "res/mt_q_max.dat"),
]

for posfile, datfile in scalar_max_fields:
    if os.path.exists(posfile):
        val = parse_pos_max(posfile)
        write_scalar(datfile, val)
        print(f"  {posfile}: max = {val:.4e}  -> {datfile}")
    else:
        print(f"  {posfile}: NOT FOUND (skipped)")

# Temperature min/max
if os.path.exists("res/temperature.pos"):
    t_min, t_max = parse_pos_minmax("res/temperature.pos")
    write_scalar("res/t_min.dat", t_min)
    write_scalar("res/t_max.dat", t_max)
    print(f"  temperature: T_min={t_min:.6f}  T_max={t_max:.6f}")
else:
    print("  res/temperature.pos: NOT FOUND")
