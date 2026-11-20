#!/usr/bin/env python3
"""Check independently compiled pre/post captures before admitting oracle updates.

Usage: python3 classic-review-repair-check.py SNAPSHOT_ROOT REPOSITORY_ROOT
SNAPSHOT_ROOT/{before,after} must contain the native inputs, capture executables,
legacy.le16 and contacts written by classic-review-repair-oracle.cpp.
The existing e27 receipts remain immutable inputs, never rewritten by this tool.
"""
from __future__ import annotations

import collections
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import sys
import zipfile

REPAIRS = {"ring_pier", "tripod_frame", "cascade_terrace", "scalloped_vault",
           "suspended_deck", "buttress_wall"}
CLASSES = {"RingPier", "TripodFrame", "CascadeTerrace", "ScallopedVault",
           "SuspendedDeck", "ButtressWall"}
HEADER = b"CLASSIC72-LE16-v1\n"
CHUNK_BYTES = 16 + 64 * 64 * 2
PROFILE_BYTES = 8 + 4 * CHUNK_BYTES
MODULE_BYTES = 3 * PROFILE_BYTES


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def require(condition: bool, label: str) -> None:
    if not condition:
        raise AssertionError(label)


def components(cells: tuple[int, ...], width: int, height: int) -> list[int]:
    unseen = {index for index, material in enumerate(cells) if material}
    sizes = []
    while unseen:
        first = unseen.pop()
        queue = collections.deque([first])
        size = 0
        while queue:
            index = queue.popleft()
            size += 1
            x, y = index % width, index // width
            for neighbor in ((index - 1 if x else -1), (index + 1 if x + 1 < width else -1),
                             (index - width if y else -1), (index + width if y + 1 < height else -1)):
                if neighbor in unseen:
                    unseen.remove(neighbor)
                    queue.append(neighbor)
        sizes.append(size)
    return sorted(sizes, reverse=True)


