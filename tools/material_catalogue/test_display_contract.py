"""Actual file mutations against the bounded B admission (all in temp copies)."""
from pathlib import Path
import tempfile
import unittest

import display_contract as contract
import legacy_display_names as legacy
import presentation
from consumer_test_support import copy_b_inputs


class DisplayContractTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="mat353b-source-guards-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        copy_b_inputs(self.root)

    def check(self):
        return contract.check(self.root)

    def test_fixture_copy_refuses_the_real_source_checkout_before_writing(self):
        path = contract.ROOT / contract.MAIN
        before = (path.read_bytes(), path.stat().st_mtime_ns)
        for target in (contract.ROOT, contract.ROOT / "tools/material_catalogue"):
            with self.subTest(target=target), self.assertRaisesRegex(ValueError, "outside the task source"):
                copy_b_inputs(target)
        self.assertEqual(before, (path.read_bytes(), path.stat().st_mtime_ns))

    def test_actual_admitted_source_nonwriting(self):
        before = {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in self.root.rglob("*") if p.is_file()}
        report = self.check()
        self.assertEqual(report["status"], "PASS")
        self.assertFalse(report["runtime_execution"])
        self.assertTrue(report["b_consumer_report_required"])
        self.assertEqual(before, {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in before})

    def test_missing_stale_and_poisoned_generated_resource_fail_closed(self):
        path = self.root / contract.RESOURCE
        original = path.read_bytes()
        for payload in (None, original + b"\n", original.replace(b'"sand"', b'"poisoned sand"', 1)):
            with self.subTest(payload=payload is None):
                path.unlink()
                if payload is not None:
                    path.write_bytes(payload)
                with self.assertRaisesRegex(ValueError, "missing|stale"):
                    self.check()
                path.write_bytes(original)

    def test_frozen_oracle_cannot_be_rewritten_with_candidate(self):
        path = self.root / legacy.FIXTURE
        path.write_bytes(path.read_bytes().replace(b'"sand"', b'"poisoned sand"', 1))
        with self.assertRaisesRegex(ValueError, "frozen legacy-name fixture"):
            self.check()

    def test_decorative_unused_preload_and_runtime_fallback_are_refused(self):
        path = self.root / contract.MAIN
        old = legacy.git_bytes(contract.ROOT, contract.MAIN).decode("utf-8")
        path.write_text(old.replace("extends Control\n", "extends Control\n\n" + contract.PRELOAD, 1))
        with self.assertRaisesRegex(ValueError, "declared.*consumer"):
            self.check()

    def test_second_direct_alias_and_indirect_consumers_are_refused(self):
        payloads = (
            'extends RefCounted\nconst Other = preload("res://scripts/generated/material_ui_names.gd")\n',
            'extends RefCounted\nconst Other = preload("res://scripts/../scripts/generated/material_ui_names.gd")\n',
            'extends RefCounted\nfunc x():\n\treturn load("res://scripts/generated/" + "material_" + "ui_names.gd")\n',
        )
        for payload in payloads:
            with self.subTest(payload=payload):
                path = self.root / "godot/scripts/second_consumer.gd"
                path.write_text(payload)
                with self.assertRaisesRegex(ValueError, "unapproved executable source inventory"):
                    self.check()
                path.unlink()

    def test_existing_script_cannot_hide_indirect_import(self):
        path = self.root / "godot/scripts/web_demo_controller.gd"
        path.write_text(path.read_text() + '\nfunc alias_name():\n\treturn load("res://scripts/generated/" + "material_ui_" + "names.gd")\n')
        with self.assertRaisesRegex(ValueError, "indirect/alias imports"):
            self.check()

    def test_native_indirect_consumer_cannot_bypass_name_scan(self):
        path = self.root / "native/src/second_consumer.cpp"
        path.write_text('auto path = "res://scripts/generated/material_ui_" "names.gd";\n')
        with self.assertRaisesRegex(ValueError, "unapproved executable source inventory"):
            self.check()

    def test_outside_scripts_addon_and_embedded_consumers_are_refused(self):
        for relative, payload in (
            ("godot/second_consumer.gd", 'extends Node\nconst Names = preload("res://scripts/generated/material_ui_names.gd")\n'),
            ("godot/addons/second/reader.gd", 'extends Node\nfunc x(): return load("res://scripts/generated/" + "material_ui_names.gd")\n'),
            ("godot/second_consumer.tres", '[gd_resource type="GDScript" format=3]\n[resource]\nscript/source = "extends Node"\n'),
        ):
            with self.subTest(relative=relative):
                path = self.root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(payload)
                with self.assertRaisesRegex(ValueError, "unapproved executable source inventory"):
                    self.check()
                path.unlink()

    def test_changed_project_routing_and_embedded_scene_source_are_refused(self):
        for relative in ("godot/project.godot", "godot/main.tscn"):
            with self.subTest(relative=relative):
                path = self.root / relative
                original = path.read_bytes()
                path.write_bytes(original + b'\n; changed routing or embedded code\n')
                with self.assertRaisesRegex(ValueError, "drift outside the single B consumer"):
                    self.check()
                path.write_bytes(original)

    def test_generated_file_renaming_is_not_an_import_bypass(self):
        path = self.root / "godot/scripts/innocent_labels.gd"
        path.write_bytes((self.root / contract.RESOURCE).read_bytes())
        with self.assertRaisesRegex(ValueError, "renamed resources"):
            self.check()

    def test_main_alias_or_second_use_is_not_approved(self):
        path = self.root / contract.MAIN
        path.write_text(path.read_text() + '\nconst Another = MaterialUiNames\n')
        with self.assertRaisesRegex(ValueError, "alias/second use"):
            self.check()

    def test_identity_omission_and_unrelated_fingerprint_drift_are_refused(self):
        path = self.root / contract.IDENTITY
        original = path.read_text()
        for changed in (original.replace(contract.IDENTITY_ENTRY, ""), original + "\n# drift\n"):
            with self.subTest(omitted=changed != original):
                path.write_text(changed)
                with self.assertRaisesRegex(ValueError, "stale source fingerprint"):
                    self.check()
        path.write_text(original)

    def test_script_file_alias_is_refused_even_when_bytes_match(self):
        path = self.root / "godot/scripts/web_demo_controller.gd"
        saved = self.root / "web.gd"
        path.rename(saved)
        path.symlink_to(saved)
        with self.assertRaisesRegex(ValueError, "source aliases"):
            self.check()

    def test_current_report_requires_current_route_and_recovers_after_rollback_control(self):
        path = self.root / contract.MAIN
        candidate = path.read_bytes()
        path.write_bytes(legacy.git_bytes(contract.ROOT, contract.MAIN))
        with self.assertRaisesRegex(ValueError, "declared.*consumer"):
            self.check()
        path.write_bytes(candidate)
        self.assertEqual(self.check()["status"], "PASS")


if __name__ == "__main__":
    unittest.main()
