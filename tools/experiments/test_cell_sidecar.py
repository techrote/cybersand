import struct,unittest
from collections import Counter
import cell_sidecar as e
import summarize_cell_sidecar as s
class SidecarTests(unittest.TestCase):
 def test_budget_order(self):
  p=e.plan();self.assertEqual(len(p),1400);self.assertEqual(Counter(r['mode'] for r in p),{0:56,1:672,2:672})
  for i in range(0,len(p),2):
   self.assertEqual({p[i]['member'],p[i+1]['member']},{0,1})
   self.assertEqual(p[i]['candidate'],p[i+1]['candidate'])
 def test_density_permutation(self):
  for pattern in ('clustered','dispersed'):
   values,counts=s.initial(15,pattern,4)
   self.assertEqual(sum(counts),s.T*15//100)
   self.assertTrue(all(v[4]==0 or v[4]&0x80000000 for v in values))
 def test_independent_unread_and_corruption(self):
  values,_=s.initial(1,'dispersed',0);work=[0]*32;work[29]=8192
  for pair in range(8):
   for j in range(1024):
    i=pair*2*s.N+j;v=values[i];work[28]+=sum(v[:3])+i
  data=bytearray(struct.pack('<32Q',*work))
  for i,v in enumerate(values):
   c,local=divmod(i,s.N);data+=s.CELL.pack(-129+c%4*128+local%128,-65+c//4*128+local//128,*v)
  r=s.replay(data,1,1,'dispersed',0,-129,-65,1);self.assertEqual(r['initial_water'],r['final_water'])
  data[-1]^=128
  with self.assertRaisesRegex(ValueError,'final state'):s.replay(data,1,1,'dispersed',0,-129,-65,1)
  data[-1]^=128;data[0]^=1
  with self.assertRaisesRegex(ValueError,'work replay'):s.replay(data,1,1,'dispersed',0,-129,-65,1)
  with self.assertRaisesRegex(ValueError,'size'):s.replay(data[:-1],1,1,'dispersed',0,-129,-65,1)
if __name__=='__main__':unittest.main()
