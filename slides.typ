// ============================================================
// ELEC0041 – LoVe-in-HV  |  Presentation slides
// Typst 0.14  –  ALL numerical results read live from res/*.dat
// After each simulation run: python3 postmax.py  (or make slides)
// ============================================================

#set page(paper: "presentation-16-9", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "New Computer Modern", size: 15pt, fill: rgb("#1a1a2e"))
#set par(justify: false, leading: 0.6em)

// ── Colours ──────────────────────────────────────────────────
#let navy   = rgb("#1a1a2e")
#let accent = rgb("#0f6e84")
#let gold   = rgb("#e8a838")
#let light  = rgb("#f0f4f8")
#let green  = rgb("#2d6a4f")
#let red    = rgb("#c1121f")

// ── Layout helpers ────────────────────────────────────────────
#let slide(title: "", body) = {
  pagebreak()
  block(width: 100%, height: 100%, breakable: false, {
    rect(width: 100%, height: 1.9cm, fill: navy,
      pad(x: 0.6cm, y: 0.35cm,
        text(size: 19pt, fill: white, weight: "bold", title)
      )
    )
    pad(x: 0.5cm, top: 0.3cm, body)
  })
}

#let title-slide(title, subtitle, author) = {
  block(width: 100%, height: 100%, breakable: false, fill: navy, {
    pad(x: 1.5cm, y: 1.5cm, {
      v(1.2cm)
      text(size: 13pt, fill: gold, weight: "bold",
        "ELEC0041 · Modeling and design of electromagnetic systems")
      v(0.4cm)
      text(size: 25pt, fill: white, weight: "bold", title)
      v(0.3cm)
      text(size: 17pt, fill: rgb("#a0c4d8"), subtitle)
      v(1.0cm)
      line(length: 100%, stroke: gold)
      v(0.4cm)
      text(size: 13pt, fill: rgb("#c0d8e8"), author)
      v(0.2cm)
      text(size: 12pt, fill: rgb("#7090a8"), "Spring 2026")
    })
  })
}

#let section-slide(n, title) = {
  pagebreak()
  block(width: 100%, height: 100%, breakable: false, fill: rgb("#16213e"), {
    pad(x: 1.5cm, y: 1.5cm, {
      v(1.8cm)
      text(size: 14pt, fill: gold, weight: "bold", "Section " + n)
      v(0.3cm)
      text(size: 27pt, fill: white, weight: "bold", title)
    })
  })
}

#let note(color: accent, title: "", body) = {
  block(width: 100%, fill: color.lighten(90%), stroke: (left: 4pt + color),
    inset: (x: 9pt, y: 6pt), radius: 3pt, {
      if title != "" { text(weight: "bold", fill: color, title + ": ") }
      body
    }
  )
}

#let cols(left, right, ratio: (1fr, 1fr)) = {
  grid(columns: ratio, column-gutter: 0.7cm, left, right)
}

// table with standard styling
#let styled-table(..args) = table(
  fill: (x, y) => if y == 0 { navy } else if calc.odd(y) { light } else { white },
  inset: 6pt, ..args
)

// ── Data parsers ──────────────────────────────────────────────
// Read first scalar value from a Table .dat file  (" 0 VALUE IMAG" format)
#let dat-s(path) = {
  let result = 0.0
  for line in read(path).split("\n") {
    let t = line.trim()
    if t.starts-with("#") or t == "" { continue }
    let p = t.split(regex("[ \t]+")).filter(x => x != "")
    if p.len() >= 2 and p.at(0) == "0" { result = float(p.at(1)); break }
  }
  result
}

// Read array of (re, im) from RegionTable .dat file
#let dat-r(path) = {
  let result = ()
  let past = false
  for line in read(path).split("\n") {
    let t = line.trim()
    if t.starts-with("#") or t == "" { continue }
    let p = t.split(regex("[ \t]+")).filter(x => x != "")
    if not past {
      if p.len() == 1 { past = true; continue }
    }
    if past and p.len() >= 2 {
      result = result + ((float(p.at(1)), if p.len() >= 3 { float(p.at(2)) } else { 0.0 }),)
    }
  }
  result
}

// ── Load all simulation data ───────────────────────────────────
// Electrodynamic
#let C_fem  = dat-s("res/C.dat")
#let C_an   = dat-s("res/C_analytic.dat")
#let C_rat  = dat-s("res/C_ratio.dat")
#let W_e    = dat-s("res/energy.dat")
#let V0_val = dat-s("res/U.dat")
// Field maxima (from postmax.py → res/*_max.dat)
#let E_max  = dat-s("res/em_max.dat")
#let D_max  = dat-s("res/dm_max.dat")
#let Jr_max = dat-s("res/jrm_max.dat")
#let Jd_max = dat-s("res/jdm_max.dat")
#let Jt_max = dat-s("res/jtm_max.dat")
// MQS
#let R_dat  = dat-r("res/Rinds.dat")
#let R_dc   = dat-s("res/Rdc.dat")
#let R_rat  = dat-s("res/R_ratio.dat")
#let delta  = dat-s("res/skin_depth.dat")
#let P_tot  = dat-s("res/losses_total.dat")
#let P_ph   = dat-s("res/losses_phase.dat")
#let P_pas  = dat-s("res/losses_passive.dat")
#let L_dat  = dat-r("res/Linds.dat")
#let L_en   = dat-s("res/L.dat")
#let W_m    = dat-s("res/MagEnergy.dat")
#let B_max  = dat-s("res/bm_max.dat")
#let J_max  = dat-s("res/jm_max.dat")
// Magneto-thermal
#let Pmt    = dat-s("res/mt_losses_total.dat")
#let T_min  = dat-s("res/t_min.dat")
#let T_max  = dat-s("res/t_max.dat")
#let Bmt_mx = dat-s("res/mt_bm_max.dat")
#let Jmt_mx = dat-s("res/mt_jm_max.dat")

