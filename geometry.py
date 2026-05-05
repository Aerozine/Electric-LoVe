import csv
import math
import sys

import gmsh

from generator import PHYS, generate_all, load_config, mm, radii_from_config


_MESH_CALLBACKS = []


def bool_cfg(cfg, section, key, default):
    return bool(cfg.get(section, {}).get(key, default))


def validate_geometry(cfg, radii):
    ordered = [
        ("conductor", radii["conductor"]),
        ("semiconductor", radii["semi"]),
        ("insulation", radii["insulation"]),
        ("layup", radii["layup"]),
        ("wrapping", radii["wrapping"]),
        ("inner_sheath", radii["inner_sheath"]),
    ]
    if bool_cfg(cfg, "general", "shield", True):
        ordered += [
            ("armour_1", radii["armour_1"]),
            ("armour_2", radii["armour_2"]),
            ("outer_sheath", radii["outer_sheath"]),
        ]
    ordered += [("environment", radii["environment"])]

    for (name_a, radius_a), (name_b, radius_b) in zip(ordered, ordered[1:]):
        if radius_a >= radius_b:
            raise ValueError(
                f"Invalid cable.toml geometry: {name_a} radius ({radius_a:g} m) "
                f"must be smaller than {name_b} radius ({radius_b:g} m)."
            )


def phase_centres(cfg, radii):
    clearance = mm(cfg["geometry"].get("core_clearance", 0.5))
    pair_radius = (2 * radii["insulation"] + clearance) / math.sqrt(3)
    outer_limit = radii["layup"] - radii["insulation"] - clearance
    if pair_radius > outer_limit:
        raise ValueError(
            "Invalid cable.toml geometry: layup_outer_diameter is too small for "
            f"three insulation circles with {clearance:g} m clearance."
        )
    radius = pair_radius
    angles = [
        math.pi / 2,
        math.pi / 2 - 2 * math.pi / 3,
        math.pi / 2 + 2 * math.pi / 3,
    ]
    return [(radius * math.cos(a), radius * math.sin(a)) for a in angles]


def surface_box(tag):
    xmin, ymin, _, xmax, ymax, _ = gmsh.model.getBoundingBox(2, tag)
    return xmin, ymin, xmax, ymax


def box_center_radius(tag):
    xmin, ymin, xmax, ymax = surface_box(tag)
    cx = 0.5 * (xmin + xmax)
    cy = 0.5 * (ymin + ymax)
    radius = max(0.5 * (xmax - xmin), 0.5 * (ymax - ymin))
    outer_radius = max(abs(xmin), abs(xmax), abs(ymin), abs(ymax))
    return cx, cy, radius, outer_radius


def add_physical(dim, tags, name, phys_id, physical_map):
    unique = sorted({int(t) for t in tags})
    if not unique:
        return
    gmsh.model.addPhysicalGroup(dim, unique, phys_id)
    gmsh.model.setPhysicalName(dim, phys_id, name)
    physical_map.append([name, dim, phys_id, ";".join(map(str, unique))])


def write_physical_map(physical_map, filename="map.csv"):
    with open(filename, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["name", "dimension", "physical_id", "entity_tags"])
        writer.writerows(physical_map)


def add_armour_wires(count, wire_radius, centre_radius, angle_offset=0.0):
    tags = []
    centres = []
    for i in range(count):
        angle = angle_offset + 2 * math.pi * i / count
        x = centre_radius * math.cos(angle)
        y = centre_radius * math.sin(angle)
        tags.append(gmsh.model.occ.addDisk(x, y, 0, wire_radius, wire_radius))
        centres.append((x, y, wire_radius))
    return tags, centres


def add_defect(cfg, radii, centres):
    defect = cfg.get("defect", {})
    if not bool(defect.get("enabled", False)):
        return [], []

    phase = int(defect.get("phase", 0))
    phase = max(0, min(phase, len(centres) - 1))
    angle = float(defect.get("angle", math.pi / 4))
    rel = float(defect.get("relative_radius", 0.65))
    radius = float(defect.get("radius", 0.00025))
    px, py = centres[phase]
    centre_r = radii["semi"] + rel * (radii["insulation"] - radii["semi"])
    x = px + centre_r * math.cos(angle)
    y = py + centre_r * math.sin(angle)
    return [gmsh.model.occ.addDisk(x, y, 0, radius, radius)], [(x, y, radius)]


def in_any_disk(x, y, disks, tol=1e-9):
    for cx, cy, radius in disks:
        if math.hypot(x - cx, y - cy) <= radius + tol:
            return True
    return False


