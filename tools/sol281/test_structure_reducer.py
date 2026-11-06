"""Analytic adversarial controls for independent structural geometry reduction."""
import math
import unittest
from copy import deepcopy
from reduce_structure_cut import area, clip, depth, geometry, handoff, coordinate, physical_commands

class Geometry(unittest.TestCase):
    def test_contained_cell_penetration_uses_exit_distance(self):
        # Interval intersection length would incorrectly return1, not2.
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
    def test_wrong_phase_ownership_refuses(self):
        d=dict(prepared=dict(native_source_members=520,aggregate_owned=0,cut_applied=True,phase=2,source_probe=43,token='t'),commit=dict(ok=True,aggregate_owned=520,phase=4,source_probe=0,token='t',body_id=1,body_generation='2'),activation=dict(ok=True,aggregate_owned=520,phase=6,token='t',body_id=1,body_generation='2'),initial_body=dict(manual_step=0),body_rid=1)
        handoff(d,520)
        for section,key,value in [('prepared','native_source_members',0),('prepared','aggregate_owned',520),('prepared','cut_applied',False),('commit','aggregate_owned',0)]:
            bad=deepcopy(d);bad[section][key]=value
            with self.assertRaises(AssertionError):handoff(bad,520)
    def test_wrong_host_worker_response_source_refuses(self):
        d=dict(platform='Windows',structure='tree',surroundings='empty',sand_response=False,workers=1,source='a')
        coordinate(d,'windows','tree','empty',False,1,'a')
        for key,value in [('platform','Linux'),('workers',4),('sand_response',True),('source','b')]:
            bad=dict(d,**{key:value})
            with self.assertRaises(AssertionError):coordinate(bad,'windows','tree','empty',False,1,'a')
    def test_missing_duplicate_coordinate_refuses(self):
        a=dict(name='a');b=dict(name='b');setup=dict(name='version')
        self.assertEqual(physical_commands([setup,a,b],{'a','b'}),[a,b])
        with self.assertRaises(AssertionError):physical_commands([setup,a],{'a','b'})
        with self.assertRaises(AssertionError):physical_commands([setup,a,a,b],{'a','b'})

if __name__=='__main__':unittest.main()
