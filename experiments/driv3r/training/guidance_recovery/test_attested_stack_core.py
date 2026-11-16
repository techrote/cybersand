import unittest
import numpy as np
import torch
from attested_stack_core import AttestedTrailResidual,host_trail_facts,attach_host_facts
from attested_stack_cue import AttestedGate,observe32
from topology_transfer import build
from signed_feedback import HostAdvice

class Contract(unittest.TestCase):
 def test_goal_trail_fact_is_factual_not_directive(self):
  self.assertTrue(np.array_equal(host_trail_facts([(1,2),(2,2)],(1,2),True,(2,2)),[1.,1.,0.]))
  self.assertTrue(np.array_equal(host_trail_facts([(1,2),(2,2)],(9,9),True,(2,2)),[0.,0.,0.]))
 def test_extended_menu_shape(self):
  x=np.zeros((10,29),np.float32)
  y=attach_host_facts(x,[1.,.5,0.])
  self.assertEqual(y.shape,(10,32));self.assertTrue(np.array_equal(x,y[:,:29]))
 def test_match_experimental_gate_logits(self):
  class Dummy(torch.nn.Module):
   def __init__(self):super().__init__();self.w=torch.nn.Parameter(torch.tensor(0.25))
   def forward(self,x):return self.w*x[...,7]
  torch.manual_seed(88088)
  for filter,scale in (('any',2.),('backtrack',1.)):
   exp=AttestedGate(Dummy(),scale=scale,advice_filter=filter)
   core=AttestedTrailResidual(Dummy(),scale=scale,advice_filter=filter)
   core.delta.load_state_dict(exp.delta.state_dict())
   for fam in ('hairpin','hook'):
    for outcome in ('reverse','ahead'):
     w=build(880001,1,fam,0,False,outcome)
     for mode in ('none','backtrack','continue'):
      a=HostAdvice(w)
      if mode!='none':getattr(a,'issue_'+mode)(w)
      cs,x=observe32(w,.75,a)
      x2=attach_host_facts(x[:,:29],host_trail_facts(w.history,w.goal,cs[8].legal,cs[8].target))
      self.assertTrue(np.array_equal(x,x2))
      with torch.no_grad():self.assertTrue(torch.equal(core(torch.from_numpy(x)),exp(torch.from_numpy(x))))
if __name__=='__main__':unittest.main()
