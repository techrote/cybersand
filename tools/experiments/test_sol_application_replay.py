import unittest
import sol_application_replay as r

class ReplayTests(unittest.TestCase):
    def test_clip_then_wrench_can_hide_native_prediction_without_combined_creation(self):
        value=r.stages(0,3,0,1,1,[0,-3],0,[0,-.1])
        self.assertEqual(value['live_KE'],4.5);self.assertEqual(value['clip_only_KE'],0)
        self.assertEqual(value['recorded_wrench_after_clip_work'],4.5)
        self.assertEqual(value['predicted_combined_work'],0);self.assertEqual(value['alternative_retain_preclip_KE'],0)
    def test_same_direction_correction_does_not_clip_and_torque_is_accounted(self):
        value=r.stages(2,0,1,2,4,[-2,0],-2,[.1,0])
        self.assertEqual(value['clip_work'],0);self.assertEqual(value['predicted_velocity'],[1,0]);self.assertEqual(value['predicted_omega'],.5)
        self.assertEqual(value['predicted_after_recorded_action_KE'],1.5)
    def test_invalid_mass_or_nonfinite_wrench_refuses(self):
        for mass,j in [(0,0),(1,float('nan'))]:
            with self.assertRaises(AssertionError):r.stages(0,0,0,mass,1,[j,0],0,[0,0])

if __name__=='__main__':unittest.main()
