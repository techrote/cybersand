"""Challenge new admission while freezing every original correctness predicate."""
from __future__ import annotations

import ast
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def nested_invoke(path):
    tree = ast.parse(path.read_text())
    return next(node for node in ast.walk(tree) if isinstance(node, ast.FunctionDef) and node.name == "invoke")


class FrozenPredicates(unittest.TestCase):
    def test_every_original_invocation_gate_is_preserved(self):
        old = nested_invoke(ROOT / "tools/pubpres_final/run_qualification.py")
        new = nested_invoke(HERE / "run_qualification.py")

        class RemoveOnlyAdditions(ast.NodeTransformer):
            import_substitutions = 0

            def visit_IfExp(self, node):
                # A local runtime template cannot import editor assets. Only
                # the exact import command may use the independently pinned
                # stock editor; every actual test still uses its admitted
                # runtime. Normalize this one expression, never an arbitrary
                # command or runtime-engine change.
                expected = ast.parse('import_engine if test == "import" else engine', mode="eval").body
                if ast.dump(node) == ast.dump(expected):
                    self.import_substitutions += 1
                    return ast.Name(id="engine", ctx=ast.Load())
                return self.generic_visit(node)

            def visit_If(self, node):
                if isinstance(node.test, ast.Compare) and ast.dump(node.test) == ast.dump(ast.parse("test in SUPPLEMENTAL", mode="eval").body):
                    # New dispatch branch has the complete original oracle
                    # chain as its else. Policy/output additions have no else.
                    return [self.visit(item) for item in node.orelse]
                if isinstance(node.test, ast.BoolOp) and ast.unparse(node.test).startswith("test in SUPPLEMENTAL and "):
                    return None
                return self.generic_visit(node)

            def visit_Attribute(self, node):
                if ast.unparse(node) == "args.render_thread":
                    return ast.Constant("safe")
                return self.generic_visit(node)

        normalizer = RemoveOnlyAdditions()
        normalized = normalizer.visit(copy.deepcopy(new))
        self.assertEqual(normalizer.import_substitutions, 1)
        self.assertEqual(ast.dump(old, include_attributes=False), ast.dump(normalized, include_attributes=False))

    def test_frozen_headless_and_graphical_inventory_remains_present(self):
        supplemental = {"test_workbench_presentation_submission", "test_workbench_water_composition",
                        "test_workbench_water_composition_native", "test_workbench_presentation_history",
                        "test_workbench_presentation_member_history", "test_workbench_member_presentation"}
        def inventories(path):
            tree = ast.parse(path.read_text())
            calls = [node for node in ast.walk(tree) if isinstance(node, ast.Call)
                     and isinstance(node.func, ast.Name) and node.func.id == "invoke"]
            frozen = {ast.dump(node, include_attributes=False) for node in calls
                    if not node.args or not isinstance(node.args[0], ast.Constant)
                    or node.args[0].value not in supplemental}
            added = {node.args[0].value for node in calls if node.args and isinstance(node.args[0], ast.Constant)
                     and node.args[0].value in supplemental}
            return frozen, added
        original, original_added = inventories(ROOT / "tools/pubpres_final/run_qualification.py")
        resulting, resulting_added = inventories(HERE / "run_qualification.py")
        self.assertEqual(original, resulting)
        self.assertEqual(original_added, set())
        self.assertEqual(resulting_added, supplemental)


class JournalOnlyIsNotAtomic(unittest.TestCase):
    def test_old_green_journal_fixture_cannot_grant_qualification(self):
        # Import by path to avoid accidentally testing the original same-named
        # runner, which intentionally does not know the new architecture.
        import importlib.util
        spec = importlib.util.spec_from_file_location("recovery_correctness_test", HERE / "run_qualification.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            project, folder = root / "project", root / "evidence"
            (project / "tests").mkdir(parents=True)
            folder.mkdir()
            name = "test_workbench_presentation_submission"
            program = project / "tests" / (name + ".gd")
            program.write_text("# source-bound development fixture\n")
            # Reach the actual atomic-admission predicate even when additive
            # resulting-source adversaries raise the required assertion count.
            # This synthetic claim is never accepted as graphical evidence.
            checks = module.SUPPLEMENTAL[name]["minimum_checks"]
            data = {"schema": "workbench-actual-submission-graphical-v1", "checks": checks, "failures": [],
                    "source_revision": "a" * 40, "display": "Windows", "input_hashes": {
                        "res://tests/" + name + ".gd": hashlib.sha256(program.read_bytes()).hexdigest()}}
            (folder / "receipt.json").write_text(json.dumps(data))
            with self.assertRaisesRegex(ValueError, "Journal-only"):
                module.supplemental_result(name, 'ACTUAL_SUBMISSION_RESULT '+json.dumps({"checks":checks,"failures":[]}),
                                           folder, {"source_commit": "a" * 40}, project)

    def test_held_part_must_follow_displayed_contact_and_retire_original_owner(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("recovery_held_place", HERE / "run_qualification.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        row = {"part_index": 4, "local_contact": [1.125, 0.25], "accepted_contact": [10, 20],
               "live_contact_before_press": [22, 11], "preview_contact": [10, 20],
               "release_target": [27.25, 13.25], "dragged_contact": [27.25, 13.25],
               "installed_contact": [27.25, 13.25], "limb_rotations": [0.0, 0.47, 0.47],
               "epochs": [1, 2], "generation_refusal": True, "submitted_serial": -1,
               "unchanged_framebuffer_sha256": "a"*64}
        inputs = {"res://scripts/" + name + ".gd": "b"*64 for name in ("main", "shared_workbench", "physical_actor_session",
                  "physical_actor_rig", "workbench_presentation_submission", "workbench_actor_interaction", "workbench_actor_manipulator")}
        module.held_placement({"held_limb_placement": row, "input_hashes": inputs}, False)
        for field, changed in (("preview_contact", [22, 11]), ("installed_contact", [27.25, 13]),
                               ("epochs", [1, 1]), ("generation_refusal", False), ("submitted_serial", 5)):
            with self.subTest(field=field), self.assertRaises(ValueError):
                module.held_placement({"held_limb_placement": {**row, field: changed}, "input_hashes": inputs}, False)


if __name__ == "__main__":
    unittest.main()
