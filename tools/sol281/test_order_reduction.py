"""Adversarial tests of the independent state-admission audit."""
import copy,struct,unittest
import order_reduce_live as live

class StateAudit(unittest.TestCase):
    def setUp(self):
        self.body=dict(bits=struct.pack('<11d',1,0,0,1,20,30,0,0,0,520,70000).hex(),valid=True,frozen=False,body_rid=3,body_instance=4,physics_epoch=2,generation=7,gravity=[0,92.12],linear_damp=.14,angular_damp=1.04,fixed_delta=1/60,terrain_revision=19,local_com=[0,0])
        self.d=dict(initial_body=copy.deepcopy(self.body),body_rid=3,body_instance=4)
    def test_control(self):live.validate_body(self.body,self.d,520,70000,[0,0])
    def test_foreign_invalid_retired_frozen_and_wrong_policy(self):
        for key,value in dict(valid=False,frozen=True,body_rid=30,body_instance=40,physics_epoch=20,generation=70,gravity=[0,9.8],linear_damp=3,angular_damp=3,fixed_delta=1/30,terrain_revision=99,local_com=[1,1]).items():
            with self.subTest(key=key):
                body=copy.deepcopy(self.body);body[key]=value
                with self.assertRaises(AssertionError):live.validate_body(body,self.d,520,70000,[0,0])
    def test_nonfinite_and_wrong_mass_inertia(self):
        for index,value in [(6,float('nan')),(9,521),(10,71000)]:
            with self.subTest(index=index):
                body=copy.deepcopy(self.body);a=list(struct.unpack('<11d',bytes.fromhex(body['bits'])));a[index]=value;body['bits']=struct.pack('<11d',*a).hex()
                with self.assertRaises(AssertionError):live.validate_body(body,self.d,520,70000,[0,0])
if __name__=='__main__':unittest.main()
