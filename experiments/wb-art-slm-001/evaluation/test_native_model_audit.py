#!/usr/bin/env python3
"""Adverse controls on immutable recovered real model/native evidence.

Never calls Godot or changes the original packet. Pass --fixture with the
extracted native_model_lfm400_attempt2 directory from the named evidence ZIP.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import tempfile
import shutil

from audit_model_replay import audit, build_aliases, load, sha


def run(fixture: Path) -> dict:
    provenance = fixture / "model-provenance"
    dev = provenance / "development-predictions.json"
    keywords = provenance / "keyword-predictions.json"
    original = provenance / "actual_model_native_cases.json"
    replay = fixture / "input-cases.json"
    alias = provenance / "case-id-mapping.json"
    baseline = audit([dev, keywords], original, replay, alias, fixture)
    assert (baseline["request_count"], baseline["first_pass_accepted"], baseline["native_request_yield"],
            baseline["native_seed_replays_passed"], baseline["symbolic_theme_primary_joint"]) == (36, 34, 34, 68, 32)
    checks = [{"name": "genuine frozen model/native fixture independently reconciles", "passed": True}]

    with tempfile.TemporaryDirectory(prefix="slm-audit-adverse-") as temporary:
        tmp = Path(temporary)
        # This genuinely constructs a fresh reversible ID-only case file, preserving original failure rows.
        new = tmp / "new-native-cases.json"
        mapped = tmp / "new-aliases.json"
        record = build_aliases(original, new, mapped)
        created = load(new)
        source = load(original)
        unchanged = all(({**old, "id": now["id"], "original_case_id": old["id"]} == now)
                        for old, now in zip(source["cases"], created["cases"]))
        assert unchanged and all(len(row["id"]) <= 38 for row in created["cases"])
        assert created["excluded_predictions"] == source["excluded_predictions"]
        assert sha(original) == record["original_manifest_sha256"]
        checks.append({"name": "ID-only alias creation preserves all raw programs, operations and exclusions", "passed": True})

        def adverse(name, changed_path, change, expected):
            dst = tmp / (name.replace(" ", "-") + ".json")
            data = load(changed_path)
            change(data)
            dst.write_text(json.dumps(data) + "\n")
            args = [[dev, keywords], original, replay, alias, fixture]
            if changed_path == dev:
                args[0] = [dst, keywords]
            elif changed_path == original:
                args = [args[0], dst, replay, alias, fixture]
            elif changed_path == alias:
                args = [args[0], original, replay, dst, fixture]
            refused = False
            try:
                audit(*args)
            except (ValueError, KeyError) as error:
                refused = expected in str(error)
            checks.append({"name": name, "passed": refused})

        adverse("reject changed exported source manifest", original,
                lambda d: d["cases"][0].update(prompt="tampered"), "Original exported manifest")
        adverse("reject altered original request completion", dev,
                lambda d: d["records"][0].update(completion='{"version":1}'), "exact raw request")
        adverse("reject EOS missing on accepted request", dev,
                lambda d: d["records"][0].update(eos_emitted=False), "Invalid/unterminated")
        adverse("reject false theme match flag", dev,
                lambda d: d["records"][0].update(theme_field_correct=False), "Theme field flag contradicts")
        adverse("reject wrong mapped geometry digest", alias,
                lambda d: d["cases"][0].update(operations_sha256="0"*64), "Alias map differs")
        adverse("reject duplicate mapped native case", alias,
                lambda d: d["cases"][1].update(replay_case_id=d["cases"][0]["replay_case_id"]), "duplicate alias")
        # Revoke one gate in a temporary packet copy, without modifying authentic evidence.
        copy = tmp / "altered-packet"
        shutil.copytree(fixture, copy)
        verified = copy / "verified-admission-receipts.json"
        evidence = load(verified)
        evidence["global_gates"]["stop_native_readback_exact"] = False
        verified.write_text(json.dumps(evidence))
        refused = False
        try:
            audit([dev, keywords], original, copy / "input-cases.json", alias, copy)
        except ValueError as error:
            refused = "globally passing" in str(error)
        checks.append({"name": "reject revoked independent Stop gate", "passed": refused})

    return {"passed": all(c["passed"] for c in checks), "controls": checks,
            "original_evidence_mutated": False, "native_engine_executed": False,
            "actual_pinned_native_packet_consulted": True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", required=True, type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = run(args.fixture)
    if args.output:
        if args.output.exists():
            raise FileExistsError("Refusing to overwrite prior adverse result")
        args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
