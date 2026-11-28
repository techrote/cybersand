"""Synthetic adversaries for verify_hierarchy_native.

These fixtures exercise the independent reducer. They are never native evidence
and cannot qualify a source/runtime. The companion hosted actual witness must
also pass. This file was initially authored while the executor was unavailable.
"""
import base64
from contextlib import redirect_stdout
import copy
import io
import json
from pathlib import Path
import tempfile
import unittest

import verify_hierarchy_native as v

SOURCE = "1" * 40


def rectangle(x, y, width, height, material=58):
    return {"shape":"rectangle", "x0":x, "y0":y,
            "x1":x+width-1, "y1":y+height-1, "material":material}


def stage(identity="synthetic", region=(8,16,16,16), operations=None, ceiling=262144):
    return {"id":identity, "intent":"Synthetic reducer fixture; not native evidence.",
            "region":list(region), "depends_on":[], "modules":[],
            "operations":[rectangle(10,20,3,2)] if operations is None else operations,
            "materials":[0,7,28,58], "protected":[], "clearances":[],
            "connections":[], "budget":{"max_checked_cells":ceiling},
            "expected_effects":"Exercise independent verification, never runtime certification."}


def make_record(value=None, before=None, prefix=None):
    value = stage() if value is None else copy.deepcopy(value)
    before = bytes(v.WORLD_BYTES) if before is None else bytes(before)
    projection = v.project_stage(value, before, {})
    intended = projection["changes"]
    rows = copy.deepcopy(intended if prefix is None else intended[:prefix])
    actual = bytearray(before)
    receipts = []
    revision = 0
    for index in range(0, len(rows), 4096):
        part = rows[index:index+4096]
        for x, y, old, new in part:
            if v.cell(actual, (x,y)) != old:
                raise AssertionError("Fixture old material inconsistency")
            v.put(actual, (x,y), new)
        receipts.append({"backend":"CyberNativeCellWorld", "status":"completed",
            "generation":3, "authoring_generation":1, "tick":0, "revision":revision+len(part),
            "before_source":{"generation":3,"authoring_generation":1,"tick":0,"revision":revision},
            "requested":len(part),"checked":len(part),"changed":len(part),"unchanged":0,
            "confirmed":len(part),"excluded":0,"refused":0,"readback":part})
        revision += len(part)
    region = v.rect(value["region"], "fixture region")
    record = {"kind":"native-stage","stage_id":value["id"],"stage":value,
        "source_revision":SOURCE,"generation":3,"native_submission":1,
        "stage_sha256":v.inner_hash(value),"preview_sha256":"2"*64,
        "plan_sha256":"3"*64,"plan_id":"synthetic",
        "source_sha256":v.sha(v.crop(before,region)),
        "expected_sha256":v.sha(v.crop(projection["plane"],region)),
        "result_sha256":v.sha(v.crop(actual,region)),
        "result_materials_base64":base64.b64encode(v.crop(actual,region)).decode("ascii"),
        "native_receipts":receipts,"native_receipts_sha256":v.inner_hash(receipts),
        "checked_cells":len(rows),"changed_cells":len(rows),
        "status":"completed" if len(rows)==len(intended) else "partial",
        "final_readback_available":True,"elapsed_usec":12345,"started_usec":1,
        "budget":{"checked_cells":len(intended),"changed_cells":len(intended),
                  "emitted_input_points":projection["emitted"],
                  "unique_cells":projection["unique"],
                  "conservative_scan_bound":projection["emitted"],
                  "limit":value["budget"]["max_checked_cells"]}}
    return record, before, actual, projection


def rehash_receipts(record):
    record["native_receipts_sha256"] = v.inner_hash(record["native_receipts"])


def verify_record(record, before):
    return v.verify_stage(record, before, {}, [], SOURCE, 3)


