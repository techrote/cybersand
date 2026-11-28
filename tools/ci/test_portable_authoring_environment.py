"""Portable compiler search must not inherit a developer toolchain's paths."""
import os
from pathlib import Path
import sys
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import package_materials_lab_candidate as package


class PortableAuthoringEnvironment(unittest.TestCase):
    def test_foreign_compiler_search_and_include_overrides_are_removed(self):
        foreign = {key: "foreign-development-toolchain" for key in (
            "GCC_EXEC_PREFIX", "COMPILER_PATH", "LIBRARY_PATH", "GCC_SPECS", "CPATH",
            "C_INCLUDE_PATH", "CPLUS_INCLUDE_PATH", "OBJC_INCLUDE_PATH",
            "COLLECT_GCC", "COLLECT_LTO_WRAPPER", "COLLECT_GCC_OPTIONS")}
        bundle = Path("portable owner (Unicode Ω)").resolve()
        with mock.patch.dict(os.environ, {**foreign, "PATH": "foreign-bin",
                                          "CYBERSAND_LAB_CXX": "foreign-g++",
                                          "SystemRoot": "C:/Windows"}, clear=True):
            actual = package.dependency_environment(bundle)
        for key in foreign:
            self.assertNotIn(key, actual)
        self.assertEqual(actual["CYBERSAND_LAB_CXX"], str(bundle / "dependencies/cxx/bin/g++.exe"))
        self.assertNotIn("foreign-bin", actual["PATH"])
        self.assertIn(str(bundle / "dependencies/cxx/bin"), actual["PATH"].split(os.pathsep))
        self.assertEqual(actual["PYTHONUTF8"], "1")


if __name__ == "__main__":
    unittest.main()