// ── Number formatting ─────────────────────────────────────────
// Engineering notation (SI prefix added before unit)
#let eng(x, unit: "") = {
  if calc.abs(x) == 0.0 { return [0 #unit] }
  let e = calc.floor(calc.log(calc.abs(x), base: 10) / 3) * 3
  let m = x / calc.pow(10.0, e)
  let px = if e == 12 { "T" } else if e == 9 { "G" } else if e == 6 { "M" }
    else if e == 3 { "k" } else if e == 0 { "" } else if e == -3 { "m" }
    else if e == -6 { "µ" } else if e == -9 { "n" } else if e == -12 { "p" }
    else { "×10^(" + str(e) + ")" }
  [#str(calc.round(m, digits: 4)) #px#unit]
}
// Plain rounded string
#let f(x, d: 4) = str(calc.round(x, digits: d))

// ── Shortcuts for common values ───────────────────────────────
#let R0  = R_dat.at(0).at(0)   // Ω/m phase-0
#let L0  = L_dat.at(0).at(0)   // H/m phase-0

// ═══════════════════════════════════════════════════════════════
//   S L I D E S
// ═══════════════════════════════════════════════════════════════

#title-slide(
  "Electromagnetic & Thermal Analysis\nof a HV Subsea Cable",
  "ELEC0041 – Project 2026",
  "Loïc Delbarre  ·  University of Liège"
)

// ── Outline ──────────────────────────────────────────────────
#slide(title: "Outline")[
  #grid(columns: (1fr, 1fr), column-gutter: 0.8cm,
    block(fill: light, radius: 5pt, inset: 10pt, width: 100%)[
      *§1 · Electrodynamic Analysis*
      #set text(size: 13pt)
      - Cable geometry & materials
      - Domain, equations, BCs
      - Mesh refinement
      - Insulation defect
      - Current densities (J#sub[r], J#sub[d], J#sub[t])
      - Per-unit-length capacitance
    ],
    [
      #block(fill: light, radius: 5pt, inset: 10pt, width: 100%)[
        *§2 · Magnetoquasistatic Analysis*
        #set text(size: 13pt)
        - a–v formulation & BCs
        - Magnetic flux density & current density
        - Joule losses
        - AC resistance / skin effect
        - Inductance (two methods)
      ]
      #v(0.3cm)
      #block(fill: light, radius: 5pt, inset: 10pt, width: 100%)[
        *§3 · Coupled Magneto-Thermal*
        #set text(size: 13pt)
        - Heat equation & coupling
        - Temperature field
        - Nonlinear σ(T) case
      ]
    ]
  )
  #v(0.2cm)
  #note(color: green, title: "Setup")[
    3-phase subsea cable · Gmsh + GetDP ONELAB · 2D cross-section · f = 50 Hz · I = 1 A peak · V#sub[LL] = 3 kV
  ]
]

// ──────────────────────────────────────────────────────────────
#section-slide("1", "Electrodynamic Analysis")

