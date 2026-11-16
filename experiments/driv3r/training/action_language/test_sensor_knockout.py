"""GAL-010b fixed-checkpoint and independent host-receipt tests."""
import json
import tempfile
import unittest
from pathlib import Path
from sensor_knockout import SEED,PANELS,evaluate,audit
from material_corridors import ARMS,KINDS,Model,episode

class SensorKnockoutTests(unittest.TestCase):
    def test_frozen_weight_sensor_toggle_changes_only_observation(self):
        a=Model();a.weights=[.17]*len(a.weights)
        w,r=episode(a,'lift','material','tree',SEED)
        z,t=episode(a,'lift','occluded','tree',SEED)
        self.assertEqual(r['world_sha256'],t['world_sha256'])
        self.assertEqual(a.weights,[.17]*len(a.weights))
        self.assertNotEqual(w.lease,z.lease)
    def test_panel_contract(self):
        self.assertEqual(len(PANELS),3)
        self.assertEqual(len(ARMS),6)
        self.assertEqual(len(KINDS),2)
    def test_evaluate_and_audit_tampering(self):
        # Uses the real frozen GAL-010 checkpoint archive, no retraining.
        source=Path(__file__).resolve().parents[1]/'results'/'checkpoints'
        if not source.exists():self.skipTest('GAL-010 checkpoint archive not present')
        with tempfile.TemporaryDirectory() as path:
            m=evaluate(source,path,n=5)
            self.assertEqual(audit(source,path)['episodes'],6*2*3*5)
            self.assertEqual(len(m['paired']),6*2*2)
            f=Path(path)/'receipts.json';f.write_text(f.read_text()+' ')
            with self.assertRaises(ValueError):audit(source,path)

if __name__=='__main__':unittest.main()
