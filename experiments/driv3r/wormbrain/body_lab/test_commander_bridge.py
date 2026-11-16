"""BODY-V4: contract/adversarial fixtures only, never actual resident models or Godot."""
from dataclasses import replace
import json
import time
import unittest

from experiments.driv3r.wormbrain.body_lab.body_v2 import BodyOptions
from experiments.driv3r.wormbrain.body_lab.commander_bridge import (
    FourWormWrangler, _digest, import_commander_plan,
)
from experiments.driv3r.wormbrain.body_lab.native_inert_adapter import ExternalSnapshot
from experiments.driv3r.wormbrain.body_lab.preflight import HostView, Refusal, INK
from experiments.driv3r.wormbrain.body_lab.test_native_inert_adapter import transcript

NATIVE_SOURCE = "b4079e74207d7a70992c48ebd70e9c7b2016f463"
RUNNERS = {0: "external-runner-A", 1: "external-runner-B"}


def fixture():
    """Independent miniature Commander /1 request+plan, NO actual model execution."""
    episodes = []
    for i in range(4):
        episodes.append({
            "id": f"worm-{i}", "seed": 570 + i * 71,
            "runner_slot": i // 2, "evidence_class": "native_model",
            "model_id": f"fictional-model-{i}", "model_revision": f"revision-{i}",
            "model_sha256": format(10 + i, "064x"),
            "checkpoint_sha256": format(20 + i, "064x"),
            "decision_budget": 36, "material_budget": 36,
            "allow_model_training": False,
        })
    req = {
        "schema": "driv3r.wormfleet.request/1", "campaign": "body-v4-fixture",
        "wrangler": "body-wrangler", "source_sha256": "a" * 64,
        "host_source_sha256": "b" * 64, "max_runners": 2,
        "models_per_runner": 2, "training": False, "paid_api": False,
        "native_permissions_remain_host_owned": True,
        "automatically_expand": False, "episodes": episodes,
    }
    request_sha = _digest(req)
    jobs = []
    for slot in (0, 1):
        leases = []
        for e in episodes:
            if e["runner_slot"] == slot:
                leases.append({"lease_id": "wf-" + _digest(
                    {"request": request_sha, "id": e["id"]})[:28], **e})
        jobs.append({"runner_slot": slot, "leases": leases,
                     "source_sha256": req["source_sha256"]})
    plan = {"schema": "driv3r.wormfleet.plan/1",
            "campaign": req["campaign"], "wrangler": req["wrangler"],
            "request_sha256": request_sha, "runner_jobs": jobs,
            "total_leases": 4, "dispatch_permitted": False}
    return req, plan


def empty():
    return HostView((0,) * (96 * 96))


def make_snapshot(identity, *, epoch=(1, 2, 3), source=NATIVE_SOURCE):
    l = identity.lease
    return ExternalSnapshot(l.id, l.runner, l.world, source, epoch,
                            (12, 24), 0, empty())


def attach_all(w):
    for identity in w.identities.values():
        w.attach(identity.lease.id, empty(), make_snapshot(identity))


def make_wrangler():
    req, plan = fixture()
    return FourWormWrangler(req, plan, RUNNERS, native_source_sha=NATIVE_SOURCE)


