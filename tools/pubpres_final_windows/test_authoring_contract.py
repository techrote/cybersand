#!/usr/bin/env python3
"""The final Full profile retains every original authoring/source/image gate."""
import copy
import inspect
import unittest

import qualify_installed as final
import run_regressions as original


class AuthoringContractTests(unittest.TestCase):
    def test_only_named_publication_policy_validator_differs(self):
        expected = inspect.getsource(original.combined_evidence).replace("def combined_evidence(", "def authoring_evidence(")
        expected = expected.replace('continuation = validate_continuation_evidence(result.get("same_frame_continuation"), same_frame)',
                                    'continuation = validate_full_policy(result.get("same_frame_continuation"))')
        self.assertEqual(inspect.getsource(final.authoring_evidence), expected)

    def test_full_two_policy_requires_actual_owner_not_just_selector(self):
        phase = {"selectors": final.full_policy()["selectors"],
                 "status": {"version": 1, "requested": False, "enabled": False, "disabled_reason": "", "mode": "off",
                            "maximum_attempts_per_process_frame": 1, "maximum_mailbox_reads_per_attempt": 1,
                            "wait_usec": 0, "new_physics_callbacks": 0, "carried_time_credit": False},
                 "material": {"requested_mode": "full", "backend": "full", "full_image_slots": 2, "fallback_reason": ""}}
        evidence = {"schema": "pubpres-authoring-continuation-evidence-v1", "mode": "off", "claim": "configuration-only",
                    "before": copy.deepcopy(phase), "after": copy.deepcopy(phase)}
        final.validate_full_policy(evidence)
        for key, value in (("full_image_slots", 3), ("backend", "blit"), ("fallback_reason", "refused")):
            with self.subTest(key=key):
                bad = copy.deepcopy(evidence)
                bad["after"]["material"][key] = value
                with self.assertRaises(ValueError):
                    final.validate_full_policy(bad)
        bad = copy.deepcopy(evidence)
        bad["before"]["status"]["carried_time_credit"] = 0
        with self.assertRaises(ValueError):
            final.validate_full_policy(bad)


if __name__ == "__main__":
    unittest.main()
