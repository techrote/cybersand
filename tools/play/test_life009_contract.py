#!/usr/bin/env python3
"""Synthetic verifier controls only; these are not engine measurements."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

from life009_contract import MARKER, RIGS, extract, verify_inventory, verify_process, verify_result
import run_life009_campaign as campaign

SOURCE = "1" * 40


def fixture(rig="jetbarrel"):
    state = dict(worker=11, session=12, bridge=13, run_id="test-only-synthetic-run", epoch=1,
                 world_generation=1, native_backend="native-phased", physics_tick=10, bridge_step=10, native_tick=10,
                 snapshot_serial=1, time_usec=1000, control_generation=1, sequence=1,
                 pending_edges=0, main_callbacks=1, physics_callbacks=1, accepted_commands=1,
                 lap_ticks=0, native_paused=False, paused=False, suspended=False, rearm=False,
                 position=[178., 304.], move=[0, 0], fault="")
    move = [1, 0] if rig == "acrobat" else [0, -1]
    records = []

    def callback(phase, applied=False, advance=True):
        state["time_usec"] += 18000
        state["main_callbacks"] += 1
        state["physics_callbacks"] += 1
        before = copy.deepcopy(state)
        if advance:
            state["physics_tick"] += 1
            state["bridge_step"] += 1
            state["native_tick"] += 1
        state["time_usec"] += 20
        prep = {}
        if applied:
            state["accepted_commands"] += 1
            state["sequence"] += 1
            state["move"] = move[:]
            prep = dict(sequence=state["sequence"], control_generation=state["control_generation"],
                        admitted_tick=before["physics_tick"], move=move[:])
        records.append(dict(phase=phase, before=before, after=copy.deepcopy(state),
                            prepared=prep, dropped_input_control=phase == "dropped"))

    identity = copy.deepcopy(state)
    for _ in range(4): callback("dropped")
    for _ in range(2): callback("neutral_before")
    for _ in range(4): callback("active", True)
    pre = copy.deepcopy(state)
    state.update(paused=True, native_paused=True, suspended=True, rearm=True,
                 control_generation=2, snapshot_serial=2, move=[0, 0])
    ack = copy.deepcopy(state)
    for _ in range(22): callback("paused", advance=False)
    end = copy.deepcopy(state)
    state.update(paused=False, native_paused=False, suspended=False)
    for _ in range(4): callback("held")
    denied = dict(accepted=False, reason="observation_not_issued", accepted_delta=0,
                  rejected_delta=1, observed_tick=pre["physics_tick"],
                  actual_tick=pre["physics_tick"]+1, sequence_before=5, sequence_after=5)
    state["rearm"] = False
    for _ in range(4): callback("fresh", True)
    row = dict(rig=rig, identity=identity, recipe_hash="synthetic-unit-fixture-not-runtime",
               worker_capacity=4, expected_move=move, pre_pause=pre, pause_ack=ack, pause_end=end,
               final=copy.deepcopy(state), stale_refusal=denied, records=records,
               queued_edges_before_pause=[dict(button="primary", pressed=True), dict(button="primary", pressed=False)],
               completed=True, capture_overflow=False,
               waits=[dict(name=str(i), started_usec=0, ended_usec=1000, deadline_usec=15000000,
                           passed=True) for i in range(10)])
    return dict(schema="play-life009-v2", source_revision=SOURCE, rig=rig, row=row,
                display_server="headless", physics_engine="Rapier2D",
                assertions=100, failures=0, elapsed_usec=2000000, teardown_usec=1000, worker_joined=True,
                session_retired=True, real_host=True, automatic_callbacks=True,
                headless_focus_seam=True, input_suppression_is_negative_control=True,
                manual_physics_calls=0, retries=0, rendered_fps_measured=False,
                physical_devices_qualified=False, human_feel_qualified=False,
                shader_startup_qualified=False)


class Controls(unittest.TestCase):
    def reject(self, mutate):
        value = fixture()
        mutate(value)
        with self.assertRaises((ValueError, KeyError, TypeError)):
            verify_result(value, "jetbarrel", SOURCE)

    def test_valid_all_five(self):
        for rig in RIGS:
            self.assertTrue(verify_result(fixture(rig), rig, SOURCE)["same_owner"])
        verify_inventory(list(RIGS))

    def test_failures_and_unsupported_claims(self):
        mutations = [lambda v: v.update(failures=1), lambda v: v.update(source_revision="2"*40),
                     lambda v: v.update(worker_joined=False), lambda v: v.update(session_retired=False),
                     lambda v: v.update(automatic_callbacks=False), lambda v: v.update(retries=1),
                     lambda v: v.update(manual_physics_calls=1), lambda v: v.update(shader_startup_qualified=True),
                     lambda v: v.update(display_server="x11"), lambda v: v.update(physics_engine="GodotPhysics2D"),
                     lambda v: v.update(elapsed_usec=150000001), lambda v: v["row"].update(capture_overflow=True),
                     lambda v: v["row"].update(completed=False), lambda v: v["row"].update(records=[])]
        for mutation in mutations:
            with self.subTest(mutation=mutation): self.reject(mutation)

    def test_input_and_clock_counterexamples(self):
        def record(v, phase):
            return next(r for r in v["row"]["records"] if r["phase"] == phase)
        mutations = [lambda v: record(v,"active").update(prepared={}),
                     lambda v: record(v,"active")["after"].update(move=[0,0]),
                     lambda v: record(v,"active")["prepared"].update(sequence=999),
                     lambda v: record(v,"active")["prepared"].update(admitted_tick=999),
                     lambda v: record(v,"active")["after"].update(bridge_step=999),
                     lambda v: record(v,"held")["after"].update(rearm=False),
                     lambda v: record(v,"held")["after"].update(move=[0,-1]),
                     lambda v: record(v,"dropped")["after"].update(move=[0,-1]),
                     lambda v: record(v,"dropped").update(dropped_input_control=False),
                     lambda v: record(v,"fresh")["after"].update(fault="fault"),
                     lambda v: record(v,"fresh")["after"].update(native_backend="gdscript"),
                     lambda v: record(v,"fresh")["after"].update(position=[float("nan"),0])]
        for mutation in mutations:
            with self.subTest(mutation=mutation): self.reject(mutation)

    def test_owner_replacement_and_pause_drift(self):
        for key in ("worker", "session", "bridge", "epoch", "run_id", "world_generation"):
            self.reject(lambda v, k=key: v["row"]["records"][-1]["after"].update({k:999}))
        for key,value in [("native_tick",999), ("bridge_step",999), ("position",[0,0]),
                          ("lap_ticks",999), ("pending_edges",2), ("native_paused",False),
                          ("main_callbacks",1), ("time_usec",1000)]:
            self.reject(lambda v,k=key,x=value: v["row"]["pause_end"].update({k:x}))

    def test_stale_refusal_must_be_generation_not_expiry(self):
        for key,value in [("accepted",True), ("reason","expired_observation"),
                          ("actual_tick",999), ("accepted_delta",1), ("sequence_after",999)]:
            self.reject(lambda v,k=key,x=value: v["row"]["stale_refusal"].update({k:x}))

    def test_late_wait_false_wait_and_wrong_input(self):
        self.reject(lambda v: v["row"]["waits"][0].update(ended_usec=15000001))
        self.reject(lambda v: v["row"]["waits"][0].update(passed=False))
        self.reject(lambda v: v["row"].update(expected_move=[1,0]))
        self.reject(lambda v: v["row"].update(queued_edges_before_pause=[]))
        self.reject(lambda v: v.update(teardown_usec=15000001))
        self.reject(lambda v: v.pop("teardown_usec"))
        self.reject(lambda v: v.update(schema="play-life009-v1"))

    def test_missing_duplicate_or_failure_marker(self):
        valid = MARKER + json.dumps(fixture())
        self.assertEqual(extract(valid)["rig"], "jetbarrel")
        for text in ("", valid+"\n"+valid, "ERROR: failure\n"+valid, "SKIP\n"+valid):
            with self.assertRaises(ValueError): extract(text)
        for rigs in ([], list(RIGS)[:-1], list(RIGS)+[RIGS[0]]):
            with self.assertRaises(ValueError): verify_inventory(rigs)

    def test_exact_signed_object_ids(self):
        value = fixture()
        row = value["row"]
        states = [row[name] for name in ("identity", "pre_pause", "pause_ack", "pause_end", "final")]
        states += [r[side] for r in row["records"] for side in ("before", "after")]
        for state in states:
            state["worker"] = -9223371966273026388
            state["bridge"] = -9223371883074809094
        self.assertTrue(verify_result(value, "jetbarrel", SOURCE)["same_owner"])
        # Adjacent large identities must not collapse through float rounding.
        row["records"][-1]["after"]["worker"] += 1
        with self.assertRaises(ValueError):
            verify_result(value, "jetbarrel", SOURCE)
        for invalid in (0, True, 1.5, float("nan"), 1 << 63, -(1 << 63) - 1, "11"):
            self.reject(lambda v, x=invalid: v["row"]["identity"].update(worker=x))

    def test_process_skips_and_late_exit_cannot_pass(self):
        valid = dict(status="passed", returncode=0, timeout_seconds=180, seconds=10,
                     skip_messages=[], diagnostic_error=False, launch_error=None, capture_error=None)
        verify_process(valid,180)
        for key,value in [("status","skipped"),("returncode",1),("seconds",180.001),
                          ("seconds",float("nan")),("timeout_seconds",240),("skip_messages",["SKIP"]),
                          ("capture_error","capture failed")]:
            with self.subTest(field=key), self.assertRaises(ValueError):
                verify_process(valid|{key:value},180)


class ParserControls(unittest.TestCase):
    """Exercise the original false-pass through the complete offline entry point."""
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.output = Path(self.tmp.name)
        original = campaign.git("show", "584b9c35085e45a0ab911730965b3cc30474dfd0:godot/tests/play_life009_same_owner_case.gd")
        (self.output / "original-584b-helper.gd").write_bytes(original)
        self.records = {"original_source_sha256": campaign.ORIGINAL_PARSER_SHA256}
        for label in ("original", "current"):
            process = dict(name="parser-" + label, log="parser-" + label + ".log",
                           status="failed" if label == "original" else "passed",
                           returncode=1 if label == "original" else 0, seconds=1,
                           timeout_seconds=30, diagnostic_error=label == "original",
                           launch_error=None, capture_error=None, skip_messages=[], timeout_kind=None)
            text = ('SCRIPT ERROR: Parse Error: Expected closing ")" after call arguments.\n'
                    '   at: GDScript::reload (/tmp/original-584b-helper.gd:205)\n'
                    if label == "original" else "Godot parser completed\n")
            (self.output / process["log"]).write_text(text, encoding="utf-8")
            self.records[label] = {"process": process, "log_sha256": campaign.sha(self.output / process["log"])}
            self.receipt(label)
        self.report = dict(schema="play-life009-campaign-v1", source_commit=SOURCE,
                           source_tree="2" * 40, platform="synthetic-unit-only", completed=True, errors=[],
                           source_unchanged=True, runtimes_unchanged=True, production_paths_unchanged_from_base=True,
                           godot_identity={"version": campaign.VERSION}, parser_controls=self.records, rows=[])
        imported = self.records["current"]["process"] | {"name": "import", "log": "import.log", "timeout_seconds": 240}
        (self.output / "import.log").write_text("Imported\n", encoding="utf-8")
        self.report["import"] = imported
        self.report["import_log_sha256"] = campaign.sha(self.output / "import.log")
        for rig in RIGS:
            result = fixture(rig)
            name = "test_play_life009_" + rig
            process = imported | {"name": name, "log": name + ".log", "timeout_seconds": 180}
            (self.output / process["log"]).write_text(MARKER + json.dumps(result) + "\n", encoding="utf-8")
            campaign.write(self.output / (name + ".process.json"), process)
            self.report["rows"].append(dict(rig=rig, process=process, process_record=name + ".process.json",
                observed_total_seconds=1, log_sha256=campaign.sha(self.output / process["log"]),
                result=result, summary=verify_result(result, rig, SOURCE)))

    def receipt(self, label):
        item = self.records[label]
        item["log_sha256"] = campaign.sha(self.output / item["process"]["log"])
        campaign.write(self.output / ("parser-" + label + ".process.json"), item["process"])

    def verify(self):
        campaign.write(self.output / "parser-controls.json", self.records)
        campaign.write(self.output / "campaign.json", self.report)
        return campaign.verify_directory(self.output)

    def test_valid_registered_failure_and_success(self):
        self.assertEqual(self.verify()["status"], "passed")

    def test_unexpected_original_success_is_rejected(self):
        self.records["original"]["process"].update(status="passed", returncode=0, diagnostic_error=False)
        (self.output / "parser-original.log").write_text("No parser error\n", encoding="utf-8")
        self.receipt("original")
        with self.assertRaisesRegex(ValueError, "did not fail as expected"):
            self.verify()

    def test_wrong_diagnostic_or_location_is_rejected(self):
        path = self.output / "parser-original.log"
        expected = path.read_text(encoding="utf-8")
        for text in (expected.replace('Expected closing ")" after call arguments.', "Unexpected identifier."),
                     expected.replace(":205)", ":206)"), expected + "SCRIPT ERROR: second failure\n"):
            with self.subTest(text=text):
                path.write_text(text, encoding="utf-8")
                self.receipt("original")
                with self.assertRaisesRegex(ValueError, "different reason"):
                    self.verify()

    def test_interrupted_controls_cannot_pass(self):
        for label in ("original", "current"):
            old = copy.deepcopy(self.records[label]["process"])
            for key, value in (("timeout_kind", "deadline"), ("launch_error", "no executable"),
                               ("capture_error", "lost log"), ("skip_messages", ["SKIP"]),
                               ("timeout_seconds", 60), ("seconds", 30.001)):
                with self.subTest(label=label, field=key):
                    self.records[label]["process"] = old | {key: value}
                    self.receipt(label)
                    with self.assertRaises(ValueError):
                        self.verify()
            self.records[label]["process"] = old
            self.receipt(label)

    def test_receipt_source_and_log_identity(self):
        campaign.write(self.output / "parser-original.process.json", self.records["original"]["process"] | {"seconds": 2})
        with self.assertRaisesRegex(ValueError, "receipt changed"):
            self.verify()
        self.receipt("original")
        (self.output / "original-584b-helper.gd").write_text("extends SceneTree\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "source changed"):
            self.verify()

    def test_current_log_errors_cannot_be_hidden_by_receipt(self):
        (self.output / "parser-current.log").write_text("SCRIPT ERROR: Parse Error: bad\n", encoding="utf-8")
        self.receipt("current")
        with self.assertRaisesRegex(ValueError, "Current parser log"):
            self.verify()


if __name__ == "__main__":
    unittest.main(verbosity=2)
