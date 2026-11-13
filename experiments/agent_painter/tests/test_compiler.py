from copy import deepcopy
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from compiler import (CompilerError, canonical_json, compile_program, digest, parse_program,
                      rasterize_operations, structural_signature, validate_program, verify_structure)
from recipes import SEEDS, all_recipes


class CompilerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipes = all_recipes()
        cls.cases = [(r, compile_program(r["program"], seed=s)) for r in cls.recipes for s in SEEDS]

    def test_every_pilot_has_exact_bounded_native_geometry(self):
        for recipe, c in self.cases:
            with self.subTest(recipe=recipe["group_id"], seed=c["seed"]):
                ids = rasterize_operations(c["operations"], c["focus"])
                self.assertEqual(sum(v == c["material"] for v in ids), c["estimated_cell_work"])
                self.assertLessEqual(len(c["operations"]), 512)
                self.assertEqual(c["operations_sha256"], digest(c["operations"]))
                self.assertEqual(c["program_sha256"], digest(recipe["program"]))
                self.assertTrue(verify_structure(c, ids)["passed"])
                self.assertFalse(c["native_qualified"])
                self.assertTrue(c["proposal_only"])
                for op in c["operations"]:
                    self.assertEqual(op["shape"], "rectangle")
                    self.assertEqual(op["material"], 58)

    def test_host_seeds_replay_exactly_without_creating_new_designs(self):
        for r in self.recipes:
            a = compile_program(r["program"], seed=SEEDS[0])
            b = compile_program(r["program"], seed=SEEDS[0])
            c = compile_program(r["program"], seed=SEEDS[1])
            self.assertEqual(a, b)
            self.assertEqual(a["program_sha256"], c["program_sha256"])
            self.assertNotEqual(a["operations_sha256"], c["operations_sha256"], r["group_id"])

    def test_focus_translation_and_scaling_are_host_owned(self):
        for r in self.recipes:
            for focus in ((109, 47, 96, 96), (0, 0, 192, 192), (13, 9, 128, 192)):
                with self.subTest(group=r["group_id"], focus=focus):
                    c = compile_program(r["program"], seed=SEEDS[0], focus=focus)
                    self.assertTrue(verify_structure(c, rasterize_operations(c["operations"], focus))["passed"])

    def test_byte_complete_strict_json_and_integer_types(self):
        program = self.recipes[0]["program"]
        raw = canonical_json(program)
        self.assertEqual(parse_program(raw), program)
        for bad in (raw[:-1], raw+" {}", "```json\n"+raw+"\n```", raw.replace('"version":2', '"version":2,"version":2'),
                    raw.replace('"variation":2', '"variation":NaN'), raw.replace('"variation":2', '"variation":2.0')):
            with self.subTest(bad=bad[:60]), self.assertRaises(CompilerError):
                parse_program(bad)
        for value in (True, 2.0, -1, 3):
            p = deepcopy(program); p["variation"] = value
            with self.assertRaises(CompilerError):
                validate_program(p)

    def test_model_cannot_supply_host_authority(self):
        for key, value in (("seed", 1), ("material", 58), ("focus", [0, 0, 96, 96]), ("allow_protected", True)):
            p = deepcopy(self.recipes[0]["program"]); p[key] = value
            with self.assertRaises(CompilerError):
                compile_program(p, seed=1)
        with self.assertRaisesRegex(CompilerError, "authorized"):
            compile_program(self.recipes[0]["program"], seed=1, material=59)
        with self.assertRaises(CompilerError):
            compile_program(self.recipes[0]["program"], seed=True)
        with self.assertRaises(CompilerError):
            compile_program(self.recipes[0]["program"], seed=1, focus=(0, 0, 513, 96))

    def test_capacity_refuses_before_any_partial_plan(self):
        for kwargs in ({"max_operations": 1}, {"max_cell_work": 10}, {"material": 0}, {"max_cell_work": 2**30}):
            with self.assertRaises(CompilerError):
                compile_program(self.recipes[0]["program"], seed=1, **kwargs)

    def test_new_compositions_are_not_fixed_template_dispatch(self):
        p = deepcopy(self.recipes[0]["program"])
        p["components"] = p["components"][:2]
        p["components"][0]["density"] = 1
        p["components"][1]["detail"] = "plates"
        p["variation"] = 0
        c = compile_program(p, seed=123)
        self.assertEqual(c["structural_preflight"]["metrics"]["panel_count"], 2)
        graph = {"version": 2, "family": "pipework", "variation": 0,
                 "components": [{"kind": "pipe_network", "nodes": [[16, 32], [48, 32], [80, 32], [48, 64]],
                                 "edges": [[0, 1], [1, 2], [1, 3]], "diameter": 7, "fittings": False}],
                 "requirements": {"connected": True, "cycles": 0}}
        d = compile_program(graph, seed=456)
        self.assertTrue(verify_structure(d, rasterize_operations(d["operations"]))["passed"])

    def test_pipe_gap_fails_actual_readback_connectivity_and_centerline(self):
        c = next(c for r, c in self.cases if r["design"] == "two_elbow_route")
        ids = rasterize_operations(c["operations"])
        p = c["semantic"]["diameter_probes"][0]
        x, y = p["at"]
        for dy in range(-8, 9):
            ids[(y+dy)*96+x] = 0
        result = verify_structure(c, ids)
        self.assertFalse(result["passed"])
        self.assertIn("native pipes are disconnected", result["errors"])
        self.assertIn("native pipe centerline has a gap", result["errors"])

    def test_pipe_diameter_and_unintended_loop_are_independent_checks(self):
        c = next(c for r, c in self.cases if r["design"] == "tee_distribution")
        ids = rasterize_operations(c["operations"])
        p = c["semantic"]["diameter_probes"][0]; x, y = p["at"]
        r = p["diameter"]//2
        ids[(y+r+1)*96+x] = 58
        result = verify_structure(c, ids)
        self.assertFalse(result["passed"])
        self.assertIn("native pipe diameter/clearance mismatch", result["errors"])
        loop = next(c for r, c in self.cases if r["design"] == "closed_loop_with_tap")
        ids = rasterize_operations(loop["operations"])
        # Filling the loop hole retains a connected graph but violates topology.
        nodes = loop["semantic"]["nodes"]
        for yy in range(nodes[0][1]+2, nodes[2][1]-1):
            for xx in range(nodes[0][0]+2, nodes[2][0]-1):
                ids[yy*96+xx] = 58
        result = verify_structure(loop, ids)
        self.assertFalse(result["passed"])
        self.assertIn("native pipe enclosed-loop count differs from graph", result["errors"])

    def test_pipe_implicit_crossing_disconnection_and_diameter_refuse(self):
        p = deepcopy(next(r["program"] for r in self.recipes if r["design"] == "tee_distribution"))
        p["components"][0]["nodes"] = [[12, 48], [84, 48], [48, 14], [48, 80]]
        p["components"][0]["edges"] = [[0, 1], [2, 3]]
        with self.assertRaises(CompilerError):
            compile_program(p, seed=1)
        p["components"][0]["edges"].append([0, 2])
        with self.assertRaises(CompilerError):
            compile_program(p, seed=1)
        p = deepcopy(next(r["program"] for r in self.recipes if r["design"] == "tee_distribution"))
        p["components"][0]["diameter"] = 4
        with self.assertRaises(CompilerError):
            compile_program(p, seed=1)

    def test_architecture_door_obstruction_blocks_native_clearance_route(self):
        c = next(c for r, c in self.cases if r["design"] == "paired_doorway_rooms")
        ids = rasterize_operations(c["operations"])
        x, y, w, h = c["semantic"]["openings"][0]
        for py in range(y, y+h):
            for px in range(x, x+w):
                ids[py*96+px] = 58
        result = verify_structure(c, ids)
        self.assertFalse(result["passed"])
        self.assertIn("native architecture opening is obstructed", result["errors"])
        self.assertIn("native architecture route lacks requested square clearance", result["errors"])

    def test_architecture_hairline_opening_is_not_actor_clearance(self):
        c = next(c for r, c in self.cases if r["design"] == "paired_doorway_rooms")
        ids = rasterize_operations(c["operations"])
        x, y, w, h = c["semantic"]["openings"][0]
        for py in range(y, y+h):
            if py == y+h//2:
                continue
            for px in range(x, x+w):
                ids[py*96+px] = 58
        self.assertFalse(verify_structure(c, ids)["metrics"]["clearance_route_passed"])

    def test_greeble_border_fastener_and_negative_space_checks_use_cells(self):
        c = self.cases[0][1]
        ids = rasterize_operations(c["operations"])
        x, y = c["semantic"]["panels"][0]["fasteners"][0]
        ids[y*96+x] = 0
        result = verify_structure(c, ids)
        self.assertIn("missing native fastener", result["errors"])
        self.assertFalse(verify_structure(c, [58]*9216)["passed"])

    def test_structural_signatures_ignore_style_and_graph_node_order(self):
        for r in self.recipes:
            p = deepcopy(r["program"]); p["variation"] = 0
            if p["family"] == "greebles":
                for c in p["components"]:
                    c["density"] = 1
            elif p["family"] == "pipework":
                p["components"][0]["diameter"] = 3
            else:
                p["requirements"]["clearance"] = 3
            self.assertEqual(structural_signature(p), structural_signature(r["program"]))
        p = deepcopy(next(r["program"] for r in self.recipes if r["design"] == "tee_distribution"))
        original = structural_signature(p); c = p["components"][0]
        c["nodes"] = list(reversed(c["nodes"]))
        c["edges"] = [[len(c["nodes"])-1-a, len(c["nodes"])-1-b] for a, b in reversed(c["edges"])]
        self.assertEqual(original, structural_signature(p))

    def test_schema_validates_all_reference_programs(self):
        import jsonschema
        schema = json.loads((Path(__file__).resolve().parents[1]/"program.schema.json").read_text())
        jsonschema.Draft202012Validator.check_schema(schema)
        validator = jsonschema.Draft202012Validator(schema)
        for recipe in self.recipes:
            validator.validate(recipe["program"])


if __name__ == "__main__":
    unittest.main()
