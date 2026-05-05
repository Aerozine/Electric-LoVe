// Electrodynamic (frequency-domain) analysis.
//
// Solves for the electric scalar potential v across the full cable cross-section
// including the seawater environment.  From v, the code computes:
//   E = -grad v           electric field
//   D = eps E             electric displacement
//   Jr = sigma E          resistive current density
//   Jd = eps * d(E)/dt    displacement current density  (= i*omega*eps*E in freq domain)
//   Jt = Jr + Jd          total current density
//
// The per-phase capacitance is extracted from the total stored electric energy:
//   C = 2 * W_e / (3 * V0^2)
// The factor 3 accounts for the equal energy contribution of the three balanced phases.
// This is compared with the analytic coaxial estimate CAnalytic (see generated_common.pro).

FunctionSpace {

  { Name Hgrad_v_Ele; Type Form0;
    BasisFunction {
      { Name sn; NameOfCoef vn; Function BF_Node;
        Support Domain_Ele; Entity NodesOf[All]; }
    }
    Constraint {
      { NameOfCoef vn; EntityType NodesOf;
        NameOfConstraint ElectricScalarPotential; }
    }
  }

}

Formulation {

  { Name Electrodynamics_v; Type FemEquation;
    Quantity {
      { Name v; Type Local; NameOfSpace Hgrad_v_Ele; }
    }
    Equation {
      // Resistive term: int( sigma * grad(v) . grad(v') )
      Galerkin { [ sigma_e[] * Dof{d v}, {d v} ];
        In Domain_Ele; Jacobian Vol; Integration I1; }
      // Capacitive term: int( eps * d(grad v)/dt . grad(v') )
      // In frequency domain DtDof introduces the factor i*omega.
      Galerkin { DtDof [ epsilon[] * Dof{d v}, {d v} ];
        In Domain_Ele; Jacobian Vol; Integration I1; }
    }
  }

}

Resolution {

  { Name Electrodynamics;
    System {
      { Name Sys_Ele; NameOfFormulation Electrodynamics_v;
        Type Complex; Frequency Freq; }
    }
    Operation {
      CreateDir["res"];
      Generate[Sys_Ele]; Solve[Sys_Ele]; SaveSolution[Sys_Ele];
    }
  }

}

PostProcessing {

  { Name EleDyn_v; NameOfFormulation Electrodynamics_v;
    Quantity {

      { Name v; Value {
          Term { [ {v} ]; In Domain_Ele; Jacobian Vol; }
        }
      }

      { Name e; Value {
          Term { [ -{d v} ]; In Domain_Ele; Jacobian Vol; }
        }
      }
      { Name norm_e; Value {
          Term { [ Norm[-{d v}] ]; In Domain_Ele; Jacobian Vol; }
        }
      }

      { Name d; Value {
          Term { [ -epsilon[] * {d v} ]; In Domain_Ele; Jacobian Vol; }
        }
      }
      { Name norm_d; Value {
          Term { [ Norm[-epsilon[] * {d v}] ]; In Domain_Ele; Jacobian Vol; }
        }
      }

      // Resistive current density Jr = sigma * E
      { Name jr; Value {
          Term { [ -sigma_e[] * {d v} ]; In Domain_Ele; Jacobian Vol; }
        }
      }
      { Name norm_jr; Value {
          Term { [ Norm[-sigma_e[] * {d v}] ]; In Domain_Ele; Jacobian Vol; }
        }
      }

      // Displacement current density Jd = eps * dE/dt = i*omega*eps*E
      { Name jd; Value {
          Term { [ Dt[-epsilon[] * {d v}] ]; In Domain_Ele; Jacobian Vol; }
        }
      }
      { Name norm_jd; Value {
          Term { [ Norm[Dt[-epsilon[] * {d v}]] ]; In Domain_Ele; Jacobian Vol; }
        }
      }

      // Total current density Jt = Jr + Jd
      { Name jt; Value {
          Term { [ -sigma_e[] * {d v} + Dt[-epsilon[] * {d v}] ]; In Domain_Ele; Jacobian Vol; }
        }
      }
      { Name norm_jt; Value {
          Term { [ Norm[-sigma_e[] * {d v} + Dt[-epsilon[] * {d v}]] ]; In Domain_Ele; Jacobian Vol; }
        }
      }

      // Total stored electric energy W_e = 0.5 * int( eps * |E|^2 )
      { Name ElectricEnergy; Value {
          Integral {
            [ 0.5 * epsilon[] * SquNorm[{d v}] ];
            In Domain_Ele; Jacobian Vol; Integration I1;
          }
        }
      }

      // Peak phasor of the imposed phase-A voltage (used to normalise capacitance)
      { Name V0_imposed; Value {
          Term { Type Global; [ V0 * F_Cos_wt_p[]{2*Pi*Freq, Pa} ]; In Copper_0; }
        }
      }

      // Per-phase capacitance from energy: C = 2*We / (3*V0^2)
      // Stored after ElectricEnergy and V0_imposed are evaluated ($We, $voltage).
      { Name C_from_Energy; Value {
          Term { Type Global; [ 2*$We / (3*SquNorm[$voltage]) ]; In DomainDummy; }
        }
      }

      // Analytic coaxial estimate for a single isolated phase (lower bound for the three-phase system)
      { Name C_analytic_ref; Value {
          Term { Type Global; [ CAnalytic ]; In DomainDummy; }
        }
      }

      // Ratio C_FE / C_analytic
      { Name C_ratio; Value {
          Term { Type Global; [ 2*$We / (3*SquNorm[$voltage]) / CAnalytic ]; In DomainDummy; }
        }
      }

    }
  }

}

