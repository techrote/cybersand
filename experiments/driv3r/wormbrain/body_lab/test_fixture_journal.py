"""BODY-V5 four-lease interleaving and partial native-inert receipt tests."""
from dataclasses import replace
import unittest

from experiments.driv3r.wormbrain.body_lab.body_v2 import BodyOptions
from experiments.driv3r.wormbrain.body_lab.commander_bridge import FourWormWrangler
from experiments.driv3r.wormbrain.body_lab.fixture_journal import InertReceiptJournal
from experiments.driv3r.wormbrain.body_lab.preflight import Refusal
from experiments.driv3r.wormbrain.body_lab.test_commander_bridge import (
    fixture, RUNNERS, NATIVE_SOURCE, attach_all, make_wrangler,
)
from experiments.driv3r.wormbrain.body_lab.test_native_inert_adapter import (
    transcript,
)


def pending(w, lease, action="INK_E_2"):
    menu = w.offer(lease, options=BodyOptions(4, True, False))
    plan = w.submit(lease, action, menu["offer_token"],
                    ("fixture-original-output:" + lease).encode(),
                    options=BodyOptions(4, True, False))
    return plan, transcript(w.sessions[lease]["snapshot"], plan)


class FixtureJournalTests(unittest.TestCase):
    def test_four_streams_interleave_without_cross_contamination(self):
        w = make_wrangler()
        attach_all(w)
        leases = list(w.identities)
        rows = {}
        for lease in leases:
            _, rows[lease] = pending(w, lease)
            report = w.begin_fixture_stream(lease)
            self.assertEqual(report["accepted_fixture_operations"], 0)
        for index in range(4):
            for lease in reversed(leases):
                result = w.accept_fixture_step(lease, rows[lease][index])
                self.assertFalse(result["native_authenticated"])
        self.assertEqual(w.report()["mock_fixture_decisions"], 4)
        self.assertEqual(w.report()["fixture_quarantines"], 0)
        self.assertEqual(w.report()["authenticated_native_receipts"], 0)
        self.assertEqual(w.report()["verified_active_model_processes"], 0)
        for lease in leases:
            s = w.sessions[lease]
            self.assertEqual(s["decisions"], 1)
            self.assertEqual(len(s["original_output_bytes"]), 1)
            self.assertEqual(len(s["fixture_receipts"]), 1)
            self.assertEqual(s["snapshot"].cursor, (14, 24))
            self.assertFalse(s["stopped"])
        self.assertEqual(len({
            w.sessions[x]["fixture_receipts"][0] for x in leases
        }), 4)

    def test_incomplete_stroke_cannot_be_accepted_wholesale_or_retried(self):
        w = make_wrangler()
        attach_all(w)
        lease = next(iter(w.identities))
        plan, rows = pending(w, lease, "INK_E_4")
        w.begin_fixture_stream(lease)
        w.accept_fixture_step(lease, rows[0])
        with self.assertRaises(Refusal):
            w.accept_fixture(lease, rows)
        with self.assertRaises(Refusal):
            w.offer(lease)
        with self.assertRaises(Refusal):
            w.submit(lease, "STOP", plan["offer_token"], b"retry")
        self.assertEqual(w.sessions[lease]["decisions"], 0)
        self.assertIsNotNone(w.sessions[lease]["pending"])
        self.assertEqual(w.sessions[lease]["fixture_journal"].report()[
            "accepted_fixture_operations"], 1)

    def test_wrong_world_receipt_quarantines_only_one_worm(self):
        w = make_wrangler()
        attach_all(w)
        a, b = list(w.identities)[:2]
        _, rows_a = pending(w, a)
        _, rows_b = pending(w, b)
        w.begin_fixture_stream(a)
        w.begin_fixture_stream(b)
        with self.assertRaises(Refusal):
            w.accept_fixture_step(a, rows_b[0])
        self.assertTrue(w.sessions[a]["quarantined"])
        self.assertEqual(w.report()["fixture_quarantines"], 1)
        with self.assertRaises(Refusal):
            w.accept_fixture_step(a, rows_a[0])
        for row in rows_b:
            w.accept_fixture_step(b, row)
        self.assertEqual(w.sessions[b]["decisions"], 1)
        self.assertEqual(w.sessions[a]["decisions"], 0)

    def test_halt_marks_partial_uncertain_and_does_not_claim_cleanup(self):
        w = make_wrangler()
        attach_all(w)
        a, b = list(w.identities)[:2]
        _, rows_a = pending(w, a)
        w.begin_fixture_stream(a)
        w.accept_fixture_step(a, rows_a[0])
        state = w.quarantine_fixture(a, "transport_loss")
        self.assertEqual(state["accepted_fixture_operations"], 1)
        self.assertEqual(state["state"], "quarantined")
        self.assertFalse(state["host_cleanup_authenticated"])
        self.assertFalse(state["safe_to_auto_retry"])
        self.assertEqual(w.sessions[a]["decisions"], 0)
        self.assertEqual(w.sessions[a]["pending_raw_output"],
                         ("fixture-original-output:" + a).encode())
        self.assertIn("INK_E_1", w.offer(b)["legal_ids"])

    def test_same_epoch_is_not_accepted_as_a_fresh_operation(self):
        w = make_wrangler()
        attach_all(w)
        lease = next(iter(w.identities))
        _, rows = pending(w, lease)
        w.begin_fixture_stream(lease)
        row = rows[0]
        prior = w.sessions[lease]["snapshot"]
        stale = (row[0], row[1], replace(row[2], epoch=prior.epoch))
        with self.assertRaises(Refusal):
            w.accept_fixture_step(lease, stale)
        self.assertEqual(w.sessions[lease]["fixture_journal"].state,
                         "quarantined")

    def test_stop_receipt_is_mock_only_and_terminal(self):
        w = make_wrangler()
        attach_all(w)
        lease = next(iter(w.identities))
        _, rows = pending(w, lease, "STOP")
        w.begin_fixture_stream(lease)
        status = w.accept_fixture_step(lease, rows[0])
        self.assertTrue(status["fixture_complete"])
        self.assertFalse(status["native_authenticated"])
        self.assertTrue(w.sessions[lease]["stopped"])
        with self.assertRaises(Refusal):
            w.offer(lease)
        self.assertEqual(w.report()["authenticated_native_receipts"], 0)

    def test_bad_source_plan_cannot_make_a_journal(self):
        w = make_wrangler()
        attach_all(w)
        lease = next(iter(w.identities))
        p, _ = pending(w, lease)
        s = w.sessions[lease]["snapshot"]
        with self.assertRaises(Refusal):
            InertReceiptJournal({**p, "native_execution": True}, s)
        with self.assertRaises(Refusal):
            InertReceiptJournal({**p, "source_sha": "a" * 40}, s)

    def test_unstarted_stream_cannot_accept_and_bad_quarantine_rejected(self):
        w = make_wrangler()
        attach_all(w)
        lease = next(iter(w.identities))
        _, rows = pending(w, lease)
        with self.assertRaises(Refusal):
            w.accept_fixture_step(lease, rows[0])
        with self.assertRaises(Refusal):
            w.quarantine_fixture(lease, "successful-native-stop")
        self.assertEqual(w.sessions[lease]["decisions"], 0)


if __name__ == "__main__":
    unittest.main()
