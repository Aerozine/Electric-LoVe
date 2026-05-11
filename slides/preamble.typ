// ============================================================
// preamble.typ – shared helpers, colours, data loading
// Import with: #import "preamble.typ": *
// ============================================================

// ## Colours ##################################################
#let navy   = rgb("#1a1a2e")
#let accent = rgb("#0f6e84")
#let gold   = rgb("#e8a838")
#let light  = rgb("#f0f4f8")
#let green  = rgb("#2d6a4f")
#let red    = rgb("#c1121f")

// ## Layout helpers ############################################
#let slide(title: "", body) = {
  pagebreak()
  block(width: 100%, height: 100%, breakable: false, {
    place(top + left, dx: -1.5cm, dy: -1.2cm,
      rect(width: 100% + 3cm, height: 1.9cm + 1.2cm, fill: navy,
        pad(x: 0.6cm + 1.5cm, y: 0.35cm + 1.2cm,
          grid(columns: (1fr, auto), column-gutter: 0.4cm,
            text(size: 19pt, fill: white, weight: "bold", title),
            align(horizon, image("ulgfsa.svg", height: 1.2cm))
          )
        )
      )
    )
    pad(x: 0.5cm, top: 1.9cm + 0.3cm, body)
  })
}

#let title-slide(title, subtitle, author) = {
  page(margin: 0pt,
    block(width: 100%, height: 100%, breakable: false, fill: navy, {
      pad(x: 2cm, y: 2.7cm, {
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
  )
}

#let section-slide(n, title) = {
  pagebreak()
  page(margin: 0pt,
    block(width: 100%, height: 100%, breakable: false, fill: rgb("#16213e"), {
      pad(x: 3cm, y: 3cm, {
        text(size: 14pt, fill: gold, weight: "bold", "Section " + n)
        v(0.3cm)
        text(size: 27pt, fill: white, weight: "bold", title)
      })
    })
  )
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

#let styled-table(..args) = table(
  fill: (x, y) => if y == 0 { navy } else if calc.odd(y) { light } else { white },
  inset: 6pt, ..args
)

// ## Data parsers ##############################################
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

#let toml-val(key) = {
  let result = 0.0
  for line in read("../cable.toml").split("\n") {
    let t = line.trim()
    if t.starts-with("#") or t == "" { continue }
    let parts = t.split("=")
    if parts.len() >= 2 and parts.at(0).trim() == key {
      let val_str = parts.at(1).trim().split("#").at(0).trim()
      result = float(val_str)
      break
    }
  }
  result
}

// ## Load all simulation data ###################################
#let C_fem  = dat-s("../res/C.dat")
#let C_an   = dat-s("../res/C_analytic.dat")
#let C_rat  = dat-s("../res/C_ratio.dat")
#let W_e    = dat-s("../res/energy.dat")
#let V0_val = dat-s("../res/U.dat")
#let E_max  = dat-s("../res/em_max.dat")
#let D_max  = dat-s("../res/dm_max.dat")
#let Jr_max = dat-s("../res/jrm_max.dat")
#let Jd_max = dat-s("../res/jdm_max.dat")
#let Jt_max = dat-s("../res/jtm_max.dat")
#let R_dat  = dat-r("../res/Rinds.dat")
#let R_dc   = dat-s("../res/Rdc.dat")
#let R_rat  = dat-s("../res/R_ratio.dat")
#let skin_depth  = dat-s("../res/skin_depth.dat")
#let P_tot  = dat-s("../res/losses_total.dat")
#let P_ph   = dat-s("../res/losses_phase.dat")
#let P_pas  = dat-s("../res/losses_passive.dat")
#let L_dat  = dat-r("../res/Linds.dat")
#let L_en   = dat-s("../res/L.dat")
#let W_m    = dat-s("../res/MagEnergy.dat")
#let B_max  = dat-s("../res/bm_max.dat")
#let J_max  = dat-s("../res/jm_max.dat")
#let Pmt    = dat-s("../res/mt_losses_total.dat")
#let T_min  = dat-s("../res/t_min.dat")
#let T_max  = dat-s("../res/t_max.dat")
#let Bmt_mx = dat-s("../res/mt_bm_max.dat")
#let Jmt_mx = dat-s("../res/mt_jm_max.dat")

// ## Number formatting #########################################
#let eng(x, unit: "") = {
  if calc.abs(x) == 0.0 { return [0 #unit] }
  let e = calc.floor(calc.log(calc.abs(x), base: 10) / 3) * 3
  let m = x / calc.pow(10.0, e)
  let px = if e == 12 { "T" } else if e == 9 { "G" } else if e == 6 { "M" }
    else if e == 3 { "k" } else if e == 0 { "" } else if e == -3 { "m" }
    else if e == -6 { "µ" } else if e == -9 { "n" } else if e == -12 { "p" }
    else { "×10^(" + str(e) + ")" }
  [#str(calc.round(m, digits: 3)) #px#unit]
}
#let f(x, d: 3) = {
  let digits = if d > 3 { 3 } else { d }
  str(calc.round(x, digits: digits))
}

// ## Geometry from cable.toml ##################################
#let t_cond_d    = toml-val("conductor_diameter")
#let t_semi_od   = toml-val("semiconductor_outer_diameter")
#let t_ins_od    = toml-val("insulation_outer_diameter")
#let t_fibre_od  = toml-val("fibre_unit_outer_diameter")
#let t_layup_od  = toml-val("layup_outer_diameter")
#let t_sheath_od = toml-val("outer_sheath_outer_diameter")
#let t_env_d     = toml-val("environment_diameter")
#let t_freq      = toml-val("frequency")
#let t_current   = toml-val("current")
#let t_Vll       = toml-val("line_voltage_rms")
#let t_h_cond    = toml-val("conductor_size")
#let t_h_semi    = toml-val("semiconductor_size")
#let t_h_ins     = toml-val("insulation_size")
#let t_T_amb     = toml-val("ambient_temperature")

// ## Shortcuts #################################################
#let R0 = R_dat.at(0).at(0)
#let L0 = L_dat.at(0).at(0)