def recovery_fixture(prefix=37):
    baseline = bytearray(v.WORLD_BYTES)
    for box in [(32,128,448,16),(32,144,16,272),(464,144,16,272),(16,416,480,16)]:
        for p in v.points(box):
            v.put(baseline, p, 58)
    v.put(baseline, (500,500), 7)  # An unrelated native cell must survive.
    trial = stage("cladding-trial", v.RECOVERY, [rectangle(*v.RECOVERY)], 65536)
    partial, before, stopped, projection = make_record(trial, baseline, prefix)
    partial_view = v.verify_stage(partial, before, {}, [], SOURCE, 3)
    clearing = stage("clear-stopped-prefix", v.RECOVERY, [rectangle(*v.RECOVERY,0)], 65536)
    clearing["input_snapshot_sha256"] = v.sha(v.crop(stopped,v.RECOVERY))
    clearing["input_generation"] = 3
    clear, _, cleaned, _ = make_record(clearing, stopped)
    clear_view = v.verify_stage(clear, stopped, {}, [], SOURCE, 3)
    ops = [rectangle(64,304,384,8),rectangle(64,160,8,144),rectangle(440,160,8,144),
           rectangle(64,160,112,8),rectangle(336,160,112,8)]
    ops += [rectangle(x,184,8,64,28) for x in (88,112,136,360,384,408)]
    opening = stage("open-workshop-bays", v.RECOVERY, ops, 16384)
    opened, _, open_plane, _ = make_record(opening, cleaned)
    open_view = v.verify_stage(opened, cleaned, {}, [], SOURCE, 3)
    pieces = [(64,144,8,16,58),(440,144,8,16,58)]
    pieces += [(x,168,8,16,28) for x in (88,112,136,360,384,408)]
    attachment = stage("attach-workshop-bays", v.ATTACHMENT_REGION,
                       [rectangle(*piece) for piece in pieces], 1024)
    attachment["materials"] = [28,58]
    attachment["depends_on"] = ["open-workshop-bays"]
    _, contacts = v.attachment_contract()
    attachment["connections"] = [{"kind":kind,"a":list(pair[0]),"b":list(pair[1])}
                                 for kind,pair in sorted(contacts)]
    attached, _, final, _ = make_record(attachment, open_plane)
    attach_view = v.verify_stage(attached, open_plane, {}, [], SOURCE, 3)
    views = {"cladding-trial":partial_view,"clear-stopped-prefix":clear_view,
             "open-workshop-bays":open_view,"attach-workshop-bays":attach_view}
    result = {"partial_checked_cells":prefix,
              "preserved_outside_recovery_except_declared_attachments":True,
              "approved_outside_recovery_cells":256,"protected_passage_empty":True}
    return views, bytes(stopped), bytes(final), result


