/* FT_BINDINGS
 * Author: boudi
 * Creation date: 09/08/2025
 */
MACHINE FT_BINDINGS
SEES FT_TYPES
VARIABLES ext_to_impl, reads, writes, facetOf
INVARIANT
  ext_to_impl ∈ FUNC +-> IMPL &
  facetOf     ∈ IMPL +-> FACET &   /* was IMPL --> FACET */
  reads ⊆ IMPL × SLOT      &
  writes ⊆ IMPL × SLOT
INITIALISATION
  ext_to_impl :: (FUNC +-> IMPL) ||
  facetOf     :: (IMPL +-> FACET) ||    /* was (IMPL --> FACET) */
  reads, writes :: POW(IMPL × SLOT) × POW(IMPL × SLOT)
END