class CommanderFourSlotBridge(unittest.TestCase):
    def test_exact_four_distinct_leases_runner_world_seed_and_pins(self):
        req, plan = fixture()
        identities = import_commander_plan(req, plan, RUNNERS)
        self.assertEqual(len(identities), 4)
        self.assertEqual(len({x.lease.id for x in identities.values()}), 4)
        self.assertEqual(len({x.lease.world for x in identities.values()}), 4)
        self.assertEqual(len({x.lease.seed for x in identities.values()}), 4)
        self.assertEqual({x.runner_slot for x in identities.values()}, {0, 1})
        self.assertEqual(len({x.model_sha256 for x in identities.values()}), 4)
        self.assertEqual(len({x.lease.runner for x in identities.values()}), 2)

    def test_four_interleaved_mock_episodes_stay_isolated(self):
        w = make_wrangler()
        attach_all(w)
        names = list(w.identities)
        before = [w.sessions[n]["snapshot"].fingerprint() for n in names]
        # Interleave four independently sourced claimed model responses;
        # none is a loaded process or native transaction.
        for i in (2, 0, 3, 1):
            ident = names[i]
            menu = w.offer(ident, options=BodyOptions(4, True, False))
            plan = w.submit(ident, "INK_E_2", menu["offer_token"],
                            f"MOCK outside model output {i}".encode(),
                            options=BodyOptions(4, True, False))
            self.assertEqual(plan["commander_request_sha256"], w.request_sha256)
            self.assertEqual(plan["model_sha256"], w.identities[ident].model_sha256)
            result = w.accept_fixture(ident, transcript(w.sessions[ident]["snapshot"], plan))
            self.assertFalse(result["model_execution_verified"])
            self.assertFalse(result["native_authenticated"])
            for j in (set(range(4)) - {i}):
                if w.sessions[names[j]]["decisions"] == 0:
                    self.assertEqual(w.sessions[names[j]]["snapshot"].fingerprint(),
                                     before[j])
        self.assertEqual([w.sessions[n]["decisions"] for n in names], [1, 1, 1, 1])
        self.assertEqual([w.sessions[n]["snapshot"].cursor for n in names],
                         [(14, 24)] * 4)
        self.assertEqual([sum(v == INK for v in w.sessions[n]["snapshot"].material.material)
                          for n in names], [2] * 4)
        self.assertEqual(w.report()["mock_fixture_decisions"], 4)
        self.assertEqual(w.report()["verified_active_model_processes"], 0)
        self.assertEqual(w.report()["authenticated_native_receipts"], 0)

    def test_stop_is_per_worm_and_cannot_be_reopened(self):
        w = make_wrangler()
        attach_all(w)
        a, b = list(w.identities)[:2]
        menu = w.offer(a)
        plan = w.submit(a, "STOP", menu["offer_token"], b"unverified STOP")
        w.accept_fixture(a, transcript(w.sessions[a]["snapshot"], plan))
        with self.assertRaises(Refusal):
            w.offer(a)
        self.assertIn("INK_E_1", w.offer(b)["legal_ids"])
        self.assertEqual(w.report()["stopped"], 1)

    def test_cross_world_and_double_attach_refused(self):
        w = make_wrangler()
        ids = list(w.identities)
        a, b = w.identities[ids[0]], w.identities[ids[1]]
        with self.assertRaises(Refusal):
            w.attach(a.lease.id, empty(), make_snapshot(b))
        with self.assertRaises(Refusal):
            w.attach(a.lease.id, empty(), replace(make_snapshot(a), source_sha="f" * 40))
        w.attach(a.lease.id, empty(), make_snapshot(a))
        with self.assertRaises(Refusal):
            w.attach(a.lease.id, empty(), make_snapshot(a))

    def test_stale_token_no_raw_output_or_arbitrary_coordinates(self):
        w = make_wrangler()
        attach_all(w)
        a = next(iter(w.identities))
        token = w.offer(a)["offer_token"]
        for action, digest, raw in (
            ("INK_E_1", token, b""), ("INK_E_1", "0" * 64, b"CHOICE"),
            ("INK_E_9", token, b"CHOICE"), ("PAINT_AT(55,55)", token, b"CHOICE"),
        ):
            with self.subTest(action=action), self.assertRaises(Refusal):
                w.submit(a, action, digest, raw)
        p = w.submit(a, "INK_E_1", token, b"original external text")
        with self.assertRaises(Refusal):
            w.submit(a, "STOP", token, b"duplicate")
        with self.assertRaises(Refusal):
            w.offer(a)
        self.assertFalse(p["native_execution"])

    def test_missing_receipt_cannot_advance_or_retry_pending_stroke(self):
        w = make_wrangler()
        attach_all(w)
        a = next(iter(w.identities))
        menu = w.offer(a, options=BodyOptions(4, False, False))
        p = w.submit(a, "INK_E_4", menu["offer_token"], b"MOCK",
                     options=BodyOptions(4, False, False))
        old = w.sessions[a]["snapshot"]
        with self.assertRaises(Refusal):
            w.accept_fixture(a, transcript(old, p)[:-1])
        self.assertEqual(w.sessions[a]["snapshot"], old)
        self.assertEqual(w.sessions[a]["decisions"], 0)
        with self.assertRaises(Refusal):
            w.submit(a, "STOP", menu["offer_token"], b"can't resume")
        self.assertIsNotNone(w.sessions[a]["pending"])

    def test_request_and_plan_must_match_exactly(self):
        req, plan = fixture()
        altered = json.loads(json.dumps(req))
        altered["episodes"][0]["seed"] = 999
        with self.assertRaises(Refusal):
            import_commander_plan(altered, plan, RUNNERS)
        altered = json.loads(json.dumps(plan))
        altered["runner_jobs"][0]["leases"][0]["model_sha256"] = "9" * 64
        with self.assertRaises(Refusal):
            import_commander_plan(req, altered, RUNNERS)
        altered = json.loads(json.dumps(plan))
        altered["dispatch_permitted"] = True
        with self.assertRaises(Refusal):
            import_commander_plan(req, altered, RUNNERS)
        with self.assertRaises(Refusal):
            import_commander_plan(req, plan, {0: "same", 1: "same"})

    def test_cannot_enable_training_or_bypass_native_ceiling(self):
        req, plan = fixture()
        altered = json.loads(json.dumps(req))
        altered["training"] = True
        with self.assertRaises(Refusal):
            import_commander_plan(altered, plan, RUNNERS)
        # Commander may plan 128 model-scored synthetic W0, but this
        # native-inert adapter will NOT allow 128 native action receipts.
        req["episodes"][0]["evidence_class"] = "model_scored_w0"
        req["episodes"][0]["decision_budget"] = 128
        with self.assertRaises(Refusal):
            import_commander_plan(req, plan, RUNNERS)
        w = make_wrangler()
        attach_all(w)
        a = next(iter(w.identities))
        w.sessions[a]["decisions"] = 36
        self.assertEqual(w.offer(a)["legal_ids"], ["STOP"])

    def test_fails_closed_after_deadline(self):
        w = make_wrangler()
        w.deadline_ns = time.monotonic_ns() - 1
        with self.assertRaises(Refusal):
            w.attach(next(iter(w.identities)), empty(),
                     make_snapshot(next(iter(w.identities.values()))))


if __name__ == "__main__":
    unittest.main()
