#!/usr/bin/env python3
"""Adverse controls for Strata's source/evidence acceptance boundary."""
from copy import deepcopy
import io
import hashlib
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch
import qualify_strata2_workbench as gate
import package_strata2_workbench as package


def predecessor_shape():
    identity = {"world_generation": 17, "physical_epoch": 8, "worker_id": "-9223371958320626182",
                "actor_session_id": "221", "actor_body_ids": ["1871", "1872"]}
    return {"schema": "strata2-workbench-execution-v1", "completed": True,
            "failures": [], "checks": 81, "scene": "orbital-terminal", "phase": "install",
            "source_revision": "a"*40, "display_server": "Windows", "rendering_method": "gl_compatibility",
            "ordinary_workbench": True, "plane_native_hashes": {s: "b"*64 for s in ("play", "scripted", "effects", "background")},
            "world_count": {"play_borrowed": 1, "decorative_owned": 3},
            "save": {"sha256": "c"*64, "path": "isolated/setup-test.json"},
            "transitions": [{"before": deepcopy(identity), "after": deepcopy(identity)} for _ in range(12)],
            "edit_readback": {"target_after": 58, "material": 58, "play_hash_before": "d"*64, "play_hash_after": "d"*64},
            "refusals": {k: True for k in ("locked", "hidden", "outside", "invalid_document", "stale_generation")},
            "undo_redo": {"undo_native": True, "redo_native": True},
            "transforms": {"samples": 48, "max_error": 0.00005},
            "cost_samples": [{"mode": m} for m in ("disabled", "flat", "stack")]}


