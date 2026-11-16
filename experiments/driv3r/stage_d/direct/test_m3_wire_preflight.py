"""Cheap adversarial tests for D-1A/M3 cursor-only versus painting semantics."""
import copy
import importlib.util
import pathlib
import unittest

spec = importlib.util.spec_from_file_location(
    'd1a_m3_wire_preflight', pathlib.Path(__file__).with_name('m3_wire_preflight.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


def sample():
    world = dict(id='original-world', width_cells=512, height_cells=512,
                 generation=3, revision=3, tick=0,
                 material_sha256='1'*64, world_material_sha256='2'*64)
    obs = dict(protocol=m.PROTOCOL, type='observation', episode_id='ep',
               record_id='obs-1', sequence=1, budget={'decisions_remaining':36},
               cursor=[12,24], world=world)
    synthetic = dict(id='S1', mode='cursor_move', brush_state='up',
                     material_effect='none', cursor_before=[12,24],
                     cursor_after=[12,25], swept_xy=[[12,25]])
    host = dict(id='MOVE_DOWN_ONE', path=[[12,24],[12,25]],
                cell_budget=0, operations=[])
    action = dict(protocol=m.PROTOCOL,type='action', episode_id='ep',
                  observation_ref='obs-1',sequence=2, world_precondition=copy.deepcopy(world),
                  world_postcondition=copy.deepcopy(world), cursor_before=[12,24],
                  cursor_after=[12,25], path=[[12,24],[12,25]],
                  candidate_id='MOVE_DOWN_ONE', mode='cursor_move', brush_state='up',
                  execution_status='selected',native_receipt_ref=None,
                  native_receipt_artifact=None)
    return synthetic,obs,action,host


def check(items):
    synthetic, obs, action, host = items
    return m.cursor_wire_preflight(synthetic_action=synthetic,observation=obs,
       native_action=action,host_candidate=host,
       accepted_m1_schema_sha256=m.M1_SCHEMA_SHA256)


class AdapterTests(unittest.TestCase):
    def test_valid_proposal_is_explicitly_not_native(self):
        result=check(sample())
        self.assertTrue(result['structural_cursor_semantics_compatible'])
        self.assertFalse(result['native_qualified'])
        self.assertEqual(result['sequential_native_receipts'],0)
    def test_real_m3_paint_action_is_not_cursor_only(self):
        v=list(sample());v[2]['mode']='add_material';v[2]['brush_state']='add'
        v[3]['operations']=[{'shape':'rectangle','material':58,'x0':12,'x1':12,'y0':25,'y1':25}]
        v[3]['cell_budget']=1
        with self.assertRaisesRegex(m.WireMismatch, 'paints/erases'):
            check(v)
    def test_committed_flag_does_not_certify_native(self):
        v=list(sample());v[2]['execution_status']='committed'
        with self.assertRaisesRegex(m.WireMismatch, 'cannot claim committed'):
            check(v)
    def test_stale_world_refused(self):
        v=list(sample());v[2]['world_precondition']['revision']+=1
        with self.assertRaisesRegex(m.WireMismatch, 'Stale'):
            check(v)
    def test_material_post_change_refused(self):
        v=list(sample());v[2]['world_postcondition']['world_material_sha256']='3'*64
        with self.assertRaisesRegex(m.WireMismatch, 'changed material'):
            check(v)
    def test_crosses_host_path_refused(self):
        v=list(sample());v[3]['path']=[[12,24],[13,24]]
        with self.assertRaisesRegex(m.WireMismatch, 'Host and native path'):
            check(v)
    def test_wrong_schema_refused(self):
        v=sample()
        with self.assertRaisesRegex(m.WireMismatch, 'schema identity'):
            m.cursor_wire_preflight(synthetic_action=v[0], observation=v[1],
               native_action=v[2], host_candidate=v[3],
               accepted_m1_schema_sha256='0'*64)
    def test_macro_length_and_bends_checked(self):
        v=list(sample());v[0].update(id='S2',swept_xy=[[12,25],[12,26]],cursor_after=[12,26])
        v[2].update(cursor_after=[12,26],path=[[12,24],[12,25],[12,26]])
        v[3]['path']=[[12,24],[12,25],[12,26]]
        self.assertEqual(check(v)['full_sweep_cells'],2)
        v[0]['swept_xy'][1]=[13,25]
        with self.assertRaisesRegex(m.WireMismatch, 'deviates'):
            check(v)
    def test_bool_coordinate_refused(self):
        v=list(sample());v[0]['cursor_before']=[True,24]
        with self.assertRaisesRegex(m.WireMismatch, 'Invalid bounded'):
            check(v)
    def test_empty_or_oversized_budget_refused(self):
        for value in (0,37,True):
            v=list(sample());v[1]['budget']['decisions_remaining']=value
            with self.subTest(value=value), self.assertRaisesRegex(m.WireMismatch, 'budget'):
                check(v)
    def test_stop_is_not_movement(self):
        v=list(sample());v[0]['id']='STOP'
        with self.assertRaisesRegex(m.WireMismatch, 'not a D-1A movement'):
            check(v)

if __name__ == '__main__':
    unittest.main()
