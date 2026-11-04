#!/usr/bin/env python3
"""Read-only #353-A guards for the immutable legacy consumers.

This is a compatibility checkpoint, not a migration or a generic GDScript
interpreter. The retained source commit independently authenticates the lock.
Source changes need an explicitly reviewed new checkpoint; there is deliberately
no --accept, --refresh or automatic baseline update mode.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASELINE = "0fd4af5987e77db4da3e37c757cf2c0917ae9e15"
LOCK = Path("materials/catalogue/compatibility-lock.json")
CATALOGUE_SOURCES = (
    "native/include/cybersand/material.hpp",
    "native/include/cybersand/interaction_rules.hpp",
)
# Lock narrowly identified legacy owners, not every unrelated source file.
SOURCE_ROLES = {
    "native/include/cybersand/material.hpp": "stable IDs and descriptor bytes",
    "native/include/cybersand/interaction_rules.hpp": "reaction, family and ordinal identity",
    "native/include/cybersand/material_rules.hpp": "material query interface",
    "native/src/material_rules.cpp": "capability and pair-query semantics",
    "native/include/cybersand/material_appearance.hpp": "visual state projection",
    "native/include/cybersand/precision_storage.hpp": "Cell layout and state widths",
    "native/include/cybersand/quantity_ledger.hpp": "quantity schema and positional slots",
    "native/src/world_quantity.inc": "quantity codec, endpoints and specialized ordinal mapping",
    "native/src/world.cpp": "legacy movement, chemistry, thermal and scheduling authority",
    "native/src/world_pressure.inc": "policy admission, physical hash and CYPS restoration",
    "native/src/world_inertial.inc": "IN sidecar and state authority",
    "native/include/cybersand/transport_policy.hpp": "transport v1 dimensions and wire contract",
    "native/include/cybersand/liquid_solver_policy.hpp": "native stale-identity refusal",
    "native/include/cybersand/liquid_policy_catalogue.hpp": "generated native policy identities",
    "native/include/cybersand/water_experiment_policy.hpp": "Water quantity defaults and bounds",
    "godot/scripts/cell_world.gd": "fallback identity, capabilities and separate physics",
    "godot/scripts/interaction_policy.gd": "fallback granular support",
    "godot/scripts/material_appearance_lut.gd": "palette bytes and Godot appearance calculations",
    "godot/scripts/transport_profiles.gd": "transport ownership, precedence and validation",
    "godot/shaders/material_palette.gdshader": "hand-coded appearance programme",
    "tools/lcb/derive_capability_matrix.py": "literal-source parser contract",
    "tools/lcb/policy_contract.py": "catalogue, capability and policy digest contract",
    "tools/lcb/native_policy_artifacts.py": "existing native identity generator",
    "docs/reference/liquid-solver-capability-matrix.json": "capability identity bytes",
    "docs/reference/liquid-policy-wire-vectors.json": "retained policy wire oracle",
    "docs/reference/water-normalization-vectors.json": "retained normalization oracle",
    "docs/reference/liquid-run-receipt-vectors.json": "retained receipt oracle",
}


class CompatibilityError(ValueError):
    """An actionable source or baseline mismatch; never repairs the source."""


def lf(data: bytes) -> bytes:
    return data.replace(b"\r\n", b"\n")


def sha(data: bytes) -> str:
    return hashlib.sha256(lf(data)).hexdigest()


def _unique_object(pairs: list[tuple[str, object]]) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise CompatibilityError(f"duplicate JSON key {key!r}")
        result[key] = value
    return result


def _canonical(value: object) -> str:
    # Distinguishes True from 1, which normal Python container equality does not.
    return json.dumps(value, sort_keys=True, ensure_ascii=True, allow_nan=False)


def read_lock(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8"),
                           object_pairs_hook=_unique_object,
                           parse_constant=lambda token: (_ for _ in ()).throw(
                               CompatibilityError(f"non-finite JSON value {token}")))
    except (OSError, UnicodeError, ValueError) as exc:
        raise CompatibilityError(f"{path}: {exc}") from exc
    if not isinstance(value, dict):
        raise CompatibilityError(f"{path}: /: expected an object")
    expected = {"schema_version", "source_commit", "source_locks", "catalogue_digest",
                "capability_digest", "fallback_source_facts", "experimental_claims"}
    if set(value) != expected:
        raise CompatibilityError(f"{path}: /: expected exactly {sorted(expected)}")
    if type(value["schema_version"]) is not int or value["schema_version"] != 1:
        raise CompatibilityError(f"{path}: /schema_version: supported version is integer 1")
    if value["source_commit"] != BASELINE:
        raise CompatibilityError(f"{path}: /source_commit: expected retained {BASELINE}; "
                                 "an identity transition requires separate review")
    return value


def catalogue_digest(sources: dict[str, bytes]) -> str:
    digest = hashlib.sha256(b"lcb-material-catalogue-v1\0")
    for path in CATALOGUE_SOURCES:
        name, data = path.encode("utf-8"), lf(sources[path])
        digest.update(struct.pack("<I", len(name)) + name)
        digest.update(struct.pack("<I", len(data)) + data)
    return digest.hexdigest()


def capability_digest(data: bytes) -> str:
    return hashlib.sha256(b"lcb-capability-matrix-v1\0" + lf(data)).hexdigest()


def _function(text: str, name: str) -> str:
    pattern = rf"(?ms)^(?:static )?func {re.escape(name)}\([^\n]*\)[^\n]*:\n(.*?)(?=^(?:static )?func |\Z)"
    found = re.search(pattern, text)
    if not found:
        raise CompatibilityError(f"fallback function {name}: unsupported/missing literal source")
    # Fields between functions do not belong to the body.
    return found[1].split("\nvar ", 1)[0].rstrip()


def fallback_facts(sources: dict[str, bytes]) -> dict:
    """Extract a limited set of inspected literals; no Godot execution claim.

    Every complete input is authenticated before these facts are accepted.
    Unsupported expression forms fail instead of guessing their evaluation.
    """
    cell = lf(sources["godot/scripts/cell_world.gd"]).decode("utf-8")
    policy = lf(sources["godot/scripts/interaction_policy.gd"]).decode("utf-8")
    palette = lf(sources["godot/scripts/material_appearance_lut.gd"]).decode("utf-8")
    identities = dict((name, int(value)) for name, value in re.findall(
        r"^const ([A-Z][A-Z0-9_]*): int = ([0-9]+)\s*$",
        cell.split("const FIRST_BUILDING_MATERIAL:", 1)[0], re.M))
    identities = {key: value for key, value in identities.items()
                  if key not in {"WORLD_WIDTH", "WORLD_HEIGHT"}}
    if len(identities) != 131 or set(identities.values()) != set(range(132)) - {10}:
        raise CompatibilityError("fallback identity constants: expected 131 distinct IDs excluding invalid10")

    density = [0] * 256
    body = _function(cell, "_material_density")
    pending = None
    saw_default = False
    for line in body.splitlines():
        line = line.split("#", 1)[0].strip()
        if not line or line == "match material_id:":
            continue
        case = re.fullmatch(r"([A-Z][A-Z0-9_]*|_):(?:\s*return ([0-9]+))?", line)
        returned = re.fullmatch(r"return ([0-9]+)", line)
        if case:
            if pending is not None:
                raise CompatibilityError("fallback density: incomplete match arm")
            pending = case[1]
            value = int(case[2]) if case[2] is not None else None
        elif returned and pending is not None:
            value = int(returned[1])
        else:
            raise CompatibilityError(f"fallback density: unsupported expression {line!r}")
        if value is not None:
            if pending == "_":
                if value != 0:
                    raise CompatibilityError("fallback density default changed")
                saw_default = True
            elif pending in identities:
                density[identities[pending]] = value
            else:
                raise CompatibilityError(f"fallback density: unknown ID {pending}")
            pending = None
    if pending is not None or not saw_default:
        raise CompatibilityError("fallback density: missing complete default arm")

    support = _function(policy, "supports_load")
    match = re.fullmatch(r"\tmatch material:\n\t\t([0-9, ]+):\n\t\t\treturn true\n\t\t_:\n\t\t\treturn false", support)
    if not match:
        raise CompatibilityError("fallback granular support: unsupported expression")
    granular = sorted(int(number.strip()) for number in match[1].split(","))
    hard_body = _function(cell, "_is_hard_surface_material")
    hard = re.fullmatch(
        r"\tif material_id >= LIMESTONE_BLOCK and material_id <= LAST_MATERIAL:\n\t\treturn true\n"
        r"\tmatch material_id:\n\t\t([A-Z_, ]+):\n\t\t\treturn true\n\t\t_:\n\t\t\treturn false", hard_body)
    last = re.search(r"^const LAST_MATERIAL: int = ([0-9]+)$", cell, re.M)
    if not hard or not last:
        raise CompatibilityError("fallback hard predicate: unsupported source")
    hard_ids = sorted(set(range(identities["LIMESTONE_BLOCK"], int(last[1]) + 1)) |
                      {identities[name.strip()] for name in hard[1].split(",")})
    rgba = re.search(r"const BASE_RGBA8: Array\[int\] = \[(.*?)\n\]", palette, re.S)
    if not rgba:
        raise CompatibilityError("fallback palette: missing BASE_RGBA8 literals")
    rgba_values = []
    for line in rgba[1].splitlines():
        code = line.split("#", 1)[0].strip()
        if not code:
            continue
        if not re.fullmatch(r"0x[0-9A-Fa-f]{8},", code):
            raise CompatibilityError(f"fallback palette: unsupported literal {code!r}")
        rgba_values.append(int(code[:-1], 16))
    if len(rgba_values) != 132:
        raise CompatibilityError("fallback palette: expected 132 literal RGBA8 entries")
    return {"qualification": "source literals only; fallback movement and Godot pixels are not native parity",
            "identity_constants": dict(sorted(identities.items())),
            "density_by_byte_id": density, "hard_surface_ids": hard_ids,
            "granular_support_ids": granular, "base_rgba8": rgba_values,
            "slush_density": density[identities["SLUSH"]]}


def retained_sources(repository: Path = ROOT) -> dict[str, bytes]:
    sources = {}
    for path in SOURCE_ROLES:
        try:
            result = subprocess.run(["git", "-C", str(repository), "show", f"{BASELINE}:{path}"],
                                    check=True, capture_output=True, timeout=30)
        except (OSError, subprocess.SubprocessError) as exc:
            raise CompatibilityError(f"cannot authenticate {BASELINE}:{path}; complete retained Git history required: {exc}") from exc
        sources[path] = result.stdout
    return sources


def expected_claims() -> dict:
    return {"pr": 358, "head": "ffee6cd0f052fbe9a44fed08d9d99b3565a19205",
            "status": "draft-experimental-not-production-reservations",
            "materials": {"StoneWall": 132, "SaltWall": 133, "CoalWall": 134,
                          "DryBinder": 135, "ActivatedBinder": 136, "BinderCrust": 137}}


def build_lock(sources: dict[str, bytes]) -> dict:
    """Pure bootstrap representation used by tests; the CLI never writes a lock."""
    return {"schema_version": 1, "source_commit": BASELINE,
            "source_locks": [{"path": path, "role": SOURCE_ROLES[path],
                              "lf_sha256": sha(sources[path])} for path in sorted(SOURCE_ROLES)],
            "catalogue_digest": catalogue_digest(sources),
            "capability_digest": capability_digest(sources["docs/reference/liquid-solver-capability-matrix.json"]),
            "fallback_source_facts": fallback_facts(sources),
            "experimental_claims": expected_claims()}


def check(root: Path = ROOT, lock_path: Path | None = None,
          baseline_repository: Path = ROOT) -> dict:
    path = lock_path or root / LOCK
    actual_lock = read_lock(path)
    baseline = retained_sources(baseline_repository)
    expected_lock = build_lock(baseline)
    for key in expected_lock:
        if _canonical(actual_lock[key]) != _canonical(expected_lock[key]):
            raise CompatibilityError(f"{path}: /{key}: differs from immutable {BASELINE}; "
                                     "do not refresh away a compatibility failure")
    current = {}
    for source in actual_lock["source_locks"]:
        name = source["path"]
        try:
            current[name] = (root / name).read_bytes()
        except OSError as exc:
            raise CompatibilityError(f"{name}: required legacy consumer unavailable: {exc}") from exc
        actual = sha(current[name])
        if actual != source["lf_sha256"]:
            raise CompatibilityError(f"{name}: LF source-byte drift ({source['role']}); "
                                     f"expected {source['lf_sha256']}, got {actual}. "
                                     "#353-A preserves this consumer; cutover/identity transition needs separate review")
    for tree in ("native", "godot"):
        for source in sorted((root / tree).rglob("*")):
            if source.suffix not in {".h", ".hh", ".hpp", ".hxx", ".c", ".cc", ".cpp", ".cxx", ".inc", ".gd", ".gdshader"}:
                continue
            if not source.is_file():
                continue
            if re.search(rb"catalogue_shadow|material_catalogue_shadow|catalogue\.shadow\.(?:hpp|gd|json)|materials/catalogue/generated",
                         source.read_bytes()):
                raise CompatibilityError(f"{source.relative_to(root)}: production/native test imports shadow output; "
                                         "#353-A permits tooling consumers only")
    return {"status": "PASS", "baseline": BASELINE, "protected_sources": len(SOURCE_ROLES),
            "catalogue_digest": catalogue_digest(current),
            "capability_digest": capability_digest(current["docs/reference/liquid-solver-capability-matrix.json"]),
            "fallback_slush_density": actual_lock["fallback_source_facts"]["slush_density"],
            "production_cutover": False, "runtime_execution": False}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT, help="candidate source root to validate")
    parser.add_argument("--check", action="store_true", help="explicit read-only mode (also the default)")
    args = parser.parse_args(argv)
    try:
        result = check(args.root.resolve())
    except CompatibilityError as exc:
        print(f"compatibility: {exc}", file=sys.stderr)
        return 1
    print(json.dumps(result, sort_keys=True, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
