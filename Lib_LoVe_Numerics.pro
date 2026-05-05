// Shared Jacobian and integration settings for all LoVe-in-HV analyses.
//
// The Jacobian block maps each region to the correct geometric transformation:
//   - Domain_Inf_Mag (EnvironmentInf): spherical-shell infinite-element mapping,
//     collapsing the annular outer ring to represent the field at infinity.
//     Parameters JacRadiusInt, JacRadiusExt, JacCenterX/Y/Z come from generated_common.pro.
//   - All other regions: standard volumetric Jacobian.
//
// The same Jacobian block is reused by the electrodynamic, magnetoquasistatic,
// and magneto-thermal formulations; for the electrodynamic case EnvironmentInf
// is also part of Domain_Ele, so the infinite-shell mapping applies there too.
//
// Integration: 4-point Gauss rule on triangles and quadrilaterals, 2-point on lines.
// This is the minimum order that integrates quadratic test functions exactly.

Jacobian {
  { Name Vol;
    Case {
      { Region Domain_Inf_Mag;
        Jacobian VolSphShell{JacRadiusInt, JacRadiusExt,
                             JacCenterX, JacCenterY, JacCenterZ}; }
      { Region All; Jacobian Vol; }
    }
  }
  { Name Sur;
    Case {
      { Region All; Jacobian Sur; }
    }
  }
}

Integration {
  { Name I1;
    Case {
      { Type Gauss;
        Case {
          { GeoElement Triangle;   NumberOfPoints 4; }
          { GeoElement Quadrangle; NumberOfPoints 4; }
          { GeoElement Line;       NumberOfPoints 2; }
        }
      }
    }
  }
}
