// Magnetoquasistatic (a-v) analysis.
//
// Solves for the magnetic vector potential a and the per-region electric scalar
// potential gradient ur (one global DoF per conducting region).
//
// All massive conductors (phase copper + armour/shield when present) are placed in
// DomainC_Mag.  Phase conductors carry imposed balanced three-phase currents (via
// the Current constraint).  Passive conductors (armour) have zero voltage drop so
// that eddy currents circulate freely (via the Voltage constraint set to 0).
//
// The a-v formulation follows tutorial 07 (busbar).  The weak form reads:
//   (nu curl a, curl a')         in Domain_Mag
//   (sigma d_t a, a')            in DomainC_Mag  -- eddy-current term
//   (sigma ur/CoefGeo, a')       in DomainC_Mag  -- circuit coupling
//   (sigma d_t a, ur')           in DomainC_Mag  -- dual equation
//   (sigma ur/CoefGeo, ur')      in DomainC_Mag  -- dual equation
//   GlobalTerm: Ic * Sign(CoefGeo) against Uc   -- links voltage and current
//
// CoefGeo = 1 for a planar 2D model (one metre per-unit-length).
//
// Derived quantities:
//   j  = -sigma * (d_t a + ur/CoefGeo)   current density in conductors
//   P  = 0.5 * sigma * |d_t a + ur/CoefGeo|^2   time-averaged Joule loss density
//   R  = -Re[Uc/Ic]   AC resistance per unit length  [Ohm/m]
//   L  = -Im[Uc/Ic] / omega               inductance per unit length  [H/m]
//
// Analytic references (from generated_common.pro):
//   RdcCopper   = 1 / (sigma_Cu * pi * r_c^2)   DC resistance [Ohm/m]
//   SkinDepthCopper = sqrt(2 / (omega * mu0 * sigma_Cu))   skin depth [m]

FunctionSpace {

  // Magnetic vector potential a (out-of-plane, 2-D perpendicular form).
  { Name Hcurl_a_Mag_2D; Type Form1P;
    BasisFunction {
      { Name se; NameOfCoef ae; Function BF_PerpendicularEdge;
        Support Domain_Mag; Entity NodesOf[All]; }
    }
    Constraint {
      { NameOfCoef ae; EntityType NodesOf;
        NameOfConstraint MagneticVectorPotential; }
    }
  }

  // Electric scalar potential gradient ur (one DoF per conducting region).
  // Voltage is the AliasOf (test function in the weak form).
  // Current is the AssociatedWith (energy dual).
  { Name Hcurl_u_Mag_2D; Type Form1P;
    BasisFunction {
      { Name sr; NameOfCoef ur; Function BF_RegionZ;
        Support DomainC_Mag; Entity DomainC_Mag; }
    }
    GlobalQuantity {
      { Name Voltage; Type AliasOf;        NameOfCoef ur; }
      { Name Current; Type AssociatedWith; NameOfCoef ur; }
    }
    Constraint {
      { NameOfCoef Voltage; EntityType Region; NameOfConstraint Voltage; }
      { NameOfCoef Current; EntityType Region; NameOfConstraint Current; }
    }
  }

}

Formulation {

  { Name MQS_av_2D; Type FemEquation;
    Quantity {
      { Name a;  Type Local;  NameOfSpace Hcurl_a_Mag_2D; }
      { Name ur; Type Local;  NameOfSpace Hcurl_u_Mag_2D; }
      { Name Uc; Type Global; NameOfSpace Hcurl_u_Mag_2D[Voltage]; }
      { Name Ic; Type Global; NameOfSpace Hcurl_u_Mag_2D[Current]; }
    }
    Equation {
      // Ampere: curl(nu curl a) contributes to the stiffness matrix
      Galerkin { [ nu[] * Dof{d a}, {d a} ];
        In Domain_Mag; Jacobian Vol; Integration I1; }
      // Eddy-current term: sigma * d_t(a) in all conducting regions
      Galerkin { DtDof [ sigma_e[] * Dof{a}, {a} ];
        In DomainC_Mag; Jacobian Vol; Integration I1; }
      // Circuit coupling: sigma * ur/CoefGeo acts like grad v in the conductor
      Galerkin { [ sigma_e[] * Dof{ur} / CoefGeo[], {a} ];
        In DomainC_Mag; Jacobian Vol; Integration I1; }
      // Dual equations for the ur DoF (voltage/current relation)
      Galerkin { DtDof [ sigma_e[] * Dof{a}, {ur} ];
        In DomainC_Mag; Jacobian Vol; Integration I1; }
      Galerkin { [ sigma_e[] * Dof{ur} / CoefGeo[], {ur} ];
        In DomainC_Mag; Jacobian Vol; Integration I1; }
      // GlobalTerm closes the circuit equation linking Uc and Ic
      GlobalTerm { [ Dof{Ic} * Sign[CoefGeo[]], {Uc} ]; In DomainC_Mag; }
    }
  }

}

