import copy
import unittest
import sol_node_trace_reduce as r

def report():
    fields=['before','sampled','live_before_application','after_application','after_step','external','controllers','geometry','application','emission_requests','inserted_materials']
    steps=[]
    for index in range(180):
        s={k:[] for k in fields};s.update(step=index,native_response={'rows':[{'impulse':[1.,2.]}],'getter_us':1})
        steps.append(s)
    return dict(initial_payload={'sha256':'initial'},final_payload={'sha256':'final'},initial_geometry=[],initial_sample={},authored=[],case={},steps=steps)

class ParityAudit(unittest.TestCase):
    def test_only_trace_and_timing_omitted(self):
        first=report();second=copy.deepcopy(first)
        for step in second['steps']:
            packet=step['native_response'];packet['getter_us']=100;packet['solver_trace_mode']='batch64-001'
            packet['rows'][0]['solver_trace']={'diagnostic':True}
        self.assertEqual(r.parity(first,second)['status'],'PASS')

    def test_physical_change_refused(self):
        first=report();second=copy.deepcopy(first);second['steps'][179]['native_response']['rows'][0]['impulse'][0]=1.01
        with self.assertRaises(AssertionError):r.parity(first,second)

    def test_missing_window_refused(self):
        first=report();second=copy.deepcopy(first);second['steps'].pop()
        with self.assertRaises(AssertionError):r.parity(first,second)

    def test_changed_pristine_input_refused(self):
        first=report();second=copy.deepcopy(first);second['initial_sample']['epoch']=2
        with self.assertRaises(AssertionError):r.parity(first,second)

if __name__=='__main__':unittest.main()
