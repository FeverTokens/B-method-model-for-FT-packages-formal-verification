# A B‑Method Model for Verifying Package‑Oriented Smart Contracts
_Beginner‑friendly walkthrough, mapped to the FeverTokens package pattern_

This README explains, in very simple terms, how our B‑Method model verifies a **package‑oriented smart contract**. We go **machine by machine** (the B modules), and for each one we show how it corresponds to the way you build a package in the FeverTokens framework.

- FeverTokens Package Framework: https://github.com/FeverTokens/ft-package-oriented-framework

---

## What you’ll learn
- The role of each B machine (\*what it describes\*).
- The key elements inside each machine (**SETS, CONSTANTS, VARIABLES, INVARIANTS**).
- How each element maps to a real package (interfaces, storage, implementations, facets).
- Why the invariants guarantee safe upgrades and safe composition in a Diamond.

---

## One‑minute legend for B notation
- **SETS**: “kinds of things” (e.g., interfaces, functions, events).
- **CONSTANTS**: fixed facts (e.g., which functions belong to an interface).
- **VARIABLES**: changeable state (e.g., current version).
- **INVARIANTS**: rules that must always hold (safety rails).
- `X --> Y`: total function (each `X` maps to exactly one `Y`).
- `X +-> Y`: partial function (some `X` may map to a `Y`, some not).
- `A >-> B`: injective function (no two `A` map to the same `B`).
- `dom(f)`, `ran(f)`: the domain and range of a function `f`.
- `union(S)`: union of all sets inside set `S`.

If you keep these in mind, the rest will feel natural.

---

## Machine: `FT_TYPES` — the vocabulary (dictionary only)
**What it is:** A pure dictionary of the basic concepts we talk about. No state, no changes—just names and signatures.

**Key elements**
- **SETS**: `INTERFACE, FUNC, EVENT, SLOT, TYPE, PACKAGE, FACET, IMPL, SELECTOR, VER`.
- **CONSTANTS** (examples):
  - `iface_funcs: INTERFACE --> P(FUNC)` — which functions each interface exports.
  - `iface_events: INTERFACE --> P(EVENT)` — which events each interface emits.
  - `funSig: FUNC --> (seq(TYPE) × seq(TYPE))` — argument and return types.
  - `eventSig: EVENT --> seq(TYPE)` — event argument types.
  - `selector: FUNC >-> SELECTOR` — unique selector per function (injective).
  - `EXT, INTERNAL ⊆ INTERFACE` — external vs internal interfaces.

**How this maps to the package repo**
- In a real package you typically have two interfaces:
  - `IMyPackageInternal.sol` (internal types/events/helpers).
  - `IMyPackage.sol` (public API for users).
- This corresponds to `INTERNAL` vs `EXT`, and the function/event lists (`iface_funcs`, `iface_events`).

---

## Machine: `FT_VERSIONING` — ordering versions
**What it is:** A strict order over versions, like `v1 < v2 < v3 ...`

**Why it matters:** Later we’ll express **upgrade rules** using this order (e.g., layout can grow but not shrink, types stay consistent).

---

## Machine: `FT_STORAGE_RULES` — safe storage across upgrades
**What it is:** Rules for storage layout and types per version so that upgrades don’t corrupt data.

**VARIABLES**
- `layout: VER --> P(SLOT)` — the set of storage slots in each version.
- `slotType: VER --> (SLOT +-> TYPE)` — the type of each allocated slot per version.

**INVARIANTS**
- `dom(slotType(v)) = layout(v)` — only allocated slots have types.
- **Upgrade safety:** If `v < w` then:
  1) `layout(v) ⊆ layout(w)` — you may **add** slots but not remove.
  2) Existing slots keep the **same type** in `w`.

**How this maps to the package repo**
- A FeverTokens package uses a dedicated **storage library** (e.g., `MyPackageStorage.sol`) with a namespaced slot (ERC‑7201 style). That’s what `layout` and `slotType` abstract: the list of slots and their declared types across versions.

---

## Machine: `FT_BINDINGS` — wiring functions to implementations
**What it is:** The mapping from public functions to internal implementations, and the read/write footprint of each implementation.

