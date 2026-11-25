#!/usr/bin/env python3
"""Read-only mergedown snapshot: immutable PR metadata plus local Git ancestry.

This evidence helper never fetches, changes refs, merges, or grants acceptance.
Run with an explicit captured metadata file, accepted-main SHA, and output path.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess


PRIORITY = {736: 1, 758: 2, 771: 3, 778: 3, 772: 4, 775: 5,
            781: 6, 779: 7, 777: 8, 729: 9, 768: 10, 780: 11,
            762: 12, 776: 13, 754: 14}
SUCCESSOR = {749: 781, 770: 777, 720: 777, 769: 776, 773: 780,
             765: 780, 766: 780, 763: 780, 752: 754, 751: 754,
             741: 754, 738: 754, 730: 754, 728: 754, 726: 754,
             748: 762, 760: 762, 755: 762, 742: 762, 747: 762,
             746: 762, 774: 783, 757: 767}
DEPENDENCIES = {771: [736, 758, 778], 781: [772], 779: [775],
                777: [720, 770], 780: [773, 777], 776: [769],
                754: [752, 751], 762: [748, 755, 760]}
PROTECTED = {767, 783}
REJECTED = {731, 732, 733, 735, 739}
SCOPES = {
    736: "One-line Windows Palette cohort concurrency",
    758: "Source-exact Windows owner verification, package launch and Gentek qualification",
    778: "Pinned Linux Godot acquisition, growing-suite planner oracle and explicit missing-plan refusal",
    771: "Campaign coordination, evidence/runtime custody and nullable metrics correction",
    772: "Explicit separate-scene native Goblin gameplay QA",
    775: "Opt-in procedural actor policy and native snapshot perception in existing actor ownership",
    781: "Persistent Goblin discovery, typed actions, replay and regression capture",
    779: "Ambient spatial memory, drives, social behaviour and personality authoring",
    777: "Native architectural parts, bounded collaboration and authoritative execution",
    729: "Consolidated reciprocal native SWARM assembly and Workbench authoring",
    768: "Declared/Active/Draft material audition with native apply/revert",
    780: "Conversational Art proposals, transport ownership and reversible native editing",
    776: "Four-plane layered authoring, independent decorative worlds and atmosphere",
    754: "Native mutable ObjectShard bodies, chemistry, exchange and Rapier integration",
    762: "Actor manipulation, input authority and optional capacity accounting",
    767: "Active physical progression/presentation recovery; frozen comparison protection",
    783: "Active persistence, retrieval and documentation custody remediation",
}
RESPONSIBILITIES = {
    "godot/scripts/main.gd": "ordinary Workbench orchestration and callbacks",
    "godot/scripts/simulation_worker.gd": "exclusive native World worker and publication",
    "godot/scripts/shared_workbench.gd": "scene replacement, authoring and history lifetime",
    "godot/scripts/physical_actor_session.gd": "actor/control/Rapier ownership",
    "godot/scripts/workbench_actor_panel.gd": "actor authoring and input handoff",
    "godot/scripts/workbench_setup.gd": "authored save schema and actor definitions",
    "godot/scripts/workbench_paint_editor_controller.gd": "native edit transactions and history",
    "godot/scripts/art_batch_panel.gd": "Art requests, providers and proposal authority",
    "godot/addons/cybersand_native/runtime-provenance.json": "Windows native binary custody",
    "godot/addons/cybersand_native/runtime-provenance-linux.json": "Linux native binary custody",
}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--metadata", type=Path, required=True)
    parser.add_argument("--main", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    def git(*parts: str) -> str:
        return subprocess.check_output(["git", "-C", str(root), *parts], text=True).strip()
    def ancestor(a: str, b: str) -> bool:
        result = subprocess.run(["git", "-C", str(root), "merge-base", "--is-ancestor", a, b], capture_output=True)
        if result.returncode not in (0, 1):
            raise RuntimeError(result.stderr.decode())
        return result.returncode == 0
    supplied = args.metadata.read_bytes()
    prs = json.loads(supplied)
    by_number = {int(row["number"]): row for row in prs}
    rows, owners = [], defaultdict(list)
    runtime = json.loads(git("show", args.main + ":godot/addons/cybersand_native/runtime-provenance.json"))
    native_paths = sorted(runtime["source_inputs"])
    for number, pr in sorted(by_number.items()):
        source = pr["head_sha"]
        merge_base = git("merge-base", args.main, source)
        target_sha = pr["base_sha"]
        changes = git("diff", "--name-only", merge_base, source).splitlines()
        implementation = [path for path in changes if path.startswith(("godot/", "native/", "tools/", ".github/", "third_party/"))]
        candidate_runtime = json.loads(git("show", source + ":godot/addons/cybersand_native/runtime-provenance.json"))
        candidate_native_paths = sorted(set(native_paths) | set(candidate_runtime["source_inputs"]))
        native_changes = git("diff", "--name-only", args.main, source, "--", *candidate_native_paths).splitlines()
        native_tree_changes = git("diff", "--name-only", args.main, source, "--", "native", "godot/native_extension").splitlines()
        outside_native_ledger = [path for path in native_tree_changes if path not in candidate_native_paths]
        runtime_artifact_changes = git("diff", "--name-only", args.main, source, "--", "godot/addons/cybersand_native").splitlines()
        adopted = ancestor(source, args.main)
        classification = ("ACTIVE PROGRAMME — PROTECT" if number in PROTECTED else
                          "REJECTED EXPERIMENT — DO NOT MERGE" if number in REJECTED else
                          "SUPERSEDED — PRESERVE EVIDENCE" if number in SUCCESSOR else
                          "QUALIFY THEN MERGE" if number in {736, 758, 771, 778, 772, 775} else
                          "RECONCILE THEN QUALIFY" if number in {780, 776, 762, 782} else
                          "OWNER ACCEPTANCE REQUIRED")
        relations = [other for other, item in by_number.items()
                     if other != number and ancestor(item["head_sha"], source)]
        if number in {736, 758, 771, 778}:
            gate = "Infrastructure/tooling integration authorized by mission; engineering gates required"
        elif number in {772, 775}:
            gate = "Opt-in code integration authorized; physical owner acceptance outstanding"
        elif number in PROTECTED:
            gate = "Active separate programme; no merge, source mutation, default activation or campaign cancellation"
        else:
            gate = "Existing physical/creative/performance owner gates preserved; see source-bound qualification register"
        for path in implementation:
            owners[path].append(number)
        rows.append({"pr": number, "programme": pr["title"], "source_sha": source,
                     "source_tree": git("rev-parse", source + "^{tree}"),
                     "target": pr["base"], "captured_target_sha": target_sha,
                     "merge_base_with_captured_target": git("merge-base", target_sha, source),
                     "merge_base_with_snapshot_main": merge_base,
                     "draft_at_capture": pr["draft"], "state_at_capture": pr["state"],
                     "implementation_scope": SCOPES.get(number, "Preserved predecessor or bounded experiment"),
                     "planned_dependencies": DEPENDENCIES.get(number, []),
                     "captured_candidates_in_source_ancestry": relations,
                     "changed_path_count": len(changes), "implementation_paths": implementation,
                     "native_input_differences_from_main": native_changes,
                     "native_paths_outside_compared_input_ledgers": outside_native_ledger,
                     "runtime_artifact_changes": runtime_artifact_changes,
                     "runtime_requirement": ("source-matched native rebuild/publication verification required" if native_changes else
                                             "inspect extra native/test/build paths before asserting binary reuse" if outside_native_ledger else
                                             "unchanged recorded native inputs; authenticate actual binary bytes and qualify application"),
                     "qualification_status": "see decisions.json and source-bound specialist reviews; ancestry is not qualification",
                     "owner_gate": gate, "classification": classification,
                     "already_in_snapshot_main": adopted, "successor": SUCCESSOR.get(number),
                     "proposed_order": PRIORITY.get(number)})
    overlap = [{"path": path, "prs": values,
                "responsibility": RESPONSIBILITIES.get(path, "shared source; inspect semantic/lifecycle compatibility"),
                "classification": "overlap discovered; textual equality alone does not establish compatibility"}
               for path, values in sorted(owners.items()) if len(values) > 1]
    output = {"schema": 2, "mission": "MERGEDOWN-RENAISSANCE-001",
              "generated_at": datetime.now(timezone.utc).isoformat(),
              "snapshot_main": args.main, "metadata_sha256": hashlib.sha256(supplied).hexdigest(),
              "native_input_authority": {"manifest": "godot/addons/cybersand_native/runtime-provenance.json", "count": len(native_paths)},
              "candidates": rows, "shared_implementation_paths": overlap,
              "limits": "Metadata is an explicit captured snapshot. No live GitHub lookup, mutation or acceptance inference is performed."}
    args.output.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"candidates": len(rows), "overlapping_paths": len(overlap), "main": args.main}))


if __name__ == "__main__":
    main()
