#import "preamble.typ": *
// ##############################################################
#section-slide("1", "Electrodynamic Analysis")

// ## §1.1 Geometry #############################################
#slide(title: [§1.1 #sym.dot.c Cable Geometry and Material Properties])[
  #cols(
    [
      // TODO: insert real cable cross-section photograph/datasheet here
      #set text(size: 12pt)
      #styled-table(
        columns: (auto, auto, auto),
        table.header(
          text(fill: white)[Layer],
          text(fill: white)[Outer OD mm],
          text(fill: white)[Material],
        ),
        [Copper conductor],  [#f(t_cond_d, d:1)], [Cu ($sigma$ = 5.96$times$$""^7$ S/m)],
        [Inner semicond.],   [#f(t_semi_od, d:1)], [XLPE-SC ($sigma$=2 S/m)],
        [XLPE insulation],   [#f(t_ins_od, d:1)], [XLPE ($epsilon$#sub[r]=2.25)],
        [PE filling],        [#f(t_layup_od, d:1)], [PE ($epsilon$#sub[r]=2.25)],
        [Inner sheath],      [#f(t_sheath_od, d:1)], [PE],
        [Steel armour],      [38 mm OD], [Steel ($sigma$=4.7$times$$""^6$ S/m, $mu$#sub[r]=4)],
        [Outer sheath],      [42.5 mm OD], [PE],
        [Environment disk],  [#f(t_env_d, d:0)], [Seawater],
      )
      #note(color: gold)[
        #set text(size: 12pt)
        *Simplification*: The optical fibre unit (present in the real cable) is replaced by a 3rd power core in the 3-phase model. The steel armour is drawn in the geometry but *excluded from the solved EM domain* (see §1.3).
      ]
    ],
    [
      #set text(size: 12pt)
      #styled-table(
        columns: (auto, auto, auto, auto),
        table.header(
          text(fill: white)[Material],
          text(fill: white)[$sigma$ S/m],
          text(fill: white)[$epsilon$#sub[r]],
          text(fill: white)[$kappa$ W/(m#sym.dot.c K)],
        ),
        [Copper],    [5.96$times$$""^7$], [1],    [400],
        [Semicond.], [2],        [2.25], [10],
        [XLPE],      [$10^(-18)$],   [2.25], [0.46],
        [Seawater],  [4.2--5.0],  [80],   [0.6],
        [Filling],   [$10^(-12)$],  [2.25], [0.25],
        [Steel],     [4.7$times$$""^6$], [1],   [50],
      )
      #v(0.2cm)
      Three phases at 0#sym.degree, -120#sym.degree, +120#sym.degree.
      r#sub[c] = #f(t_cond_d/2, d:2) mm (conductor radius), r#sub[semi] = #f(t_semi_od/2, d:2) mm, r#sub[ins] = #f(t_ins_od/2, d:2) mm.
    ]
  )
]

// ## §1.2 Domain & BCs #########################################
#slide(title: [§1.2 #sym.dot.c Computational Domain & Boundary Conditions])[
  #cols(
    [
      *Governing equation* (freq. domain, v-formulation):
      $ -nabla dot (sigma + j omega epsilon) nabla v = 0 $
      solved on *Domain_Ele* = full 2D cross-section.

      *Boundary conditions*
      - $v = V_0 e^(j phi_k)$ on Cu phase k, $V_0 = V_"LL"\/sqrt(3)$ = #eng(V0_val, unit: "V")
      - $v = 0$ on outer seawater boundary (R = #f(t_env_d/2, d:0) mm)
      - Continuity of $J_n = (sigma + j omega epsilon) E_n$ at interfaces

      *Variational form*: Find $v in V_h$ such that $v = V_0 e^(j phi_k)$ on $Gamma_k$ and:
      $ integral_Omega (sigma + j omega epsilon_0 epsilon_r) nabla v dot nabla v' , d Omega = 0 quad forall v' in V_(h,0) $
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
      *Domain*: environment disk R = #f(t_env_d/2, d:0) mm (cable outer sheath r = 21.25 mm).
      Outer ring R+25%: *VolSphShell* infinite-element Jacobian.

      #v(0.2cm)
      #note(color: green, title: "Simplifications")[
        #set text(size: 12pt)
        *2D*: per-unit-length, infinite cable along z.
        *Semiconductor layer* ($sigma$ = 2 S/m) graded explicitly -- avoids field-stress singularities at Cu/XLPE interface.
        *Steel armour* excluded from EM solve (see §1.3).
      ]
    ]
  )
]
#slide(title: [§1.2 #sym.dot.c Domain Size -- Capacitance Convergence])[
  #image("graphs/domain_conv.svg", width: 100%)
]
#slide(title: [§1.2 #sym.dot.c Electrodynamic Domain and BCs])[
  #image("graphs/geometry_electro.svg", width: 100%)
]

// ## §1.3 Simplifications #####################################
#slide(title: [§1.3 #sym.dot.c Geometry Simplifications])[
  #cols(
    [
      *Retained in this model*
      #set text(size: 13pt)
      - *2D cross-section*: cable is infinitely long $->$ per-unit-length quantities
      - *Full three-phase geometry*: all three cores modelled -- mutual field cancellation captured
      - *Semiconductor layer*: graded $sigma$ = 2 S/m annulus -- prevents field-stress singularity at Cu/XLPE edge
      - *VolSphShell* outer ring: maps R $->$ $infinity$; eliminates v = 0 truncation error $tilde.op (r_"cable"/R)^2$
    ],
    [
      *Simplifications made*
      #set text(size: 13pt)
      - *Armour excluded from EM domain*: the steel armour wires are drawn in the geometry (shield = true) but not included in the conducting domain -- set to $sigma$ = 0 for the electrodynamic solve. This avoids the complex helical geometry of ~66 wires.
      - *No optical fibre*: 3-phase model replaces the fibre unit with a 3rd power core
      - *Linear $mu$*: Cu, PE, seawater all have $mu_r$ = 1
      - *Steady-state time-harmonic*: transient effects neglected

      #v(0.15cm)
      #note(color: gold, title: "Impact of armour exclusion")[
        #set text(size: 12pt)
        Real armour: $sigma$=4.7$times$$""^6$ S/m, $mu$#sub[r]=4, wire diam.=3.6 mm. At 50 Hz the skin depth in steel $approx$ 2 mm $approx$ wire radius $->$ *significant eddy losses expected*. Excluding it is conservative (underestimates losses). For a complete loss budget, the armour must be modelled.
      ]
    ]
  )
]

