/* FT_STORAGE_RULES
 * Author: boudi
 * Creation date: 09/08/2025
 */
MACHINE FT_STORAGE_RULES
SEES FT_TYPES, FT_VERSIONING
VARIABLES layout, slotType
INVARIANT
  /* Per-version allocated slots and their types */
  layout   ∈ VER --> POW(SLOT)                  &
  slotType ∈ VER --> (SLOT +-> TYPE)            &

  /* slotType is defined exactly on allocated slots of each version */
  (!vv.(vv∈VER ⇒ dom(slotType(vv)) = layout(vv)))   &

  /* Upgrade-safety: monotone allocation and type stability across versions */
  (!(vv,ww).(vv∈VER ∧ ww∈VER ∧ (vv,ww)∈ord ⇒
        (layout(vv) ⊆ layout(ww)  ∧
         (!ss.(ss∈layout(vv) ⇒ slotType(ww)(ss) = slotType(vv)(ss))))))
INITIALISATION
  /* leave abstract; concretized by refinement */
  layout, slotType :: (VER --> POW(SLOT)) × (VER --> (SLOT +-> TYPE))
END

