---
title: ObjectShard 001R owner-evidence forensics and first reproduced repairs
status: Historical
document-kind: audit
scope: Dated experimental evidence; initial repair checkpoint, not final integrated qualification or owner physical acceptance
last-reviewed: 2026-11-22
related-documents: [../research/objectshard-001.md, 2026-11-22-objectshard-final-acceptance.md]
---

# OBJECTSHARD-001R — forensic checkpoint

The owner-reported late rotation is reproduced on the original native runtime,
Godot 4.7 and selected Rapier. Replacing the previous sleeping-state restoration
with explicit wake after a necessary collider/mass change removes the observed
failure in controlled experiments. Rapier subsequently returns the bodies to
natural sleep. No velocity clamp, forced freeze, geometry filling, material-law
change or relaxed motion guard is involved.

This is an early checkpoint. Native admission repairs, bounded motion segments,
improved Lab controls, final Windows packaging and independent final-source review
are separate later qualifications. The original **10 of 74 native timing-limit
failures remain recorded failures**. This record does not replace them.

## Source and empirical inputs

- Fresh main: `662df51cd8409a52332fa7ef15d06d8ab8945aed`.
- Parent M2 #730: `dc4282e5f5f9b886315e8450613740d265f5fbc3`.
- Original qualified runtime source: `8f55a4e61b7cbb34a594f5e07e7d81d49aa58945`;
  native Linux runtime SHA-256 `dac291dfe1cebbe03859e2405afb028e187aa9a2dccd40b06d27735c368e974b`.
- Owner ZIP SHA-256: `0ba642c5253e71c07fe285999a72920c50035cf7d1b983c12a7b50f14e7c5f29`.
- Exact Godot `4.7.stable.official.5b4e0cb0f`, runtime SHA-256
  `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`.
- Selected Linux Rapier SHA-256
  `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`.

All six original JSON byte counts and SHA-256 values match the supplied summary.
They represent **five sessions**: the two D reports are successive observations
at ticks 754 and 970. The [derived owner report](objectshard-001r-20261122/owner-forensics.json)
records original identities without rewriting the exports. Reproduce verification
with `tools/objectshard/analyze_owner_evidence.py` against the extracted ZIP.

Native metrics accumulated across resets in the original runtime. For example,
session B at tick 1999 reports 2116 process-wide steps and six cumulative promotions.
The 256-event ring may omit earlier events. No World material raster, continuous
pose/velocity/sleep history, or complete process input stream is present.

## Forensic ledger

| Observed defect | Demonstrated mechanism | Remaining hypothesis or missing evidence | Discriminating experiment |
| --- | --- | --- | --- |
| Long B has owners of 4, 17 and 69 Wood cells while owner reports the main structure floating | Original discovery returns its first eligible component; an independent synthetic oracle confirms tiny components take all three slots before a 400-cell component | The original B topology and complete cut order are absent; its precise remaining component cannot be reconstructed | Simultaneous independent components, tiny discovery budget, repeated full-slot calls and release/retry |
| Owner D rotates about 39 degrees and holds at tick 970 after three geometry revisions | Applying its 198 retained edits reproduces tick 970 and all three final pose strings exactly; restoring sleep after shape replacement causes late contact failure in controlled interventions | Rapier internal contact-state causal details are inferred from the intervention, not a solver-internal trace | Unchanged, identical shape replacement, mass-only, shape-only, erosion, omitted transform restore and explicit wake variants |
| Cutting visible moving material is confusing | Original `Session.edit()` calls World even when the displayed cell is shard-owned | Exact handoff timing of each historical mouse stroke is absent | Source-owned erase with exact cell/pose/revision receipts; no World second owner |
| Capacity repeats and large searches never finish | Full slots cause repeated component traversal; a component larger than the per-call search budget restarts indefinitely | Original exports use one generic `Capacity` outcome | Cached eligibility, explicit reason codes and resumable searches checked against an independent connectivity oracle |
| Windows launcher requires manual correction | Generated `%~dp0` ends in a backslash immediately before the quoted argument terminator | Actual delivered-directory matrix still requires Windows execution | Test both packaged CMD files from spaces, parentheses, nested and Unicode roots |

