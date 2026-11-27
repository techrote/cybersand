#!/usr/bin/env python3
"""Adversarial policy tests: exact original contract and bounded source changes."""
from __future__ import annotations
import copy
import unittest
from gentek80_reference_inputs import assess

A="a"*64
B="b"*64
C="c"*64
BEFORE={"godot/scripts/shared_workbench.gd":A,"native/src/world_wave.inc":B}
REF={"source_commit":"1"*40,"source_tree":"2"*40,"rendering_inputs_sha256":BEFORE}
NOW={"commit":"3"*40,"tree":"4"*40,"inputs":dict(BEFORE)}
POLICY={"schema":"gentek80-merged-reference-delta-v1",
        "reference_commit":REF["source_commit"],"reference_tree":REF["source_tree"],
        "baseline_sha256":{"godot/scripts/shared_workbench.gd":A,
                           "godot/scripts/art_traffic_archive.gd":None}}

class SourceBoundary(unittest.TestCase):
  def test_original_exact_source_passes_without_policy(self):
    self.assertEqual(assess(REF,NOW)["status"],"pass")
    self.assertEqual(assess(REF,NOW)["mode"],"exact-inputs")
    self.assertEqual(assess(REF,NOW,POLICY)["status"],"fail")
  def test_explicit_changed_and_added_inputs_require_full_replay(self):
    new=copy.deepcopy(NOW)
    new["inputs"]["godot/scripts/shared_workbench.gd"]=C
    new["inputs"]["godot/scripts/art_traffic_archive.gd"]=B
    self.assertEqual(assess(REF,new)["status"],"fail")
    receipt=assess(REF,new,POLICY)
    self.assertEqual(receipt["status"],"pass")
    self.assertEqual(receipt["mode"],"declared-drift-requires-all-80-pixel-parity")
    self.assertEqual(len(receipt["changed_paths"]),2)
    cases=[]
    extra=copy.deepcopy(new)
    extra["inputs"]["native/src/world_wave.inc"]=C
    cases.append((extra,POLICY))
    bad=copy.deepcopy(POLICY)
    bad["baseline_sha256"]["godot/scripts/shared_workbench.gd"]=B
    cases.append((new,bad))
    bad=copy.deepcopy(POLICY)
    bad["reference_commit"]="0"*40
    cases.append((new,bad))
    bad=copy.deepcopy(POLICY)
    bad["baseline_sha256"].pop("godot/scripts/art_traffic_archive.gd")
    cases.append((new,bad))
    bad=copy.deepcopy(POLICY)
    bad["schema"]="other"
    cases.append((new,bad))
    removed=copy.deepcopy(new)
    removed["inputs"].pop("godot/scripts/art_traffic_archive.gd")
    cases.append((removed,POLICY))
    malformed=copy.deepcopy(new)
    malformed["inputs"]["godot/scripts/shared_workbench.gd"]="invalid"
    cases.append((malformed,POLICY))
    for candidate,accepted in cases:
      with self.subTest(candidate=candidate,policy=accepted):
        self.assertEqual(assess(REF,candidate,accepted)["status"],"fail")

if __name__=="__main__":
  unittest.main()
