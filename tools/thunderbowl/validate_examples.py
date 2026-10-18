#!/usr/bin/env python3
"""Validate Thunderbowl JSON schemas, fixtures and optional Godot captures.

Development dependency: jsonschema (tested with 4.26.0). This does not add a
runtime dependency to CyberSand. Runtime authority remains in the Godot owner.
"""

import argparse
import hashlib
import json
from pathlib import Path

from jsonschema import Draft202012Validator
from referencing import Registry, Resource

ROOT = Path(__file__).resolve().parents[2]
EXAMPLES = ROOT / "godot/examples/thunderbowl"
SCHEMAS = EXAMPLES / "schemas"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture", action="append", type=Path, default=[])
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    documents = {}
    for path in sorted(SCHEMAS.glob("*.schema.json")):
        schema = json.loads(path.read_text())
        schema["$id"] = path.as_uri()
        Draft202012Validator.check_schema(schema)
        documents[path.name.removesuffix(".schema.json")] = schema
    registry = Registry().with_resources(
        (schema["$id"], Resource.from_contents(schema)) for schema in documents.values()
    )
    validators = {name: Draft202012Validator(schema, registry=registry) for name, schema in documents.items()}
    cases = []
    for path in sorted((EXAMPLES / "matches").glob("*.json")):
        cases.append((str(path.relative_to(ROOT)), "match", json.loads(path.read_text()), True))
    for filename, schema in (("input_keyboard.json", "input"), ("input_touch.json", "input"),
                             ("input_gamepad_metal.json", "actuator-input"), ("nca_seed_weights.json", "nca-weights")):
        cases.append((filename, schema, json.loads((EXAMPLES / filename).read_text()), True))
    for path in args.capture:
        for case in json.loads(path.read_text())["cases"]:
            cases.append((str(path) + ":" + case["name"], case["schema"], case["value"], case["valid"]))
    failures = []
    for name, schema, value, expected in cases:
        errors = list(validators[schema].iter_errors(value))
        if (not errors) != expected:
            failures.append({"case": name, "schema": schema, "expected_valid": expected,
                             "errors": [e.message for e in errors[:4]]})
    report = {"schema_count": len(documents), "case_count": len(cases), "failures": failures,
              "schema_sha256": {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                                for path in sorted(SCHEMAS.glob("*.schema.json"))}}
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    return bool(failures)


if __name__ == "__main__":
    raise SystemExit(main())
