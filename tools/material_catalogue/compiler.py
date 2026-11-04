#!/usr/bin/env python3
"""Compile explicitly authored metadata into unconsumed, native-parity shadows.

The production headers, policy identities and Godot fallback are deliberately
not generator outputs. Schema 1 has one explicit input file and no imports,
inheritance, family defaults, executable expressions or runtime loader.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SOURCE = REPO_ROOT / "materials/catalogue/catalogue.json"
DEFAULT_OUTPUT = REPO_ROOT / "materials/catalogue/generated"
SCHEMA_ID = "cybersand.material-catalogue.shadow"
SCHEMA_VERSION = 1
GENERATOR_VERSION = 1
MANIFEST_VERSION = 1
GENERATOR_SHA256 = hashlib.sha256(Path(__file__).read_bytes().replace(b"\r\n", b"\n")).hexdigest()

# Immutable schema-1 registry from the reviewed native source. This is an ID
# allocation guard, not the descriptor/parity oracle (which compiles native C++).
# A later production allocation needs a deliberately versioned admission.
CURRENT_MATERIAL_NAMES = tuple("""
empty wall sand water smoke cloner fire wood
lava ice invalid plant acid stone dust mite
oil rocket fungus seed paste slush steam salt
brine sodium gunpowder coal metal rust cement concrete
toxic-sludge mercury spark glass molten-glass foam limestone-block sandstone-block
granite-block cobblestone mossy-cobblestone red-brick lime-plaster wattle-and-daub oak-timber thatch
terracotta-tile slate wrought-iron lead-sheet bronze copper verdigris-copper stained-glass
packed-earth industrial-brick reinforced-concrete asphalt wet-asphalt wet-cobblestone steel-plate painted-steel
corrugated-steel rusted-steel steel-grating chainlink steel-pipe copper-pipe ceramic-tile chemical-glass
dark-glass rubber cable-bundle insulation hazard-stripe neon-cyan neon-magenta neon-amber
led-white pine-planks birch-log oak-log walnut-panel mahogany-panel bamboo plywood
driftwood cedar-shingles charred-timber cork wicker cardboard paper-screen tar-block
acrylic-sheet moss-wall marble chalk-block basalt-columns obsidian adobe-brick raw-clay
firebrick packed-snow rock-salt-block gypsum-board quicklime-block rammed-earth sandbag terrazzo
gabion zinc-sheet aluminium-panel magnesium-plate thermite-brick bare-iron gold-leaf brass-panel
glass-block frosted-glass quartz-crystal uranium-glass sugar-glass wax-block sulfur-block phosphor-panel
polymer-panel solar-panel carbon-fibre heat-shield-tile
""".split())

ENUM_DOMAINS = {
    "MaterialState": ["Empty", "Solid", "Powder", "Liquid", "Gas", "Agent"],
    "RuleKernel": [
        "None", "Sand", "Water", "Gas", "Cloner", "Fire", "Combustible", "Lava",
        "Ice", "Plant", "Acid", "Stone", "Dust", "Mite", "Oil", "Rocket",
        "Fungus", "Seed", "YieldingLiquid", "Steam", "Gunpowder", "Coal", "Metal",
        "Cement", "Spark", "MoltenGlass", "Foam",
    ],
    "DensityMotion": ["None", "Down", "Up"],
    "LateralFlowMode": ["None", "FreeMass", "CellularYield"],
    "VisualStateSource": ["Zero", "StateA", "StateB"],
    "InteractionTriggerKind": ["PairContact", "NeighbourhoodContext", "IntrinsicState"],
    "InteractionMatchKind": ["Ordered", "UnorderedRolePreserving", "Symmetric"],
    "InteractionChannel": [
        "ThermalPhase", "DissolutionCorrosion", "ChemicalConversionProducts",
        "Combustion", "Electrical", "CuringGrowthSpecialState", "AuthoritativeEmissionsByproducts",
    ],
    "InteractionLayerKind": ["ChannelDefault", "FamilyDefault", "MaterialAdjustment", "PairOverride", "ContextModifier"],
}

MATERIAL_FIELDS = (
    "id", "name", "state", "density", "rgba", "movable", "valid", "current_rule_available",
    "kernel", "initial_state_a", "initial_state_b", "maximum_write_radius", "density_motion",
    "accepts_density_exchange", "lateral_flow", "viscosity_index",
)
PAIR_FIELDS = (
    "legacy_slot", "id", "channels", "trigger", "match", "first", "second", "first_product",
    "second_product", "probability", "accounting", "revalidation_tags", "version", "supersedes", "tuning_pass_id",
)
SPECIALIZED_FIELDS = (
    "legacy_slot", "id", "channels", "trigger", "material", "kernel", "authority_path",
    "represented_semantics", "revalidation_tags", "version", "supersedes", "tuning_pass_id",
)
CAPABILITY_FIELDS = (
    "id", "valid", "current_rule", "hard_surface", "granular_support", "free_leveling_liquid", "pair_participant",
)
FAMILY_ORDER = (
    "int.family.combustible-kernel", "int.family.conductive-base-metal", "int.family.reactive-base-glass",
    "int.family.hot-source", "int.family.aqueous-contact", "int.family.biological-growth", "int.family.special-agent",
)
COVERAGE_ORDER = (
    "compact-pair-current", "specialized-current-kernels", "control.water-sand", "family.conductive-themed-metals",
    "pair-override.acid-themed-metals", "family.reactive-themed-glass", "mat002-building-pair-rules",
    "mat002-building-combustibles", "mat002-building-inert", "future-mechanism-tuning",
)
PASS_ORDER = ("int.pass.current-oracle", "int.pass.mat002-building-materials")
CHANNEL_IDS = (
    "thermal_phase", "dissolution_corrosion", "chemical_conversion_products", "combustion", "electrical",
    "curing_growth_special_state", "authoritative_emissions_byproducts",
)
LAYER_IDS = ("channel_default", "family_default", "material_adjustment", "pair_override", "context_modifier")


class CatalogueError(ValueError):
    """An invalid source or unsafe output request; no output was published."""


class DriftError(CatalogueError):
    """A nonwriting check found missing, stale or unexpected generated files."""


class _ObjectPairs(list):
    """Keep duplicate JSON keys until their complete JSON pointer is known."""


class _NonFinite:
    def __init__(self, token: str):
        self.token = token


def _pointer(parent: str, key: Any) -> str:
    return parent + "/" + str(key).replace("~", "~0").replace("/", "~1")


class _Validator:
    def __init__(self, source: Path):
        self.source = source

    def fail(self, pointer: str, message: str, other: str | None = None) -> None:
        location = f"{self.source}#{pointer or '/'}"
        if other is not None:
            message += f"; conflicts with {self.source}#{other or '/'}"
        raise CatalogueError(f"{location}: {message}")

    def object(self, value: Any, pointer: str, fields: tuple[str, ...]) -> dict:
        if not isinstance(value, dict):
            self.fail(pointer, "expected an object")
        unknown = sorted(set(value) - set(fields))
        if unknown:
            self.fail(_pointer(pointer, unknown[0]), "unknown field")
        missing = sorted(set(fields) - set(value))
        if missing:
            self.fail(_pointer(pointer, missing[0]), "required field is missing")
        return value

    def array(self, value: Any, pointer: str, count: int | None = None) -> list:
        if not isinstance(value, list):
            self.fail(pointer, "expected an array")
        if count is not None and len(value) != count:
            self.fail(pointer, f"expected exactly {count} entries; found {len(value)}")
        return value

    def integer(self, value: Any, pointer: str, low: int, high: int) -> int:
        if type(value) is not int or not low <= value <= high:
            self.fail(pointer, f"expected an integer in [{low}, {high}] (booleans/coercion are not allowed)")
        return value

    def boolean(self, value: Any, pointer: str) -> bool:
        if type(value) is not bool:
            self.fail(pointer, "expected a boolean")
        return value

    def string(self, value: Any, pointer: str, *, empty: bool = False) -> str:
        if not isinstance(value, str) or (not empty and not value):
            self.fail(pointer, "expected a nonempty string" if not empty else "expected a string")
        return value

    def equal(self, value: Any, expected: Any, pointer: str) -> None:
        if type(value) is not type(expected) or value != expected:
            self.fail(pointer, f"schema 1 requires {expected!r}; found {value!r}")

    def unique(self, rows: list, pointer: str, fields: tuple[str, ...]) -> None:
        seen: dict[tuple, str] = {}
        for index, row in enumerate(rows):
            key = tuple(row[field] for field in fields)
            at = _pointer(pointer, index)
            if key in seen:
                self.fail(at, f"duplicate identity {key!r}", seen[key])
            seen[key] = at


def _read_json(path: Path, validator: _Validator) -> Any:
    try:
        raw = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        raise CatalogueError(f"{path}#/: cannot read UTF-8 source: {error}") from error
    try:
        parsed = json.loads(raw, object_pairs_hook=_ObjectPairs, parse_constant=_NonFinite)
    except json.JSONDecodeError as error:
        raise CatalogueError(
            f"{path}#/: JSON syntax at line {error.lineno}, column {error.colno}: {error.msg}"
        ) from error
    except (ValueError, RecursionError) as error:
        raise CatalogueError(f"{path}#/: invalid JSON: {error}") from error

    def convert(value: Any, pointer: str) -> Any:
        if isinstance(value, _ObjectPairs):
            result = {}
            for key, child in value:
                at = _pointer(pointer, key)
                if key in result:
                    validator.fail(at, "duplicate object key (second occurrence)", at + " (first occurrence)")
                convert(key, at)
                result[key] = convert(child, at)
            return result
        if isinstance(value, list):
            return [convert(child, _pointer(pointer, index)) for index, child in enumerate(value)]
        if isinstance(value, _NonFinite) or (isinstance(value, float) and not math.isfinite(value)):
            validator.fail(pointer, "non-finite numbers are not allowed")
        if isinstance(value, str):
            try:
                value.encode("utf-8")
            except UnicodeEncodeError:
                validator.fail(pointer, "unpaired Unicode surrogate is not valid UTF-8 text")
            if "\x00" in value:
                validator.fail(pointer, "NUL is not allowed in authored text")
        return value

    try:
        return convert(parsed, "")
    except RecursionError as error:
        raise CatalogueError(f"{path}#/: JSON nesting is too deep") from error


def _material_records(value: Any, v: _Validator, p: str, isolated: bool) -> list[dict]:
    count = 133 if isolated else 132
    rows = v.array(value, p)
    for i, row in enumerate(rows):
        at = _pointer(p, i)
        v.object(row, at, MATERIAL_FIELDS)
        material_id = v.integer(row["id"], at + "/id", 0, 255)
        name = v.string(row["name"], at + "/name")
        if not re.fullmatch(r"[a-z][a-z0-9-]*", name):
            v.fail(at + "/name", "expected a native descriptor key, not a display label")
        for field in ("movable", "valid", "current_rule_available", "accepts_density_exchange"):
            v.boolean(row[field], at + "/" + field)
        for field, domain in (("state", "MaterialState"), ("kernel", "RuleKernel"),
                              ("density_motion", "DensityMotion"), ("lateral_flow", "LateralFlowMode")):
            v.integer(row[field], at + "/" + field, 0, len(ENUM_DOMAINS[domain]) - 1)
        v.integer(row["density"], at + "/density", 0, 65535)
        for field in ("initial_state_a", "initial_state_b", "viscosity_index"):
            v.integer(row[field], at + "/" + field, 0, 255)
        v.integer(row["maximum_write_radius"], at + "/maximum_write_radius", 0, 2)
        for j, channel in enumerate(v.array(row["rgba"], at + "/rgba", 4)):
            v.integer(channel, at + f"/rgba/{j}", 0, 255)
    v.unique(rows, p, ("id",))
    v.unique(rows, p, ("name",))
    v.array(rows, p, count)
    for i, row in enumerate(rows):
        at = _pointer(p, i)
        material_id, name = row["id"], row["name"]
        if material_id < 132:
            if name != CURRENT_MATERIAL_NAMES[material_id]:
                v.fail(at + "/name", f"immutable ID {material_id} belongs to {CURRENT_MATERIAL_NAMES[material_id]!r}")
            v.equal(row["valid"], material_id != 10, at + "/valid")
        elif isolated and material_id == 132:
            # This deliberately cannot produce or export a production material.
            v.equal(name, "synthetic-powder", at + "/name")
            v.equal(row["state"], 2, at + "/state")
            v.equal(row["kernel"], 1, at + "/kernel")
            v.equal(row["valid"], True, at + "/valid")
        else:
            v.fail(at + "/id", "unallocated production ID; schema 1 admits only 0..131 (132 requires isolated synthetic mode)")
        if row["kernel"] == 0 and row["maximum_write_radius"] != 0:
            v.fail(at + "/maximum_write_radius", "inert native kernel requires radius zero", at + "/kernel")
        if row["kernel"] != 0 and row["maximum_write_radius"] == 0:
            v.fail(at + "/maximum_write_radius", "active native kernel requires an explicit supported radius", at + "/kernel")
        if not row["valid"] and (row["movable"] or row["current_rule_available"]):
            v.fail(at + "/valid", "reserved invalid slot cannot be movable or available")
    if {row["id"] for row in rows} != set(range(count)):
        v.fail(p, f"every allocated ID 0..{count - 1} must occur exactly once")
    return sorted(rows, key=lambda row: row["id"])


def _capability_records(value: Any, v: _Validator, p: str, isolated: bool) -> list[dict]:
    rows = v.array(value, p)
    for i, row in enumerate(rows):
        at = _pointer(p, i)
        v.object(row, at, CAPABILITY_FIELDS)
        material_id = v.integer(row["id"], at + "/id", 0, 255)
        for field in CAPABILITY_FIELDS[1:]:
            v.boolean(row[field], at + "/" + field)
        if material_id == 10 or material_id >= (133 if isolated else 132):
            for field in CAPABILITY_FIELDS[1:]:
                v.equal(row[field], False, at + "/" + field)
        if isolated and material_id == 132:
            v.equal(row["hard_surface"], False, at + "/hard_surface")
    v.unique(rows, p, ("id",))
    v.array(rows, p, 256)
    return sorted(rows, key=lambda row: row["id"])


def _appearance_records(value: Any, v: _Validator, p: str, isolated: bool) -> list[dict]:
    rows = v.array(value, p)
    for i, row in enumerate(rows):
        at = _pointer(p, i)
        v.object(row, at, ("id", "visual_state_source"))
        material_id = v.integer(row["id"], at + "/id", 0, 255)
        v.integer(row["visual_state_source"], at + "/visual_state_source", 0, 2)
        if material_id == 10 or material_id >= (133 if isolated else 132):
            v.equal(row["visual_state_source"], 0, at + "/visual_state_source")
    v.unique(rows, p, ("id",))
    v.array(rows, p, 256)
    return sorted(rows, key=lambda row: row["id"])


def _reference(value: Any, v: _Validator, p: str, valid_ids: set[int]) -> int:
    v.integer(value, p, 0, 255)
    if value not in valid_ids:
        v.fail(p, f"material {value} is invalid, reserved or unallocated")
    return value


def _rule_records(value: Any, v: _Validator, p: str, valid_ids: set[int], *, specialized: bool) -> list[dict]:
    count = 19 if specialized else 56
    rows = v.array(value, p)
    for i, row in enumerate(rows):
        at = _pointer(p, i)
        v.object(row, at, SPECIALIZED_FIELDS if specialized else PAIR_FIELDS)
        v.integer(row["legacy_slot"], at + "/legacy_slot", 0, count - 1)
        prefix = "int.kernel." if specialized else "int.pair."
        if not v.string(row["id"], at + "/id").startswith(prefix):
            v.fail(at + "/id", f"rule ID must have the {prefix!r} namespace")
        v.integer(row["channels"], at + "/channels", 1, 127)
        v.integer(row["trigger"], at + "/trigger", 0, 2)
        v.integer(row["revalidation_tags"], at + "/revalidation_tags", 0, 63)
        v.integer(row["version"], at + "/version", 1, 4294967295)
        v.string(row["supersedes"], at + "/supersedes", empty=True)
        v.string(row["tuning_pass_id"], at + "/tuning_pass_id")
        if row["tuning_pass_id"] not in ("int.pass.current-oracle", "int.pass.mat002-building-materials"):
            v.fail(at + "/tuning_pass_id", "unsupported tuning pass in schema 1")
        if row["supersedes"]:
            v.fail(at + "/supersedes", "schema 1 freezes Current records; new supersession needs separate admission", at + "/id")
        if specialized:
            _reference(row["material"], v, at + "/material", valid_ids)
            v.integer(row["kernel"], at + "/kernel", 0, 26)
            v.string(row["authority_path"], at + "/authority_path")
            v.string(row["represented_semantics"], at + "/represented_semantics")
        else:
            v.equal(row["trigger"], 0, at + "/trigger")
            v.integer(row["match"], at + "/match", 0, 2)
            for field in ("first", "second", "first_product", "second_product"):
                _reference(row[field], v, at + "/" + field, valid_ids)
            v.integer(row["probability"], at + "/probability", 0, 255)
            v.string(row["accounting"], at + "/accounting")
    v.unique(rows, p, ("id",))
    v.unique(rows, p, ("legacy_slot",))
    v.array(rows, p, count)
    if not specialized:
        # Finite pair intersections, including reverse orientations, never use
        # source order as precedence. Schema 1 has no layering/supersession.
        occupied: dict[tuple[int, int], str] = {}
        for i, row in enumerate(rows):
            domain = {(row["first"], row["second"])}
            if row["match"] != 0:
                domain.add((row["second"], row["first"]))
            for pair in sorted(domain):
                at = _pointer(p, i)
                if pair in occupied:
                    v.fail(at, f"ambiguous pair override for ordered IDs {pair}", occupied[pair])
                occupied[pair] = at
    return sorted(rows, key=lambda row: row["legacy_slot"])


def _identity(value: Any, v: _Validator, p: str, isolated: bool, valid_ids: set[int]) -> dict:
    v.object(value, p, ("allocated_slots", "reserved_ids", "aliases"))
    v.equal(value["allocated_slots"], 133 if isolated else 132, p + "/allocated_slots")
    reserved = v.array(value["reserved_ids"], p + "/reserved_ids", 1)
    v.equal(reserved[0], 10, p + "/reserved_ids/0")
    aliases = v.array(value["aliases"], p + "/aliases")
    for i, alias in enumerate(aliases):
        at = p + f"/aliases/{i}"
        v.object(alias, at, ("namespace", "name", "target"))
        v.string(alias["namespace"], at + "/namespace")
        v.string(alias["name"], at + "/name")
        # Aliases reference numeric identities only. Alias chains/cycles are
        # not representable, and alias names never choose material behavior.
        _reference(alias["target"], v, at + "/target", valid_ids)
    v.unique(aliases, p + "/aliases", ("namespace", "name"))
    v.array(aliases, p + "/aliases", 1)
    v.equal(aliases[0]["namespace"], "native_enum", p + "/aliases/0/namespace")
    v.equal(aliases[0]["name"], "Gas", p + "/aliases/0/name")
    v.equal(aliases[0]["target"], 4, p + "/aliases/0/target")
    return value


def _interactions(value: Any, v: _Validator, p: str, valid_ids: set[int]) -> dict:
    fields = (
        "schema_id", "schema_version", "profile_id", "profile_version", "current_oracle_pair_rule_count",
        "building_material_pass_id", "channels", "layer_kinds", "pairs", "specialized", "families",
        "memberships", "coverage", "tuning_passes", "layers",
    )
    v.object(value, p, fields)
    for field, expected in (
        ("schema_id", "cybersand.interactions"), ("schema_version", 1),
        ("profile_id", "int.current-behaviour"), ("profile_version", 2),
        ("current_oracle_pair_rule_count", 14), ("building_material_pass_id", PASS_ORDER[1]),
    ):
        v.equal(value[field], expected, p + "/" + field)
    layers = v.array(value["layers"], p + "/layers")
    if layers:
        v.fail(p + "/layers/0", "schema 1 permits no active layers, defaults, overrides or selectors; new semantics require separate admission")

    channels = v.array(value["channels"], p + "/channels")
    for i, row in enumerate(channels):
        at = p + f"/channels/{i}"
        v.object(row, at, ("channel", "id"))
        number = v.integer(row["channel"], at + "/channel", 0, 6)
        v.equal(row["id"], CHANNEL_IDS[number], at + "/id")
    v.unique(channels, p + "/channels", ("channel",))
    v.array(channels, p + "/channels", 7)

    layer_kinds = v.array(value["layer_kinds"], p + "/layer_kinds")
    for i, row in enumerate(layer_kinds):
        at = p + f"/layer_kinds/{i}"
        v.object(row, at, ("kind", "id", "precedence"))
        number = v.integer(row["kind"], at + "/kind", 0, 4)
        v.equal(row["id"], LAYER_IDS[number], at + "/id")
        v.equal(row["precedence"], (number + 1) * 100, at + "/precedence")
    v.unique(layer_kinds, p + "/layer_kinds", ("kind",))
    v.array(layer_kinds, p + "/layer_kinds", 5)

    pairs = _rule_records(value["pairs"], v, p + "/pairs", valid_ids, specialized=False)
    specialized = _rule_records(value["specialized"], v, p + "/specialized", valid_ids, specialized=True)
    all_rule_ids = {row["id"] for row in pairs}
    if all_rule_ids.intersection(row["id"] for row in specialized):
        v.fail(p + "/specialized", "pair and specialized identities must not collide", p + "/pairs")

    families = v.array(value["families"], p + "/families")
    for i, row in enumerate(families):
        at = p + f"/families/{i}"
        v.object(row, at, ("id", "version", "purpose"))
        if v.string(row["id"], at + "/id") not in FAMILY_ORDER:
            v.fail(at + "/id", "unknown family; schema 1 preserves the seven existing membership-only families")
        v.integer(row["version"], at + "/version", 1, 4294967295)
        v.string(row["purpose"], at + "/purpose")
    v.unique(families, p + "/families", ("id",))
    v.array(families, p + "/families", 7)

    memberships = v.array(value["memberships"], p + "/memberships")
    family_ids = {row["id"] for row in families}
    for i, row in enumerate(memberships):
        at = p + f"/memberships/{i}"
        v.object(row, at, ("family_id", "material"))
        if v.string(row["family_id"], at + "/family_id") not in family_ids:
            v.fail(at + "/family_id", "unknown semantic family")
        _reference(row["material"], v, at + "/material", valid_ids)
    v.unique(memberships, p + "/memberships", ("family_id", "material"))
    v.array(memberships, p + "/memberships", 33)

    coverage = v.array(value["coverage"], p + "/coverage")
    coverage_fields = ("subject_id", "channel_id", "authored_status", "evidence_status", "effective_rule_id", "limitation")
    for i, row in enumerate(coverage):
        at = p + f"/coverage/{i}"
        v.object(row, at, coverage_fields)
        if v.string(row["subject_id"], at + "/subject_id") not in COVERAGE_ORDER:
            v.fail(at + "/subject_id", "unknown retained coverage subject")
        if v.string(row["channel_id"], at + "/channel_id") not in (*CHANNEL_IDS, "multiple"):
            v.fail(at + "/channel_id", "unknown interaction channel")
        v.integer(row["authored_status"], at + "/authored_status", 0, 7)
        v.integer(row["evidence_status"], at + "/evidence_status", 0, 4)
        v.string(row["effective_rule_id"], at + "/effective_rule_id", empty=True)
        v.string(row["limitation"], at + "/limitation")
    v.unique(coverage, p + "/coverage", ("subject_id",))
    v.array(coverage, p + "/coverage", 10)

    tuning_passes = v.array(value["tuning_passes"], p + "/tuning_passes")
    for i, row in enumerate(tuning_passes):
        at = p + f"/tuning_passes/{i}"
        v.object(row, at, ("id", "version", "parent", "disposition", "changed_rules"))
        if v.string(row["id"], at + "/id") not in PASS_ORDER:
            v.fail(at + "/id", "unknown tuning pass; schema 1 admits no new semantics")
        v.integer(row["version"], at + "/version", 1, 4294967295)
        v.equal(row["parent"], "" if row["id"] == PASS_ORDER[0] else PASS_ORDER[0], at + "/parent")
        v.string(row["disposition"], at + "/disposition")
        v.string(row["changed_rules"], at + "/changed_rules")
    v.unique(tuning_passes, p + "/tuning_passes", ("id",))
    v.array(tuning_passes, p + "/tuning_passes", 2)

    # Preserve legacy consumer presentation order explicitly, without using
    # input-array order as a semantic or inheritance rule.
    result = dict(value)
    result.update(
        channels=sorted(channels, key=lambda row: row["channel"]),
        layer_kinds=sorted(layer_kinds, key=lambda row: row["kind"]),
        pairs=pairs,
        specialized=specialized,
        families=sorted(families, key=lambda row: FAMILY_ORDER.index(row["id"])),
        memberships=sorted(memberships, key=lambda row: (FAMILY_ORDER.index(row["family_id"]), row["material"])),
        coverage=sorted(coverage, key=lambda row: COVERAGE_ORDER.index(row["subject_id"])),
        tuning_passes=sorted(tuning_passes, key=lambda row: PASS_ORDER.index(row["id"])),
    )
    return result


def load_catalogue(source: Path = DEFAULT_SOURCE, *, isolated: bool = False) -> dict:
    """Read one strict source file and return normalized, validated shadow facts."""
    source = Path(source)
    v = _Validator(source)
    value = _read_json(source, v)
    v.object(value, "", ("schema_id", "schema_version", "scope", "native"))
    v.equal(value["schema_id"], SCHEMA_ID, "/schema_id")
    v.equal(value["schema_version"], SCHEMA_VERSION, "/schema_version")
    v.equal(value["scope"], "isolated-synthetic" if isolated else "current-shadow", "/scope")
    native = v.object(value["native"], "/native", ("identity", "materials", "capabilities", "appearance", "interactions"))
    materials = _material_records(native["materials"], v, "/native/materials", isolated)
    valid_ids = {row["id"] for row in materials if row["valid"]}
    identity = _identity(native["identity"], v, "/native/identity", isolated, valid_ids)
    capabilities = _capability_records(native["capabilities"], v, "/native/capabilities", isolated)
    appearance = _appearance_records(native["appearance"], v, "/native/appearance", isolated)
    # The isolated material tests explicit classification only; it cannot add
    # production interactions, aliases, family defaults or experimental exports.
    interactions = _interactions(native["interactions"], v, "/native/interactions", valid_ids - {132})

    participant_ids = {rule[key] for rule in interactions["pairs"] for key in ("first", "second")}
    material_origins = {row["id"]: f"/native/materials/{i}" for i, row in enumerate(native["materials"])}
    for i, cap in enumerate(native["capabilities"]):
        material_id = cap["id"]
        descriptor = materials[material_id] if material_id < len(materials) else materials[10]
        expected = {
            "valid": material_id in valid_ids,
            "current_rule": material_id in valid_ids and descriptor["current_rule_available"],
            "free_leveling_liquid": descriptor["lateral_flow"] == 1,
            "pair_participant": material_id in participant_ids,
        }
        for field, actual in expected.items():
            if cap[field] != actual:
                origin = "/native/interactions/pairs" if field == "pair_participant" else material_origins.get(material_id, material_origins[10])
                v.fail(f"/native/capabilities/{i}/{field}", "explicit capability contradicts its native owner", origin)
    for i, rule in enumerate(native["interactions"]["specialized"]):
        if rule["kernel"] != materials[rule["material"]]["kernel"]:
            v.fail(f"/native/interactions/specialized/{i}/kernel", "specialized provenance kernel contradicts its material descriptor", material_origins[rule["material"]] + "/kernel")
    return {
        "schema_id": SCHEMA_ID, "schema_version": SCHEMA_VERSION, "scope": value["scope"],
        "native": {"identity": identity, "materials": materials, "capabilities": capabilities,
                   "appearance": appearance, "interactions": interactions},
    }


def canonical_json(value: Any) -> bytes:
    """Stable UTF-8 JSON bytes; no timestamps, filesystem paths or locale."""
    return (json.dumps(value, ensure_ascii=False, allow_nan=False, sort_keys=True, indent=2) + "\n").encode("utf-8")


def _cpp_string(value: str) -> str:
    # Three-digit octal byte escapes avoid source-encoding and hex-run ambiguity.
    out = []
    for byte in value.encode("utf-8"):
        if byte == 34:
            out.append('\\"')
        elif byte == 92:
            out.append("\\\\")
        elif 32 <= byte <= 126:
            out.append(chr(byte))
        else:
            out.append(f"\\{byte:03o}")
    return '"' + "".join(out) + '"'


def _cpp_value(value: Any) -> str:
    if type(value) is bool:
        return "true" if value else "false"
    if type(value) is int:
        return str(value) + "U"
    if isinstance(value, str):
        return _cpp_string(value)
    if isinstance(value, list):
        return "{" + ", ".join(_cpp_value(child) for child in value) + "}"
    raise TypeError(f"unsupported validated C++ field: {type(value).__name__}")


def _render_cpp(catalogue: dict) -> bytes:
    native = catalogue["native"]
    interactions = native["interactions"]
    lines = [
        "// Generated by the schema-1 material catalogue compiler. Do not edit.",
        "// SHADOW ONLY: native-parity candidate, not a production or fallback definition.",
        "#pragma once", "", "#include <array>", "#include <cstdint>", "#include <string_view>", "",
        "namespace cybersand::material_catalogue_shadow {", "",
        f"inline constexpr std::uint32_t kSourceSchemaVersion = {SCHEMA_VERSION}U;",
        f"inline constexpr std::uint32_t kGeneratorVersion = {GENERATOR_VERSION}U;",
        f"inline constexpr std::string_view kScope = {_cpp_string(catalogue['scope'])};",
        "inline constexpr bool kProductionAuthority = false;", "",
    ]

    def table(name: str, struct_name: str, fields: tuple[tuple[str, str], ...], rows: list[dict]) -> None:
        lines.append(f"struct {struct_name} {{")
        lines.extend(f"    {kind} {field};" for field, kind in fields)
        lines.extend(["};", f"inline constexpr std::array<{struct_name}, {len(rows)}> {name}{{{{"])
        for row in rows:
            values = [row["namespace" if field == "namespace_id" else field] for field, _ in fields]
            lines.append("    {" + ", ".join(_cpp_value(value) for value in values) + "},")
        lines.extend(["}};", ""])

    byte, u16, u32, text = "std::uint8_t", "std::uint16_t", "std::uint32_t", "std::string_view"
    table("kMaterialDefinitions", "MaterialDefinition", (
        ("id", byte), ("name", text), ("state", byte), ("density", u16), ("rgba", "std::array<std::uint8_t, 4>"),
        ("movable", "bool"), ("valid", "bool"), ("current_rule_available", "bool"), ("kernel", byte),
        ("initial_state_a", byte), ("initial_state_b", byte), ("maximum_write_radius", byte),
        ("density_motion", byte), ("accepts_density_exchange", "bool"), ("lateral_flow", byte), ("viscosity_index", byte),
    ), native["materials"])
    lines.extend(["inline constexpr std::array<std::uint8_t, 1> kReservedIds{{10U}};", ""])
    table("kAliases", "MaterialAlias", (("namespace_id", text), ("name", text), ("target", byte)), native["identity"]["aliases"])
    table("kCapabilities", "MaterialCapabilities", tuple((field, byte if field == "id" else "bool") for field in CAPABILITY_FIELDS), native["capabilities"])
    lines.append("inline constexpr std::array<std::uint8_t, 256> kVisualStateSources{{")
    visual = [row["visual_state_source"] for row in native["appearance"]]
    for start in range(0, 256, 16):
        lines.append("    " + ", ".join(_cpp_value(x) for x in visual[start:start + 16]) + ",")
    lines.extend(["}};", ""])

    for variable, field in (
        ("kInteractionSchemaId", "schema_id"), ("kInteractionSchemaVersion", "schema_version"),
        ("kInteractionProfileId", "profile_id"), ("kInteractionProfileVersion", "profile_version"),
        ("kCurrentOraclePairRuleCount", "current_oracle_pair_rule_count"), ("kBuildingMaterialPassId", "building_material_pass_id"),
    ):
        value = interactions[field]
        lines.append(f"inline constexpr {text if isinstance(value, str) else u32} {variable} = {_cpp_value(value)};")
    lines.append("")
    table("kInteractionChannels", "InteractionChannelDefinition", (("channel", byte), ("id", text)), interactions["channels"])
    table("kInteractionLayerKinds", "InteractionLayerKindDefinition", (("kind", byte), ("id", text), ("precedence", u16)), interactions["layer_kinds"])
    table("kPairInteractionRules", "PairInteractionRule", (
        ("legacy_slot", u16), ("id", text), ("channels", u32), ("trigger", byte), ("match", byte),
        ("first", byte), ("second", byte), ("first_product", byte), ("second_product", byte),
        ("probability", byte), ("accounting", text), ("revalidation_tags", u32), ("version", u32),
        ("supersedes", text), ("tuning_pass_id", text),
    ), interactions["pairs"])
    table("kSpecializedInteractionRules", "SpecializedInteractionRule", (
        ("legacy_slot", u16), ("id", text), ("channels", u32), ("trigger", byte), ("material", byte),
        ("kernel", byte), ("authority_path", text), ("represented_semantics", text),
        ("revalidation_tags", u32), ("version", u32), ("supersedes", text), ("tuning_pass_id", text),
    ), interactions["specialized"])
    table("kSemanticFamilies", "SemanticFamilyDefinition", (("id", text), ("version", u32), ("purpose", text)), interactions["families"])
    table("kSemanticFamilyMemberships", "SemanticFamilyMembership", (("family_id", text), ("material", byte)), interactions["memberships"])
    table("kInteractionCoverage", "InteractionCoverageEntry", (
        ("subject_id", text), ("channel_id", text), ("authored_status", byte), ("evidence_status", byte),
        ("effective_rule_id", text), ("limitation", text),
    ), interactions["coverage"])
    table("kInteractionTuningPasses", "InteractionTuningPass", (
        ("id", text), ("version", u32), ("parent", text), ("disposition", text), ("changed_rules", text),
    ), interactions["tuning_passes"])
    lines.extend([
        "// No generic layer semantics are admitted by source schema 1.",
        "struct InteractionLayerDefinition {};",
        "inline constexpr std::array<InteractionLayerDefinition, 0> kInteractionLayerDefinitions{};",
        "", "}  // namespace cybersand::material_catalogue_shadow", "",
    ])
    return "\n".join(lines).encode("utf-8")


def _descriptor_contracts() -> dict:
    """Inspection-only ownership, never an effective-parameter merge or UI API."""
    entries = {
        "name": ("UTF-8 immutable native descriptor slug", None, None,
                 "Identity registry key; display labels and native enum aliases have separate namespaces."),
        "state": ("uint8 enum", [0, 5], "MaterialState",
                  "Broad native phase classification; does not select kernel, solver, family defaults or appearance."),
        "density": ("uint16", [0, 65535], None,
                    "Dimensionless comparison rank. Exchange also uses direction, target admission and source-specific exclusions; not calibrated physical density."),
        "rgba": ("four uint8 channels", [0, 255], None,
                 "Native base appearance tuple; does not replace Godot appearance programs or their floating-point arithmetic."),
        "movable": ("bool", None, None,
                    "Native descriptor flag; not a complete movement algorithm or a promise that the current cell will move."),
        "valid": ("bool", None, None,
                  "Immutable allocated-identity admission. Reserved slot 10 and unallocated IDs are invalid."),
        "current_rule_available": ("bool", None, None,
                                   "Native rule availability includes intentional inert RuleKernel::None; it does not mean always awake."),
        "kernel": ("uint8 enum", [0, 26], "RuleKernel",
                   "Named existing bounded native implementation, with specialized movement/state/scheduling still World-owned."),
        "initial_state_a": ("uint8 authored default", [0, 255], None,
                            "Material-specific default only. Runtime state_a is 16 bits; Water creation uses the applied native Water policy maximum on relevant paths."),
        "initial_state_b": ("uint8 authored default", [0, 255], None,
                            "Material-specific lifetime/burn/capture/heading state; not a universal retained-state policy."),
        "maximum_write_radius": ("uint8 descriptor radius", [0, 2], None,
                                 "Base kernel descriptor radius; selected IN has separately admitted applied radius 3 geometry."),
        "density_motion": ("uint8 enum", [0, 2], "DensityMotion",
                           "Opt-in native density-exchange direction; phase or visual similarity cannot infer it."),
        "accepts_density_exchange": ("bool", None, None,
                                     "Target-side native exchange permission; source direction and special pair exclusions still apply."),
        "lateral_flow": ("uint8 enum", [0, 2], "LateralFlowMode",
                         "Base descriptor mode. Applied liquid-family policy and specialized kernels remain separate owners."),
        "viscosity_index": ("uint8 dimensionless gameplay index", [0, 255], None,
                            "Generic yielding liquids consume this descriptor except Mercury's diagnostic override. Lava/Acid/Oil specialized movement does not consume it; Water-CY consumes its versioned material-block policy viscosity."),
    }
    return {
        field: {
            "owner": "native/include/cybersand/material.hpp::MaterialDefinition",
            "encoding": encoding,
            "bounds": bounds,
            "enum_domain": domain,
            "applicability": applicability,
            "change_boundary": "source-rebuild-required; no editing or application API admitted by this shadow compiler",
            "effective_runtime_value": False,
        }
        for field, (encoding, bounds, domain, applicability) in entries.items()
    }


def render_outputs(catalogue: dict) -> dict[str, bytes]:
    """Render a validated catalogue; no runtime dependency or source reads."""
    native = catalogue["native"]
    normalized = canonical_json(catalogue)
    source_digest = hashlib.sha256(normalized).hexdigest()
    inspection = {
        "schema_id": "cybersand.material-catalogue.inspection",
        "schema_version": MANIFEST_VERSION,
        "generator_version": GENERATOR_VERSION,
        "generator_sha256": GENERATOR_SHA256,
        "source_schema_version": SCHEMA_VERSION,
        "normalized_source_sha256": source_digest,
        "scope": catalogue["scope"],
        "authority": "shadow-only",
        "backend": "native",
        "production_consumer": None,
        "material_keys": [
            {"id": row["id"], "key": ("cybersand.synthetic.material." if catalogue["scope"] == "isolated-synthetic"
                                      else "cybersand.material.") + row["name"]}
            for row in native["materials"]
        ],
        "descriptor_field_contracts": _descriptor_contracts(),
        "validation_boundary": "Strict schema, bounds, references and local consistency are checked here; native source parity independently detects semantic metadata changes. Nothing applies these candidates to a World.",
        "enum_domains": ENUM_DOMAINS,
        "projection_contract": {
            "water_state_a": "active native Water policy normalized_mass; no authored float arithmetic",
            "other_state_a": "native uint8 truncation",
            "state_b": "native state_b byte",
            "unknown_id": 0,
        },
        "native": native,
    }
    gd = (
        "# Generated by the schema-1 material catalogue compiler. Do not edit.\n"
        "# SHADOW ONLY: native-parity metadata; not the GDScript fallback's physical definitions.\n"
        "extends RefCounted\n\n"
        f"const SOURCE_SCHEMA_VERSION: int = {SCHEMA_VERSION}\n"
        f"const GENERATOR_VERSION: int = {GENERATOR_VERSION}\n"
        "const PRODUCTION_AUTHORITY: bool = false\n"
        f"const SCOPE: String = {json.dumps(catalogue['scope'])}\n"
        "const BACKEND: String = \"native\"\n"
        "const NATIVE_FACTS: Dictionary = " + canonical_json(native).decode("utf-8")
    ).encode("utf-8")
    outputs = {"catalogue.shadow.hpp": _render_cpp(catalogue), "catalogue_shadow.gd": gd,
               "inspection.json": canonical_json(inspection)}
    manifest = {
        "schema_id": "cybersand.material-catalogue.output-manifest",
        "schema_version": MANIFEST_VERSION,
        "generator_version": GENERATOR_VERSION,
        "generator_sha256": GENERATOR_SHA256,
        "source_schema_version": SCHEMA_VERSION,
        "normalized_source_sha256": source_digest,
        "scope": catalogue["scope"],
        "authority": "shadow-only",
        "artifacts": [{"name": name, "sha256": hashlib.sha256(content).hexdigest(), "bytes": len(content)}
                      for name, content in sorted(outputs.items())],
    }
    outputs["manifest.json"] = canonical_json(manifest)
    return outputs


def _output_path(output: Path, isolated: bool) -> Path:
    if output.is_symlink():
        raise CatalogueError(f"{output}#/: output directory must not be a symlink")
    destination = output.resolve()
    inside_repository = destination.is_relative_to(REPO_ROOT)
    if isolated and inside_repository:
        raise CatalogueError(f"{output}#/: isolated synthetic output must be outside the repository")
    if inside_repository and destination != DEFAULT_OUTPUT:
        raise CatalogueError(
            f"{output}#/: the only repository output is materials/catalogue/generated; production paths are forbidden"
        )
    if destination.exists() and not destination.is_dir():
        raise CatalogueError(f"{output}#/: output must be a directory")
    return destination


def _publish(outputs: dict[str, bytes], destination: Path, *, check: bool) -> list[str]:
    """Validate the complete candidate before replacing its offline output set.

    A directory swap avoids a mixed set of generated files. Unchanged files use
    copy2 so their mtimes survive a change elsewhere. This is an offline tool,
    not a concurrent runtime publication API or a crash-durable transaction.
    """
    existing = set()
    if destination.exists():
        for path in destination.iterdir():
            if path.is_symlink() or not path.is_file():
                raise CatalogueError(f"{path}#/: output entries must be regular files, not links/directories")
            existing.add(path.name)
    unexpected = sorted(existing - outputs.keys())
    if unexpected:
        error = DriftError if check else CatalogueError
        raise error(f"{destination}#/: unexpected output entries: {', '.join(unexpected)}; preserved unchanged")
    changed = [
        name for name, content in sorted(outputs.items())
        if name not in existing or (destination / name).read_bytes() != content
    ]
    if check:
        if changed:
            raise DriftError(f"{destination}#/: generated artifact drift: {', '.join(changed)}")
        return []
    if not changed:
        return []

    destination.parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix=f".{destination.name}.stage-", dir=destination.parent))
    backup: Path | None = None
    published = False
    try:
        for name, content in sorted(outputs.items()):
            if name in existing and name not in changed:
                shutil.copy2(destination / name, stage / name)
            else:
                (stage / name).write_bytes(content)
        if destination.exists():
            backup = Path(tempfile.mkdtemp(prefix=f".{destination.name}.previous-", dir=destination.parent))
            backup.rmdir()
            os.replace(destination, backup)
        try:
            os.replace(stage, destination)
            published = True
        except OSError:
            if backup is not None:
                os.replace(backup, destination)
                backup = None
            raise
    finally:
        if stage.exists():
            shutil.rmtree(stage)
        if published and backup is not None and backup.exists():
            shutil.rmtree(backup)
    return changed


def compile_catalogue(
    source: Path = DEFAULT_SOURCE,
    output: Path = DEFAULT_OUTPUT,
    *,
    check: bool = False,
    isolated: bool = False,
) -> list[str]:
    """Return changed filenames, or raise before publication on invalid input."""
    catalogue = load_catalogue(Path(source), isolated=isolated)
    outputs = render_outputs(catalogue)
    destination = _output_path(Path(output), isolated)
    if Path(source).resolve().is_relative_to(destination):
        raise CatalogueError(f"{output}#/: output must not contain its input source {Path(source).resolve()}")
    return _publish(outputs, destination, check=check)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE, help="one explicit schema-1 catalogue JSON file")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT, help="shadow output directory; production paths are forbidden")
    parser.add_argument("--check", action="store_true", help="report artifact drift without writing anything")
    parser.add_argument("--isolated", action="store_true", help="allow one synthetic ID132 only, with output outside the repository")
    args = parser.parse_args(argv)
    try:
        changed = compile_catalogue(args.source, args.output, check=args.check, isolated=args.isolated)
    except (CatalogueError, OSError) as error:
        print(error, file=sys.stderr)
        return 1
    if args.check:
        print("shadow material catalogue matches authored source; production authority unchanged")
    else:
        print(f"shadow material catalogue: {len(changed)} changed artifacts; production authority unchanged")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
