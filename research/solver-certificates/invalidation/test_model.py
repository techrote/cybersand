"""Deterministic model/oracle and independently falsified shortcut tests."""
import unittest

from model import (Cached, State, SAND, WATER, ROCK, EMPTY, STEAM,
                   apply_events, full_step, make_state, run)


class CertificateTests(unittest.TestCase):
    def test_quiet_profile(self):
        for workers in (1, 4):
            r = run("quiet", workers=workers)
            self.assertGreater(r["skip_ratio"], 0.70)
            self.assertEqual(r["incremental_calls"] + r["skipped_calls"], r["full_calls"])

    def test_mixed_pressure_actor_reaction_seam_explosion_aba_rollback(self):
        self.assertEqual(run("mixed", workers=1)["end_hash"],
                         run("mixed", workers=4)["end_hash"])

    def test_dense_cost_includes_tracking(self):
        a = run("dense", workers=4)
        self.assertLessEqual(a["incremental_calls"], a["full_calls"])
        # The accounting deliberately includes proof work and invalidation.
        self.assertGreaterEqual(a["abstract_work_units"], a["incremental_calls"])

    def test_unmodelled_effect_enforces_costly_full_recompute(self):
        a = run("churn", workers=1)
        self.assertEqual(a["skipped_calls"], 0)
        self.assertGreater(a["abstract_work_units"], a["oracle_work_units"])
        self.assertEqual(a["end_hash"], run("churn", workers=4)["end_hash"])

    def test_false_positive_tracking_is_offline(self):
        a = run("mixed", workers=1)
        self.assertGreater(a["statistics"]["false_positive_invalidations"], 0)
        self.assertGreater(a["statistics"]["diagnostic_probe_calls"], 0)
        self.assertEqual(a["abstract_work_units"],
                         a["incremental_calls"] + a["probe_calls"] + a["halo_sites"])

    def test_invalidate_halo_over_tile_boundary(self):
        s = State(8, 8, [EMPTY] * 64, frozenset({4 * 8 + 3}))
        s.cells[s.index(3,3)] = SAND  # top tile ends y=3; actor is at y=4
        o = s.copy(); c = Cached(s.copy())
        self.assertIn(c.tile(3,3), c.certified)
        self.assertIn(c.tile(3,4), c.certified)
        # Phase tick1 activates pair (3,4), so advance through tick0 first.
        full_step(o, [])
        c.step([])
        self.assertEqual(o.digest(), c.state.digest())
        event = [("actor", ())]
        full_step(o, event)
        c.step(event)
        self.assertEqual(o.digest(), c.state.digest())
        self.assertEqual(c.state.at(3,3), EMPTY)
        self.assertEqual(c.state.at(3,4), SAND)

    def test_under_invalidation_is_detected(self):
        s = State(8, 8, [EMPTY] * 64, frozenset({4 * 8 + 3}))
        s.cells[s.index(3,3)] = SAND
        o = s.copy(); c = Cached(s.copy())
        full_step(o, [])
        c.step([])
        full_step(o, [("actor", ())])
        c.step([("actor", ())], faulty_no_halo=True)
        self.assertNotEqual(o.digest(), c.state.digest(), "negative-control halo omission escaped")

    def test_pressure_requires_nonlocal_invalidation(self):
        s = State(16, 8, [ROCK] * 128)
        s.cells[s.index(14, 1)] = WATER
        o = s.copy(); c = Cached(s.copy())
        self.assertEqual(len(c.certified), c.cols * c.rows)
        event = [("pressure", 1)]
        full_step(o, event)
        c.step(event)
        self.assertEqual(o.digest(), c.state.digest())
        self.assertEqual(c.state.at(14,1), STEAM)
        self.assertGreater(c.stats.pressure_fallbacks, 0)

    def test_suppress_pressure_wake_is_unsound(self):
        s = State(16, 8, [ROCK] * 128)
        s.cells[s.index(14,1)] = WATER
        o = s.copy(); c = Cached(s.copy())
        event = [("pressure", 1)]
        full_step(o, event)
        c.step(event, faulty_ignore_pressure=True)
        self.assertNotEqual(o.digest(), c.state.digest(), "negative-control pressure omission escaped")
        self.assertEqual(c.state.at(14,1), WATER)

    def test_aba_wakes_even_when_value_restored(self):
        s = State(8, 8, [ROCK] * 64)
        c = Cached(s.copy())
        assert len(c.certified) == 4
        c.step([("set", 3, 3, EMPTY), ("set", 3, 3, ROCK)])
        self.assertGreater(c.stats.invalidated, 0)
        self.assertEqual(c.state.at(3,3), ROCK)

    def test_unknown_revokes_all(self):
        s = State(8, 8, [ROCK] * 64)
        c = Cached(s)
        c.step([("unknown",)])
        self.assertEqual(c.stats.unknown_fallbacks, 1)
        self.assertEqual(c.stats.executed, 64)

    def test_rollback_discards_derived_certificates(self):
        s = State(8, 8, [ROCK] * 64)
        c = Cached(s.copy())
        frozen = c.state.copy()
        c.step([("set", 2, 2, WATER)])
        c.restore(frozen)
        self.assertEqual(c.state.digest(), frozen.digest())
        self.assertEqual(len(c.certified), 4)


if __name__ == "__main__":
    unittest.main()
