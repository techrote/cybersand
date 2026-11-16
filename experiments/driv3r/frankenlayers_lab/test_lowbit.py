"""Fail-closed source tests for the IQ3_XS model-only W0 screening arm."""
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from experiments.driv3r.backend import PINS
from experiments.driv3r.frankenlayers_lab.infer_lowbit import MODES, validate_iq3_receipt


class IQ3ScreenTests(unittest.TestCase):
    def test_screen_excludes_unqualified_layers(self):
        self.assertEqual(MODES, ("aero4_no10", "aero4_no2"))

    def test_receipt_checks_real_quant_bytes_and_fixed_donor(self):
        with tempfile.TemporaryDirectory() as tmp:
            q8 = Path(tmp) / "q8.gguf"
            iq3 = Path(tmp) / "iq3.gguf"
            q8.write_bytes(b"immutable-test-donor")
            with iq3.open("wb") as f:
                f.truncate(1_000_001)
            receipt = {
                "schema": "frankenlayers-iq3-requant/1",
                "quant": "IQ3_XS",
                "allow_requantize": True,
                "q8_sha256": PINS["model"]["sha256"],
                "iq3_sha256": "test-iq3-bytes",
            }
            def digest(path):
                return PINS["model"]["sha256"] if path == q8 else "test-iq3-bytes"
            with patch("experiments.driv3r.frankenlayers_lab.infer_lowbit.sha256_file",
                       side_effect=digest):
                validate_iq3_receipt(receipt, q8, iq3)
                for field, bad in (("quant", "Q4_K_M"), ("allow_requantize", False),
                                   ("q8_sha256", "not-the-donor"),
                                   ("iq3_sha256", "not-the-IQ3-file"),
                                   ("schema", "unknown")):
                    invalid = dict(receipt, **{field: bad})
                    with self.subTest(field=field), self.assertRaises(ValueError):
                        validate_iq3_receipt(invalid, q8, iq3)
                iq3.unlink()
                with self.assertRaises(ValueError):
                    validate_iq3_receipt(receipt, q8, iq3)

if __name__ == "__main__":
    unittest.main()