def contact_proof(fixture: dict, before: bytes, after: bytes) -> dict:
    width, height = fixture["width"], fixture["height"]
    require(len(before) == len(after) == width * height * 2, "complete contact captures")
    old = struct.unpack(f"<{width * height}H", before)
    new = struct.unpack(f"<{width * height}H", after)
    module, bay, floor, wall = (fixture[key] for key in ("module", "bay", "floor", "wall"))
    label = fixture["file"]
    require(all(not a or b for a, b in zip(old, new)), label + ": no existing occupied cell removed")
    require(all((a == 121) == (b == 121) for a, b in zip(old, new)), label + ": exact glass mask retained")
    changes = [(index, a, b) for index, (a, b) in enumerate(zip(old, new)) if a != b]
    for index, a, b in changes:
        x, y = index % width, index // width
        if a:
            require(module == "tripod_frame" and a == 65 and b == 62 and y % floor >= floor - wall,
                    label + ": only Tripod foot contacts may become transfer deck")
        elif module in {"ring_pier", "cascade_terrace", "suspended_deck", "buttress_wall"}:
            require(b == 58, label + ": additions use structural shell material")
        elif module == "scalloped_vault":
            require(b == 65, label + ": additions retain the original rib material")
        else:
            require(b in {58,62,65}, label + ": additions use the three structural roles")
        if module == "ring_pier":
            require(abs(x % bay - bay // 2) <= wall, label + ": stems stay centred")
            column = [row for row in range(floor) if old[row * width + x % bay] == 65]
            require(column and (y % floor < min(column) or y % floor > max(column)),
                    label + ": ring void and original outline are untouched")
        if module == "cascade_terrace":
            require(x % bay >= bay - wall, label + ": only the rear support core is added")
    if module in {"suspended_deck", "buttress_wall"} and not fixture["windows"]:
        require(before == after, label + ": disabling glazing disables the added frame")
    old_components = components(old, width, height)
    new_components = components(new, width, height)
    require(len(new_components) == 1, label + ": all structure and glass face-connect across repeated tiers")
    require(any(material == 0 for material in new), label + ": useful negative space remains")
    return {**fixture, "before_sha256": sha(before), "after_sha256": sha(after),
            "changed_cells": len(changes), "added_cells": sum(a == 0 for _, a, _ in changes),
            "retained_glass_cells": old.count(121), "before_component_sizes": old_components,
            "after_component_sizes": new_components, "status": "pass"}


def legacy_profiles(snapshots: dict[str, bytes], ids: list[str]) -> dict:
    for data in snapshots.values():
        require(data.startswith(HEADER) and len(data) == len(HEADER) + len(ids) * MODULE_BYTES, "complete legacy encoding")
    legacy = {}
    for index, module in enumerate(ids):
        start = len(HEADER) + index * MODULE_BYTES
        old = snapshots["before"][start:start+MODULE_BYTES]
        new = snapshots["after"][start:start+MODULE_BYTES]
        if module not in REPAIRS:
            require(old == new, module + ": all cells, fingerprints and receipts remain byte-identical")
        profiles = []
        for profile in range(3):
            offset = profile * PROFILE_BYTES
            require(old[offset:offset+8] == new[offset:offset+8], module + ": recipe fingerprint preserved")
            material_bytes = {}
            for phase, data in (("before", old), ("after", new)):
                material_bytes[phase] = b"".join(data[offset+8+c*CHUNK_BYTES+16:offset+8+(c+1)*CHUNK_BYTES] for c in range(4))
            profiles.append({"profile": profile,
                             "before_material_sha256": sha(material_bytes["before"]),
                             "after_material_sha256": sha(material_bytes["after"]),
                             "exact_bytes_equal": old[offset:offset+PROFILE_BYTES] == new[offset:offset+PROFILE_BYTES]})
        legacy[module] = {"exact_bytes_equal": old == new, "before_sha256": sha(old), "after_sha256": sha(new), "profiles": profiles}
    return legacy


def main() -> None:
    work, root = map(Path, sys.argv[1:])
    evidence = root / "docs/images/gentek-80"
    old_receipt = json.loads((evidence / "classic-repaired-oracle.json").read_text())
    old_maps = json.loads((evidence / "megablock-repaired-parent-oracle.json").read_text())
    captured_identity = json.loads((work / "after/capture-identity.json").read_text())
    inputs = {phase: json.loads((work / phase / "native-inputs.json").read_text())
              for phase in ("before", "after")}
    require(inputs["before"] == old_receipt["source_inputs"], "the baseline is exactly retained repaired e27")
    for phase in ("before", "after"):
        for name, expected in inputs[phase].items():
            require(sha((work / phase / name).read_bytes()) == expected, phase + ": frozen source unchanged: " + name)
    definitions = {}
    for phase in ("before", "after"):
        text = (work / phase / "native/src/generation_architecture_classic.inc").read_text()
        definitions[phase] = dict(re.findall(r"class (\w+) final[^\n]*\n(.*?\n};)", text, re.S))
    require(len(definitions["before"]) == 72 and set(definitions["before"]) <= set(definitions["after"]),
            "all 72 class identities retained")
    require(set(definitions["after"]) - set(definitions["before"]) == {"CathedralMegaframe", "MegatrussStation"},
            "only the two already reconciled showcase classes are appended to this include")
    changed_classes = sorted(name for name in definitions["before"]
                             if definitions["before"][name] != definitions["after"][name])
    require(set(changed_classes) == CLASSES, "only six specifically reviewed classes differ")
    module_fnvs = {}
    for line in (work / "after/classic-repaired-oracle.txt").read_text().splitlines():
        module, value = line.split()
        module_fnvs[module] = f"0x{int(value, 16):016x}"
    combined = module_fnvs.pop("COMBINED")
    require(set(module_fnvs) == set(old_receipt["module_fnv1a64"]), "exact 72-module FNV inventory")
    corpus = {name: {"before_fnv1a64": f"0x{int(old,16):016x}", "after_fnv1a64": module_fnvs[name]}
              for name, old in old_receipt["module_fnv1a64"].items()}
    changed_corpus = sorted(name for name, pair in corpus.items() if pair["before_fnv1a64"] != pair["after_fnv1a64"])
    require(set(changed_corpus) <= REPAIRS, "no unreviewed module changed in the 72-style corpus")
    maps = {}
    for line in (work / "after/megablock-repaired-parent-oracle.txt").read_text().splitlines():
        identity, value, historical = line.split()
        require(int(historical,16) == int(old_maps["material_oracles"][identity]["historical_fnv1a64"],16),
                "retained original Megablock literal: " + identity)
        maps[identity] = {"before_fnv1a64": f"0x{int(old_maps['material_oracles'][identity]['repaired_fnv1a64'],16):016x}",
                          "after_fnv1a64": f"0x{int(value,16):016x}"}
    require(set(maps) == set(old_maps["material_oracles"]), "all 148 original profile identities retained")
    changed_maps = sorted(key for key, pair in maps.items() if pair["before_fnv1a64"] != pair["after_fnv1a64"])
    require(all(key.split(":")[0] in REPAIRS for key in changed_maps), "only reviewed profiles differ")
    ids = list(old_receipt["module_fnv1a64"]) + ["arcade-v1", "arcade-v2"]
    snapshots = {phase: (work / phase / "legacy.le16").read_bytes() for phase in ("before", "after")}
    legacy = legacy_profiles(snapshots, ids)
    rosework_snapshots = {phase: (work / phase / "legacy-rosework.le16").read_bytes() for phase in ("before", "after")}
    rosework_legacy = legacy_profiles(rosework_snapshots, ids)
    fixtures = json.loads((work / "before/contact-fixtures.json").read_text())
    require(fixtures == json.loads((work / "after/contact-fixtures.json").read_text()), "identical pre/post contact profiles")
    contacts = [contact_proof(f, *((work / phase / "contacts" / f["file"]).read_bytes()
                                 for phase in ("before", "after"))) for f in fixtures]
    receipt = {"schema_version": 1, "kind": "independent-review-repair-differential-oracle", "status": "pass",
               "baseline_source_commit": old_receipt["source_commit"],
               "candidate_head_at_capture": captured_identity["head"],
               "candidate_native_delta_at_capture": captured_identity["native_delta"], "source_inputs": inputs,
               "compiler": subprocess.check_output(["g++-14", "--version"], text=True).splitlines()[0],
               "approved_modules": sorted(REPAIRS), "changed_classes": changed_classes,
               "unmodified_classic_classes": 66,
               "capture_driver_sha256": sha((evidence / "classic-review-repair-oracle.cpp").read_bytes()),
               "checker_sha256": sha(Path(__file__).read_bytes()),
               "executables": {phase: sha((work / phase / "classic-review-repair-oracle").read_bytes()) for phase in ("before", "after")},
               "native_corpus_executables": {name: sha((work / "after" / name).read_bytes()) for name in
                    ("classic-repaired-oracle", "megablock-repaired-parent-oracle")},
               "native_corpus_drivers": {name: sha((work / "after" / (name + ".cpp")).read_bytes()) for name in
                    ("classic-repaired-oracle", "megablock-repaired-parent-oracle")},
               "classic72": {"before_combined_fnv1a64": old_receipt["combined_fnv1a64"], "after_combined_fnv1a64": combined,
                             "changed_modules": changed_corpus, "module_oracles": corpus},
               "megablock148": {"changed_profiles": changed_maps, "unchanged_profiles": 148-len(changed_maps), "material_oracles": maps},
               "qualifier_profiles": legacy, "rosework_qualifier_profiles": rosework_legacy,
               "qualifier_material_palettes": {"standard": [58,62,121,65], "rosework": [100,119,55,119]},
               "contact_cases": contacts,
               "historical_receipts_preserved": {name: sha((evidence / name).read_bytes()) for name in
                    ("classic-repaired-oracle.json", "megablock-repaired-parent-oracle.json")}}
    archive = evidence / "classic-review-repair-captures.zip"
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as package:
        for phase in ("before", "after"):
            paths = [work / phase / "legacy.le16", work / phase / "legacy-rosework.le16", work / phase / "contact-fixtures.json", work / phase / "native-inputs.json",
                     *sorted((work / phase / "contacts").glob("*.le16"))]
            for path in paths:
                info = zipfile.ZipInfo(str(path.relative_to(work)), date_time=(2026,11,20,0,0,0))
                info.compress_type = zipfile.ZIP_DEFLATED
                package.writestr(info, path.read_bytes(), compresslevel=9)
    receipt["raw_capture_archive"] = {"path": archive.name, "sha256": sha(archive.read_bytes()),
                                      "legacy_before_sha256": sha(snapshots["before"]), "legacy_after_sha256": sha(snapshots["after"]),
                                      "rosework_legacy_before_sha256": sha(rosework_snapshots["before"]),
                                      "rosework_legacy_after_sha256": sha(rosework_snapshots["after"])}
    (evidence / "classic-review-repair-oracle.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps({"status": "pass", "changed_classes": changed_classes, "classic72_changed": changed_corpus,
                      "combined": combined, "megablock148_changed": changed_maps, "contact_cases": len(contacts)}, indent=2))


if __name__ == "__main__":
    main()
