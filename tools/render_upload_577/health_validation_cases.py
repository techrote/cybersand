"""Adversarial receipt controls shared by Python and actual Windows PS5.1.

These controls target the reproduced worker-before-Main failure and legitimate
actor handoff pause. They do not exercise or model rendering implementation.
"""
from __future__ import annotations

import copy


def healthy_receipt(workload: str = "active") -> dict:
    active = workload in {"active", "dormant", "actor"}
    running = False

    def observation(stage: str, frame: int, ordinal: int, play: bool, requested_paused: bool) -> dict:
        nonlocal running
        previous = running
        running = running or (stage != "final_after_worker_join" and not requested_paused)
        # Paused native publications are legitimate at both initial handshake
        # and later actor-sample holds. Main/requested pause intent stays clear.
        snapshot = {"available": True, "snapshot_serial": ordinal + 1, "published_usec": ordinal + 1,
                    "tick_index": max(0, ordinal - 1), "simulation_world_revision": ordinal + 1,
                    "world_revision": ordinal + 1, "render_world_generation": 2,
                    "render_snapshot_serial": ordinal + 1, "render_tick_index": max(0, ordinal - 1),
                    "backend_name": "native-phased", "simulation_failed": False, "failed_tick_index": 0,
                    "tick_failure_count": 0, "last_tick_error": "", "paused": True, "workbench_refusal": ""}
        return {"stage": stage, "frame": frame, "observed_usec": ordinal + 1,
                "expect_running": play, "worker_has_failed": False,
                "worker_owner_state": {"thread_running": stage != "final_after_worker_join",
                                       "requested_paused": requested_paused},
                "worker_running_observed_before": previous, "worker_running_observed": running,
                "main_paused": not play, "main_error": "", "workbench_refusal": "", "workbench_message": "",
                "worker_snapshot": copy.deepcopy(snapshot), "main_snapshot": copy.deepcopy(snapshot),
                "healthy": True, "reasons": []}

    before = observation("before", -1, 0, active, True)
    frames = []
    for i in range(3):
        play = active or (workload == "burst" and i >= 1)
        frames.append({"frame": i, "frame_ms": 16.0, "tick": i + 1 if play else 0,
                       "rapier_step": 3 + i if workload == "actor" else 0,
                       "native_health": observation("frame", i, i + 1, play, not play)})
    final_play = active or workload == "burst"
    after = observation("after_timing", -1, 4, final_play, not final_play)
    final = observation("final_after_worker_join", -1, 5, final_play, not final_play)
    return {"ok": True, "failures": [], "workload": workload, "cohort": "mounted_native_workbench",
            "initial_native_tick": 0, "initial_rapier_step": 3 if workload == "actor" else 0, "frames": frames,
            "native_health": {"schema": "render-upload-577-native-health-v1", "applicable": True,
                              "before": before, "after_timing": after, "final": final,
                              "first_failure": {}, "failure_observations": 0}}


