"""Analytic and adverse stage-accounting controls, independent of campaign outcomes."""
import math
import unittest
from reduce_structure_stages import clipped_velocity, load_reference, normalize, wrench, window, f

class StageAccounting(unittest.TestCase):
    def test_correction_clips_only_opposing_components(self):
        self.assertEqual(clipped_velocity((2.,4.),(-.1,-.2)),(0.,0.))
        self.assertEqual(clipped_velocity((2.,4.),(.1,-.2)),(2.,0.))
        self.assertEqual(clipped_velocity((2.,4.),(0.,0.)),(2.,4.))
    def test_central_and_opposite_offset_impulses(self):
        p=[1.,0.,0.,1.,80.,40.]
        central=wrench([(1.,2.)],[(0.,0.)],p,1.)
        self.assertEqual(central['applied'],(1.,2.));self.assertEqual(central['torque'],0.)
        pair=wrench([(0.,-1.),(0.,1.)],[(-1.,0.),(1.,0.)],p,1.)
        self.assertEqual(pair['applied'],(0.,0.));self.assertEqual(pair['torque'],2.)
    def test_cap_is_sum_of_magnitudes_not_net_wrench(self):
        pair=wrench([(0.,-5.),(0.,5.)],[(-1.,0.),(1.,0.)],[1.,0.,0.,1.,0.,0.],3./10.)
        self.assertEqual(pair['applied'],(0.,0.));self.assertEqual(pair['scaled_magnitudes'],3.);self.assertEqual(pair['torque'],3.)
    def test_tiny_impulse_is_in_proposed_but_not_applied_wrench(self):
        pair=wrench([(.0009,0.),(.0011,0.)],[(0.,0.),(0.,0.)],[1.,0.,0.,1.,0.,0.],1.)
        self.assertEqual(pair['applications'],1);self.assertEqual(pair['applied'],(f(.0011),0.))
        self.assertGreater(pair['proposed'][0],pair['applied'][0]);self.assertGreater(pair['discarded_magnitude'],0.)
    def test_upward_correction_potential_and_clipping_are_distinct(self):
        mass=2.;g=10.;velocity=(0.,4.);correction=(0.,-.25)
        clip=clipped_velocity(velocity,correction);dk=.5*mass*(clip[1]**2-velocity[1]**2);du=-mass*g*correction[1]
        self.assertEqual(dk,-16.);self.assertEqual(du,5.);self.assertEqual(dk+du,-11.)
    def test_normalization_sign_and_zero_g(self):
        load=load_reference(2.,(0.,10.),.1);self.assertEqual(load,2.)
        self.assertEqual(normalize((0.,-2.),(0.,10.),load),1.)
        self.assertEqual(normalize((0.,2.),(0.,10.),load),-1.)
        self.assertIsNone(normalize((0.,-2.),(0.,0.),0.))
    def test_energy_telescope_does_not_imply_conservation(self):
        energy=[100.,110.,105.,112.];deltas=[energy[i+1]-energy[i] for i in range(3)]
        self.assertEqual(sum(deltas),12.);self.assertNotEqual(sum(deltas),0.)

if __name__=='__main__':unittest.main()
