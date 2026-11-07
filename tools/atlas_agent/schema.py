"""A deliberately small JSON-Schema subset validator (stdlib only).

The runner ships its configuration and receipt contracts as JSON Schema files so
external automation can read them. This validator enforces the subset those files
use: type, enum, const, required, properties, additionalProperties (bool or
schema), items, minItems/maxItems, minimum/maximum, minLength/maxLength, pattern
and oneOf. Unknown keywords are ignored; ``$ref`` is intentionally unsupported.
"""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

SCHEMA_DIR = Path(__file__).resolve().parent / "schemas"

_TYPES = {
    "object": dict,
    "array": list,
    "string": str,
    "boolean": bool,
    "null": type(None),
}


def load_schema(name: str) -> dict:
    return json.loads((SCHEMA_DIR / name).read_text(encoding="utf-8"))


def _type_ok(value: Any, expected: str) -> bool:
    if expected == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if expected == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    return isinstance(value, _TYPES[expected])


def validate(instance: Any, schema: dict, path: str = "$") -> list[str]:
    """Return a list of human-readable problems (empty when valid)."""
    problems: list[str] = []
    expected = schema.get("type")
    if expected is not None:
        names = expected if isinstance(expected, list) else [expected]
        if not any(_type_ok(instance, name) for name in names):
            return [f"{path}: expected {'|'.join(names)}, got {type(instance).__name__}"]
    if "const" in schema and instance != schema["const"]:
        problems.append(f"{path}: must equal {schema['const']!r}")
    if "enum" in schema and instance not in schema["enum"]:
        problems.append(f"{path}: {instance!r} not in {schema['enum']}")
    if "oneOf" in schema:
        matches = sum(1 for option in schema["oneOf"] if not validate(instance, option, path))
        if matches != 1:
            problems.append(f"{path}: must match exactly one alternative (matched {matches})")
    if isinstance(instance, str):
        if len(instance) < schema.get("minLength", 0):
            problems.append(f"{path}: shorter than {schema['minLength']}")
        if len(instance) > schema.get("maxLength", 1 << 62):
            problems.append(f"{path}: longer than {schema['maxLength']}")
        if "pattern" in schema and not re.search(schema["pattern"], instance):
            problems.append(f"{path}: does not match {schema['pattern']!r}")
    if _type_ok(instance, "number") and not isinstance(instance, bool):
        if "minimum" in schema and instance < schema["minimum"]:
            problems.append(f"{path}: {instance} below minimum {schema['minimum']}")
        if "maximum" in schema and instance > schema["maximum"]:
            problems.append(f"{path}: {instance} above maximum {schema['maximum']}")
        if "exclusiveMinimum" in schema and instance <= schema["exclusiveMinimum"]:
            problems.append(f"{path}: {instance} not above {schema['exclusiveMinimum']}")
    if isinstance(instance, list):
        if len(instance) < schema.get("minItems", 0):
            problems.append(f"{path}: fewer than {schema['minItems']} items")
        if len(instance) > schema.get("maxItems", 1 << 62):
            problems.append(f"{path}: more than {schema['maxItems']} items")
        if "items" in schema:
            for index, item in enumerate(instance):
                problems += validate(item, schema["items"], f"{path}[{index}]")
    if isinstance(instance, dict):
        for key in schema.get("required", []):
            if key not in instance:
                problems.append(f"{path}: missing required '{key}'")
        properties = schema.get("properties", {})
        extra = schema.get("additionalProperties", True)
        for key, value in instance.items():
            if key in properties:
                problems += validate(value, properties[key], f"{path}.{key}")
            elif extra is False:
                problems.append(f"{path}: unexpected property '{key}'")
            elif isinstance(extra, dict):
                problems += validate(value, extra, f"{path}.{key}")
    return problems