**VARIABLES**
- `ext_to_impl: FUNC +-> IMPL` — which implementation handles each exported function.
- `facetOf: IMPL +-> FACET` — which facet an implementation belongs to.
- `reads, writes ⊆ IMPL × SLOT` — which storage slots an implementation may read/write.

**Why this matters**
- We ensure only **exported** functions are bound, and that every bound implementation sits inside a **facet**. We also constrain each implementation to touch only the **allocated** slots (from `FT_STORAGE_RULES`).

**How this maps to the package repo**
- External entry points live in `MyPackage.sol` → think `ext_to_impl`.
- Internal logic lives in `MyPackageInternal.sol` → the actual `IMPL`.
- A **facet** is the deployable surface grouping those functions (Diamond terminology). The `reads`/`writes` sets correspond to which fields the internal logic touches in `MyPackageStorage.layout()`.

---

## Machine: `FT_DEPENDENCIES` — who this package needs
**What it is:** Declares the current package and (optionally) the packages/versions it requires.

**Typical elements**
- `thisPkg ∈ PACKAGE` — identity of the current package.
- (Used later) `requires: PACKAGE +-> VER` — dependency versions.

**How this maps to the package repo**
- In practice, dependencies surface in deployment metadata and hub configuration (e.g., “ERC‑20 Permit requires ≥ v2 of ERC‑20 Base”). The model gives a formal place to assert and check such constraints.

---

## Machine: `FT_PACKAGE_ABS` — one package’s full rulebook
**What it is:** The **main state** and safety rules for a **single** package.

**VARIABLES**
- **Version & exports**
  - `current ∈ VER` — live version.
  - `exports: VER --> P(EXT)` — exported external interfaces per version.
  - `exportedFuncs: VER --> P(FUNC)` — the exact set of exported functions per version, defined by:
    `exportedFuncs(v) = union( iface_funcs[ exports(v) ] )`.
- **Storage (same as FT_STORAGE_RULES)**
  - `layout, slotType` with the same invariants (grow‑only, types stable).
- **Bindings & read/write (same as FT_BINDINGS)**
  - `ext_to_impl, facetOf, reads, writes` with discipline rules.
- **Dependencies**
  - `requires: PACKAGE +-> VER` and `thisPkg ∉ dom(requires)`.

**INVARIANTS (high level)**
- **Interface conformance:** `exportedFuncs(v)` is exactly what the exported interfaces declare (no hidden public functions).
- **Binding correctness:**
  - `dom(ext_to_impl) ⊆ exportedFuncs(current)` — only exported functions are bound.
  - `ran(ext_to_impl) ⊆ dom(facetOf)` — every bound impl belongs to a facet.
  - `ran(reads) ∪ ran(writes) ⊆ layout(current)` — implementations touch only allocated slots.
- **Selector uniqueness (per package):** Function selectors are injective within the exported surface (no collisions).
- **Upgrade safety & dependency sanity:** As specified above.

**How this maps to the package repo**
- `exports` / `exportedFuncs` mirror your **external interface** (`IMyPackage.sol`).
- `layout/slotType` mirror the **storage struct** and slot namespace in `MyPackageStorage.sol`.
- `ext_to_impl`/`facetOf` mirror how functions in `MyPackage.sol` call into `MyPackageInternal.sol` (grouped in a facet).

---

## Machine: `FT_DIAMOND_ABS` — many packages together
**What it is:** The **aggregator** that models a Diamond proxy holding multiple installed packages (facets).

**VARIABLES**
- `installed ⊆ PACKAGE` — which packages are currently installed.
- For each installed package `p`:
  - `exportedFuncsD(p) ⊆ FUNC` — its exported functions.
  - `layoutD(p) ⊆ SLOT` — its allocated storage slots.

**INVARIANTS (global guarantees)**
- **Selector uniqueness across packages:** Restrict `selector` to the union of all exported functions → still injective (no cross‑package selector collisions).
- **Storage disjointness:** For distinct packages `p ≠ q`, `layoutD(p) ∩ layoutD(q) = ∅` (no slot overlaps).

