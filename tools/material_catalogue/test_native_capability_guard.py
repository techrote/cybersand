"""Adversarial generated-consumer admission; no lock or source auto-refresh."""
from __future__ import annotations

import copy
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import compatibility as guard
import compiler
import native_capabilities
from test_compatibility import admitted_sources


class NativeCapabilityGuardTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if guard.NATIVE_CAPABILITY_ROUTE is None:
            raise AssertionError("native capability route must be bound to its retained source commit")
        cls.current = admitted_sources(guard.retained_sources())
        cls.lock = guard.read_lock(guard.ROOT / guard.LOCK)

    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="mat-capability-guard-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        for name, data in self.current.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        path = self.root / guard.LOCK
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(compiler.canonical_json(self.lock))

    def reject(self, pattern):
        with self.assertRaisesRegex(guard.CompatibilityError, pattern):
            guard.check(self.root)

    def test_current_route_is_authenticated_without_identity_transition(self):
        result = guard.check(self.root)
        self.assertTrue(result["production_cutover"])
        route = result["generated_native_consumer"]
        self.assertEqual(route["consumer"], "native/src/material_rules.cpp")
        self.assertEqual(route["fields"], ["hard_surface", "granular_support"])
        self.assertFalse(route["identity_transition"])
        self.assertEqual(result["catalogue_digest"], self.lock["catalogue_digest"])
        self.assertEqual(result["capability_digest"], self.lock["capability_digest"])

    def test_changed_header_is_refused(self):
        path = self.root / guard.NATIVE_CAPABILITY_HEADER
        path.write_bytes(path.read_bytes() + b"// changed\n")
        self.reject("material_capabilities.hpp differs from reviewed source")

    def test_coherent_authored_and_generated_change_cannot_rebaseline(self):
        path = self.root / "materials/catalogue/catalogue.json"
        catalogue = compiler.load_catalogue(path)
        catalogue["native"]["capabilities"][7]["hard_surface"] = False
        path.write_bytes(compiler.canonical_json(catalogue))
        (self.root / guard.NATIVE_CAPABILITY_HEADER).write_bytes(native_capabilities.render(catalogue))
        self.reject("differs from reviewed source")

    def test_changed_generator_is_refused_even_when_output_is_unchanged(self):
        path = self.root / "tools/material_catalogue/native_capabilities.py"
        path.write_bytes(path.read_bytes() + b"\n# changed generator\n")
        self.reject("native_capabilities.py differs from reviewed source")

    def test_changed_header_and_forged_pin_does_not_authenticate_against_git(self):
        name = guard.NATIVE_CAPABILITY_HEADER
        path = self.root / name
        path.write_bytes(path.read_bytes() + b"// forged pin\n")
        route = copy.deepcopy(guard.NATIVE_CAPABILITY_ROUTE)
        route["inputs_lf_sha256"][name] = guard.sha(path.read_bytes())
        with patch.object(guard, "NATIVE_CAPABILITY_ROUTE", route):
            self.reject("pin differs from retained source")

    def test_missing_or_extra_inventory_entries_are_refused(self):
        for change in ("missing", "extra"):
            route = copy.deepcopy(guard.NATIVE_CAPABILITY_ROUTE)
            if change == "missing":
                route["inputs_lf_sha256"].pop(guard.NATIVE_CAPABILITY_HEADER)
            else:
                route["inputs_lf_sha256"]["native/src/world.cpp"] = "0" * 64
            with self.subTest(change=change), patch.object(guard, "NATIVE_CAPABILITY_ROUTE", route):
                self.reject("exact generated source inventory")

    def test_missing_generated_file_is_refused(self):
        (self.root / guard.NATIVE_CAPABILITY_HEADER).unlink()
        self.reject("material_capabilities.hpp differs from reviewed source")

    def test_unregistered_include_and_namespace_consumers_are_refused(self):
        path = self.root / "native/src/foreign_capability_consumer.inc"
        for text in ('#include "cybersand/material_capabilities.hpp"\n',
                     'auto x = material_capability_catalogue::hard_surface(7);\n'):
            with self.subTest(text=text):
                path.write_text(text)
                self.reject("unadmitted consumer.*foreign_capability_consumer")

    def test_unregistered_godot_consumer_is_refused(self):
        path = self.root / "godot/scripts/foreign_capability_consumer.gd"
        path.write_text('const Bad = "material_capabilities.hpp"\n')
        self.reject("unadmitted consumer.*foreign_capability_consumer")

    def test_unrelated_native_transition_cannot_authenticate_route(self):
        route = copy.deepcopy(guard.NATIVE_CAPABILITY_ROUTE)
        route["consumer_lf_sha256"] = "0" * 64
        with patch.object(guard, "NATIVE_CAPABILITY_ROUTE", route):
            self.reject("consumer is not the reviewed transition target")

    def test_missing_code_pinned_route_is_refused(self):
        with patch.object(guard, "NATIVE_CAPABILITY_ROUTE", None):
            self.reject("no complete code-pinned consumer transition")

    def test_invalid_route_versions_types_and_record_paths_are_refused(self):
        attacks = (("pr", True, "pr must be a positive integer"),
                   ("issue", 0, "issue must be a positive integer"),
                   ("source_commit", "short", "expected a full source commit"),
                   ("record", "docs/audits/../bad.md", "expected a committed audit record"))
        for key, value, diagnostic in attacks:
            route = copy.deepcopy(guard.NATIVE_CAPABILITY_ROUTE)
            route[key] = value
            with self.subTest(key=key), patch.object(guard, "NATIVE_CAPABILITY_ROUTE", route):
                self.reject(diagnostic)


if __name__ == "__main__":
    unittest.main()
