"""Failure-path tests for the experiment evidence driver, never performance runs."""
import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("cell_layout", Path(__file__).with_name("cell_layout.py"))
driver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(driver)


class EvidenceTests(unittest.TestCase):
    def test_measurement_hold_precedes_any_manifest_or_process_access(self):
        with self.assertRaisesRegex(RuntimeError, "Owner hold"):
            driver.measure(Path("does-not-exist.json"), False)

    def test_exact_comparator_rejects_same_length_corruption(self):
        with tempfile.TemporaryDirectory(dir=driver.OUT) as tmp:
            a, b = Path(tmp)/"a", Path(tmp)/"b"
            a.write_bytes(b"state-a"); b.write_bytes(b"state-b")
            with self.assertRaisesRegex(RuntimeError, "Exact comparison failed"):
                driver.equal_files(a,b)

    def test_observer_parser_ignores_only_event_payload(self):
        with tempfile.TemporaryDirectory(dir=driver.OUT) as tmp:
            p=Path(tmp)/"frames"
            core=struct.pack("<Q",22)+bytes(range(22))+bytes(range(128))
            p.write_bytes(core+struct.pack("<Q",1)+struct.pack("<QQ",7,9))
            self.assertEqual(list(driver.without_events(p)),[core])
            p.write_bytes(core+struct.pack("<Q",0))
            self.assertEqual(list(driver.without_events(p)),[core])

    def test_observer_parser_rejects_truncated_cells_and_events(self):
        with tempfile.TemporaryDirectory(dir=driver.OUT) as tmp:
            p=Path(tmp)/"bad"
            for data in (b"x",struct.pack("<Q",22)+b"x",
                         struct.pack("<Q",0)+bytes(128)+struct.pack("<Q",1)+b"x"):
                p.write_bytes(data)
                with self.assertRaises(ValueError): list(driver.without_events(p))


if __name__ == "__main__":
    driver.OUT.mkdir(parents=True,exist_ok=True)
    unittest.main()