// ## §1.4 Mesh #################################################
#slide(title: [§1.4 #sym.dot.c Mesh Refinement])[
  #cols(ratio: (1fr, 1.35fr),
    [
      Gmsh Python API #sym.dot.c Distance + Threshold fields.
      #set text(size: 12pt)
      #v(0.1cm)
      #styled-table(
        columns: (auto, auto),
        table.header(text(fill: white)[Region], text(fill: white)[h]),
        [Copper ($r_c$ = #f(t_cond_d/2, d:2) mm)], [#f(t_h_cond*1000, d:2) mm],
        [Semiconductor],   [#f(t_h_semi*1000, d:2) mm],
        [XLPE insulation], [#f(t_h_ins*1000, d:2) mm],
        [Sheath / filling],[1.25 mm],
        [Environment],     [18 mm],
        [Outer boundary],  [35 mm],
      )
      #v(0.15cm)
      #set text(size: 13pt)
      - $r_c$ = conductor radius = #f(t_cond_d/2, d:2) mm
      - $#sym.delta$ = #f(skin_depth*1000, d:1) mm $>>$ $r_c$ $->$ uniform J, no sub-skin refinement
      - Convergence criterion: all quantities within *0.1%* of finest mesh
    ],
    [
      *Electrodynamic convergence* -- `make convergence`:
      #image("graphs/conv_electro.svg", width: 100%)
    ]
  )
]

// ## §1.5 Defect ###############################################
// Analytical bubble field estimate (coaxial formula, independent of mesh quality)
#let r_semi_m   = t_semi_od / 2000.0
#let r_ins_m    = t_ins_od  / 2000.0
#let rel_r_def  = toml-val("relative_radius")
#let r_void_m   = r_semi_m + rel_r_def * (r_ins_m - r_semi_m)
#let E_bg_void  = V0_val / (r_void_m * calc.ln(r_ins_m / r_semi_m))
#let E_void_est = E_bg_void * 2.0 * 2.25 / (2.25 + 1.0)

#slide(title: [§1.5 #sym.dot.c Insulation Defect -- Air Bubble])[
  #cols(
    [
      #set text(size: 11pt)
      *Defect parameters* (cable.toml `[defect]`):
      - Phase 0 (Copper_0), angle 45#sym.degree
      - Radial position: 65% of insulation thickness
      - *Radius: 0.25 mm*, material: air ($epsilon$#sub[r] = 1, $sigma$ $approx$ 0)

      *Field enhancement*: normal D continuity gives
      $epsilon_"XLPE" E_"XLPE" = epsilon_"air" E_"void"$.
      For a cylindrical air void:
      $E_"void" = frac(2 epsilon_r, epsilon_r + 1) E_0 = #f(2*2.25/(2.25+1), d:3) E_0$.

      *Analytical estimate* at $r_"void"$ = #f(r_void_m*1000, d:3) mm (coaxial, V#sub[LL] = 3 kV):
      $ E_0 = frac(V_phi, r_"void" ln(r_"ins"\/r_"semi")) = #eng(E_bg_void, unit: "V/m") $
      $ E_"void" = #f(2*2.25/(2.25+1), d:3) times E_0 = bold(#eng(E_void_est, unit: "V/m")) $

      Rated 33 kV scales by $times$11 $->$ #eng(E_void_est*11, unit: "V/m") $>>$ 3 MV/m $->$ *PD expected*.
    ],
    [
      #image("graphs/defect_field.svg", width: 100%)
      #set text(size: 11pt)
      FEM $|E|_"void"$ at rated 33 kV for 7 bubble radii (100--500 µm).
      The conclusion is robust for the resolved 250--500 µm range; smaller bubbles require a dedicated local mesh refinement study.
    ]
  )
]

