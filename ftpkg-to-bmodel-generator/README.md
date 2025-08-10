# ftpkg-gen — B refinement & glue generator (v0.1)

Generates:
- `FT_PACKAGE_INST_<Name>.ref` (refinement with robust init: total maps over `VER`, `current=v1`)
- `FT_PACKAGE_GLUE_<Name>.mch` (local signatures)
from a **YAML ontology instance** of a FeverTokens package.

## Usage

```bash
pip install -r requirements.txt
python cli.py validate --yaml example/package.yaml
python cli.py emit-b --yaml example/package.yaml --out ./out
```

Open the emitted `.ref` and `.mch` in Atelier B / ProB.

## Notes
- `reads`/`writes` are emitted as relations `(IMPL × SLOT)` with one pair per access.
- `exportedFuncs` equals the union of functions in exported interfaces (kept consistent by construction).
- Selectors in YAML must be unique (0xXXXXXXXX).

Extend later by adding a Solidity extractor that builds the YAML from the 5-file package.
