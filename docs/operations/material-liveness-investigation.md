---
title: Material liveness investigation and implementation admission
status: Current
document-kind: guide
scope: Accepted MAT-AUTH-002 Phase A evidence, source-scoped reproduction and unresolved H1 production boundary; historical integration permission is not current authorization
canonical-for: [material-liveness-investigation, material-liveness-reproduction, material-liveness-admission]
last-reviewed: 2026-11-24
related-documents: [../systems/materials-and-rule-kernels.md, ../systems/activity-dirty-regions-and-waking.md, material-catalogue-shadow.md, ../architecture/material-authoring-catalogue-plan.md, ../audits/2026-11-04-mat354-findings.md, ../audits/2026-11-04-mat354-correction-admission.md]
---

# Material liveness investigation

## Which gates control Phase A integration?

**The evidence-only integration is complete.** [PR #377](https://github.com/techrote/cybersand/pull/377)
merged on 4 November 2026 at `0103de80d11304388868f89f7b26c672ad6100ad`.
Its original Ready transition, independent review and guarded merge were
specifically authorized for that Phase A task. Those instructions do not
permit a later reader to promote or merge a different candidate. Use the
[current development lifecycle](github-development-and-release.md) and the
explicit authority of the new assignment.

The original intake was head `58b8d27b003c812aff24152f903b6c6123f71e5c`
and main `01f9b7c8e382ca6bdbaf0bf70c7847adc12fe0bc`. Its qualification required
source-matched focused Linux/Windows proof, all applicable checks, independent
review and a final base/head reread. Earlier Draft skips remained skips. The
[original guide](https://github.com/techrote/cybersand/blob/00cdb02f103265b6dc5224c68283e9a0c8cb449f/docs/operations/material-liveness-investigation.md)
and PR retain the complete gated procedure, sources and actual disposition.

**H1 was not repaired by that integration.** Issue [#354](https://github.com/techrote/cybersand/issues/354)
remains open at the 24 November intake. Source inspection at accepted main
`00cdb02f` still finds MoltenGlass's four-tick cooling lane and the existing
Fire/Lava/MoltenGlass reset to 180 in
[`World::update_rule_kernel`](../../native/src/world.cpp).
`World::schedule_pending_reaction_wake` still schedules pair reactions and Ice
melt/freeze, without the proposed MoltenGlass cooling-continuation branch.
This is a source check, not a fresh execution of the 552-case campaign. Preserve
H2 mutual heating and H3 generic rest; a scheduler/source transition remains
separately admitted work. Materials Lab and generated capability-consumer
acceptance do not imply that H1 was fixed.

## What does Phase A establish?

Issue [#354](https://github.com/techrote/cybersand/issues/354) has three separate
mechanisms. The [dated findings](../audits/2026-11-04-mat354-findings.md) bind the
observations to accepted production main `7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1`,
the actual compiled apparatus, retained raw outputs and platform limits.

| Mechanism | Phase A observation on its recorded source | Original bounded disposition |
|---|---|---|
| Isolated MoltenGlass cooling | A sleeping block can omit the next valid four-tick cooling opportunity. Quiet=1024 and separated active-neighbor controls execute the unchanged rule and reach Glass. | Design the smallest existing block-deadline repair; production implementation is pending. |
| Touching MoltenGlass | Visible Fire, Lava or MoltenGlass resets the countdown to180. Repeated actual execution retains touching pools. Stored temperature does not control this rule. | Preserve Current. Changing mutual heating or180 is a separate thermal/gameplay decision. |
| Generic CellularYield retry | A failed mobility draw may be followed by sleep despite a legal side. Awake controls eventually move. Current documentation preserves this legacy resting approximation. | Preserve Current. A perpetual retry policy needs separate, versioned gameplay admission. |

The investigation changes tests, tooling and documentation only. It does not
close #354, modify material laws or production defaults, migrate #353-B consumers,
or refresh #371's protected source hashes. Source/partner edits, unmasking and region re-entry
restore actual visits in the registered cases; no additional missed mandatory wake is
demonstrated. Negative and inconclusive evidence remains in the dated report.

Preserving generic legacy rest does not establish owner approval of every
material's late-rest behavior. Historical Brine desirability remains unresolved;
the evidence supplies no new constitutive heap/stress law.

## Where are the recovered evidence and final qualification?

The [recovery qualification](../audits/2026-11-04-mat354-recovery-qualification.md)
and [current evidence index](../audits/mat354-2026-11-04/evidence-index.json)
identify durable raw transport, independent reviews and exact execution sources.
Hosted run41817101140 executed source `1a06a0d88d295ed99983e7b1f6149b9fff84f1b3`
on Windows and Linux. Both552-case campaigns are independently authenticated,
and all88,384 per-step physical identities match across the two OSes. This is
cross-OS evidence; independent physical hardware is not established.

The stalled session's local raw files were never published and are unavailable
in the recovered workspace. Their failure diagnoses, identities and prior
reported results are preserved as historical records, without a claim of fresh
authentication. The preserved Phase A packet contains recovered hosted evidence and its
then-fresh recovery runs. A new passing run does not repair an old missing or failed file.
LeakSanitizer, full Godot/Web/graphics, human gameplay acceptance and production
implementation remain outside the claims; no draft-skipped job is a pass.

## How is the actual World exercised?

The [native probe](../../native/tests/material_liveness_probe.cpp) includes the
unchanged production `world.cpp` once and links its ordinary supporting native
sources. It uses the already-declared `PrecisionProbe` friend for copied,
read-only observations between ticks. There is no mock scheduler, rewritten
movement function, isolated-PRNG substitute or production instrumentation patch.

The [preregistration](../audits/2026-11-04-mat354-preregistration.md) and
[552-case manifest](../../native/tests/fixtures/material_liveness_campaign_v1.json)
fix 88,384 owner steps, decision rules and stop conditions. They cover quiet3,
quiet1024 and separated active Smoke; all four thermal phases; representative
generic viscosities; translations, activity/core/chunk seams and negative
coordinates; legal-side and blocked controls; masks, source/partner edits,
region exclusion/re-entry, owner pause and reset; protected material families;
and bounded distributed jobs with configured workers1/4.

The full Cartesian product is not claimed. Exact fixtures, variant horizons and
coordinates are authoritative in the manifest. World has no configurable seed:
the record uses `rng_seed=null` and preserves x/y/tick/stream. The four deliberately
selected initial-miss witnesses are mechanism probes, not random frequency samples.

## Which observations prove execution?

Native material-specific diagnostic counters establish actual stationary generic
or MoltenGlass flow entries. MoltenGlass-to-Glass conversions account for a
thermal return before flow. These fixtures contain no Water quench that could
misattribute that conversion. Counts are whole-World subject-material totals;
only singleton fixtures bind them to a particular source. Pool and distributed
counts remain aggregate. Specialized controls report unavailable kernel counts
as null, never zero.

`TickStats.visited_cells` counts selected traversal and can include cells rejected
by body masks. A block marked inactive can still be scanned when another block
selects the same64×64-cell core. Neither selected visits nor activity state alone
proves a particular kernel ran or was omitted. A prospective deterministic draw
is not proof that an asleep or previously converted source consumed it.

Raw rows also retain the material/a/b/stored-temperature tuple, actual World tick,
thermal phase, legal sides, visible heat, block quiet/deadline state, source edits,
known mask/region interventions, scheduled jobs, observed claimants, health, independent census checks,
exact Water quantity, allocations, memory and per-step physical hashes. Worker
parity compares full hash sequences at matching physical configuration. Quiet
threshold comparisons use the relevant cell tuples, because configuration and
the active-neighbor control intentionally differ.

Configured worker capacity is a limit, actual scheduled jobs are dispatched
work, and `TickStats.worker_threads_observed` is the maximum number of distinct
task claimants in one phase dispatch. A tiny one-job fixture can expose only one
claimant even with capacity4. The distributed64-chamber cases supply enough
independent jobs to require evidence of multiple actual claimants; configuring4
alone does not establish concurrency. Full per-step physical-state hash parity
remains a separate check from task participation or speed.

## How can the campaign be reproduced?

For a deliberate reproduction, select the exact intended apparatus/source and
record it before running the campaign. Use a clean checkout, a C++20 compiler and
Python3. Outputs must go to a new directory outside the checkout. The runner
authenticates all27 protected sources, records source commit/tree and actual
compiler dependency inputs, and refuses production drift. A later source is a
new attempt; retain a guard refusal rather than refreshing old hashes to obtain
a pass. The campaign bounds below are its own registered scientific contract,
not the generic application watchdog.

```sh
python3 -m unittest discover -s tools/material_liveness -p 'test_*.py'
python3 tools/material_catalogue/compatibility.py --check
python3 tools/material_liveness/run.py \
  --plan native/tests/fixtures/material_liveness_campaign_v1.json \
  --output /absolute/outside-checkout/mat354-normal --mode normal
python3 tools/material_liveness/reduce.py \
  /absolute/outside-checkout/mat354-normal/campaign.json \
  --output /absolute/outside-checkout/mat354-normal/reduction.json
python3 tools/material_liveness/analyze.py \
  /absolute/outside-checkout/mat354-normal/campaign.json \
  --output /absolute/outside-checkout/mat354-normal/analysis.json
```

The [tool guide](../../tools/material_liveness/README.md) owns exact flags,
supported sanitizer modes, trace schema, Windows build setup and lossless raw
transport commands. `--allow-dirty-apparatus` is diagnostic only; it cannot qualify
a campaign. A process has60 seconds, the build900 seconds and the entire campaign
1800 seconds. Bounds may be shortened, never extended after a failure.

The runner publishes complete stdout/stderr atomically without overwriting an
existing artifact and verifies all raw hashes again before reporting execution.
`EXECUTED` still requires independent reduction to qualify. The reader checks
receipt, source/guard, process results, raw identities, exact step/epoch coverage,
health, quantity and worker/repeat parity. The independent scientific reader then
reports causal witnesses; partial authenticated subsets remain explicitly
unqualified as complete campaigns.

ASan/UBSan normally requests leak checking. After the retained local LeakSanitizer
environment failure, an explicitly separate `--mode asan-ubsan --disable-leak-check`
attempt can establish only address/undefined-behavior coverage. It does not
establish leak freedom. Sanitizer execution, ordinary execution and physical
parity are separate evidence claims.

## What is preserved when a run fails?

For each new attempt, retain every process outcome, partial raw output, original
receipt and independently detected integrity failure. Do not update an old receipt to match
changed raw bytes. A corrected apparatus gets a new source identity and output
directory. The first complete ordinary attempt's truncated distributed-Paste
output, the separate executable-mode loss and the LeakSanitizer environment
failure remain historical failures in the [dated ledger](../audits/2026-11-04-mat354-findings.md),
with the missing-original custody limitation stated explicitly.

Versioned transport shards hold zlib/base64-encoded original bytes, inventories
and hashes. Unpacking authenticates the entire bundle before writing new files.
Transport authentication does not upgrade scientific qualification: unpacking a
failed campaign must reproduce its failure. Executables and object files are
not committed; receipts preserve their identities and reproducible build inputs.

## What may a later implementation change?

The [ranked admission memo](../audits/2026-11-04-mat354-correction-admission.md)
proposes a targeted change to the existing deadline helper in protected
`native/src/world.cpp`. Retain the earliest strictly future period4/stream192
opportunity only when an unchanged visible MoltenGlass cell can still cool,
convert, or reset a countdown different from180 under the existing law. Hot180 fixed points
should rest. Reuse job-owned coalesced block wakes and current phase/barrier,
mask, region and source-epoch semantics; do not create per-cell timers.

Production implementation requires separate owner authorization and a narrowly
reviewed #371 compatibility transition, followed by the appropriate runtime
rebuild, LFS publication and provenance qualification. The present evidence does
not authorize a thermal profile, generic perpetual retries, a scheduler framework,
or changes owned by #355/#358/#347/#370/#373/#201. Issue #354 remains open for
those production decisions. The evidence PR's readiness and integration were authorized only for its
recorded Phase A task; they do not grant current Ready/merge authority.