def classify_surfaces(cfg, radii, phase_xy, armour1, armour2, bubbles):
    groups = {
        "Filling": [],
        "InnerSheath": [],
        "OuterSheath": [],
        "Armour1": [],
        "Armour2": [],
        "Environment": [],
        "EnvironmentInf": [],
        "AirBubble": [],
    }
    for i in range(cfg["geometry"]["phase_count"]):
        groups[f"Copper_{i}"] = []
        groups[f"Semi_{i}"] = []
        groups[f"Insulation_{i}"] = []

    shield = bool_cfg(cfg, "general", "shield", True)
    for _, tag in gmsh.model.getEntities(2):
        cx, cy, local_r, outer_r = box_center_radius(tag)

        if in_any_disk(cx, cy, bubbles):
            groups["AirBubble"].append(tag)
            continue

        phase_name = None
        for i, (px, py) in enumerate(phase_xy):
            if math.hypot(cx - px, cy - py) <= radii["insulation"] + 1e-6:
                if local_r <= radii["conductor"] + 1e-6:
                    phase_name = f"Copper_{i}"
                elif local_r <= radii["semi"] + 1e-6:
                    phase_name = f"Semi_{i}"
                else:
                    phase_name = f"Insulation_{i}"
                break
        if phase_name:
            groups[phase_name].append(tag)
            continue

        if shield and in_any_disk(cx, cy, armour1):
            groups["Armour1"].append(tag)
            continue
        if shield and in_any_disk(cx, cy, armour2):
            groups["Armour2"].append(tag)
            continue

        if outer_r <= radii["wrapping"] + 1e-6:
            groups["Filling"].append(tag)
        elif outer_r <= radii["inner_sheath"] + 1e-6:
            groups["InnerSheath"].append(tag)
        elif shield and outer_r <= radii["armour_2"] + 1e-6:
            groups["Filling"].append(tag)
        elif shield and outer_r <= radii["outer_sheath"] + 1e-6:
            groups["OuterSheath"].append(tag)
        elif outer_r <= radii["environment"] + 1e-6:
            groups["Environment"].append(tag)
        else:
            groups["EnvironmentInf"].append(tag)

    return groups


def outer_boundary_curves(r_ext):
    return circular_boundary_curves(r_ext)


def circular_boundary_curves(radius, rel_tol=5e-3):
    curves = []
    for dim, tag in gmsh.model.getEntities(1):
        if dim != 1:
            continue
        xmin, ymin, _, xmax, ymax, _ = gmsh.model.getBoundingBox(dim, tag)
        curve_radius = max(abs(xmin), abs(xmax), abs(ymin), abs(ymax))
        if abs(curve_radius - radius) <= rel_tol * radius:
            curves.append(tag)
    return curves


def set_curve_size(curves, size):
    if not curves:
        return
    points = gmsh.model.getBoundary(
        [(1, int(c)) for c in curves], oriented=False, recursive=True
    )
    points = sorted(set(p for p in points if p[0] == 0))
    if points:
        gmsh.model.mesh.setSize(points, size)


def boundary_curves_for_groups(groups, names):
    curves = set()
    for name in names:
        tags = groups.get(name, [])
        if not tags:
            continue
        boundary = gmsh.model.getBoundary(
            [(2, int(t)) for t in tags], oriented=False, recursive=False
        )
        curves.update(tag for dim, tag in boundary if dim == 1)
    return sorted(curves)


def add_threshold_field(field_id, curves, size_min, size_max, dist_min, dist_max):
    if not curves:
        return None
    gmsh.model.mesh.field.add("Distance", field_id)
    gmsh.model.mesh.field.setNumbers(field_id, "CurvesList", curves)
    gmsh.model.mesh.field.setNumber(field_id, "Sampling", 120)

    threshold_id = field_id + 1
    gmsh.model.mesh.field.add("Threshold", threshold_id)
    gmsh.model.mesh.field.setNumber(threshold_id, "InField", field_id)
    gmsh.model.mesh.field.setNumber(threshold_id, "SizeMin", size_min)
    gmsh.model.mesh.field.setNumber(threshold_id, "SizeMax", size_max)
    gmsh.model.mesh.field.setNumber(threshold_id, "DistMin", dist_min)
    gmsh.model.mesh.field.setNumber(threshold_id, "DistMax", dist_max)
    return threshold_id


