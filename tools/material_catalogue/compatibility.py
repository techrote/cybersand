#!/usr/bin/env python3
"""Read-only #353-A guards for the immutable legacy consumers.

This is a compatibility checkpoint, not a migration or a generic GDScript
interpreter. The retained source commit independently authenticates the lock.
Source changes need an explicitly reviewed new checkpoint; there is deliberately
no --accept, --refresh or automatic baseline update mode. A reviewed edit to one
protected consumer is admitted only by a code-pinned REVIEWED_TRANSITIONS entry,
authenticated against retained Git history; the lock itself never changes.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
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
# Files whose bytes are a retained identity: the inputs of the catalogue digest,
# capability digest and fallback facts, plus the policy identity generators,
# digest contract and retained oracles. Changing one is a cutover or identity
# transition, never a reviewed per-file transition.
IDENTITY_INPUTS = frozenset((
    *CATALOGUE_SOURCES,
    "docs/reference/liquid-solver-capability-matrix.json",
    "godot/scripts/cell_world.gd",
    "godot/scripts/interaction_policy.gd",
    "godot/scripts/material_appearance_lut.gd",
    "native/include/cybersand/liquid_policy_catalogue.hpp",
    "tools/lcb/policy_contract.py",
    "tools/lcb/native_policy_artifacts.py",
    "docs/reference/liquid-policy-wire-vectors.json",
    "docs/reference/water-normalization-vectors.json",
    "docs/reference/liquid-run-receipt-vectors.json",
))
TRANSITION_FIELDS = frozenset(("path", "from_lf_sha256", "to_lf_sha256", "source_commit",
                               "record", "issue", "pr"))
# Git variables that would redirect `git -C <repository>` to another repository
# or index (they are exported inside hooks and `git rebase -x`).
GIT_LOCATION_VARIABLES = frozenset(("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR",
                                    "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES",
                                    "GIT_NAMESPACE"))
# Owner-approved reviewed per-file transitions, in order. This is code, not lock
# data, so editing the lock alone can never admit one. Each step moves one
# protected, non-identity consumer from the hash it is currently admitted at (its
# baseline lock entry, or the previous step for that path) to the LF bytes of
# `path` at `source_commit`. That commit must descend from BASELINE (or from the
# previous step's commit) and stay reachable from HEAD, so a PR adding an entry
# must merge with a merge commit, not a squash or rebase. `record` is a Markdown
# record under docs/audits/, committed at HEAD, naming the path, both hashes and
# the commit. Working bytes must equal the final target after LF normalization; a
# further edit needs its own reviewed step. The table starts empty; each reviewed
# PR adds its own entry together with its source change.
REVIEWED_TRANSITIONS: tuple[dict, ...] = ({'path': 'native/src/world_pressure.inc',
  'from_lf_sha256': 'c8cb11512e935d05e099d8f155c1659473a7f61aa301e2e4900e55bdcfe4024b',
  'to_lf_sha256': 'd766e808e88287f3f9ef1b833d790106e56eb512654a350716c8573beb30a874',
  'source_commit': 'e5416b81bebf7ce79ac9894f7f9edf88f63b58da',
  'record': 'docs/audits/2026-11-04-lcb201-world-pressure-transition.md',
  'issue': 201,
  'pr': 382},
 {'path': 'native/src/world.cpp',
  'from_lf_sha256': 'b7a129f44eccc7c33dbd2f0d84802ab096140dcaa9b5b3a83d45dd3bf85fbad1',
  'to_lf_sha256': 'a47955f79ed5fbc8bc0ca8e2892ed4eb0ddbd728b841bc08ccee14a4c239e4a7',
  'source_commit': '1ca90de5181953f9ebd95ef19c920d8dee7e17e2',
  'record': 'docs/audits/2026-11-04-workbench394-material-source-transition.md',
  'issue': 391,
  'pr': 394},
 {'path': 'native/src/world_inertial.inc',
  'from_lf_sha256': 'f9e891dafa9c61e76460b5b3a720e3e522e7b63c381e81539e5e508b2719a0dd',
  'to_lf_sha256': '8a5d3680e96ca47a3f496be5a8b953084d2c6d2e0bd723c3214b87bdbc3580b5',
  'source_commit': '1ca90de5181953f9ebd95ef19c920d8dee7e17e2',
  'record': 'docs/audits/2026-11-04-workbench394-material-source-transition.md',
  'issue': 391,
  'pr': 394},
 {'path': 'native/src/world_pressure.inc',
  'from_lf_sha256': 'd766e808e88287f3f9ef1b833d790106e56eb512654a350716c8573beb30a874',
  'to_lf_sha256': '9977b8c49bfb523acf2f0abcedfc6cc99e2348c60e2bbbfeb29d1fc53738c1a8',
  'source_commit': 'd04fe009c2d5ab45f49a1d02cd36bb377f5d9873',
  'record': 'docs/audits/2026-11-04-workbench394-ready-validation.md',
  'issue': 391,
  'pr': 394},
 {'path': 'native/src/world_pressure.inc',
  'from_lf_sha256': '9977b8c49bfb523acf2f0abcedfc6cc99e2348c60e2bbbfeb29d1fc53738c1a8',
  'to_lf_sha256': '7b28bf216bf70af7059267cae31117f1f01e88d0e5f276f61d67280ab5c6d2e5',
  'source_commit': 'acce570e667c7e2cc3ef83ab451e7dff262006a9',
  'record': 'docs/audits/2026-11-04-workbench394-ready-validation.md',
  'issue': 391,
  'pr': 394},
 {'path': 'native/include/cybersand/quantity_ledger.hpp',
  'from_lf_sha256': '4345032e718b601a33ac3ffb69a456cd91bcf05ee3ab503650dcb7c06a59c6ad',
  'to_lf_sha256': 'd8c6463c7cea7193e8257115f6eddee911cc85467d5f2ab9be830f6ee7756a79',
  'source_commit': '30419bdac24902b47bab3756d3116008bec8f0ca',
  'record': 'docs/audits/2026-11-05-wcx-ballistic-water.md',
  'issue': 362,
  'pr': 406},
 {'path': 'native/src/world_quantity.inc',
  'from_lf_sha256': '627936a33c9ed58b6841f04466bf83aefe83b451ceb0da22baa19269ed5ef074',
  'to_lf_sha256': 'd9e6835d092193e4976c728d90121c6dee4b421337e056b5fc3c74975491af6e',
  'source_commit': '30419bdac24902b47bab3756d3116008bec8f0ca',
  'record': 'docs/audits/2026-11-05-wcx-ballistic-water.md',
  'issue': 362,
  'pr': 406},
 {'path': 'native/src/world.cpp',
  'from_lf_sha256': 'a47955f79ed5fbc8bc0ca8e2892ed4eb0ddbd728b841bc08ccee14a4c239e4a7',
  'to_lf_sha256': '93ab7874e913bf696ffcdb85724d01f860bbd53c160dd9b7ea3f8daf28026b85',
  'source_commit': '30419bdac24902b47bab3756d3116008bec8f0ca',
  'record': 'docs/audits/2026-11-05-wcx-ballistic-water.md',
  'issue': 362,
  'pr': 406},
 {'path': 'native/src/world_pressure.inc',
  'from_lf_sha256': '7b28bf216bf70af7059267cae31117f1f01e88d0e5f276f61d67280ab5c6d2e5',
  'to_lf_sha256': '21fade10be70387a41438586a3ca88c022af078e5ea11bc016ee20e7a9792573',
  'source_commit': '30419bdac24902b47bab3756d3116008bec8f0ca',
  'record': 'docs/audits/2026-11-05-wcx-ballistic-water.md',
  'issue': 362,
  'pr': 406},
 {'path': 'native/src/world_inertial.inc',
  'from_lf_sha256': '8a5d3680e96ca47a3f496be5a8b953084d2c6d2e0bd723c3214b87bdbc3580b5',
  'to_lf_sha256': '51fa78b33df7ea5e7e468c670b348ae24a19fd41905e2e78d9e841fa99af1491',
  'source_commit': '30419bdac24902b47bab3756d3116008bec8f0ca',
  'record': 'docs/audits/2026-11-05-wcx-ballistic-water.md',
  'issue': 362,
  'pr': 406},
 {'path': 'native/src/world_pressure.inc',
  'from_lf_sha256': '21fade10be70387a41438586a3ca88c022af078e5ea11bc016ee20e7a9792573',
  'to_lf_sha256': '8f7649cda6561eb6d44ebca5b11cfeec41210105bf7e0d20435ede4b03077012',
  'source_commit': 'f666a6c6e4a4e5fd4091129df463b59ef79acebd',
  'record': 'docs/audits/2026-11-05-wcx-ballistic-water.md',
  'issue': 362,
  'pr': 406},
 {'path': 'native/src/world.cpp',
  'from_lf_sha256': '93ab7874e913bf696ffcdb85724d01f860bbd53c160dd9b7ea3f8daf28026b85',
  'to_lf_sha256': '09685e01cdd7e2bb898f46ce3c9ab97b7427ac34e7568875a3bdfd7866190ac5',
  'source_commit': '6c69ba072f0507a3f6ee5966186fecb5070a45b2',
  'record': 'docs/audits/2026-11-06-workbench-pf-tick-cost.md',
  'issue': 362,
  'pr': 406},
 {'path': 'native/src/world_pressure.inc',
  'from_lf_sha256': '8f7649cda6561eb6d44ebca5b11cfeec41210105bf7e0d20435ede4b03077012',
  'to_lf_sha256': 'f89c9d6b6bcb1f4c76e2432ab4bc99ae22c45f0587aea0de33c06b21e13cac27',
  'source_commit': '6c69ba072f0507a3f6ee5966186fecb5070a45b2',
  'record': 'docs/audits/2026-11-06-workbench-pf-tick-cost.md',
  'issue': 362,
  'pr': 406},
 {'path': 'native/src/world_pressure.inc',
  'from_lf_sha256': 'f89c9d6b6bcb1f4c76e2432ab4bc99ae22c45f0587aea0de33c06b21e13cac27',
  'to_lf_sha256': 'af5bcaf27e4e7bd17d65279aaddb074359db20ff9c06cb5dfabf1a573e02be18',
  'source_commit': 'b4e78e5d425023156f1b8ca4b2ca4e2f81a2505a',
  'record': 'docs/audits/2026-11-06-workbench-pf-tick-cost.md',
  'issue': 362,
  'pr': 406},
 {'path': 'native/src/world.cpp',
  'from_lf_sha256': '09685e01cdd7e2bb898f46ce3c9ab97b7427ac34e7568875a3bdfd7866190ac5',
  'to_lf_sha256': 'a69a70332450ed246753457f85fcedfa0e3a36e848486e12c441a059c3574d1e',
  'source_commit': '35c1373ef31c8ed96fd9752eecbc3f129b34c5ba',
  'record': 'docs/audits/2026-11-06-whole-engine-bench.md',
  'issue': 362,
  'pr': 406},
 {'path': 'native/src/material_rules.cpp',
  'from_lf_sha256': '8fd1509bfcef162c5cb6028e9af38c563ad651822b9fcfcc2e79a569d185afa3',
  'to_lf_sha256': '3afda824571842e387b0cac70218ee5f1f96005d07aaaafcf95c146c3eee3254',
  'source_commit': '35c1373ef31c8ed96fd9752eecbc3f129b34c5ba',
  'record': 'docs/audits/2026-11-06-whole-engine-bench.md',
  'issue': 362,
  'pr': 406},
 {'path': 'native/src/world.cpp',
  'from_lf_sha256': 'a69a70332450ed246753457f85fcedfa0e3a36e848486e12c441a059c3574d1e',
  'to_lf_sha256': '3c90c5887800f75936a3e75c57030dcf4c7809640652ea2fc03f3e6b597ab654',
  'source_commit': '5fbf0a39c43a234fec2c092d52ea43066bf49335',
  'record': 'docs/audits/2026-11-06-stress-canvas.md',
  'issue': 362,
  'pr': 406},
 {'path': 'native/src/world.cpp',
  'from_lf_sha256': '3c90c5887800f75936a3e75c57030dcf4c7809640652ea2fc03f3e6b597ab654',
  'to_lf_sha256': '97e605b556c178f6169c1c89fff49041d5640b8fb0f728a6fc3d6c43506f4f00',
  'source_commit': 'fd061dd098d2e4b277141b76ada7f4b340e02e97',
  'record': 'docs/audits/2026-11-06-pf-ballistic-tick-cost.md',
  'issue': 362,
  'pr': 406},
 {'path': 'native/src/world_pressure.inc',
  'from_lf_sha256': 'af5bcaf27e4e7bd17d65279aaddb074359db20ff9c06cb5dfabf1a573e02be18',
  'to_lf_sha256': '894068b587b17b215c993d0eea5c5f14a8a818d4c1430c246f13bdec66653738',
  'source_commit': 'fd061dd098d2e4b277141b76ada7f4b340e02e97',
  'record': 'docs/audits/2026-11-06-pf-ballistic-tick-cost.md',
  'issue': 362,
  'pr': 406},
 {'path': 'native/src/world.cpp',
  'from_lf_sha256': '97e605b556c178f6169c1c89fff49041d5640b8fb0f728a6fc3d6c43506f4f00',
  'to_lf_sha256': '5f510058ae43c8dcf6adc2df62b7fde580d5f509012c8c7a358a54f2a7dc2129',
  'source_commit': '481011090a9a56fb06311144b5bfb26f8f1028a4',
  'record': 'docs/audits/2026-11-06-pf-ballistic-tick-cost.md',
  'issue': 362,
  'pr': 406},
 {'path': 'native/src/world.cpp',
  'from_lf_sha256': '5f510058ae43c8dcf6adc2df62b7fde580d5f509012c8c7a358a54f2a7dc2129',
  'to_lf_sha256': '5a9de5e09a8665392677902ab501696aafefb5bbd2d2800e3dc1059b87a6f17d',
  'source_commit': '0b408ae97c061d7263a3322022429aa32a0385a6',
  'record': 'docs/audits/2026-11-06-pf-ballistic-tick-cost.md',
  'issue': 362,
  'pr': 406},
 {'path': 'native/src/world_pressure.inc',
  'from_lf_sha256': '894068b587b17b215c993d0eea5c5f14a8a818d4c1430c246f13bdec66653738',
  'to_lf_sha256': '26051b0d10ab10d65db822c993742e0a0bf13711f3bd56158e95d77735737aca',
  'source_commit': 'a2373e12fb87d8d5b28efcc6037316fb6f605a14',
  'record': 'docs/audits/2026-11-06-pf-ballistic-tick-cost.md',
  'issue': 362,
  'pr': 406},
 {'path': 'native/src/world.cpp',
  'from_lf_sha256': '5a9de5e09a8665392677902ab501696aafefb5bbd2d2800e3dc1059b87a6f17d',
  'to_lf_sha256': 'd743ca60406fc8f220206e005b37996f1d182005b1b86e0ed6591f050608fe1c',
  'source_commit': '51d462537480324a4c11b3bf92f1ecb1882d8685',
  'record': 'docs/audits/2026-11-06-hard-surface-packet-incremental.md',
  'issue': 362,
  'pr': 470},
 {'path': 'native/src/world.cpp',
  'from_lf_sha256': 'd743ca60406fc8f220206e005b37996f1d182005b1b86e0ed6591f050608fe1c',
  'to_lf_sha256': '8bf0cb0058b139c32c030f5bbbc7e7e4555814c601598e1d6c7abecf7397d7fb',
  'source_commit': '9ad76b21854b3e44fc9444f8293d3c36c619746b',
  'record': 'docs/audits/2026-11-06-hard-surface-packet-incremental.md',
  'issue': 362,
  'pr': 470},
 {'path': 'native/src/world.cpp',
  'from_lf_sha256': '8bf0cb0058b139c32c030f5bbbc7e7e4555814c601598e1d6c7abecf7397d7fb',
  'to_lf_sha256': 'e23935738a1424b6e0009ae935e6f79fdc0d56c4162766061acb0ae2ec3de6ee',
  'source_commit': '484b48f67ba4db68b1b4c73cd63f1a187594523d',
  'record': 'docs/audits/2026-11-07-pf471-world-transition-proposal.md',
  'issue': 492,
  'pr': 471})


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


def git_environment() -> dict[str, str]:
    """The caller's environment without variables that redirect `git -C`."""
    return {key: value for key, value in os.environ.items() if key not in GIT_LOCATION_VARIABLES}


