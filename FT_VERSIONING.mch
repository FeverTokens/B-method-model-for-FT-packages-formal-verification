/* FT_VERSIONING
 * Author: boudi
 * Creation date: 09/08/2025
 */
MACHINE FT_VERSIONING
SEES FT_TYPES
ABSTRACT_CONSTANTS ord
PROPERTIES
  ord ⊆ VER × VER  &
  /* strict total order on VER */
  (!xx.(xx∈VER ⇒ (xx,xx) ∉ ord))  &                                         /* irreflexive */
  (!(xx,yy,zz).(xx∈VER ∧ yy∈VER ∧ zz∈VER ∧ (xx,yy)∈ord ∧ (yy,zz)∈ord ⇒ (xx,zz)∈ord)) & /* transitive */
  (!(xx,yy).(xx∈VER ∧ yy∈VER ∧ xx≠yy ⇒ ((xx,yy)∈ord ∨ (yy,xx)∈ord)))                  /* connex */
END
