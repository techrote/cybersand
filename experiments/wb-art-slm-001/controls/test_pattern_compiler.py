"""Host-boundary and metamorphic checks; these do not claim native execution."""
import copy
import hashlib
import json
import math
import subprocess
import sys
import unittest
from pathlib import Path

import pattern_compiler as p


def bounds(operation):
    shape=operation["shape"]
    if shape=="disc":
        x,y,r=operation["x"],operation["y"],operation["radius"]
        return x-r,y-r,x+r,y+r
    points=operation.get("points") or [[operation["x0"],operation["y0"]],[operation["x1"],operation["y1"]]]
    radius=math.ceil(operation.get("width",1)/2) if operation.get("width",1)>1 else 0
    return min(q[0] for q in points)-radius,min(q[1] for q in points)-radius,max(q[0] for q in points)+radius,max(q[1] for q in points)+radius


class PatternCompilerTests(unittest.TestCase):
    def test_every_theme_template_and_supported_pilot_aspect_is_bounded(self):
        for theme in p.THEMES:
            for variant in range(8):
                for width,height in [(64,64),(96,96),(128,128),(64,128),(128,64)]:
                    with self.subTest(theme=theme,variant=variant,size=(width,height)):
                        result=p.compile_with_report(p.make_program(theme,variant),width,height,17)
                        self.assertGreater(result["operation_count"],0)
                        self.assertLessEqual(result["operation_count"],2048)
                        self.assertLessEqual(result["estimated_cell_work"],131072)
                        for op in result["operations"]:
                            x0,y0,x1,y1=bounds(op)
                            self.assertTrue(0<=x0<=x1<width and 0<=y0<=y1<height,op)
                            self.assertEqual(op["material"],58)
                            for key in ("x","y","radius","width","x0","y0","x1","y1"):
                                if key in op:self.assertIs(type(op[key]),int)
                            for q in op.get("points",[]):
                                self.assertTrue(all(type(v) is int for v in q))

    def test_all_templates_are_explicit_and_modifiers_cannot_leak_split_identity(self):
        groups={p.structural_signature(p.make_program(t,v)) for t in p.THEMES for v in range(8)}
        self.assertEqual(len(groups),96)
        a=p.make_program("roots",0,["open"])
        b=p.make_program("roots",3)
        self.assertEqual(p.structural_signature(a),p.structural_signature(b))
        # The caller must group by the effective structure, not the nominal ID.
        self.assertEqual(a,b)

    def test_seed_replay_survives_process_restart(self):
        program=p.make_program("roots",5,["twisted"])
        expected=p.canonical_json(p.compile_program(program,96,128,12345))
        code="import json,pattern_compiler as p;print(p.canonical_json(p.compile_program(json.loads("+repr(json.dumps(program))+"),96,128,12345)))"
        actual=subprocess.check_output([sys.executable,"-c",code],cwd=Path(__file__).parent,text=True).strip()
        self.assertEqual(expected,actual)

    def test_seed_changes_each_family_without_mutating_program(self):
        for theme in p.THEMES:
            program=p.make_program(theme);before=copy.deepcopy(program)
            hashes={hashlib.sha256(p.canonical_json(p.compile_program(program,96,96,s)).encode()).hexdigest() for s in range(8)}
            self.assertGreaterEqual(len(hashes),6,theme)
            self.assertEqual(program,before)

    def test_open_layout_preserves_a_large_central_void(self):
        for theme in p.THEMES:
            for variant in (0,4):
                operations=p.compile_program(p.make_program(theme,variant,["open"]),96,96,29)
                for op in operations:
                    x0,y0,x1,y1=bounds(op)
                    self.assertTrue(x1<25 or x0>71 or y1<25 or y0>71,(theme,op))

    def test_symmetric_modifier_reflects_every_operation_including_companions(self):
        for theme in p.THEMES:
            ops=p.compile_program(p.make_program(theme,4,["symmetric"]),96,96,29)
            unique={p.canonical_json(x) for x in ops}
            for op in ops:
                self.assertIn(p.canonical_json(p.reflected_operation(op,96)),unique)

    def test_density_has_a_directional_effect_for_all_families(self):
        # This measures primitive count across seeds, not artistic quality.
        for theme in p.THEMES:
            totals={modifier:sum(len(p.compile_program(p.make_program(theme,0,[modifier]),96,96,seed)) for seed in range(8)) for modifier in ("sparse","dense")}
            self.assertGreater(totals["dense"],totals["sparse"],(theme,totals))

    def test_shape_and_cell_work_limits_refuse_before_returning_any_plan(self):
        program=p.make_program("roots",0,["dense"])
        with self.assertRaises(p.CompilerError):p.compile_program(program,96,96,1,max_shapes=1)
        with self.assertRaises(p.CompilerError):p.compile_program(program,96,96,1,max_estimated_cells=1)
        # Refusal must not leave global mutable state that changes a subsequent run.
        self.assertEqual(p.compile_program(program,96,96,1),p.compile_program(program,96,96,1))

    def test_material_scope_is_host_owned_and_restricted(self):
        program=p.make_program("ribs")
        for material in (0,58):
            self.assertEqual({x["material"] for x in p.compile_program(program,64,64,1,material)}, {material})
        for material in (True,1,2,59,58.0,"58",None):
            with self.subTest(material=material),self.assertRaises(p.CompilerError):p.compile_program(program,64,64,1,material)
        modified=copy.deepcopy(program);modified["material"]=58
        with self.assertRaises(p.CompilerError):p.validate_program(modified)

    def test_adversarial_program_fields_raise_typed_refusal(self):
        invalid=[None,[],{},True,{"version":1,"theme":[],"layers":[]}]
        good=p.make_program("strata")
        for key,value in [("version",True),("version",2),("theme",[]),("theme",{}),("layers",{}),("layers",[]),("layers",good["layers"]*5)]:
            candidate=copy.deepcopy(good);candidate[key]=value;invalid.append(candidate)
        for key,value in [("motif",[]),("motif",{}),("layout",[]),("density",float("nan")),("scale",float("inf")),("width",True),("angle",10**1000),("density",-0.1),("scale",1.01)]:
            candidate=copy.deepcopy(good);candidate["layers"][0][key]=value;invalid.append(candidate)
        candidate=copy.deepcopy(good);candidate["layers"][0]["code"]="print('untrusted')";invalid.append(candidate)
        for candidate in invalid:
            with self.subTest(candidate=str(candidate)[:120]),self.assertRaises(p.CompilerError):p.validate_program(candidate)

    def test_invalid_host_parameters_raise_typed_refusal(self):
        program=p.make_program("roots")
        for width,height,seed in [(15,64,1),(513,64,1),(64,True,1),(64,64,-1),(64,64,2**63),(64,64,1.0),(64,64,[])]:
            with self.subTest(values=(width,height,seed)),self.assertRaises(p.CompilerError):p.compile_program(program,width,height,seed)

    def test_unknown_and_conflicting_modifiers_refuse(self):
        for modifiers in (["sparse","dense"],["thick","thin"],["open","open"],["dragon"],"dense",[{}]):
            with self.subTest(modifiers=modifiers),self.assertRaises(p.CompilerError):p.make_program("roots",0,modifiers)


if __name__=="__main__":unittest.main()
