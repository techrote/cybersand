import copy
import struct
import unittest
import sol_node_trace_audit as a

def put(capture,key,values):
    capture[key]=values
    capture[key+'le']=struct.pack('<'+str(len(values))+'d',*values).hex()

def fixture(policy='original',overflow=False):
    count=64 if overflow else 1;total=65 if overflow else 1
    c=dict(schema='gcr-node-trace-001',status='INCOMPLETE_NODE_CAP' if overflow else 'COMPLETE',complete=not overflow,
        export_complete=True,normal_policy=policy,storage_bytes=55872,node_limit=64,total_nodes=total,captured_nodes=count,
        dropped_nodes=total-count,batch_count=8,input_bins=total,samples=total,owner_id=1,instance_id=2,generation=1,sample=4)
    c['kernel_status']=c['status'];body=[0. if overflow else -1.,0.,0.,0.,0.,1.,1.,0.]
    capacity=20. if overflow else 2.;weight=1./total
    put(c,'body_f64',body);put(c,'solve_f64',[20.,1.,20.])
    result=[0.]*19;result[14]=capacity;result[17]=1.
    if not overflow:
        for index in [0,2,6,10,12]:result[index]=1.
        result[15]=.5
    put(c,'result_f64',result)
    c['result_counts']=[total,total,0,8*total,0,0,0]
    put(c,'nodes_f64',[v for _ in range(count) for v in [0.,0.,1.,0.,weight,capacity*weight]])
    c['node_meta_f64']=[v for i in range(count) for v in [i,1,0,1,0]]
    batches=[];meta=[];steps=[];flags=[]
    for index in range(8):
        axis=index%2;loaded=not overflow and index>0;first=not overflow and index==0
        masked=not axis and policy=='active-normal-001'
        active=not overflow and not axis
        batches.extend([-1. if first else 0.,0.,0.,0.,0.,0.,1. if active else 0.,1. if active and masked else 0.])
        meta.extend([index//2,axis,int(active),int(active and masked),0,0,int(masked)])
        for _ in range(count):
            before=1. if loaded else 0.;after=0. if overflow else 1.
            steps.extend([before,0.,after,0.,-1. if first else 0.,1. if first else -0.,weight,
                0. if axis or overflow else 1.,0. if axis or overflow else 1.,1. if first else 0.,
                0. if axis else capacity*weight])
            flags.append((1|(2 if active else 0) if not axis else 0)|(4|(8 if active else 0) if masked else 0))
    put(c,'batches_f64',batches);put(c,'steps_f64',steps);c['batch_meta_f64']=meta;c['flags_f64']=flags
    c['raw_energy_after']=0.;c['raw_energy_f64le']=struct.pack('<d',0.).hex()
    return c

class TraceAudit(unittest.TestCase):
    def test_complete_both_policies(self):
        for policy in ['original','active-normal-001']:
            result=a.audit(fixture(policy));self.assertTrue(result['full_closure']);self.assertEqual(result['nodes'],1)

    def test_incomplete_has_no_full_closure(self):
        result=a.audit(fixture(overflow=True));self.assertFalse(result['full_closure']);self.assertEqual(result['dropped'],1)

    def test_corruption_refusals(self):
        for name in ['weight','mask','delta','order','capacity','length','bits','count']:
            with self.subTest(name=name):
                c=fixture('active-normal-001')
                if name=='weight':v=c['steps_f64'].copy();v[6]=.5;put(c,'steps_f64',v)
                elif name=='mask':c['flags_f64'][0]^=8
                elif name=='delta':v=c['steps_f64'].copy();v[9]=.5;put(c,'steps_f64',v)
                elif name=='order':c['batch_meta_f64'][0]=1
                elif name=='capacity':v=c['nodes_f64'].copy();v[5]=3.;put(c,'nodes_f64',v)
                elif name=='length':c['steps_f64'].pop()
                elif name=='bits':c['steps_f64le']=struct.pack('<d',2.).hex()+c['steps_f64le'][16:]
                else:c['result_counts'][3]=7
                with self.assertRaises((AssertionError,ValueError)):a.audit(c)

    def test_overflow_cannot_claim_complete(self):
        c=fixture(overflow=True);c['complete']=True;c['status']=c['kernel_status']='COMPLETE'
        with self.assertRaises(AssertionError):a.audit(c)

    def test_owner_binding(self):
        c=fixture();row=dict(id=99,instance_id=2,generation=1,sample=4)
        with self.assertRaises(AssertionError):a.audit(c,row)

    def test_display_is_not_exact_oracle(self):
        c=fixture();c['steps_f64'][5]+=1e-15
        self.assertTrue(a.audit(c)['full_closure'])

if __name__=='__main__':unittest.main()