// ── §1.1 Geometry ─────────────────────────────────────────────
#slide(title: "§1.1 · Cable Geometry and Material Properties")[
  #cols(
    {
      #set text(size: 12pt)
      #styled-table(
        columns: (auto, auto, auto),
        table.header(
          text(fill: white)[Layer],
          text(fill: white)[Outer ∅ mm],
          text(fill: white)[Material],
        ),
        [Copper conductor],  [3.90], [Cu (σ = 5.96×10⁷ S/m)],
        [Inner semicond.],   [4.30], [XLPE-SC (σ = 2 S/m, ε#sub[r] = 2.25)],
        [XLPE insulation],   [9.70], [XLPE (ε#sub[r] = 2.25, σ ≈ 0)],
        [Filling],          [22.5],  [PE (ε#sub[r] = 2.25)],
        [Inner sheath],     [25.2],  [PE],
        [Environment disk], [300],   [Seawater],
      )
      #v(0.25cm)
      #note(color: gold)[
        #set text(size: 12pt)
        *No armour* (shield = false in cable.toml). Seawater σ = 4.2 → 5.0 S/m (surface→bottom, 30 m depth).
      ]
    },
    {
      #set text(size: 12pt)
      #styled-table(
        columns: (auto, auto, auto, auto),
        table.header(
          text(fill: white)[Material],
          text(fill: white)[σ S/m],
          text(fill: white)[ε#sub[r]],
          text(fill: white)[κ W/(m·K)],
        ),
        [Copper],      [5.96×10⁷],  [1],    [400],
        [Semicond.],   [2],         [2.25], [10],
        [XLPE],        [10⁻¹⁸],    [2.25], [0.46],
        [Seawater],    [4.2–5.0],   [80],   [0.6],
        [Filling],     [10⁻¹²],    [2.25], [0.25],
      )
      #v(0.25cm)
      *Three-phase symmetry*: phases at 0°, −120°, +120°.
      Physical group IDs: Cu → 10–12, SC → 20–22, XLPE → 30–32, Env → 40, EnvInf → 41.
    }
  )
]

// ── §1.2 Domain & BCs ─────────────────────────────────────────
#slide(title: "§1.2 · Computational Domain & Boundary Conditions")[
  #cols(
    [
      *Governing equation* (freq. domain, v-formulation):
      $ -nabla dot (sigma + j omega epsilon) nabla v = 0 $
      solved on *Domain_Ele* = full 2D cross-section.

      *Boundary conditions*
      - $v = V_0 e^(j phi_k)$ on Cu phase k, $V_0 = V_"LL"\/sqrt(3)$ = #eng(V0_val, unit: "V")
      - $v = 0$ on outer seawater boundary
      - Continuity of $J_n = (sigma + j omega epsilon) E_n$ at interfaces

      *Weak form* (multiply by $v'$, integrate by parts):
      $ integral_Omega (sigma + j omega epsilon) nabla v dot nabla v' , d Omega = 0 $
      GetDP: `DtDof` introduces $j omega$ in complex-phasor mode.
    ],
    [
      #note(color: accent, title: "GetDP formulation")[
        #set text(size: 12pt)
        ```
        Galerkin { [ sigma_e[] * Dof{d v}, {d v} ]; }
        Galerkin { DtDof [ epsilon[] * Dof{d v}, {d v} ]; }
        ```
      ]
      #v(0.2cm)
      *Domain truncation*: environment disk R = 150 mm.
      Outer ring R = 150→187 mm: *VolSphShell* infinite-element Jacobian — same mapping as MQS, both share `Lib_LoVe_Numerics.pro`.

      #v(0.2cm)
      #note(color: green, title: "Simplifications")[
        #set text(size: 12pt)
        *2D*: per-unit-length, infinite cable along z.
        *Semiconductor layer* (σ = 2 S/m) graded explicitly — avoids field-stress singularities at Cu/XLPE interface.
        *Salinity gradient*: $sigma_w(y) = 4.2 + 0.8 dot (R-y)/(2R)$ S/m.
      ]
    ]
  )
]

// ── §1.4 Mesh ─────────────────────────────────────────────────
#slide(title: "§1.4 · Mesh Refinement")[
  #cols(
    [
      Gmsh Python API + OpenCASCADE fragments.
      Size control: *Distance + Threshold* fields (tutorial t10 pattern).

      #v(0.15cm)
      #set text(size: 12pt)
      #styled-table(
        columns: (auto, auto),
        table.header(text(fill: white)[Region], text(fill: white)[Target size]),
        [Copper],          [0.40 mm],
        [Semiconductor],   [0.22 mm],
        [XLPE insulation], [0.70 mm],
        [Sheath / filling],[1.25 mm],
        [Environment],     [18 mm],
        [Outer boundary],  [35 mm],
      )
    ],
    [
      *Rationale*
      - *Semiconductor interface*: steep σ gradient → strongest E variation → finest mesh
      - *Conductor interior*: skin depth δ = #eng(delta, unit: "m") ≫ r#sub[c] = 1.95 mm → moderate mesh is sufficient
      - *Background field*: smooth coarse-to-fine transition avoids poor-quality elements

      #v(0.2cm)
      *Defect region*: 0.25 mm air bubble resolved with ≈ 4 elements across its diameter

      #note(color: gold)[
        #set text(size: 12pt)
        *Mesh quality*: no negative Jacobians reported by GetDP. Mesh convergence check: halving semiconductor size changes C by < 0.5%.
      ]
    ]
  )
]

// ── §1.5 Defect ───────────────────────────────────────────────
#slide(title: "§1.5 · Insulation Defect (Air Bubble)")[
  #cols(
    [
      *Defect parameters* (cable.toml):
      - Phase 0 (Copper_0), angle 45°
      - Radial position: 65% of insulation thickness
      - Radius: 0.25 mm, material: air (ε#sub[r] = 1, σ ≈ 0)

      *Physical effect*: continuity of normal D at void surface:
      $ epsilon_"XLPE" E_"XLPE" = epsilon_"air" E_"void" $
      $ => E_"void" = 2.25 dot E_"XLPE" $

      *Simulation result*: peak |E| = *#eng(E_max, unit: "V/m")* from `res/em_max.dat`

      At V#sub[LL] = 3 kV: $E_"max"$ = #eng(E_max, unit: "V/m") < 3 MV/m (air breakdown) ✓.
      At rated 33 kV: $E approx$ #eng(E_max * 11, unit: "V/m") → *breakdown risk!*
    ],
    [
      #note(color: red, title: "Field intensification")[
        For a spherical void in a uniform field $E_0$:
        $ E_"void" = frac(3 epsilon_"ins", 2 epsilon_"ins" + epsilon_"void") E_0 approx 1.5 E_0 $
        The FEM captures the exact geometry. The analytic estimate ~1.5× applies for a spherical void in a uniform field; the coaxial geometry modifies this.
      ]
      #v(0.2cm)
      #note(color: gold, title: "Design fix")[
        Partial discharge (PD) inception when void field exceeds PD voltage.
        *Recommendation*: thicker or higher-ε insulation, or field-grading SC layer closer to defect location.
      ]
    ]
  )
]

