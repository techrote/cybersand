import unittest,tempfile,struct,json
from pathlib import Path
from collections import Counter
import cell_epoch as e
from summarize_cell_epoch import summarize
class EpochDriverTests(unittest.TestCase):
 def test_plan(self):
  p=e.plan();self.assertEqual(len(p),280);c=Counter(r['comparison'] for r in p)
  self.assertEqual(c['bridge'],28);self.assertEqual(c['epoch'],140)
  for i in range(0,len(p),2):self.assertEqual({p[i]['member'],p[i+1]['member']},{0,1})
 def test_wraps(self):
  self.assertEqual(e.wrap_ticks(8),[256,511,766,1021,1276,1531,1786,2041])
  self.assertEqual(len(e.wrap_ticks(6)),32);self.assertEqual(e.wrap_ticks(6)[-1],2017)
 def test_hold(self):
  with self.assertRaises(RuntimeError):e.measure(Path('absent.json'),False)
 def test_comparator(self):
  with tempfile.TemporaryDirectory() as t:
   a,b=Path(t)/'a',Path(t)/'b'
   base=struct.pack('<Q',22)+struct.pack('<qqHBBh',-1,128,3,255,12,315)+bytes(120)
   a.write_bytes(base+struct.pack('<QQ',1,0));b.write_bytes(base+struct.pack('<QQ',2,0))
   self.assertEqual(e.equal_frames(a,b),1)
   with self.assertRaises(ValueError):e.equal_frames(a,b,keep_hash=True)
   b.write_bytes(b.read_bytes()[:-1])
   with self.assertRaises(ValueError):e.equal_frames(a,b)
 def test_clear_identities(self):
  with tempfile.TemporaryDirectory() as t:
   p=Path(t)/'run'
   p.with_suffix('.clears.csv').write_text('tick,ns,chunks,cells\n256,100,2,32768\n')
   header='tick,x,y,cells,active_blocks,selection,active\n'
   p.with_suffix('.clear-chunks.csv').write_text(header+'256,-1,0,16384,1,0,1\n256,0,0,16384,0,2,0\n')
   self.assertEqual(len(e.read_clears(p,8,True,256)[1]),2)
   p.with_suffix('.clear-chunks.csv').write_text(header+'256,-1,0,16384,1,0,1\n256,-1,0,16384,0,2,0\n')
   with self.assertRaises(ValueError):e.read_clears(p,8,True,256)
 def test_timing_hash_only_normalization(self):
  with tempfile.TemporaryDirectory() as t:
   a,b=Path(t)/'a',Path(t)/'b'
   work=struct.pack('<15Q',*range(15));body=struct.pack('<Q',0)+bytes(120)
   a.write_bytes(work+body+struct.pack('<QQ',1,0));b.write_bytes(work+body+struct.pack('<QQ',2,0))
   self.assertEqual(e.normalized_timing(a,1),e.normalized_timing(b,1))
   changed=bytearray(b.read_bytes());changed[8]^=1;b.write_bytes(changed)
   self.assertNotEqual(e.normalized_timing(a,1),e.normalized_timing(b,1))
 def test_incomplete(self):
  with tempfile.TemporaryDirectory() as t:
   p=Path(t)
   for name,value in [('plan.json',e.plan()),('identity.json',{'plan':e.plan()}),('results.json',[])]: (p/name).write_text(json.dumps(value))
   with self.assertRaises(ValueError):summarize(p)
if __name__=='__main__':unittest.main()
