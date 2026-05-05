// Main entry point for the LoVe-in-HV cable model.
// Selects the analysis type and delegates to the appropriate sub-file.
// All geometry/material constants come from generated_common.pro (written by generator.py).

DefineConstant[
  Flag_AnalysisType = {0,
    Choices{
      0="Electrodynamic",
      1="Magnetoquasistatic",
      2="Magneto-thermal"
    },
    Name "{00FE param./Type of analysis", Highlight "ForestGreen",
    ServerAction Str["Reset",
      StrCat["GetDP/1ResolutionChoices", ",", "GetDP/2PostOperationChoices"]] }
];

Function {
  Resolution_name()    = Str["Electrodynamics",  "Magnetoquasistatics", "Magnetothermal"];
  PostOperation_name() = Str["Post_Ele",          "Post_Mag",           "Post_MagTher, Post_Thermal"];
}

DefineConstant[
  r_ = {Str[Resolution_name(Flag_AnalysisType)],    Name "GetDP/1ResolutionChoices"}
  c_ = {"-solve -v2 -pos",                           Name "GetDP/9ComputeCommand"}
  p_ = {Str[PostOperation_name(Flag_AnalysisType)], Name "GetDP/2PostOperationChoices"}
];

Include "generated_common.pro";
Include "Lib_LoVe_Numerics.pro";

// Shared constraints used by all three analysis types.
Constraint {

  // Electrodynamic: Dirichlet on the electric scalar potential v.
  // Phase conductors are equipotential at the imposed phase voltage.
  // Passive conductors (armour) are grounded.  Outer boundary is grounded.
  { Name ElectricScalarPotential;
    Case {
      { Region Copper_0; Value V0; TimeFunction F_Cos_wt_p[]{2*Pi*Freq, Pa}; }
      { Region Copper_1; Value V0; TimeFunction F_Cos_wt_p[]{2*Pi*Freq, Pb}; }
      { Region Copper_2; Value V0; TimeFunction F_Cos_wt_p[]{2*Pi*Freq, Pc}; }
      { Region PassiveConductors; Value 0; }
      { Region Sur_Dirichlet_Ele; Value 0; }
    }
  }

  // Magnetoquasistatic / magneto-thermal: Dirichlet on the magnetic vector potential.
  { Name MagneticVectorPotential;
    Case {
      { Region Sur_Dirichlet_Mag; Value 0.; }
    }
  }

  // Voltage constraint for the a-v formulation.
  // Passive conductors (armour) are shorted: zero voltage drop along z,
  // so induced eddy currents can circulate freely.
  { Name Voltage;
    Case {
      { Region PassiveConductors; Value 0; }
    }
  }

  // Current constraint for the a-v formulation.
  // Phase conductors carry balanced three-phase AC currents.
  { Name Current;
    Case {
      { Region Copper_0; Value I; TimeFunction F_Cos_wt_p[]{2*Pi*Freq, Pa}; }
      { Region Copper_1; Value I; TimeFunction F_Cos_wt_p[]{2*Pi*Freq, Pb}; }
      { Region Copper_2; Value I; TimeFunction F_Cos_wt_p[]{2*Pi*Freq, Pc}; }
    }
  }

  // Thermal initial condition: start from the ambient temperature.
  { Name T_The; Type Init;
    Case {
      { Region Domain_The; Value T0; }
    }
  }

}

If(Flag_AnalysisType == 0)
  Include "LoVe_Electrodynamics.pro";
EndIf

If(Flag_AnalysisType == 1)
  Include "LoVe_Magnetoquasistatics.pro";
EndIf

If(Flag_AnalysisType == 2)
  Include "LoVe_Magnetothermal.pro";
EndIf
