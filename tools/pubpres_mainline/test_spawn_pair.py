"""Refuse incomplete comparison evidence and keep unavailable clocks absent."""
from copy import deepcopy
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).parent))
import run_spawn_pair as pair


class SpawnPair(unittest.TestCase):
    def cohort(self):
        registration = json.loads(pair.REGISTRATION.read_bytes())
        sources = {role: {"source_commit": role*40, "source_tree": role.lower()*40,
                          "native_runtime_sha256": role*64} for role in ("P", "C")}
        driver = {"source_commit": sources["C"]["source_commit"], "source_tree": sources["C"]["source_tree"]}
        arms = []
        for index, plan in enumerate(registration["order"]):
            role = plan["role"]
            arm = {"index": index, "plan": deepcopy(plan), "pass": True,
                   "identity": {"source": sources[role]["source_commit"], "source_tree": sources[role]["source_tree"],
                                "graphical": True, "selected": pair.common.SELECTORS,
                                "native_sha256": role*64, "driver": driver, "fixtures": {"observer": "unchanged"}},
                   "results": []}
            modes = plan["recording_order"].split("-") if plan["recording"] == "both" else [plan["recording"]]
            for scene in registration["scenes"]:
                for mode in modes:
                    cases = []
                    for label in registration["cases"]:
                        row = {key: 100 if role == "P" else 20 for key in pair.TIMINGS if "." not in key}
                        row.update(label=label, accepted=True, input_upward_pose_response_observed_usec=None,
                                   observed_draw_callback_gaps={"p95_usec": 100, "maximum_usec": 200},
                                   physical_gaps={"p95_usec": 120000, "maximum_usec": 280000} if mode == "on" else None,
                                   physical_gap_context_both_boundaries={"maximum_usec": 300000},
                                   physical_unfinished_suffix_usec=5000,
                                   first_completed_step_usec=130 if mode == "on" else None,
                                   cadence_return={}, post_admission={name.split(".")[1]: 30 for name in pair.RATES})
                        cases.append(row)
                    ready = {key: "unchanged" for key in ("extent", "authored_setup_sha256", "authored_actor_count",
                        "engine_sha256", "rapier_sha256", "render_thread_inline", "render_driver", "display_server", "adapter", "platform")}
                    ready.update(scene=scene, source_commit=sources[role]["source_commit"], native_sha256=role*64,
                        wave_flow={key: "unchanged" for key in ("parameters", "workers_requested", "water_cells", "water_quantity", "construction_options")})
                    raw = [{"label": label, "kind": "place", "fire": False, "position": [280, 120], "actor_instance": 2}
                           for label in registration["cases"]]
                    arm["results"].append({"scene": scene, "recording": mode, "pass": True, "startup": ready,
                        "spawn": {"recording": mode == "on", "cases": raw},
                        "reduced": {"cases": cases, "recorder_closed": mode == "on", "recorder_loss_intervals": [],
                                    "recorded_actual_steps": 10 if mode == "on" else 0, "recorded_draw_callbacks": 10 if mode == "on" else 0}})
            arms.append(arm)
        return arms, registration, sources

    def test_balanced_repeated_population_and_unavailable_response_clock(self):
        result = pair.qualify(*self.cohort())
        first = result["comparisons"][0]["candidate_vs_owner_recording_off"]
        self.assertEqual(first["request_latency_usec"]["candidate_to_reference_ratio"], .2)
        self.assertIsNone(first["input_upward_pose_response_observed_usec"]["candidate_to_reference_ratio"])
        self.assertEqual(result["candidate_exact_physical"][0]["p95_deficit_usec"], 20000)
        self.assertEqual(result["candidate_exact_physical"][0]["maximum_deficit_usec"], 30000)
        self.assertEqual(result["physical_owner_acceptance"], "HOLD")

    def test_application_and_measurement_driver_identities_are_checked_separately(self):
        arms, registration, sources = self.cohort()
        driver = {"source_commit": "d" * 40, "source_tree": "e" * 40}
        for arm in arms:
            arm["identity"]["driver"] = dict(driver)
        result = pair.qualify(arms, registration, sources, driver)
        self.assertEqual(result["physical_owner_acceptance"], "HOLD")
        self.assertEqual(sources["C"]["source_commit"], "C" * 40)
        with self.assertRaisesRegex(ValueError, "Spawn source, graphical mode or selected policy differs"):
            pair.qualify(arms, registration, sources)

    def test_missing_failed_and_reordered_arm_refused(self):
        for mutation in (lambda arms: arms.pop(), lambda arms: arms[1].update({"pass": False}),
                         lambda arms: arms[1].update({"index": 2}),
                         lambda arms: arms[1]["results"].reverse()):
            arms, registration, sources = self.cohort()
            mutation(arms)
            with self.assertRaises(ValueError):
                pair.qualify(arms, registration, sources)

    def test_changed_fixture_source_native_and_recording_loss_refused(self):
        for mutation in (
            lambda arm: arm["results"][0]["startup"].update({"adapter": "another host"}),
            lambda arm: arm["identity"].update({"source": "foreign"}),
            lambda arm: arm["identity"].update({"native_sha256": "foreign"}),
            lambda arm: arm["results"][0]["reduced"].update({"recorder_loss_intervals": [["loss", 100]]}),
            lambda arm: arm["results"][1]["reduced"].update({"recorded_actual_steps": 1}),
        ):
            arms, registration, sources = self.cohort()
            mutation(arms[1])
            with self.assertRaises(ValueError):
                pair.qualify(arms, registration, sources)


if __name__ == "__main__":
    unittest.main()