def successor_fields(data):
    """Explicitly synthetic verifier fixtures, never execution evidence."""
    owner = deepcopy(data["transitions"][0]["before"])
    owner.update(native_tick=0, rapier_tick=0)
    after = dict(owner, native_tick=30, rapier_tick=60)
    phases = {name: {"phase_seconds": 1.0} for name in ("scripted", "effects", "background")}
    data.update(diagnostic_headless=False, document_version=2, authored_settings_sha256="f" * 64,
                saved_authoring={"native_marker":{"plane":"background","point":[96,96],"material":131},
                                 "authoring_sha256":"a"*64,"atmosphere_sha256":"b"*64,"authoring_records":0,"raster_imports":[],
                                 "atmosphere":{"paused":True,"effects":[{"id":"fixture-effect","strength":0.43}]}},
                authored_mutations={"plane":"background","point":[96,96],"before":0,"after":131,
                                    "effect_id":"fixture-effect","effect_strength_before":0.5,"effect_strength_after":0.43},
                native_grid_details=[{"plane":plane,"pixels_per_cell_x":1.0,"pixels_per_cell_y":1.0} for plane in ("play","scripted")],
                admission_target_ms=45000, admission_elapsed_ms=400, admission_target_met=True,
                cost_samples=[{"mode": mode, "atmosphere_enabled": animated,
                               "native_snapshots_during_sample": 0, "decorative_uploads_during_sample": 0}
                              for mode, animated in (("disabled", False), ("flat", False), ("stack", False), ("stack", True))],
                atmosphere={"visual_difference": {"changed_samples": 20}, "solo_leakage": {"changed_samples": 0},
                            "play_material_time":{"fixed":12.5,"original":-1.0,"shader_instance":"991","restored":True,
                                                  "emission_shader_instance":"992","emission_original":-1.0,"emission_restored":True},
                            "native_hashes_before": deepcopy(data["plane_native_hashes"]),
                            "native_hashes_after": deepcopy(data["plane_native_hashes"]), "native_capture_delta": 0,
                            "paused_before": deepcopy(phases), "paused_after": deepcopy(phases),
                            "hidden_before": deepcopy(phases), "hidden_after": deepcopy(phases),
                            "moving_before": deepcopy(phases),
                            "moving_after": {name: {"phase_seconds": 2.0} for name in phases}},
                route_probe={"completed_rapier_ticks": 60, "completed_native_ticks": 30, "forward_cells": 8.0,
                             "live_decorative_edit":{"plane":"background","committed":True,"marker":131,
                                                     "native_before":0,"native_written":131,"native_restored":0,
                                                     "receipt":{"ok":True,"published":True},
                                                     "before":dict(owner,native_tick=5,rapier_tick=6),
                                                     "after":dict(owner,native_tick=5,rapier_tick=6)},
                             "before": owner, "after": after, "samples": [{"rapier_tick": 60}]})
    reference = gate.REFERENCE_FIXTURES.get(data["scene"])
    if reference:
        provenance = json.loads((gate.ROOT / "godot/data/strata2/reference-imports" / (reference+".provenance.json")).read_text())
        data["reference_import"] = {"id":reference,"plane":"scripted","source_sha256":provenance["crop_file_sha256"],
                                    "mask_sha256":provenance["mask_sha256"],"geometry_sha256":provenance["proposed_uint16le_sha256"],
                                    "write_mask_sha256":provenance["proposed_write_mask_sha256"],
                                    "mapped":provenance["proposal_counts"]["mapped"],
                                    "no_write":provenance["proposal_counts"]["source_pixels"]-provenance["proposal_counts"]["mapped"],
                                    "completed_status":"completed","approved_token":"synthetic-test-token","history_chunks":7,
                                    "before_sha256":"1"*64,"expected_sha256":"2"*64,"actual_sha256":"2"*64,"restored_sha256":"1"*64,
                                    "play_before_sha256":"3"*64,"play_after_sha256":"3"*64,"visual_difference":{"changed_samples":20}}
        data["saved_authoring"]["authoring_records"] = 1
        data["saved_authoring"]["raster_imports"] = [{"source_sha256":provenance["crop_file_sha256"],"plane":"scripted",
                                                    "status":"completed","historical":True,"geometry_sha256":"2"*64,"actual_sha256":"3"*64}]
    if data["scene"] == "orbital-terminal":
        data["play_visibility_pixels"] = {"background_remains_visible":True, "background_probe":{
            "native_inspection_required":True,"requested_cell":[596,246],"sampled_native_cell":[596,246],
            "sampled_material":131,"physical_pixel":[601,310],"projected_native_centre":[601.4,310.7],
            "pixels_per_cell":[1.4,1.4],"camera_origin":[160,80],"view_size":[1024,576],
            "expected_rgba":[0.5,0.5,0.5,1.0],"observed_rgba":[0.5,0.5,0.5,1.0],
            "max_rgb_error":0.0,"tolerance":0.08}}
        data["composition_review"] = {"filename":"composition-ready-approval.png","status":"ready",
            "approval_enabled":True,"approval_visible":True,"proposal_visible":True,"scroll_vertical":500,
            "reviewed_token":"synthetic-compose-token","backend_token":"synthetic-compose-token",
            "displayed_status":"Review exact material-ID projection, then Approve. Synthetic verifier fixture.",
            "backend_message":"Review exact material-ID projection, then Approve. Synthetic verifier fixture. ",
            "stage_count":3,"approved":False,"cancelled_without_approval":True,
            "stop":{"status":"cancelled","token":"","can_approve":False,"applied_cells":0,"approval_disabled":True},
            "native_hashes_before":deepcopy(data["plane_native_hashes"]),"native_hashes_after":deepcopy(data["plane_native_hashes"])}
    if reference:
        fixture = json.loads((gate.ROOT / "godot/data/strata2/reference-imports" / (reference+".fixture.json")).read_text())
        region = fixture["options"]["origin"] + fixture["options"]["crop"][2:]
        data["reference_import"]["ready_review"] = {
            "filename":"reference-import-"+reference+"-approval.png","status":"ready",
            "approval_enabled":True,"approval_visible":True,"proposal_visible":True,"scroll_vertical":500,
            "reviewed_token":"synthetic-test-token","backend_token":"synthetic-test-token",
            "displayed_status":"Review exact material-ID projection, then Approve. Synthetic verifier fixture.",
            "backend_message":"Review exact material-ID projection, then Approve. Synthetic verifier fixture. ",
            "expected_region":region,"region_label":"Target: scripted · region "+str(region),
            "changed_counts":"Synthetic changed/no-write accounting; not execution evidence."}
    return data