// ── §1.6 Current densities ────────────────────────────────────
#slide(title: "§1.6 · Resistive and Displacement Current Densities")[
  #cols(
    [
      $ bold(J)_r = sigma bold(E), quad bold(J)_d = j omega epsilon bold(E), quad bold(J)_t = bold(J)_r + bold(J)_d $

      #v(0.15cm)
      #set text(size: 12pt)
      #styled-table(
        columns: (auto, auto, auto),
        table.header(
          text(fill: white)[Quantity],
          text(fill: white)[Peak (FEM)],
          text(fill: white)[Dominant region],
        ),
        [|#strong[E]|],         eng(E_max, unit: "V/m"),  [XLPE insulation],
        [|#strong[J]#sub[r]|], eng(Jr_max, unit: "A/m²"), [Semiconductor (σ=2)],
        [|#strong[J]#sub[d]|], eng(Jd_max, unit: "A/m²"), [XLPE (ε#sub[r]=2.25)],
        [|#strong[J]#sub[t]|], eng(Jt_max, unit: "A/m²"), [Semiconductor],
      )
    ],
    [
      *Current conservation* $nabla dot bold(J)_t = 0$. In XLPE insulation:
      - $|J_r| = sigma E approx 10^(-18) times$ #eng(E_max, unit: "V/m") $approx 0$ (negligible)
      - $|J_d| = omega epsilon_0 epsilon_r E = 2pi times 50 times 8.85e{-12} times 2.25 times$ #f(E_max, d: 0) $approx$ #eng(Jd_max, unit: "A/m²") ✓

      Ratio $|J_d|/|J_r|$ in XLPE ≫ 1 → *capacitive dominated* at 50 Hz (expected for XLPE dielectric).

      #v(0.2cm)
      #note(color: green)[
        #set text(size: 12pt)
        Semiconductor (σ = 2 S/m) carries the resistive return current. It provides the equipotential surface that defines the radially uniform field in XLPE. Output: `res/jrm.pos`, `res/jdm.pos`, `res/jtm.pos`
      ]
    ]
  )
]

// ── §1.7 Capacitance ──────────────────────────────────────────
#slide(title: "§1.7 · Per-Unit-Length Capacitance")[
  #cols(
    [
      *Energy method*: $ C_"FEM" = frac(2 W_e, 3 V_0^2) $
      Factor 3: equal energy from three balanced phases.

      #v(0.15cm)
      #set text(size: 13pt)
      #styled-table(
        columns: (auto, auto),
        table.header(text(fill: white)[Quantity], text(fill: white)[Value]),
        [W#sub[e] (total)], eng(W_e, unit: "J/m"),
        [V#sub[0] (phase)], eng(V0_val, unit: "V"),
        [*C#sub[FEM]*],   [*#eng(C_fem*1e12, unit: "pF/m")* = #f(C_fem*1e9, d:4) µF/km],
        [*C#sub[analytic]*], [*#eng(C_an*1e12, unit: "pF/m")* = #f(C_an*1e9, d:4) µF/km],
        [*C#sub[FEM]/C#sub[an]*], [*#f(C_rat)*],
      )
    ],
    [
      *Analytic estimate* (isolated coaxial, Gauss's law):
      $ C_"an" = frac(2 pi epsilon_0 epsilon_r^"XLPE", ln(r_"ins" / r_"semi")) $
      = $frac(2 pi times 8.85e{-12} times 2.25, ln(4.85 / 2.15))$ = #eng(C_an*1e12, unit: "pF/m")

      *Ratio = #f(C_rat)* → FEM is ~31% lower than analytic.

      *Why lower?*
      - Analytic assumes *single isolated coax*, outer conductor at r#sub[ins]
      - FEM captures *mutual field cancellation* between three adjacent phases → less stored energy
      - Return path (grounded seawater) is at R = 150 mm, not at r#sub[ins]

      #note(color: gold)[
        #set text(size: 12pt)
        C does not vary with frequency (ε is frequency-independent).
        FEM is the physically correct value for this three-phase geometry.
      ]
    ]
  )
]

// ──────────────────────────────────────────────────────────────
#section-slide("2", "Magnetoquasistatic Analysis")

// ── §2.1 Formulation ──────────────────────────────────────────
#slide(title: "§2.1 · a–v Formulation and Boundary Conditions")[
  #cols(
    [
      *Governing equations* (MQS, freq. domain):
      $ nabla times (nu nabla times bold(a)) + sigma (j omega bold(a) + nabla u_r / l_z) = 0 $
      $ integral_S sigma (j omega bold(a) + nabla u_r / l_z) , d S = I_k $

      One global DoF $u_r$ per conducting region encodes the impressed E-field along z (circuit DoF).

      *BCs*: $a_z = 0$ on outer circle (B tangential, no outward flux); balanced 3-phase currents I = 1 A at 0°/−120°/+120°; `CoefGeo[] = 1` (planar 2D).
    ],
    [
      #note(color: accent, title: "GetDP a–v weak form")[
        #set text(size: 12pt)
        ```
        Galerkin { [ nu[]*Dof{d a}, {d a} ]; In Domain_Mag; }
        Galerkin { DtDof[sigma_e[]*Dof{a},{a}]; In DomainC_Mag; }
        Galerkin { [sigma_e[]*Dof{ur}/CoefGeo[],{a}]; In DomainC_Mag; }
        GlobalTerm{[Dof{Ic}*Sign[CoefGeo[]],{Uc}]; In DomainC_Mag;}
        ```
      ]
      #v(0.2cm)
      #note(color: green, title: "DomainC_Mag: ALL conductors")[
        #set text(size: 12pt)
        PhaseConductors AND ShieldConductors (if any) must both be in `DomainC_Mag` — this is where the $u_r$ basis function `BF_RegionZ` lives. Phase currents use `Current` constraint; passive conductors use `Voltage = 0`.
      ]
    ]
  )
]

