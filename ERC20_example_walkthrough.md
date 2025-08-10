# ERC-20 Base — Walkthrough (Solidity ↔ B‑Method)

This document explains, step by step, how an **ERC‑20 Base** package looks in Solidity and how the **B‑Method model** describes the same thing. The goal is to make the link crystal clear for newcomers: if you understand the package files, you can understand the B model.

---

## 0) What ERC‑20 Base is (plain words)

ERC‑20 Base is the “core” token behavior:
- **Public functions**: `totalSupply`, `balanceOf`, `transfer`, `allowance`, `approve`, `transferFrom`
- **Events**: `Transfer`, `Approval`
- **Storage**: `totalSupply`, `balances[address]`, `allowances[address][address]`

The B model doesn’t change what ERC‑20 does. It **checks the structure** is safe and consistent: the public API is exact, storage is upgrade‑safe, bindings are correct, and packages compose cleanly in a Diamond (EIP‑2535) without collisions.

---

## 1) Files in the Solidity package (the 5‑file pattern)

1. **`IMyPackageInternal.sol`** – internal types/events/helpers (no public entry points).
2. **`IMyPackage.sol`** – the **public** interface (the 6 ERC‑20 functions + events).
3. **`MyPackageStorage.sol`** – a namespaced storage slot and a `Layout` struct containing:
   - `uint256 totalSupply`
   - `mapping(address => uint256) balances`
   - `mapping(address => mapping(address => uint256)) allowances`
4. **`MyPackageInternal.sol`** – the actual logic (`_transfer`, `_approve`, etc.).
5. **`MyPackage.sol`** – the **facet** users call; it delegates each public function to the internal logic.

Keep this picture in mind; the B model mirrors it one‑for‑one.

---

## 2) The B‑Method machines that mirror the package

### `FT_TYPES` — Vocabulary
- Defines the “kinds of things”: **interfaces, functions, events, storage slots, types, packages, facets, implementations, selectors, versions**.
- Links interface → functions (e.g., `I_ERC20` exports the 6 functions).
- Enforces **selector uniqueness** (no two public functions share the same selector).

**Solidity ↔ B**: `IMyPackage.sol` ↔ `I_ERC20` and its function set in `FT_TYPES`.

### `FT_STORAGE_RULES` — Storage layout (per version)
- Declares which **slots** exist in version `v1`: `s_totalSupply`, `s_balances`, `s_allowances`.
- Declares each slot’s **type** (e.g., `s_balances` is a map `address → uint`).
- **Upgrade safety**: future versions can **add** slots, but cannot remove or change types of existing slots.

**Solidity ↔ B**: `MyPackageStorage.sol` ↔ `layout(v1)` and `slotType(v1)`.

### `FT_BINDINGS` — Wiring functions to logic
- Maps **exported functions → implementations** (`ext_to_impl`), e.g., `f_transfer ↦ im_transfer`.
- Records each implementation’s **facet** membership.
- Records **read/write footprints**: which slots each implementation touches.

**Solidity ↔ B**: `MyPackage.sol` + `MyPackageInternal.sol` ↔ `ext_to_impl`, `facetOf`, `reads/writes`.

### `FT_PACKAGE_ABS` — One package’s rulebook
- Ties **exports**, **storage**, **bindings**, and **dependencies** together for *this* package and version.
- Key safety rails (invariants):
  - The **public surface** equals the exported interfaces (no hidden public functions).
  - Only **exported** functions are **bound** to implementations.
  - Every bound implementation belongs to a **facet**.
  - Implementations read/write **only allocated** slots.
  - **Selectors unique** within the package.

### `FT_DIAMOND_ABS` — Many packages together (optional here)
- Ensures **no selector collisions across packages** and **disjoint storage** between packages installed behind the same proxy.

---

## 3) Function‑by‑function (Solidity ↔ B)

