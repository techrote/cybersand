import copy,gzip,hashlib,json,struct,tempfile,unittest
from pathlib import Path
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

class IndependentAdmission(unittest.TestCase):
    def setUp(self):
        body=dict(bits=struct.pack('<11d',1,0,0,1,0,0,0,0,0,2,1).hex(),valid=True,frozen=False,body_rid=3,body_instance=4,generation=2,physics_epoch=1,gravity=[0,92.1199951171875],linear_damp=.14000000059604645,angular_damp=1.0399999618530273,fixed_delta=1/60,terrain_revision=7,local_com=[0,0])
        self.d=dict(initial_body=body,body_rid=3,body_instance=4,prepared=dict(center=[0,0]),server_shapes=[dict(data=[1,.5],transform=[1,0,0,1,0,0])],authored=dict(gravity_scale=.094,linear_damp=.04,angular_damp=.04,ordinary_cap=3,correction_cap=.5,workbench_budget=20))
    def test_independent_controls_pass(self):q.controls(self.d,2,1)
    def test_consistently_wrong_gravity_refused(self):
        self.d['initial_body']['gravity']=[0,0]
        with self.assertRaises(AssertionError):q.controls(self.d,2,1)
    def test_consistently_wrong_com_refused(self):
        self.d['initial_body']['local_com']=[100,100]
        with self.assertRaises(AssertionError):q.controls(self.d,2,1)
    def test_changed_boundary_generation_refused(self):
        body=copy.deepcopy(self.d['initial_body']);body['generation']+=1
        with self.assertRaises(AssertionError):q.body_ok(body,self.d,2,1)
    def test_missing_raw_custody_refused(self):
        raw=b'{}';packed=gzip.compress(raw,mtime=0)
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'report.json.gz';path.write_bytes(packed)
            record=dict(bytes=len(packed),sha256=hashlib.sha256(packed).hexdigest(),raw_bytes=len(raw),raw_sha256=hashlib.sha256(raw).hexdigest())
            self.assertEqual(q.archive(path,record),{})
            del record['raw_sha256']
            with self.assertRaises(KeyError):q.archive(path,record)
    def test_wrong_raw_length_refused(self):
        raw=b'{}';packed=gzip.compress(raw,mtime=0)
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'report.json.gz';path.write_bytes(packed)
            record=dict(bytes=len(packed),sha256=hashlib.sha256(packed).hexdigest(),raw_bytes=3,raw_sha256=hashlib.sha256(raw).hexdigest())
            with self.assertRaises(AssertionError):q.archive(path,record)
if __name__=='__main__':unittest.main()