// ## §1.6 Current densities ####################################
#slide(title: [§1.6 #sym.dot.c Resistive and Displacement Current Densities])[
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
        [|#strong[J]#sub[r]|], eng(Jr_max, unit: "A/m²"), [Semiconductor ($sigma$=2)],
        [|#strong[J]#sub[d]|], eng(Jd_max, unit: "A/m²"), [XLPE ($epsilon$#sub[r]=2.25)],
        [|#strong[J]#sub[t]|], eng(Jt_max, unit: "A/m²"), [Semiconductor],
      )
    ],
    [
      *Current conservation* $nabla dot bold(J)_t = 0$. In XLPE insulation:
      - $|J_r| = sigma E approx 10^(-18) times$ #eng(E_max, unit: "V/m") $approx 0$ (negligible)
      - $|J_d| = omega epsilon_0 epsilon_r E = 2pi times 50 times 8.85 times 10^(-12) times 2.25 times$ #f(E_max, d: 0) $approx$ #eng(Jd_max, unit: "A/m²") ✓

      Ratio $|J_d|/|J_r|$ in XLPE $>>$ 1 $->$ *capacitive dominated* at 50 Hz.

      #v(0.2cm)
      #note(color: green)[
        #set text(size: 12pt)
        Semiconductor ($sigma$ = 2 S/m) carries the resistive return current and provides the equipotential surface defining uniform radial field in XLPE. Output: `res/jrm.pos`, `res/jdm.pos`, `res/jtm.pos`
      ]
    ]
  )
]

// ## §1.7 Capacitance ##########################################
#slide(title: [§1.7 #sym.dot.c Per-Unit-Length Capacitance])[
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
        [*C#sub[FEM]*],   [*#eng(C_fem*1e12, unit: "pF/m")* = #f(C_fem*1e9, d:2) $mu$F/km],
        [*C#sub[analytic]*], [*#eng(C_an*1e12, unit: "pF/m")* = #f(C_an*1e9, d:2) $mu$F/km],
        [*C#sub[FEM]/C#sub[an]*], [*#f(C_rat, d:2)*],
      )
    ],
    [
      *Analytic estimate* (isolated coaxial, Gauss's law):
      $ C_"an" = frac(2 pi epsilon_0 epsilon_r^"XLPE", ln(r_"ins" / r_"semi")) $
      = $frac(2 pi times 8.85 times 10^(-12) times 2.25, ln(4.85 / 2.15))$ = #eng(C_an*1e12, unit: "pF/m")

      *Ratio = #f(C_rat, d:2)* $->$ FEM is ~31% lower than analytic.

      *Why lower?*
      - Analytic assumes *single isolated coax*, outer conductor at r#sub[ins]
      - FEM captures *mutual field cancellation* between three adjacent phases
      - Return path (grounded seawater) is at R = #f(t_env_d/2, d:0) mm, not at r#sub[ins]

      #note(color: gold)[
        #set text(size: 12pt)
        C does not vary with frequency ($epsilon$ is frequency-independent in XLPE).
      ]
    ]
  )
]

