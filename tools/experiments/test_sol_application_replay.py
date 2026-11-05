import unittest
import hashlib
import json
from pathlib import Path
import sol_application_replay as r

DATA=Path(__file__).resolve().parents[2]/'docs/audits/sol-application-replay-20261105'
def read(path):return json.loads(path.read_text(encoding='utf-8'))

class ReplayTests(unittest.TestCase):
    def test_public_custody_and_complete_body_step_coverage(self):
        custody=read(DATA/'custody.json')
        for item in custody['artifacts']:
            self.assertEqual(hashlib.sha256((DATA/item['public_file']).read_bytes()).hexdigest(),item['public_lf_sha256'])
        rows=read(DATA/'records.json');self.assertEqual(len(rows),1080)
        expected={(arm,i,b) for arm in ['selective-original','selective-active'] for i in range(180) for b in [1,2,3]}
        self.assertEqual({(v['arm'],v['step'],v['body']) for v in rows},expected)
        self.assertTrue(all(v['body']==v['actual_action']['id'] for v in rows))

    def test_staged_positive_work_is_not_combined_creation(self):
        rows=read(DATA/'records.json');self.assertEqual(sum(v['recorded_wrench_after_clip_work']>0 for v in rows),364)
        self.assertTrue(all(v['actual_response_work']<=0 and v['native_scalar']['energy_delta']<=0 for v in rows))
        summary=read(DATA/'summary.json');self.assertEqual({v['body']:v['first_native_wrench_difference'] for v in summary['first_divergences']},{1:30,2:32,3:2})
        self.assertTrue(all(abs(v['work_balance_residual'])<1e-12 for v in summary['owner_summaries']))
        self.assertFalse(summary['live_actuation']);self.assertEqual((summary['native_mutations'],summary['rid_calls'],summary['generated_work']),(0,0,0))

    def test_cross_analysis_difference_is_preserved(self):
        comparison=read(DATA/'cross-analysis.json');self.assertTrue(comparison['summary_bytes_equal'])
        self.assertEqual(comparison['difference_count'],2)
        self.assertEqual(comparison['maximum_absolute_difference'],3.3881317890172014e-21)
        self.assertNotEqual(comparison['record_hashes']['windows'],comparison['record_hashes']['linux'])
    def test_clip_then_wrench_can_hide_native_prediction_without_combined_creation(self):
        value=r.stages(0,3,0,1,1,[0,-3],0,[0,-.1])
        self.assertEqual(value['live_KE'],4.5);self.assertEqual(value['clip_only_KE'],0)
        self.assertEqual(value['recorded_wrench_after_clip_work'],4.5)
        self.assertEqual(value['predicted_combined_work'],0);self.assertEqual(value['alternative_retain_preclip_KE'],0)
    def test_same_direction_correction_does_not_clip_and_torque_is_accounted(self):
        value=r.stages(2,0,1,2,4,[-2,0],-2,[.1,0])
        self.assertEqual(value['clip_work'],0);self.assertEqual(value['predicted_velocity'],[1,0]);self.assertEqual(value['predicted_omega'],.5)
        self.assertEqual(value['predicted_after_recorded_action_KE'],1.5)
    def test_invalid_mass_or_nonfinite_wrench_refuses(self):
        for mass,j in [(0,0),(1,float('nan'))]:
            with self.assertRaises(AssertionError):r.stages(0,0,0,mass,1,[j,0],0,[0,0])

if __name__=='__main__':unittest.main()
