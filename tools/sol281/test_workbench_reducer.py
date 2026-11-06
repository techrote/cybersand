import copy,unittest
import workbench_reduce as q
class ApplicationReadback(unittest.TestCase):
    def setUp(self):
        self.b=[1,0,0,1,0,0,0,2,0,520,70000]
        self.action=dict(impulse=[0,520],torque=70000,correction=[0,-.1])
        self.a=copy.copy(self.b);self.a[7]=1;self.a[8]=1
    def test_clip_is_separate_from_impulse(self):
        residual,torque,clip=q.application_readback(self.b,self.a,self.action)
        self.assertEqual(residual,[0,0]);self.assertEqual(torque,0);self.assertEqual(clip,-1040)
    def test_lost_linear_impulse_refused(self):
        self.a[7]=0
        with self.assertRaises(AssertionError):q.application_readback(self.b,self.a,self.action)
    def test_lost_torque_refused(self):
        self.a[8]=0
        with self.assertRaises(AssertionError):q.application_readback(self.b,self.a,self.action)
if __name__=='__main__':unittest.main()
