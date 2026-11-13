"""Build grouped reference data, then admit it using native replay receipts.

Generation never labels its own output as executed. Text paraphrases may share
one exact program/seed/native trace; the manifest reports both counts.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "controls"))
from pattern_compiler import (COMPILER_VERSION, THEMES, canonical_json,
                              compile_with_report, make_program,
                              structural_signature, validate_program)

CORPUS_VERSION = "wb-art-slm-001/bootstrap-v1"
MODIFIER_SETS = ((), ("sparse",), ("dense",), ("thin",), ("thick",),
                 ("twisted",), ("sparse", "thin"), ("dense", "twisted"))
SYNONYMS = {
    "roots": "branching root systems", "coral": "fan-shaped coral growth",
    "veins": "connected vein networks", "mycelium": "wandering fungal threads",
    "strata": "faulted geological layers", "dunes": "wind-swept dune ridges",
    "crystals": "clusters of crystal facets", "honeycomb": "hexagonal honeycomb cells",
    "labyrinth": "a winding maze", "ruins": "broken architectural ruins",
    "circuitry": "orthogonal circuit traces", "ribs": "paired rib-like structures",
}
LAYOUT_WORDS = {
    "center": ("centered in the focus", "across the middle"),
    "offset": ("offset toward the upper left", "leaving more space to the right and below"),
    "split": ("as a mirrored pair", "with bilateral symmetry in two panels"),
    "border": ("around an open center", "in border strips with a central void"),
}
MODIFIER_WORDS = {
    "sparse": ("sparse", "with fewer elements"),
    "dense": ("dense", "with many closely packed elements"),
    "thin": ("thin", "with fine strokes"),
    "thick": ("thick", "with heavy strokes"),
    "twisted": ("twisted", "tilted by twenty-two degrees"),
}


def sha(value: object) -> str:
    return hashlib.sha256(canonical_json(value).encode()).hexdigest()


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False, allow_nan=False) + "\n")


def write_jsonl(path: Path, values: list[dict]) -> None:
    path.write_text("".join(canonical_json(x) + "\n" for x in values))


def split_for(theme_index: int, variant: int) -> str:
    # Exact one-word center recipes always belong to training. A different
    # layout is held out per theme; each layout is still taught on other themes.
    # This is a theme/layout/template holdout, not unseen primitive morphology.
    held_layout = (1, 2, 3)[theme_index % 3]
    if variant % 4 != held_layout:
        return "train"
    is_composed = variant >= 4
    return "dev" if is_composed == bool(theme_index % 2) else "final"


def prompt_for(theme: str, variant: int, modifiers: tuple[str, ...], form: int) -> str:
    if variant == 0 and not modifiers and form == 0:
        return theme
    layout = ("center", "offset", "split", "border")[variant % 4]
    if form == 0:
        adjectives = " ".join(modifiers)
        subject = f"{adjectives} {theme}".strip()
        ending = "; add its complementary detail layer" if variant >= 4 else ""
        return f"Create {subject}, {LAYOUT_WORDS[layout][0]}{ending}."
    qualifier = ", ".join(MODIFIER_WORDS[m][1] for m in modifiers)
    qualifier = ", " + qualifier if qualifier else ""
    detail = ". Include a fine secondary motif along the border" if variant >= 4 else ""
    return f"Make {SYNONYMS[theme]} {LAYOUT_WORDS[layout][1]}{qualifier}{detail}."


def build(out: Path) -> dict:
    out.mkdir(parents=True, exist_ok=True)
    cases: list[dict] = []
    records: list[dict] = []
    groups: dict[str, dict] = {}
    gallery_ids: list[str] = []
    pilot_ids: list[str] = []
    for ti, theme in enumerate(THEMES):
        for variant in range(8):
            split = split_for(ti, variant)
            for mi, modifiers in enumerate(MODIFIER_SETS):
                program = make_program(theme, variant, list(modifiers))
                signature = structural_signature(program)
                group_id = theme + ":" + sha(signature)[:16]
                previous = groups.get(group_id)
                if previous and previous["split"] != split:
                    raise ValueError("effective structural group crosses splits")
                groups[group_id] = {"group_id": group_id, "theme": theme,
                                    "signature": signature, "split": split}
                seed = 17 if mi == 0 else 101 + mi * 37
                report = compile_with_report(program, 96, 96, seed)
                case_id = f"{theme}-v{variant}-m{mi}-s{seed}"
                case = {"id": case_id, "kind": "teacher", "theme": theme,
                        "split": split, "group_id": group_id, "variant": variant,
                        "modifiers": list(modifiers), "program": program,
                        "operations_sha256": sha(report["operations"]), **report}
                cases.append(case)
                if mi == 0:
                    gallery_ids.append(case_id)
                    other = compile_with_report(program, 96, 96, 73)
                    second = {**case, **other, "id": f"{theme}-v{variant}-m0-s73",
                              "operations_sha256": sha(other["operations"])}
                    cases.append(second)
                    gallery_ids.append(second["id"])
                if theme in ("roots", "coral", "strata", "labyrinth") and variant in (0, 4) and mi in (0, 1):
                    pilot_ids.append(case_id)
                    if mi == 0:
                        pilot_ids.append(second["id"])
                for form in range(2):
                    records.append({"id": case_id + f"-p{form}", "split": split,
                                    "prompt": prompt_for(theme, variant, modifiers, form),
                                    "completion": canonical_json(program), "theme": theme,
                                    "group_id": group_id, "seed": seed, "width": 96,
                                    "height": 96, "material": 58,
                                    "native_case_id": case_id,
                                    "program_sha256": report["program_sha256"],
                                    "operations_sha256": case["operations_sha256"],
                                    "origin": "deterministic-reference-teacher",
                                    "native_qualified": False})
    # 24 initial four-theme cases plus eight more centered defaults give a
    # bounded 32-case smoke that contains an exact-keyword case for every theme.
    pilot_ids += [f"{t}-v0-m0-s17" for t in THEMES
                  if t not in ("roots", "coral", "strata", "labyrinth")]
    assert len(pilot_ids) == 32
    validate_splits(records)
    compiler_path = ROOT / "controls" / "pattern_compiler.py"
    manifest = {
        "corpus_version": CORPUS_VERSION, "compiler_version": COMPILER_VERSION,
        "compiler_sha256": hashlib.sha256(compiler_path.read_bytes()).hexdigest(),
        "state": "native-replay-pending", "record_count": len(records),
        "distinct_native_cases": len(cases), "gallery_count": len(gallery_ids),
        "pilot_count": len(pilot_ids), "split_counts": dict(Counter(r["split"] for r in records)),
        "group_counts": dict(Counter(g["split"] for g in groups.values())),
        "theme_counts": dict(Counter(r["theme"] for r in records)),
        "groups": list(groups.values()), "records_sha256": sha(records),
        "cases_sha256": sha(cases), "gallery_case_ids": gallery_ids,
        "pilot_case_ids": pilot_ids,
        "split_claim": "Disjoint theme/motif/layout structural groups and exact programs; all compiler primitives shared. Seeds are replay variation, not additional independent templates.",
        "positive_admission": "Only successful native receipts plus explicit visual-review admission create train/dev files. Final is sequestered from training and development.",
    }
    write_jsonl(out / "candidates.jsonl", records)
    write_json(out / "native_cases.json", {"manifest": {k: manifest[k] for k in ("corpus_version", "compiler_version", "compiler_sha256")}, "cases": cases})
    for filename, ids in (("pilot_cases.json", pilot_ids), ("gallery_cases.json", gallery_ids)):
        selected = set(ids)
        write_json(out / filename, {"cases": [c for c in cases if c["id"] in selected]})
    write_json(out / "manifest.json", manifest)
    return manifest


def validate_splits(records: list[dict]) -> None:
    groups, programs, prompts, ids = {}, {}, {}, set()
    for row in records:
        if row["id"] in ids:
            raise ValueError("duplicate record ID")
        ids.add(row["id"])
        validate_program(json.loads(row["completion"]))
        for seen, key in ((groups, row["group_id"]),
                          (programs, row["program_sha256"]),
                          (prompts, row["prompt"].strip().lower())):
            if key in seen and seen[key] != row["split"]:
                raise ValueError("structural group, program or prompt leaked across split")
            seen[key] = row["split"]


def validate_candidate_bindings(out: Path, candidates: list[dict], native_cases: list[dict]) -> dict:
    """Bind the exact trained completion to the geometry that was executed."""
    manifest = json.loads((out / "manifest.json").read_text())
    compiler_hash = hashlib.sha256((ROOT / "controls" / "pattern_compiler.py").read_bytes()).hexdigest()
    if compiler_hash != manifest["compiler_sha256"]:
        raise ValueError("compiler source changed after corpus generation")
    if sha(candidates) != manifest["records_sha256"] or sha(native_cases) != manifest["cases_sha256"]:
        raise ValueError("candidate or native-case manifest hash mismatch")
    by_case = {c["id"]: c for c in native_cases}
    if len(by_case) != len(native_cases):
        raise ValueError("duplicate native case ID")
    cache = {}
    for row in candidates:
        program = json.loads(row["completion"])
        validate_program(program)
        if sha(program) != row["program_sha256"] or row["theme"] != program["theme"]:
            raise ValueError("completion/program hash or theme mismatch")
        expected_group = row["theme"] + ":" + sha(structural_signature(program))[:16]
        if expected_group != row["group_id"]:
            raise ValueError("completion/structural group mismatch")
        case = by_case.get(row["native_case_id"])
        if case is None or case["program"] != program or case["split"] != row["split"] or case["group_id"] != row["group_id"]:
            raise ValueError("completion is not the native case that was executed")
        context = (row["program_sha256"], row["width"], row["height"], row["seed"], row["material"])
        if context not in cache:
            cache[context] = compile_with_report(program, row["width"], row["height"], row["seed"], row["material"])
        report = cache[context]
        if any(row[k] != case[k] for k in ("width", "height", "seed", "material")):
            raise ValueError("native host context mismatch")
        if (sha(report["operations"]) != row["operations_sha256"]
                or report["operations"] != case["operations"]
                or row["operations_sha256"] != case["operations_sha256"]):
            raise ValueError("completion does not compile to acknowledged operations")
    validate_splits(candidates)
    return manifest


def admit(out: Path, receipts_path: Path, review_path: Path, allow_partial: bool) -> dict:
    """Receipt adapter consumes normalized evidence, never inferred success.

    Input {runtime:{source_commit,native_sha256,godot_version},cases:[...]};
    each case needs id,success,operations_sha256,image_sha256,readback_sha256,
    outside_focus_violations=0 and acknowledged_cells>0. A reviewer supplies
    {reviewed_case_ids:[...],accepted_group_ids:[...],notes:...}. Group admission
    is a pilot review label and is explicitly weaker than viewing every image.
    """
    receipts = json.loads(receipts_path.read_text())
    review = json.loads(review_path.read_text())
    if receipts.get("passed") is not True:
        raise ValueError("native run's global gates or custody checks did not pass")
    runtime = receipts["runtime"]
    for field in ("source_commit", "native_sha256", "godot_version"):
        if not runtime.get(field):
            raise ValueError("missing native runtime provenance: " + field)
    if not re.fullmatch(r"[a-f0-9]{40}", runtime["source_commit"]) or not re.fullmatch(r"[a-f0-9]{64}", runtime["native_sha256"]):
        raise ValueError("source and native identities must be full hashes")
    evidence = {r["id"]: r for r in receipts["cases"]}
    if len(evidence) != len(receipts["cases"]):
        raise ValueError("duplicate native receipt ID")
    accepted = set(review["accepted_group_ids"])
    reviewed = set(review["reviewed_case_ids"])
    if not reviewed or not accepted or not review.get("notes"):
        raise ValueError("visual review must be explicit")
    candidates = [json.loads(line) for line in (out / "candidates.jsonl").read_text().splitlines()]
    native_cases = json.loads((out / "native_cases.json").read_text())["cases"]
    manifest = validate_candidate_bindings(out, candidates, native_cases)
    by_case = {r["id"]: r for r in native_cases}
    if not reviewed <= by_case.keys():
        raise ValueError("visual review contains an unknown native case")
    for case_id in reviewed:
        representative = evidence.get(case_id, {})
        if (representative.get("success") is not True
                or representative.get("operations_sha256") != by_case[case_id]["operations_sha256"]
                or representative.get("outside_focus_violations") != 0
                or representative.get("unexpected_material_cells") != 0
                or not re.fullmatch(r"[a-f0-9]{64}", representative.get("image_sha256", ""))
                or not re.fullmatch(r"[a-f0-9]{64}", representative.get("readback_sha256", ""))):
            raise ValueError("reviewed representative has no matching successful native image")
    inspected_groups = {by_case[key]["group_id"] for key in reviewed}
    if not accepted <= inspected_groups:
        raise ValueError("every admitted group needs an inspected representative")
    missing = []
    admitted = []
    for row in candidates:
        receipt = evidence.get(row["native_case_id"], {})
        passed = (receipt.get("success") is True
                  and receipt.get("operations_sha256") == row["operations_sha256"]
                  and receipt.get("outside_focus_violations") == 0
                  and receipt.get("unexpected_material_cells") == 0
                  and type(receipt.get("acknowledged_cells")) is int
                  and receipt.get("acknowledged_cells", 0) > 0
                  and re.fullmatch(r"[a-f0-9]{64}", receipt.get("image_sha256", ""))
                  and re.fullmatch(r"[a-f0-9]{64}", receipt.get("readback_sha256", ""))
                  and row["group_id"] in accepted)
        if not passed:
            missing.append(row["id"])
            continue
        admitted.append({**row, "native_qualified": True,
                         "native_runtime": runtime,
                         "native_receipt": receipt,
                         "visual_review": "case-inspected" if row["native_case_id"] in reviewed else "template-group-pilot-admitted"})
    if missing and not allow_partial:
        raise ValueError(f"{len(missing)} records lack execution or review admission; use --allow-partial for a declared pilot")
    if not admitted:
        raise ValueError("no positively admitted records")
    validate_splits(admitted)
    for split in ("train", "dev", "final"):
        write_jsonl(out / (split + ".jsonl"), [r for r in admitted if r["split"] == split])
    summary = {"corpus_version": CORPUS_VERSION,
               "corpus_manifest_sha256": hashlib.sha256((out / "manifest.json").read_bytes()).hexdigest(),
               "compiler_sha256": manifest["compiler_sha256"],
               "state": "partial-native-pilot" if missing else "native-qualified-bootstrap",
               "admitted_records": len(admitted), "excluded_records": len(missing),
               "distinct_admitted_native_traces": len({r["native_case_id"] for r in admitted}),
               "split_counts": dict(Counter(r["split"] for r in admitted)),
               "runtime": runtime, "receipts_sha256": hashlib.sha256(receipts_path.read_bytes()).hexdigest(),
               "review_sha256": hashlib.sha256(review_path.read_bytes()).hexdigest(),
               "excluded_ids": missing,
               "file_sha256": {s: hashlib.sha256((out / (s + ".jsonl")).read_bytes()).hexdigest() for s in ("train", "dev", "final")}}
    write_json(out / "admission.json", summary)
    return summary


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("build", "admit"))
    parser.add_argument("--out", type=Path, default=Path(__file__).parent)
    parser.add_argument("--receipts", type=Path)
    parser.add_argument("--review", type=Path)
    parser.add_argument("--allow-partial", action="store_true")
    args = parser.parse_args()
    if args.command == "build":
        result = build(args.out)
    else:
        if not args.receipts or not args.review:
            parser.error("admit requires --receipts and --review")
        result = admit(args.out, args.receipts, args.review, args.allow_partial)
    print(json.dumps({k: v for k, v in result.items() if k not in ("groups", "excluded_ids", "gallery_case_ids", "pilot_case_ids")}, indent=2))


if __name__ == "__main__":
    main()