// ## §1.8 Frequency effects -- text ############################
#slide(title: [§1.8 #sym.dot.c Frequency Dependence of the Electrodynamic Model])[
  #cols(
    [
      #set text(size: 12pt)
      *Capacitance*: purely dielectric, *frequency-independent*:
      $ C = frac(2 pi epsilon_0 epsilon_r, ln(r_"ins"/r_"semi")) $
      Valid as long as $sigma / (omega epsilon) << 1$ in XLPE.
      At 50 Hz: $sigma_"XLPE"/(omega epsilon) approx 10^(-18)/(2pi times 50 times 2.25 times 8.85 times 10^(-12)) approx 10^(-10)$ $->$ ideal dielectric. *C is flat with frequency* (confirmed by sweep below).

      #v(0.15cm)
      *Charging current* -- physical meaning:
      The cable acts as a distributed capacitor: each metre of XLPE stores charge $q = C V_0$ on the conductor surface. In AC operation, this charge is deposited and withdrawn every half-cycle, so a *reactive* current flows along the cable even at no load:
      $ I_c = omega C V_0 $
      $I_c$ grows linearly with $f$ even though $C$ is constant.

      At 50 Hz and V#sub[LL] = 3 kV:
      $I_c = 2 pi times 50 times #eng(C_fem, unit: "F/m") times #eng(V0_val, unit: "V") = #eng(2*calc.pi*50*C_fem*V0_val, unit: "A/m")$.

      For a cable of length $ell$, the total charging current at rated 33 kV reaches:
      $I_c^"total" = omega C_"FEM" times (V_"LL"/sqrt(3)) times ell$

      This current flows in the conductor before any load is connected, occupying thermal and ampacity budget. Beyond a *critical length* $ell_c = I_"rated"/(omega C V_0)$, the cable is fully loaded by its own charging current and cannot transmit useful power. For typical 33 kV XLPE cables this critical length is $tilde$ 50--100 km, which is why *HVDC* (DC has zero charging current) becomes attractive for long subsea links.
    ],
    [
      #align(center, image("img/E.png", height: 4.35cm))
      #set text(size: 11pt)
      Electric-field map in the cable area. The highest stress is located near the conductor/semiconductor interface and is the reference field for the frequency-independent capacitance calculation.

      #v(0.15cm)
      #note(color: accent)[
        #set text(size: 12pt)
        *Frequency sweep* (`make freq`) records C and $I_c$ at 1--1000 Hz. Key result: the capacitance remains flat; only the capacitive current increases with frequency.
      ]
      #v(0.15cm)
      #note(color: gold)[
        #set text(size: 12pt)
        Resistance and skin-effect questions are discussed in the MQS section (§2.7), where current density and Joule losses are computed.
      ]
    ]
  )
]
#slide(title: [§1.8 #sym.dot.c Frequency Sweep -- C and Charging Current])[
  #image("graphs/freq_sweep_em.svg", width: 100%)
]

// ## §1.9 Design improvements ##################################
#slide(title: [§1.9 #sym.dot.c Cable Design Improvements -- Conductor Material])[
  #let sig_cu = 5.96e7
  #let sig_al = 3.5e7
  #let ratio_al = sig_cu / sig_al
  #cols(
    [
      *Goal*: reduce resistive losses. Dominant term is R#sub[DC] (skin negligible at 50 Hz).
      $ R_"DC" = frac(1, sigma pi r_c^2) $

      #set text(size: 12pt)
      *Copper vs Aluminium* (same conductor geometry, $r_c$ = #f(t_cond_d/2, d:2) mm):
      #styled-table(
        columns: (auto, auto, auto),
        table.header(
          text(fill: white)[Material],
          text(fill: white)[R#sub[DC] (mΩ/m)],
          text(fill: white)[Losses @ 400 A (kW/km)],
        ),
        [*Cu* (current)],     [*#f(R_dc*1e3, d:2)*], [*#f(P_tot*160000, d:1)*],
        [Al ($sigma$=3.5$times$$""^7$)], [#f(R_dc*ratio_al*1e3, d:2)], [#f(P_tot*ratio_al*160000, d:1)],
        [Al/Cu ratio],        [#f(ratio_al, d:2)$times$], [#f(ratio_al, d:2)$times$],
      )
      Aluminium is *#f(ratio_al, d:2)$times$ worse* in resistive losses for the same cross-section.
    ],
    [
      *Why aluminium is used in practice:*
      - Al density = 2.7 g/cm³ vs Cu = 8.9 g/cm³ $->$ 3.3$times$ lighter per volume
      - For the same resistance, Al cross-section = #f(ratio_al, d:2)$times$ Cu $->$ still *2$times$ lighter*
      - Lower cost per tonne
      - *For subsea cables*: weight is critical $->$ Al conductors common despite higher resistivity

      #v(0.1cm)
      *Electrodynamic impact*: larger Al conductor ($times$#f(ratio_al, d:2) cross-section) gives larger $r_c$ $->$ C increases slightly; E#sub[max] at inner insulation surface decreases (larger inner radius). *Net: Al at equivalent resistance $approx$ same C, lower E#sub[max]*.

      #v(0.1cm)
      #note(color: red, title: "Other design levers")[
        #set text(size: 12pt)
        Thicker XLPE (r#sub[ins]$arrow.t$): E $arrow.b$ $prop$ 1/ln(r#sub[ins]/r#sub[semi]), C $arrow.b$ simultaneously. Void-free manufacturing: removes $times$#f(2*2.25/(2.25+1), d:3) peak, no C change.
      ]
    ]
  )
]
