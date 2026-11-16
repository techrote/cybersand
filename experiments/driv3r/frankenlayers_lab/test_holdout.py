"""Research-only held-out W0 scenario source tests; no model downloads."""
import unittest

from experiments.driv3r.frankenlayers_lab.holdout import (
    CASES, HOLDOUT_SEED, SIZE, STEPS, ChallengeHost, overlay_obstacles, summarize,
)


class MiniW0:
    ACTIONS = ("STRAIGHT", "LEFT", "RIGHT", "BRANCH", "RETRACE", "STOP")

    def initial_world(self, seed, size=SIZE):
        return {(20, 20), (7, size // 2)}

    def run(self, *, seed, mode, family, steps, size, selector):
        blocks = self.initial_world(seed, size)
        assert (7, size // 2) not in blocks
        obs = {"legal": ["STRAIGHT", "STOP"], "family": family}
        assert selector(obs) == "STRAIGHT"
        return {"size": size, "seed": seed, "family": family,
                "obstacles": sorted(blocks), "events": []}

    def png_bytes(self, record):
        return b"png"


class HeldoutTests(unittest.TestCase):
    def test_distinct_scenarios_and_spawn_safety(self):
        geometries = []
        for family in CASES:
            blocks = overlay_obstacles({(7, SIZE // 2)}, family, SIZE)
            self.assertNotIn((7, SIZE // 2), blocks)
            self.assertTrue(all(0 <= x < SIZE and 0 <= y < SIZE for x, y in blocks))
            geometries.append(frozenset(blocks))
        self.assertEqual(len(set(geometries)), len(CASES))
        self.assertGreater(STEPS, 48)

    def test_pin_rejects_unsupported_case(self):
        with self.assertRaises(ValueError):
            overlay_obstacles(set(), "unregistered", SIZE)
        with self.assertRaises(ValueError):
            overlay_obstacles(set(), "greebles", SIZE - 1)

    def test_host_overlay_is_scoped_and_restored(self):
        w0 = MiniW0()
        original = w0.initial_world.__func__
        host = ChallengeHost(w0)
        for family in CASES:
            record = host.run(seed=HOLDOUT_SEED, mode="callback", family=family,
                              steps=STEPS, selector=lambda obs: "STRAIGHT")
            self.assertEqual(record["research_challenge"]["label"], CASES[family])
            self.assertFalse(record["research_challenge"]["native_game"])
            self.assertEqual(w0.initial_world.__func__, original)
            self.assertEqual(host.png_bytes(record), b"png")
        with self.assertRaises(ValueError):
            host.run(seed=570, mode="callback", family="greebles",
                     steps=STEPS, selector=lambda obs: "STRAIGHT")

    def test_summarize_is_descriptive_not_competence_claim(self):
        arm = {"valid_decisions": 6, "experiments": [
            {"decisions": 3, "raw_choices": ["BRANCH", "RETRACE", "BRANCH"],
             "metrics": {"new_steps": 2, "terminated_by_stop": False,
                         "total_revisit_contacts": 1, "invalid_raw_choices": 0}},
            {"decisions": 3, "raw_choices": ["LEFT", "STRAIGHT", "STOP"],
             "metrics": {"new_steps": 1, "terminated_by_stop": True,
                         "total_revisit_contacts": 2, "invalid_raw_choices": 0}},
        ]}
        s = summarize(arm)
        self.assertEqual(s["decisions"], 6)
        self.assertEqual(s["early_stop_episodes"], 1)
        self.assertEqual(s["full_length_episodes"], 0)
        self.assertEqual(s["distinct_world_action_sequences"], 2)
        self.assertEqual(s["new_steps_per_decision"], .5)


if __name__ == "__main__":
    unittest.main()
