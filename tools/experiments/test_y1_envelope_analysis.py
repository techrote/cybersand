import unittest

from y1_envelope_analysis import clearance, excursions, physical_rows, quantiles, registered_spec_equal


def row(tick, overlap=0, support=0):
    return {'tick':tick,'pre_overlap':overlap,'post_overlap':overlap,
            'tick_overlap':overlap,'support':{'raw_support':support}}


class EnvelopeAnalysisTests(unittest.TestCase):
    def test_only_angle_decimal_formatting_can_round(self):
        self.assertTrue(registered_spec_equal({'angle':.785398163397448}, {'angle':.7853981633974483}))
        self.assertFalse(registered_spec_equal({'angle':.78539}, {'angle':.7853981633974483}))
        self.assertFalse(registered_spec_equal({'mass':1.000000000000001,'angle':0.0}, {'mass':1.0,'angle':0.0}))

    def test_airborne_zero_is_not_clearance(self):
        rows = [row(i) for i in range(80)] + [row(80,1)]
        self.assertEqual(clearance(rows)['status'],'right-censored')
        self.assertEqual(clearance(rows)['contact'],80)

    def test_recurrence_after_sustained_run_is_retained(self):
        rows = [row(0,1)] + [row(i) for i in range(1,61)] + [row(61,1)]
        result = clearance(rows)
        self.assertEqual(result['sustained_start'],1)
        self.assertEqual(result['recurrence'],1)
        self.assertIsNone(result['terminal_start'])

    def test_one_zero_boundary_does_not_clear(self):
        rows = [row(i,1 if i in (0,3) else 0) for i in range(63)]
        self.assertEqual(clearance(rows)['status'],'right-censored')

    def test_supported_no_overlap_has_zero_latency(self):
        rows = [row(i,support=8) for i in range(60)]
        self.assertEqual(clearance(rows)['latency_samples'],0)

    def test_excursion_requires_amplitude(self):
        self.assertEqual(excursions([0,.1,-.1,.1]),0)
        self.assertGreaterEqual(excursions([0,2,0,2,0,2,0]),5)

    def test_nearest_rank_percentiles_and_max_are_distinct(self):
        result = quantiles(list(range(1,101)))
        self.assertEqual(result,{'p50':50,'p95':95,'p99':99,'max':100})

    def test_negative_comparison_keeps_water_and_bearing(self):
        original = {'rows':[{'water':255,'bearing_y':0,'support':{'candidate':'B0'},'times_us':[1]}]}
        other = {'rows':[{'water':254,'bearing_y':0,'support':{'candidate':'Y1'},'times_us':[99]}]}
        self.assertNotEqual(physical_rows(original),physical_rows(other))


if __name__=='__main__':
    unittest.main()
