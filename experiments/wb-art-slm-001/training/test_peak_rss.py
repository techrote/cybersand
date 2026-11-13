"""Platform-specific training completion telemetry regressions; no model required."""
from __future__ import annotations

import builtins
import sys
import types
import unittest
from unittest import mock

import train_lora


class PeakRssTests(unittest.TestCase):
    def test_windows_has_null_peak_without_importing_resource(self):
        real_import = builtins.__import__

        def prohibit_resource(name, *args, **kwargs):
            if name == "resource":
                raise AssertionError("Windows must not import resource")
            return real_import(name, *args, **kwargs)

        # Simulate Windows on POSIX with an import trap, so this covers
        # the exact failure at the end of an otherwise completed run.
        with mock.patch.object(train_lora.sys, "platform", "win32"):
            with mock.patch("builtins.__import__", side_effect=prohibit_resource):
                self.assertIsNone(train_lora.peak_rss_kib())

    def test_posix_missing_resource_is_nonfatal(self):
        real_import = builtins.__import__

        def missing_resource(name, *args, **kwargs):
            if name == "resource":
                raise ModuleNotFoundError("No module named 'resource'")
            return real_import(name, *args, **kwargs)

        with mock.patch.object(train_lora.sys, "platform", "linux"):
            with mock.patch("builtins.__import__", side_effect=missing_resource):
                self.assertIsNone(train_lora.peak_rss_kib())

    def test_linux_ru_maxrss_is_kib(self):
        resource = types.ModuleType("resource")
        resource.RUSAGE_SELF = 0
        resource.getrusage = lambda scope: types.SimpleNamespace(ru_maxrss=8192)
        with mock.patch.object(train_lora.sys, "platform", "linux"):
            with mock.patch.dict(sys.modules, {"resource": resource}):
                self.assertEqual(train_lora.peak_rss_kib(), 8192)

    def test_macos_ru_maxrss_bytes_convert_to_kib(self):
        resource = types.ModuleType("resource")
        resource.RUSAGE_SELF = 0
        resource.getrusage = lambda scope: types.SimpleNamespace(ru_maxrss=4097)
        with mock.patch.object(train_lora.sys, "platform", "darwin"):
            with mock.patch.dict(sys.modules, {"resource": resource}):
                self.assertEqual(train_lora.peak_rss_kib(), 5)


if __name__ == "__main__":
    unittest.main()