| ERC‑20 function | Solidity view (what it touches) | B view (footprint & binding) |
|---|---|---|
| `totalSupply()` | reads `Layout.totalSupply` | `im_totalSupply` **reads** `s_totalSupply`; bound via `ext_to_impl` |
| `balanceOf(owner)` | reads `Layout.balances[owner]` | `im_balanceOf` **reads** `s_balances` |
| `transfer(to, amt)` | reads/writes `balances` | `im_transfer` **reads & writes** `s_balances` |
| `allowance(o, s)` | reads `allowances[o][s]` | `im_allowance` **reads** `s_allowances` |
| `approve(s, amt)` | writes `allowances[msg.sender][s]` | `im_approve` **writes** `s_allowances` |
| `transferFrom(f, t, amt)` | reads/writes `balances` & `allowances` | `im_transferFrom` **reads & writes** `s_balances`, `s_allowances` |

**Why footprints matter:** reviewers instantly see the “blast radius” of each function. The invariants then force those reads/writes to stay within **declared** storage only.

---

## 4) Versioning & dependencies

- Set `current = v1` for ERC‑20 Base.
- If you add v2 later, the model forces **grow‑only** layout with **type stability** (no silent storage corruption).
- If the package required another, declare it in `requires` and prove it’s sane (no self‑dependency, min versions, etc.).

---

## 5) Events

- Events (`Transfer`, `Approval`) are listed in the vocabulary and tied to the interface.
- The structural model doesn’t specify payload values—only that events belong to the public surface. (You can extend the model if you want to check event logic.)

---

## 6) What you’ve actually “proved” (structural safety)

- Public API is **exactly** what the interface declares (no hidden externals).
- Each public function is **bound** to vetted logic inside a **facet**.
- Implementations **only** touch **declared** storage slots.
- **Selectors are unique** (no ambiguity in dispatch).
- Future upgrades **cannot** break storage layout (grow‑only, type‑stable).

These are the common failure points in real systems. You can extend this example with **behavioral properties** (e.g., arithmetic rules like non‑negative balances) later, but the structural layer already prevents many costly mistakes.

---

## 7) Practical “how‑to” checklist

1. List externals from `IMyPackage.sol` → fill `exports` and derive `exportedFuncs`.
2. Record selectors from the ABI → check injectivity.
3. Describe storage in `MyPackageStorage.sol` → fill `layout(v1)` and `slotType(v1)`.
4. Map externals to internal logic (`MyPackage.sol` → `MyPackageInternal.sol`) → `ext_to_impl`, `facetOf`.
5. For each implementation, list **reads/writes** to storage.
6. Set `current = v1` (and dependencies if any). Ready to discharge proofs.

---

## 8) Tiny skeleton (illustrative, not full B code)

```
/* Interfaces & functions */
I_ERC20 ∈ EXT
iface_funcs(I_ERC20) = { f_totalSupply, f_balanceOf, f_transfer, f_allowance, f_approve, f_transferFrom }
selector is injective on that set

/* Storage v1 */
layout(v1) = { s_totalSupply, s_balances, s_allowances }
slotType(v1)(s_totalSupply) = t_UINT
slotType(v1)(s_balances)    = t_MAP_ADDR_UINT
slotType(v1)(s_allowances)  = t_MAP_ADDR_ADDR_UINT

/* Bindings & footprints */
ext_to_impl = {
  f_totalSupply ↦ im_totalSupply,
  f_balanceOf  ↦ im_balanceOf,
  f_transfer   ↦ im_transfer,
  f_allowance  ↦ im_allowance,
  f_approve    ↦ im_approve,
  f_transferFrom ↦ im_transferFrom
}
reads  = { im_totalSupply ↦ {s_totalSupply}, im_balanceOf ↦ {s_balances}, ... }
writes = { im_transfer ↦ {s_balances}, im_approve ↦ {s_allowances}, im_transferFrom ↦ {s_balances, s_allowances} }
```
