import gmsh
import numpy as np
import sys
from generator import *

# Base physical group IDs used by GetDP to identify regions in the .pro file.
# These must match the Region[] numbers in generated_common.pro.
PHYS = {"COPPER": 10, "SEMI": 20, "POLY": 30, "WATER": 40, "BOUNDARY": 50}


physical_map = []


def unitp10(x, y, z=0):
    # PolyEt( Semi( Copper
    copper = gmsh.model.occ.addDisk(x, y, z, copper_diam, copper_diam)
    gmsh.model.occ.synchronize()

    semi_outer = gmsh.model.occ.addDisk(
        x, y, z, copper_insulator_semi, copper_insulator_semi
    )
    copper_copy = gmsh.model.occ.addDisk(x, y, z, copper_diam, copper_diam)
    gmsh.model.occ.synchronize()
    semi_ring, _ = gmsh.model.occ.cut(
        [(2, semi_outer)], [(2, copper_copy)], removeObject=True, removeTool=True
    )
    gmsh.model.occ.synchronize()

    polyet_outer = gmsh.model.occ.addDisk(
        x, y, z, copper_insulator_polyet, copper_insulator_polyet
    )
    semi_copy = gmsh.model.occ.addDisk(
        x, y, z, copper_insulator_semi, copper_insulator_semi
    )
    gmsh.model.occ.synchronize()
    polyet_ring, _ = gmsh.model.occ.cut(
        [(2, polyet_outer)], [(2, semi_copy)], removeObject=True, removeTool=True
    )
    gmsh.model.occ.synchronize()

    copper_tag = copper
    semi_tag = semi_ring[0][1]
    polyet_tag = polyet_ring[0][1]

    return copper_tag, semi_tag, polyet_tag


def add_physical(dim, tags, name, phys_id):
    gmsh.model.addPhysicalGroup(dim, tags, phys_id)
    gmsh.model.setPhysicalName(dim, phys_id, name)
    tag_str = ";".join(map(str, tags))
    physical_map.append([name, dim, phys_id, tag_str])


"""
for minimum radius 
we have for 3
"""
#  A--r--B
#   \   /
#    \ /
#     X
"""
where A , B are radius center and X the center
we have AXB= alpha = 2 pi / k (k=3)
h = 2tan (alpha)/r
"""


def generate_unitp10_triplet(cx, cy, ndim=2):
    R = copper_insulator_polyet
    d = 2 * R * np.tan(np.pi / 6)

    angles = np.arange(3) * (2 * np.pi / 3)

    coords = np.column_stack((cx + d * np.cos(angles), cy + d * np.sin(angles)))

    pre_copper, pre_semi, pre_poly = [], [], []
    for x, y in coords:
        copper, semi, poly = unitp10(x, y)
        pre_copper.append(copper)
        pre_semi.append(semi)
        pre_poly.append(poly)

    return pre_copper, pre_semi, pre_poly


def outer_dielec(infinity_diameter=infinity_diameter, cx=0, cy=0, ndim=2):
    outer_disk = gmsh.model.occ.addDisk(
        cx, cy, 0, infinity_diameter / 2, infinity_diameter / 2
    )
    gmsh.model.occ.synchronize()
    return outer_disk


def assign_physical_groups(
    pre_copper, pre_semi, pre_poly, pre_water, out_map, all_surfs, ndim=2
):
    def to_tag(e):
        # Normalise a fragment output entry to a plain integer surface tag.
        # Gmsh returns (dim, tag) tuples in some versions and raw ints in others.
        return int(e[1]) if isinstance(e, (tuple, list)) else int(e)

    # Build a dict mapping old (dim, tag) to list of new surface tags.
    old_to_new = {}
    for (old_dim, old_tag), new_entry in zip(all_surfs, out_map):
        if isinstance(new_entry, (tuple, list)) and not isinstance(
            new_entry[0], (tuple, list, int, float)
        ):
            new_tags = [to_tag(e) for e in new_entry]
        else:
            new_tags = [to_tag(new_entry)]
        old_to_new[(old_dim, old_tag)] = new_tags

    def resolve(tag):
        # Return the list of post-fragment surface tags for a pre-fragment tag.
        return old_to_new.get((2, tag), [tag])

    # Assign one physical group per cable layer per cable
    all_cable_tags = set()
    for i, (cu, se, po) in enumerate(zip(pre_copper, pre_semi, pre_poly)):
        cu_new = resolve(cu)
        se_new = resolve(se)
        po_new = resolve(po)
        add_physical(ndim, cu_new, f"Copper_{i}", PHYS["COPPER"] + i)
        add_physical(ndim, se_new, f"Semi_{i}", PHYS["SEMI"] + i)
        add_physical(ndim, po_new, f"PolyEt_{i}", PHYS["POLY"] + i)
        all_cable_tags.update(cu_new + se_new + po_new)

    # Water flows everywhere
    water_tags = [t for _, t in gmsh.model.getEntities(ndim) if t not in all_cable_tags]
    add_physical(ndim, water_tags, "Water", PHYS["WATER"])

    # The outer Dirichlet boundary is the set of 1D curves on the outer circle.
    # define outer by sufficiently (0.9 R_inf) large
    # TODO better solution ?
    R_inf = infinity_diameter / 2
    wb = gmsh.model.getBoundary(
        [(ndim, t) for t in water_tags], oriented=False, recursive=False
    )
    outer_curves = []
    for bdim, ctag in wb:
        xmin, ymin, _, xmax, ymax, _ = gmsh.model.getBoundingBox(bdim, ctag)
        r = max(abs(xmin), abs(xmax), abs(ymin), abs(ymax))
        if r > R_inf * 0.9:
            outer_curves.append(ctag)

    # Add Physical Line for outer Dirichlet boundary (tag 50 in GetDP)
    gmsh.model.addPhysicalGroup(1, outer_curves, PHYS["BOUNDARY"])
    gmsh.model.setPhysicalName(1, PHYS["BOUNDARY"], "Outer_boundary")


