"""Compiler-only v1.2 rooted-coral controls; not native World qualification."""
from collections import Counter
import hashlib
import json
from pathlib import Path
import unittest
import pattern_compiler as c0
import pattern_compiler_v11 as c1
import pattern_compiler_v12 as c2


def sig(op): return c0.canonical_json(op)


class RootedCoralCandidateTests(unittest.TestCase):
    def test_version_parent_and_isolation(self):
        self.assertEqual(hashlib.sha256(Path(c0.__file__).read_bytes()).hexdigest(), c2.BASE_COMPILER_SHA256)
        self.assertNotEqual(c2.COMPILER_VERSION, c1.COMPILER_VERSION)
        self.assertIsNot(c0._DRAW,c2._v1._DRAW)
        self.assertIsNot(c1._v1._DRAW,c2._v1._DRAW)
        self.assertIsNot(c0._DRAW['fan'],c2._v1._DRAW['fan'])

    def test_frozen_noncoral_no_change(self):
        for theme in c0.THEMES:
            if theme == 'coral': continue
            for variant in range(8):
                p=c0.make_program(theme,variant)
                for seed in (17,73):
                    self.assertEqual(c0.compile_program(p,96,96,seed), c2.compile_program(p,96,96,seed),(theme,variant,seed))

    def test_all_spread_fan_geometry_retained_plus_connectors(self):
        for variant in range(8):
            p=c0.make_program('coral',variant)
            for seed in (17,73):
                before=c1.compile_program(p,96,96,seed)
                after=c2.compile_program(p,96,96,seed)
                old,new=Counter(map(sig,before)),Counter(map(sig,after))
                self.assertEqual(old-new, Counter(),(variant,seed))
                extra=list((new-old).elements())
                self.assertTrue(extra,(variant,seed))
                self.assertTrue(all(json.loads(op)['shape']=='line' for op in extra))
                self.assertLessEqual(len(extra), 32)

    def test_32_fixed_cases_with_v1_reference_custody(self):
        for variant in range(8):
            for seed in (17,73):
                p=c0.make_program('coral',variant)
                for module in (c0,c1,c2):
                    report=module.compile_with_report(p,96,96,seed)
                    self.assertEqual(report['program_sha256'],hashlib.sha256(c0.canonical_json(p).encode()).hexdigest())
                    self.assertEqual(report['operation_count'],len(report['operations']))
                    self.assertTrue(report['operations'])
                    self.assertLessEqual(report['estimated_cell_work'],131072)
                    self.assertLessEqual(len(report['operations']),2048)

    def test_bounds_budget_void_and_split_reflection(self):
        for variant in range(8):
            for width,height in ((64,64),(96,96),(128,64),(64,128),(256,256)):
                for seed in (17,73):
                    p=c0.make_program('coral',variant)
                    report=c2.compile_with_report(p,width,height,seed)
                    for op in report['operations']:
                        if op['shape']=='disc':
                            x0,y0,x1,y1=(op['x']-op['radius'],op['y']-op['radius'],op['x']+op['radius'],op['y']+op['radius'])
                        else:
                            pts=op.get('points',[[op.get('x0',0),op.get('y0',0)],[op.get('x1',0),op.get('y1',0)]])
                            margin=(op.get('width',1)+1)//2 if op.get('width',1)>1 else 0
                            x0=min(p[0] for p in pts)-margin;y0=min(p[1] for p in pts)-margin
                            x1=max(p[0] for p in pts)+margin;y1=max(p[1] for p in pts)+margin
                        self.assertTrue(0<=x0<=x1<width and 0<=y0<=y1<height,(variant,width,height,op))
                        if variant in (3,7):
                            self.assertTrue(x1<width*.27 or x0>width*.73 or y1<height*.27 or y0>height*.73,(variant,op))
        p=c0.make_program('coral',2)
        ops=c2.compile_program(p,96,96,73)
        names={sig(x) for x in ops}
        for op in ops:
            self.assertIn(sig(c2.reflected_operation(op,96)), names)
        for kw in [{'max_shapes':1},{'max_estimated_cells':1},{'material':1}]:
            with self.assertRaises(c2.CompilerError): c2.compile_program(p,96,96,73,**kw)

    def test_determinism_and_no_rng_cross_theme_changes(self):
        for var in range(8):
            p=c0.make_program('coral',var)
            for seed in (17,73):
                a=c2.compile_program(p,96,96,seed)
                b=c2.compile_program(p,96,96,seed)
                self.assertEqual(a,b)

if __name__=='__main__':unittest.main()
