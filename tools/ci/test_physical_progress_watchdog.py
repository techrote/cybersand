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


if __name__ == "__main__":
    unittest.main()