def set_mesh_sizes(dtot):
    cl = dtot / 3
    phys = gmsh.model.getPhysicalGroups()
    print(f"Assigning sizes to {len(phys)} physical groups...")

    for dim, tag in phys:
        name = gmsh.model.getPhysicalName(dim, tag)
        entities = gmsh.model.getEntitiesForPhysicalGroup(dim, tag)

        # Retrieve all mesh points belonging to this group's boundary
        boundary = gmsh.model.getBoundary(
            [(dim, e) for e in entities], oriented=False, recursive=True
        )
        points = [p for p in boundary if p[0] == 0]

        if "Copper" in name:
            gmsh.model.mesh.setSize(points, cl / 16)
        elif "Semi" in name or "PolyEt" in name or "Water" in name:
            gmsh.model.mesh.setSize(points, cl / 8)

        if dim == 1 and tag == PHYS["BOUNDARY"]:
            gmsh.model.mesh.setSize(points, cl)


def write_physical_map_csv(filename="map.csv"):
    # generate a map.csv that has every usefull information
    # used for debug purpose + generate common.pro
    if len(physical_map) == 0:
        return
    data = np.array(physical_map, dtype=object)
    header = "name,dimension,physical_id,entity_tags"
    np.savetxt(filename, data, fmt="%s", delimiter=",", header=header, comments="")


def generate_mesh(dtot):
    # MeshSizeFromPoints: respect the sizes set on geometric points.
    gmsh.option.setNumber("Mesh.MeshSizeFromPoints", 1)
    # MeshSizeFromCurvature: disabled to avoid overriding explicit sizes.
    gmsh.option.setNumber("Mesh.MeshSizeFromCurvature", 0)
    # MeshSizeExtendFromBoundary: propagate boundary sizes into the interior.
    gmsh.option.setNumber("Mesh.MeshSizeExtendFromBoundary", 1)
    set_mesh_sizes(dtot)

    gmsh.model.mesh.generate(2)


ndim = 2
if __name__ == "__main__":
    try:
        gmsh.initialize()
        # quiet gmsh
        # gmshhhhhhh
        gmsh.option.setNumber("General.Terminal", 0)
        gmsh.model.add("cables")

        gmsh.model.occ.synchronize()

        # Build the three cable units and the outer water disk.
        # Physical groups are NOT assigned yet because fragment will remap tags.
        pre_copper, pre_semi, pre_poly = generate_unitp10_triplet(0, 0)
        gmsh.model.occ.synchronize()
        pre_water = outer_dielec()
        gmsh.model.occ.synchronize()

        # BooleanFragments: intersect all surfaces and remove destroyed ones.
        # Equivalent to the Gmsh geo syntax:
        #     BooleanFragments{ Surface{:}; Delete; }{}
        # out_map records how each input surface maps to its output surface(s).
        all_2d = gmsh.model.occ.getEntities(2)
        out_map, _ = gmsh.model.occ.fragment(all_2d, [])
        gmsh.model.occ.synchronize()

        # Now that fragment has stabilised the tags, assign physical groups.
        assign_physical_groups(
            pre_copper, pre_semi, pre_poly, pre_water, out_map, all_2d
        )

        write_physical_map_csv()
        generate_mesh(infinity_diameter / 5)
        gmsh.write("LoVe.msh")
        gmsh.write("LoVe.step")

        # generate the common_pro based on the map.csv
        # allow us to centralize every problem value to the
        # .toml file
        generate_like_a_pro()
        if "-popup" in sys.argv:
            gmsh.fltk.run()

    except Exception as e:
        print(f"Error: {e}")
        import traceback

        traceback.print_exc()
    finally:
        gmsh.finalize()
