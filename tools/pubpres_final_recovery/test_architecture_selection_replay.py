from copy import deepcopy
from decimal import Decimal
import unittest

from replay_architecture_selection import compare_bodies


class ArchitectureTrajectoryReplayTests(unittest.TestCase):
    def setUp(self):
        body = {"slot": 0, "instance_id": 1, "contacts": 0, "angle": Decimal("0.0"),
                "xy": [Decimal("200.002075195313"), Decimal("150.0")],
                "velocity": [Decimal("0.0"), Decimal("0.0")]}
        self.stock = [[deepcopy(body)] for _ in range(144)]
        self.custom = deepcopy(self.stock)

    def test_exact_adjacent_decimal_tie(self):
        self.custom[17][0]["xy"][0] = Decimal("200.002075195312")
        self.assertEqual(compare_bodies(self.stock, self.custom), {"xy": 1, "velocity": 0})

    def test_reject_non_tie_or_changed_physical_identity(self):
        for field, value in (("xy", [Decimal("200.002075195314"), Decimal("150.0")]),
                             ("xy", [Decimal("200.00209"), Decimal("150.0")]), ("contacts", True),
                             ("angle", Decimal("0.00000001")), ("extra", 0), ("instance_id", 2)):
            with self.subTest(field=field, value=value):
                self.custom = deepcopy(self.stock)
                self.custom[17][0][field] = value
                with self.assertRaises(ValueError):
                    compare_bodies(self.stock, self.custom)


if __name__ == "__main__":
    unittest.main()
