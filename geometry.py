import gmsh
import numpy as np
import sys
try:
    # Python 3.11+ – built‑in module
    import tomllib as toml_parser
except ImportError:
    # Python < 3.11 – external library
    import tomli as toml_parser   # type: ignore

with open("cable.toml", "rb") as f:
     data= toml_parser.load(f)
copper_diam = data["copper_diam"]*1e-3
copper_insulator_semi = data["copper_insulator_semi"]*1e-3
copper_insulator_polyet = data["copper_insulator_polyet"]*1e-3

gmsh.initialize()
gmsh.model.add("cables")
gmsh.model.occ.synchronize()

"""
the structure is 
(polyet(semi(copper)))
"""
def unitp10(x, y, z=0):
    copper = gmsh.model.occ.addDisk(x, y, z, copper_diam, copper_diam)
    semi = gmsh.model.occ.addDisk(x, y, z, copper_insulator_semi, copper_insulator_semi)
    polyet = gmsh.model.occ.addDisk(x, y, z, copper_insulator_polyet, copper_insulator_polyet)
    # Create semi ring: semi - copper
    semi_ring, _ = gmsh.model.occ.cut(
        [(2, semi)],
        [(2, copper)],
        removeObject=True,
        removeTool=False
    )
    # Create polyethylene ring: polyet - semi
    polyet_ring, _ = gmsh.model.occ.cut(
        [(2, polyet)],
        [(2, semi)],
        removeObject=True,
        removeTool=True
    )
    gmsh.model.occ.synchronize()

    copper_tag = copper
    semi_tag = semi_ring[0][1]
    polyet_tag = polyet_ring[0][1]

    return copper_tag, semi_tag, polyet_tag
def add_physical(dim, tags, name):
    pg = gmsh.model.addPhysicalGroup(dim, tags)
    gmsh.model.setPhysicalName(dim, pg, name)
"""
for minimum radius 
we have for 3
  A--r--B
   \   / 
    \ /
     X
where A , B are radius center and X the center
we have AXB= alpha = 2 pi / k (k=3)
h = 2tan (alpha)/r
"""

def generate_unitp10_triplet(cx, cy):
    R = copper_insulator_polyet
    # hard-coded with 3
    d = 2 * R * np.tan(np.pi/6)

    angles = np.arange(3) * (2*np.pi/3)

    coords = np.column_stack((
        cx + d * np.cos(angles),
        cy + d * np.sin(angles)
    ))

    for i,(x,y) in enumerate(coords):
        c,s,p = unitp10(x,y)
        add_physical(2,[c],f"Copper_{i}")
        add_physical(2,[s],f"Semi_{i}")
        add_physical(2,[p],f"Polyethylene_{i}")

generate_unitp10_triplet(0, 0)

gmsh.model.occ.synchronize()

#gmsh.option.setNumber("Mesh.CharacteristicLengthMin", ??? 0.01)
#gmsh.option.setNumber("Mesh.CharacteristicLengthMax", ??? 0.2)

gmsh.model.mesh.generate(2)

gmsh.write("LoVe.msh")
gmsh.write("LoVe.step")

# Launch GUI
if "-nopopup" not in sys.argv:
    gmsh.fltk.run()
gmsh.finalize()
