import copy,unittest
import workbench_order_reduce as q
class PrimitiveAdmission(unittest.TestCase):
    def setUp(self):
        self.b=[1,0,0,1,10,20,0,2,0,520,70000]
        self.action=dict(impulse=[0,-520],torque=70000,correction=[0,-.1])
    def test_delivered_impulse_then_cancelled_by_clip(self):
        after=copy.copy(self.b);after[7]=1;q.primitive(self.b,after,'after_central_impulse',self.action)
        clipped=copy.copy(after);clipped[7]=0;q.primitive(after,clipped,'after_clip',self.action)
    def test_final_clip_cannot_hide_lost_impulse(self):
        with self.assertRaises(AssertionError):q.primitive(self.b,self.b,'after_central_impulse',self.action)
    def test_clip_before_delivery_remains_separate(self):
        clipped=copy.copy(self.b);clipped[7]=0;q.primitive(self.b,clipped,'after_clip',self.action)
        after=copy.copy(clipped);after[7]=-1;q.primitive(clipped,after,'after_central_impulse',self.action)
    def test_wrong_clip_direction_refused(self):
        before=copy.copy(self.b);before[7]=-2;after=copy.copy(before);after[7]=0
        with self.assertRaises(AssertionError):q.primitive(before,after,'after_clip',self.action)
    def test_torque_delivery_and_lost_torque(self):
        after=copy.copy(self.b);after[8]=1;q.primitive(self.b,after,'after_torque_impulse',self.action)
        with self.assertRaises(AssertionError):q.primitive(self.b,self.b,'after_torque_impulse',self.action)
    def test_translation_does_not_reset_velocity(self):
        after=copy.copy(self.b);after[5]-=.1;q.primitive(self.b,after,'after_translation',self.action)
        after[7]=0
        with self.assertRaises(AssertionError):q.primitive(self.b,after,'after_translation',self.action)
    def test_impulse_cannot_change_inertia_or_pose(self):
        after=copy.copy(self.b);after[7]=1;after[10]+=1
        with self.assertRaises(AssertionError):q.primitive(self.b,after,'after_central_impulse',self.action)
        after[10]-=1;after[4]+=1
        with self.assertRaises(AssertionError):q.primitive(self.b,after,'after_central_impulse',self.action)
if __name__=='__main__':unittest.main()