def retained_sources(repository: Path = ROOT) -> dict[str, bytes]:
    sources = {}
    for path in SOURCE_ROLES:
        try:
            result = subprocess.run(["git", "-C", str(repository), "show", f"{BASELINE}:{path}"],
                                    check=True, capture_output=True, timeout=30, env=git_environment())
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


def _git(repository: Path, *arguments: str) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(["git", "-C", str(repository), *arguments],
                              capture_output=True, timeout=30, env=git_environment())
    except (OSError, subprocess.SubprocessError) as exc:
        raise CompatibilityError(f"git {' '.join(arguments)}: {exc}") from exc


def _stderr(result: subprocess.CompletedProcess) -> str:
    return result.stderr.decode("utf-8", errors="replace").strip()


def _is_ancestor(repository: Path, older: str, newer: str) -> bool:
    result = _git(repository, "merge-base", "--is-ancestor", older, newer)
    if result.returncode not in (0, 1):
        raise CompatibilityError(f"cannot resolve ancestry {older} -> {newer} in {repository}; "
                                 f"complete retained Git history required: {_stderr(result)}")
    return result.returncode == 0


def admitted_transitions(lock: dict, transitions, repository: Path = ROOT) -> dict[str, str]:
    """Authenticate reviewed transitions; return each moved path's admitted LF hash.

    Every rule fails closed. Nothing here can change the lock, a baseline hash,
    an identity input or a path without a committed review record.
    """
    if not isinstance(transitions, (tuple, list)):
        raise CompatibilityError("REVIEWED_TRANSITIONS: expected an ordered sequence")
    admitted = {entry["path"]: entry["lf_sha256"] for entry in lock["source_locks"]}
    base_commit: dict[str, str] = {}
    targets: dict[str, str] = {}
    for index, entry in enumerate(transitions):
        where = f"REVIEWED_TRANSITIONS[{index}]"
        if not isinstance(entry, dict) or set(entry) != TRANSITION_FIELDS:
            raise CompatibilityError(f"{where}: expected exactly {sorted(TRANSITION_FIELDS)}")
        name, commit, record = entry["path"], entry["source_commit"], entry["record"]
        if type(name) is not str or name not in SOURCE_ROLES:
            raise CompatibilityError(f"{where}: {name!r} is not a protected consumer")
        if name in IDENTITY_INPUTS:
            raise CompatibilityError(f"{where}: {name} feeds a retained identity; "
                                     "changing it is a cutover, not a reviewed transition")
        for key in ("from_lf_sha256", "to_lf_sha256"):
            if type(entry[key]) is not str or not re.fullmatch(r"[0-9a-f]{64}", entry[key]):
                raise CompatibilityError(f"{where}: {key}: expected a lowercase SHA-256")
        if type(commit) is not str or not re.fullmatch(r"[0-9a-f]{40}", commit):
            raise CompatibilityError(f"{where}: source_commit: expected a full lowercase commit ID")
        for key in ("issue", "pr"):
            if type(entry[key]) is not int or entry[key] <= 0:
                raise CompatibilityError(f"{where}: {key}: expected a positive integer")
        if (type(record) is not str or not re.fullmatch(r"docs/audits/[A-Za-z0-9._/-]+\.md", record)
                or ".." in record.split("/")):
            raise CompatibilityError(f"{where}: record: expected a Markdown path under docs/audits/")
        if entry["from_lf_sha256"] != admitted[name]:
            raise CompatibilityError(f"{where}: {name}: from_lf_sha256 must equal the currently "
                                     f"admitted {admitted[name]}")
        if entry["to_lf_sha256"] == entry["from_lf_sha256"]:
            raise CompatibilityError(f"{where}: {name}: a transition must change the bytes")
        parent = base_commit.get(name, BASELINE)
        if not _is_ancestor(repository, parent, commit):
            raise CompatibilityError(f"{where}: source_commit {commit} does not descend from {parent}")
        if not _is_ancestor(repository, commit, "HEAD"):
            raise CompatibilityError(
                f"{where}: source_commit {commit} is not retained in HEAD's history. Merge a PR that adds "
                "an entry with a merge commit, not a squash or rebase. If one already landed that way, a "
                "reviewed follow-up must point source_commit at the merged commit that holds these bytes "
                "and update the record")
        shown = _git(repository, "show", f"{commit}:{name}")
        if shown.returncode:
            raise CompatibilityError(f"{where}: cannot read {commit}:{name}: {_stderr(shown)}")
        if sha(shown.stdout) != entry["to_lf_sha256"]:
            raise CompatibilityError(f"{where}: {name}: to_lf_sha256 is not the authenticated bytes at {commit}")
        written = _git(repository, "show", f"HEAD:{record}")
        if written.returncode:
            raise CompatibilityError(f"{where}: record {record} is not committed at HEAD")
        text = written.stdout.decode("utf-8", errors="replace")
        for fact in (name, entry["from_lf_sha256"], entry["to_lf_sha256"], commit):
            if fact not in text:
                raise CompatibilityError(f"{where}: record {record} does not name {fact}")
        admitted[name] = targets[name] = entry["to_lf_sha256"]
        base_commit[name] = commit
    return targets


