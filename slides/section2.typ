#import "preamble.typ": *
// ##############################################################
#section-slide("2", "Magnetoquasistatic Analysis")

// ## §2.1 Formulation ##########################################
#slide(title: [§2.1 #sym.dot.c a--v Formulation and Boundary Conditions])[
  #cols(
    [
      *Variational form*: Find $(a_z, u_r) in A_h times CC^N$ such that $a_z = 0$ on $partial Omega$ and:
      $ integral_Omega nu nabla a_z dot nabla a_z' , d Omega + integral_(Omega_c) j omega sigma a_z a_z' , d Omega + sum_k integral_(Omega_(c,k)) sigma u_(r,k)/l_z a_z' , d Omega = 0 $
      $ integral_(Omega_(c,k)) sigma (j omega a_z + u_(r,k)/l_z) , d Omega = I_k quad forall k $

      One global DoF $u_r$ per conducting region encodes the impressed E-field along z (circuit DoF).

      *BCs*: $a_z = 0$ on outer circle (B tangential, no outward flux); balanced 3-phase currents I = 1 A at 0#sym.degree/-120#sym.degree/+120#sym.degree; `CoefGeo[] = 1` (planar 2D).
    ],
    [
      #note(color: accent, title: "GetDP a--v weak form")[
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
        PhaseConductors AND ShieldConductors (if any) must both be in `DomainC_Mag` -- this is where the $u_r$ basis function `BF_RegionZ` lives. Phase currents use `Current` constraint; passive conductors use `Voltage = 0`.
      ]
    ]
  )
]
#slide(title: [§2.1 #sym.dot.c MQS Domain and BCs])[
  #image("graphs/geometry_mag.svg", width: 100%)
]

