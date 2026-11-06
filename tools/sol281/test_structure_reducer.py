"""Analytic adversarial controls for independent structural geometry reduction."""
import math
import unittest
from reduce_structure_cut import area, clip, depth, geometry

class Geometry(unittest.TestCase):
    def test_contained_cell_penetration_uses_exit_distance(self):
        # Interval intersection length would incorrectly return1, not1.5.
        poly=[(-1,-1),(2,-1),(2,2),(-1,2)]
        self.assertEqual(area(clip(poly,0,0)),1)
        self.assertEqual(depth(poly,0,0),2)
    def test_rotated_diamond(self):
        poly=[(0,1),(1,0),(2,1),(1,2)]
        self.assertAlmostEqual(area(clip(poly,0,0)),.5)
        self.assertAlmostEqual(depth(poly,0,0),math.sqrt(.5))
    def test_touch_and_original_tiny_witness_filter(self):
        shape={'data':[.5,.5],'transform':[1,0,0,1,0,0]}
        self.assertEqual(geometry([1,0,0,1,-.5,.5],[shape],{(0,0):43})['witnesses'],0)
        self.assertEqual(geometry([1,0,0,1,-.5+5e-10,.5],[shape],{(0,0):43})['witnesses'],0)
        self.assertEqual(geometry([1,0,0,1,-.5+2e-9,.5],[shape],{(0,0):43})['witnesses'],1)
    def test_hole_is_not_filled_by_aggregate_aabb(self):
        def rect(x,y,w,h):return dict(data=[w/2,h/2],transform=[1,0,0,1,x+w/2,y+h/2])
        shapes=[rect(0,0,3,1),rect(0,1,1,1),rect(2,1,1,1),rect(0,2,3,1)]
        out=geometry([1,0,0,1,0,0],shapes,{(1,1):1})
        self.assertEqual(out['area'],0);self.assertEqual(out['witnesses'],0)

if __name__=='__main__':unittest.main()