def check(root: Path = ROOT, lock_path: Path | None = None,
          baseline_repository: Path = ROOT, transitions=None) -> dict:
    path = lock_path or root / LOCK
    actual_lock = read_lock(path)
    baseline = retained_sources(baseline_repository)
    expected_lock = build_lock(baseline)
    for key in expected_lock:
        if _canonical(actual_lock[key]) != _canonical(expected_lock[key]):
            raise CompatibilityError(f"{path}: /{key}: differs from immutable {BASELINE}; "
                                     "do not refresh away a compatibility failure")
    reviewed = REVIEWED_TRANSITIONS if transitions is None else transitions
    targets = admitted_transitions(actual_lock, reviewed, baseline_repository)
    current = {}
    for source in actual_lock["source_locks"]:
        name = source["path"]
        try:
            current[name] = (root / name).read_bytes()
        except OSError as exc:
            raise CompatibilityError(f"{name}: required legacy consumer unavailable: {exc}") from exc
        actual = sha(current[name])
        if name in targets and actual != targets[name]:
            raise CompatibilityError(f"{name}: LF source-byte drift ({source['role']}); expected reviewed "
                                     f"transition target {targets[name]}, got {actual}. "
                                     "A further edit needs its own reviewed transition")
        if name not in targets and actual != source["lf_sha256"]:
            raise CompatibilityError(f"{name}: LF source-byte drift ({source['role']}); "
                                     f"expected {source['lf_sha256']}, got {actual}. "
                                     "#353-A preserves this consumer; cutover/identity transition needs separate review "
                                     "(a behaviour-preserving edit may use a reviewed REVIEWED_TRANSITIONS entry)")
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
            "reviewed_transitions": copy.deepcopy(list(reviewed)),
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
