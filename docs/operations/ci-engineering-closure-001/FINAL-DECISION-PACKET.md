---
title: CI engineering closure decision packet
status: Current
document-kind: decision
scope: CI-ENGINEERING-CLOSURE-001 evidence adjudication, tooling custody, capacity limits and remaining exact-source qualification gates; no merge or production publication authority
canonical-for: [ci-engineering-closure-001-decision]
last-reviewed: 2026-11-24
related-documents: [../ci-execution-and-performance.md, ../github-development-and-release.md, ../documentation-maintenance.md]
---

# CI-ENGINEERING-CLOSURE-001 — final decision packet

**Disposition: Draft / HOLD.** This packet records engineering decisions and their
evidence scopes. It does not authorize a merge, Ready transition, runtime
publication, cancellation of another programme's work, provider migration or
production default change. The corresponding JSON is
[FINAL-DECISION-PACKET.json](FINAL-DECISION-PACKET.json). The lead owns the single
request ledger; new hosted execution is deliberately separated from recovery of
already completed work.

## Governing source and accepted improvements

Accepted main was refreshed to
[`00cdb02f103265b6dc5224c68283e9a0c8cb449f`](https://github.com/techrote/cybersand/commit/00cdb02f103265b6dc5224c68283e9a0c8cb449f),
tree `06b62d73138028d1f7615b83edc9810491bf6287`. It already contains these
independently admitted increments; this mission does not reimplement them.

| Record | Accepted merge | Preserved improvement | Evidence scope |
|---|---|---|---|
| [#714](https://github.com/techrote/cybersand/pull/714) | `846fe0533b3170e7b01f690518da49fc40cc24d1` | Existing documentation and full runtime-provenance checks run before compiling material/LCB checks. | Genuine negative admission improved 593.895 to 2.767 seconds in the original pair; this is not successful whole-CI acceleration. |
| [#722](https://github.com/techrote/cybersand/pull/722) | `30e1cddd3d678456df10f52f7a2fb2210a9daaad` | Configuration-bound local soliding object reuse removes repeated core compilation while preserving eight executables and their ordered execution. | Original complete-family pairs saved 43.40% normal and 37.03% sanitized; no whole-CI percentage follows from those pairs. |
| [#723](https://github.com/techrote/cybersand/pull/723) | `662df51cd8409a52332fa7ef15d06d8ab8945aed` | Seven mandatory worldgen showcases use the existing two-job Make budget before the nine-test principal tail; source-bound original logs are mandatory. | Original full-worldgen pair saved 29.52%; hardware, order and queue limitations remain recorded in the original PR. |

[#708](https://github.com/techrote/cybersand/pull/708) remains a separate
Draft/HOLD at `11e23b392b63dfb15ea0916c90ca8d9361d3406b`. Its Gentek publisher,
shared-download design and preflight prototypes were not admitted by the above
merges. It is not a blanket authority to alter active publishers. Earlier compiler
experiments and original red attempts remain immutable evidence.

## Current source contract and historical population limits

The independently generated
[contract inventory](current-contract-inventory.json) records actual source
planning, relevant file hashes and complete shard assignment names. It is a
local inspection result, not execution evidence.

| Obligation at accepted main | Source-derived inventory |
|---|---|
| Active workflow files | 93 |
| Native | Six families, 20 outer commands, 154 physics CLI invocations |
| Linux Godot | 340 distinct cases in 24 shards |
| Windows Godot | 317 distinct applicable cases in 23 shards |
| Palette | Six cohort jobs: ten Linux cases and nine Windows cases |
| GDExtension requested simultaneous shard caps | Linux eight / Windows eight |
| Palette requested simultaneous cohort caps | Linux two / Windows two |
| Godot safety boundary | Full 280-minute execution allowance within a 360-minute job |

The original fan-out experiment population is 338 Linux / 315 Windows cases,
not this main's 340 / 317. Therefore historical successes can establish what
happened on those exact sources and support an engineering recommendation; they
cannot qualify this integrated candidate. A PR API `head_sha` may differ from
the executed synthetic merge checkout. Exact source trees, reducer receipts and
run/attempt identities must retain that distinction.

All required Native commands, compiler flags, sanitizer settings, Linux and
Windows cases, rendered controls, platform builds, timeouts, source/input checks,
failure artifacts and independent reducers remain mandatory. Source-scope advice
always grants no Native exemption. Workflow success or a Draft-suppressed matrix
is not an independent test-coverage decision.

## Performance decisions

**Keep GDExtension at 8/8. Select only Windows Palette 2 to 3 in the isolated
Draft candidate; Linux Palette remains two.** Higher GDExtension fan-out is HOLD,
and both production RAM proposals are REJECT. The detailed
[performance analysis](../../audits/2026-11-24-ci-engineering-closure/performance.md)
and [machine-readable original evidence](../../audits/2026-11-24-ci-engineering-closure/performance.json)
retain 36 workflow attempts, 479 original job records, actual tested source/tree
identities, every historical case name, 48 RAM trials and archive digest
verification scope. They are the authoritative comparative record; the table
below is its decision summary.

| GDExtension arm | Original run / attempt | Attempt wall | Linux / Windows shard span | Realized peak Linux / Windows shards | Summed runner-minutes | Decision |
|---|---|---|---|---|---|---|
| Accepted 8/8 retry | [44967549040 / 2](https://github.com/techrote/cybersand/actions/runs/44967549040/attempts/2) | 21:13 | 617 / 803 s | 8 / 8 | 175.850 | Retain accepted configuration |
| #731 12/12 | [44974802645 / 1](https://github.com/techrote/cybersand/actions/runs/44974802645/attempts/1) | 16:50 | 451 / 605 s | 12 / 12 | 169.533 | REJECT this policy-invalid candidate |
| #735 corrected 16/16 | [44984940287 / 1](https://github.com/techrote/cybersand/actions/runs/44984940287/attempts/1) | 20:21 | 675 / 916 s | 9 / 16 | 166.750 | HOLD adoption |
| #739 final 14/18 | [44989006830 / 1](https://github.com/techrote/cybersand/actions/runs/44989006830/attempts/1) | 23:20 | 398 / 490 s | 14 / 18 | 178.067 | HOLD adoption |

Wall time is attempt start to last completed workflow job; runner-minutes sum
actual job intervals, with neither billing multipliers nor inferred prices.
Linux/Windows columns describe regression execution. The Windows native
cross-build itself runs on a Linux host. Requested caps and realized interval
overlap are independently recorded. Heterogeneous four-logical-CPU VMs, differing
images, network/checkout behaviour and uncontrolled queueing prevent a causal
whole-CI percentage claim.

The baseline's first attempt remains failed: three successful, three failed and
five skipped job records consumed 19.717 runner-minutes after GitHub TCP/443
checkout failures. Its retry's 21:13 does not erase the 37:02 elapsed from the
original event to the last GDExtension job. The 12/12 arm's Documentation run
`44974802604/1` refused its invalid scheduling policy. The original uncorrected
16/16 arm likewise retains failed Documentation `44977850017/1`, despite its
successful 15:03 GDExtension `44977849960/1`. The initial 14/18 source
`97418f385450dd12d3e450bba79b7cf0cae3076f` retains Palette run
`44985182460/1`'s LFS authorization failure; the final same-tree request does not
rewrite that failure.

All six recovered successful GDExtension attempts have 338 unique Linux and 315
unique Windows natural-completion cases, matching their complete source plans.
Their two explicit skips are the non-applicable physical stress job and Ready
scope job, not missing regression shards. All 24 Linux and 23 Windows shard jobs
and both coverage reducers are retained. The historical Windows plan's 23
graphical exclusions remain explicit; separate required graphical scopes are
not silently promoted from those headless results.

The corrected 16/16 and final 14/18 PR cohorts reached their last required
non-advisory jobs in 33:22 and 33:27 respectively, consuming 280.20 and 294.35
runner-minutes. Native was their last job. On final 14/18, Linux build time was
639 seconds and the last-shard-to-reducer tail was 357 seconds; the shorter
shard spans did not shorten the full workflow. On corrected 16/16, Linux only
realized nine concurrent shards. These observations do not establish an
asymmetric advantage or a reliable return for increasing shared runner demand.
If the owner later admits higher GDExtension concurrency, corrected 16/16 is the
simpler already policy-qualified starting point; this mission requests no new
timing campaign to reopen that question.

### Narrow Palette selection

The original comparison is baseline `44977849917/1`, source
`fea11a6061a4ca3ce0c9217bc2e124e2cfb08c24`, against #736
`44978447427/1`, source `3c9900ef426c7b50d682c569e06363e821aa31df`, tree
`4a85d204d16d27812cde4ff163ba302934dbc592`. Both plans have the same SHA-256.
The original #736 diff changes only Windows `max-parallel: 2` to `3`.

| Observed Palette measure | Windows cap two | Windows cap three |
|---|---|---|
| Linux three-cohort span | 223 s | 217 s |
| Windows three-cohort span | 351 s | 208 s |
| Full Palette workflow | 450 s | 358 s |
| Total runner-minutes | 16.867 | 16.800 |
| Windows realized peak | 2 | 3 |

This supports removing one scheduling dependency among three independent
Windows cohorts. It is one observational pair, not a guaranteed 92-second
future improvement. All six original qualification reports and 19 unique cases
are retained: ten Linux and nine Windows, including 15 rendered cases and four
deliberately headless controls. Independent review reproduced the complete
cohort plans, natural process exits, original log hashes and actual Linux
X11/OpenGL3 and Windows ANGLE contexts. The mandatory v3 reducer passed; the
separate v2 finished-image diagnostic failed on both arms and stays recorded as
diagnostic failure. No compiler observation marked unavailable is treated as a
measured compilation result. Complete frame/cache semantics remain in the
original reducer's scope. This GO selects the one-line Draft change; final
integrated-source execution and owner adoption are still HOLD.

### RAM and earlier compiler experiments

Both original RAM arms completed all 24 declared trials: three stock and three
RAM executions on each of shards 2, 6, 12 and 19. Each covers 56 distinct cases
and 336 case executions. SSD-staged-copy #732 (`44976089046/1`, source
`a7a8c90bc1c876d8d6e667b580dda7ae34a2486c`) does not measure direct RAM checkout
or build. Its execution median savings ranged from -0.014% to +2.139%.

Corrected RAM-first #733 (`44976706404/1`, source
`ffc4d1a65b7f1ce85a840948f250ebb330b5f33d`, tree
`e1b62dc9be220c8380c434bf0c58ecac42e60bc6`) actually prepared and built each arm
on its measured filesystem. Original receipts distinguish stock `ext2/ext3`
from RAM `tmpfs`, retain source/native/engine parity, alternated arm order,
memory/swap observations and preparation phases.

| RAM-first shard | Stock execution median | RAM execution median | RAM saving |
|---|---|---|---|
| 2 | 107.729 s | 108.276 s | -0.508% |
| 6 | 120.692 s | 121.238 s | -0.452% |
| 12 | 209.020 s | 209.107 s | -0.042% |
| 19 | 137.503 s | 137.761 s | -0.188% |

Preparation varied in both directions, from approximately 16.4 seconds faster
to 20.0 seconds slower on RAM. Per-arm retained caches and first/subsequent
trial distinctions are preserved; neither experiment establishes a controlled
fully cold host or a continuous whole-VM peak-memory trace. No whole-CI storage
speedup follows. Close both as useful negative research and retain their data;
do not merge either research workflow into production.

Earlier #718 and #721 remain HOLD and are not bundled. Their retained independent
analyses report respectively a 25-second (1.11%) Native-workflow gain with 5.09% more
runner time and later first functional feedback, and a 14.976-second (1.058%)
two-command compiler saving. These do not justify reopening the accepted
six-family topology or replacing the subsequent accepted #722/#723 increments.

## Publication custody and migration boundary

[#761](https://github.com/techrote/cybersand/issues/761) records a genuine
publication refusal after real Actor qualification: the Linux object was
byte-identical, both provenance documents changed, and only three tracked paths
changed. That is a valid Git outcome, not permission to reduce identity checks.
Both provenance changes remain mandatory where the owning publisher specifies
them. A native pointer can remain unchanged only after actual candidate bytes,
SHA-256, byte size, committed pointer and source-bound provenance agree.

The Actor-specific corrected implementation
[#762](https://github.com/techrote/cybersand/pull/762) and original qualified
[#748](https://github.com/techrote/cybersand/pull/748) retain their owners and
exact evidence. This candidate supplies [generic custody tooling and a migration
contract](../publication-custody.md). It neither rewrites an Actor publisher nor duplicates a privileged
workflow. PUBPRES, ObjectShard, Equipment, Art, Batch Lab and SWARM each retain
their source-bound campaign and publication ownership; #729 and its Q5 joins,
artifacts, reducers and tests are outside this write set.

Accepted main does not contain #762's later Actor-specific unchanged-pointer
fix; that implementation remains on its owner Draft branch. The
[publication evidence record](publication-evidence.json) preserves failed
`45068056417/1`, its successful verifier recovery `45073351155/1`, and later
#762 qualification `45112739808/1` as distinct campaigns. The original unchanged
Linux SO is 5,253,840 bytes with SHA-256
`1aa42ed85b2fafa31d1c521224ed9d4f8199709b41cbe8b9c1299f9c2392fb4f`.
It was checked against actual downloaded bytes and the unchanged parent/child
pointer, not inferred from a printed staging intent.

The new helper was also exercised against the actual immutable #762 source
`af13c6a3926da0749a32708a44a12b66ed5d0c7c` and its publication-only child
`47e87cb84cf302b4e283cfc7e8f884e01b7b4c73`. Its
[contract and acquisition pin](actor-custody-replay-pin.json) binds 105 native
and 1,283 build inputs, actual materialized binaries/local LFS objects, original
artifact bytes and the 42 Linux, 42 Windows and 18 extracted-Windows report/log
joins. The exact original semantic reducer was replayed separately. The
[custody receipt](actor-custody-replay-result.json) explicitly grants no new
product execution, publication authority, semantic-qualification exemption or
remote LFS storage proof. The 94 MB owner evaluator was not redownloaded; its
package-execution claim remains tied to the original retained installed-package
evidence and owning campaign.

An offline verifier replay of immutable original evidence is a new verification
result for that original campaign. It is not fresh application execution and
cannot qualify modified product source. Publication still needs an exact tested
parent, repeated branch lease, permitted changed paths, actual LFS storage and
one publication-only child. An unavailable authenticated publisher remains an
explicit gate.

## Shared capacity and operational interpretation

The bounded repository snapshot collected at **17:00:19–17:00:53 UTC on
24 November 2026** observed two assigned runner IDs on sampled running jobs (one Linux and one
Windows) and zero queued/waiting jobs. These are observations across the collection
interval, not a simultaneous runner count. This does not show account saturation and is not the
reason the final suite remains pending. The snapshot is identified in the JSON
packet; fresh admission needs a fresh observation.

The owner's previously stated 40 standard hosted slots is recorded as an
owner-reported ceiling, not an authenticated account entitlement. Repository run
and job APIs do not reveal all account activity, applicable plan limits, per-OS
limits or contention from other repositories. Lowering a Linux job cap cannot
transfer cores into a Windows VM. Requested matrix capacity, observed overlapping
jobs, VM core count, account capacity and the number of Pro sessions are separate
quantities.

[`SCHEDUSWARM.md`](../../../SCHEDUSWARM.md) remains paused, with automatic dispatch
disabled. Its three lane / two project-dispatch budget does not prove a hosted
runner limit and does not authorize a restart. The read-only refresh of
[#305](https://github.com/techrote/cybersand/issues/305) found 53 comments, ending
with the 9 November completed #542 lane; this old ledger does not establish
current ownership of the ten sessions. Current branch/source/run and the lead's
explicit request ledger are needed for admission decisions.

The [operational summary](../ci-campaign-coordination.md) is read-only. It distinguishes executing, queued,
waiting, failed, cancelled, skipped, superseded and unavailable records; partial
pagination and changing attempts cannot establish completeness. Running jobs
with a known runner identity give an observed lower bound within the queried
scope. Long-running jobs are critical-path candidates until a verified
dependency graph proves otherwise. An unverified ledger receipt remains an
unverified claim; this summary does not replace a programme's strict reducer.

Suggested staggering is advisory. No programme is automatically cancelled or
reprioritized. Ordinary supersession retains its existing PR policy; a frozen
explicit campaign is not superseded merely because its branch advances.

## Exact-source qualification still required

No heavy campaign is requested by this mission. Resulting-source execution and
owner Ready authority remain outstanding. The final Draft commit/tree is to be
pinned externally in its PR handoff after this packet is committed. Existing
`gh` has no authenticated session, and
the approved connector has no workflow-dispatch operation. The browser fallback
also did not establish a usable authenticated execution route. This capability
and authority boundary is distinct from runner contention. The lead
[request ledger](CI_REQUEST_LEDGER.json) owns the deferred request.

New `tools/ci/*.py` files are not excluded by the current Native and GDExtension
Ready-scope classifiers and do match the Palette PR filter. Thus the generic
helper candidate is not a docs-only exemption. Draft state intentionally avoids
expensive matrices while local implementation and review finish.

Before any admitted final qualification request, the lead must refresh current
ownership/queue pressure, freeze the resulting source/tree, check materialized
runtime/source integrity and state the expected runner cost from prior runs.
The minimum applicable complete cohort follows existing policy:

- Full Documentation/provenance, including all required materialized LFS objects.
- Native policy and all six real native families, followed by the exact-source
  `native` reducer; original failed logs and attempts retained.
- Linux build, Windows cross-build, all source-derived Linux and Windows shards,
  Linux graphical Art smoke and both independent complete-coverage reducers.
- The applicable Palette plan, three real Linux and three real Windows cohorts,
  retained frames/cache lineage and strict final reducer.
- Any additionally applicable scoped workflow produced by the final actual diff;
  the Native source-scope advisory never substitutes for required tests.

Do not repeat a successful timing arm for a better sample. If a scheduling cap
is later adopted, its resulting-source full suite and policy/inventory comparison
are still needed. If a generic helper is integrated into an owner publisher,
that owner must also execute the required same-source native, graphical and
freshly extracted package campaign, genuine negative controls and publication
lease/LFS checks. Local unit fixtures do not replace that execution.

The live `main` branch was unprotected and its repository rulesets collection
empty at intake. The procedural exact-head requirements still apply; this task
does not install administrative branch protection. Physical Windows/NVIDIA feel
and feature acceptance remain owner decisions wherever those gates already
apply. This CI-only mission introduces no new physical product acceptance claim.

## Independent review

The [independent review](../../audits/2026-11-24-ci-engineering-closure/independent-review.md)
records repaired status-summary, provenance/report and staged-index race findings
with exact reviewed file digests. Independent status verification passed the
final 28-test suite. Custody verification covered the 36-test suite plus four
focused race/malformed-input regressions using real temporary Git/LFS repositories
and synthetic payloads. The author's full 38-test suite and five final focused
archive checks passed; final inventory is 39 tests. Original metrics tests passed
8/8. This is
**source contract GO / hosted HOLD**.
No local fixture or metadata result is promoted to genuine product execution.

The subsequent [integrated local validation](local-validation.json) passes the
complete final 39-test custody suite in 81.031 seconds, 28 status tests, eight
metrics tests and ten scheduling tests. Provider policy, all 93 workflow graphs,
pinned actionlint 1.7.12, documentation (148 documents / 33 questions) and retained
M11 integrity pass. Repository admission passes only in pointer-only mode: 18
runtime files remain unmaterialized locally, so the strict materialized gate
remains pending. The final retrieval baseline finds 31/33 canonical routes in
its top five, retaining the existing Q19/Q32 misses; the new closure question is
rank one. Challenge retrieval finds 162/164 routes in its top five. Those lexical
results are routing observations, not semantic correctness or runtime evidence.

The Documentation workflow adds these reusable status/custody unit suites after
the existing early materialized-runtime admission and before native compilation.
Each retains the existing 300-second operation allowance inside a ten-minute
step. Existing admission, compiler tests and mandatory product gates are
unchanged. Independent source review also confirmed the Palette one-line cap
change preserves its providers, plan, cases, flags, timeouts, artifacts and
required reducer.

## Rollback and owner decisions

Accepted production main is unchanged. If the selected Palette change is later
adopted and must be rolled back, restore only Windows `max-parallel: 3` to `2`;
keep the complete matrix, plans, payloads and reducer. No GDExtension exception or
RAM workflow is introduced. The generic standalone tools and their additive
unit-test invocation can be removed without altering product/runtime data. A
later publisher migration must retain its separately reviewed rollback and
cannot rewrite an already published runtime child.

Owner decisions remain: capacity/admission policy, whether and when a fully
reviewed candidate may transition to Ready, any eventual scheduling adoption,
publisher-owner integration and merge. No auto-merge or production publication
is part of this closure candidate.