class NativeRows(unittest.TestCase):
    def setUp(self):
        self.record, self.before, self.after, self.projection = make_record()

    def test_complete_native_rows_and_plane(self):
        actual = verify_record(self.record, self.before)
        self.assertEqual(actual["after"], self.after)
        self.assertEqual(len(actual["rows"]), 6)

    def test_partial_authority_is_rows_not_elapsed_time(self):
        record, before, _, _ = make_record(prefix=3)
        record["elapsed_usec"] = 10**18
        actual = verify_record(record, before)
        self.assertEqual(len(actual["rows"]), 3)

    def test_arbitrary_elapsed_time_cannot_create_a_prefix(self):
        record, before, _, _ = make_record(prefix=0)
        record["elapsed_usec"] = 10**18
        with self.assertRaisesRegex(v.Violation, "Partial record"):
            verify_record(record, before)

    def test_incomplete_prefix_cannot_be_completed(self):
        record, before, _, _ = make_record(prefix=3)
        record["status"] = "completed"
        with self.assertRaisesRegex(v.Violation, "Completed record"):
            verify_record(record, before)

    def test_full_prefix_cannot_be_called_partial(self):
        self.record["status"] = "partial"
        with self.assertRaisesRegex(v.Violation, "Partial record"):
            verify_record(self.record, self.before)

    def test_counter_boolean_float_negative_and_overflow(self):
        for bad in (True, 6.0, -1, 4097):
            with self.subTest(bad=bad):
                candidate = copy.deepcopy(self.record)
                candidate["native_receipts"][0]["checked"] = bad
                rehash_receipts(candidate)
                with self.assertRaises(v.Violation):
                    verify_record(candidate, self.before)

    def test_missing_counter(self):
        del self.record["native_receipts"][0]["confirmed"]
        rehash_receipts(self.record)
        with self.assertRaises(v.Violation):
            verify_record(self.record, self.before)

    def test_counter_algebra(self):
        self.record["native_receipts"][0]["requested"] = 5
        rehash_receipts(self.record)
        with self.assertRaisesRegex(v.Violation, "counter algebra"):
            verify_record(self.record, self.before)

    def test_status_and_backend(self):
        for key, value in (("status","queued"),("status","refused"),("backend","VisualCanvas")):
            with self.subTest(key=key,value=value):
                candidate = copy.deepcopy(self.record)
                candidate["native_receipts"][0][key] = value
                rehash_receipts(candidate)
                with self.assertRaises(v.Violation):
                    verify_record(candidate, self.before)

    def test_receipt_checksum_tamper(self):
        self.record["native_receipts"][0]["readback"][0][3] = 28
        with self.assertRaisesRegex(v.Violation, "receipt checksum"):
            verify_record(self.record, self.before)

    def test_rehashed_old_material_tamper(self):
        self.record["native_receipts"][0]["readback"][0][2] = 58
        rehash_receipts(self.record)
        with self.assertRaisesRegex(v.Violation, "old material"):
            verify_record(self.record, self.before)

    def test_rehashed_out_of_region_row(self):
        self.record["native_receipts"][0]["readback"][0][0] = 100
        rehash_receipts(self.record)
        with self.assertRaisesRegex(v.Violation, "escaped approved region"):
            verify_record(self.record, self.before)

    def test_reordered_prefix_is_not_approved_native_order(self):
        rows = self.record["native_receipts"][0]["readback"]
        rows[0], rows[1] = rows[1], rows[0]
        rehash_receipts(self.record)
        with self.assertRaisesRegex(v.Violation, "approved change prefix"):
            verify_record(self.record, self.before)

    def test_receipt_denominator_mismatch(self):
        self.record["native_receipts"][0]["readback"].pop()
        rehash_receipts(self.record)
        with self.assertRaisesRegex(v.Violation, "denominator"):
            verify_record(self.record, self.before)

    def test_stale_generation(self):
        self.record["native_receipts"][0]["generation"] = 4
        rehash_receipts(self.record)
        with self.assertRaisesRegex(v.Violation, "generation"):
            verify_record(self.record, self.before)

    def test_native_tick_is_not_static_qualification(self):
        self.record["native_receipts"][0]["tick"] = 1
        rehash_receipts(self.record)
        with self.assertRaisesRegex(v.Violation, "simulation tick"):
            verify_record(self.record, self.before)

    def test_native_exclusion_is_not_accepted_in_hierarchy(self):
        receipt = self.record["native_receipts"][0]
        receipt["excluded"] = 1
        receipt["requested"] = receipt["checked"] = 7
        rehash_receipts(self.record)
        with self.assertRaises(v.Violation):
            verify_record(self.record, self.before)

    def test_result_bytes_changed_even_with_new_result_hash(self):
        actual = bytearray(v.crop(self.after,v.rect(self.record["stage"]["region"],"test")))
        actual[0] = 58
        self.record["result_materials_base64"] = base64.b64encode(actual).decode("ascii")
        self.record["result_sha256"] = v.sha(actual)
        with self.assertRaises(v.Violation):
            verify_record(self.record, self.before)

    def test_missing_authoritative_readback(self):
        self.record["final_readback_available"] = False
        with self.assertRaisesRegex(v.Violation, "authoritative"):
            verify_record(self.record, self.before)

    def test_source_and_source_pin_fences(self):
        for field, value in (("input_snapshot_sha256","f"*64),("input_generation",4)):
            with self.subTest(field=field):
                candidate = copy.deepcopy(self.record)
                candidate["stage"]["input_snapshot_sha256"] = candidate["source_sha256"]
                candidate["stage"][field] = value
                candidate["stage_sha256"] = v.inner_hash(candidate["stage"])
                with self.assertRaisesRegex(v.Violation, "pin"):
                    verify_record(candidate, self.before)

    def test_changed_source_and_source_commit(self):
        candidate = bytearray(self.before)
        v.put(candidate,(8,16),58)
        with self.assertRaisesRegex(v.Violation, "Stage source"):
            verify_record(self.record,candidate)
        self.record["source_revision"] = "0"*40
        with self.assertRaisesRegex(v.Violation, "source revision"):
            verify_record(self.record,self.before)

    def test_stage_hash_and_host_budget_tamper(self):
        candidate = copy.deepcopy(self.record)
        candidate["stage"]["operations"][0]["material"] = 28
        with self.assertRaisesRegex(v.Violation, "Stage checksum"):
            verify_record(candidate,self.before)
        self.record["budget"]["checked_cells"] += 1
        with self.assertRaisesRegex(v.Violation, "resource count"):
            verify_record(self.record,self.before)

    def test_guard_and_clearance_projected_independently(self):
        for field, code in (("protected","guard"),("clearances","clearance")):
            with self.subTest(field=field):
                value = stage()
                value[field] = [[10,20,1,1]]
                with self.assertRaises(v.Violation) as error:
                    v.project_stage(value,self.before,{})
                self.assertEqual(error.exception.code,code)

    def test_unsupported_native_source_material(self):
        before = bytearray(self.before)
        v.put(before,(10,20),7)
        with self.assertRaisesRegex(v.Violation, "unsupported source material"):
            v.project_stage(stage(),before,{})

    def test_unsupported_shape_refuses_instead_of_ignoring(self):
        value = stage(operations=[{"shape":"polygon","material":58,"vertices":[]}])
        with self.assertRaisesRegex(v.Violation, "Unsupported shape"):
            v.project_stage(value,self.before,{})

    def test_receipt_and_point_capacity(self):
        with self.assertRaises(v.Violation):
            v.replay_receipts([{}]*(v.MAX_RECEIPTS+1), self.before, v.WORLD, 3, [])
        with self.assertRaises(v.Violation):
            v.point([512,0],"out of bounds")


class RecoveryContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.views, cls.stopped, cls.final, cls.result = recovery_fixture()

    def test_exact_eight_piece_recovery(self):
        result = v.verify_recovery(self.views,self.stopped,self.final,self.result)
        self.assertEqual(result["partial_checked_cells"],37)
        self.assertEqual(result["attachment_cells"],1024)
        self.assertEqual(result["solid_contact_requirements"],128)
        self.assertEqual(result["approved_outside_recovery_cells"],256)

    def test_partial_prefix_does_not_assume_one4096_chunk(self):
        result = dict(self.result)
        result["partial_checked_cells"] = 4096
        with self.assertRaisesRegex(v.Violation, "observed incomplete"):
            v.verify_recovery(self.views,self.stopped,self.final,result)

    def test_legacy_outside_preservation_claim_is_not_final_gate(self):
        result = {"partial_checked_cells":37,"preserved_outside_recovery":True,
                  "protected_passage_empty":True}
        with self.assertRaisesRegex(v.Violation, "Legacy or incomplete"):
            v.verify_recovery(self.views,self.stopped,self.final,result)

    def test_extra_outside_native_cell_fails_even_when_manifest_claims_preserved(self):
        altered = bytearray(self.final)
        v.put(altered,(500,500),58)
        with self.assertRaisesRegex(v.Violation, "exact declared 256"):
            v.verify_recovery(self.views,self.stopped,bytes(altered),self.result)

    def test_missing_hanger_cell_fails(self):
        altered = bytearray(self.final)
        v.put(altered,(64,144),0)
        with self.assertRaisesRegex(v.Violation, "exact declared 256"):
            v.verify_recovery(self.views,self.stopped,bytes(altered),self.result)

    def test_not_a_widened_attachment_bounding_box(self):
        altered = bytearray(self.final)
        v.put(altered,(300,150),58)
        with self.assertRaisesRegex(v.Violation, "exact declared 256"):
            v.verify_recovery(self.views,self.stopped,bytes(altered),self.result)

    def test_one_missing_contact_is_not_full_face_attachment(self):
        views = copy.deepcopy(self.views)
        views["attach-workshop-bays"]["record"]["stage"]["connections"].pop()
        with self.assertRaisesRegex(v.Violation, "128 full-face"):
            v.verify_recovery(views,self.stopped,self.final,self.result)

    def test_duplicate_contact_cannot_fill_denominator(self):
        views = copy.deepcopy(self.views)
        contacts = views["attach-workshop-bays"]["record"]["stage"]["connections"]
        contacts[-1] = copy.deepcopy(contacts[0])
        with self.assertRaisesRegex(v.Violation, "128 full-face"):
            v.verify_recovery(views,self.stopped,self.final,self.result)

    def test_declared_face_needs_prior_native_support(self):
        views = copy.deepcopy(self.views)
        before = bytearray(views["attach-workshop-bays"]["before"])
        v.put(before,(64,143),0)
        views["attach-workshop-bays"]["before"] = bytes(before)
        with self.assertRaisesRegex(v.Violation, "prior actual native face"):
            v.verify_recovery(views,self.stopped,self.final,self.result)

    def test_stopped_plane_must_match_actual_retired_prefix(self):
        altered = bytearray(self.stopped)
        v.put(altered,(100,200),58)
        with self.assertRaisesRegex(v.Violation, "Stopped full-World"):
            v.verify_recovery(self.views,bytes(altered),self.final,self.result)

    def test_recovery_cannot_clear_an_unwitnessed_suffix(self):
        views = copy.deepcopy(self.views)
        views["clear-stopped-prefix"]["rows"].append([100,200,58,0])
        with self.assertRaisesRegex(v.Violation, "exactly the actual"):
            v.verify_recovery(views,self.stopped,self.final,self.result)

    def test_protected_passage_is_measured(self):
        altered = bytearray(self.final)
        v.put(altered,(208,336),58)
        with self.assertRaises(v.Violation):
            v.verify_recovery(self.views,self.stopped,bytes(altered),self.result)


