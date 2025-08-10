/* FT_DIAMOND_INSTALL_ERC20_Base
 * Author: boudi
 * Creation date: 09/08/2025
 */
MACHINE FT_DIAMOND_INSTALL_ERC20_Base
SEES FT_TYPES, FT_VERSIONING, FT_DEPENDENCIES
INCLUDES FT_DIAMOND_ABS, FT_PACKAGE_ABS

OPERATIONS
  /* Install the package currently described by FT_PACKAGE_ABS */
  InstallThisPkg =
    PRE
      thisPkg ∈ PACKAGE ∧
      thisPkg ∉ installed ∧
      /* ensure cross-package slot disjointness before the call */
      layout(current) ∩ union(ran(layoutD)) = {}
    THEN
      /* call the Install op of the included FT_DIAMOND_ABS */
      Install(thisPkg, exportedFuncs(current), layout(current))
    END;

  /* Update the diamond with the package's current version (v2, v3, ...) */
  UpgradeThisPkg =
    PRE
      thisPkg ∈ PACKAGE ∧
      thisPkg ∈ installed ∧
      /* allow changing thisPkg layout, but keep disjointness vs others */
      layout(current) ∩ ( union(ran(layoutD)) - layoutD(thisPkg) ) = {}
    THEN
      Upgrade(thisPkg, exportedFuncs(current), layout(current))
    END;

  /* Optional passthrough if you want to remove it from the diamond here */
  UninstallThisPkg =
    PRE thisPkg ∈ installed
    THEN Uninstall(thisPkg) END
END



