import json,tempfile,unittest
from pathlib import Path
from analyze_gcr_load import reduce_capture,quantile
from gcr_load_manifest import manifest
class LoadTools(unittest.TestCase):
    def test_population_and_support(self):
        p=manifest()
        self.assertEqual(len(p['cases'])*len(p['arms'])*len(p['platforms']),68)
        self.assertEqual(len({v['id'] for v in p['cases']}),17)
        self.assertEqual(p['compound_recipe']['mass'],520)
        self.assertEqual(p['compound_recipe']['isolated_narrow_x'],[56,58])
    def test_failed_capture_cannot_supply_numeric_pass(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'failed.json'
            path.write_text(json.dumps({'ok':False,'rows':[{'entry_com':0}]}))
            result=reduce_capture(path)
            self.assertEqual(result['status'],'failed')
            self.assertIsNone(result['metrics'])
            self.assertNotIn('entry_peak',result)
    def test_empty_is_not_zero_penetration(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'empty.json';path.write_text('{"ok":true,"rows":[]}')
            self.assertEqual(reduce_capture(path)['status'],'failed')
    def test_tail_quantile_not_mean(self):
        self.assertEqual(quantile(list(range(100)),.95),94)
        self.assertIsNone(quantile([],.95))
if __name__=='__main__':unittest.main()
