import copy
import unittest

from metrics import validate_deadline_baseline


def capture(supported=True):
    status = {"schema": "pubpres-material-deadline-v1", "enabled": False, "physical_credit": False}
    status.update({name: 0 for name in ("requested_hz", "interval_usec", "pending_count", "offers",
                                      "replaced_offers", "consumptions", "accepted_uploads", "cancellations")})
    status.update({name: -1 for name in ("pending_serial", "pending_generation", "deadline_usec", "next_upload_usec")})
    selector = {"requested": {"CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ": "0"},
                "material_deadline": status if supported else None}
    return {name: copy.deepcopy(selector) for name in ("selectors_before", "selectors_after")}


class BaselineDeadlineContract(unittest.TestCase):
    def test_current_off_and_frozen_absence_are_distinct(self):
        self.assertTrue(validate_deadline_baseline(capture(), required=True)["verified_off"])
        old = validate_deadline_baseline(capture(False), required=False)
        self.assertFalse(old["verified_off"])
        self.assertTrue(old["frozen_absence_verified"])
        for supported, required in ((False, True), (True, False)):
            with self.assertRaises(ValueError):
                validate_deadline_baseline(capture(supported), required=required)

    def test_every_boundary_rejects_unregistered_work_and_wrong_types(self):
        status_faults = {"schema": "other", "enabled": True, "physical_credit": True,
                         "requested_hz": 30, "interval_usec": 16667, "pending_count": 1,
                         "offers": 1, "replaced_offers": 1, "consumptions": 1,
                         "accepted_uploads": 1, "cancellations": 1,
                         "pending_serial": 9, "pending_generation": 2,
                         "deadline_usec": 100000, "next_upload_usec": 100000}
        for phase in ("selectors_before", "selectors_after"):
            for key, value in status_faults.items():
                row = capture(); row[phase]["material_deadline"][key] = value
                with self.subTest(phase=phase, field=key), self.assertRaises(ValueError):
                    validate_deadline_baseline(row, required=True)
            for value in (False, 0.0):
                row = capture(); row[phase]["material_deadline"]["offers"] = value
                with self.assertRaises(ValueError):
                    validate_deadline_baseline(row, required=True)
            row = capture(); row[phase]["requested"]["CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ"] = "30"
            with self.assertRaises(ValueError):
                validate_deadline_baseline(row, required=True)
            row = capture(False); del row[phase]["material_deadline"]
            with self.assertRaises(ValueError):
                validate_deadline_baseline(row, required=False)


if __name__ == "__main__":
    unittest.main()
