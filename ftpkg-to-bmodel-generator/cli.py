import argparse
import json
import os
import re
import sys
import yaml
from jinja2 import Environment, FileSystemLoader
from jsonschema import Draft202012Validator


# --- Paths (relative to this script) ---
HERE = os.path.dirname(os.path.abspath(__file__))
SCHEMA_PATH = os.path.join(HERE, "schema", "package.schema.json")
TEMPLATES_DIR = os.path.join(HERE, "templates")


# --- IO helpers ---
def load_schema():
    with open(SCHEMA_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def load_yaml(path: str):
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


# --- Solidity type → B type (ASCII names) ---
def solidity_type_to_b(t: str):
    # Normalize and use simple prefix checks
    t = (t or "").replace(" ", "")
    if t == "address":
        return "t_ADDR"
    if t in ["uint256", "uint", "uint128", "uint64", "uint32", "uint16", "uint8"]:
        return "t_UINT"
    # mapping(address => mapping(address => uint...))
    if t.startswith("mapping(address=>mapping(address=>uint"):
        return "t_MAP_ADDR_ADDR_UINT"
    # mapping(address => uint...)
    if t.startswith("mapping(address=>uint"):
        return "t_MAP_ADDR_UINT"
    # Fallback opaque type alias (user-defined/complex)
    return "t_OPAQUE"


# --- Context builder for templates ---
def build_context(pkg: dict):
    name = pkg["name"]
    iface_name = re.sub(r"[^A-Za-z0-9_]", "_", name.upper())

    # Symbols
    func_syms = [f"f_{f['name']}" for f in pkg["exports"]["functions"]]
    event_syms = [f"e_{e['name']}" for e in pkg["exports"].get("events", [])]
    selector_syms = [f"sel_{f['name']}" for f in pkg["exports"]["functions"]]
    slot_syms = [s["slot"] for s in pkg["storage"]["layout"]]

    # Helper: map solidity type strings to B type symbols
    def map_types(ts):
        return [solidity_type_to_b(t) for t in ts]

    # Types from storage + signatures; include base atoms for mapping shapes
    typeset = set()
    slot_type_pairs = []  # ["s_slot|->t_TYPE", ...] with no spaces
    for s in pkg["storage"]["layout"]:
        tname = solidity_type_to_b(s["type"])
        typeset.add(tname)
        if tname.startswith("t_MAP_ADDR_"):
            typeset.add("t_ADDR")
            typeset.add("t_UINT")
        slot_type_pairs.append(f"{s['slot']}|->{tname}")

    for f in pkg["exports"]["functions"]:
        for t in map_types(f["inputs"] + f["outputs"]):
            typeset.add(t)
            if t.startswith("t_MAP_ADDR_"):
                typeset.add("t_ADDR")
                typeset.add("t_UINT")

    for e in pkg["exports"].get("events", []):
        for t in map_types(e["inputs"]):
            typeset.add(t)
            if t.startswith("t_MAP_ADDR_"):
                typeset.add("t_ADDR")
                typeset.add("t_UINT")

    type_syms = sorted(typeset)

    # Signatures (tight [] / <>; empty -> [] with no spaces)
    funsig_lines = []
    funsig_map = []
    for f in pkg["exports"]["functions"]:
        ins = ",".join(map_types(f["inputs"]))
        outs = ",".join(map_types(f["outputs"]))
        funsig_lines.append(f"funSig(f_{f['name']}) = ([{ins}],[{outs}])")
        funsig_map.append(f"f_{f['name']}|->(<{ins}>,<{outs}>)")

    eventsig_lines = []
    eventsig_map = []
    for e in pkg["exports"].get("events", []):
        ins = ",".join(map_types(e["inputs"]))
        eventsig_lines.append(f"eventSig(e_{e['name']}) = [{ins}]")
        eventsig_map.append(f"e_{e['name']}|-><{ins}>")

    # Selectors
    selector_bindings = [f"selector(f_{f['name']})=sel_{f['name']}" for f in pkg["exports"]["functions"]]

    # Bindings & facet
    ext_to_impl_pairs = [f"f_{fname}|->{impl}" for fname, impl in pkg["impl"]["bindings"].items()]
    facet_sym = pkg["impl"]["facet"]

    # Unique implementation symbols (preserve order)
    impl_order = []
    for impl in pkg["impl"]["bindings"].values():
        if impl not in impl_order:
            impl_order.append(impl)

    impl_to_facet_pairs = [f"{impl}|->{facet_sym}" for impl in impl_order]

    # Footprints (pairs, no spaces; {} if none)
    read_pairs, write_pairs = [], []
    for impl, rw in pkg["impl"]["footprints"].items():
        for r in rw.get("reads", []):
            read_pairs.append(f"{impl}|->{r}")
        for w in rw.get("writes", []):
            write_pairs.append(f"{impl}|->{w}")

    # requires (map package-name symbol -> v1) — can extend later to real versions
    requires_pairs = []
    for dep in pkg.get("dependsOn", []):
        dep_sym = re.sub(r"[^A-Za-z0-9_]", "_", dep["name"])
        requires_pairs.append(f"{dep_sym}|->v1")

    return {
        "pkg_name": pkg["name"],
        "iface_name": iface_name,
        "func_syms": func_syms,
        "event_syms": event_syms,
        "slot_syms": slot_syms,
        "type_syms": type_syms,
        "selector_syms": selector_syms,
        "impl_syms": impl_order,
        "facet_sym": facet_sym,
        "funsig_lines": funsig_lines,
        "eventsig_lines": eventsig_lines,
        "selector_bindings": selector_bindings,
        "slot_type_pairs": slot_type_pairs,
        "ext_to_impl_pairs": ext_to_impl_pairs,
        "impl_to_facet_pairs": impl_to_facet_pairs,
        "read_pairs": read_pairs,
        "write_pairs": write_pairs,
        "requires_pairs": requires_pairs,
        "funsig_map": funsig_map,
        "eventsig_map": eventsig_map,
    }


# --- Extra validation to fail early with clear messages ---
def basic_validate(pkg: dict):
    # Bindings refer only to exported function names
    exported = {f["name"] for f in pkg["exports"]["functions"]}
    for fname in pkg["impl"]["bindings"].keys():
        if fname not in exported:
            raise ValueError(f"Binding refers to non-exported function: {fname}")

    # Selector uniqueness + basic format check
    sels = [f["selector"].lower() for f in pkg["exports"]["functions"]]
    if len(sels) != len(set(sels)):
        raise ValueError("Duplicate function selector detected.")
    for sel in sels:
        if not re.fullmatch(r"0x[0-9a-f]{8}", sel):
            raise ValueError(f"Bad selector format (want 0x + 8 hex): {sel}")

    # Footprints reference declared slots
    declared_slots = {s["slot"] for s in pkg["storage"]["layout"]}
    for impl, rw in pkg["impl"]["footprints"].items():
        for r in rw.get("reads", []):
            if r not in declared_slots:
                raise ValueError(f"Footprint reads unknown slot: {impl} -> {r}")
        for w in rw.get("writes", []):
            if w not in declared_slots:
                raise ValueError(f"Footprint writes unknown slot: {impl} -> {w}")


# --- Rendering / emission ---
def emit(yaml_path: str, out_dir: str):
    schema = load_schema()
    pkg = load_yaml(yaml_path)
    Draft202012Validator(schema).validate(pkg)
    basic_validate(pkg)

    env = Environment(
        loader=FileSystemLoader(TEMPLATES_DIR),
        trim_blocks=True,
        lstrip_blocks=True,
    )

    ctx = build_context(pkg)

    ref_text = env.get_template("refinement.j2").render(**ctx)
    glue_text = env.get_template("glue_machine.j2").render(**ctx)

    os.makedirs(out_dir, exist_ok=True)
    ref_path = os.path.join(out_dir, f"FT_PACKAGE_INST_{pkg['name']}.ref")
    glue_path = os.path.join(out_dir, f"FT_PACKAGE_GLUE_{pkg['name']}.mch")

    with open(ref_path, "w", encoding="utf-8") as f:
        f.write(ref_text)
    with open(glue_path, "w", encoding="utf-8") as f:
        f.write(glue_text)

    print(ref_path)
    print(glue_path)


# --- CLI ---
def main():
    ap = argparse.ArgumentParser(prog="ftpkg-gen", description="Generate B refinement + glue from FeverTokens package YAML")
    sub = ap.add_subparsers(dest="cmd", required=True)

    em = sub.add_parser("emit-b", help="Emit B artifacts from YAML")
    em.add_argument("--yaml", required=True, help="Path to package.yaml")
    em.add_argument("--out", required=True, help="Output directory")

    va = sub.add_parser("validate", help="Validate YAML & run static checks")
    va.add_argument("--yaml", required=True, help="Path to package.yaml")

    args = ap.parse_args()
    if args.cmd == "emit-b":
        emit(args.yaml, args.out)
    elif args.cmd == "validate":
        schema = load_schema()
        pkg = load_yaml(args.yaml)
        Draft202012Validator(schema).validate(pkg)
        basic_validate(pkg)
        print("YAML is valid and consistent.")
    else:
        ap.print_help()


if __name__ == "__main__":
    main()
