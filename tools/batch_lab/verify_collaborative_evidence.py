#!/usr/bin/env python3
"""Fail-closed scope/custody gate for a complete M6/M7 qualification invocation.

Native harnesses and independent scalar reducers establish detailed contracts.
This gate binds their reports to one exact source/runtime and checks full cohorts
and capture files. Development capacity, cropped gameplay and archival render
substitutions cannot satisfy it. No aesthetic or model-quality claim is made.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re

from m67.reduce_comparison import canonical_bytes as comparison_canonical_bytes

MAX_FILE_BYTES = 128 * 1024 * 1024
NATIVE_TICK_SOURCE = "CyberSimulationWorker.take_latest_snapshot(0).tick_index"
FLAGSHIP_EXTENTS = {"orbital-fabrication": [1024, 1024], "terraced-arcology": [1024, 1024],
                    "monumental-viaduct": [1536, 768], "biomechanical-vault": [1024, 768]}


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


class Custody:
    def __init__(self, root: Path, source: str, native: str):
        self.root, self.source, self.native = root.resolve(), source, native
        self.checks, self.files = 0, {}
        self.require(bool(re.fullmatch(r"[0-9a-f]{40}", source)), "Exact source commit required")
        self.require(bool(re.fullmatch(r"[0-9a-f]{64}", native)), "Exact native runtime digest required")

    def require(self, value: bool, message: str) -> None:
        self.checks += 1
        if not value:
            raise ValueError(message)

    def file(self, relative: str, expected: str | None = None) -> bytes:
        self.require(isinstance(relative, str) and bool(relative), "Missing evidence path")
        path = self.root / relative
        self.require(not Path(relative).is_absolute() and not path.is_symlink()
                     and path.resolve().is_relative_to(self.root) and path.is_file(), "Unsafe/missing evidence path: " + relative)
        self.require(path.stat().st_size <= MAX_FILE_BYTES, "Evidence input exceeds finite bound: " + relative)
        data = path.read_bytes()
        digest = sha(data)
        if expected is not None:
            self.require(digest == expected, "Evidence digest mismatch: " + relative)
        self.files[relative] = digest
        return data

    def reference(self, parent: str, relative: str, expected: str) -> bytes:
        self.require(isinstance(relative, str) and bool(relative) and "\\" not in relative and ":" not in relative
                     and not Path(relative).is_absolute() and ".." not in Path(relative).parts,
                     "Unsafe nested evidence reference")
        self.require(isinstance(expected, str) and bool(re.fullmatch(r"[0-9a-f]{64}", expected)),
                     "Nested evidence reference lacks an exact digest")
        return self.file(parent + "/" + relative, expected)

    def native_record(self, parent: str, relative: str, expected: str) -> dict:
        record = json.loads(self.reference(parent, relative, expected))
        self.require(isinstance(record, dict) and isinstance(record.get("provenance"), dict),
                     "Native record lacks source/runtime provenance")
        self.require(record["provenance"].get("source_revision") == self.source
                     and record["provenance"].get("native_binary_sha256") == self.native,
                     "Raw native record source/runtime differs")
        return record

    def document(self, relative: str, *, source_key: str = "source_revision", finished: bool = True) -> dict:
        value = json.loads(self.file(relative))
        self.require(isinstance(value, dict), "Evidence must be an object: " + relative)
        self.require(value.get(source_key) == self.source, "Evidence source differs: " + relative)
        if finished:
            self.require(type(value.get("checks")) is int and value["checks"] > 0
                         and value.get("failures") in (0, []) and value.get("passed", True) is True,
                         "Evidence did not complete its checks: " + relative)
        for key in ("model_calls", "real_model_calls", "actual_model_calls"):
            if key in value:
                self.require(type(value[key]) is int and value[key] == 0, "Unexpected model execution: " + relative)
        return value

    def normal_capacity(self, value: dict, key: str = "native_active_core_capacity") -> None:
        self.require(value.get(key) == 1024, "Final campaign requires normal native active-core capacity 1024")
        for flag in ("development_core_capacity_override", "development_core_capacity", "development_memory_configuration"):
            self.require(value.get(flag, 0) in (0, False), "Development runtime cannot qualify final campaign")

    def images(self, parent: str, rows: list, count: int, path_key: str = "image", sha_key: str = "image_sha256") -> None:
        self.require(isinstance(rows, list) and len(rows) == count, "Missing actual image cohort: " + parent)
        paths = []
        for row in rows:
            relative = parent + "/" + str(row.get(path_key, ""))
            self.require(isinstance(row.get(sha_key), str), "Missing actual image digest")
            data = self.file(relative, row[sha_key])
            self.require(data.startswith(b"\x89PNG\r\n\x1a\n"), "Capture is not a PNG: " + relative)
            paths.append(relative)
        self.require(len(set(paths)) == count, "Duplicate capture substituted for required view")


def verify(root: Path, source: str, native: str) -> dict:
    gate = Custody(root, source, native)
    catalogue = gate.document("catalogue/native-catalogue-report.json")
    gate.normal_capacity(catalogue)
    modules, observations = catalogue.get("modules", []), catalogue.get("observations", [])
    module_ids = {row["id"] for row in modules}
    gate.require(len(modules) == 40 and len(module_ids) == 40 and len(observations) == 100,
                 "Complete forty-module/one-hundred-observation native catalogue required")
    keys = {(row.get("id"), row.get("phase"), row.get("transform")) for row in observations}
    gate.require(len(keys) == 100
                 and {row["id"] for row in observations if row.get("phase") == "source" and row.get("transform") == "identity"} == module_ids
                 and {row["id"] for row in observations if row.get("phase") == "replay" and row.get("transform") == "identity"} == module_ids
                 and sum(row.get("phase") == "replay" and row.get("transform") != "identity" for row in observations) == 20,
                 "Catalogue source/identity/asymmetric cohorts differ")
    for row in observations:
        gate.require(row.get("source_revision") == source and row.get("native_binary_sha256") == native
                     and row.get("status") == "completed", "Catalogue observation source/runtime/status differs")
        gate.native_record("catalogue", row["record_path"], row["record_sha256"])
    library_sha = sha(gate.file("catalogue/curated-library-v2.json"))
    gallery = gate.document("catalogue/rendered/catalogue-render-report.json", source_key="render_source_revision")
    gate.require(gallery.get("native_source_revision") == source and gallery.get("same_source") is True
                 and gallery.get("validation_only") is False and gallery.get("archival_development_requested") is False
                 and gallery.get("native_modules_checked") == 40, "Gallery requires this exact source's native observations")
    gate.images("catalogue/rendered", gallery.get("rendered"), 40)
    gate.file("catalogue/rendered/native-parts-contact-gallery.png", gallery.get("gallery_sha256", "missing"))

    detail = gate.document("detail/cases.json")
    gate.normal_capacity(detail)
    detail_analysis = gate.document("detail/analysis.json", finished=False)
    gate.normal_capacity(detail_analysis)
    gate.require(len(detail.get("cases", [])) == 24 and all(detail_analysis.get(key) == 24 for key in (
        "registered_cases", "retained_rows", "evaluable_cases", "constraints_preserved_cases", "exact_projection_cases")),
        "All twenty-four detail cases require independent exact-plane/constraint observations")
    gate.require(detail_analysis.get("native_binary_sha256") == [native], "Detail observations use another native runtime")
    gate.require(detail_analysis.get("manifest_sha256") == gate.files["detail/cases.json"],
                 "Detail reduction is not bound to this exact manifest")
    for row in detail["cases"]:
        gate.require(isinstance(row, dict), "Malformed retained detail case")
        for key in ("before", "after", "recipe"):
            reference = row.get(key)
            gate.require(isinstance(reference, dict), "Missing exact detail file reference")
            gate.reference("detail", reference.get("path"), reference.get("sha256"))
        reference = row.get("native_record")
        gate.require(isinstance(reference, dict), "Missing raw detail native record")
        gate.native_record("detail", reference.get("path"), reference.get("sha256"))

    comparison = gate.document("comparison/cases.json")
    gate.require(comparison.get("development_core_capacity") == 0 and len(comparison.get("cases", [])) == 60,
                 "Comparison must retain sixty registered proposals under the normal runtime")
    analysis = gate.document("comparison/analysis.json", finished=False)
    gate.require(analysis.get("passed") is True and analysis.get("failures") == []
                 and analysis.get("case_count") == 60 and analysis.get("development_core_capacity") == 0
                 and analysis.get("manifest_sha256") == gate.files["comparison/cases.json"],
                 "Independent comparison custody/constraint reduction did not pass complete denominator")
    for key in ("native_completed", "pre_native_refusals"):
        gate.require(type(analysis.get(key)) is int and 0 <= analysis[key] <= 60,
                     "Comparison outcome counts must be bounded nonnegative integers")
    gate.require(analysis["native_completed"] + analysis["pre_native_refusals"] == 60,
                 "Successful comparison executions and pre-native refusals must remain distinct")
    sources, parts = comparison.get("source_observations"), comparison.get("module_observations")
    gate.require(isinstance(sources, list) and len(sources) == 6 and isinstance(parts, list) and len(parts) == 40,
                 "Comparison needs all six source baselines and forty fresh native parts")
    for row in sources:
        gate.native_record("comparison", row.get("record_path"), row.get("record_sha256"))
        gate.reference("comparison", row.get("source_plane_path"), row.get("source_sha256"))
    for row in parts:
        gate.native_record("comparison", row.get("record_path"), row.get("record_sha256"))
        identity = row.get("id")
        gate.require(isinstance(identity, str) and bool(re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,63}", identity)),
                     "Comparison module identity cannot be a file path")
        # These exports are pinned by their canonical semantic content identity,
        # not a raw-file digest in the historical comparison schema.
        module = json.loads(gate.file("comparison/modules/" + identity + ".json"))
        gate.require(isinstance(module, dict), "Malformed comparison module export")
        declared = module.pop("content_sha256", None)
        gate.require(declared == row.get("module_sha256") and sha(comparison_canonical_bytes(module)) == declared,
                     "Comparison module changed after independent reduction")
    attempted = 0
    for row in comparison["cases"]:
        gate.require(isinstance(row, dict) and type(row.get("native_attempted")) is bool,
                     "Comparison proposal lacks explicit native-attempt status")
        for path_key, hash_key in (("source_plane_path", "source_sha256"), ("result_plane_path", "result_sha256"),
                                   ("program_path", "program_sha256")):
            gate.reference("comparison", row.get(path_key), row.get(hash_key))
        if row["native_attempted"]:
            attempted += 1
            record = gate.native_record("comparison", row.get("raw_native_record_path"), row.get("raw_native_record_sha256"))
            gate.require(row.get("status") == record.get("state") == "completed", "Native comparison attempt is incomplete")
        else:
            gate.require(row.get("status") == "refused-before-native" and not row.get("raw_native_record_path")
                         and not row.get("raw_native_record_sha256") and row.get("result_sha256") == row.get("source_sha256"),
                         "Pre-native refusal cannot masquerade as native geometry")
    gate.require(attempted == analysis["native_completed"] and 60-attempted == analysis["pre_native_refusals"],
                 "Raw retained comparison attempts differ from reduced outcome counts")

    flagships = gate.document("flagships/flagships-native.json")
    gate.normal_capacity(flagships, "core_capacity")
    examples = flagships.get("examples", [])
    gate.require(len(examples) == 4 and {row["id"] for row in examples} == set(FLAGSHIP_EXTENTS), "Four distinct full native flagships required")
    family_ids = {row["id"] for row in examples}
    for row in examples:
        gate.require(row.get("all_tasks_completed") is True and row.get("clearance_occupancy_verified") is True
                     and row.get("stages", 0) > 1 and row.get("native_receipt_chunks", 0) > 0
                     and row.get("extent") == FLAGSHIP_EXTENTS[row["id"]], "Incomplete full-World flagship: " + row["id"])
        data = gate.file("flagships/" + row["plane"], row["sha256"])
        gate.require(len(data) == row["extent"][0] * row["extent"][1] * 2, "Full native flagship extent/plane mismatch")
        gate.file("flagships/" + row["start_path"], row["start_sha256"])
    renders = gate.document("flagships/flagships-render.json")
    gate.require(renders.get("native_source_revision") == source and renders.get("display") not in (None, "", "headless"),
                 "Flagship rendering requires actual display and same native source")
    gate.images("flagships", renders.get("renders"), 12)

    gameplay = gate.document("gameplay/architecture-gameplay.json")
    gate.normal_capacity(gameplay)
    gate.require(gameplay.get("native_tick_source") == NATIVE_TICK_SOURCE, "Gameplay requires current worker publication, not render-cache tick measurements")
    gate.require(gameplay.get("cropped_route_worlds") is False and gameplay.get("display") not in (None, "", "headless")
                 and gameplay.get("manifest_sha256") == gate.files["flagships/flagships-native.json"],
                 "Gameplay requires this invocation's complete actual flagship Worlds and display")
    attempts = gameplay.get("attempts", [])
    gate.require(len(attempts) == 4 and {row["id"] for row in attempts} == family_ids, "Full four-family actor cohort required")
    for row in attempts:
        gate.require(row.get("status") == "completed" and row.get("actor_ticks", 0) > 0 and row.get("native_ticks", 0) > 0
                     and row.get("contact_samples", 0) >= 12 and row.get("command_refusals") == 0
                     and row.get("left_corridor") is False and row.get("worker_failed") is False
                     and not row.get("source_derivation") and row.get("ordinary_history", {}).get("ok") is True,
                     "Incomplete full-World actor/contact/history witness: " + row["id"])
        gate.file("gameplay/" + row["start_path"], row["saved_start_sha256"])
        gate.require(gate.file("gameplay/" + row["id"] + "-actual-workbench.png").startswith(b"\x89PNG\r\n\x1a\n"),
                     "Missing actual Workbench gameplay capture")
    reopened = gate.document("gameplay/architecture-gameplay-reopen.json")
    gate.normal_capacity(reopened)
    gate.require(reopened.get("native_tick_source") == NATIVE_TICK_SOURCE, "Fresh actor replay requires worker publication tick measurements")
    gate.require(reopened.get("route_source_revision") == source and reopened.get("route_report_sha256") == gate.files["gameplay/architecture-gameplay.json"],
                 "Reopen must consume this exact process's actor report")
    gate.require(len(reopened.get("attempts", [])) == 4 and {row["id"] for row in reopened["attempts"]} == family_ids
                 and all(row.get("fresh_commands_accepted") is True and row.get("actor_ticks", 0) > 0
                         and row.get("native_ticks", 0) > 0 for row in reopened["attempts"]), "Fresh four-family actor replay incomplete")

    ui = gate.document("ui/collaborative-ui.json")
    gate.normal_capacity(ui)
    gate.require(ui.get("catalogue_sha256") == library_sha and ui.get("display") not in (None, "", "headless"),
                 "Actual UI requires this source's native catalogue and real display")
    gate.images("ui", ui.get("captures"), 7, "path", "sha256")
    gate.file("ui/connected-native-region.u16le", ui.get("native_sha256", "missing"))
    gate.require(len(ui.get("native_records", [])) == 3 and all(row.get("source_revision") == source
                 and row.get("status") == "completed" and row.get("result_sha256") == row.get("expected_sha256")
                 for row in ui["native_records"]), "UI native placement/detail receipts incomplete")

    hierarchy = gate.document("hierarchy/hierarchy-native.json")
    gate.normal_capacity(hierarchy, "core_capacity")
    result = hierarchy.get("result", {})
    gate.require(len(result.get("delegated_workers", [])) == 3 and result.get("final_campaign_state") == "completed"
                 and result.get("prior_campaigns") == 1 and 0 < result.get("partial_checked_cells", 0) < 61440
                 and result.get("preserved_outside_recovery_except_declared_attachments") is True
                 and result.get("approved_outside_recovery_cells") == 256 and result.get("protected_passage_empty") is True,
                 "Delegation/actual partial Stop/fresh native recovery witness incomplete")
    gate.file("hierarchy/" + result["plane"], result["plane_sha256"])
    gate.file("hierarchy/" + result["start"], result["start_sha256"])
    hierarchy_analysis = gate.document("hierarchy/independent-hierarchy-verification.json", finished=False)
    gate.require(hierarchy_analysis.get("status") == "PASS" and hierarchy_analysis.get("errors") == []
                 and hierarchy_analysis.get("manifest_sha256") == gate.files["hierarchy/hierarchy-native.json"]
                 and hierarchy_analysis.get("final_plane_sha256") == result["plane_sha256"]
                 and hierarchy_analysis.get("runtime", {}).get("native_active_core_capacity") == 1024
                 and hierarchy_analysis.get("counts", {}).get("native_stages") == 10
                 and hierarchy_analysis.get("counts", {}).get("workers") == 3,
                 "Independent ten-stage hierarchy reduction is absent, stale or incomplete")
    recovery = hierarchy_analysis.get("recovery", {})
    gate.require(recovery.get("attachment_cells") == 1024 and recovery.get("solid_contact_requirements") == 128
                 and recovery.get("approved_outside_recovery_cells") == 256
                 and recovery.get("all_other_outside_cells_preserved") is True,
                 "Independent attachment recovery exception differs from the approved contract")
    observed_files = hierarchy_analysis.get("files")
    gate.require(isinstance(observed_files, list) and 1 <= len(observed_files) <= 64,
                 "Independent hierarchy report lacks a bounded raw-file custody inventory")
    for row in observed_files:
        gate.require(isinstance(row, dict) and type(row.get("bytes")) is int and row["bytes"] >= 0,
                     "Malformed independent hierarchy file identity")
        raw = gate.reference("hierarchy", row.get("path"), row.get("sha256"))
        gate.require(len(raw) == row["bytes"], "Independent hierarchy raw file size changed")
    fresh = gate.document("hierarchy/hierarchy-reopen.json")
    gate.normal_capacity(fresh, "core_capacity")
    gate.require(fresh.get("result", {}).get("fresh_process") is True and fresh["result"].get("plane_sha256") == result["plane_sha256"],
                 "Fresh hierarchy Reopen did not reproduce exact recovered geometry")
    rendered = gate.document("hierarchy/hierarchy-render.json")
    gate.require(rendered.get("native_source_revision") == source and rendered.get("display") not in (None, "", "headless"),
                 "Hierarchy images require same-source actual Godot framebuffers")
    gate.images("hierarchy", rendered.get("renders"), 3)
    return {"format": "cybersand-collaborative-qualification-custody-v1", "passed": True,
            "checks": gate.checks, "failures": [], "source_revision": source, "native_binary_sha256": native,
            "native_active_core_capacity": 1024, "cropped_route_worlds": False, "model_calls": 0,
            "counts": {"modules": 40, "catalogue_native_observations": 100, "detail_cases": 24,
                       "comparison_proposals": 60, "comparison_native_completed": analysis["native_completed"],
                       "comparison_pre_native_refusals": analysis["pre_native_refusals"], "full_native_flagships": 4,
                       "full_world_actor_trials": 4, "fresh_actor_reopens": 4, "catalogue_part_frames": 40,
                       "flagship_frames": 12, "collaborative_ui_frames": 7, "hierarchy_frames": 3,
                       "delegated_local_workers": 3}, "files_sha256": gate.files,
            "physical_owner_acceptance": "pending", "art_successor_integration": "separate gate",
            "scope": "Exact-source/runtime cohort, capture and report custody. Native/actor claims remain limited to retained bounded tests; no model quality, subjective preference or general playability inferred."}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    parser.add_argument("--source", required=True)
    parser.add_argument("--native-sha256", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    result = verify(args.root, args.source, args.native_sha256)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("COLLABORATIVE_EVIDENCE_CUSTODY " + json.dumps({"checks": result["checks"], "failures": [], "passed": True}))


if __name__ == "__main__":
    main()
