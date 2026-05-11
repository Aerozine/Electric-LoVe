#import "preamble.typ": *
// ##############################################################
#section-slide("3", "Coupled Magneto-Thermal Analysis")

// ## §3.1 Equations ############################################
#slide(title: [§3.1 #sym.dot.c Equations and Coupling])[
  #cols(
    [
      *Magnetic problem* (a--v, now $sigma$ = $sigma$(T)):
      $ nabla times (nu nabla times bold(a)) + sigma(T)(j omega bold(a) + nabla u_r/l_z) = 0 $

      *Thermal problem* (steady-state):
      $ -nabla dot (kappa nabla T) = Q(bold(a)), quad Q = frac(1,2) sigma |j omega bold(a) + u_r/l_z|^2 $

      *Temperature-dependent conductivity*:
      $ sigma(T) = frac(sigma_0, 1 + alpha(T - T_"ref")), quad alpha_"Cu" = 3.86 times 10^(-3) "K"^(-1) $

      *Coupling*: Q depends on a (mag.); $sigma$ depends on T (thermal).
    ],
    [
      #note(color: accent, title: "Picard iteration")[
        1. Solve magnetic at current T $->$ a, u#sub[r]\
        2. Compute $Q = frac(1,2)sigma(T)|j omega a + u_r/l_z|^2$\
        3. Solve thermal with Q $->$ update T\
        4. Re-assemble magnetic with new $sigma$(T); get residual\
        5. Repeat while $||"res"||/"||res"_0|| > "NLTolRel"$
      ]
      #v(0.2cm)
      #note(color: gold, title: "GetDP <a>[...] operator")[
        Thermal formulation is real-valued; Q involves complex phasors. `<a>[SquNorm[Dt[{a}]+{ur}/CoefGeo[]]]` forces complex arithmetic inside the real thermal equation, yielding the correct squared modulus.
      ]
    ]
  )
]

// ## §3.2 Domain & BCs #########################################
#slide(title: [§3.2 #sym.dot.c Thermal Domain and Boundary Conditions])[
  #cols(
    [
      *Thermal domain* = full cross-section (cable + seawater).
      Sources in DomainC_Mag (copper only; no armour $->$ no eddy-current source).

      *Robin BC* at outer boundary Sur_Robin_The:
      $ kappa frac(partial T, partial n) + h(T - T_0) = 0 $
      - h = 20 W/(m$""^2$#sym.dot.c K) (seawater natural convection)
      - T#sub[0] = 20#sym.degree C (ambient)

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
        table.header(text(fill: white)[Material], text(fill: white)[$kappa$ W/(m#sym.dot.c K)]),
        [Copper],   [400  (excellent)],
        [XLPE],     [0.46 (*bottleneck*)],
        [Filling],  [0.25 (*worst*)],
        [Seawater], [0.6],
      )
      The XLPE insulation is the main *thermal resistance* limiting heat dissipation.
    ]
  )
]

// ## §3.2b Thermal geometry figure ############################
#slide(title: [§3.2 #sym.dot.c Thermal Domain and Boundary Conditions])[
  #image("graphs/geometry_thermal.svg", width: 100%)
]

// ## §3.3 Mesh refinement thermal #############################
#slide(title: [§3.3 #sym.dot.c Mesh Refinement Effects on Thermal Analysis])[
  #cols(ratio: (1fr, 1.4fr),
    [
      #set text(size: 13pt)
      *Critical interfaces* (steep $nabla$T):
      - Cu/XLPE: $kappa$ 400 $->$ 0.46 W/(m#sym.dot.c K) $->$ highest gradient
      - XLPE/filling: $kappa$ 0.46 $->$ 0.25 $->$ second

      *At I = 1 A*: $Delta$T = #eng(T_max - T_min, unit: "#sym.degree C") -- invisible at this scale. Same mesh coincides with MQS refinement region $->$ no extra cost.

      *At I_rated = 400 A* ($Delta$T $prop$ I$""^2$): $Delta$T $approx$ #f((T_max - T_min)*160000, d:1) #sym.degree C $->$ mesh effect visible. Coarser XLPE mesh $->$ T#sub[max] *underestimated* (gradient undersampled).

      Thermal problem: second-order elliptic $->$ smooth monotone convergence.
    ],
    [
      *T_max convergence* -- `make convergence` produces:
      #image("graphs/conv_thermal.svg", width: 100%)
      #set text(size: 11pt)
      At I = 1 A, $Delta$T too small to show convergence. Scale by 400$""^2$ for rated current sensitivity.
    ]
  )
]

// ## §3.4 Thermal vs frequency ########################################
#slide(title: [§3.4 #sym.dot.c Thermal Impact of Frequency (Skin Effect)])[
  #cols(ratio: (1fr, 1.4fr),
    [
      #set text(size: 12pt)
      At 50 Hz: $#sym.delta =$ #eng(skin_depth, unit: "m") $>>$ r#sub[c] $->$ uniform J $->$ baseline heating.

      At higher frequency: skin effect concentrates J near surface
      $->$ higher local Q $->$ higher T#sub[max] even at same *total* I.

      *Key transition*: when $#sym.delta tilde.op r_c$, i.e. f $tilde.op$ #f(1.0/(calc.pi*(1.95e-3)*(1.95e-3)*4*calc.pi*1e-7*5.96e7)*2, d:0) Hz for r#sub[c] = 1.95 mm.

      #v(0.1cm)
      #note(color: gold, title: "Design implication")[
        #set text(size: 11pt)
        For power cables at 50 Hz: skin effect negligible. For
        high-frequency applications (>500 Hz), litz wire or hollow
        conductors are required to limit R#sub[AC] and thermal hotspots.
      ]
    ],
    [
      *Relative temperature-rise increase vs frequency*:
      #image("graphs/freq_sweep_thermal.svg", width: 100%)
    ]
  )
]

