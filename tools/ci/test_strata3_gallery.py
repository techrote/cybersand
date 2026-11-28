#!/usr/bin/env python3
"""Source/evidence custody tests with labelled synthetic one-pixel PNG fixtures.

These are document-builder unit fixtures, never graphical execution evidence.
"""
from __future__ import annotations

import base64
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("strata3_gallery", ROOT / "tools/build_strata3_gallery.py")
gallery = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(gallery)
PIXEL = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")
SOURCE = "a" * 40
HASH = "b" * 64


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"))


class GalleryCustody(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix="strata3-gallery-synthetic-")
        self.root = Path(self.scratch.name)
        self.package = self.root / "package"
        self.campaign = self.package / "qualification/windows"
        self.campaign.mkdir(parents=True)
        self.output = self.package / "Gallery.html"
        self.original_root = gallery.ROOT
        gallery.ROOT = self.root
        self.report = {"schema":"strata3-workbench-campaign-v1", "status":"passed", "completed":True,
            "platform":"win32", "source_identity":{"source_commit":SOURCE,"source_tree":"c"*40,
                "source_inputs_sha256":{},"source_assets_sha256":{},"local_delta":[]},
            "godot":{"version":gallery.ENGINE_VERSION,"sha256":gallery.ENGINE_SHA["win32"]},
            "runtime":{"runtime_source_commit":"d"*40,
                "cybersand_runtime":{"path":"synthetic-native.dll","sha256":HASH,"size":1},
                "rapier_runtime":{"path":"synthetic-rapier.dll","sha256":HASH,"size":1}},
            "cases":[],"files_sha256":{}}
        for name in (gallery.GENERATOR,"godot/scripts/depth/strata_optical_profiles.gd",
                "godot/scripts/depth/strata_optics_configuration.gd","godot/tools/qualify_workbench_strata3.gd",
                "godot/scripts/depth/strata_optics_fixtures.gd"):
            self.source(name, "Synthetic unit source; not a Godot application.\n")
        for index, scene in enumerate(gallery.SCENES):
            metadata = {"id":scene,"title":"Synthetic <native> fixture "+scene,
                "description":"Unit fixture only, no rendering claim.","extent":[512,512]}
            if scene != "optics-readability-challenge":
                directory = "strata2" if scene in gallery.SCENES[:5] else "strata3"
                self.source("godot/data/"+directory+"/"+scene+".json", json.dumps(metadata))
            native = {plane:HASH for plane in gallery.PLANES}
            native_json = canonical(native)
            camera = {"origin":[0,0],"view_size":[512,512],"world_rect":[0,0,1,1]}
            for phase in ("install","reopen"):
                result = {"schema":"strata3-workbench-execution-v1","completed":True,"failures":[],
                    "scene":scene,"phase":phase,"source_revision":SOURCE,"ordinary_workbench":True,
                    "diagnostic_headless":False,"rendering_method":"gl_compatibility","display_server":"Windows",
                    "rendering_adapter":"SYNTHETIC UNIT FIXTURE, NOT AN ADAPTER","process_id":100+index*2+(phase=="reopen"),
                    "fresh_process_reopen":phase=="reopen","extent":[512,512],
                    "admission_elapsed_ms":50000 if phase=="install" else 40000,
                    "admission_target_ms":45000,"admission_target_met":phase=="reopen",
                    "plane_native_hashes_before":native,"plane_native_hashes_after":native,
                    "native_hashes_canonical_json":native_json,"profile_captures":[],"additional_captures":[],
                    "saved_optics":{"sha256":gallery.digest(b'{}'),"configuration_canonical_json":"{}"}}
                output_dir = scene+"/"+phase
                if phase == "install":
                    for profile in gallery.PROFILES:
                        config = {"profile":profile,"enabled":profile!="classic","planes":{"play":{"participates":False}}}
                        config_json = canonical(config)
                        filename = "profile-"+profile+".png"
                        self.evidence(output_dir+"/"+filename,PIXEL)
                        result["profile_captures"].append({"profile":profile,"filename":filename,"configuration":config,
                            "configuration_canonical_json":config_json,"configuration_sha256":gallery.digest(config_json.encode()),
                            "camera":camera,"actor_state":{"position":[256,256],"rotation":0.0,"linear_velocity":[0,0],"rapier_tick":0},
                            "geometry_group_sha256":gallery.digest(native_json.encode()),"sha256":gallery.digest(PIXEL),"optics_statistics":{}})
                    for extra_id in ("classic-return","compare-wipe","clarity-assistance","focus-play","focus-scripted","focus-effects","focus-background","optics-lab"):
                        filename = extra_id+".png"
                        self.evidence(output_dir+"/"+filename,PIXEL)
                        result["additional_captures"].append({"id":extra_id,"filename":filename,"sha256":gallery.digest(PIXEL),
                            "scope":"Synthetic supplemental fixture, no actual graphical claim.","camera":camera,
                            "geometry_group_sha256":gallery.digest(native_json.encode())})
                case = {"label":scene+"-"+phase,"scene":scene,"phase":phase,"result_path":output_dir+"/result.json",
                    "output_dir":output_dir,"exit_code":0,"result":result}
                self.report["cases"].append(case)
                self.save_case(case)
        self.motion_case()
        self.evidence("process-original.log",b"SYNTHETIC UNIT FIXTURE ONLY\n")
        self.save_report()

    def tearDown(self):
        gallery.ROOT = self.original_root
        self.scratch.cleanup()

    def source(self,name,text):
        path=self.root/name
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text(text)
        self.report["source_identity"]["source_inputs_sha256"][name]=gallery.digest(text.encode())

    def evidence(self,name,data):
        path=self.campaign/name
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_bytes(data)
        self.report["files_sha256"][name]=gallery.digest(data)

    def save_case(self,case):
        data=(json.dumps(case["result"],sort_keys=True)+"\n").encode()
        self.evidence(case["result_path"],data)
        case["report_sha256"]=gallery.digest(data)

    def save_report(self):
        (self.campaign/"campaign.json").write_text(json.dumps(self.report,sort_keys=True))

    def prepare(self):
        return gallery.prepare(self.campaign,self.output)

    def changed_case(self,mutator):
        case=self.report["cases"][0]
        mutator(case["result"])
        self.save_case(case)
        self.save_report()

    def progression_case(self):
        result=copy.deepcopy(self.report["cases"][0]["result"])
        result.update(phase="progression",process_id=999,profile_captures=[],additional_captures=[],
            progression_registration={"scope":"Synthetic unit fixture, no measured physical claim.","repeats":1},
            progression_samples=[{"profile":"classic","repeat":0,"elapsed_usec":1000,"callbacks":2,
                "physical_distribution_usec":{"count":1,"p50":500,"p95":500,"p99":500,"max":500},
                "observer_scope":"Synthetic unit fixture only.","physical_gpu_acceptance":False}])
        scene=gallery.SCENES[0]
        case={"label":scene+"-progression","scene":scene,"phase":"progression",
              "result_path":scene+"/progression/result.json","output_dir":scene+"/progression","exit_code":0,"result":result}
        self.report["cases"].append(case)
        self.save_case(case);self.save_report()
        return case

    def motion_case(self):
        result=copy.deepcopy(self.report["cases"][-2]["result"])
        result.update(phase="motion",process_id=998,profile_captures=[],additional_captures=[],motion_sequences=[])
        scene="optics-readability-challenge";output_dir=scene+"/motion"
        for profile in gallery.MOTION_PROFILES:
            config={"profile":profile,"enabled":profile!="classic","planes":{"play":{"participates":False}}}
            serialized=canonical(config)
            sequence={"profile":profile,"configuration":config,"configuration_canonical_json":serialized,
                      "configuration_sha256":gallery.digest(serialized.encode()),"quality":"balanced",
                      "scope":"Synthetic motion unit fixture only, never graphical or performance evidence.","frames":[]}
            for index in range(10):
                name=f"motion-{profile}-{index:02d}.png";self.evidence(output_dir+"/"+name,PIXEL)
                sequence["frames"].append({"index":index,"filename":name,"sha256":gallery.digest(PIXEL),"actual_image_size":[1,1],
                    "camera":{"origin":[index,0],"view_size":[512,512],"world_rect":[0,0,1,1]},
                    "actor_state":{"position":[256+index,256]},"native_tick":10+index,"rapier_tick":20+index,"captured_usec":1000+index*1000})
            result["motion_sequences"].append(sequence)
        case={"label":scene+"-motion","scene":scene,"phase":"motion","result_path":output_dir+"/result.json",
              "output_dir":output_dir,"exit_code":0,"result":result}
        self.report["cases"].append(case);self.save_case(case);self.save_report()
        return case

    def changed_motion(self,mutator):
        case=next(c for c in self.report["cases"] if c["phase"]=="motion")
        mutator(case["result"]);self.save_case(case);self.save_report()

    def test_complete_deterministic_build(self):
        data=self.prepare()
        self.assertEqual(data,self.prepare())
        result=gallery.build(self.campaign,self.output)
        self.assertEqual(result["matched_profile_captures"],99)
        self.assertEqual(result["additional_captures"],72)
        self.assertEqual(json.loads(self.output.with_suffix(".inputs.json").read_text()),data)
        self.assertEqual(gallery.digest(self.output.read_bytes()),result["html_sha256"])
        self.assertEqual(self.output.read_text(),gallery.render(data))

    def test_html_escapes_source_text_and_runs_offline(self):
        data=self.prepare()
        data["scenes"][0]["title"]='</script><img src="outside" onerror="alert(1)">'
        rendered=gallery.render(data)
        self.assertNotIn('</script><img src="outside"',rendered)
        self.assertIn('\\u003c/script>',rendered)
        self.assertIn('&lt;/script&gt;',rendered)
        self.assertNotIn('fetch(',rendered)
        self.assertIn("connect-src 'none'",rendered)

    def test_failed_campaign_does_not_emit_gallery(self):
        self.report["status"]="failed";self.save_report()
        with self.assertRaisesRegex(ValueError,"passing campaign"):self.prepare()
        self.assertFalse(self.output.exists())

    def test_wrong_source_commit_refuses(self):
        self.report["source_identity"]["source_commit"]="e"*40;self.save_report()
        with self.assertRaisesRegex(ValueError,"source-bound ordinary"):self.prepare()

    def test_local_changes_refuse(self):
        self.report["source_identity"]["local_delta"]=["changed.gd"];self.save_report()
        with self.assertRaisesRegex(ValueError,"clean source"):self.prepare()

    def test_wrong_engine_refuses(self):
        self.report["godot"]["version"]="4.7.2";self.save_report()
        with self.assertRaisesRegex(ValueError,"pinned official"):self.prepare()

    def test_native_runtime_identity_required(self):
        del self.report["runtime"]["cybersand_runtime"]["sha256"];self.save_report()
        with self.assertRaisesRegex(ValueError,"runtime byte identity"):self.prepare()

    def test_changed_original_capture_refuses(self):
        path=self.campaign/gallery.SCENES[0]/"install/profile-classic.png"
        path.write_bytes(PIXEL+b"altered")
        with self.assertRaisesRegex(ValueError,"evidence bytes changed"):self.prepare()

    def test_changed_non_image_log_is_not_discarded(self):
        (self.campaign/"process-original.log").write_text("edited")
        with self.assertRaisesRegex(ValueError,"evidence bytes changed"):self.prepare()

    def test_missing_profile_refuses(self):
        self.changed_case(lambda r:r["profile_captures"].pop())
        with self.assertRaisesRegex(ValueError,"eleven matched"):self.prepare()

    def test_missing_fresh_process_refuses(self):
        self.report["cases"]=[case for case in self.report["cases"] if not(case["scene"]==gallery.SCENES[-1] and case["phase"]=="reopen")];self.save_report()
        with self.assertRaisesRegex(ValueError,"fresh-process reopen"):self.prepare()

    def test_same_process_reopen_refuses(self):
        reopened=self.report["cases"][1]
        reopened["result"]["process_id"]=self.report["cases"][0]["result"]["process_id"]
        self.save_case(reopened);self.save_report()
        with self.assertRaisesRegex(ValueError,"Fresh-process"):self.prepare()

    def test_missing_native_invariance_refuses(self):
        self.changed_case(lambda r:r.update(plane_native_hashes_after={p:"f"*64 for p in gallery.PLANES}))
        with self.assertRaisesRegex(ValueError,"native material state"):self.prepare()

    def test_changed_actor_cannot_be_called_matched(self):
        def mutate(r):r["profile_captures"][1]["actor_state"]={"position":[257,256]}
        self.changed_case(mutate)
        with self.assertRaisesRegex(ValueError,"actor state"):self.prepare()

    def test_changed_camera_cannot_be_called_matched(self):
        def mutate(r):r["profile_captures"][1]["camera"]={"origin":[1,0],"view_size":[512,512],"world_rect":[0,0,1,1]}
        self.changed_case(mutate)
        with self.assertRaisesRegex(ValueError,"camera, actor"):self.prepare()

    def test_profile_geometry_group_is_source_bound(self):
        def mutate(r):r["profile_captures"][1]["geometry_group_sha256"]="f"*64
        self.changed_case(mutate)
        with self.assertRaisesRegex(ValueError,"geometry group"):self.prepare()

    def test_changed_configuration_serialization_refuses(self):
        def mutate(r):r["profile_captures"][1]["configuration"]["enabled"]=False
        self.changed_case(mutate)
        with self.assertRaisesRegex(ValueError,"exact captured serialization"):self.prepare()

    def test_headless_cannot_impersonate_graphical(self):
        self.changed_case(lambda r:r.update(diagnostic_headless=True))
        with self.assertRaisesRegex(ValueError,"graphical execution"):self.prepare()

    def test_receipt_copy_is_not_authoritative(self):
        self.report["cases"][0]["result"]["failures"]=["hidden"]
        self.save_report()
        with self.assertRaisesRegex(ValueError,"original campaign witness"):self.prepare()

    def test_changed_source_recipe_refuses(self):
        path=self.root/"godot/data/strata2"/(gallery.SCENES[0]+".json")
        path.write_text(path.read_text().replace("Synthetic","Unqualified"))
        with self.assertRaisesRegex(ValueError,"source differs"):self.prepare()

    def test_path_escape_refuses_even_when_hashed(self):
        self.report["files_sha256"]["../escape"]=HASH;self.save_report()
        with self.assertRaisesRegex(ValueError,"Unsafe evidence path"):self.prepare()

    def test_linked_original_refuses(self):
        path=self.campaign/"process-original.log"
        elsewhere=self.root/"external.log";elsewhere.write_bytes(path.read_bytes())
        path.unlink();path.symlink_to(elsewhere)
        with self.assertRaisesRegex(ValueError,"Linked evidence"):self.prepare()

    def test_output_cannot_reference_outside_package(self):
        elsewhere=self.root/"other";elsewhere.mkdir()
        with self.assertRaisesRegex(ValueError,"inside the offline package"):
            gallery.prepare(self.campaign,elsewhere/"Gallery.html")

    def test_missing_supplemental_focus_refuses(self):
        self.changed_case(lambda r:r["additional_captures"].pop())
        with self.assertRaisesRegex(ValueError,"Missing actual focus"):self.prepare()

    def test_reopen_changed_authored_optics_refuses(self):
        reopened=self.report["cases"][1]
        reopened["result"]["saved_optics"]["sha256"]="e"*64
        self.save_case(reopened);self.save_report()
        with self.assertRaisesRegex(ValueError,"authored optical settings"):self.prepare()

    def test_png_crc_and_end_checked(self):
        self.assertEqual(gallery.png_extent(PIXEL),[1,1])
        with self.assertRaisesRegex(ValueError,"PNG"):gallery.png_extent(b"not PNG")
        changed=bytearray(PIXEL);changed[30]^=1
        with self.assertRaisesRegex(ValueError,"CRC"):gallery.png_extent(bytes(changed))
        with self.assertRaisesRegex(ValueError,"after original PNG end"):gallery.png_extent(PIXEL+b"extra")

    def test_admission_failures_remain_visible_in_passing_functional_campaign(self):
        performance=self.prepare()["scenes"][0]["performance"]
        self.assertEqual(performance["admission"]["install"]["elapsed_ms"],50000)
        self.assertIs(performance["admission"]["install"]["target_met"],False)
        self.assertIs(performance["admission"]["reopen"]["target_met"],True)
        self.assertEqual(performance["admission"]["install"]["target_ms"],45000)

    def test_missing_performance_is_unrecorded_never_zero_cost(self):
        performance=self.prepare()["scenes"][0]["performance"]
        self.assertEqual(performance["progression"]["status"],"not_recorded")
        self.assertIsNone(performance["optical_cost_observations"])
        self.assertEqual(performance["progression"]["reports"],[])

    def test_missing_admission_is_not_assumed_zero(self):
        self.changed_case(lambda r:r.pop("admission_elapsed_ms"))
        with self.assertRaisesRegex(ValueError,"actual observation"):self.prepare()

    def test_admission_target_cannot_be_weakened_or_miss_hidden(self):
        self.changed_case(lambda r:r.update(admission_target_ms=60000,admission_target_met=True))
        with self.assertRaisesRegex(ValueError,"45-second target"):self.prepare()

    def test_progression_report_is_linked_and_keeps_observer_scope(self):
        case=self.progression_case()
        data=self.prepare()
        progression=data["scenes"][0]["performance"]["progression"]
        self.assertEqual(progression["status"],"recorded")
        self.assertEqual(progression["reports"][0]["sha256"],case["report_sha256"])
        self.assertEqual(progression["reports"][0]["url"],"qualification/windows/"+case["result_path"])
        self.assertEqual(progression["reports"][0]["samples"][0]["observer_scope"],"Synthetic unit fixture only.")
        self.assertEqual(data["scenes"][1]["performance"]["progression"]["status"],"not_recorded")
        self.assertIn("Original physical progression report",gallery.render(data))

    def test_progression_report_requires_actual_source_witness(self):
        case=self.progression_case()
        case["result"]["source_revision"]="f"*40
        self.save_case(case);self.save_report()
        with self.assertRaisesRegex(ValueError,"source-bound ordinary"):self.prepare()

    def test_progression_cannot_claim_physical_gpu_acceptance(self):
        case=self.progression_case()
        case["result"]["progression_samples"][0]["physical_gpu_acceptance"]=True
        self.save_case(case);self.save_report()
        with self.assertRaisesRegex(ValueError,"hosted scope"):self.prepare()

    def test_progression_report_copy_cannot_replace_original(self):
        case=self.progression_case()
        case["result"]["progression_samples"][0]["elapsed_usec"]=2000
        self.save_report()
        with self.assertRaisesRegex(ValueError,"original campaign witness"):self.prepare()

    def test_duplicate_progression_observation_rejected(self):
        case=self.progression_case()
        case["result"]["progression_samples"]*=2
        self.save_case(case);self.save_report()
        with self.assertRaisesRegex(ValueError,"Duplicate profile/repeat"):self.prepare()

    def test_boolean_is_not_an_actual_process_exit_code(self):
        self.report["cases"][0]["exit_code"]=False;self.save_report()
        with self.assertRaisesRegex(ValueError,"actual execution case"):self.prepare()

    def test_motion_originals_retain_moving_camera_actor_and_arbitrary_review_scope(self):
        data=self.prepare();motion=data["scenes"][-1]["motion"]
        self.assertEqual(len(motion["sequences"]),4)
        sequence=motion["sequences"][0]
        self.assertEqual(len(sequence["frames"]),10)
        self.assertNotEqual(sequence["frames"][0]["camera"],sequence["frames"][1]["camera"])
        self.assertNotEqual(sequence["frames"][0]["actor_state"],sequence["frames"][1]["actor_state"])
        self.assertIn("not matched paused",sequence["comparison_limit"])
        self.assertIn("arbitrary cadence",gallery.render(data))
        self.assertIsNone(data["scenes"][0]["motion"])

    def test_missing_motion_report_refuses_full_gallery(self):
        self.report["cases"]=[case for case in self.report["cases"] if case["phase"]!="motion"];self.save_report()
        with self.assertRaisesRegex(ValueError,"instrumented motion inspection report"):self.prepare()

    def test_motion_duplicate_or_missing_profile_refuses(self):
        self.changed_motion(lambda r:r["motion_sequences"].pop())
        with self.assertRaisesRegex(ValueError,"four original profile sequences"):self.prepare()

    def test_motion_cannot_relabel_still_as_progress(self):
        def mutate(r):r["motion_sequences"][0]["frames"][1]["rapier_tick"]=20
        self.changed_motion(mutate)
        with self.assertRaisesRegex(ValueError,"strictly advancing"):self.prepare()

    def test_motion_timestamp_must_advance(self):
        def mutate(r):r["motion_sequences"][0]["frames"][1]["captured_usec"]=1000
        self.changed_motion(mutate)
        with self.assertRaisesRegex(ValueError,"strictly advancing"):self.prepare()

    def test_motion_framebuffer_receipt_must_match_original_png(self):
        def mutate(r):r["motion_sequences"][0]["frames"][1]["actual_image_size"]=[1600,1000]
        self.changed_motion(mutate)
        with self.assertRaisesRegex(ValueError,"actual framebuffer dimensions"):self.prepare()

    def test_motion_configuration_is_source_bound(self):
        def mutate(r):r["motion_sequences"][0]["configuration"]["enabled"]=True
        self.changed_motion(mutate)
        with self.assertRaisesRegex(ValueError,"original protected-Play configuration"):self.prepare()

    def test_motion_original_hash_refuses_relabelled_bytes(self):
        def mutate(r):r["motion_sequences"][0]["frames"][1]["sha256"]="e"*64
        self.changed_motion(mutate)
        with self.assertRaisesRegex(ValueError,"Motion image bytes"):self.prepare()

    def test_motion_never_requires_frozen_play_materials(self):
        self.changed_motion(lambda r:r.update(plane_native_hashes_after={p:"e"*64 if p=="play" else HASH for p in gallery.PLANES}))
        self.assertEqual(len(self.prepare()["scenes"][-1]["motion"]["sequences"]),4)


if __name__=="__main__":
    unittest.main()
