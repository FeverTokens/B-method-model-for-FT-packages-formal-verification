/* FT_TYPES
 * Author: boudi
 * Creation date: 09/08/2025
 */
MACHINE FT_TYPES
SETS
  INTERFACE; FUNC; EVENT; SLOT; TYPE; PACKAGE; FACET; IMPL; SELECTOR; VER
ABSTRACT_CONSTANTS
  iface_funcs, iface_events, funSig, eventSig, selector, EXT, INTERNAL
PROPERTIES
  /* Interface partition */
  EXT ⊆ INTERFACE & INTERNAL ⊆ INTERFACE & EXT ∩ INTERNAL = {} & EXT ∪ INTERNAL = INTERFACE &

  /* Interface exports */
  iface_funcs ∈ INTERFACE --> POW(FUNC)  &
  iface_events ∈ INTERFACE --> POW(EVENT) &

  /* Signatures */
  funSig   ∈ FUNC  --> ( seq(TYPE) × seq(TYPE) ) &
  eventSig ∈ EVENT --> seq(TYPE) &

  /* Function selector: total injection (no collisions) */
  selector ∈ FUNC >-> SELECTOR
ASSERTIONS
  !xx.( xx ∈ POW(FUNC) => union({xx}) = xx )

END