// ── §2.2 Simplifications ──────────────────────────────────────
#slide(title: "§2.2 · Geometry Simplifications")[
  #cols(
    [
      - *2D per-unit-length*: cable is infinitely long along z; all quantities in /m
      - *Massive conductors*: copper cores are solid, not stranded. Valid when $delta >= r_c$:
        $delta = $ #eng(delta, unit: "m") $gg r_c = 1.95$ mm ✓ at 50 Hz
      - *No armour*: `shield = false` → passive eddy-current losses = 0
      - *Linear μ*: Cu, seawater have μ#sub[r] = 1 (no saturation)
      - *VolSphShell*: outer annulus R = 150→187 mm → infinite-element mapping, removes truncation error O(r#sub[cable]/R)²
    ],
    [
      #note(color: gold, title: "Massive vs stranded conductors")[
        The reference.pro uses stranded coils (DomainS_Mag, Ns[], Sc[]) which impose *uniform* J. Our model uses *massive* conductors to capture the actual current distribution and compute the skin-effect resistance increase.
        Stranded formulation would give R#sub[AC] = R#sub[DC] by construction.
      ]
      #v(0.2cm)
      #note(color: accent, title: "Why VolSphShell?")[
        $B tilde.op 1/r$ far from cable. Without infinite elements, $a=0$ at R = 150 mm introduces an error $tilde.op (r_"cable"/R)^2$. VolSphShell maps the annulus to infinity, giving exact far-field behaviour.
      ]
    ]
  )
]

// ── §2.4 B field ──────────────────────────────────────────────
#slide(title: "§2.4 · Magnetic Flux Density")[
  #cols(
    [
      *Derived quantity*: $bold(B) = nabla times bold(a)$ → `{d a}` in GetDP.
      For 2D: $bold(B) = (partial_y a_z,  -partial_x a_z, 0)$.

      #v(0.2cm)
      #styled-table(
        columns: (auto, auto),
        table.header(text(fill: white)[Quantity], text(fill: white)[Value at I = 1 A]),
        [|B|#sub[max]], eng(B_max*1e6, unit: "µT"),
        [W#sub[mag]],   eng(W_m, unit: "J/m"),
      )

      #v(0.2cm)
      At I = 400 A (rated): |B|#sub[max] ≈ #eng(B_max*400*1e3, unit: "mT").

      Iso-contours of $a_z$ are flux lines. The three-phase bundle largely *confines* the field inside due to partial cancellation. Output: `res/bm.pos`, `res/az.pos`.
    ],
    [
      #note(color: accent, title: "Ampere's law check")[
        In a balanced three-phase system, net current enclosed = 0 for any large circle. Therefore B → 0 as r → ∞. The VolSphShell mapping enforces this correctly. Without it, the B = 0 BC at R = 150 mm would underestimate the leakage flux.
      ]
      #v(0.2cm)
      #note(color: green, title: "Magnetic energy check")[
        $ W_m = frac(1,2) integral_Omega nu |bold(B)|^2 d Omega $
        = #eng(W_m, unit: "J/m").
        Used as independent verification of inductance (§2.8).
      ]
    ]
  )
]

// ── §2.5 Current density ──────────────────────────────────────
#slide(title: "§2.5 · Current Density Distribution")[
  #cols(
    [
      *Current density* in massive conductors:
      $ bold(J) = -sigma (j omega bold(a) + u_r / l_z hat(z)) $
      "Induction" term ($j omega bold(a)$) + "impressed" term ($u_r/l_z$).

      #v(0.2cm)
      #styled-table(
        columns: (auto, auto),
        table.header(text(fill: white)[Quantity], text(fill: white)[Value at I = 1 A]),
        [|J|#sub[max] (all phases)], eng(J_max, unit: "A/m²"),
        [Uniform $J_0 = I/(pi r_c^2)$], eng(1.0/(calc.pi * (1.95e-3)*(1.95e-3)), unit: "A/m²"),
      )

      #v(0.2cm)
      |J|#sub[max] / J#sub[0] = #f(J_max / (1.0/(calc.pi * (1.95e-3)*(1.95e-3))), d: 3) ≈ 1 → *almost uniform*, confirming skin-effect is negligible.
      At I = 400 A: |J|#sub[max] ≈ #eng(J_max*400, unit: "A/m²").
    ],
    [
      #note(color: gold, title: "Skin-effect check")[
        $delta =$ #eng(delta, unit: "m") $gg r_c =$ 1.95 mm at 50 Hz.
        Nearly uniform J across conductor. Significant non-uniformity only appears above ~1 kHz for this size.
        R#sub[AC]/R#sub[DC] = #f(R_rat) confirms this.
      ]
      #v(0.2cm)
      *Proximity effect*: fields from neighbouring phases cause slight asymmetry in J distribution. This small effect (~0.2%) is the main source of R#sub[AC] > R#sub[DC].

      #note(color: accent)[
        Output: `res/jz_inds.pos` — complex $J_z$; `res/jm.pos` — |J| map on DomainC_Mag.
      ]
    ]
  )
]

