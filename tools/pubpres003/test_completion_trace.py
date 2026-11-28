"""Adversarial checks for the additive Completion trace, not performance tests."""
import copy
import unittest

from causal_trace import analyze
from test_causal_trace import fixture


def completion_fixture():
    identity, rows, receipt, steps = fixture()
    steps[0]["native_snapshot_serial"] = 14
    steps[0].update(response_accepted=True, response_refusal="")
    for row in rows:
        if row["observer_owner"] == "main":
            row.update(trace_version=2, snapshot_serial=14)
    packet = rows[-1]
    rows.extend([
        {**packet, "event": "native_response_application", "start_usec": 2420,
         "time_usec": 2421, "accepted": True, "refusal": "", "application_snapshot": 14},
        {**packet, "event": "transaction_exit", "start_usec": 3350, "time_usec": 3351,
         "physical_tick": 1, "manual_steps_after": 1, "next_requested_sample": 3},
        {**packet, "event": "material_consumption", "start_usec": 3500, "time_usec": 4500,
         "uploaded_serial": 12, "ack_serial": 12},
        {**packet, "event": "main_process_exit", "start_usec": 3450, "time_usec": 4600,
         "packet_present": False},
    ])
    return identity, rows, receipt, steps


class CompletionTraceTests(unittest.TestCase):
    def test_real_step_remains_the_only_completion_authority(self):
        result = analyze(*completion_fixture())
        self.assertEqual(result["actual_completed_rapier_steps"], 1)
        self.assertEqual(result["exact_application_and_exit_joins"], 1)
        self.assertEqual(result["native_response_application_outcomes"], {"accepted": 1})
        self.assertEqual(result["transactions"][0]["native_response_application"]["application_usec"], 2421)

    def test_historical_missing_observations_stay_unknown(self):
        result = analyze(*fixture())
        self.assertEqual(result["exact_application_and_exit_joins"], 0)
        self.assertIsNone(result["transactions"][0]["native_response_application"])

    def test_downgraded_entry_cannot_silently_omit_completion_evidence(self):
        identity, rows, receipt, steps = completion_fixture()
        del rows[4]["trace_version"]
        with self.assertRaisesRegex(ValueError, "Mixed Main causal versions"):
            analyze(identity, rows, receipt, steps)

    def test_retained_status_packet_cannot_replace_exact_step_snapshot(self):
        for index in (4, 5, 6):
            identity, rows, receipt, steps = completion_fixture()
            rows[index]["snapshot_serial"] = 15
            if index == 5:
                rows[index]["application_snapshot"] = 15
            with self.subTest(index=index), self.assertRaises(ValueError):
                analyze(identity, rows, receipt, steps)

    def test_snapshot_and_version_fields_have_strict_json_types(self):
        for field, value in (("snapshot_serial", 14.0), ("trace_version", []), ("trace_version", {})):
            identity, rows, receipt, steps = completion_fixture()
            rows[6][field] = value
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                analyze(identity, rows, receipt, steps)

    def test_retained_accepted_flag_cannot_authorize_another_snapshot(self):
        identity, rows, receipt, steps = completion_fixture()
        rows[5]["application_snapshot"] = 13
        with self.assertRaisesRegex(ValueError, "another snapshot"):
            analyze(identity, rows, receipt, steps)

    def test_missing_duplicate_or_wrong_callback_application_fails(self):
        for mutation in ("missing", "duplicate", "callback"):
            identity, rows, receipt, steps = completion_fixture()
            if mutation == "missing":
                rows.pop(5)
            elif mutation == "duplicate":
                rows.append(copy.deepcopy(rows[5]))
            else:
                rows[5]["origin_callback_id"] += 1
            with self.subTest(mutation=mutation), self.assertRaisesRegex(ValueError, "exact native application"):
                analyze(identity, rows, receipt, steps)

    def test_exit_cannot_claim_an_extra_step_or_precede_completion(self):
        for field, value in (("manual_steps_after", 2), ("time_usec", 3299), ("origin_callback_id", 99)):
            identity, rows, receipt, steps = completion_fixture()
            rows[6][field] = value
            rows[6]["start_usec"] = min(rows[6]["start_usec"], rows[6]["time_usec"])
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, "exact transaction exit"):
                analyze(identity, rows, receipt, steps)

    def test_refusal_is_explicit_and_not_counted_as_acceptance(self):
        identity, rows, receipt, steps = completion_fixture()
        rows[5].update(accepted=False, refusal="sample_properties")
        steps[0].update(response_accepted=False, response_refusal="sample_properties")
        self.assertEqual(analyze(identity, rows, receipt, steps)["native_response_application_outcomes"],
                         {"refused:sample_properties": 1})

    def test_application_cannot_reclassify_the_independent_step_witness(self):
        for field, value in (("accepted", False), ("refusal", "sample_properties")):
            identity, rows, receipt, steps = completion_fixture()
            rows[5][field] = value
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, "result differs"):
                analyze(identity, rows, receipt, steps)

    def test_advanced_ack_is_not_material_consumption(self):
        identity, rows, receipt, steps = completion_fixture()
        rows[7]["ack_serial"] = 13
        with self.assertRaisesRegex(ValueError, "ACK exceeds"):
            analyze(identity, rows, receipt, steps)

    def test_unknown_version_or_event_is_refused(self):
        for field, value in (("trace_version", 1), ("trace_version", 3), ("event", "fabricated_step")):
            identity, rows, receipt, steps = completion_fixture()
            rows[5][field] = value
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                analyze(identity, rows, receipt, steps)


if __name__ == "__main__":
    unittest.main()
