import copy
import math
import struct
import unittest
import sol_gravity_operator_reduce as r

class OperatorTests(unittest.TestCase):
    def sample(self):
        profile=dict(registration='test',models=['reference_barrel'],initial_states=[dict(id='rest',velocity=[0,0],omega=0)],steps=32,cadence=60,gate=dict(absolute_velocity_omega_error=1e-5))
        def state(v,step):
            return dict(velocity_omega_f64le=struct.pack('<3d',*v).hex(),pose_f64le=struct.pack('<6d',1,0,0,1,128,100).hex(),
                mass=1,inertia=1,kinetic=.5*sum(x*x for x in v),contacts=0,sleeping=False,gravity=[0,60],gravity_f64le=struct.pack('<2d',0,60).hex(),
                linear_damp=0,angular_damp=0,reported_step=1/60,manual_step=step,constant_force=[0,0],constant_torque=0)
        episode=dict(model='reference_barrel',initial_motion=profile['initial_states'][0],native_World='ABSENT',native_workers='NOT_APPLICABLE',teardown=True,
            properties=dict(freeze=False,custom_integrator=False,omit_force_integration=False,physics_ticks_per_second=60,server_params={'mass':1}),
            actual_shapes=[dict(disabled=False)],steps=[dict(step=i,before=state([0,i,0],i+1),after=state([0,i+1,0],i+2)) for i in range(32)])
        return dict(registration='test',failures=[],episodes=[episode]),profile
    def test_complete_fixed_operator(self):
        data,profile=self.sample();result=r.audit(data,profile)
        self.assertEqual(result['status'],'COMPLETE')
        self.assertTrue(all(m['compatible'] for m in result['aggregate']))
    def test_missing_observation_refuses(self):
        data,profile=self.sample();data['episodes'][0]['steps'].pop()
        with self.assertRaises(AssertionError):r.audit(data,profile)
    def test_extra_step_refuses(self):
        data,profile=self.sample();data['episodes'][0]['steps'][0]['after']['manual_step']+=1
        with self.assertRaises(AssertionError):r.audit(data,profile)
    def test_wrong_initial_motion_refuses(self):
        data,profile=self.sample();data['episodes'][0]['initial_motion']=dict(id='rest',velocity=[1,0],omega=0)
        with self.assertRaises(AssertionError):r.audit(data,profile)
    def test_constant_force_refuses(self):
        data,profile=self.sample();data['episodes'][0]['steps'][0]['before']['constant_force']=[0,1]
        with self.assertRaises(AssertionError):r.audit(data,profile)
    def test_nonfinite_property_refuses(self):
        data,profile=self.sample();data['episodes'][0]['steps'][0]['before']['linear_damp']=math.nan
        with self.assertRaises(AssertionError):r.audit(data,profile)
    def test_body_contact_refuses(self):
        data,profile=self.sample();data['episodes'][0]['steps'][0]['before']['contacts']=1
        with self.assertRaises(AssertionError):r.audit(data,profile)
    def test_gravity_and_each_equation(self):
        self.assertEqual(r.predict([2,1,.3],[0,60],0,0,'gravity-only','float64'),[2,2,.3])
        for precision in ['float64','float32']:
            for model in r.MODELS:
                self.assertEqual(r.predict([0,0,0],[0,0],0,0,model,precision),[0,0,0])
    def test_order_is_discriminating(self):
        a=r.predict([2,1,.3],[0,60],1,1,r.MODELS[1],'float64')
        b=r.predict([2,1,.3],[0,60],1,1,r.MODELS[2],'float64')
        self.assertGreater(abs(a[1]-b[1]),1e-5)
    def test_explicit_float32(self):
        self.assertEqual(r.predict([0,0,0],[0,38],0,0,'gravity-only','float32')[1],r.f32(r.f32(38)*r.f32(1/60)))
    def test_linear_law_does_not_reverse(self):
        self.assertEqual(r.predict([2,1,.3],[0,60],100,100,r.MODELS[3],'float64'),[0,0,0])
    def test_unknown_model_is_error(self):
        with self.assertRaises(ValueError):r.predict([0,0,0],[0,0],0,0,'unknown','float64')

if __name__=='__main__':unittest.main()
