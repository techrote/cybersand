import unittest
from fleet_receipt_v1 import (CONTRACT, is_live_model, original_w0_envelope,
                              summarise_fleet)

NOW = 1_800_000_000_000_000_000
SHA = 'a' * 64


def mock_model(i, *, wrangler='test-model-wrangler'):
    # Artificial unit-test input only; NOT live inference evidence.
    return dict(contract=CONTRACT, wrangler_id=wrangler, lease_id=f'lease{i}',
                runner_id='runnerA', run_id='unit-test', job_id='mock',
                pid=1000+i, pid_alive=True, forward_in_flight=True,
                model_name='test-model', model_revision='test-pin',
                model_sha256=SHA, checkpoint_sha256=SHA, source_sha256=SHA,
                world_sha256=SHA, world_seed=i, decision_budget=12,
                model_forward_count=2, status='actively_deciding',
                evidence_class='model_scored_w0',
                pid_sampled_utc_ns=NOW-1_000_000,
                forward_sampled_utc_ns=NOW-1_000_000,
                native_execution=False)


class FleetTests(unittest.TestCase):
    def test_two_genuine_model_process_slots_not_four(self):
        s = summarise_fleet([mock_model(1), mock_model(2)], sampled_utc_ns=NOW)
        self.assertEqual(s['active_resident_models'], 2)
        self.assertFalse(s['four_active_per_wrangler_proven'])

    def test_four_distinct_model_process_slots(self):
        a = [mock_model(i) for i in range(4)]
        s = summarise_fleet(a, sampled_utc_ns=NOW)
        self.assertTrue(s['four_active_per_wrangler_proven'])

    def test_synthetic_fake_model_cannot_count(self):
        x = mock_model(1)
        x['evidence_class'] = 'synthetic_w0'
        x['model_forward_count'] = 0
        self.assertFalse(is_live_model(x, sampled_utc_ns=NOW))

    def test_queued_or_loaded_not_active(self):
        for status in ('queued', 'loaded', 'completed', 'failed'):
            x = mock_model(1)
            x['status'] = status
            if status == 'completed':
                x.update(original_png_sha256=SHA, original_receipt_sha256=SHA,
                         decisions_applied=3)
            self.assertFalse(is_live_model(x, sampled_utc_ns=NOW))

    def test_stale_liveness_not_counted(self):
        x = mock_model(1)
        x['pid_sampled_utc_ns'] = NOW - 20_000_000_000
        self.assertFalse(is_live_model(x, sampled_utc_ns=NOW))

    def test_duplicate_pid_rejected(self):
        a, b = mock_model(1), mock_model(2)
        b['pid'] = a['pid']
        with self.assertRaisesRegex(ValueError, 'one resident PID'):
            summarise_fleet([a, b], sampled_utc_ns=NOW)

    def test_native_requires_host_receipts(self):
        x = mock_model(1)
        x.update(evidence_class='native_model', native_execution=True)
        self.assertFalse(is_live_model(x, sampled_utc_ns=NOW))
        x['native_host_receipts_verified'] = True
        self.assertTrue(is_live_model(x, sampled_utc_ns=NOW))

    def test_actual_synthetic_envelope_not_a_model(self):
        record = dict(contract='cybersand.worm.observation-action/0-experimental',
                      engine='python-stdlib-baseline-not-native', seed=42,
                      step_budget=3, steps_executed=1,
                      events=[dict(raw_choice='STOP', applied='STOP')])
        original = original_w0_envelope(record, b'\x89PNG\r\n\x1a\nabcdef',
                    wrangler_id='test', lease_id='w0', runner_id='runner',
                    run_id='unit-test', job_id='test')
        s = summarise_fleet([original], sampled_utc_ns=NOW)
        self.assertEqual(s['active_resident_models'], 0)
        self.assertEqual(s['status_counts']['completed'], 1)


if __name__ == '__main__':
    unittest.main()