def witness():
    return successor_fields(predecessor_shape())


def native_witness(label, source="a" * 40):
    owner = deepcopy(witness()["transitions"][0]["before"])
    result = {"completed": True, "failures": [], "checks": 64, "source_revision": source}
    if label == "test_strata2_mounted_failures":
        result.update(schema="strata2-mounted-failures-v1",
                      partial={"receipt": {"status": "partial", "applied": 1}, "native_before": [0, 0],
                               "native_after": [131, 0], "quarantined": True, "authored_retained": True},
                      committed_stale_view={"returned_committed": True, "native_after": 131,
                                            "receipt": {"ok": True, "published": False}, "revision_before": 1,
                                            "revision_after": 2, "copied_pixels_retained": True},
                      failed_play_ack={"serial": 3, "instance_id": "-9223371958320626181", "pending_native_worlds": 0,
                                       "previous_document_retained": True, "before": owner, "after": deepcopy(owner)},
                      play_hash_before="c" * 64, play_hash_after="c" * 64)
    else:
        result.update(schema="strata2-workflow-v1", input_sha256="d" * 64, play_hash_original="a" * 64,
                      play_hash_imported="b" * 64, play_hash_restored="a" * 64,
                      provenance={"records": [{"scope": "synthetic verifier fixture"}]},
                      play_identity_before=owner, play_identity_after=deepcopy(owner))
    return result


