#!/usr/bin/env python3
"""Independent geometry/filter and malformed-census controls."""
import importlib.util
import math
from pathlib import Path
import struct
import unittest

spec=importlib.util.spec_from_file_location("chamber",Path(__file__).with_name("sol_chamber_reduce.py"))
c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)

def capture(material=1,dy=0):
    index=(62-59)*51+50-47;count=51*44
    return dict(origin=[47,59],size=[51,44],material_runs=[[0,index],[material,1],[0,count-index-1]],mask_runs=[[0,count]],state=dict(pose_f64le=struct.pack("<6d",1,0,0,1,0,dy).hex()))

class GeometryObserver(unittest.TestCase):
    def setUp(self):c.CACHE.clear()
    def test_unit_square_wall(self):
        r=c.geometry(capture(),[(50.5,62.5,1,1)])
        self.assertEqual(r["area_by_material"][1],1);self.assertEqual(r["max_depth_by_material"][1],1)
        self.assertEqual(len(r["hard_exclusions"]),1)
    def test_sand_is_separate(self):
        r=c.geometry(capture(2),[(50.5,62.5,1,1)])
        self.assertEqual(r["sand_area"],1);self.assertFalse(r["hard_exclusions"])
    def test_original_hard_filter(self):
        r=c.geometry(capture(43,1e-8),[(50.5,61.5,1,1)])
        self.assertTrue(math.isclose(r["area_by_material"][43],1e-8,rel_tol=1e-5));self.assertEqual(len(r["hard_exclusions"]),1)
        r=c.geometry(capture(43,1e-10),[(50.5,61.5,1,1)])
        self.assertGreater(r["area_by_material"][43],0);self.assertFalse(r["hard_exclusions"])
    def test_foreign_mask(self):
        r=capture();r["mask_runs"]=[[9,51*44]]
        with self.assertRaises(AssertionError):c.geometry(r,[(50.5,62.5,1,1)])
    def test_incomplete_census(self):
        r=capture();r["material_runs"].pop()
        with self.assertRaises(AssertionError):c.geometry(r,[(50.5,62.5,1,1)])
    def test_pose_changes_cache_identity(self):
        first=c.geometry(capture(),[(50.5,62.5,1,1)])
        self.assertIs(first,c.geometry(capture(),[(50.5,62.5,1,1)]))
        self.assertNotEqual(first["area_by_material"],c.geometry(capture(dy=1),[(50.5,62.5,1,1)])["area_by_material"])

if __name__=="__main__":unittest.main()