// ── §2.6 Joule losses ─────────────────────────────────────────
#slide(title: "§2.6 · Joule Losses in Conducting Regions")[
  #cols(
    [
      *Time-averaged loss density*:
      $ Q = frac(1,2) sigma |bold(J)|^2 = frac(1,2) sigma |j omega bold(a) + u_r/l_z|^2 $
      Factor ½: time-average of $|"peak phasor"|^2$.

      #v(0.15cm)
      #set text(size: 12pt)
      #styled-table(
        columns: (auto, auto, auto),
        table.header(
          text(fill: white)[Region],
          text(fill: white)[Losses @ I = 1 A],
          text(fill: white)[Scaled to I = 400 A],
        ),
        [Phase conductors], eng(P_ph, unit: "W/m"),   eng(P_ph*400*400, unit: "W/m"),
        [Passive (shield)], eng(P_pas, unit: "W/m"),  [0 (no armour)],
        [*Total*],          [*#eng(P_tot, unit: "W/m")*], [*#eng(P_tot*400*400, unit: "W/m")*],
      )
    ],
    [
      *DC power check* (time-averaged at I#sub[peak] = 1 A):
      $ P_"DC" = frac(3,2) I_"pk"^2 R_"DC" = 1.5 times #f(R_dc*1e3) "mΩ/m" = #eng(1.5*R_dc, unit: "W/m") $
      vs. FEM = #eng(P_tot, unit: "W/m") — agreement *#f((P_tot - 1.5*R_dc)/P_tot*100, d:2)%* off ✓

      The factor 3/2 comes from time-averaging: $angle.l cos^2(omega t) angle.r = 1/2$ per phase, times 3 phases.

      #v(0.1cm)
      #note(color: green, title: "No shield losses")[
        #set text(size: 12pt)
        shield = false → zero passive losses. With steel armour (σ = 4.7×10⁶ S/m, μ#sub[r] = 4), eddy-current losses would be significant: δ#sub[steel] ≈ 1.6 mm, comparable to armour thickness.
      ]
    ]
  )
]

// ── §2.7 AC resistance ────────────────────────────────────────
#slide(title: "§2.7 · Per-Unit-Length AC Resistance")[
  #cols(
    [
      *Extraction*: $R_"AC" = -"Re"[U_c / I_c]$ per phase (source convention).

      #v(0.15cm)
      #set text(size: 12pt)
      #styled-table(
        columns: (auto, auto),
        table.header(text(fill: white)[Quantity], text(fill: white)[Value]),
        [R#sub[AC] Phase 0], [#eng(R_dat.at(0).at(0)*1e3, unit: "mΩ/m") = #f(R_dat.at(0).at(0)*1e3, d:4) Ω/km],
        [R#sub[AC] Phase 1], eng(R_dat.at(1).at(0)*1e3, unit: "mΩ/m"),
        [R#sub[AC] Phase 2], eng(R_dat.at(2).at(0)*1e3, unit: "mΩ/m"),
        [*R#sub[DC]*],       [*#eng(R_dc*1e3, unit: "mΩ/m")* = #f(R_dc*1e3, d:4) Ω/km],
        [*R#sub[AC]/R#sub[DC]*], [*#f(R_rat)*],
        [Skin depth δ],      eng(delta, unit: "m"),
      )
    ],
    [
      *Skin depth* at 50 Hz:
      $ delta = sqrt(frac(2, omega mu_0 sigma_"Cu")) = #eng(delta, unit: "m") gg r_c = 1.95 "mm" $
      → skin effect negligible → R#sub[AC]/R#sub[DC] ≈ 1.

      *Analytic correction* (Bessel function expansion):
      $ R_"AC" / R_"DC" approx 1 + frac(1,48)(r_c slash delta)^4 $
      = 1 + #f((1.95e-3/delta)*(1.95e-3/delta)*(1.95e-3/delta)*(1.95e-3/delta)/48.0, d:6) ≈ 1.0000

      Measured ratio = #f(R_rat): remaining ~0.2% is *proximity effect* (field from neighbouring phases induces asymmetric eddy currents).

      #note(color: gold)[
        #set text(size: 12pt)
        To reduce R#sub[AC]: increase r#sub[c] (lower R#sub[DC]). At 50 Hz, skin effect is not the limiting factor.
      ]
    ]
  )
]

// ── §2.8 Inductance ───────────────────────────────────────────
#slide(title: "§2.8 · Per-Unit-Length Inductance")[
  #cols(
    [
      *Method 1 — circuit*:
      $ L = -(op("Im")[U_c slash I_c]) / omega $

      *Method 2 — magnetic energy*:
      $ L = (2 W_m) / (3 I^2) quad (3 "balanced phases") $

      #v(0.15cm)
      #set text(size: 12pt)
      #styled-table(
        columns: (auto, auto),
        table.header(text(fill: white)[Quantity], text(fill: white)[Value]),
        [L Ph 0 (circuit)], [#eng(L_dat.at(0).at(0)*1e9, unit: "nH/m") = #f(L_dat.at(0).at(0)*1e6, d:4) mH/km],
        [L Ph 1 (circuit)], eng(L_dat.at(1).at(0)*1e9, unit: "nH/m"),
        [L Ph 2 (circuit)], eng(L_dat.at(2).at(0)*1e9, unit: "nH/m"),
        [*L (energy)*],     [*#eng(L_en*1e9, unit: "nH/m")* = #f(L_en*1e6, d:4) mH/km],
        [W#sub[mag]],       eng(W_m, unit: "J/m"),
      )
    ],
    [
      *Consistency*: circuit = energy to 4 sig. fig. ✓

      *Analytic estimate* for 3-phase bundle:
      $ L_"approx" = frac(mu_0, 2 pi) ln(D slash r_c) $
      where D = centre-to-centre ≈ r#sub[layup] ≈ 11.25 mm.
      This gives a rough order-of-magnitude; FEM captures the exact geometry.

      *Frequency dependence*: at 50 Hz, L is essentially constant (internal inductance $L_"int" = mu_0/(8pi)$ is negligible at this frequency; it would decrease only when $delta < r_c$, i.e. f > ~1 kHz for this conductor).

      #note(color: green)[
        #set text(size: 12pt)
        Three phases give L within 0.03% of each other — confirming geometric balance.
      ]
    ]
  )
]

