"""Check liveness boundaries without waiting for wall-clock deadlines."""

import unittest

from physical_progress_watchdog import ProgressWatchdog


class WatchdogTests(unittest.TestCase):
    def test_stalled_step_requests_live_capture_then_failure(self):
        watchdog = ProgressWatchdog("test_physical_actor_rigs", 0)
        watchdog.observe('CYBERSAND_PROGRESS {"phase":"step","steps":120}', 1)
        self.assertFalse(watchdog.capture_due(30))
        self.assertTrue(watchdog.capture_due(31))
        self.assertFalse(watchdog.expired(45))
        self.assertTrue(watchdog.expired(46))

    def test_actual_progress_renews_liveness_and_unrelated_output_does_not(self):
        watchdog = ProgressWatchdog("test_physical_actor_arena", 0)
        watchdog.observe('CYBERSAND_PROGRESS {"phase":"step","steps":120}', 1)
        watchdog.observe('CYBERSAND_PROGRESS {"phase":"step","steps":240}', 40)
        watchdog.observe('CYBERSAND_PROGRESS {"phase":"step","steps":240}\nnoise', 80)
        self.assertFalse(watchdog.expired(84))
        self.assertTrue(watchdog.expired(85))

    def test_missing_startup_marker_and_stuck_quit_are_bounded(self):
        for output in ("banner", 'CYBERSAND_PROGRESS {"phase":"quit","steps":900}'):
            watchdog = ProgressWatchdog("test_physical_usable_course", 0)
            watchdog.observe(output, 0)
            self.assertTrue(watchdog.expired(45))

    def test_other_tests_keep_their_original_deadline(self):
        watchdog = ProgressWatchdog("profile_scheduler", 0)
        self.assertFalse(watchdog.capture_due(1000))
        self.assertFalse(watchdog.expired(1000))

    def test_issue233_marker_preserves_actual_case_rig_and_tick(self):
        watchdog = ProgressWatchdog("test_physical_actor_rigs", 0)
        marker = "REGRESSION_PROGRESS case=test_physical_actor_rigs phase=roster_step rig=runner tick=300"
        watchdog.observe(marker, 10)
        self.assertEqual(watchdog.marker["rig"], "runner")
        self.assertEqual(watchdog.marker["tick"], "300")
        watchdog.observe(marker + "\nERROR: REGRESSION_WATCHDOG expired", 40)
        self.assertTrue(watchdog.expired(55))

    def test_wrong_case_malformed_marker_and_changed_clock_cannot_renew(self):
        watchdog = ProgressWatchdog("test_physical_actor_arena", 0)
        watchdog.observe('CYBERSAND_PROGRESS {"phase":"step","steps":120,"elapsed_ms":1}', 1)
        watchdog.observe('CYBERSAND_PROGRESS {"phase":"step","steps":120,"elapsed_ms":90000}', 40)
        watchdog.observe('REGRESSION_PROGRESS case=another_case phase=step tick=20', 42)
        watchdog.observe('CYBERSAND_PROGRESS {malformed', 44)
        self.assertTrue(watchdog.expired(46))

    def test_helper_sequence_renews_repeated_setup_phase(self):
        watchdog = ProgressWatchdog("test_physical_actor_arena", 0)
        watchdog.observe('CYBERSAND_PROGRESS {"phase":"configure","steps":0,"sequence":1}', 1)
        watchdog.observe('CYBERSAND_PROGRESS {"phase":"configure","steps":0,"sequence":2}', 40)
        self.assertFalse(watchdog.expired(46))

    def test_nonfinite_clock_is_rejected(self):
        with self.assertRaises(ValueError):
            ProgressWatchdog("test_physical_actor_arena", float("nan"))
        watchdog = ProgressWatchdog("test_physical_actor_arena", 0)
        with self.assertRaises(ValueError):
            watchdog.observe("", float("inf"))


if __name__ == "__main__":
    unittest.main()