Resolution {

  { Name Magnetoquasistatics;
    System {
      { Name Sys_Mag; NameOfFormulation MQS_av_2D;
        Type Complex; Frequency Freq; }
    }
    Operation {
      CreateDir["res"];
      InitSolution[Sys_Mag];
      Generate[Sys_Mag]; Solve[Sys_Mag]; SaveSolution[Sys_Mag];
    }
  }

}

PostProcessing {

  { Name MQS_av_2D; NameOfFormulation MQS_av_2D;
    PostQuantity {

      // Flux lines: z-component of a
      { Name az; Value {
          Term { [ CompZ[{a}] ]; In Domain_Mag; Jacobian Vol; }
        }
      }

      // Magnetic flux density B = curl a
      { Name b; Value {
          Term { [ {d a} ]; In Domain_Mag; Jacobian Vol; }
        }
      }
      { Name norm_b; Value {
          Term { [ Norm[{d a}] ]; In Domain_Mag; Jacobian Vol; }
        }
      }

      // Current density j = -sigma * (d_t a + ur/CoefGeo)
      { Name j; Value {
          Term { [ -sigma_e[] * (Dt[{a}] + {ur} / CoefGeo[]) ];
            In DomainC_Mag; Jacobian Vol; }
        }
      }
      { Name jz; Value {
          Term { [ CompZ[-sigma_e[] * (Dt[{a}] + {ur} / CoefGeo[])] ];
            In DomainC_Mag; Jacobian Vol; }
        }
      }
      { Name norm_j; Value {
          Term { [ Norm[-sigma_e[] * (Dt[{a}] + {ur} / CoefGeo[])] ];
            In DomainC_Mag; Jacobian Vol; }
        }
      }

      // Time-averaged Joule loss density: Q = 0.5 * sigma * |e|^2
      { Name local_losses; Value {
          Term { [ 0.5 * sigma_e[] * SquNorm[Dt[{a}] + {ur} / CoefGeo[]] ];
            In DomainC_Mag; Jacobian Vol; }
        }
      }
      { Name global_losses; Value {
          Integral { [ 0.5 * sigma_e[] * SquNorm[Dt[{a}] + {ur} / CoefGeo[]] ];
            In DomainC_Mag; Jacobian Vol; Integration I1; }
        }
      }

      // Per-region voltage (z-component of grad v per unit length) and current
      { Name U; Value { Term { [ {Uc} ]; In DomainC_Mag; } } }
      { Name I; Value { Term { [ {Ic} ]; In DomainC_Mag; } } }

      // AC resistance per unit length R = -Re[U/I]  (sign from source convention)
      { Name R; Value { Term { [ -Re[{Uc}/{Ic}] ]; In DomainC_Mag; } } }

      // Inductance per unit length L = -Im[U/I] / omega
      { Name L; Value { Term { [ -Im[{Uc}/{Ic}] / (2*Pi*Freq) ]; In DomainC_Mag; } } }

      // Total magnetic energy W_m = 0.5 * int( nu * |B|^2 )
      { Name MagneticEnergy; Value {
          Integral {
            [ 0.5 * nu[] * SquNorm[{d a}] ];
            In Domain_Mag; Jacobian Vol; Integration I1;
          }
        }
      }

      // Imposed phase-A current phasor (stored for energy-based inductance below)
      { Name I0_imposed; Value {
          Term { Type Global; [ I * F_Cos_wt_p[]{2*Pi*Freq, Pa} ]; In Copper_0; }
        }
      }

      // Inductance from magnetic energy: L = 2*Wm / (3*I^2)
      // Factor 3 for three balanced phases, analogous to the capacitance formula.
      { Name L_from_Energy; Value {
          Term { Type Global; [ 2*$Wm / (3*SquNorm[$current]) ]; In DomainDummy; }
        }
      }

      // Analytic DC resistance and skin depth for reference
      { Name Rdc_ref; Value {
          Term { Type Global; [ RdcCopper ]; In DomainDummy; }
        }
      }
      { Name SkinDepth_ref; Value {
          Term { Type Global; [ SkinDepthCopper ]; In DomainDummy; }
        }
      }

      // R_AC / R_DC ratio (requires $R_ac stored from the R print below)
      { Name R_ratio; Value {
          Term { Type Global; [ $R_ac / RdcCopper ]; In DomainDummy; }
        }
      }

    }
  }

}

