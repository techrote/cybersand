---
title: SWARM-006 baseline source and revealed evidence custody
status: Current
document-kind: audit
scope: Dated read-only intake of SWARM-004/005 sources, Windows failures and revealed corpus before SWARM-006 implementation
canonical-for: []
last-reviewed: 2026-11-21
related-documents: [../systems/gentek-reciprocal-assembly.md]
---

# SWARM-006 baseline custody — 21 November 2026

This is historical intake evidence for [programme #704](https://github.com/techrote/cybersand/issues/704),
not an instruction to alter earlier candidates or accepted main. Inspection used
live GitHub PR/issue/Actions metadata and job logs plus local Git ancestry.
Every referenced PR was open, unmerged, mergeable and Draft at intake.

| Source | Exact HEAD | Parent/base custody |
|---|---|---|
| [SWARM-004 native #692](https://github.com/techrote/cybersand/pull/692) | `2c4b8061ef5315de6a31df933e9f84c31865284e` | Stacked on frozen SWARM-003 |
| [SWARM-004 Workbench #693](https://github.com/techrote/cybersand/pull/693) | `16a11ef2d25f03d58b229f4bba3f88009ebe1154` | Incorporates exact #692 |
| [SWARM-005 native #696](https://github.com/techrote/cybersand/pull/696) | `c178feeb39899fd155b7deb9d5bde3f50ee28548` | Sole parent `2c4b8061` |
| [SWARM-005 Workbench #697](https://github.com/techrote/cybersand/pull/697) | `8ec6d3c62197f3ef4088d79e4aa2910f5eaa36f7` | Explicit composition of #693 + #696 |
| [Docs follow-on #700](https://github.com/techrote/cybersand/pull/700) | `580ff82f285b7aeda8fb4a2a0d034425f0d0401d` | One-line corpus addition on #697 |

Workbench merge `ecdfd8b6` has parents `16a11ef2` and `c178feeb`. The subsequent
chain is `65353d67 → 00a3773d → 54664423 → 69828e6d → 8ec6d3c6`.
No historical source or evidence was rewritten during intake.

## Actual Windows and documentation state

Current #697 [run 44854238228](https://github.com/techrote/cybersand/actions/runs/44854238228)
passed exact native build/custody and native V3 tests, then failed actual
graphical lifecycle startup in
[job 136695261848](https://github.com/techrote/cybersand/actions/runs/44854238228/job/136695261848).
Its report has four checks, `completed=false`, and failures “real Shared Workbench
startup completed” and “complete interactive test sequence reached its final
assertion”. Device: Microsoft Basic Render Driver via ANGLE. Owner packaging
was skipped. This is not a passed V3 graphical qualification.

Docs #700 [run 44855435069](https://github.com/techrote/cybersand/actions/runs/44855435069)
also failed. Registering `operations/swarm005-workbench-playtest.md` exposed its
missing title/status/scope/document-kind/last-reviewed/canonical-for/related-documents
frontmatter. The old generic retained-runtime provenance gate remains separate;
Draft-skipped Native/GDExtension execution is not a passing platform campaign.

The older owner-tested source was `69828e6d8be1f15c7d03091602a42e6068c51446`.
[Run 44854206608](https://github.com/techrote/cybersand/actions/runs/44854206608)
passed source/pristine graphical testing, but the graphical stage invoked
inherited reciprocal 4099 and transaction 605 examples. It does not qualify the
later V3-specific style cases. Its
[outer owner artifact 14687114604](https://github.com/techrote/cybersand/actions/runs/44854206608/artifacts/14687114604)
has 94,652,674 bytes and SHA-256
`15872af36891bd1b0a4546d6aa988b0c20d56d529632cde0f03720ad82648fde`.
The misleading SWARM-004 inner filename is historical packaging behavior.
Outer and inner ZIP digests are different identities. This package is not a
SWARM-006 deliverable and cannot be renamed as one.

## Already revealed SWARM-005 cohort

[Registration #698](https://github.com/techrote/cybersand/issues/698) and its
[result comment 7055626297](https://github.com/techrote/cybersand/issues/698#issuecomment-7055626297)
retain 360 executions: 36 fixture/profile/seed cases × ten policies. Primary off/off
and both each yielded 1 Complete+Apply, 14 Blocked, 21 Exhausted. There were zero
new Apply-valid cases, zero losses and zero new qualified joints. Six blocked
cases had nine fewer requirements via legitimate source-time selection, without
becoming complete. The hard-only result 8/16/12 and fixed-territory result 5/11/20
change other dimensions and are not isolated switch effects.

Original CSV SHA-256:
`5a826358c286eec22e6f6e5cf9a0498299efde850cea11927ebe0e9a239d458d`.
An initial 90-case aggregation failed and was repeated without tuning. Those
duplicate executions are not additional independent samples. All these seeds
are now revealed development evidence for SWARM-006.

Native blank Irregular 605 at 192×112 with source-time termination became complete
with 6,026 cells and zero joints; its baseline had 6,034 cells and one unresolved
obligation. Viaduct remained blocked with 6,035 cells, one unresolved and zero
joints across all four switch settings. Neither observation establishes a new
qualified foreign-closure improvement or reproduces the owner's existing World.

## Fresh frozen-source native reproduction

Strict C++20 (`-Wall -Wextra -Wpedantic -Werror -O2`) builds of exact #692 and
#696 completed locally on 21 November. Each links a retained external comparison
harness snapshot to the unchanged donor's native objects. Their compiled native
definition hashes are respectively
`07901d11889c217ebe61e9ab3562046914a1e9e31865281fe8667b4124adbc71`
and `4ef94e7b1b13506f50318791a2c9d3f632e3eccca3889c7d12b01e0e61759365`.
The latter differs from the previously published Workbench/holdout definition
`12a4816dab749a9c872a4d531836db8ec6a170aab31576d70086efa80eeb3b6b`,
which also contains Workbench transport source. These are distinct source
footprints, not interchangeable binary identities.

The full 18-case development cohort contains six owner-related **blank synthetic
crops** and the twelve revealed SWARM-005 pilot cases. Frozen #692 OFF and frozen
#696 OFF each produced 1 Complete, 15 Blocked, 1 UNSAT and 1 Exhausted. Their full
native behavioral responses match in all 18 cases after the guide's enumerated
source identity and disabled schema-extension normalization. Both consumed
110,693,891 aggregate work units across the 18 independent executions.

| Frozen #696 treatment | Complete | Blocked | UNSAT | Exhausted | Sum of qualified joints |
|---|---:|---:|---:|---:|---:|
| Both OFF | 1 | 15 | 1 | 1 | 10 |
| Source-time terminal parts only | 5 | 11 | 1 | 1 | 10 |
| Native receptors only | 1 | 15 | 1 | 1 | 15 |
| Both ON | 5 | 11 | 1 | 1 | 15 |

The exact fixed-territory 4099 control remains Complete with 4,001 material cells,
eight qualified joints and zero remaining obligations. Its matched no-offer
and frozen-peer controls show 56 MOSAIC and 55 FRAME occupied-footprint changes;
the no-offer donor grants exactly match the candidate's 1,512,532 generator and
3,481,728 categorical-solver units. Each control is an independent execution
with separately retained native work.

The native Industrial expression default (clutter 0.35) has 6,133 cells; the GUI
default (clutter 0) has 6,051. Both remain blocked with zero joints and two
remaining obligations under all four treatments. The 128×128 Irregular blank
crop has 4,751 cells, zero joints and one remaining obligation. It does not
reproduce the owner's reported 4,889-cell, one-joint world.

All 360 already-revealed #698 executions were also rerun, with all ten published
status distributions reproduced. The primary treatments each yielded 1 Complete,
14 Blocked and 21 Exhausted; no newly Apply-valid case appeared. No failed or
exhausted execution was removed from its denominator.

Retained evidence directory names and final manifest SHA-256 values:

| Evidence set | Manifest SHA-256 |
|---|---|
| `evidence-sw004-development` (18 executions) | `d2e803dc0ed43fb1ecf6f63552ddcdaecf5b88cf4e78455d1bad72477c73dc4d` |
| `evidence-sw005-development` (72 executions) | `42454f0cbb149d661f9a5c61904bb84c3cdc06ad0e9c675f15c7228c6be3c651` |
| `evidence-sw005-revealed360` (360 executions) | `ae368bcdd4395c77116f03dec4ef21df63dc87499047a172cf21e5ccc05d7a82` |

Each contains complete native input and response JSON, losslessly compressed
with raw and stored SHA-256, binary/source receipts and process logs. Early
exhaustion retains unknown final closure counts, rather than inferring zero.
The first harness build attempt failed because quoted includes selected headers
from the harness checkout. Its log remains retained; the corrected builds compile
an external harness snapshot. The first compatibility invocation rejected an
incorrectly named schema type in the comparison tool; its failure receipt remains
retained and the corrected comparison passed 18/18. Neither failed tool attempt
was counted as a native result or hidden by replacing its output directory.

## Intake recommendation

Keep native succession on exact #696 and Workbench succession on exact #697 with an
explicitly recorded frozen-native ancestry join. Reuse the existing experimental
panel and atomic native transaction. Preserve all earlier source states,
qualifications, failures and Draft/HOLD boundaries. New raw native comparisons,
source/pristine Windows graphical execution and physical owner acceptance each
need their own exact-source receipts.

The separate [SWARM-006 experiment guide](../../native/experiments/gentek_swarm/SWARM-006-EXPERIMENTS.md)
documents the new harness's controls and evidence interpretation. It does not
preregister fresh unseen seeds or assert an implementation outcome.