class PathsAndIdentities(unittest.TestCase):
    def test_raw_artifact_hash_and_relative_custody(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root/"exact.u16le").write_bytes(b"\0\0")
            custody = v.Custody(root)
            self.assertEqual(custody.read("exact.u16le",2,v.sha(b"\0\0")),b"\0\0")
            for name in ("../escape","/absolute","C:\\outside","a\\outside"):
                with self.subTest(name=name), self.assertRaises(v.Violation):
                    custody.read(name,1024)
            with self.assertRaisesRegex(v.Violation,"SHA-256"):
                custody.read("exact.u16le",2,"0"*64)

    def test_symlink_escape_when_supported(self):
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            root, outside = Path(first), Path(second)/"outside"
            outside.write_bytes(b"x")
            try:
                (root/"link").symlink_to(outside)
            except (OSError,NotImplementedError) as error:
                self.skipTest("Platform cannot create a test symlink: "+str(error))
            with self.assertRaises(v.Violation):
                v.Custody(root).read("link",16)

    def test_file_capacity_is_not_inferred_from_declared_length(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root/"large").write_bytes(b"abc")
            with self.assertRaisesRegex(v.Violation,"byte bound"):
                v.Custody(root).read("large",2)

    def test_duplicate_keys_nonfinite_and_deep_json(self):
        for raw in (b'{"a":1,"a":2}',b'{"a":NaN}',b'{"a":1e999}',b'['*50+b'0'+b']'*50):
            with self.subTest(raw=raw[:30]), self.assertRaises(v.Violation):
                v.strict_json(raw,"synthetic")

    def test_integral_float_hash_compatibility_only(self):
        self.assertEqual(v.inner_hash({"keep_fraction":1.0}),v.inner_hash({"keep_fraction":1}))
        with self.assertRaisesRegex(v.Violation,"nonintegral"):
            v.inner_hash({"density":0.65})

    def test_plane_base64_exact_length_and_canonical_encoding(self):
        self.assertEqual(v.decoded_plane("AAA=",2,"plane"),b"\0\0")
        for value in ("AAA=\n","AA==","AAAA","*AA="):
            with self.subTest(value=value), self.assertRaises(v.Violation):
                v.decoded_plane(value,2,"plane")

    def test_old_manifest_explicitly_refuses_new_final_contract(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary)/"hierarchy-native.json"
            path.write_text(json.dumps({"format":v.WITNESS_FORMAT,"source_revision":SOURCE,
                "failures":0,"checks":81,"core_capacity":16,"real_model_calls":0,
                "platform":"Linux","godot":"4.7-stable (official)",
                "result":{"extent":[512,512],"final_campaign_state":"completed",
                          "preserved_outside_recovery":True}}),encoding="utf-8")
            with self.assertRaises(v.Violation) as error:
                v.verify(path,SOURCE)
            self.assertEqual(error.exception.code,"legacy-final-contract")
            output = Path(temporary)/"independent-hierarchy-verification.json"
            with redirect_stdout(io.StringIO()) as captured:
                code = v.main([str(path),"--expected-source",SOURCE,"--output",str(output)])
            self.assertEqual(code,1)
            self.assertIn("HIERARCHY_NATIVE_VERIFICATION_RESULT",captured.getvalue())
            self.assertEqual(json.loads(output.read_text())["status"],"FAIL")
            with self.assertRaises(v.Violation) as default_error:
                v.verify(path,SOURCE,True)
            self.assertEqual(default_error.exception.code,"runtime")

    def test_output_cannot_overwrite_input(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary)/"hierarchy-native.json"
            path.write_text("{}",encoding="utf-8")
            with self.assertRaises(v.Violation):
                v.main([str(path),"--expected-source",SOURCE,"--output",str(path)])
            self.assertEqual(path.read_text(),"{}")