// ## §3.5-6 Temperature ########################################
#slide(title: [§3.5--3.6 #sym.dot.c Temperature Distribution])[
  #cols(
    [
      *Linear case* (NonLinearThermal = 0):

      #styled-table(
        columns: (auto, auto),
        table.header(text(fill: white)[Quantity], text(fill: white)[Value]),
        [T#sub[ambient] T#sub[0]],          [20.000 #sym.degree C],
        [T#sub[min] (FEM, from file)],       eng(T_min, unit: "°C"),
        [T#sub[max] (hotspot, from file)],   eng(T_max, unit: "°C"),
        [$Delta$T at I#sub[peak] = 1 A],           eng(T_max - T_min, unit: "°C"),
        [Q#sub[total]],                      eng(Pmt, unit: "W/m"),
        [|B|#sub[max] (magneto-thermal)],    eng(Bmt_mx*1e6, unit: "µT"),
        [|J|#sub[max] (magneto-thermal)],    eng(Jmt_mx, unit: "A/m²"),
      )
    ],
    [
      *Hotspot*: at centre of each copper conductor.
      Heat path: Cu $->$ XLPE (low $kappa$) $->$ seawater $->$ Robin BC.

      *Scaling to real current* (linear regime: $Delta T tilde.op I^2$):
      - At I = 400 A: $Delta T approx 400^2 times$ #f(T_max - T_min, d: 3) = #f((T_max - T_min)*160000, d: 1) #sym.degree C

      This far exceeds the XLPE limit (~90#sym.degree C over ambient). Real cable design uses lower current density or better cooling.

      #note(color: gold)[
        Temperature at outer water boundary = T#sub[0] (Robin BC enforces ambient at large r). Temperature field output: `res/temperature.pos`.
      ]
      #note(color: accent)[
        MQS and magneto-thermal results are identical for the linear case ($sigma$ = const): |B|#sub[max] and |J|#sub[max] agree to all significant figures.
      ]
    ]
  )
]

// ## §3.7-8 Nonlinear ##########################################
#slide(title: [§3.7--3.8 #sym.dot.c Nonlinear $sigma$(T) Case])[
  #cols(ratio: (1fr, 1.45fr),
    [
      $ sigma(T) = frac(sigma_0, 1 + alpha(T-T_"ref")) $
      As T $arrow.t$: $sigma$ $arrow.b$ $->$ R $arrow.t$ $->$ Q $arrow.t$ $->$ *positive feedback*.

      #set text(size: 12pt)
      *Picard (fixed-point) loop*: NLTolRel = 10$""^(-6)$, max 25 iter.

      #styled-table(
        columns: (auto, auto, auto, auto),
        table.header(
          text(fill: white)[I (A)],
          text(fill: white)[$Delta$T (#sym.degree C)],
          text(fill: white)[$sigma$ change],
          text(fill: white)[Iterations],
        ),
        [1],   [< 0.001], [< 0.001%], [2 ✓],
        [50],  [$approx$ 0.47],   [$approx$ 0.18%],  [4 ✓],
        [150], [$approx$ 4.2],    [$approx$ 1.6%],   [8 ✓],
        [400], [$approx$ 30],     [$approx$ 11.5%],  [*25 ✗ (no convergence)*],
      )
      #v(0.1cm)
      At 400 A: Picard does *not reach tolerance* within 25 iterations. Fix: Newton-Raphson (quadratic convergence -- see dashed curves in graph), under-relaxation, or reduce NLTolRel.
    ],
    [
      *Picard relative-error study* -- `make picard` produces:
      #image("graphs/picard_convergence.svg", width: 100%)
      #set text(size: 11pt)
      400 A hits max-iter limit (||r||/||r_0|| = 0.188 after 25 steps).
    ]
  )
]

// Summary ###################################################
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
        [C#sub[FEM]/C#sub[an]],     f(C_rat, d:2),
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
        [$Delta$T],                   eng(T_max - T_min, unit: "°C"),
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
        [R#sub[AC] (Ph 0)],      [#eng(R0*1e3, unit: "mΩ/m") = #f(R0*1e3, d:2) Ω/km],
        [R#sub[DC]],             [#eng(R_dc*1e3, unit: "mΩ/m") = #f(R_dc*1e3, d:2) Ω/km],
        [Skin depth $#sym.delta$],          eng(skin_depth, unit: "m"),
        [P#sub[total]],          [#eng(P_tot, unit: "W/m") = #eng(P_tot*1e3, unit: "W/km")],
        [L (circuit)],           [#eng(L0*1e9, unit: "nH/m") = #f(L0*1e6, d:2) mH/km],
        [L (energy)],            [#eng(L_en*1e9, unit: "nH/m") = #f(L_en*1e6, d:2) mH/km],
      )
      #note(color: green)[
        #set text(size: 12pt)
        All values read live from `res/*.dat` via Typst `read()`. Re-run `make slides` after each simulation to refresh.
      ]
    ]
  )
]