def configure_background_mesh(cfg, radii, groups, r_ext):
    mesh = cfg["mesh"]
    shield = bool_cfg(cfg, "general", "shield", True)
    r_cable = radii["outer_sheath"] if shield else radii["inner_sheath"]

    phase_count = cfg["geometry"]["phase_count"]
    core_names = []
    for i in range(phase_count):
        core_names += [f"Copper_{i}", f"Semi_{i}", f"Insulation_{i}"]

    fields = []
    fine_curves = boundary_curves_for_groups(groups, core_names)
    fine_min = min(
        mesh["conductor_size"],
        mesh.get("semiconductor_size", mesh["insulation_size"]),
        mesh["insulation_size"],
    )
    field = add_threshold_field(
        1,
        fine_curves,
        fine_min,
        mesh["environment_size"],
        max(0.25 * radii["conductor"], 2 * fine_min),
        max(1.25 * radii["insulation"], 12 * fine_min),
    )
    if field is not None:
        fields.append(field)

    defect_curves = boundary_curves_for_groups(groups, ["AirBubble"])
    field = add_threshold_field(
        3,
        defect_curves,
        min(fine_min, cfg["defect"]["radius"] / 3) if defect_curves else fine_min,
        mesh["environment_size"],
        cfg["defect"]["radius"] if defect_curves else 0.0,
        6 * cfg["defect"]["radius"] if defect_curves else 0.0,
    )
    if field is not None:
        fields.append(field)

    cable_names = ["Filling", "InnerSheath", "OuterSheath", "Armour1", "Armour2"]
    cable_curves = boundary_curves_for_groups(groups, cable_names)
    field = add_threshold_field(
        5,
        cable_curves,
        min(mesh["sheath_size"], mesh["armour_size"]),
        mesh["environment_size"],
        0.15 * r_cable,
        1.5 * r_cable,
    )
    if field is not None:
        fields.append(field)

    if fields:
        gmsh.model.mesh.field.add("Min", 99)
        gmsh.model.mesh.field.setNumbers(99, "FieldsList", fields)
        gmsh.model.mesh.field.setAsBackgroundMesh(99)

    def mesh_size_callback(dim, tag, x, y, z, lc):
        del dim, tag, z
        radius = math.hypot(x, y)
        if radius <= r_cable:
            base = mesh["sheath_size"]
        else:
            span = max(r_ext - r_cable, r_cable)
            t = min(max((radius - r_cable) / span, 0.0), 1.0)
            base = (1.0 - t) * mesh["environment_size"] + t * mesh["boundary_size"]
        return min(lc, base)

    _MESH_CALLBACKS.append(mesh_size_callback)
    gmsh.model.mesh.setSizeCallback(mesh_size_callback)


def set_sizes_from_groups(cfg, groups, r_ext):
    mesh = cfg["mesh"]
    size_by_group = {
        "Copper": mesh["conductor_size"],
        "Semi": mesh.get("semiconductor_size", mesh["insulation_size"]),
        "Insulation": mesh["insulation_size"],
        "AirBubble": min(mesh["conductor_size"], cfg["defect"]["radius"] / 2),
        "Filling": mesh["sheath_size"],
        "InnerSheath": mesh["sheath_size"],
        "OuterSheath": mesh["sheath_size"],
        "Armour1": mesh["armour_size"],
        "Armour2": mesh["armour_size"],
        "Environment": mesh["environment_size"],
        "EnvironmentInf": mesh["boundary_size"],
    }
    ordered_groups = []
    for name, tags in groups.items():
        if not tags:
            continue
        size = next(
            value for prefix, value in size_by_group.items() if name.startswith(prefix)
        )
        ordered_groups.append((size, name, tags))

    for size, name, tags in sorted(ordered_groups, reverse=True):
        boundary = gmsh.model.getBoundary(
            [(2, int(t)) for t in tags], oriented=False, recursive=False
        )
        curves = [tag for dim, tag in boundary if dim == 1]
        set_curve_size(curves, size)
    set_curve_size(outer_boundary_curves(r_ext), mesh["boundary_size"])