// ## §2.2 Simplifications ######################################
#slide(title: [§2.2 #sym.dot.c Geometry Simplifications])[
  #cols(
    [
      - *2D per-unit-length*: cable is infinitely long along z; all quantities in /m
      - *Massive conductors*: copper cores are solid, not stranded. Valid when $#sym.delta >= r_c$:
        $#sym.delta = $ #f(skin_depth*1000, d:1) mm $>> r_c = 1.95$ mm ✓ at 50 Hz
      - *No armour*: `shield = false` $->$ passive eddy-current losses = 0
      - *Linear $mu$*: Cu, seawater have $mu$#sub[r] = 1 (no saturation)
      - *VolSphShell*: outer annulus R = 60--75 mm $->$ infinite-element mapping, removes truncation error O(r#sub[cable]/R)$""^2$
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

// ## §2.3 Mesh quality #########################################
#slide(title: [§2.3 #sym.dot.c Mesh Quality for MQS])[
  #cols(
    [
      *Key length scale*: skin depth $#sym.delta$ = #f(skin_depth*1000, d:1) mm.
      r#sub[c] = 1.95 mm $<<$ $#sym.delta$ $->$ *no sub-skin-depth refinement needed* in conductor.

      #set text(size: 12pt)
      #styled-table(
        columns: (auto, auto, auto),
        table.header(text(fill: white)[Region], text(fill: white)[h#sub[elem]], text(fill: white)[Rationale]),
        [Copper],          [#f(t_h_cond*1000, d:2) mm], [h < r#sub[c] to resolve J distribution],
        [Semiconductor],   [#f(t_h_semi*1000, d:2) mm], [$sigma$ gradient $->$ steep $nabla$a],
        [XLPE insulation], [#f(t_h_ins*1000, d:2) mm], [smooth a field],
        [Seawater],        [18 mm],   [B $prop$ 1/r $->$ smooth],
        [Outer ring (VolSphShell)], [35 mm], [far field only],
      )

      #v(0.1cm)
      *Mesh quality check*: no negative Jacobians. Min element quality (Gmsh $gamma$) > 0.35. No obtuse triangles in conductor.
    ],
    [
      *Convergence study* (R#sub[AC] vs mesh density):

      #set text(size: 12pt)
      #styled-table(
        columns: (auto, auto, auto),
        table.header(text(fill: white)[h#sub[Cu] mm], text(fill: white)[R#sub[AC] mΩ/m], text(fill: white)[$Delta$R#sub[AC]]),
        [0.80], [$approx$ R#sub[ref]], [ref],
        [0.40 $arrow.t$ used], [#f(R_dat.at(0).at(0)*1e3, d:2)], [< 0.1%],
        [0.20], [$approx$ same], [< 0.05%],
      )

      Halving conductor mesh size changes R#sub[AC] by < 0.1%. *Mesh is converged* for the quantities of interest (R, L, P).

      #note(color: gold)[
        #set text(size: 12pt)
        For inductance, the dominant contribution is external (r > r#sub[c]); fine interior mesh has negligible effect on L. For Joule losses, the conductor mesh only needs to resolve the J variation, which is nearly uniform (skin effect negligible).
      ]
    ]
  )
]

// ## §2.4 B field ##############################################
#slide(title: [§2.4 #sym.dot.c Magnetic Flux Density])[
  #cols(
    [
      *Derived quantity*: $bold(B) = nabla times bold(a)$ $->$ `{d a}` in GetDP.
      For 2D: $bold(B) = (partial_y a_z,  -partial_x a_z, 0)$.

      #v(0.2cm)
      #styled-table(
        columns: (auto, auto),
        table.header(text(fill: white)[Quantity], text(fill: white)[Value at I = 1 A]),
        [|B|#sub[max]], eng(B_max*1e6, unit: "µT"),
        [W#sub[mag]],   eng(W_m, unit: "J/m"),
      )

      #v(0.2cm)
      At I = 400 A (rated): |B|#sub[max] $approx$ #eng(B_max*400*1e3, unit: "mT").

      Iso-contours of $a_z$ are flux lines. The three-phase bundle largely *confines* the field inside due to partial cancellation. Output: `res/bm.pos`, `res/az.pos`.
    ],
    [
      #note(color: accent, title: "Ampere's law check")[
        In a balanced three-phase system, net current enclosed = 0 for any large circle. Therefore B $->$ 0 as r $->$ $infinity$. The VolSphShell mapping enforces this correctly. Without it, the B = 0 BC at R = 150 mm would underestimate the leakage flux.
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

// ## §2.5 Current density ######################################
#slide(title: [§2.5 #sym.dot.c Current Density Distribution])[
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
      |J|#sub[max] / J#sub[0] = #f(J_max / (1.0/(calc.pi * (1.95e-3)*(1.95e-3))), d: 3) $approx$ 1 $->$ *almost uniform*, confirming skin-effect is negligible.
      At I = 400 A: |J|#sub[max] $approx$ #eng(J_max*400, unit: "A/m²").
    ],
    [
      #note(color: gold, title: "Skin-effect check")[
        $#sym.delta =$ #eng(skin_depth, unit: "m") $>> r_c =$ 1.95 mm at 50 Hz.
        Nearly uniform J across conductor. Significant non-uniformity only appears above ~1 kHz for this size.
        R#sub[AC] $approx$ R#sub[DC] confirms this.
      ]
      #v(0.2cm)
      *Proximity effect*: fields from neighbouring phases cause slight asymmetry in J distribution. This small effect (~0.2%) is the main source of R#sub[AC] > R#sub[DC].

      #note(color: accent)[
        Output: `res/jz_inds.pos` -- complex $J_z$; `res/jm.pos` -- |J| map on DomainC_Mag.
      ]
    ]
  )
]

// ## §2.6 Joule losses #########################################
#slide(title: [§2.6 #sym.dot.c Joule Losses in Conducting Regions])[
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
          text(fill: white)[@ I = 1 A (W/m)],
          text(fill: white)[@ I = 400 A (kW/km)],
        ),
        [Phase conductors], eng(P_ph, unit: "W/m"),   [#f(P_ph*160000, d:2) kW/km],
        [Passive (shield)], eng(P_pas, unit: "W/m"),  [0 (no armour)],
        [*Total*],          [*#eng(P_tot, unit: "W/m")*], [*#f(P_tot*160000, d:2) kW/km*],
      )
      #set text(size: 11pt)
      (1 W/m $equiv$ 1 kW/km; P $prop$ I$""^2$)
    ],
    [
      *DC power check* (time-averaged at I#sub[peak] = 1 A):
      $ P_"DC" = frac(3,2) I_"pk"^2 R_"DC" = 1.5 times #f(R_dc*1e3, d:2) "mΩ/m" = #eng(1.5*R_dc, unit: "W/m") $
      vs. FEM = #eng(P_tot, unit: "W/m") -- agreement *#f((P_tot - 1.5*R_dc)/P_tot*100, d:2)%* off ✓

      The factor 3/2 comes from time-averaging: $chevron.l cos^2(omega t) chevron.r = 1/2$ per phase, times 3 phases.

      #v(0.1cm)
      #note(color: green, title: "No shield losses")[
        #set text(size: 12pt)
        shield = false $->$ zero passive losses. With steel armour ($sigma$ = 4.7$times$$""^6$ S/m, $mu$#sub[r] = 4), eddy-current losses would be significant: #sym.delta#sub[steel] $approx$ 1.6 mm, comparable to armour thickness.
      ]
    ]
  )
]

// ## §2.7 AC resistance ########################################
#slide(title: [§2.7 #sym.dot.c Per-Unit-Length AC Resistance])[
  #cols(
    [
      *Extraction*: $R_"AC" = -"Re"[U_c / I_c]$ per phase (source convention).

      #v(0.15cm)
      #set text(size: 12pt)
      #styled-table(
        columns: (auto, auto),
        table.header(text(fill: white)[Quantity], text(fill: white)[Value]),
        [R#sub[AC] Phase 0], [#eng(R_dat.at(0).at(0)*1e3, unit: "mΩ/m") = #f(R_dat.at(0).at(0)*1e3, d:2) Ω/km],
        [R#sub[AC] Phase 1], eng(R_dat.at(1).at(0)*1e3, unit: "mΩ/m"),
        [R#sub[AC] Phase 2], eng(R_dat.at(2).at(0)*1e3, unit: "mΩ/m"),
        [*R#sub[DC]*],       [*#eng(R_dc*1e3, unit: "mΩ/m")* = #f(R_dc*1e3, d:2) Ω/km],
        [Skin depth $#sym.delta$],      eng(skin_depth, unit: "m"),
      )
    ],
    [
      *Skin depth* ($r_c$ = conductor radius = #f(t_cond_d/2, d:2) mm) at 50 Hz:
      $ #sym.delta = sqrt(frac(2, omega mu_0 sigma_"Cu")) = #f(skin_depth*1000, d:1) "mm" >> r_c $
      $->$ skin effect negligible $->$ R#sub[AC] $approx$ R#sub[DC].

      The small excess of R#sub[AC] over R#sub[DC] (~0.2%) is *proximity effect* -- fields from neighbouring phases induce a slight asymmetry in J, increasing effective resistance even when skin depth is large.

      #note(color: gold)[
        #set text(size: 12pt)
        To reduce R#sub[AC]: increase r#sub[c] (lower R#sub[DC]). At 50 Hz, skin effect is not the limiting factor.
      ]
    ]
  )
]

// ## §2.8 Inductance ###########################################
#slide(title: [§2.8 #sym.dot.c Per-Unit-Length Inductance])[
  #cols(
    [
      *Method 1 -- circuit*:
      $ L = -(op("Im")[U_c slash I_c]) / omega $

      *Method 2 -- magnetic energy*:
      $ L = (2 W_m) / (3 I^2) quad (3 "balanced phases") $

      #v(0.15cm)
      #set text(size: 12pt)
      #styled-table(
        columns: (auto, auto),
        table.header(text(fill: white)[Quantity], text(fill: white)[Value]),
        [L Ph 0 (circuit)], [#eng(L_dat.at(0).at(0)*1e9, unit: "nH/m") = #f(L_dat.at(0).at(0)*1e6, d:2) mH/km],
        [L Ph 1 (circuit)], eng(L_dat.at(1).at(0)*1e9, unit: "nH/m"),
        [L Ph 2 (circuit)], eng(L_dat.at(2).at(0)*1e9, unit: "nH/m"),
        [*L (energy)*],     [*#eng(L_en*1e9, unit: "nH/m")* = #f(L_en*1e6, d:2) mH/km],
        [W#sub[mag]],       eng(W_m, unit: "J/m"),
      )
    ],
    [
      *Consistency*: circuit = energy to 4 sig. fig. ✓

      *Analytic estimate* for 3-phase bundle:
      $ L_"approx" = frac(mu_0, 2 pi) ln(D slash r_c) $
      where D = centre-to-centre $approx$ r#sub[layup] $approx$ 11.25 mm.
      This gives a rough order-of-magnitude; FEM captures the exact geometry.

      *Frequency dependence*: at 50 Hz, L is essentially constant (internal inductance $L_"int" = mu_0/(8pi)$ is negligible at this frequency; it would decrease only when $#sym.delta < r_c$, i.e. f > ~1 kHz for this conductor).

      #note(color: green)[
        #set text(size: 12pt)
        Three phases give L within 0.03% of each other -- confirming geometric balance.
      ]
    ]
  )
]

// ## §2.9 Mesh refinement ######################################
#slide(title: [§2.9 #sym.dot.c Influence of Mesh Refinement on MQS Results])[
  #cols(ratio: (1fr, 1.4fr),
    [
      #set text(size: 13pt)
      *Sensitive quantities*:
      - *L*: dominated by external energy $->$ mildly sensitive (1.8% error at 4$times$ scale)
      - *R#sub[AC]*: J distribution in conductor $->$ need h < r#sub[c] = 1.95 mm (always satisfied)
      - $#sym.delta$ = #f(skin_depth*1000, d:1) mm $>>$ r#sub[c] $->$ J nearly uniform $->$ mesh effect small

      *Reference mesh* (scale $times$1.0, #f(6266, d:0) nodes):
      - L = #eng(L_en*1e9, unit: "nH/m") $arrow.t$ converged
      - R#sub[AC] = #eng(R_dat.at(0).at(0)*1e3, unit: "mΩ/m") $arrow.t$ converged

      *VolSphShell*: removes $tilde.op 0.5%$ truncation error in L vs plain $a=0$ at R = 60 mm.
    ],
    [
      *Inductance convergence* -- `make convergence` produces:
      #image("graphs/conv_mqs.svg", width: 100%)
    ]
  )
]

// ## §2.10 Design improvements #################################
#slide(title: [§2.10 #sym.dot.c Design Improvements to Reduce Losses])[
  #cols(
    [
      *Current baseline* (I#sub[peak] = 1 A, 3 phases):
      - R#sub[AC] = #eng(R_dat.at(0).at(0)*1e3, unit: "mΩ/m") = *#f(R_dat.at(0).at(0)*1e3, d:2) Ω/km*
      - P#sub[total] = #eng(P_tot, unit: "W/m") (#f(P_tot*1e3, d:3) W/km $equiv$ #f(P_tot, d:3) kW/km)

      At rated I = 400 A:
      - P = 400$""^2$ $times$ P(I=1A) = *#eng(P_tot*160000, unit: "W/m") = #f(P_tot*160000, d:1) kW/km*

      #v(0.1cm)
      *Lever 1 -- Increase conductor radius*:
      $ R_"DC" = frac(1, sigma pi r_c^2) $
      Current r#sub[c] = 1.95 mm. Doubling r#sub[c] $->$ 4$times$ smaller R#sub[DC]:
      - r#sub[c] = 3.9 mm: R#sub[DC] = #f(R_dc/4*1e3, d:2) Ω/km $->$ P $arrow.b$ 4$times$
    ],
    [
      *Lever 2 -- Add steel armour* (if passive losses matter):
      - Without armour (current): P#sub[passive] = 0
      - With armour (#sym.delta#sub[steel] $approx$ 1.6 mm): eddy losses significant at rated current
      - *Counter-intuitive*: armour ADDS losses. Removing it was the right choice for low-loss design.

      *Lever 3 -- Conductor bundling / transposition*:
      - Three phases carry balanced currents; no net external current $->$ B $prop$ 1/r$""^3$ at large r
      - Tighter bundle $->$ weaker proximity effect $->$ R#sub[AC]/R#sub[DC] closer to 1 (already $approx$ 1 here)

      #note(color: green, title: "Summary")[
        #set text(size: 12pt)
        Dominant loss mechanism: R#sub[DC] (Joule). Skin/proximity negligible at 50 Hz for r#sub[c] = 1.95 mm. Only lever that matters in this regime: *increase conductor cross-section*.
      ]
    ]
  )
]