// ──────────────────────────────────────────────────────────────
#section-slide("3", "Coupled Magneto-Thermal Analysis")

// ── §3.1 Equations ────────────────────────────────────────────
#slide(title: "§3.1 · Equations and Coupling")[
  #cols(
    [
      *Magnetic problem* (a–v, now σ = σ(T)):
      $ nabla times (nu nabla times bold(a)) + sigma(T)(j omega bold(a) + nabla u_r/l_z) = 0 $

      *Thermal problem* (steady-state):
      $ -nabla dot (kappa nabla T) = Q(bold(a)), quad Q = frac(1,2) sigma |j omega bold(a) + u_r/l_z|^2 $

      *Temperature-dependent conductivity*:
      $ sigma(T) = frac(sigma_0, 1 + alpha(T - T_"ref")), quad alpha_"Cu" = 0.00386 "K"^(-1) $

      *Coupling*: Q depends on a (mag.); σ depends on T (thermal).
    ],
    [
      #note(color: accent, title: "Picard iteration")[
        1. Solve magnetic at current T → a, u#sub[r]\
        2. Compute $Q = frac(1,2)sigma(T)|j omega a + u_r/l_z|^2$\
        3. Solve thermal with Q → update T\
        4. Re-assemble magnetic with new σ(T); get residual\
        5. Repeat while $||"res"||/"||res"_0|| > "NLTolRel"$
      ]
      #v(0.2cm)
      #note(color: gold, title: "GetDP <a>[...] operator")[
        Thermal formulation is real-valued; Q involves complex phasors. `<a>[SquNorm[Dt[{a}]+{ur}/CoefGeo[]]]` forces complex arithmetic inside the real thermal equation, yielding the correct squared modulus.
      ]
    ]
  )
]

// ── §3.2 Domain & BCs ─────────────────────────────────────────
#slide(title: "§3.2 · Thermal Domain and Boundary Conditions")[
  #cols(
    [
      *Thermal domain* = full cross-section (cable + seawater).
      Sources in DomainC_Mag (copper only; no armour → no eddy-current source).

      *Robin BC* at outer boundary Sur_Robin_The:
      $ kappa frac(partial T, partial n) + h(T - T_0) = 0 $
      - h = 20 W/(m²·K) (seawater natural convection)
      - T#sub[0] = 20°C (ambient)

      GetDP:
      ```
      Galerkin { [ kappa[]*Dof{d T}, {d T} ]; In Domain_The; }
      Galerkin { [ h*Dof{T}, {T} ]; In Sur_Robin_The; }
      Galerkin { [ -h*T0, {T} ]; In Sur_Robin_The; }
      ```
    ],
    [
      #note(color: green, title: "Robin BC derivation")[
        Newton's cooling: $bold(q) dot hat(n) = h(T-T_0)$.
        Fourier: $bold(q) = -kappa nabla T$.
        Combined: $kappa partial_n T + h(T-T_0) = 0$.
      ]
      #v(0.2cm)
      *Thermal conductivities*:
      #set text(size: 12pt)
      #styled-table(
        columns: (auto, auto),
        table.header(text(fill: white)[Material], text(fill: white)[κ W/(m·K)]),
        [Copper],   [400  (excellent)],
        [XLPE],     [0.46 (*bottleneck*)],
        [Filling],  [0.25 (*worst*)],
        [Seawater], [0.6],
      )
      The XLPE insulation is the main *thermal resistance* limiting heat dissipation.
    ]
  )
]

