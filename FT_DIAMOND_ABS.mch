/* FT_DIAMOND_ABS
 * Author: boudi
 * Creation date: 09/08/2025
 */
MACHINE FT_DIAMOND_ABS
SEES FT_TYPES
CONCRETE_VARIABLES installed, exportedFuncsD, layoutD
INVARIANT
  installed ⊆ PACKAGE &
  exportedFuncsD ∈ installed --> POW(FUNC) &
  layoutD        ∈ installed --> POW(SLOT) &
  /* global selector uniqueness on all exported functions */
  ( union(ran(exportedFuncsD)) <| selector )
     ∈ union(ran(exportedFuncsD)) >-> SELECTOR &
  /* pairwise slot disjointness between installed packages */
  !(pp,qq).(pp∈installed ∧ qq∈installed ∧ pp≠qq ⇒ layoutD(pp) ∩ layoutD(qq) = {})
INITIALISATION
  installed := {} || exportedFuncsD := {} || layoutD := {}
OPERATIONS
  Install(pp, ef, ls) =
    PRE
      pp ∈ PACKAGE ∧ pp ∉ installed ∧
      ef ∈ POW(FUNC) ∧ ls ∈ POW(SLOT) ∧
      /* new slots must be disjoint from all already-installed slots */
      ls ∩ union(ran(layoutD)) = {}
    THEN
      installed      := installed ∪ { pp } ||
      exportedFuncsD := exportedFuncsD ∪ { pp |-> ef } ||
      layoutD        := layoutD        ∪ { pp |-> ls }
    END;

  Uninstall(pp) =
    PRE pp ∈ installed
    THEN
      installed      := installed - { pp } ||
      exportedFuncsD := { pp } <<| exportedFuncsD ||
      layoutD        := { pp } <<| layoutD
    END;

  Upgrade(pp, ef2, ls2) =
    PRE
      pp ∈ PACKAGE ∧ pp ∈ installed ∧
      ef2 ∈ POW(FUNC) ∧ ls2 ∈ POW(SLOT) ∧
      /* allow changing pp’s own slots, but keep disjointness vs others */
      ls2 ∩ ( union(ran(layoutD)) - layoutD(pp) ) = {}
    THEN
      exportedFuncsD := ({pp} <<| exportedFuncsD) ∪ { pp |-> ef2 } ||
      layoutD        := ({pp} <<| layoutD)        ∪ { pp |-> ls2 }
    END
END