**How this maps to the package repo**
- This is the “whole Diamond” view: installing multiple FeverTokens packages (facets) behind one proxy is safe if and only if these invariants hold at install/upgrade time.

---

## Refinements — proving a concrete package respects the rules
A **refinement** instantiates the abstract model with the concrete symbols of your package and proves the invariants.

### Example A: Minimal “MyContract”
- **Define**:
  - one version `v1`, one external interface `I_Main`, one function `f_ping`, one event, two slots, one implementation `im_ping`, one facet, and a selector `sel_ping`.
- **Initialize**:
  - `current := v1`, `exports(v1) = {I_Main}`.
  - `exportedFuncs(v1) = {f_ping}` (must equal `iface_funcs(I_Main)`).
  - declare storage layout & types; bind `f_ping` to `im_ping`; set `facetOf(im_ping)`; list `reads/writes` only within `layout(v1)`.
- **Result**: All invariants follow: exact exported surface, correct binding to a facet, and storage access limited to allocated slots.

### Example B: ERC‑20 Base package
- **Interface:** `totalSupply, balanceOf, transfer, allowance, approve, transferFrom` (+ events); selectors are unique.
- **Storage:** `totalSupply`, `balances`, `allowances` with appropriate (abstract) types.
- **Bindings:** each external function is bound to one implementation; every impl belongs to a facet.
- **Footprints:** e.g., `im_transfer` writes `balances`; `im_approve` writes `allowances`; etc. All reads/writes are inside `layout(v1)`.
- **Outcome:** A faithful abstraction of the Solidity ERC‑20 base that passes the structural safety checks.

---

## How this maps to the FeverTokens 5‑file package pattern
FeverTokens recommends (simplified names):
1. `IMyPackageInternal.sol` — internal interface (types, events, helpers).
2. `IMyPackage.sol` — external/public interface.
3. `MyPackageStorage.sol` — storage namespace & `Layout` struct.
4. `MyPackageInternal.sol` — internal logic (implementations).
5. `MyPackage.sol` — the external entry points that bind to internal logic (a facet).

These align one‑to‑one with the B model:
- **Interfaces** ↔ `FT_TYPES` (EXT vs INTERNAL, function/event sets, selectors).
- **Storage** ↔ `FT_STORAGE_RULES` (layout evolution and type stability across versions).
- **Bindings/facets** ↔ `FT_BINDINGS` & `FT_PACKAGE_ABS` (function→impl, impl→facet, read/write discipline).
- **Diamond composition** ↔ `FT_DIAMOND_ABS` (no selector collisions, disjoint storage between packages).

---

## Why the invariants matter (plain words)
- **No hidden externals:** The exported surface is exactly what your interfaces declare.
- **Correct bindings:** Every public function points to vetted logic inside a facet (not arbitrary code).
- **Upgrade‑safe storage:** New versions can’t silently break persistent data.
- **Diamond‑safe composition:** Multiple packages can coexist without selector clashes or storage overwrites.

---

## Practical checklist (Solidity → B)
1) **List your externals** from `IMyPackage.sol` → fill `exports` and derive `exportedFuncs`.
2) **Record selectors** (ABI) → ensure they’re injective within the package.
3) **Describe storage** from `MyPackageStorage.sol` → fill `layout` and `slotType`.
4) **Map externals to internal functions** in `MyPackage.sol`/`MyPackageInternal.sol` → `ext_to_impl` and `facetOf`.
5) **Over‑approximate reads/writes** per internal function → `reads`, `writes`.
6) **Set version & dependencies** (`current`, `requires`) → ready for install checks in `FT_DIAMOND_ABS`.

If you follow the FeverTokens package template, you are already aligning with the model; the refinement is a faithful, formal summary of what your package declares in code.

---

## Pointers
- FeverTokens Package Framework: https://github.com/FeverTokens/ft-package-oriented-framework
- Diamond Standard (facets mindset): EIP‑2535
- ERC‑7201 (storage namespaces): common pattern mirrored by `layout`/`slotType`