def generate_geometry():
    cfg = load_config()
    radii = radii_from_config(cfg)
    validate_geometry(cfg, radii)
    shield = bool_cfg(cfg, "general", "shield", True)
    armour_cfg = cfg.get("armour", {})
    physical_map = []

    phase_xy = phase_centres(cfg, radii)
    for x, y in phase_xy:
        gmsh.model.occ.addDisk(x, y, 0, radii["conductor"], radii["conductor"])
        gmsh.model.occ.addDisk(x, y, 0, radii["semi"], radii["semi"])
        gmsh.model.occ.addDisk(x, y, 0, radii["insulation"], radii["insulation"])

    gmsh.model.occ.addDisk(0, 0, 0, radii["layup"], radii["layup"])
    gmsh.model.occ.addDisk(0, 0, 0, radii["wrapping"], radii["wrapping"])
    gmsh.model.occ.addDisk(0, 0, 0, radii["inner_sheath"], radii["inner_sheath"])

    armour1 = []
    armour2 = []
    if shield:
        r1 = mm(armour_cfg.get("large_diameter", 3.6)) / 2
        r2 = mm(armour_cfg.get("small_diameter", 2.4)) / 2
        _, armour1 = add_armour_wires(
            int(armour_cfg.get("large_count", 24)),
            r1,
            radii["armour_1"] - r1,
            angle_offset=math.pi / int(armour_cfg.get("large_count", 24)),
        )
        _, armour2 = add_armour_wires(
            int(armour_cfg.get("small_count", 42)),
            r2,
            radii["armour_2"] - r2,
            angle_offset=math.pi / int(armour_cfg.get("small_count", 42)),
        )
        gmsh.model.occ.addDisk(0, 0, 0, radii["outer_sheath"], radii["outer_sheath"])

    bubble_tags, bubbles = add_defect(cfg, radii, phase_xy)
    del bubble_tags

    gmsh.model.occ.addDisk(0, 0, 0, radii["environment"], radii["environment"])
    r_ext = 1.25 * radii["environment"]
    gmsh.model.occ.addDisk(0, 0, 0, r_ext, r_ext)

    gmsh.model.occ.synchronize()
    all_surfaces = gmsh.model.occ.getEntities(2)
    gmsh.model.occ.fragment(all_surfaces, [])
    gmsh.model.occ.synchronize()

    groups = classify_surfaces(cfg, radii, phase_xy, armour1, armour2, bubbles)

    for i in range(cfg["geometry"]["phase_count"]):
        add_physical(2, groups[f"Copper_{i}"], f"Copper_{i}", PHYS["COPPER"] + i, physical_map)
        add_physical(2, groups[f"Semi_{i}"], f"Semi_{i}", PHYS["SEMI"] + i, physical_map)
        add_physical(
            2,
            groups[f"Insulation_{i}"],
            f"Insulation_{i}",
            PHYS["INSULATION"] + i,
            physical_map,
        )

    add_physical(2, groups["Filling"], "Filling", PHYS["FILLING"], physical_map)
    add_physical(2, groups["InnerSheath"], "InnerSheath", PHYS["INNER_SHEATH"], physical_map)
    if shield:
        add_physical(2, groups["Armour1"], "Armour1", PHYS["ARMOUR_1"], physical_map)
        add_physical(2, groups["Armour2"], "Armour2", PHYS["ARMOUR_2"], physical_map)
        add_physical(2, groups["OuterSheath"], "OuterSheath", PHYS["OUTER_SHEATH"], physical_map)
    if groups["AirBubble"]:
        add_physical(2, groups["AirBubble"], "AirBubble", PHYS["AIR_BUBBLE"], physical_map)
    add_physical(2, groups["Environment"], "Environment", PHYS["ENVIRONMENT"], physical_map)
    add_physical(2, groups["EnvironmentInf"], "EnvironmentInf", PHYS["ENVIRONMENT_INF"], physical_map)
    add_physical(1, outer_boundary_curves(r_ext), "Outer_boundary", PHYS["BOUNDARY"], physical_map)
    add_physical(
        1,
        circular_boundary_curves(radii["environment"]),
        "Thermal_boundary",
        PHYS["THERMAL_BOUNDARY"],
        physical_map,
    )

    set_sizes_from_groups(cfg, groups, r_ext)
    configure_background_mesh(cfg, radii, groups, r_ext)
    return physical_map


def main():
    generate_all()
    gmsh.initialize(sys.argv)
    try:
        gmsh.option.setNumber("General.Terminal", 0)
        cfg = load_config()
        mesh = cfg["mesh"]
        gmsh.option.setNumber("Mesh.MeshSizeFromPoints", 0)
        gmsh.option.setNumber("Mesh.MeshSizeExtendFromBoundary", 0)
        gmsh.option.setNumber("Mesh.MeshSizeFromCurvature", 0)
        gmsh.option.setNumber("Mesh.MeshSizeMin", min(mesh.values()) / 2)
        gmsh.option.setNumber("Mesh.MeshSizeMax", mesh["boundary_size"])
        gmsh.option.setNumber("Mesh.Algorithm", 5)
        gmsh.option.setNumber("Mesh.Optimize", 1)
        gmsh.model.add("LoVe-in-HV")

        physical_map = generate_geometry()
        gmsh.model.mesh.generate(2)
        gmsh.model.mesh.optimize("Netgen")
        gmsh.write("LoVe.msh")
        gmsh.write("LoVe.step")
        write_physical_map(physical_map)

        if "-popup" in sys.argv:
            gmsh.fltk.run()
    finally:
        gmsh.finalize()


if __name__ == "__main__":
    main()
