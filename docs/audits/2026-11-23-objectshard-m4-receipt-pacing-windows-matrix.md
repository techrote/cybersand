---
title: ObjectShard M4 real Windows bounded receipt-pacing evidence
status: Experiment — Draft/HOLD, owner GPU FPS acceptance open
last-reviewed: 2026-11-23
---
# OBJECTSHARD-M4-PACING-001: exact native material/physical output, bounded Main receipt budget

## Owner acceptance blocker

The original Windows owner reports sustained displayed frame rate **below 10 FPS while Rapier bodies are active** in the previous M4 experimental evaluator. This has not been reproduced or cleared on the owner's NVIDIA machine. Existing M4 ordinary Workbench value transport also remains distinct from the M3 live physics rehearsal. No normal defaults or production source are authorised for promotion.

## New exact-controlled Windows physical benchmark

Workflow [45111035466](https://github.com/techrote/cybersand/actions/runs/45111035466), scripts at 5e1638c7b062ce2b1fe994042ac0def27a993301, official Godot 4.7 and Rapier2D 0.35.2. Reused a Windows DLL crossbuilt and qualified at ca72bbd387082dc54c1fab26b73c6d55b7549154 **only after rechecking SHA256 for all 117 native C++ compilation inputs**, whose contents were exactly identical on the new source. This is an explicitly source-compatible **diagnostic reuse**, not a fresh full production source-bound runtime.

Four actual 240-tick 3-body native/Rapier experiments, 954 real substeps, 60 live Sand/Water/Fire edits each. Source-exact final snapshots, all 240 material+geometry+pose publication digests, native accounting, physical contact body IDs and actual physics step counts matched across all four modes; no refused tests. All process callback measurements were headless Windows; **they are not user-NVIDIA display FPS.**

| Bounded main receipt pump | Semantic ticks/sec | p95 semantic interval | p95 process callback | p95 bounded pump work |
| --- | ---: | ---: | ---: | ---: |
| 0ms (poll) | 8.2558 | 126.846ms | 16.678ms | 0ms |
| 4ms | 18.1247 | 59.858ms | 16.678ms | 5.701ms |
| 8ms | 26.3913 | 37.862ms | 16.675ms | 9.582ms |
| 12ms | 29.8590 | 30.888ms | 16.674ms | 13.558ms |

A receipt-pump budget is **soft**. A handler already executing can exceed it. The 8ms experiment is selected by default only in the M3 **experimental evaluator**, balancing semantic progression against Main-thread time. The 12ms mode may improve throughput but consume significant rendering headroom. Keep 0/4/8/12 modes available for one-machine comparisons.

## Correctness evidence

The standalone physical rehearsal remains a single exclusive native worker World, with all Rapier RIDs owned on Main. Native motion applied acknowledgement, collision contacts, Water/Fire chemistry, pose revision and actual stable occupancy remain mandatory. Intermediate success receipts may omit only an unpublished full material screenshot; the final receipt keeps exact material and pose. No native timestep, gravity, bounce, velocity, sweep, collision parameter, or real physical substep was changed.

The separately tested actual native owner-local M4 same-World/Rapier physical-chain moving Wood edit **passes 44/44** on official Windows Godot 4.7 and Rapier 0.35.2 at ca72bbd387082dc54c1fab26b73c6d55b7549154. The prior **39-check failure** was caused by test index 4 targeting an Empty border cell rather than Structural Wood, and the negative result is preserved in the earlier audit.

## Remaining acceptance

1. On owner's Windows/NVIDIA system run rendered M3 physical rehearsal, compare **actual display FPS** and p95 active-body frame intervals for 4/8/12ms modes, and export the bug report. The Windows CI headless 16.7ms callbacks cannot substitute for rendered FPS.
2. Achieve responsive physics **and** rendering, not merely higher semantic ticks; 26-30 semantic ticks/s is still short of the 60Hz simulation target and should not be described as full repair.
3. Native M4 ordinary Workbench commands, authoritative Rapier handoff, material edit/settle/repeat, owner reset and cross-World fences remain unfinished and must pass the normal Windows evaluator.
4. No merge, Ready promotion, normal default change or production runtime eligibility until the remaining engineering gates pass.

Evidence: https://github.com/techrote/cybersand/actions/runs/45111035466 . 