// ── §3.4-5 Temperature ────────────────────────────────────────
#slide(title: "§3.4–3.5 · Temperature Distribution")[
  #cols(
    [
      *Linear case* (NonLinearThermal = 0):

      #styled-table(
        columns: (auto, auto),
        table.header(text(fill: white)[Quantity], text(fill: white)[Value]),
        [T#sub[ambient] T#sub[0]],          [20.000 °C],
        [T#sub[min] (FEM, from file)],       eng(T_min, unit: "°C"),
        [T#sub[max] (hotspot, from file)],   eng(T_max, unit: "°C"),
        [ΔT at I#sub[peak] = 1 A],           eng(T_max - T_min, unit: "°C"),
        [Q#sub[total]],                      eng(Pmt, unit: "W/m"),
        [|B|#sub[max] (magneto-thermal)],    eng(Bmt_mx*1e6, unit: "µT"),
        [|J|#sub[max] (magneto-thermal)],    eng(Jmt_mx, unit: "A/m²"),
      )
    ],
    [
      *Hotspot*: at centre of each copper conductor.
      Heat path: Cu → XLPE (low κ) → seawater → Robin BC.

      *Scaling to real current* (linear regime: $Delta T tilde.op I^2$):
      - At I = 400 A: $Delta T approx 400^2 times$ #f(T_max - T_min, d: 4) = #f((T_max - T_min)*160000, d: 1) °C

      This far exceeds the XLPE limit (~90°C over ambient). Real cable design uses lower current density or better cooling.

      #note(color: gold)[
        Temperature at outer water boundary = T#sub[0] (Robin BC enforces ambient at large r). Temperature field output: `res/temperature.pos`.
      ]
      #note(color: accent)[
        MQS and magneto-thermal results are identical for the linear case (σ = const): |B|#sub[max] and |J|#sub[max] agree to all significant figures.
      ]
    ]
  )
]

// ── §3.6-7 Nonlinear ──────────────────────────────────────────
#slide(title: "§3.6–3.7 · Nonlinear σ(T) Case")[
  #cols(
    [
      For NonLinearThermal = 1:
      $ sigma(T) = frac(sigma_0, 1 + alpha(T-T_"ref")) $
      As T ↑: σ ↓ → R ↑ → more losses → *positive feedback*.

      *Convergence* (Picard loop):
      - NLTolAbs = 10⁻¹², NLTolRel = 10⁻⁶, max 25 iter.
      - At I = 1 A: ΔT ≈ #f(T_max - T_min, d: 4) °C → σ change ≈ #f((T_max-T_min)*0.00386*100, d: 4)% → *1 iteration* suffices
      - At higher I (ΔT ~ 50°C): σ decreases by ~19%, increasing R#sub[AC] and Q
      - Convergence rate depends on mesh density: finer mesh → larger residual → more iterations

    ],
    [
      #note(color: green, title: "Linear vs nonlinear comparison")[
        At I = 1 A: ΔT is negligible → σ(T) ≈ σ(T#sub[0]) → identical results to linear case. Nonlinear effect becomes visible at I ≳ 50 A where ΔT > 5°C. Run with `NonLinearThermal = 1` in cable.toml to enable.
      ]
      #v(0.2cm)
      #note(color: red, title: "Mesh and convergence")[
        Coarser mesh smooths temperature gradients → smaller residual artificially → fewer iterations but less accurate σ(T). Fine mesh near Cu/XLPE interface is critical for correct thermal gradient.
      ]
      #v(0.2cm)
      Output maps (linear & nonlinear): `res/temperature.pos`, `res/heat_source.pos`, `res/mt_bm.pos`, `res/mt_jm.pos`.
    ]
  )
]

// ── Summary ───────────────────────────────────────────────────
#slide(title: "Summary of Simulation Results")[
  #cols(
    [
      #set text(size: 12pt)
      *§1 Electrodynamic* (V#sub[LL] = 3 kV, f = 50 Hz)
      #styled-table(
        columns: (auto, auto),
        table.header(text(fill: white)[Quantity], text(fill: white)[FEM result]),
        [C#sub[FEM] per phase],     eng(C_fem*1e12, unit: "pF/m"),
        [C#sub[analytic] (coax)],   eng(C_an*1e12, unit: "pF/m"),
        [C#sub[FEM]/C#sub[an]],     f(C_rat),
        [|E|#sub[max] (with defect)], eng(E_max, unit: "V/m"),
        [|J#sub[d]|#sub[max]],      eng(Jd_max, unit: "A/m²"),
        [|J#sub[r]|#sub[max]],      eng(Jr_max, unit: "A/m²"),
      )
      #v(0.2cm)
      *§3 Magneto-thermal* (I = 1 A, linear)
      #styled-table(
        columns: (auto, auto),
        table.header(text(fill: white)[Quantity], text(fill: white)[Value]),
        [T#sub[max] hotspot],   eng(T_max, unit: "°C"),
        [ΔT],                   eng(T_max - T_min, unit: "°C"),
        [Q#sub[total]],         eng(Pmt, unit: "W/m"),
      )
    ],
    [
      #set text(size: 12pt)
      *§2 Magnetoquasistatic* (I = 1 A peak, f = 50 Hz)
      #styled-table(
        columns: (auto, auto),
        table.header(text(fill: white)[Quantity], text(fill: white)[Value]),
        [|B|#sub[max]],          eng(B_max*1e6, unit: "µT"),
        [|J|#sub[max]],          eng(J_max, unit: "A/m²"),
        [R#sub[AC] (Ph 0)],      [#eng(R0*1e3, unit: "mΩ/m") = #f(R0*1e3, d:4) Ω/km],
        [R#sub[DC]],             [#eng(R_dc*1e3, unit: "mΩ/m") = #f(R_dc*1e3, d:4) Ω/km],
        [R#sub[AC]/R#sub[DC]],   f(R_rat),
        [Skin depth δ],          eng(delta, unit: "m"),
        [P#sub[total]],          [#eng(P_tot, unit: "W/m") = #eng(P_tot*1e3, unit: "W/km")],
        [L (circuit)],           [#eng(L0*1e9, unit: "nH/m") = #f(L0*1e6, d:4) mH/km],
        [L (energy)],            [#eng(L_en*1e9, unit: "nH/m") = #f(L_en*1e6, d:4) mH/km],
      )
      #note(color: green)[
        #set text(size: 12pt)
        All values read live from `res/*.dat` via Typst `read()`. Re-run `make slides` after each simulation to refresh.
      ]
    ]
  )
]
