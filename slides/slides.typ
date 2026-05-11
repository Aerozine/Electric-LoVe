#import "@preview/dashy-todo:0.1.3": todo
#import "preamble.typ": *
// ============================================================
// ELEC0041 – LoVe-in-HV  |  Presentation slides
// Typst 0.14  –  compile with:  typst compile --root . slides/slides.typ
// ============================================================
#set page(paper: "presentation-16-9", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "New Computer Modern", size: 15pt, fill: rgb("#1a1a2e"))
#set par(justify: false, leading: 0.6em)

// ═══════════════════════════════════════════════════════════════
//   S L I D E S
// ═══════════════════════════════════════════════════════════════

#title-slide(
  "Electromagnetic & Thermal Analysis\nof a HV Subsea Cable",
  "ELEC0041 – Project 2026",
  "Loïc Delbarre  ·  University of Liège"
)

// ## Outline ##################################################
#slide(title: "Outline")[
  #grid(columns: (1fr, 1fr), column-gutter: 0.8cm,
    block(fill: light, radius: 5pt, inset: 10pt, width: 100%)[
      *§1 #sym.dot.c Electrodynamic Analysis*
      #set text(size: 13pt)
      - Cable geometry & materials
      - Domain, equations, BCs
      - Domain size justification
      - Mesh refinement
      - Insulation defect
      - Current densities (J#sub[r], J#sub[d], J#sub[t])
      - Per-unit-length capacitance
      - Frequency effects
    ],
    [
      #block(fill: light, radius: 5pt, inset: 10pt, width: 100%)[
        *§2 #sym.dot.c Magnetoquasistatic Analysis*
        #set text(size: 13pt)
        - a--v formulation & BCs
        - Magnetic flux density & current density
        - Joule losses
        - AC resistance / skin effect
        - Inductance (two methods)
      ]
      #v(0.3cm)
      #block(fill: light, radius: 5pt, inset: 10pt, width: 100%)[
        *§3 #sym.dot.c Coupled Magneto-Thermal*
        #set text(size: 13pt)
        - Heat equation & coupling
        - Temperature field
        - Nonlinear $sigma$(T) case
        - Frequency thermal
      ]
    ]
  )
  #v(0.2cm)
  #note(color: green, title: "Setup")[
    3-phase subsea cable #sym.dot.c Gmsh + GetDP ONELAB #sym.dot.c 2D cross-section #sym.dot.c f = 50 Hz #sym.dot.c I = 1 A peak #sym.dot.c V#sub[LL] = 3 kV
  ]
]

// ## Context ##################################################
#slide(title: "Context -- Application & Standards")[
  #grid(columns: (1fr, 1fr), row-gutter: 0.4cm, column-gutter: 0.5cm,
    align(center, image("../docs/image003.png", height: 4.3cm)),
    align(center, image("../docs/image004.png", height: 4.3cm)),
    align(center, image("../docs/image001.png", height: 4.3cm)),
    align(center, image("../docs/image002.png", height: 4.3cm)),
  )
]

// ═══════════════════════════════════════════════════════════════
#include "section1.typ"
#include "section2.typ"
#include "section3.typ"
