// Coupled magneto-thermal analysis.
//
// Solves the frequency-domain magnetoquasistatic problem (a-v formulation, same as
// LoVe_Magnetoquasistatics.pro) and a steady-state thermal conduction problem coupled
// through the Joule losses.
//
// Coupling mechanism (Picard / fixed-point iteration):
//   1. Solve magnetic problem at current temperature T => get a, ur
//   2. Compute time-averaged Joule loss density Q = 0.5 * sigma(T) * |d_t a + ur|^2
//   3. Solve thermal problem with Q as heat source => update T
//   4. Repeat until the magnetic residual satisfies the convergence criterion.
//
// The thermal problem is governed by steady-state heat conduction:
//   -div(kappa * grad T) = Q     in Domain_The
// with a Robin (convective) boundary condition at the outer water boundary:
//   kappa * d_n T + h*(T - T0) = 0   on Sur_Robin_The
//
// When NonLinearThermal == 0 (linear), sigma is temperature-independent and a
// single magnetic + thermal solve suffices (no iteration needed).
//
// The <a>[...] syntax evaluates the enclosed expression in complex arithmetic even
// though the thermal formulation is real-valued.  This is required to get the
// correct squared modulus of the complex phasor fields.
//
// Reference: project2026.pdf section 3; tutorial 07 (busbar coupled problem).