PostOperation {

  { Name Post_Ele; NameOfPostProcessing EleDyn_v;
    Operation {

      // Field maps
      Print[ v,       OnElementsOf Domain_Ele, File "res/v.pos" ];
      Print[ norm_e,  OnElementsOf Domain_Ele, Name "|E| [V/m]",      File "res/em.pos"  ];
      Print[ norm_d,  OnElementsOf Domain_Ele, Name "|D| [C/m^2]",    File "res/dm.pos"  ];
      Print[ e,       OnElementsOf Domain_Ele, Name "E [V/m]",         File "res/e.pos"   ];
      Print[ jr,      OnElementsOf Domain_Ele, Name "Jr [A/m^2]",      File "res/jr.pos"  ];
      Print[ norm_jr, OnElementsOf Domain_Ele, Name "|Jr| [A/m^2]",    File "res/jrm.pos" ];
      Print[ jd,      OnElementsOf Domain_Ele, Name "Jd [A/m^2]",      File "res/jd.pos"  ];
      Print[ norm_jd, OnElementsOf Domain_Ele, Name "|Jd| [A/m^2]",    File "res/jdm.pos" ];
      Print[ jt,      OnElementsOf Domain_Ele, Name "Jtot [A/m^2]",    File "res/jt.pos"  ];
      Print[ norm_jt, OnElementsOf Domain_Ele, Name "|Jtot| [A/m^2]",  File "res/jtm.pos" ];

      // Store We and V0 in runtime variables before computing derived quantities.
      Print[ ElectricEnergy[Domain_Ele], OnGlobal, Format Table,
        StoreInVariable $We,
        SendToServer "{01Global ELE results/0Electric energy [J/m]",
        File "res/energy.dat" ];
      Print[ V0_imposed, OnRegion Copper_0, Format Table,
        StoreInVariable $voltage,
        SendToServer "{01Global ELE results/0Voltage [V]",
        Units "V", File "res/U.dat" ];

      // Per-phase capacitance and comparison with analytic estimate
      Print[ C_from_Energy, OnRegion DomainDummy, Format Table,
        StoreInVariable $C1,
        SendToServer "{01Global ELE results/1Per-phase capacitance [F/m]",
        Units "F/m", File "res/C.dat" ];
      Print[ C_analytic_ref, OnRegion DomainDummy, Format Table,
        SendToServer "{01Global ELE results/2Coaxial analytic C [F/m]",
        Units "F/m", File "res/C_analytic.dat" ];
      Print[ C_ratio, OnRegion DomainDummy, Format Table,
        SendToServer "{01Global ELE results/3C_FE / C_analytic",
        File "res/C_ratio.dat" ];

    }
  }

}