class CampaignAndGeometry(unittest.TestCase):
    def make_campaign(self):
        a = stage("a")
        b = stage("b")
        return {"format":v.CAMPAIGN_FORMAT,"id":"c","intent":"Synthetic hierarchy",
                "region":[0,0,512,512],"budget":{"native_checks":524288,"raster_candidates":2097152},
                "nodes":[{"id":"g","kind":"group","region":[0,0,512,512],"parent_id":"","depends_on":[]},
                         {"id":"a","kind":"typed","region":a["region"],"stage":a,"parent_id":"g","depends_on":[]},
                         {"id":"b","kind":"typed","region":b["region"],"stage":b,"parent_id":"","depends_on":["g"]}]}

    def test_group_dependency_is_flattened(self):
        flat = v.flatten_campaign(self.make_campaign())
        self.assertEqual(flat["stages"][1]["depends_on"],["a"])

    def test_session_revision_and_campaign_declared_dependencies_agree(self):
        archived = self.make_campaign()
        reconstructed = copy.deepcopy(archived)
        reconstructed["nodes"][2]["stage"]["depends_on"] = ["a"]
        self.assertEqual(v.flatten_campaign(archived), v.flatten_campaign(reconstructed))
        self.assertEqual(v.campaign_contract(archived), v.campaign_contract(reconstructed))

    def test_dependency_normalization_does_not_drop_other_contract_changes(self):
        original = self.make_campaign()
        missing_dependency = copy.deepcopy(original)
        missing_dependency["nodes"][2]["depends_on"] = []
        self.assertNotEqual(v.campaign_contract(original), v.campaign_contract(missing_dependency))
        altered_intent = copy.deepcopy(original)
        altered_intent["nodes"][2]["stage"]["intent"] = "Changed owner contract"
        self.assertNotEqual(v.campaign_contract(original), v.campaign_contract(altered_intent))

    def test_cycles_and_unknown_dependencies_refuse(self):
        for name in ("b","missing"):
            campaign = self.make_campaign()
            campaign["nodes"][1]["depends_on"] = [name]
            with self.assertRaises(v.Violation):
                v.flatten_campaign(campaign)

    def test_source_anchoring_is_not_just_equal_cell_count(self):
        before = bytearray(v.WORLD_BYTES)
        v.put(before,(10,10),58)
        anchored = [[11,10,0,28],[12,10,0,28]]
        floating = [[20,20,0,28],[21,20,0,28]]
        self.assertEqual(v.anchored_components(anchored,before)["unanchored_new_cells"],0)
        self.assertEqual(v.anchored_components(floating,before)["unanchored_new_cells"],2)

    def test_contacts_need_actual_orthogonal_occupancy(self):
        before = bytearray(v.WORLD_BYTES)
        v.put(before,(10,10),58)
        request = [{"kind":"solid-contact","a":[10,10],"b":[11,10]}]
        with self.assertRaises(v.Violation):
            v.validate_connections(request,before,v.WORLD)
        v.put(before,(11,10),28)
        self.assertEqual(len(v.validate_connections(request,before,v.WORLD)),1)
        request[0]["b"] = [11,11]
        with self.assertRaises(v.Violation):
            v.validate_connections(request,before,v.WORLD)

    def test_module_geometry_and_selected_identity(self):
        modules = []
        for module_id, _ in v.MODULE_INSTANCES.values():
            data = b"\x3a\x00\x00\x00\x00\x00\x1c\x00"
            module = {"format":"cybersand-native-module-v2","id":module_id,"extent":[2,2],
                      "geometry":{"encoding":"uint16-le-row-major",
                                  "cells_base64":base64.b64encode(data).decode("ascii"),
                                  "sha256":v.sha(data)}}
            module["content_sha256"] = v.inner_hash(module,module=True)
            modules.append(module)
        document = {"format":"cybersand-native-module-library-v1","modules":modules,"content_sha256":"a"*64}
        self.assertEqual(len(v.module_library(document)),3)
        document["modules"][0]["geometry"]["cells_base64"] = "AAAAAA=="
        with self.assertRaises(v.Violation):
            v.module_library(document)


if __name__ == "__main__":
    unittest.main()
