#!/usr/bin/env python3
"""Regenerate the per-screen JSON specs that sit next to each PNG in exports/.

For every exports/**/<screen-name>--<nodeId>.png, writes <screen-name>--<nodeId>.json
containing the screen's full subtree from playola-ios.pen, every component it
references (transitively), and the document variables. Run from anywhere; no
pen.dev connection needed:

    python3 design/export-specs.py
"""
import json
import sys
from pathlib import Path

design_dir = Path(__file__).resolve().parent
doc = json.loads((design_dir / "playola-ios.pen").read_text())

nodes_by_id = {}

def index(node):
    if isinstance(node, dict):
        if "id" in node:
            nodes_by_id[node["id"]] = node
        for child in node.get("children", []):
            index(child)

for top in doc["children"]:
    index(top)

def collect_refs(node, acc):
    if isinstance(node, dict):
        ref = node.get("ref")
        if isinstance(ref, str) and ref not in acc:
            target = nodes_by_id.get(ref)
            if target is not None:
                acc[ref] = target
                collect_refs(target, acc)
        for child in node.get("children", []):
            collect_refs(child, acc)

pngs = sorted((design_dir / "exports").rglob("*--*.png"))
if not pngs:
    sys.exit("no exports found — run from a checkout with design/exports/")

written, missing = 0, []
for png in pngs:
    node_id = png.stem.rsplit("--", 1)[1]
    screen = nodes_by_id.get(node_id)
    if screen is None:
        missing.append(f"{png.relative_to(design_dir)} → node {node_id} not in .pen")
        continue
    components = {}
    collect_refs(screen, components)
    spec = {
        "screen": screen,
        "components": components,
        "variables": doc.get("variables", {}),
    }
    png.with_suffix(".json").write_text(json.dumps(spec, indent=2, ensure_ascii=False) + "\n")
    written += 1

print(f"wrote {written} specs")
for m in missing:
    print("MISSING:", m, file=sys.stderr)
sys.exit(1 if missing else 0)
