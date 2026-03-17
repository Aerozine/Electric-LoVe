import numpy as np

try:
    # Python 3.11+ – built-in module
    import tomllib as toml_parser
except ImportError:
    # Python < 3.11 – external library
    import tomli as toml_parser

with open("cable.toml", "rb") as f:
    data = toml_parser.load(f)
    copper_diam = data["copper_diam"] * 1e-3
    copper_insulator_semi = data["copper_insulator_semi"] * 1e-3
    copper_insulator_polyet = data["copper_insulator_polyet"] * 1e-3
    infinity_diameter = data["infinity_diameter"] * 1e-3


def generate_group(csv_file="map.csv", output_file="generated_common.pro"):
    data = np.genfromtxt(csv_file, delimiter=",", dtype=str, skip_header=1)
    copper = []
    semi = []
    poly = []
    water_id = None

    for row in data:
        name, dim, phys_id, tags = row
        phys_id = int(phys_id)
        if "Copper" in name:
            copper.append((name, phys_id))
        elif "Semi" in name:
            semi.append((name, phys_id))
        elif "PolyEt" in name:
            poly.append((name, phys_id))
        elif name == "Water":
            water_id = phys_id

    # Start writing Group block
    lines = ["Group {", ""]

    # Copper
    for name, phys_id in copper:
        lines.append(f"  {name} = Region[{phys_id}];")
    lines.append("")

    # Semiconductor
    for name, phys_id in semi:
        lines.append(f"  {name} = Region[{phys_id}];")
    lines.append("")

    # Polyethylene
    for name, phys_id in poly:
        lines.append(f"  {name} = Region[{phys_id}];")
    lines.append("")

    # Higher-level groups
    lines.append(f"  DomainS_Mag = Region[{{{', '.join(n for n,_ in copper)}}}];")
    lines.append(f"  Semiconductor = Region[\n {{ {', '.join(n for n,_ in semi)} }}];")
    lines.append(f"  Insulation = Region[\n {{ {', '.join(n for n,_ in poly)} }}];")

    # Water must be defined BEFORE any compound region that references it
    if water_id is not None:
        lines.append(f"  Water = Region[{water_id}];")

    all_names = [n for n, _ in copper + semi + poly]
    # Water must be in Domain_Ele , otherwise we have 0 Dof
    ele_names = all_names + (["Water"] if water_id is not None else [])
    lines.append(f"  Domain_Ele = Region[\n {{ {', '.join(ele_names)} }}];")

    lines.append(f"  DomainC_Mag = Region[\n {{ {', '.join(n for n,_ in copper)} }}];")
    lines.append(
        f"  DomainNC_Mag = Region[\n {{ {', '.join(n for n,_ in semi+poly)}{', Water' if water_id is not None else ''} }}];"
    )
    # Domain_Mag = full computational domain (conducting + non-conducting + water)
    lines.append(f"  Domain_Mag = Region[\n {{ DomainC_Mag, DomainNC_Mag }}];")
    lines.append(f"  Sur_Dirichlet_Ele = Region[{{50}}];")
    lines.append(f"  Sur_Dirichlet_Mag = Region[{{50}}];")

    lines.append(f"DomainDummy = Region[1234]; //postpro")
    lines.append("}")

    # Write to file
    with open(output_file, "w") as f:
        f.write("\n".join(lines))


def generate_function(toml_file="cable.toml", output_file="generated_common.pro"):
    # Load configuration
    with open(toml_file, "rb") as f:
        cfg = toml_parser.load(f)

    # Constants
    eps0 = cfg.get("eps0", 8.854187818e-12)

    # Materials
    sigma = cfg.get("sigma", {})
    sigma_copper = sigma.get("Copper", 5.99e7)
    sigma_semiconductor = sigma.get("Semiconductor", 2)
    sigma_water = sigma.get("Ground", 28)
    epsilon_sem = cfg.get("epsilon", {}).get("Semiconductor", 2.25)
    epsilon_others = cfg.get("epsilon", {}).get("Others", 1.0)

    # AC parameters
    Freq = cfg.get("Freq", 50)
    Phase = cfg.get("Phase", {})

    Pa = Phase.get("A", 0.0)
    Pb = Phase.get("B", -120.0 / 180.0 * np.pi)
    Pc = Phase.get("C", -240.0 / 180.0 * np.pi)

    I = cfg.get("I", 406)
    Vrms = cfg.get("Vrms", 132e3)

    lines = ["", "Function {"]

    lines.append("  mu0 = 4.e-7 * Pi;")
    lines.append(f"  eps0 = {eps0};")
    lines.append("")

    lines.append(f"  sigma[Semiconductor] = {sigma_semiconductor};")
    lines.append(f"  sigma[Water] = {sigma_water};")
    lines.append(f"  sigma[DomainS_Mag] = {sigma_copper};")
    # Insulation (polyethylene) gets a near-zero sigma so GetDP
    # does not encounter undefined material DOFs in Domain_Ele
    lines.append(f"  sigma[Insulation] = 1e-10;  // near-zero: polyethylene insulator")
    lines.append("")

    lines.append(f"  epsilon[Water] = eps0*{epsilon_others};")
    lines.append(f"  epsilon[DomainS_Mag] = eps0*{epsilon_others};")
    lines.append(f"  epsilon[Semiconductor] = eps0*{epsilon_sem};")
    lines.append(f"  epsilon[Insulation] = eps0*{epsilon_others};")
    lines.append("")

    lines.append("  nu[Water] = 1./mu0;")
    lines.append("  nu[Semiconductor] = 1./mu0;")
    lines.append("  nu[DomainS_Mag] = 1./mu0;")
    lines.append("  nu[Insulation] = 1./mu0;")
    lines.append("")

    lines.append(f"  Freq = {Freq};")
    lines.append("  Omega = 2*Pi*Freq;")
    lines.append("")

    lines.append(f"  Pa = {Pa}; Pb = {Pb}; Pc = {Pc};")
    lines.append(f"  I = {I};")
    lines.append(f"  Vrms = {Vrms};")
    lines.append("  V0 = Vrms/Sqrt[3];")
    lines.append("")

    lines.append("  Ns[]= 1;")
    lines.append("  Sc[]= SurfaceArea[];")
    lines.append("}")
    with open(output_file, "a") as f:
        f.write("\n".join(lines) + "\n")

    print(f"Function block appended to {output_file}")


def generate_like_a_pro(
    csv_file="map.csv", toml_file="cable.toml", output_file="generated_common.pro"
):
    generate_group(csv_file=csv_file, output_file=output_file)
    generate_function(toml_file=toml_file, output_file=output_file)


if __name__ == "__main__":
    generate_like_a_pro()
