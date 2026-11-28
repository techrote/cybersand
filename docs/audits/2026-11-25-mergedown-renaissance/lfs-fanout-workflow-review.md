# Same-attempt runtime distribution: workflow integration review

Specialist B, 2026-11-26. Prepared from #775 source
`120f0d0825e1fcdf9ea1ea9d8d50a0d5b32735d6`; the final source identity and hosted
qualification must be recorded after the lead freezes this repair.

## Observed defect and selected repair

Two complete GDE attempts and two complete Palette attempts at the repaired
source retained real Git LFS batch service failures. The bounded helper recovered
three original Windows cohorts in the first attempt, but repeated independent
downloads still prevented complete coverage. The second attempt includes an
original HTTP 503 after two batch timeouts. No observed failure justifies larger
retry limits, changing committed runtime bytes, or weakening a test.

The existing Windows native producer now acquires the exact committed Windows
Rapier once and retains a separate source/run/attempt-bound artifact. Its native
candidate artifact format and native build remain unchanged. Each Windows shard
downloads the separate payload, validates the original acquisition and every
byte against its own committed pointer, then installs the selected file before
the established native/Rapier and application checks.

The existing Palette plan acquires all four retained Linux/Windows native and
Rapier objects once. Each cohort requires the complete four-object manifest,
verifies every available object, and installs only its platform's two files.
There is no consumer network fallback. The existing retained-runtime provenance,
actual GL/ANGLE execution, original pixels, cache lineage, and strict six-cohort
readback remain mandatory. Historical failed attempts remain failed.

Original early second-attempt evidence is in
`lfs-hosted-repair-attempt2-early.json` (CI lane commit `55cfdd05`); the complete
first-attempt acquisition packet is `lfs-hosted-repair-attempt1.json` (commit
`39a959fa`). This source repair is distinct from those source-bound results.

## Complete budget accounting

| Phase | Before | Resulting allowance and reason |
| --- | --- | --- |
| Windows native producer | 240-minute existing envelope | 255 minutes: preserve all 240 plus moved 10-minute acquisition and separate 5-minute retention |
| Windows regression dependency step | 10-minute acquisition | 5-minute artifact download plus 5-minute verified install; same total |
| Windows regression parent setup | 4,200 seconds | Unchanged; actual workflow-step accounting test passes |
| Palette plan | 30-minute existing envelope | 55 minutes: original 30 plus 20-minute acquisition and 5-minute retention |
| Palette plan explicit steps | Four 5-minute steps | Four original 5-minute steps, one 20-minute acquisition, one 5-minute upload: 45 minutes plus existing 10-minute headroom |
| Palette runtime preparation slot | 1,200 seconds | Same 1,200 seconds, now verification/install; producer owns service acquisition |
| Palette cohort metadata | Linux 4 / Windows 5 steps | Linux 5 / Windows 6: adds one actual artifact download and preserves scheduling reserve |
| Palette execution | 19 registered cases | Same cases, watchdogs, cleanup, readback and dependency budgets |

Current derived cohort parents are Linux visual 320/320, Linux Main-cache 350,
Windows visual 330/290, and Windows Main-cache 350 minutes. Every value remains
within the supported 360-minute ceiling. Palette reducer remains 160 minutes.
No native compilation, Godot case, diagnostic, retry count, concurrency or
process-cleanup allowance is reduced.

## Complete-attempt retry entry points

Every artifact name and manifest binds the actual run attempt. Retrying only
failed consumers would omit the successful producer's new-attempt artifact and
must fail admission. Recovery must rerun the producer and all dependent
consumers together. In GDE, execution-plan and both native producers are sibling
jobs: rerun their common `ready_scope` ancestor, as the lead successfully did for
`45719650698/2`, rather than execution-plan alone. In Palette, rerun `plan`, which
now owns runtime production and is already the ancestor of all six cohorts and
their reducer. Preserve all original failed artifacts and source identities.

## Source custody and local verification

The new helper is included in Windows shard `INPUT_SCOPES` and Palette
`REQUIRED_APPARATUS`. Palette mainline path filters now include both acquisition
helpers and their owned-process cleanup dependency. Producer artifacts retain
original acquisition receipts and logs even when acquisition fails; a failed
producer prevents consumers from being admitted.

Specialist B independently ran 38 Palette controls, including a workflow-derived
parent-budget check, missing attempt admission refusal, and invalid artifact
refusal before any engine/service fallback. The unchanged 12 planner controls
also verify actual GDE preparation steps fit their original setup reservation.
Fourteen checkout-custody and 22 Windows runner controls pass. Both edited
workflows pass actionlint 1.7.12 and the existing CI provider policy gate.

These are source/workflow checks. Actual producer artifacts, cross-platform
consumer execution, full resulting-source application coverage and independent
review remain necessary before merge. No physical owner acceptance is claimed.
