"""Synthetic receipt regressions; no physical efficacy is inferred."""
import unittest

from analyze_gcr_qualification import compare_pair, summarize


def report(candidate='GCR', **changes):
    value = {'candidate':candidate, 'case':{'id':'sand-horizontal'}, 'mode':'desktop-asynchronous',
             'ok':True, 'completed_ticks':1800, 'rows':[
                 {'tick':1800, 'out':[0,0,0,0,0,0], 'conserved':True,
                  'result':[1,3,4,0,0,0,0,0,1,7,0,0,1,1]}]}
    value.update(changes)
    return value


class ReducerTests(unittest.TestCase):
    def test_held_packet_is_not_applied_impulse(self):
        value = report()
        value['rows'][0].update(held=True, application={'accepted':True,'bodies':[
            {'index':0,'impulse':[3,4],'angular_impulse':7}]})
        receipt = summarize(value)
        self.assertEqual(receipt['total_observed_packet_Jx_Jy_L'], [3,4,7])
        self.assertEqual(receipt['total_applied_Jx_Jy_L'], [0,0,0])

    def test_actual_application_uses_translated_scaled_wrench(self):
        value = report()
        value['rows'][0]['application'] = {'accepted':True,'bodies':[
            {'index':0,'impulse':[2.4,3.2],'angular_impulse':9.6}]}
        self.assertEqual(summarize(value)['total_applied_Jx_Jy_L'], [2.4,3.2,9.6])

    def test_absent_application_and_overlap_are_unsupported(self):
        y1, gcr = summarize(report('Y1')), summarize(report())
        self.assertIsNone(gcr['total_applied_Jx_Jy_L'])
        self.assertIsNone(gcr['peak_pre_overlap'])
        pair = compare_pair(y1,gcr)
        for key in ['pre_overlap_nonworsening','post_overlap_nonworsening',
                    'horizontal_nonworsening','registered_25percent_horizontal_gate']:
            self.assertIsNone(pair[key])

    def test_legacy_uses_applied_age_scaled_values(self):
        value = report('Y1')
        value['rows'][0]['legacy_application'] = [1,2.4,3.2,0,0,1]
        self.assertEqual(summarize(value)['total_applied_Jx_Jy_L'], [2.4,3.2,0])

    def test_multi_body_diagnostics_are_counted_once_per_body_row(self):
        value = report()
        application = {'accepted':True,'bodies':[{'index':0,'impulse':[1,2],'angular_impulse':3},
                                                {'index':1,'impulse':[4,5],'angular_impulse':6}]}
        value['rows'] = [dict(value['rows'][0], body=body, application=application) for body in [1,2]]
        self.assertEqual(summarize(value)['total_applied_Jx_Jy_L'], [5,7,9])


if __name__ == '__main__':
    unittest.main()
