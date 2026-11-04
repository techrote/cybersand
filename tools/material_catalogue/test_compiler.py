#!/usr/bin/env python3
"""Adversarial authoring/output regressions for the #353-A shadow compiler.

These tests exercise its public API and CLI with independently mutated input.
The separately compiled native oracle owns source parity; this suite does not
reinterpret native C++ or reimplement the compiler's validation predicates.
"""
from __future__ import annotations

import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import compiler

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "materials/catalogue/catalogue.json"
CLI = Path(__file__).with_name("compiler.py")


def tree_state(root: Path) -> dict:
    """Observe bytes and mtimes, including stray files and directory changes."""
    if not root.exists():
        return {}
    result = {}
    for path in [root, *sorted(root.rglob("*"))]:
        relative = str(path.relative_to(root))
        stat = path.stat()
        result[relative] = (path.read_bytes() if path.is_file() else None,
                            stat.st_mtime_ns)
    return result


class CatalogueTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.baseline = json.loads(SOURCE.read_text(encoding="utf-8"))

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="cybersand-mat353-test-")
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.source = self.directory / "catalogue.json"
        self.output = self.directory / "output"

    def write(self, value=None, *, path=None, raw=None):
        path = path or self.source
        path.parent.mkdir(parents=True, exist_ok=True)
        if raw is None:
            raw = json.dumps(self.baseline if value is None else value,
                             ensure_ascii=False, indent=2) + "\n"
        path.write_text(raw, encoding="utf-8", newline="\n")
        return path

    def bad(self, value=None, *, pointers=(), raw=None, isolated=False):
        source = self.write(value, raw=raw)
        with self.assertRaises(compiler.CatalogueError) as caught:
            compiler.load_catalogue(source, isolated=isolated)
        diagnostic = str(caught.exception)
        self.assertIn(source.name, diagnostic, diagnostic)
        for pointer in pointers:
            self.assertIn(pointer, diagnostic, diagnostic)
        return diagnostic

    def run_cli(self, source=None, output=None, *arguments):
        return subprocess.run(
            [sys.executable, str(CLI), "--source", str(source or self.source),
             "--output", str(output or self.output), *arguments],
            cwd=self.directory, text=True, capture_output=True, timeout=20,
            env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"})

    def test_public_default_catalogue_is_accepted_and_renders_only_shadow_artifacts(self):
        rendered = compiler.render_outputs(compiler.load_catalogue(SOURCE))
        self.assertTrue(rendered)
        self.assertIn("catalogue.shadow.hpp", rendered)
        self.assertIn("catalogue_shadow.gd", rendered)
        self.assertIn("inspection.json", rendered)
        for name, data in rendered.items():
            with self.subTest(artifact=name):
                self.assertEqual(Path(name).name, name)
                self.assertIsInstance(data, bytes)
                data.decode("utf-8", errors="strict")
                self.assertTrue(data.endswith(b"\n"))
                self.assertNotIn(b"\r", data)
                self.assertNotIn(str(ROOT).encode(), data)
                self.assertNotIn(str(SOURCE).encode(), data)
        self.assertEqual(json.loads(rendered["inspection.json"])["schema_version"], 1)

    def test_cpp_free_text_compiles_and_round_trips_special_utf8_bytes(self):
        # All nine trigraph spellings are legal authored text. GCC still warns
        # about them in C++20, and the native parity compiler treats warnings as
        # errors. Exercise the generated header and actual decoded bytes.
        value = "??= ??/ ??' ??( ??) ??! ??< ??> ??- \" \\ \t\n\r\x01 café 雪"
        changed = copy.deepcopy(self.baseline)
        for family in changed["native"]["interactions"]["families"]:
            family["purpose"] = value
        compiler.compile_catalogue(self.write(changed), self.output)
        probe = self.directory / "string-readback.cpp"
        probe.write_text(
            '#include "catalogue.shadow.hpp"\n'
            '#include <fstream>\n'
            'int main(int argc, char** argv) {\n'
            '    if (argc != 2) return 1;\n'
            '    const auto value = cybersand::material_catalogue_shadow::kSemanticFamilies[0].purpose;\n'
            '    std::ofstream out(argv[1], std::ios::binary);\n'
            '    out.write(value.data(), static_cast<std::streamsize>(value.size()));\n'
            '    out.close();\n'
            '    return out ? 0 : 2;\n'
            '}\n', encoding="utf-8")
        executable = self.directory / ("string-readback.exe" if os.name == "nt" else "string-readback")
        compiled = subprocess.run(
            ["c++", "-std=c++20", "-Wall", "-Wextra", "-Werror", "-I", str(self.output),
             str(probe), "-o", str(executable)], capture_output=True, timeout=30)
        self.assertEqual(compiled.returncode, 0, compiled.stderr.decode("utf-8", errors="replace"))
        readback = self.directory / "string-readback.bin"
        executed = subprocess.run([str(executable), str(readback)], capture_output=True, timeout=10)
        self.assertEqual(executed.returncode, 0, executed.stderr)
        self.assertEqual(readback.read_bytes(), value.encode("utf-8"))

    def test_input_named_like_generated_file_cannot_be_overwritten_by_its_output_directory(self):
        source = self.output / "inspection.json"
        self.write(path=source)
        before = tree_state(self.output)
        for checking in (False, True):
            with self.subTest(check=checking):
                with self.assertRaises(compiler.CatalogueError):
                    compiler.compile_catalogue(source, self.output, check=checking)
                self.assertEqual(before, tree_state(self.output))

    def test_unknown_fields_and_schema_versions_have_source_locations(self):
        changed = copy.deepcopy(self.baseline)
        changed["silently_ignored_option"] = True
        self.bad(changed, pointers=("/silently_ignored_option",))
        for version in (0, 2, -1, True, 1.0, "1", None):
            with self.subTest(schema_version=repr(version)):
                changed = copy.deepcopy(self.baseline)
                changed["schema_version"] = version
                self.bad(changed, pointers=("/schema_version",))

    def test_json_syntax_failure_reports_file_line_and_column(self):
        diagnostic = self.bad(raw='{\n  "schema_version": 1,\n}\n')
        self.assertRegex(diagnostic.lower(), r"line\s*[:=]?\s*3")
        self.assertRegex(diagnostic.lower(), r"col(?:umn)?\s*[:=]?\s*1")

    def test_duplicate_json_object_keys_are_not_last_writer_wins(self):
        raw = json.dumps(self.baseline)
        # Both equal and differing duplicate values are malformed authorship.
        for value in (1, 2):
            with self.subTest(second_value=value):
                changed = raw.replace('"schema_version": 1',
                                      f'"schema_version": 1, "schema_version": {value}', 1)
                self.bad(raw=changed, pointers=("/schema_version",))

    def test_nonfinite_json_tokens_never_enter_catalogue(self):
        raw = json.dumps(self.baseline)
        for token in ("NaN", "Infinity", "-Infinity"):
            with self.subTest(token=token):
                changed = raw.replace('"schema_version": 1',
                                      '"schema_version": ' + token, 1)
                self.bad(raw=changed, pointers=("/schema_version",))

    def test_missing_required_root_field_is_not_defaulted(self):
        changed = copy.deepcopy(self.baseline)
        del changed["schema_version"]
        self.bad(changed, pointers=("/schema_version",))

    def test_clean_output_roots_and_different_source_paths_are_byte_identical(self):
        a = self.write(path=self.directory / "a" / "catalogue.json")
        b = self.write(path=self.directory / "other" / "deep" / "catalogue.json")
        out_a, out_b = self.directory / "out-a", self.directory / "out-b"
        compiler.compile_catalogue(a, out_a)
        compiler.compile_catalogue(b, out_b)
        bytes_a = {str(p.relative_to(out_a)): p.read_bytes() for p in out_a.rglob("*") if p.is_file()}
        bytes_b = {str(p.relative_to(out_b)): p.read_bytes() for p in out_b.rglob("*") if p.is_file()}
        self.assertTrue(bytes_a)
        self.assertEqual(bytes_a, bytes_b)
        for data in bytes_a.values():
            self.assertNotIn(str(self.directory).encode(), data)

    def test_unchanged_generation_preserves_every_file_mtime(self):
        self.write()
        compiler.compile_catalogue(self.source, self.output)
        for path in self.output.rglob("*"):
            if path.is_file():
                os.utime(path, ns=(1_000_000_000, 1_000_000_000))
        before = tree_state(self.output)
        changed = compiler.compile_catalogue(self.source, self.output)
        self.assertEqual(changed, [])
        self.assertEqual(tree_state(self.output), before)

    def test_check_does_not_create_an_absent_output_directory(self):
        self.write()
        with self.assertRaises(compiler.DriftError):
            compiler.compile_catalogue(self.source, self.output, check=True)
        self.assertFalse(self.output.exists())
        result = self.run_cli(None, None, "--check")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(self.output.exists())
        self.assertNotIn("Traceback", result.stderr)

    def test_check_detects_drift_without_repairing_or_touching_any_output(self):
        self.write()
        compiler.compile_catalogue(self.source, self.output)
        damaged = self.output / "catalogue.shadow.hpp"
        damaged.write_bytes(damaged.read_bytes() + b"// independently introduced drift\n")
        before = tree_state(self.output)
        with self.assertRaises(compiler.DriftError) as caught:
            compiler.compile_catalogue(self.source, self.output, check=True)
        self.assertIn(damaged.name, str(caught.exception))
        self.assertEqual(tree_state(self.output), before)
        result = self.run_cli(None, None, "--check")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(damaged.name, result.stdout + result.stderr)
        self.assertEqual(tree_state(self.output), before)

    def test_successful_check_is_nonwriting_and_cli_works_outside_checkout(self):
        self.write()
        compiler.compile_catalogue(self.source, self.output)
        before = tree_state(self.output)
        self.assertEqual(compiler.compile_catalogue(self.source, self.output, check=True), [])
        result = self.run_cli(None, None, "--check")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(tree_state(self.output), before)

    def test_rejected_source_keeps_previous_output_bytes_and_mtimes(self):
        self.write()
        compiler.compile_catalogue(self.source, self.output)
        before = tree_state(self.output)
        changed = copy.deepcopy(self.baseline)
        changed["schema_version"] = 9001
        self.write(changed)
        with self.assertRaises(compiler.CatalogueError):
            compiler.compile_catalogue(self.source, self.output)
        self.assertEqual(tree_state(self.output), before)
        result = self.run_cli()
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        self.assertEqual(tree_state(self.output), before)

    def test_invalid_source_does_not_create_partial_output(self):
        self.write(raw='{"schema_version": 1, "materials": [}')
        with self.assertRaises(compiler.CatalogueError):
            compiler.compile_catalogue(self.source, self.output)
        self.assertFalse(self.output.exists())


    def test_unknown_field_pointer_escapes_slashes_and_tildes(self):
        changed = copy.deepcopy(self.baseline)
        changed["extension/path~name"] = 1
        self.bad(changed, pointers=("/extension~1path~0name",))

    def test_top_level_nonobjects_are_rejected_as_authored_input(self):
        for value in ([], None, True, 1, "catalogue"):
            with self.subTest(value=value):
                self.bad(raw=json.dumps(value))

    def test_output_repair_does_not_touch_unchanged_files(self):
        self.write()
        compiler.compile_catalogue(self.source, self.output)
        damaged = self.output / "catalogue.shadow.hpp"
        original = damaged.read_bytes()
        damaged.write_bytes(original + b"// damaged output\n")
        for path in self.output.iterdir():
            os.utime(path, ns=(1_000_000_000, 1_000_000_000))
        before = tree_state(self.output)
        changed = compiler.compile_catalogue(self.source, self.output)
        self.assertEqual(changed, [damaged.name])
        self.assertEqual(damaged.read_bytes(), original)
        after = tree_state(self.output)
        for name in before:
            if name not in (".", damaged.name):
                self.assertEqual(after[name], before[name], name)

    def test_unexpected_output_is_preserved_and_never_silently_deleted(self):
        self.write()
        compiler.compile_catalogue(self.source, self.output)
        (self.output / "owner-note.txt").write_text("Keep this unrelated file.\n")
        before = tree_state(self.output)
        for check in (False, True):
            with self.subTest(check=check):
                with self.assertRaises(compiler.CatalogueError) as caught:
                    compiler.compile_catalogue(self.source, self.output, check=check)
                self.assertIn("owner-note.txt", str(caught.exception))
                self.assertEqual(tree_state(self.output), before)

    def test_existing_file_cannot_be_replaced_by_output_directory(self):
        self.write()
        self.output.write_bytes(b"Existing owner data.\n")
        before = self.output.read_bytes(), self.output.stat().st_mtime_ns
        with self.assertRaises(compiler.CatalogueError):
            compiler.compile_catalogue(self.source, self.output)
        self.assertEqual((self.output.read_bytes(), self.output.stat().st_mtime_ns), before)

    def isolated_fixture(self):
        """Private clone of Sand at 132; no production ID allocation is made."""
        changed = copy.deepcopy(self.baseline)
        changed["scope"] = "isolated-synthetic"
        native = changed["native"]
        native["identity"]["allocated_slots"] = 133
        material = copy.deepcopy(native["materials"][2])
        material.update(id=132, name="synthetic-powder")
        native["materials"].append(material)
        capability = copy.deepcopy(native["capabilities"][2])
        capability.update(id=132, hard_surface=False, pair_participant=False)
        native["capabilities"][132] = capability
        return changed

    def test_descriptor_integer_fields_reject_boolean_coercion_and_storage_overflow(self):
        # Boundary values come from the native contract, not compiler constants.
        attacks = {
            "id": (-1, 256, True, 2.0, "2"),
            "state": (-1, 6, True, 2.0),
            "kernel": (-1, 27, True, 1.0),
            "density": (-1, 65536, True, 1600.0, "1600"),
            "initial_state_a": (-1, 256, False, 0.0),
            "initial_state_b": (-1, 256, False, 0.0),
            "maximum_write_radius": (-1, 3, True, 1.0),
            "density_motion": (-1, 3, True, 1.0),
            "lateral_flow": (-1, 3, False, 0.0),
            "viscosity_index": (-1, 256, False, 0.0),
        }
        for field, values in attacks.items():
            for value in values:
                with self.subTest(field=field, value=repr(value)):
                    changed = copy.deepcopy(self.baseline)
                    changed["native"]["materials"][2][field] = value
                    self.bad(changed, pointers=(f"/native/materials/2/{field}",))

    def test_rgba_and_booleans_have_exact_types_and_widths(self):
        for rgba, suffix in (([0, 0, 0], ""), ([0, 0, 0, 256], "/3"),
                             ([0, 0, -1, 255], "/2"), ([False, 0, 0, 255], "/0")):
            with self.subTest(rgba=rgba):
                changed = copy.deepcopy(self.baseline)
                changed["native"]["materials"][2]["rgba"] = rgba
                self.bad(changed, pointers=("/native/materials/2/rgba" + suffix,))
        for field in ("movable", "valid", "current_rule_available", "accepts_density_exchange"):
            changed = copy.deepcopy(self.baseline)
            changed["native"]["materials"][2][field] = 1
            self.bad(changed, pointers=(f"/native/materials/2/{field}",))

    def test_optional_state_contract_does_not_hide_unsupported_kernel_radius(self):
        for material, radius in ((1, 1), (2, 0)):
            with self.subTest(material=material, radius=radius):
                changed = copy.deepcopy(self.baseline)
                changed["native"]["materials"][material]["maximum_write_radius"] = radius
                self.bad(changed, pointers=(f"/native/materials/{material}/maximum_write_radius",
                                            f"/native/materials/{material}/kernel"))
        changed = copy.deepcopy(self.baseline)
        changed["native"]["materials"][2]["state_contract"] = {"state_c": 1}
        self.bad(changed, pointers=("/native/materials/2/state_contract",))

    def test_invalid_ten_is_not_reclaimed_and_existing_ids_are_immutable(self):
        for field, value in (("valid", True), ("movable", True), ("current_rule_available", True)):
            with self.subTest(field=field):
                changed = copy.deepcopy(self.baseline)
                changed["native"]["materials"][10][field] = value
                self.bad(changed, pointers=("/native/materials/10",))
        changed = copy.deepcopy(self.baseline)
        changed["native"]["identity"]["reserved_ids"] = []
        self.bad(changed, pointers=("/native/identity/reserved_ids",))
        changed = copy.deepcopy(self.baseline)
        changed["native"]["materials"][2]["name"] = "new-concrete"
        self.bad(changed, pointers=("/native/materials/2/name",))
        changed = copy.deepcopy(self.baseline)
        changed["native"]["identity"]["allocated_slots"] = 257
        self.bad(changed, pointers=("/native/identity/allocated_slots",))

    def test_duplicate_material_identity_reports_both_conflicting_records(self):
        changed = copy.deepcopy(self.baseline)
        changed["native"]["materials"][1] = copy.deepcopy(changed["native"]["materials"][0])
        message = self.bad(changed, pointers=("/native/materials/0", "/native/materials/1"))
        self.assertGreaterEqual(message.count(self.source.name), 2)

    def test_aliases_preserve_gas_identity_and_cannot_create_graphs_or_collisions(self):
        alias = self.baseline["native"]["identity"]["aliases"]
        self.assertEqual(alias, [{"namespace": "native_enum", "name": "Gas", "target": 4}])
        for target in (10, 256, True, "Gas", "Smoke"):
            with self.subTest(target=target):
                changed = copy.deepcopy(self.baseline)
                changed["native"]["identity"]["aliases"][0]["target"] = target
                self.bad(changed, pointers=("/native/identity/aliases/0/target",))
        changed = copy.deepcopy(self.baseline)
        changed["native"]["identity"]["aliases"][0]["name"] = "Sand"
        self.bad(changed, pointers=("/native/identity/aliases/0/name",))
        changed = copy.deepcopy(self.baseline)
        changed["native"]["identity"]["aliases"].append(copy.deepcopy(alias[0]))
        self.bad(changed, pointers=("/native/identity/aliases",))

    def test_unknown_nested_fields_cannot_enable_implicit_physics_inheritance(self):
        for section, field, value in (("materials", "category", "metal"),
                                      ("materials", "inherits", "water"),
                                      ("capabilities", "hard_by_range", True)):
            changed = copy.deepcopy(self.baseline)
            changed["native"][section][0][field] = value
            self.bad(changed, pointers=(f"/native/{section}/0/{field}",))
        changed = copy.deepcopy(self.baseline)
        changed["native"]["interactions"]["families"][0]["defaults"] = {"density": 7800}
        self.bad(changed, pointers=("/native/interactions/families/0/defaults",))
        changed = copy.deepcopy(self.baseline)
        changed["behaviour_presets"] = [{"family": "metal", "kernel": "Metal"}]
        self.bad(changed, pointers=("/behaviour_presets",))

    def test_overlapping_family_membership_has_no_descriptor_or_capability_inheritance(self):
        changed = copy.deepcopy(self.baseline)
        memberships = changed["native"]["interactions"]["memberships"]
        wood_family = next(row["family_id"] for row in memberships if row["material"] == 7)
        other = next(row for row in memberships if row["family_id"] != wood_family
                     and not any(m["family_id"] == row["family_id"] and m["material"] == 7 for m in memberships))
        other["material"] = 7
        accepted = compiler.load_catalogue(self.write(changed))
        memberships_after = accepted["native"]["interactions"]["memberships"]
        self.assertGreaterEqual(len({row["family_id"] for row in memberships_after if row["material"] == 7}), 2)
        self.assertEqual(accepted["native"]["materials"], self.baseline["native"]["materials"])
        self.assertEqual(accepted["native"]["capabilities"], self.baseline["native"]["capabilities"])

    def test_duplicate_membership_and_missing_family_reference_are_rejected(self):
        changed = copy.deepcopy(self.baseline)
        members = changed["native"]["interactions"]["memberships"]
        members[1] = copy.deepcopy(members[0])
        self.bad(changed, pointers=("/native/interactions/memberships/0", "/native/interactions/memberships/1"))
        changed = copy.deepcopy(self.baseline)
        changed["native"]["interactions"]["memberships"][0]["family_id"] = "int.family.missing"
        self.bad(changed, pointers=("/native/interactions/memberships/0/family_id",))

    def test_active_generic_layers_are_rejected_instead_of_silently_ignored(self):
        for layer in ({}, {"id": "new-layer", "precedence": 200, "defaults": {"density": 0}}):
            changed = copy.deepcopy(self.baseline)
            changed["native"]["interactions"]["layers"] = [layer]
            self.bad(changed, pointers=("/native/interactions/layers",))

    def test_duplicate_legacy_slots_report_both_origins_for_pairs_and_specialized_records(self):
        for table in ("pairs", "specialized"):
            changed = copy.deepcopy(self.baseline)
            rows = changed["native"]["interactions"][table]
            rows[1]["legacy_slot"] = rows[0]["legacy_slot"]
            self.bad(changed, pointers=(f"/native/interactions/{table}/0", f"/native/interactions/{table}/1"))

    def test_duplicate_rule_names_do_not_depend_on_array_order(self):
        for table in ("pairs", "specialized"):
            changed = copy.deepcopy(self.baseline)
            rows = changed["native"]["interactions"][table]
            rows[1]["id"] = rows[0]["id"]
            self.bad(changed, pointers=(f"/native/interactions/{table}/0", f"/native/interactions/{table}/1"))

    def test_finite_pair_intersection_detects_reversed_ordered_vs_unordered_conflict(self):
        changed = copy.deepcopy(self.baseline)
        first, second = changed["native"]["interactions"]["pairs"][:2]
        self.assertNotEqual(first["id"], second["id"])
        first["match"] = 1  # UnorderedRolePreserving: both endpoint orientations.
        second.update(first=first["second"], second=first["first"], match=0)
        self.bad(changed, pointers=("/native/interactions/pairs/0", "/native/interactions/pairs/1"))

    def test_pair_inputs_and_probability_remain_exact_byte_contracts(self):
        for field, values in (("probability", (-1, 256, False, 1.0)),
                              ("match", (-1, 3, True)),
                              ("trigger", (1, 3, False)),
                              ("channels", (0, 128, True)),
                              ("first", (10, 256, True)),
                              ("second_product", (10, 255, 1.0)),
                              ("legacy_slot", (-1, 56, True))):
            for value in values:
                with self.subTest(field=field, value=value):
                    changed = copy.deepcopy(self.baseline)
                    changed["native"]["interactions"]["pairs"][0][field] = value
                    self.bad(changed, pointers=(f"/native/interactions/pairs/0/{field}",))
        # Zero is still a supported stored roll threshold, not an "off" value.
        changed = copy.deepcopy(self.baseline)
        changed["native"]["interactions"]["pairs"][0]["probability"] = 0
        accepted = compiler.load_catalogue(self.write(changed))
        self.assertEqual(accepted["native"]["interactions"]["pairs"][0]["probability"], 0)

    def test_new_supersession_does_not_bypass_conflict_validation(self):
        changed = copy.deepcopy(self.baseline)
        pairs = changed["native"]["interactions"]["pairs"]
        pairs[1]["supersedes"] = pairs[0]["id"]
        self.bad(changed, pointers=("/native/interactions/pairs/1/supersedes",))

    def test_inert_participants_remain_valid_targets(self):
        accepted = compiler.load_catalogue(SOURCE)
        materials = {row["id"]: row for row in accepted["native"]["materials"]}
        participants = {row[field] for row in accepted["native"]["interactions"]["pairs"]
                        for field in ("first", "second")}
        inert = {i for i in participants if materials[i]["kernel"] == 0}
        self.assertEqual(len(inert), 26)
        self.assertTrue(all(materials[i]["valid"] for i in inert))

    def test_permuting_authored_record_arrays_preserves_all_generated_bytes(self):
        original = compiler.render_outputs(compiler.load_catalogue(SOURCE))
        changed = copy.deepcopy(self.baseline)
        native = changed["native"]
        for name in ("materials", "capabilities", "appearance"):
            native[name].reverse()
        for name in ("channels", "layer_kinds", "pairs", "specialized", "families",
                     "memberships", "coverage", "tuning_passes"):
            native["interactions"][name].reverse()
        rendered = compiler.render_outputs(compiler.load_catalogue(self.write(changed)))
        self.assertEqual(rendered, original)

    def test_late_validation_failure_keeps_the_entire_previous_output_set(self):
        self.write()
        compiler.compile_catalogue(self.source, self.output)
        before = tree_state(self.output)
        changed = copy.deepcopy(self.baseline)
        changed["native"]["interactions"]["layers"] = [{"id": "must-not-publish"}]
        self.write(changed)
        with self.assertRaises(compiler.CatalogueError):
            compiler.compile_catalogue(self.source, self.output)
        self.assertEqual(tree_state(self.output), before)

    def test_synthetic132_requires_explicit_namespace_and_isolation_flag(self):
        changed = self.isolated_fixture()
        self.bad(changed)  # Namespace alone cannot opt a caller into a new registry.
        changed["scope"] = "current-shadow"
        self.bad(changed, isolated=True, pointers=("/scope",))

    def test_isolated132_is_an_explicit_nonhard_powder_and_not_stonewall(self):
        changed = self.isolated_fixture()
        accepted = compiler.load_catalogue(self.write(changed), isolated=True)
        material = next(r for r in accepted["native"]["materials"] if r["id"] == 132)
        capability = next(r for r in accepted["native"]["capabilities"] if r["id"] == 132)
        self.assertEqual((material["name"], material["state"], material["kernel"]), ("synthetic-powder", 2, 1))
        self.assertFalse(capability["hard_surface"])
        compiler.compile_catalogue(self.source, self.output, isolated=True)
        self.assertTrue(self.output.is_dir())
        for name in ("stone-wall", "StoneWall", "salt-wall", "dry-binder"):
            with self.subTest(experimental_identity=name):
                changed = self.isolated_fixture()
                changed["native"]["materials"][132]["name"] = name
                self.bad(changed, isolated=True, pointers=("/native/materials/132/name",))

    def test_synthetic132_cannot_inherit_hard_surface_from_id_range(self):
        changed = self.isolated_fixture()
        changed["native"]["capabilities"][132]["hard_surface"] = True
        self.bad(changed, isolated=True, pointers=("/native/capabilities/132/hard_surface",))

    def test_synthetic_output_cannot_write_inside_repository_even_through_parent_link(self):
        self.write(self.isolated_fixture())
        production = ROOT / "materials/catalogue/generated"
        before = tree_state(production)
        with self.assertRaises(compiler.CatalogueError):
            compiler.compile_catalogue(self.source, production, isolated=True)
        self.assertEqual(tree_state(production), before)
        if hasattr(os, "symlink"):
            link = self.directory / "repository-link"
            try:
                link.symlink_to(ROOT, target_is_directory=True)
            except OSError:
                return  # Windows may require a symlink privilege unavailable in CI.
            with self.assertRaises(compiler.CatalogueError):
                compiler.compile_catalogue(self.source, link / "materials/catalogue/generated", isolated=True)
            self.assertEqual(tree_state(production), before)

    def test_ordinary_compiler_cannot_target_production_native_or_godot_directories(self):
        self.write()
        for output in (ROOT / "native/include/cybersand", ROOT / "godot/scripts"):
            with self.subTest(output=output):
                with self.assertRaises(compiler.CatalogueError) as caught:
                    compiler.compile_catalogue(self.source, output)
                self.assertIn("production", str(caught.exception).lower())

    def test_shadow_metadata_keeps_native_slush_and_leaves_separate_fallback_value(self):
        accepted = compiler.load_catalogue(SOURCE)
        material = next(r for r in accepted["native"]["materials"] if r["id"] == 21)
        self.assertEqual(material["density"], 1080)
        lock = json.loads((ROOT / "materials/catalogue/compatibility-lock.json").read_text())
        self.assertEqual(lock["fallback_source_facts"]["density_by_byte_id"][21], 1100)
        # Two native metadata consumers must not silently substitute fallback physics.
        rendered = compiler.render_outputs(accepted)
        inspection = json.loads(rendered["inspection.json"])
        material = next(r for r in inspection["native"]["materials"] if r["id"] == 21)
        self.assertEqual(material["density"], 1080)
        self.assertEqual(inspection["backend"], "native")
        self.assertEqual(inspection["authority"], "shadow-only")
        self.assertIsNone(inspection["production_consumer"])
        gdscript = rendered["catalogue_shadow.gd"].decode("utf-8")
        self.assertIn('const BACKEND: String = "native"', gdscript)
        self.assertIn("const PRODUCTION_AUTHORITY: bool = false", gdscript)
        gd_facts = json.loads(gdscript.split("const NATIVE_FACTS: Dictionary = ", 1)[1])
        self.assertEqual(gd_facts, accepted["native"])
        self.assertEqual(gd_facts["materials"][21]["density"], 1080)

    def test_nested_duplicate_keys_and_nonfinite_tokens_report_full_json_pointer(self):
        raw = json.dumps(self.baseline)
        for replacement in ('"density": 1600, "density": 0',
                            '"density": NaN', '"density": 1e309'):
            with self.subTest(replacement=replacement):
                changed = raw.replace('"density": 1600', replacement, 1)
                self.assertNotEqual(changed, raw)
                self.bad(raw=changed, pointers=("/native/materials/2/density",))

    def test_invalid_utf8_text_contract_fails_before_rendering(self):
        raw = json.dumps(self.baseline)
        for replacement in ('"name": "\\ud800"', '"name": "sa\\u0000nd"'):
            with self.subTest(replacement=replacement):
                changed = raw.replace('"name": "sand"', replacement, 1)
                self.bad(raw=changed, pointers=("/native/materials/2/name",))

    def test_scope_and_schema_identifier_cannot_silently_change_compatibility_mode(self):
        for field, value in (("schema_id", "cybersand.material-catalogue.production"),
                              ("scope", "production"), ("scope", True)):
            with self.subTest(field=field, value=value):
                changed = copy.deepcopy(self.baseline)
                changed[field] = value
                self.bad(changed, pointers=(f"/{field}",))

    def test_duplicate_explicit_capability_and_appearance_slots_report_both_origins(self):
        for table in ("capabilities", "appearance"):
            with self.subTest(table=table):
                changed = copy.deepcopy(self.baseline)
                changed["native"][table][1] = copy.deepcopy(changed["native"][table][0])
                self.bad(changed, pointers=(f"/native/{table}/0", f"/native/{table}/1"))

    def test_experimental_ids133_through137_are_not_admitted_by_isolation_flag(self):
        for material_id in range(133, 138):
            with self.subTest(material_id=material_id):
                changed = self.isolated_fixture()
                changed["native"]["materials"][132]["id"] = material_id
                self.bad(changed, isolated=True, pointers=("/native/materials/132/id",))

if __name__ == "__main__":
    unittest.main()
