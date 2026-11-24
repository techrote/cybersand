---
title: ObjectShard M4 completion source and evidence recovery
status: Historical
document-kind: audit
scope: Frozen intake identities for the 24 November ordinary Workbench completion mission; historical evidence is not final-candidate qualification
last-reviewed: 2026-11-24
related-documents: [2026-11-23-objectshard-m4-composite-occupancy-native.md, 2026-11-23-objectshard-m4-receipt-pacing-windows-matrix.md, ../research/objectshard-001.md, ../research/objectshard-m3-preflight.md]
---

# ObjectShard M4 completion source and evidence recovery

The owner authorized OBJECTSHARD-M4-COMPLETION-001 on 24 November 2026:
complete the ordinary interactive Workbench integration, native ownership and
chemistry, physical structures, lifecycle, performance investigation and a
source-bound Windows evaluator. The candidate remains Draft/HOLD. The authority
excludes merge, Ready, default activation, material-compatibility bypass and
unqualified production runtime publication. PUBPRES, Equipment, Actor Compose
and RAMCACHE development branches are outside the implementation scope.

## Frozen live source intake

GitHub metadata was refreshed on 24 November, rather than treating the older
PR descriptions as current source identities. Every listed donor was open,
Draft and unmerged at intake.

| Role | PR | Exact source at intake |
| --- | --- | --- |
| Accepted main | — | `00cdb02f103265b6dc5224c68283e9a0c8cb449f` |
| M0 ownership and Rapier handoff | #726 | `28fa42a5ad05d49fee96d1bba7252aaf36abf331` |
| M1 continuing chemistry | #728 | `1b85782a15565bad7e4dae28755b17d630daaf46` |
| M2 exchange | #730 | `dc4282e5f5f9b886315e8450613740d265f5fbc3` |
| Stability/playability finisher | #738 | `44abd754d014a44078a41792d2d46967a9b8cf30` |
| M3 continuous-play rehearsal | #741 | `febfad1b0b1ee93dac8d5b5a76f145b9ab80ad0a` |
| Native M4 seam | #751 | `a06537555002c12ffde231bfa051575a64bc16ca` |
| Workbench M4 seam | #752 | `351c5a78ebf7a6f71650ecc6b092ef36123badbe` |
| Principal candidate | #754 | `a12636c28519543d9359d6b2abb5a9767857427d` |
| Requested receipt-pacing evaluator | experiment branch | `0d9cbdf215c083f0e97726ab175f1dae55ca997e` |
| Intake including subsequent CI-cost correction | experiment branch | `ceb6c0d90599362ce28a85232179118a415deab4` |

The principal branch is `integration/objectshard-m4-mainline-20261122`.
The newer source is `experiment/objectshard-m4-main-receipt-pacing-20261123`.
`git merge-base a12636c2 0d9cbdf2` returned the exact principal tip. Therefore
the experiment is a descendant that preserves the principal and its donors;
its positive native seam must be recovered before further implementation.
The subsequent `ceb6c0d9` change only suppresses repeatedly running the costly
four-way pacing workflow on unrelated source edits. It does not supply new
runtime evidence.

The mission uses isolated native, gameplay and qualification worktrees and a
separate integration branch. Existing donor refs and historical evidence are
preserved. Source changes are reviewed and committed before integration.

## What the recovered Windows evidence establishes

Run [45111514463](https://github.com/techrote/cybersand/actions/runs/45111514463)
uses exact source `0d9cbdf215c083f0e97726ab175f1dae55ca997e`, official Windows
Godot 4.7 (`5b4e0cb0f`) and Rapier2D 0.35.2. The recovered test logs contain:

| Executed family | Successful checks |
| --- | ---: |
| Native same-World extension | 27 |
| Existing Main Rapier space | 13 |
| Cut, motion, witnessed Wood edit and retirement | 44 |
| Compact intermediate motion packets | 9 |
| M3 worker rehearsal | 41 |
| Total | 134 |

The genuine moving-cell correction selects a currently published Structural
Wood cell. The earlier 39-check failure selected an Empty border cell and
remains a historical failed result. The successful physical chain includes
120 real Rapier/native motion steps; it is not a scripted animation.

Run [45111035466](https://github.com/techrote/cybersand/actions/runs/45111035466)
at `5e1638c7b062ce2b1fe994042ac0def27a993301` measured 0/4/8/12 ms receipt
rendezvous with unchanged native compilation inputs and matching material/pose
digests. Semantic throughput was 8.26/18.12/26.39/29.86 ticks per second.
The 240-tick profile used 954 actual Rapier substeps and 60 Sand/Water/Fire
inputs. The intermediate receipt change had separately suppressed 713 full
snapshot rasterizations from 1,512 worker receipts in its Linux profile.

These are attributed to their original source, workload and platform. They do
not establish completed ordinary Workbench authoring, current-candidate
conservation, or displayed NVIDIA performance. The owner's observed active-body
display rate below 10 FPS remains an unresolved physical acceptance result.

## Intake defects and engineering direction

The experiment attaches policy to the ordinary native World, but the ordinary
moving-cell worker method deliberately refuses every request. The native GCR
caller still clears the combined transient field before composing it again;
a later admission failure can therefore erase previously valid shard coverage.
Explicit native retirement drops the coordinator while owned inventory may
remain. Ordinary authoring paths need accounting and mutation observation.

The completion work must repair those paths, install actual revisioned bodies
in Main's existing Rapier space, coordinate static terrain replacement, publish
source-bound material/pose witnesses, and provide usable ordinary Workbench
controls. The positive attachment tests and M3 rehearsal cannot stand in for
those end-to-end checks.

## Evidence custody and qualification boundaries

Recovered artifact hashes and raw log inventories are retained by the
qualification track. New test and package records must carry their own exact
source and native compilation input identities. A locally available GCC 14.2 /
binutils 2.44 build is development evidence with explicit toolchain drift;
it cannot impersonate the pinned source-bound CI build.

The source checkout initially lacked the companion documentation files used
by the normal CI layout. The five missing expected-fact inputs are recovered
from the workflow's immutable companion commit
`6a58311982941b75f46e22109a0829e5acb83c7e`, without editing the retrieval
expectations. Retained production runtime manifests also predate the native
source. They remain separate from a newly qualified experimental evaluator.

Final completion, performance and owner-pending decisions belong to the
subsequent qualification record, not this frozen intake audit.
