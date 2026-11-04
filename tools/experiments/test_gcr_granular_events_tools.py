"""Adversarial identity, quantity, selector and actual-delivery evidence checks."""
import copy,unittest,json,tempfile
from pathlib import Path
from analyze_gcr_granular_events import reduce_capture,EvidenceError,REG,metadata_equal,validate_gates,sha,EXISTING

class Evidence(unittest.TestCase):
    def setUp(self):
        self.spec=dict(id='barrel-high',kind='barrel',material=2,configuration=dict(mass=1,layout='deep'))
        self.identity=dict(source='a'*40,source_inputs_sha256='b'*64,platforms=dict(windows=dict(native_sha256='c'*64,engine_sha256='d'*64)))
        self.raw=dict(ok=True,errors=[],registration=REG,case=self.spec,arm='E',platform='Windows',dt=1/60,
            identity=dict(source='a'*40,input_identity='b'*64,protocol_sha256='e'*64,native_sha256='c'*64,engine_sha256='d'*64,physics_backend='Rapier2D'),
            initial_native_hash='0123456789abcdef',actual_mass=1,actual_inertia=1,initial=[0,0,0,0,0,0],
            configuration=dict(self.spec['configuration'],material=2,ticks=1800,granular_events='off'),
            before=dict(counts=[9,0,1,0],water_mass=0),after=dict(counts=[9,0,1,0],water_mass=0),rows=[])
        for i in range(1800):
            body=dict(session=1,index=0,sample=i,age=0,correction=[0,0],correction_potential_delta=0,zeroing_removed_energy=0,
                kinetic_after_zeroing=0,kinetic_after_wrench=0,actual_mass=1,actual_inertia=1,velocity_after_zeroing=[0,0],velocity_after_wrench=[0,0],
                impulse=[0,0],omega_after_zeroing=0,omega_after_wrench=0,angular_impulse=0)
            self.raw['rows'].append(dict(tick=i,application=dict(accepted=True,bodies=[body]),selector='off',
                gcr=dict(legacy_non_granular=[0,0],event_accepted=[0,0],event_raw=[0,0],event_raw_torque=0,event_torque=0,event_budget_cost=0),
                observed_native_steps=1,observed_rapier_steps=1,conserved=True,material_count=1,water=0,tick_overlap=0,
                hard_clearance=True,out=[0,0,0,0,0,0],vertical_depth=0,work=[0,0,0],result=[1,0,0,0,0,0,0,0,i,0,0,0,1,1]))

    def run_reader(self):return reduce_capture(self.raw,self.spec,'E',self.identity,'windows','e'*64)
    def test_complete_measured_fixture(self):self.assertEqual(self.run_reader()[0]['applications']['unique_accepted_applications'],1800)
    def test_metadata_serialization_tolerance_is_bounded(self):
        self.assertTrue(metadata_equal({'angle':.785398163397448},{'angle':.7853981633974483}))
        self.assertFalse(metadata_equal({'angle':.785398164397448},{'angle':.7853981633974483}))
        self.assertFalse(metadata_equal(True,1))
    def test_source_protocol_runtime_identity(self):
        for key in ('source','protocol_sha256','native_sha256','input_identity'):
            old=self.raw['identity'][key];self.raw['identity'][key]='changed'
            with self.subTest(key=key),self.assertRaises(EvidenceError):self.run_reader()
            self.raw['identity'][key]=old
    def test_duplicate_or_stale_application(self):
        for key,value in [('sample',0),('age',1)]:
            old=self.raw['rows'][1]['application']['bodies'][0][key]
            self.raw['rows'][1]['application']['bodies'][0][key]=value
            with self.subTest(key=key),self.assertRaises(EvidenceError):self.run_reader()
            self.raw['rows'][1]['application']['bodies'][0][key]=old
    def test_registered_mass_cannot_drift(self):
        self.raw['actual_mass']=2
        with self.assertRaises(EvidenceError):self.run_reader()
    def test_selector_and_each_event_component(self):
        for key,value in [('event_accepted',[0,1]),('event_torque',1),('event_budget_cost',1)]:
            g=self.raw['rows'][0]['gcr'];old=g[key];g[key]=value
            with self.subTest(key=key),self.assertRaises(EvidenceError):self.run_reader()
            g[key]=old
        self.raw['rows'][0]['selector']='control'
        with self.assertRaises(EvidenceError):self.run_reader()
    def test_changed_native_quantity(self):
        self.raw['rows'][0]['material_count']=0
        with self.assertRaises(EvidenceError):self.run_reader()
    def test_missing_overlap_or_clock(self):
        for key,value in [('tick_overlap',None),('observed_native_steps',0),('observed_rapier_steps',2)]:
            old=self.raw['rows'][0][key];self.raw['rows'][0][key]=value
            with self.subTest(key=key),self.assertRaises(EvidenceError):self.run_reader()
            self.raw['rows'][0][key]=old
    def test_nonfinite_or_nonclosing_delivered_wrench(self):
        b=self.raw['rows'][0]['application']['bodies'][0]
        b['impulse']=[0,1]
        with self.assertRaises(EvidenceError):self.run_reader()
        b['impulse']=[0,float('nan')]
        with self.assertRaises(EvidenceError):self.run_reader()

class MechanicalGateEvidence(unittest.TestCase):
    def test_original_host_logs_and_unique_population_required(self):
        with tempfile.TemporaryDirectory() as temp:
            folder=Path(temp);platform=folder/'windows';platform.mkdir();gates=[]
            for name in ['import','test_gcr_granular_events']+EXISTING:
                path=platform/(name+'.log')
                path.write_text('GCR_GRANULAR_EVENT_CHECKS {"checks":59,"failures":[]}\n' if name=='test_gcr_granular_events' else 'unit fixture\n',encoding='utf-8')
                gates.append(dict(test=name,ok=True,exit=0,timed_out=False,log_sha256=sha(path)))
            write=lambda value:(platform/'gates.json').write_text(json.dumps(value),encoding='utf-8')
            write(gates);validate_gates(folder,'windows')
            for value in (gates[:-1],gates+[gates[0]], [dict(x,inherited_from='old') for x in gates]):
                write(value)
                with self.assertRaises(EvidenceError):validate_gates(folder,'windows')
            write(gates);(platform/'import.log').write_text('changed',encoding='utf-8')
            with self.assertRaises(EvidenceError):validate_gates(folder,'windows')
if __name__=='__main__':unittest.main()