def validation_cases() -> list[dict]:
    cases = [{"name": "healthy-" + workload, "accepted": True, "receipt": healthy_receipt(workload)}
             for workload in ("active", "manual", "dormant", "burst", "actor")]
    synthetic = healthy_receipt()
    synthetic.update(cohort="deterministic_renderer_seam", workload="sparse")
    synthetic["native_health"].update(applicable=False, before={}, after_timing={}, final={})
    for frame in synthetic["frames"]:
        frame["native_health"] = {}
    cases.append({"name": "synthetic-explicitly-inapplicable", "accepted": True, "receipt": synthetic})

    def bad(name: str, mutate, workload: str = "active") -> None:
        receipt = healthy_receipt(workload)
        mutate(receipt)
        # All malformed controls deliberately retain ok:true and empty failures.
        cases.append({"name": name, "accepted": False, "receipt": receipt})

    bad("missing-health", lambda d: d.pop("native_health"))
    bad("missing-workload", lambda d: d.pop("workload"))
    bad("unknown-workload", lambda d: d.update(workload="undeclared"))
    bad("wrong-native-cohort", lambda d: d.update(cohort="deterministic_renderer_seam"))
    bad("boolean-cohort-is-not-a-string-identity", lambda d: d.update(cohort=True))
    def relabel_synthetic(d):
        d["cohort"] = "deterministic_renderer_seam"
        d["native_health"].update(applicable=False, before={}, after_timing={}, final={})
        for frame in d["frames"]:
            frame["native_health"] = {}
    bad("native-relabelled-as-inapplicable-synthetic", relabel_synthetic)
    bad("missing-frame-health", lambda d: d["frames"][1].pop("native_health"))
    bad("missing-final-health", lambda d: d["native_health"].pop("final"))
    bad("worker-before-main-failure", lambda d: d["frames"][1]["native_health"].update(worker_has_failed=True))
    bad("failed-earlier-worker-snapshot-healthy-final", lambda d:
        d["frames"][1]["native_health"]["worker_snapshot"].update(simulation_failed=True, failed_tick_index=24,
            tick_failure_count=1, last_tick_error="pressure gas compartment capacity exhausted"))
    bad("failed-main-snapshot", lambda d: d["frames"][1]["native_health"]["main_snapshot"].update(simulation_failed=True))
    bad("failure-count-without-flag", lambda d: d["frames"][1]["native_health"]["worker_snapshot"].update(tick_failure_count=1))
    bad("original-error-without-flag", lambda d: d["frames"][1]["native_health"]["worker_snapshot"].update(last_tick_error="native failure"))
    bad("attempted-failed-tick-without-flag", lambda d: d["frames"][1]["native_health"]["worker_snapshot"].update(failed_tick_index=24))
    bad("worker-finite-body-refusal", lambda d: d["frames"][1]["native_health"]["worker_snapshot"].update(workbench_refusal="finite canvas edge"))
    bad("main-workbench-refusal", lambda d: d["frames"][1]["native_health"].update(workbench_refusal="body sample refused"))
    bad("main-collider-refusal", lambda d: d["frames"][1]["native_health"].update(main_error="Terrain collider snapshot was refused"))
    bad("automatic-main-pause", lambda d: d["frames"][1]["native_health"].update(main_paused=True))
    bad("confirmed-worker-requested-pause", lambda d: d["frames"][1]["native_health"]["worker_owner_state"].update(requested_paused=True))
    bad("worker-thread-stopped", lambda d: d["frames"][1]["native_health"]["worker_owner_state"].update(thread_running=False))
    bad("retained-first-failure", lambda d: d["native_health"].update(first_failure={"worker_has_failed": True}))
    bad("retained-failure-count", lambda d: d["native_health"].update(failure_observations=1))
    bad("string-false-is-not-false", lambda d: d["frames"][1]["native_health"].update(worker_has_failed="false"))
    bad("missing-original-native-identity", lambda d: d["frames"][1]["native_health"]["worker_snapshot"].pop("failed_tick_index"))
    bad("reassociated-frame", lambda d: d["frames"][1]["native_health"].update(frame=0))
    bad("zero-actor-step-progress", lambda d: [f.update(rapier_step=3) for f in d["frames"]], "actor")
    bad("regressing-actor-step", lambda d: d["frames"][1].update(rapier_step=2), "actor")
    expected = {"size": 2048, "workload": "active", "workers": 4, "family": "pressure_flow_v1",
                "channels": 2, "ack": "normal", "fixture": "pressure_dam_v1"}
    requested = healthy_receipt()
    requested.update(strategy="full", config=dict(expected, strategy="full"))
    cases.append({"name": "requested-case-bound", "accepted": True, "receipt": copy.deepcopy(requested),
                  "expected_case": expected, "expected_strategy": "full"})
    def wrong_request(name, mutate):
        receipt = copy.deepcopy(requested)
        mutate(receipt)
        cases.append({"name": name, "accepted": False, "receipt": receipt,
                      "expected_case": expected, "expected_strategy": "full"})
    def relabel_all(d):
        relabel_synthetic(d)
        d["workload"] = "sparse"
        d["config"]["workload"] = "sparse"
    wrong_request("mutually-consistent-relabelling-cannot-change-request", relabel_all)
    wrong_request("top-level-workload-differs-from-request", lambda d: d.update(workload="dormant"))
    wrong_request("top-level-strategy-differs-from-request", lambda d: d.update(strategy="hybrid"))
    wrong_request("reported-strategy-differs-from-request", lambda d: d["config"].update(strategy="hybrid"))
    wrong_request("fixture-differs-from-request", lambda d: d["config"].update(fixture="legacy_scatter_v1"))
    wrong_request("workers-differ-from-request", lambda d: d["config"].update(workers=1))
    wrong_request("coercible-workers-are-not-original-identity", lambda d: d["config"].update(workers="4"))
    wrong_request("missing-requested-config", lambda d: d.pop("config"))
    return cases
