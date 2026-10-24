"""Independent IN native damping-v2 schema, identity and integer-bound checks."""
import json
import unittest
import inertial_parameter_contract as contract
import inertial_contract as model
import policy_contract as policy


class InertialDampingContract(unittest.TestCase):
    def test_registered_native_artifacts_match(self):
        data = contract.vectors()
        self.assertEqual(json.loads(contract.JSON_PATH.read_text(encoding="utf-8")), data)
        self.assertEqual(contract.HEADER_PATH.read_text(encoding="utf-8"), contract.header(data))

    def test_version2_is_separate_from_historical_illustrative_version1(self):
        self.assertEqual(policy.BLOCK_SCHEMAS[("family", 4, 1)]["fields"],
                         (("damping_q16", 0, 65536), ("speed_cap_q8", 256, 2048)))
        cases = {c["name"]: c for c in contract.vectors()["cases"]}
        self.assertFalse(cases["historical-illustrative-v1"]["accepted"])
        self.assertEqual(cases["historical-illustrative-v1"]["refusal"], "unknown_parameter")
        self.assertTrue(all(cases[f"damping-{n}"]["accepted"] for n in (0, 1, 7, 16)))
        self.assertFalse(cases["below-range"]["accepted"])
        self.assertFalse(cases["above-range"]["accepted"])
        self.assertFalse(cases["unused-family"]["accepted"])

    def test_default_identity_and_explicit_actual_parameter(self):
        cases = {c["name"]: c for c in contract.vectors()["cases"]}
        self.assertEqual(cases["omitted-default"]["extension_identity"], cases["damping-1"]["extension_identity"])
        self.assertEqual(len({cases[f"damping-{n}"]["extension_identity"] for n in (0, 1, 7, 16)}), 4)
        self.assertNotEqual(cases["omitted-default"]["policy_hash"], cases["damping-1"]["policy_hash"])

    def test_all_supported_damping_values_preserve_signed_two_cell_bound(self):
        for numerator in range(17):
            for velocity in range(-32, 33):
                applied, remainder = model.trunc_mul(velocity, (numerator, 16))
                self.assertLessEqual(abs(velocity - applied), 32)
                self.assertEqual(velocity * numerator, applied * 16 + remainder)
                for accumulator in (-15, 15):
                    self.assertLessEqual(abs(velocity - applied + accumulator) // 16, 2)
        self.assertEqual(model.trunc_mul(-17, (8, 16)), (-8, -8))
        self.assertEqual(model.trunc_mul(17, (8, 16)), (8, 8))
        self.assertEqual(model.trunc_mul(32, (0, 16)), (0, 0))
        self.assertEqual(model.trunc_mul(-32, (16, 16)), (-32, 0))


if __name__ == "__main__":
    unittest.main()