## Native admission control

The original source was frozen before compiling the independent four-connected
oracle. [Its source/compiler/binary receipt](objectshard-001r-20261122/admission-control.json)
records **826 checks and four failures against desired new behavior**. These are
retained negative results, not a failed attempt reclassified as a pass.

| Controlled input | Original observed behavior |
| --- | --- |
| Eligible disconnected components of 1, 4, 9 and 400 cells, three free slots | Admits `[1, 4, 9]`; 400 cells remain World-owned |
| 128 repeated preparations with unchanged full slots | 51,200 cells unnecessarily rediscovered |
| 400-cell component, 32-work per-call discovery budget | Still `Capacity` after 2,048 calls |

The synthetic fixture establishes those mechanisms independently of the
incomplete owner B export. It does not assert that every remaining stationary
cell in the original session was eligible or within every geometry limit.

## Actual Rapier intervention

Three owner-shaped trees fall and settle naturally around ticks 437–443. Without
an intervention, they remain still through the extended control. At tick 1800,
the original geometry path can disturb rest even when reinstalling identical
geometry. Exact one-cell crown erosion gives up to approximately 19.4 degrees
of rotation and 11.54 cells of displacement in the isolated three-body fixture.

Changing only the final sleeping-state write to `false`, or omitting its old
sleep restoration, reduces that erosion fixture's maximum excursion to about
0.00316 degrees and 0.00168 cells. Omitting only transform restoration retains
the failure. Shapes remain exact, mass/COM updates remain active and bodies are
free to move and sleep through Rapier's normal solver.

The candidate also avoids replacing shape handles when the exact rectangle
publication is unchanged; cargo-only mass updates retain their rigid geometry.
Necessary shape or mass changes explicitly wake the body. The unchanged-material
control does not acquire periodic artificial wakeups.

## Retained D-action reproduction

`probe_object_shard_retained_actions.gd` executes only the 198 `OrdinaryEdit`
operations actually present in the second D export, at their recorded ticks.
Using the frozen original session/native runtime and original bridge reproduces
the owner's **tick-970 hold and all three final pose strings exactly**. Owner IDs
differ because a fresh process starts a new identity sequence.

The same actions and native runtime with the repaired bridge run to tick 3600,
with three material owners, continuing native chemistry/geometry, and natural
sleep. [Exact file and runtime bindings](objectshard-001r-20261122/rest-source-binding.json)
identify both bridge snapshots and the full retained traces.

| Measure after tick 754 | Original bridge | Repaired bridge |
| --- | ---: | ---: |
| Third body's maximum angular excursion | 45.2933 degrees | 0.001537 degrees |
| Third body's maximum lattice-origin excursion | 18.9011 cells | 0.000692 cells |
| Last semantic tick | 970, held | 3600, running |
| Exact match to original final pose strings | 3 of 3 | Deliberately different stable outcome |

The original 39-degree figure is a difference between two snapshots; the new
continuous trace measures a larger intervening maximum. Neither number is a
velocity estimate. This reproduction does not claim complete input replay,
cross-platform solver determinism, final-source acceptance, or Windows/NVIDIA
physical acceptance.

## Concurrent ownership and delivery boundary

Historical M0 #726, M1 #728 and M2 #730 heads are unchanged and restored to actual
GitHub Draft status. The new work is stacked on M2. PUBPRES #719 at
`d316c281e0abb575eb6302afc12ec44f211460ba`, PUBPRES #682, GEN-006 #725/#734,
equipment #724 and SWARM #729/#716 are read-only coordination inputs. No sibling
branch or qualification run is modified. Workbench integration preparation must
respect their accepted successors and remain opt-in, separately qualified and
Draft/HOLD. No merge or Ready promotion is authorized.
