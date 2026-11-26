import unittest
from reduce_comparison import components, contacts_on_plane, native_totals, plane, rect_points, replay_edits, source_clearance_audit

class ScalarAuditTests(unittest.TestCase):
    def test_exact_little_endian_extent(self):
        self.assertEqual(plane(bytes([58,0,0,1]),2,1),[58,256])
        with self.assertRaises(ValueError):plane(bytes([58]),1,1)
    def test_regions_refuse_overflow_and_noninteger(self):
        self.assertEqual(list(rect_points([1,1,2,1],4,3)),[5,6])
        for box in ([3,1,2,1],[1,1,0,1],[1.0,1,2,1]):
            with self.assertRaises(ValueError):list(rect_points(box,4,3))
    def test_acknowledged_edit_replay_preserves_other_cells(self):
        before=[0]*12;before[0]=13
        self.assertEqual(replay_edits(before,[[1,1,2,1,58]],4,3),[13,0,0,0,0,58,58,0,0,0,0,0])
        with self.assertRaises(ValueError):replay_edits(before,[[3,1,2,1,58]],4,3)
    def test_components_exclude_diagnostic_marker(self):
        self.assertEqual(components([13,0,58,58,0,0,58,0],4,2),[3])
    def test_catalogue_overlap_exclusions_are_counted_but_cases_stay_strict(self):
        receipts=[{'checked':12,'changed':10,'excluded':2,'refused':0}]
        with self.assertRaises(ValueError):native_totals(receipts)
        self.assertEqual(native_totals(receipts,allow_excluded=True)['excluded'],2)
        receipts[0].update(changed=9,refused=1)
        with self.assertRaises(ValueError):native_totals(receipts,allow_excluded=True)
    def test_native_contact_must_be_rechecked_on_actual_plane(self):
        row={'brief':{'relations':[{'a':'west','b':'east'}]},'arm':'retrieval_guided','native_attempted':True,
             'module_contact_result':{'ok':True,'contacts':[{'a':{'instance':'west'},'b':{'instance':'east'},'a_cells':[[1,1]],'b_cells':[[2,1]],'cell_count':1}]}}
        cells=[0]*12;cells[5]=58;cells[6]=28
        self.assertTrue(contacts_on_plane(row,cells,4,3)['satisfied'])
        cells[6]=0
        with self.assertRaises(ValueError):contacts_on_plane(row,cells,4,3)
    def test_unavailable_raw_tool_contract_is_not_success_or_failure(self):
        result=contacts_on_plane({'brief':{'relations':[{'a':'a','b':'b'}]},'arm':'hand_typed','native_attempted':True},[0]*12,4,3)
        self.assertFalse(result['applicable']);self.assertIsNone(result['satisfied'])
    def test_frozen_source_conflict_is_separate_from_selector_failure(self):
        brief={'slots':[{'region':[0,0,2,2]}],'required_empty_regions':[[2,1,2,2]]}
        cells=[0]*16;cells[6]=58;cells[7]=58
        audit=source_clearance_audit(brief,cells,4,4)
        self.assertTrue(audit['immutable_source_clearance_conflict'])
        self.assertEqual(audit['source_occupied_clearance_cells'],2)
        self.assertEqual(audit['outside_write_slots'],2)
        cells[6]=0;cells[7]=0
        self.assertFalse(source_clearance_audit(brief,cells,4,4)['immutable_source_clearance_conflict'])

if __name__=='__main__':unittest.main()
