import copy
import math
import struct
import unittest
import sol_contact_application_reduce as a

def state(v,pose=None):
    pose=pose or [1.,0.,0.,1.,128.,121.]
    return dict(velocity_omega_f64le=struct.pack('<3d',*v).hex(),pose_f64le=struct.pack('<6d',*pose).hex(),mass=1.,inertia=2.,
        kinetic=a.kinetic(v,1.,2.),potential=0.,center_of_mass_local=[0.,0.])

def witness(variant,correction=None):
    c=correction if correction is not None else [0.,a.f32(-.1)]
    row=dict(correction=c,impulse=[-1.,a.f32(-.2)],torque=.3)
    eff=a.effective(c);t=.3+a.cross32([-eff[0],-eff[1]],row['impulse'])
    action=dict(age=0,correction=eff,impulse=row['impulse'],torque=t)
    if variant=='retain-linear-001':action['linear_clip_policy']=variant
    live=state([2.,1.,.2]);base=[2.,0. if eff[1]<0 and variant=='baseline' else 1.,.2]
    result=[base[0]-1.,base[1]+row['impulse'][1],base[2]+t/2.]
    after=state(result,[1.,0.,0.,1.,128.,a.f32(121.+eff[1])])
    return [row,action,live,live,after,after,variant]

def gate_fixture():
    result={}
    for host in ['windows','linux']:
        for worker in [1,4]:
            for case in ['barrel-rest','barrel-constrained-valid','shared-granular-bodies-extended360']:
                for arm in ['original-baseline','active-baseline','original-retain','active-retain']:
                    records=[dict(kinetic=1. if arm.endswith('retain') else 2.,speed=1.,abs_omega=0.,sand_area=0.,sand_depth=0.) for _ in range(360)]
                    owner=dict(windows=a.windows(records,[state([0.,0.,0.]) for _ in records]),static_screen=True,hard_witnesses=0,maximum_hard_intersection=0.)
                    result[(host,worker,case,arm)]={'owners':[dict(copy.deepcopy(owner),body=i+1) for i in range(3 if case.startswith('shared-') else 1)]}
    return result

class ApplicationAccounting(unittest.TestCase):
    def test_both_real_state_models(self):
        for variant in ['baseline','retain-linear-001']:
            r=a.application_record(*witness(variant));self.assertLessEqual(r['readback_error'],1e-5)
            self.assertEqual(r['clip_work']==0,variant!='baseline')

    def test_wrong_clipping_refused(self):
        x=witness('retain-linear-001');wrong=witness('baseline');x[4]=x[5]=wrong[4]
        with self.assertRaises(AssertionError):a.application_record(*x)

    def test_wrong_variant_tag_refused(self):
        x=witness('retain-linear-001');x[1].pop('linear_clip_policy')
        with self.assertRaises(AssertionError):a.application_record(*x)

    def test_native_wrench_change_refused(self):
        x=witness('retain-linear-001');x[1]['impulse']=[-1.1,-.2]
        with self.assertRaises(AssertionError):a.application_record(*x)

    def test_wrong_torque_reference_refused(self):
        x=witness('retain-linear-001');x[1]['torque']=x[0]['torque']
        with self.assertRaises(AssertionError):a.application_record(*x)

    def test_stale_core_refused(self):
        x=witness('retain-linear-001');x[1]['age']=1
        with self.assertRaises(AssertionError):a.application_record(*x)

    def test_small_correction_is_not_applied(self):
        for variant in ['baseline','retain-linear-001']:
            x=witness(variant,[0.,a.f32(-.0005)]);self.assertEqual(a.application_record(*x)['correction'],[0.,0.])
            x[1]['correction']=x[0]['correction']
            with self.assertRaises(AssertionError):a.application_record(*x)

    def test_missing_observation_refused(self):
        x=witness('baseline');x[4].pop('velocity_omega_f64le')
        with self.assertRaises(KeyError):a.application_record(*x)

    def test_window_denominators_and_integral(self):
        records=[dict(kinetic=float(i),speed=1.,abs_omega=0.,sand_area=0.,sand_depth=0.) for i in range(360)]
        w=a.windows(records,[state([0.,0.,0.]) for _ in records])
        self.assertEqual([x['motion']['kinetic']['count'] for x in w],[120,120,120,180,360])
        self.assertEqual(w[-1]['motion']['kinetic']['integral'],math.fsum(range(360))/60.)

    def test_prefix_hash_mismatch_refused(self):
        new=dict(initial_payload={'sha256':'a'},prefix_payload={'sha256':'b'});old=dict(initial_payload={'sha256':'a'},final_payload={'sha256':'c'})
        with self.assertRaises(AssertionError):a.prefix_compare(new,old)

    def test_per_intersection_hard_filter(self):
        observation=dict(origin=[0,0],size=[1,1],material_runs=[[43,1]],pose=[1.,0.,0.,1.,0.,0.])
        large=dict(center=[.5,-.5+4.3e-8],size=[1.,1.]);small=dict(center=[.5,-.5+5e-10],size=[1.,1.])
        self.assertEqual(a.hard_witnesses(observation,[large])['count'],1)
        self.assertEqual(a.hard_witnesses(observation,[small]*4)['count'],0)

    def test_gate_zero_margin_is_not_RID_tolerance(self):
        data=gate_fixture();self.assertEqual(a.compare_gate(data)['status'],'PASS')
        data[('windows',1,'shared-granular-bodies-extended360','active-retain')]['owners'][0]['windows'][0]['motion']['speed']['mean']+=1e-12
        self.assertEqual(a.compare_gate(data)['status'],'NO-GO')

    def test_support_failure_blocks_expansion(self):
        data=gate_fixture();data[('linux',4,'barrel-rest','active-retain')]['owners'][0]['static_screen']=False
        result=a.compare_gate(data);self.assertEqual(result['status'],'NO-GO');self.assertEqual(result['stage_b'],'NOT_ADMITTED_BY_REGISTERED_GATE')

if __name__=='__main__':unittest.main()