FunctionSpace {

  // Magnetic vector potential (identical to the MQS-only analysis)
  { Name Hcurl_a_MagThe_2D; Type Form1P;
    BasisFunction {
      { Name se; NameOfCoef ae; Function BF_PerpendicularEdge;
        Support Domain_Mag; Entity NodesOf[All]; }
    }
    Constraint {
      { NameOfCoef ae; EntityType NodesOf;
        NameOfConstraint MagneticVectorPotential; }
    }
  }

  // Electric scalar potential gradient (one DoF per conducting region)
  { Name Hcurl_u_MagThe_2D; Type Form1P;
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

  // Temperature field (nodal Lagrange basis, real-valued)
  { Name Hgrad_T_The; Type Form0;
    BasisFunction {
      { Name sn; NameOfCoef Tn; Function BF_Node;
        Support Region[{Domain_The, Sur_Robin_The}]; Entity NodesOf[All]; }
    }
    Constraint {
      { NameOfCoef Tn; EntityType NodesOf; NameOfConstraint T_The; }
    }
  }

}

Formulation {

  // Magnetoquasistatic a-v formulation with optional temperature-dependent sigma.
  // sigma(T) = sigmaT[{T}] when NonLinearThermal == 1 (temperature read from the
  // thermal FunctionSpace via the <T>[...] real-evaluation operator).
  { Name MQS_T_a_2D; Type FemEquation;
    Quantity {
      { Name a;  Type Local;  NameOfSpace Hcurl_a_MagThe_2D; }
      { Name ur; Type Local;  NameOfSpace Hcurl_u_MagThe_2D; }
      { Name Uc; Type Global; NameOfSpace Hcurl_u_MagThe_2D[Voltage]; }
      { Name Ic; Type Global; NameOfSpace Hcurl_u_MagThe_2D[Current]; }
      // T declared here to access the thermal solution inside the magnetic formulation
      { Name T; Type Local; NameOfSpace Hgrad_T_The; }
    }
    Equation {
      Galerkin { [ nu[] * Dof{d a}, {d a} ];
        In Domain_Mag; Jacobian Vol; Integration I1; }

      If(NonLinearThermal)
        // Temperature-dependent conductivity: <T>[{T}] evaluates T in real arithmetic
        Galerkin { DtDof [ sigmaT[<T>[{T}]] * Dof{a}, {a} ];
          In DomainC_Mag; Jacobian Vol; Integration I1; }
        Galerkin { [ sigmaT[<T>[{T}]] * Dof{ur} / CoefGeo[], {a} ];
          In DomainC_Mag; Jacobian Vol; Integration I1; }
        Galerkin { DtDof [ sigmaT[<T>[{T}]] * Dof{a}, {ur} ];
          In DomainC_Mag; Jacobian Vol; Integration I1; }
        Galerkin { [ sigmaT[<T>[{T}]] * Dof{ur} / CoefGeo[], {ur} ];
          In DomainC_Mag; Jacobian Vol; Integration I1; }
      Else
        Galerkin { DtDof [ sigma_e[] * Dof{a}, {a} ];
          In DomainC_Mag; Jacobian Vol; Integration I1; }
        Galerkin { [ sigma_e[] * Dof{ur} / CoefGeo[], {a} ];
          In DomainC_Mag; Jacobian Vol; Integration I1; }
        Galerkin { DtDof [ sigma_e[] * Dof{a}, {ur} ];
          In DomainC_Mag; Jacobian Vol; Integration I1; }
        Galerkin { [ sigma_e[] * Dof{ur} / CoefGeo[], {ur} ];
          In DomainC_Mag; Jacobian Vol; Integration I1; }
      EndIf

      GlobalTerm { [ Dof{Ic} * Sign[CoefGeo[]], {Uc} ]; In DomainC_Mag; }
    }
  }

  // Steady-state heat conduction with Joule loss source and convective BC.
  // The <a>[...] operator forces complex arithmetic when evaluating the magnetic
  // phasor fields inside this otherwise real-valued formulation.
  { Name Thermal_T; Type FemEquation;
    Quantity {
      { Name T;  Type Local; NameOfSpace Hgrad_T_The; }
      { Name a;  Type Local; NameOfSpace Hcurl_a_MagThe_2D; }
      { Name ur; Type Local; NameOfSpace Hcurl_u_MagThe_2D; }
    }
    Equation {
      // Heat conduction: int( kappa * grad T . grad T' )
      Galerkin { [ kappa[] * Dof{d T}, {d T} ];
        In Domain_The; Jacobian Vol; Integration I1; }

      // Robin BC: h*(T - T0) on the outer water boundary
      Galerkin { [ h * Dof{T}, {T} ];
        In Sur_Robin_The; Jacobian Sur; Integration I1; }
      Galerkin { [ -h * T0, {T} ];
        In Sur_Robin_The; Jacobian Sur; Integration I1; }

      // Joule heat source: Q = 0.5 * sigma * |d_t a + ur/CoefGeo|^2
      // <a>[...] evaluates the magnetic fields in complex arithmetic.
      If(NonLinearThermal)
        Galerkin { [ -0.5 * sigmaT[{T}] *
            <a>[SquNorm[Dt[{a}] + {ur} / CoefGeo[]]], {T} ];
          In DomainC_Mag; Jacobian Vol; Integration I1; }
      Else
        Galerkin { [ -0.5 * sigma_e[] *
            <a>[SquNorm[Dt[{a}] + {ur} / CoefGeo[]]], {T} ];
          In DomainC_Mag; Jacobian Vol; Integration I1; }
      EndIf
    }
  }

}

Resolution {

  { Name Magnetothermal;
    System {
      { Name Sys_MagThe; NameOfFormulation MQS_T_a_2D;
        Type Complex; Frequency Freq; }
      { Name Sys_The; NameOfFormulation Thermal_T; }
    }
    Operation {
      CreateDir["res"];

      // Initialise temperature to T0 everywhere in Domain_The
      InitSolution[Sys_The];

      // First solve: magnetic at initial temperature, then thermal
      Generate[Sys_MagThe]; Solve[Sys_MagThe];
      Generate[Sys_The];    Solve[Sys_The];

      If(NonLinearThermal)
        // Re-generate with updated temperature (sigma(T) changed) and get residual
        Generate[Sys_MagThe]; GetResidual[Sys_MagThe, $res0];
        Evaluate[ $res = $res0, $iter = 0 ];
        Print[{$iter, $res, $res / $res0},
          Format "Residual %03g: abs %14.12e rel %14.12e"];

        While[$res > NLTolAbs && $res / $res0 > NLTolRel &&
          $res / $res0 <= 1 && $iter < NLIterMax]{
          Solve[Sys_MagThe];
          Generate[Sys_The]; Solve[Sys_The];
          Generate[Sys_MagThe]; GetResidual[Sys_MagThe, $res];
          Evaluate[ $iter = $iter + 1 ];
          Print[{$iter, $res, $res / $res0},
            Format "Residual %03g: abs %14.12e rel %14.12e"];
        }
      EndIf

      SaveSolution[Sys_MagThe];
      SaveSolution[Sys_The];
    }
  }

}

PostProcessing {

  // Magnetic quantities from the coupled solve
  { Name MagThe; NameOfFormulation MQS_T_a_2D;
    Quantity {

      { Name az; Value {
          Term { [ CompZ[{a}] ]; In Domain_Mag; Jacobian Vol; }
        }
      }
      { Name b; Value {
          Term { [ {d a} ]; In Domain_Mag; Jacobian Vol; }
        }
      }
      { Name norm_b; Value {
          Term { [ Norm[{d a}] ]; In Domain_Mag; Jacobian Vol; }
        }
      }

      { Name j; Value {
          If(NonLinearThermal)
            Term { [ -sigmaT[<T>[{T}]] * (Dt[{a}] + {ur} / CoefGeo[]) ];
              In DomainC_Mag; Jacobian Vol; }
          Else
            Term { [ -sigma_e[] * (Dt[{a}] + {ur} / CoefGeo[]) ];
              In DomainC_Mag; Jacobian Vol; }
          EndIf
        }
      }
      { Name norm_j; Value {
          If(NonLinearThermal)
            Term { [ Norm[-sigmaT[<T>[{T}]] * (Dt[{a}] + {ur} / CoefGeo[])] ];
              In DomainC_Mag; Jacobian Vol; }
          Else
            Term { [ Norm[-sigma_e[] * (Dt[{a}] + {ur} / CoefGeo[])] ];
              In DomainC_Mag; Jacobian Vol; }
          EndIf
        }
      }

      { Name local_losses; Value {
          If(NonLinearThermal)
            Term { [ 0.5 * sigmaT[<T>[{T}]] *
                SquNorm[Dt[{a}] + {ur} / CoefGeo[]] ];
              In DomainC_Mag; Jacobian Vol; }
          Else
            Term { [ 0.5 * sigma_e[] * SquNorm[Dt[{a}] + {ur} / CoefGeo[]] ];
              In DomainC_Mag; Jacobian Vol; }
          EndIf
        }
      }
      { Name global_losses; Value {
          If(NonLinearThermal)
            Integral { [ 0.5 * sigmaT[<T>[{T}]] *
                SquNorm[Dt[{a}] + {ur} / CoefGeo[]] ];
              In DomainC_Mag; Jacobian Vol; Integration I1; }
          Else
            Integral { [ 0.5 * sigma_e[] * SquNorm[Dt[{a}] + {ur} / CoefGeo[]] ];
              In DomainC_Mag; Jacobian Vol; Integration I1; }
          EndIf
        }
      }

      { Name U; Value { Term { [ {Uc} ]; In DomainC_Mag; } } }
      { Name I; Value { Term { [ {Ic} ]; In DomainC_Mag; } } }
      { Name R; Value { Term { [ -Re[{Uc}/{Ic}] ]; In DomainC_Mag; } } }
      { Name L; Value { Term { [ -Im[{Uc}/{Ic}] / (2*Pi*Freq) ]; In DomainC_Mag; } } }

    }
  }

  // Thermal quantities
  { Name The; NameOfFormulation Thermal_T;
    Quantity {

      { Name T; Value {
          Term { [ {T} ]; In Domain_The; Jacobian Vol; }
        }
      }

      // Heat source Q used in the thermal solve (for visualisation)
      { Name heat_source; Value {
          If(NonLinearThermal)
            Term { [ 0.5 * sigmaT[{T}] *
                <a>[SquNorm[Dt[{a}] + {ur} / CoefGeo[]]] ];
              In DomainC_Mag; Jacobian Vol; }
          Else
            Term { [ 0.5 * sigma_e[] *
                <a>[SquNorm[Dt[{a}] + {ur} / CoefGeo[]]] ];
              In DomainC_Mag; Jacobian Vol; }
          EndIf
        }
      }

    }
  }

}

PostOperation {

  // Magnetic field maps and global scalars from the coupled solve
  { Name Post_MagTher; NameOfPostProcessing MagThe;
    Operation {
      Print[ az,          OnElementsOf Domain_Mag,  Name "Az [Wb/m]",   File "res/mt_az.pos"            ];
      Print[ norm_b,      OnElementsOf Domain_Mag,  Name "|B| [T]",      File "res/mt_bm.pos"            ];
      Print[ norm_j,      OnElementsOf DomainC_Mag, Name "|J| [A/m^2]", File "res/mt_jm.pos"            ];
      Print[ local_losses,OnElementsOf DomainC_Mag, Name "Q [W/m^3]",   File "res/mt_losses_density.pos"];

      Print[ global_losses[DomainC_Mag], OnGlobal, Format Table,
        SendToServer "{01Global M-T results/0Total losses [W/m]",
        Units "W/m", File "res/mt_losses_total.dat" ];
      Print[ R, OnRegion PhaseConductors, Format RegionTable,
        SendToServer "{01Global M-T results/1Resistance [Ohm/m]",
        Units "Ohm/m", File "res/mt_Rinds.dat" ];
      Print[ L, OnRegion PhaseConductors, Format RegionTable,
        SendToServer "{01Global M-T results/2Inductance [H/m]",
        Units "H/m", File "res/mt_Linds.dat" ];
      Print[ U, OnRegion DomainC_Mag, Format RegionTable,
        SendToServer "{01Global M-T results/3Voltage [V/m]",
        Units "V/m", File "res/mt_Uinds.dat" ];
      Print[ I, OnRegion DomainC_Mag, Format RegionTable,
        SendToServer "{01Global M-T results/3Current [A]",
        Units "A", File "res/mt_Iinds.dat" ];
    }
  }

  // Temperature field and heat source distribution
  { Name Post_Thermal; NameOfPostProcessing The;
    Operation {
      Print[ T,           OnElementsOf Domain_The,  Name "T [degC]",    File "res/temperature.pos"  ];
      Print[ heat_source, OnElementsOf DomainC_Mag, Name "Q [W/m^3]",   File "res/heat_source.pos"  ];
    }
  }

}
