import unittest
from summarize_state_precision import quantize,quantile,validate
class PrecisionAccountingTests(unittest.TestCase):
    def test_registered_thresholds(self):
        self.assertEqual([quantize(48,255,b) for b in (4,6,8,10)],[3,12,48,193])
        self.assertEqual([quantize(1,255,b) for b in (4,6,8,10)],[0,0,1,4])
    def test_half_up_and_exact_full(self):
        for b in (4,6,8,10):
            self.assertEqual(quantize(1,1,b),(1<<b)-1)
            self.assertEqual(quantize(1,2,b),1<<(b-1))
            self.assertEqual(quantize(0,1,b),0)
    def test_nearest_rank_retains_tail(self):
        self.assertEqual(quantile(list(range(1,101)),.99),99)
        self.assertEqual(quantile([1,2,3,1000],.95),1000)
    def test_accounting_rejects_loss_and_incomplete(self):
        rows=[{'metadata':True,'initial':3},{'tick':0,'quantity':3,'columns':[1,2]},
              {'tick':1,'quantity':3,'columns':[1,2],'visited':2},
              {'result':True,'quantity':3,'columns':[1,2],'visits':2}]
        validate(rows,1)
        rows[2]['quantity']=2
        with self.assertRaisesRegex(ValueError,'conservation'):validate(rows,1)
        rows[2]['quantity']=3;rows[2]['tick']=0
        with self.assertRaisesRegex(ValueError,'tick'):validate(rows,1)
if __name__=='__main__':unittest.main()