class Acceptance(unittest.TestCase):
    def check(self, data):
        gate.validate_result(data, "orbital-terminal", "install", "a"*40)

    def test_positive_complete_shape(self):
        self.check(witness())

    def test_reject_contradictory_evidence(self):
        changes = {
            "failed": lambda d: d.update(failures=["bad native readback"]),
            "incomplete": lambda d: d.update(completed=False),
            "wrong_source": lambda d: d.update(source_revision="e"*40),
            "wrong_scene": lambda d: d.update(scene="cavern"),
            "headless": lambda d: d.update(display_server="headless"),
            "standalone": lambda d: d.update(ordinary_workbench=False),
            "missing_plane": lambda d: d["plane_native_hashes"].pop("effects"),
            "bad_native_digest": lambda d: d["plane_native_hashes"].update(play="author-json-not-native"),
            "duplicate_play": lambda d: d["world_count"].update(play_borrowed=2),
            "invalid_save": lambda d: d["save"].update(sha256="bad"),
            "baseline_only_save": lambda d: d["authored_mutations"].update(before=131),
            "lost_saved_native_edit": lambda d: d["saved_authoring"]["native_marker"].update(material=0),
            "lost_saved_import_history": lambda d: d["saved_authoring"].update(raster_imports=[]),
            "lost_saved_effect_change": lambda d: d["saved_authoring"]["atmosphere"]["effects"][0].update(strength=0.5),
            "no_transitions": lambda d: d.update(transitions=[]),
            "missing_pixel_oracle": lambda d: d.pop("play_visibility_pixels"),
            "hardcoded_background_success": lambda d: d["play_visibility_pixels"].update(background_remains_visible=False),
            "downsampled_exact_colour": lambda d: d["play_visibility_pixels"]["background_probe"].update(pixels_per_cell=[0.71,0.71]),
            "wrong_native_texel": lambda d: d["play_visibility_pixels"]["background_probe"].update(sampled_native_cell=[596,247]),
            "wrong_native_material": lambda d: d["play_visibility_pixels"]["background_probe"].update(sampled_material=0),
            "relaxed_colour_tolerance": lambda d: d["play_visibility_pixels"]["background_probe"].update(tolerance=0.2),
            "unmeasured_framebuffer_colour": lambda d: d["play_visibility_pixels"]["background_probe"].pop("observed_rgba"),
            "false_colour_error": lambda d: d["play_visibility_pixels"]["background_probe"].update(observed_rgba=[0.7,0.5,0.5,1.0]),
            "colour_outside_tolerance": lambda d: d["play_visibility_pixels"]["background_probe"].update(observed_rgba=[0.7,0.5,0.5,1.0],max_rgb_error=0.2),
            "wrong_framebuffer_pixel": lambda d: d["play_visibility_pixels"]["background_probe"].update(physical_pixel=[602,310]),
            "missing_ready_compose": lambda d: d.pop("composition_review"),
            "compose_proposal_below_fold": lambda d: d["composition_review"].update(proposal_visible=False),
            "compose_unready_status": lambda d: d["composition_review"].update(displayed_status="Reading the actual target planes..."),
            "compose_changed_status_content": lambda d: d["composition_review"].update(backend_message="Review exact material-ID projection, then Approve. A different warning."),
            "missing_raw_backend_message": lambda d: d["composition_review"].pop("backend_message"),
            "compose_replaced_token": lambda d: d["composition_review"].update(backend_token="different"),
            "compose_stop_disconnected": lambda d: d["composition_review"]["stop"].update(status="ready",can_approve=True),
            "compose_stop_wrote_cells": lambda d: d["composition_review"]["stop"].update(applied_cells=1),
            "compose_review_mutates_native": lambda d: d["composition_review"]["native_hashes_after"].update(effects="9"*64),
            "missing_ready_import": lambda d: d["reference_import"].pop("ready_review"),
            "import_approval_below_fold": lambda d: d["reference_import"]["ready_review"].update(approval_visible=False),
            "import_unreviewed_token": lambda d: d["reference_import"]["ready_review"].update(backend_token="different"),
            "import_missing_counts": lambda d: d["reference_import"]["ready_review"].update(changed_counts=""),
            "import_changed_status_content": lambda d: d["reference_import"]["ready_review"].update(backend_message="Review exact material-ID projection, then Approve. A different warning."),
            "import_missing_displayed_region": lambda d: d["reference_import"]["ready_review"].update(region_label="Target: scripted · region —"),
            "import_wrong_displayed_origin": lambda d: d["reference_import"]["ready_review"].update(region_label="Target: scripted · region [0, 0, 384, 320]"),
            "import_self_declared_wrong_region": lambda d: d["reference_import"]["ready_review"].update(expected_region=[0,0,384,320],region_label="Target: scripted · region [0, 0, 384, 320]"),
            "magnified_claimed_native_resolution": lambda d: d["native_grid_details"][0].update(pixels_per_cell_x=2.0),
            "missing_native_resolution_detail": lambda d: d.pop("native_grid_details"),
            "missing_native_reference": lambda d: d.pop("reference_import"),
            "wrong_reference_mapping": lambda d: d["reference_import"].update(geometry_sha256="9"*64),
            "reference_no_native_change": lambda d: d["reference_import"].update(actual_sha256="1"*64,expected_sha256="1"*64),
            "reference_alpha_clears_play": lambda d: d["reference_import"].update(play_after_sha256="9"*64),
            "reference_undo_loses_destination": lambda d: d["reference_import"].update(restored_sha256="9"*64),
            "reference_without_owner_approval": lambda d: d["reference_import"].update(approved_token=""),
            "reference_render_only": lambda d: d["reference_import"].update(actual_sha256="native-looking screenshot"),
            "world_replaced": lambda d: d["transitions"][5]["after"].update(world_generation=18),
            "actor_replaced": lambda d: d["transitions"][5]["after"].update(actor_session_id=222),
            "bodies_replaced": lambda d: d["transitions"][5]["after"].update(actor_body_ids=[1872, 1891]),
            "no_actual_owner": lambda d: d["transitions"][0]["before"].update(worker_id=0),
            "wrong_edit_target": lambda d: d["edit_readback"].update(target_after=0),
            "play_mutated": lambda d: d["edit_readback"].update(play_hash_after="f"*64),
            "empty_edit_proof": lambda d: d.update(edit_readback={}),
            "hidden_edited": lambda d: d["refusals"].update(hidden=False),
            "locked_edited": lambda d: d["refusals"].update(locked=False),
            "stale_adopted": lambda d: d["refusals"].update(stale_generation=False),
            "invalid_adopted": lambda d: d["refusals"].update(invalid_document=False),
            "undo_unproved": lambda d: d["undo_redo"].update(undo_native=False),
            "transform_drift": lambda d: d["transforms"].update(max_error=2.0),
            "undersampled": lambda d: d["transforms"].update(samples=1),
            "no_cost": lambda d: d.update(cost_samples=[]),
            "legacy_document": lambda d: d.update(document_version=1),
            "hidden_diagnostic": lambda d: d.update(diagnostic_headless=True),
            "missing_settings": lambda d: d.pop("authored_settings_sha256"),
            "changed_admission_target": lambda d: d.update(admission_target_ms=90000),
            "concealed_admission_miss": lambda d: d.update(admission_elapsed_ms=87000),
            "no_animation_control": lambda d: d["cost_samples"].pop(),
            "recurring_native_capture": lambda d: d["cost_samples"][-1].update(native_snapshots_during_sample=1),
            "recurring_upload": lambda d: d["cost_samples"][-1].update(decorative_uploads_during_sample=1),
            "no_visible_atmosphere": lambda d: d["atmosphere"]["visual_difference"].update(changed_samples=0),
            "unfrozen_play_material_time": lambda d: d["atmosphere"].pop("play_material_time"),
            "engine_time_confound": lambda d: d["atmosphere"]["play_material_time"].update(fixed=-1),
            "borrowed_shader_not_restored": lambda d: d["atmosphere"]["play_material_time"].update(restored=False),
            "borrowed_emission_time_confound": lambda d: d["atmosphere"]["play_material_time"].pop("emission_shader_instance"),
            "solo_effect_leak": lambda d: d["atmosphere"]["solo_leakage"].update(changed_samples=1),
            "atmosphere_mutates_native": lambda d: d["atmosphere"]["native_hashes_after"].update(play="e"*64),
            "hidden_clock_advances": lambda d: d["atmosphere"]["hidden_after"]["effects"].update(phase_seconds=2),
            "pause_clock_advances": lambda d: d["atmosphere"]["paused_after"]["effects"].update(phase_seconds=2),
            "no_native_route_ticks": lambda d: d["route_probe"].update(completed_native_ticks=0),
            "no_live_native_edit": lambda d: d["route_probe"].pop("live_decorative_edit"),
            "live_edit_not_native": lambda d: d["route_probe"]["live_decorative_edit"].update(native_written=0),
            "live_edit_did_not_restore": lambda d: d["route_probe"]["live_decorative_edit"].update(native_restored=131),
            "live_edit_stopped_play": lambda d: d["route_probe"]["live_decorative_edit"]["after"].update(native_tick=30),
            "live_edit_replaced_owner": lambda d: d["route_probe"]["live_decorative_edit"]["after"].update(worker_id="991"),
            "no_actual_route_progress": lambda d: d["route_probe"].update(forward_cells=0),
            "route_replaces_world": lambda d: d["route_probe"]["after"].update(world_generation=123),
            "claimed_ticks_disagree": lambda d: d["route_probe"].update(completed_rapier_ticks=61),
            "visible_animation_stopped": lambda d: d["atmosphere"].update(moving_after=deepcopy(d["atmosphere"]["moving_before"])),
        }
        for name, mutate in changes.items():
            with self.subTest(name=name):
                data = witness(); mutate(data)
                with self.assertRaises((RuntimeError, KeyError, TypeError)): self.check(data)

    def test_honest_admission_overrun_is_retained(self):
        data = witness(); data.update(admission_elapsed_ms=87000, admission_target_met=False)
        self.check(data)

    def test_ready_status_uses_declared_display_whitespace_only(self):
        for edge in ("", " ", "\t", "\n", "\r\n"):
            with self.subTest(edge=repr(edge)):
                data = witness()
                for review in (data["composition_review"], data["reference_import"]["ready_review"]):
                    review["backend_message"] = edge + review["displayed_status"] + edge
                self.check(data)
        data = witness()
        data["composition_review"]["backend_message"] = data["composition_review"]["displayed_status"].replace("then Approve", "then  Approve")
        with self.assertRaises(RuntimeError): self.check(data)

    def test_native_fault_and_import_adverse_controls(self):
        for label in gate.NATIVE_REPORTS:
            gate.validate_native_report(native_witness(label), label, "a"*40)
        controls = [
            ("test_strata2_mounted_failures", lambda d: d["partial"].update(native_after=[131,131])),
            ("test_strata2_mounted_failures", lambda d: d["committed_stale_view"].update(returned_committed=False)),
            ("test_strata2_mounted_failures", lambda d: d["failed_play_ack"].update(pending_native_worlds=3)),
            ("test_strata2_workflow", lambda d: d.update(play_hash_imported=d["play_hash_original"])),
            ("test_strata2_workflow", lambda d: d["provenance"].update(records=[])),
            ("test_strata2_workflow", lambda d: d.update(play_hash_original=None,play_hash_restored=None,play_hash_imported="placeholder")),
            ("test_strata2_workflow", lambda d: d.update(play_hash_imported="not actual native readback")),
            ("test_strata2_workflow", lambda d: [d[key].update(worker_id=None) for key in ("play_identity_before","play_identity_after")]),
            ("test_strata2_workflow", lambda d: [d[key].update(world_generation=0) for key in ("play_identity_before","play_identity_after")]),
            ("test_strata2_workflow", lambda d: [d[key].update(actor_body_ids=[]) for key in ("play_identity_before","play_identity_after")]),
            ("test_strata2_mounted_failures", lambda d: [d["failed_play_ack"][key].update(actor_body_ids=[0]) for key in ("before","after")]),
        ]
        for label, mutate in controls:
            data = native_witness(label); mutate(data)
            with self.assertRaises((RuntimeError, KeyError, TypeError)):
                gate.validate_native_report(data, label, "a"*40)

    def test_reopen_requires_independent_process_route(self):
        data = witness(); data.update(phase="reopen", fresh_process_reopen=True)
        gate.validate_result(data, "orbital-terminal", "reopen", "a"*40)
        data["fresh_process_reopen"] = False
        with self.assertRaises(RuntimeError): gate.validate_result(data, "orbital-terminal", "reopen", "a"*40)


