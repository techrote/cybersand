"""CPU-only exact-source unittest discovery inventory regressions."""
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from experiments.driv3r.stage_d.direct import inventory


class TestInventoryTests(unittest.TestCase):
    def create_tree(self, root, counts):
        folder = Path(root) / inventory.LANE
        folder.mkdir(parents=True)
        for name, count in counts.items():
            body = "import unittest\nclass Smoke(unittest.TestCase):\n"
            body += "".join(f"    def test_{n}(self): pass\n" for n in range(count))
            (folder / name).write_text(body, encoding="utf-8")
        return folder

    def test_exact_source_inventory_counts_all_methods(self):
        with TemporaryDirectory() as tmp, patch.object(inventory, "REQUIRED_METHODS", {"test_a.py": 2}):
            self.create_tree(tmp, {"test_a.py": 3})
            report = inventory.audit_test_inventory(Path(tmp))
            self.assertEqual(report["method_count"], 3)
            self.assertEqual(report["module_method_counts"], {"test_a.py": 3})

    def test_missing_module_is_refused(self):
        with TemporaryDirectory() as tmp, patch.object(inventory, "REQUIRED_METHODS", {"test_a.py": 1}):
            self.create_tree(tmp, {})
            with self.assertRaisesRegex(inventory.TestInventoryError, "missing"):
                inventory.audit_test_inventory(Path(tmp))

    def test_unknown_module_is_refused(self):
        with TemporaryDirectory() as tmp, patch.object(inventory, "REQUIRED_METHODS", {"test_a.py": 1}):
            self.create_tree(tmp, {"test_a.py": 1, "test_b.py": 1})
            with self.assertRaisesRegex(inventory.TestInventoryError, "unknown"):
                inventory.audit_test_inventory(Path(tmp))

    def test_removed_method_is_refused(self):
        with TemporaryDirectory() as tmp, patch.object(inventory, "REQUIRED_METHODS", {"test_a.py": 2}):
            self.create_tree(tmp, {"test_a.py": 1})
            with self.assertRaisesRegex(inventory.TestInventoryError, "lost source methods"):
                inventory.audit_test_inventory(Path(tmp))

    def test_unparseable_source_is_refused(self):
        with TemporaryDirectory() as tmp, patch.object(inventory, "REQUIRED_METHODS", {"test_a.py": 1}):
            folder = self.create_tree(tmp, {"test_a.py": 1})
            (folder / "test_a.py").write_text("not valid python @@@", encoding="utf-8")
            with self.assertRaisesRegex(inventory.TestInventoryError, "cannot be parsed"):
                inventory.audit_test_inventory(Path(tmp))

    def test_symlinked_module_is_refused(self):
        with TemporaryDirectory() as tmp, patch.object(inventory, "REQUIRED_METHODS", {"test_a.py": 1}):
            folder = self.create_tree(tmp, {"test_a.py": 1})
            source = folder / "original.py"
            (folder / "test_a.py").rename(source)
            (folder / "test_a.py").symlink_to(source)
            with self.assertRaisesRegex(inventory.TestInventoryError, "not a regular"):
                inventory.audit_test_inventory(Path(tmp))

    def test_top_level_function_does_not_count_as_unittest_method(self):
        with TemporaryDirectory() as tmp, patch.object(inventory, "REQUIRED_METHODS", {"test_a.py": 2}):
            folder = self.create_tree(tmp, {"test_a.py": 1})
            with (folder / "test_a.py").open("a", encoding="utf-8") as out:
                out.write("\ndef test_not_in_a_testcase(): pass\n")
            with self.assertRaisesRegex(inventory.TestInventoryError, "lost source methods"):
                inventory.audit_test_inventory(Path(tmp))


if __name__ == "__main__":
    unittest.main()
