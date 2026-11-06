"""Adversarial tests of the SOL-BEARING-GATE-001 native-law model and counterfactual."""
import struct,unittest
import gate_reduce as g

def pack(rows):return struct.pack('<%df'%sum(len(r) for r in rows),*[v for r in rows for v in r]).hex()
def state(i,y,vy,sample):return [i,10.,y,0.,2.,2.,0.,vy,0.,4.,sample]
def result(i,cy,sample):return [i,0.,0.,0.,cy,0.,0.,0.,sample]
def row(i,sample,support,below=None):return [i,sample,0.,0.,0.,0.,0.,0.,support,support if below is None else below]
def entry(states,results,rows,tick=5,serial=9):return dict(serial=serial,tick=tick,epoch=1,states=pack(states),results=pack(results),rows=rows)

class Gate(unittest.TestCase):
    def test_ungated_law_matches(self):
        prev=entry([state(1,20.,1.,6)],[result(1,0.,6)],[row(1,6,0)],tick=4)
        now=entry([state(1,20.1,1.,7)],[result(1,g.law(20.1,20.),7)],[row(1,7,3)])
        v=g.evaluate(now,prev,[4.]);self.assertEqual((v['checks'],v['fails'],v['gated']),(1,0,0));self.assertAlmostEqual(v['actual'][1],v['counterfactual'][1],6)
    def test_gated_proxy_counterfactual_restores_withheld_correction(self):
        prev=entry([state(1,20.,0.,6)],[result(1,0.,6)],[row(1,6,0)],tick=4)
        now=entry([state(1,20.02,0.,7)],[result(1,0.,7)],[row(1,7,0,below=3)])
        v=g.evaluate(now,prev,[4.]);self.assertEqual((v['gated'],v['fails']),(1,0))
        self.assertAlmostEqual(v['actual'][1]-v['counterfactual'][1],.99*.02,5)
    def test_wrong_native_emission_fails_model(self):
        prev=entry([state(1,20.,0.,6)],[result(1,0.,6)],[row(1,6,0)],tick=4)
        now=entry([state(1,20.02,0.,7)],[result(1,-.1,7)],[row(1,7,3)])
        self.assertEqual(g.evaluate(now,prev,[4.])['fails'],1)
    def test_cap_and_mass_weight(self):
        prev=entry([state(1,20.,0.,6),state(2,20.,0.,6)],[result(1,0.,6),result(2,0.,6)],[row(1,6,0),row(2,6,0)],tick=4)
        now=entry([state(1,22.,0.,7),state(2,20.,0.,7)],[result(1,0.,7),result(2,0.,7)],[row(1,7,0,below=3),row(2,7,0)])
        v=g.evaluate(now,prev,[3.,1.]);self.assertAlmostEqual(v['counterfactual'][1],-.375,6)
    def test_misaligned_sample_refused(self):
        now=entry([state(1,20.,0.,7)],[result(1,0.,8)],[row(1,7,3)])
        self.assertIsNone(g.evaluate(now,None,[4.]))
    def test_unknown_previous_has_no_checks(self):
        now=entry([state(1,20.,0.,7)],[result(1,0.,7)],[row(1,7,3)])
        v=g.evaluate(now,None,[4.]);self.assertEqual((v['checks'],v['previous_known']),(0,False))
    def test_calibration_counts_only_ungated(self):
        now=entry([state(1,20.,1.,7),state(2,20.,1.,7),state(3,20.,0.,7)],[result(1,0.,7),result(2,0.,7),result(3,0.,7)],
            [row(1,7,2,below=2),row(2,7,0,below=1),row(3,7,0,below=1)])
        cal=g.evaluate(now,None,[1.,1.,1.])['calibration'];self.assertEqual((cal[(True,True)],cal[(True,False)],sum(cal.values())),(1,1,2))
    def test_race_and_perturbation_classification(self):
        base=dict(after_step=dict(bits='a'),ordinary_stage=dict(native_states_bits='s',native_results_bits='r'))
        race=dict(after_step=dict(bits='b'),ordinary_stage=dict(native_states_bits='t',native_results_bits='r'))
        pert=dict(after_step=dict(bits='b'),ordinary_stage=dict(native_states_bits='s',native_results_bits='q'))
        self.assertEqual(g.first_difference([base,race],[base,base]),(1,'RACE'))
        self.assertEqual(g.first_difference([base,pert],[base,base]),(1,'PERTURBATION'))
        self.assertEqual(g.first_difference([base],[base]),(None,'EQUAL'))
if __name__=='__main__':unittest.main()