class ArchivedGeneratorProfiles(unittest.TestCase):
    def test_gallery_recomputed_manifest_cannot_bless_changed_document(self):
        # Reuse the explicitly synthetic gallery fixture only to exercise the
        # package boundary. This is neither Godot nor Windows package evidence.
        from test_strata2_gallery import GalleryCustody, SOURCE
        fixture = GalleryCustody(methodName="test_deterministic_build_and_receipt")
        fixture.setUp()
        try:
            with patch.object(package.gallery, "ROOT", fixture.root):
                receipt = package.gallery.build(fixture.campaign, fixture.output, SOURCE)
                record = {"gallery": receipt, "files_sha256": package.payload(fixture.package)}
                source = {"source_commit": SOURCE}
                package.verify_gallery(fixture.package, record, source)
                original = fixture.output.read_bytes()
                fixture.output.write_bytes(original + b"<!-- altered -->")
                record["files_sha256"] = package.payload(fixture.package)
                record["gallery"]["html_sha256"] = gate.sha(fixture.output)
                with self.assertRaises(RuntimeError): package.verify_gallery(fixture.package, record, source)
                fixture.output.write_bytes(original)
                receipt = package.gallery.build(fixture.campaign, fixture.output, SOURCE)
                record["gallery"] = receipt
                inputs = fixture.output.with_suffix(".inputs.json")
                altered = json.loads(inputs.read_text())
                altered["source_commit"] = "f" * 40
                inputs.write_text(json.dumps(altered, ensure_ascii=False, sort_keys=True, indent=2) + "\n")
                record["files_sha256"] = package.payload(fixture.package)
                record["gallery"]["inputs_sha256"] = gate.sha(inputs)
                with self.assertRaises(RuntimeError): package.verify_gallery(fixture.package, record, source)
        finally:
            fixture.tearDown()

    def test_raw_png_asset_custody_rejects_rehashed_package_mutation(self):
        # The PNG signature itself contains CRLF; raw identity must preserve it.
        original = b"\x89PNG\r\n\x1a\nraw-source-fixture"
        name = "godot/data/strata2/imports/raw-fixture.png"
        digest = hashlib.sha256(original).hexdigest()
        source = {"source_assets_sha256":{name:digest}}
        with tempfile.TemporaryDirectory(prefix="Strata raw PNG custody ") as temporary:
            folder = Path(temporary)
            path = folder / name
            path.parent.mkdir(parents=True)
            path.write_bytes(original)
            record = dict(source, files_sha256={name:digest})
            package.verify_native_import_assets(folder,record,source)
            self.assertNotEqual(digest,hashlib.sha256(original.replace(b"\r\n",b"\n")).hexdigest())
            path.write_bytes(original[:-1]+b"X")
            record["files_sha256"][name] = gate.sha(path)
            with self.assertRaises(RuntimeError): package.verify_native_import_assets(folder,record,source)
            record["source_assets_sha256"] = {name:gate.sha(path)}
            with self.assertRaises(RuntimeError): package.verify_native_import_assets(folder,record,source)
            path.write_bytes(original)
            extra = path.with_name("unrecorded.png")
            extra.write_bytes(original)
            with self.assertRaises(RuntimeError): gate.project_assets_identity(folder/"godot",source)

    def test_actual_source_profiles_and_adverse_copies(self):
        # Use the real canonical recipes and nested style/schema assets from
        # the committed source. The established stager defines the contract;
        # this catches disagreement between staging and independent admission.
        archive = subprocess.check_output(["git", "archive", "HEAD", "--", "examples/worldgen"], cwd=package.ROOT)
        with tempfile.TemporaryDirectory(prefix="Strata archived profiles ") as temporary:
            folder = Path(temporary)
            originals = set()
            with tarfile.open(fileobj=io.BytesIO(archive)) as tree:
                for member in tree:
                    if not member.isfile():
                        continue
                    path = folder / member.name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_bytes(tree.extractfile(member).read())
                    originals.add(member.name)
            profiles = package.stage_generator_profiles(folder)
            record = {"generator_profiles_sha256":profiles}
            names = package.payload(folder)
            package.verify_generator_profiles(folder, record, originals, names)
            self.assertIn("gen007-deepworks.json", profiles)
            self.assertIn("gen007-qualification.json", profiles)
            for retained in ("architectural/habitation-arcology.style.json", "schemas/semantic-planes-v1.schema.json"):
                self.assertIn("examples/worldgen/" + retained, names)
                self.assertNotIn(Path(retained).name, profiles)
            missing_record = deepcopy(record)
            missing_record["generator_profiles_sha256"].pop("gen007-deepworks.json")
            with self.assertRaises(RuntimeError):
                package.verify_generator_profiles(folder, missing_record, originals, names)
            copied_name = "godot/authoring/worldgen/gen007-deepworks.json"
            missing_copy = dict(names)
            missing_copy.pop(copied_name)
            with self.assertRaises(RuntimeError):
                package.verify_generator_profiles(folder, record, originals, missing_copy)
            copied = folder / copied_name
            copied.write_bytes(copied.read_bytes() + b"\n")
            with self.assertRaises(RuntimeError):
                package.verify_generator_profiles(folder, record, originals, package.payload(folder))


if __name__ == "__main__":
    unittest.main()