PostOperation {

  { Name Post_Mag; NameOfPostProcessing MQS_av_2D;
    Operation {

      // Field maps
      Print[ az,     OnElementsOf Domain_Mag,  Name "Az [Wb/m]",   File "res/az.pos"       ];
      Print[ b,      OnElementsOf Domain_Mag,  Name "B [T]",        File "res/b.pos"        ];
      Print[ norm_b, OnElementsOf Domain_Mag,  Name "|B| [T]",      File "res/bm.pos"       ];
      Print[ jz,     OnElementsOf DomainC_Mag, Name "Jz [A/m^2]",  File "res/jz_inds.pos"  ];
      Print[ norm_j, OnElementsOf DomainC_Mag, Name "|J| [A/m^2]", File "res/jm.pos"       ];

      // Joule losses by region group
      Print[ global_losses[DomainC_Mag], OnGlobal, Format Table,
        SendToServer "{01Global MAG results/0Total Joule losses [W/m]",
        Units "W/m", File "res/losses_total.dat" ];
      Print[ global_losses[PhaseConductors], OnGlobal, Format Table,
        SendToServer "{01Global MAG results/1Phase-conductor losses [W/m]",
        Units "W/m", File "res/losses_phase.dat" ];
      Print[ global_losses[PassiveConductors], OnGlobal, Format Table,
        SendToServer "{01Global MAG results/2Passive-conductor losses [W/m]",
        Units "W/m", File "res/losses_passive.dat" ];

      // Per-region voltage and current (one row per region)
      Print[ U, OnRegion DomainC_Mag, Format RegionTable,
        SendToServer "{01Global MAG results/3Voltage [V/m]",
        Units "V/m", File "res/Uinds.dat" ];
      Print[ I, OnRegion DomainC_Mag, Format RegionTable,
        SendToServer "{01Global MAG results/3Current [A]",
        Units "A", File "res/Iinds.dat" ];

      // AC resistance and inductance per unit length for each phase conductor.
      // Phase-A R is also stored in $R_ac for the R_AC/R_DC ratio below.
      Print[ R, OnRegion Copper_0, Format Table, StoreInVariable $R_ac, File "" ];
      Print[ R, OnRegion PhaseConductors, Format RegionTable,
        SendToServer "{01Global MAG results/4AC resistance [Ohm/m]",
        Units "Ohm/m", File "res/Rinds.dat" ];
      Print[ L, OnRegion PhaseConductors, Format RegionTable,
        SendToServer "{01Global MAG results/5Inductance [H/m]",
        Units "H/m", File "res/Linds.dat" ];

      // Analytic references and AC/DC ratio
      Print[ Rdc_ref, OnRegion DomainDummy, Format Table,
        SendToServer "{01Global MAG results/6DC resistance ref [Ohm/m]",
        Units "Ohm/m", File "res/Rdc.dat" ];
      Print[ SkinDepth_ref, OnRegion DomainDummy, Format Table,
        SendToServer "{01Global MAG results/6Skin depth [m]",
        Units "m", File "res/skin_depth.dat" ];
      Print[ R_ratio, OnRegion DomainDummy, Format Table,
        SendToServer "{01Global MAG results/7R_AC / R_DC",
        File "res/R_ratio.dat" ];

      // Magnetic energy and energy-based inductance
      Print[ MagneticEnergy[Domain_Mag], OnGlobal, Format Table,
        StoreInVariable $Wm,
        SendToServer "{01Global MAG results/8Magnetic energy [J/m]",
        File "res/MagEnergy.dat" ];
      Print[ I0_imposed, OnRegion Copper_0, Format Table,
        StoreInVariable $current,
        SendToServer "{01Global MAG results/8Current ref [A]",
        Units "A", File "res/I.dat" ];
      Print[ L_from_Energy, OnRegion DomainDummy, Format Table,
        SendToServer "{01Global MAG results/9Inductance from energy [H/m]",
        Units "H/m", File "res/L.dat" ];

    }
  }

}
