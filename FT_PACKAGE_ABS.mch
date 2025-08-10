/* FT_PACKAGE_ABS
 * Author: boudi
 * Creation date: 09/08/2025
 */

MACHINE FT_PACKAGE_ABS
SEES FT_TYPES, FT_VERSIONING, FT_DEPENDENCIES

/* All state lives here, so a refinement can assign it */
CONCRETE_VARIABLES
  current,                      /* VER */
  exports, exportedFuncs,       /* VER → P(EXT), VER → P(FUNC) */
  layout, slotType,             /* VER → P(SLOT), VER → (SLOT +-> TYPE) */
  ext_to_impl, facetOf,         /* FUNC +-> IMPL, IMPL +-> FACET */
  reads, writes,                /* ⊆ IMPL × SLOT */
  requires                      /* PACKAGE +-> VER */

INVARIANT
  /* Version & exports */
  current ∈ VER  &
  exports ∈ VER --> POW(EXT)  &
  exportedFuncs ∈ VER --> POW(FUNC)  &

    /* exportedFuncs(v) = ⋃ iface_funcs[ exports(v) ] */
  !vv.(vv∈VER ⇒ exportedFuncs(vv) = union( iface_funcs[ exports(vv) ] ))  &

  /* Storage typing + upgrade safety */
  layout   ∈ VER --> POW(SLOT)  &
  slotType ∈ VER --> (SLOT +-> TYPE)  &
  !vv.(vv∈VER ⇒ dom(slotType(vv)) = layout(vv))  &
  !(vv,ww).(vv∈VER ∧ ww∈VER ∧ (vv,ww)∈ord ⇒
        (layout(vv) ⊆ layout(ww) ∧
         !ss.(ss∈layout(vv) ⇒ slotType(ww)(ss) = slotType(vv)(ss))))  &

  /* Bindings + facets + RW discipline */
  ext_to_impl ∈ FUNC +-> IMPL  &
  facetOf     ∈ IMPL +-> FACET &
  ran(ext_to_impl) ⊆ dom(facetOf) &
  reads ⊆ IMPL × SLOT  ∧  writes ⊆ IMPL × SLOT  &
  dom(ext_to_impl) ⊆ exportedFuncs(current)  &
  ran(reads)  ⊆ layout(current)  ∧  ran(writes) ⊆ layout(current)  &

  /* Selector injective on exported funcs of current version */
  ( exportedFuncs(current) <| selector ) ∈ exportedFuncs(current) >-> SELECTOR  &

  /* Dependencies */
  requires ∈ PACKAGE +-> VER  ∧  thisPkg ∉ dom(requires)


INITIALISATION
  /*
  // Keep abstract; a refinement will set concrete values
  current :∈ VER  ||
  exports, exportedFuncs :∈ (VER --> POW(EXT)) × (VER --> POW(FUNC))  ||
  layout, slotType :∈ (VER --> POW(SLOT)) × (VER --> (SLOT +-> TYPE)) ||
  ext_to_impl :∈ (FUNC +-> IMPL)  ||
  facetOf     :∈ (IMPL +-> FACET) ||
  reads, writes :∈ POW(IMPL × SLOT) × POW(IMPL × SLOT) ||
  requires :∈ PACKAGE +-> VER
*/

  ANY cur, ex, ef, ly, st, e2i, fc, rd, wr, rq WHERE
      cur ∈ VER &
      ex  ∈ VER --> POW(EXT) &
      ef  ∈ VER --> POW(FUNC) &
      ly  ∈ VER --> POW(SLOT) &
      st  ∈ VER --> (SLOT +-> TYPE) &
      e2i ∈ FUNC +-> IMPL &
      fc  ∈ IMPL +-> FACET &
      rd  ⊆ IMPL * SLOT &
      wr  ⊆ IMPL * SLOT &
      rq  ∈ PACKAGE +-> VER &

      /* Link exported functions to exports */
      !vv.(vv∈VER => ef(vv) = union(iface_funcs[ ex(vv) ])) &

      /* Storage domain & upgrade safety already true at init */
      !vv.(vv∈VER => dom(st(vv)) = ly(vv)) &
      !(vv,ww).(vv∈VER & ww∈VER & (vv,ww)∈ord =>
             ( ly(vv) ⊆ ly(ww) &
               !ss.(ss∈ly(vv) => st(ww)(ss) = st(vv)(ss)) )) &

      /* Binding discipline + facets + RW ⊆ layout(current) */
      dom(e2i) ⊆ ef(cur) &
      ran(e2i) ⊆ dom(fc) &
      ran(rd) ⊆ ly(cur) &
      ran(wr) ⊆ ly(cur) &
      (ef(cur) <| selector) ∈ ef(cur) >-> SELECTOR &      
      not(thisPkg : dom(rq))
      
  THEN
      current      := cur ||
      exports      := ex  ||
      exportedFuncs:= ef  ||
      layout       := ly  ||
      slotType     := st  ||
      ext_to_impl  := e2i ||
      facetOf      := fc  ||
      reads        := rd  ||
      writes       := wr  ||
      requires     := rq
  END
END


 
