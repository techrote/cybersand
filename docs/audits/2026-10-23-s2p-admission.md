---
title: S2P independent packed-performance timing admission
status: Current
document-kind: audit
scope: Exact five-arm actual-workload qualification and independent admission of four prospective paired contrasts; owner execution authority remains pending
canonical-for: [s2p-timing-admission-2026-10-23]
last-reviewed: 2026-10-23
related-documents: [2026-10-23-mat003-continuation.md, 2026-10-23-wclear-admission.md, ../research/mat003-continuation.md, ../operations/github-development-and-release.md]
---

# S2P independent timing admission — 2026-10-23

## Decision and execution boundary

**Approved independent timing admission; execution is not authorized.** The
independent S2P verifier/apparatus reviewer `/root/independent_review`, separate
from apparatus/collector implementation owner `/root`, admits the exact four
prospective contrasts in the [admitted registration](../../tools/experiments/mat003_s2p/admitted-registration.json).
This is an independent agent review, not human peer review or owner authority.
The user authorized preparation and independent admission while requiring a stop
before dispatch until the owner authorizes the exact registration hash.

The registration sets `formal_timing_admitted=true`,
`execution_authorized=false`, and `performance_accepted=false`. The
[manual-only workflow](../../.github/workflows/mat003-s2p-timing.yml) has not been
dispatched by this review. No authority receipt was fabricated and no timing
binary was executed. PRs #211 and #221 remain draft; neither merge nor promotion
is authorized. Accepted S0/S1/S2F/S2A and completed WCLEAR evidence are preserved.

## Exact evidence and fresh independent readback

The qualification is [run 39919157903](https://github.com/techrote/cybersand/actions/runs/39919157903),
artifact `12485574778`, **3,713,276 bytes**, SHA-256
`cb63fdf9ceb769770f16cf9e0c6f49b6a8cb0c0811dad642e84fce8632dfe6a0`.
Its reported retention expires `2027-01-21T07:38:52Z`. Hosted source is
`59093d68a673c2014908a1a44846b82b885a6744`; reviewed branch/checkpoint source is
`d67e00ce53a200c76726d25b98cac8047000f4aa` on
`codex/mat003-continuation`.

On 2026-10-23 the independent reviewer checked exact ZIP/extraction equality for
all **421 files**, no duplicate members and clean ZIP integrity. The full
before/after SHA-256 inventories are identical, with no new files or mutation.
The following fresh readback on the Windows review host exited zero, with empty
stderr and no errors:

```text
python -B tools/experiments/mat003_s2p/verify.py build/mat003-continuation/s2p-39919157903 --source-commit 59093d68a673c2014908a1a44846b82b885a6744
```

It independently verified **10 builds, 10 cases and 419 sealed files**, returning
`qualification-readback-passed-timing-held`. Its result exactly equals the
embedded readback. External review output is retained outside the sealed root at
`build/mat003-continuation/independent-s2p-review-39919157903/`.
This review invoked no simulation or timing process. Native qualification ran on
GitHub-hosted Ubuntu 24.04, GCC
`13.3.0-6ubuntu2~24.04.1`, GNU ld 2.42, using the unchanged S2A compilation flags.

| Sealed item | SHA-256 |
|---|---|
| Qualified inventory | `11b2902e635838fa8a5948a43aaa492c666e716817b709cdbb1fe6f9e9949bbc` |
| Independent qualification readback | `4932449c5ff829a044b1e32272c29181858ad03700c4c3844714a937bf4c99c2` |
| Source manifest | `aa1225bf217d6bc619d27f7153866169092b0a87922adf654c2bc97a733c626c` |
| Generated-source seal | `09111e3f2497607ea6081f16790b806133f0cfdebf03b367bf37913052f30a06` |
| Binary seal | `e48f8202b65dc72ab006a440f06b6b2f76076e71585d4dafc0d173b55884822a` |
| Frozen collector | `de08d8a19e65299a2be848848c0081f9c3a0638ccfb90d14e10543fe94dd2b65` |
| Frozen independent verifier | `1d686f18d06d8459f02fbd649d693d050522a07627446ca839c86f159837bfe6` |
| Frozen actual-workload fixture | `ee795168482666cacb2bf6ad7a44211c5dc76923178b509b8146a7882734dcd3` |
| Original S2P preregistration | `2fa849cbd56674b96e537fd00f0647de52d41b660300868f5d0104ec50daf6ca` |
| Canonical LF admitted registration | `95ed476709c3e29d5c3b802c03f97a48b8658c61975b18b9c169ed322abbe68d` |
| Manual-only workflow | `eecbb081d8ce7d404b28e072f7ce54c84799617da1f857864c0de7df23c27706` |

## Qualification findings and limits

All five arms have observed/off twins in the actual active-512/four-worker
workload. Every observer-off result has zero dispatch counters. Every observed
result records 1,504 dispatch calls and 22,405 dispatched/background tasks over
the complete 376-tick execution. These counts include warmup; they are not direct
per-sample-tick participation measurements.

C64 word has size/stride 8 and alignment 8. P1 packed and P2 memcpy each retain
size/stride 9, alignment 1 at C72, and size/stride 10, alignment 1 at C80. Their
nominal 512² cell-array extents are 2/2.25/2.5 MiB respectively, excluding other
World allocations. No storage enlargement is hidden in the optimized arms.

Every case matches final content hash `4755590408775054945` and state hash
`3164311774606233619`, full material/Water summaries, input ledgers, all 256
visit/phase-work observations, and natural clear witness tick 256, epoch 255→1.
Qualification emits empty tick/input timing arrays and zero startup nanoseconds;
all clock calls are conditional on measurement mode. Observed binaries explicitly
reject measurement mode.

**Qualification limit:** this actual-workload fixture retains final hashes and
per-tick work, not complete per-tick semantic-byte records. Full-state carrier
traces, boundary values, partial/whole updates and the independent storage model
remain qualified separately by artifact `12472344560`, SHA-256
`fd3e269812bfadd737f38c2cabafd906efb15ea407cb2d4c70a820279179b0c5`.
The S2P snapshot's `candidates.hpp` and `overlay.py` match those previously
qualified files byte for byte. The fresh reader anchors all retained sources to
reviewed Git objects and checks native/prepass/S2A inputs against preserved base
`2b2a1dd64f16dc46d5e812b757de73f47df0fb2b`.

Physics diagnostics remain disabled through the unchanged S2A `WorldConfig`
default. Correctness dispatch observers are compiled out of timed binaries.
Neutral capacity is not a new material schema and this workload does not model
future added material state. Native Linux/x86-64 is the admitted platform; no
other-platform performance or general cold-gameplay guarantee follows.

## Admitted prospective matrix and interpretation

Only these four B/A contrasts are admitted:

| A | B | Question |
|---|---|---|
| C72-E8-packed, P1 | C72-E8-memcpy, P2 | Compact implementation change at identical physical layout |
| C80-E8-packed, P1 | C80-E8-memcpy, P2 | Compact implementation change at identical physical layout |
| C64-E8-word | C72-E8-memcpy, P2 | Optimized C72 versus the word control |
| C64-E8-word | C80-E8-memcpy, P2 | Optimized C80 versus the word control |

Each contrast uses seven fresh-process pairs in `AB, BA, AB, BA, AB, BA, AB`
order, giving **56 processes**. Every process uses 120 warmup ticks and 256 sample
ticks, the fixed seed-204 fixture parameter, active 512² residency and four
configured workers. The natural E8 clear at completed tick 256 remains included
in the process mean. Input cost is retained separately and excluded from
`World::tick()` timing. No new compilation is performed during timing.

The accepted S2A statistical definitions are reused prospectively: process mean
over all 256 tick observations, seven independent B-mean/A-mean ratios per
contrast, then median/min/max/MAD across ratios. Per-process tick distributions
use nearest-rank p50/p95/p99 and literal maximum. Retained ticks are not independent
process replicates. All raw tick/input observations, extrema, startup, RSS, work,
ledgers and failures must remain; incomplete matrices and selective replacements
are rejected. The independent reader leaves automatic performance acceptance
held even after a complete readback.

This creates no new timing result. Do not merge its prospective data with
accepted S2A, revise historical ratios, or manufacture an unregistered contrast
by combining independent campaigns. Even a successful result would qualify
these implementations under the registered workload; it would not establish an
intrinsic packed-layout penalty or attribute differences to cache misses or
unaligned instructions without additional evidence. E16/wide clearing, C128,
S2B, production migration and GEN-006 remain outside this admission.

## Owner authority and future manual action

**STOP before dispatch.** The owner must explicitly authorize canonical LF
registration hash
`95ed476709c3e29d5c3b802c03f97a48b8658c61975b18b9c169ed322abbe68d`
and the exact execution commit. A genuine owner-established receipt must contain
`execution_authorized` (boolean true), `approver` (authenticated repository owner),
`registration_sha256`, `decision` (`authorize-exact-registered-campaign`),
`campaign_id` (`S2P-56-001`), `scope_acknowledged`
(`active512w4-packed-access-v1`), and `execution_commit`. No affirmative owner
receipt is created by this review.

The workflow uses only `workflow_dispatch`, environment-bound input parsing,
owner/commit/registration/workflow hash checks, frozen exact-source readers and
collector, immutable artifact download/hash verification, fresh apparatus
readback, then the one exact matrix and independent result readback. Raw inputs,
observations and failures are retained for 90 days. The 100-minute job allowance
covers download/readback, the collector's 1,800-second wall budget, independent
post-readback and retention. Process timeouts remain 120 seconds. Workflow reruns
are refused. A failed campaign requires a new recorded review disposition.

**Planned publication prerequisite:** GitHub's official
[manual-run guide](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)
requires the workflow on the default branch to receive dispatch; an already run
workflow can later be dispatched against another ref. This newly prepared
workflow has no runtime validation or publication established by admission.
Publication must be separately authorized; admission grants no default-branch
merge, automatic-trigger workaround or stacked PR merge.

After publication and explicit owner authority, this PowerShell command is the
future manual action, **not an instruction to run it now**. The branch tip must
equal the receipt's exact owner-approved execution commit.

```powershell
gh workflow run mat003-s2p-timing.yml --repo techrote/cybersand --ref codex/mat003-continuation --field "registration_sha256=95ed476709c3e29d5c3b802c03f97a48b8658c61975b18b9c169ed322abbe68d" --field "owner_authority_json=$(Get-Content -Raw -LiteralPath 'OWNER-APPROVED-S2P-AUTHORITY.json')"
```

The implementation owner records the recoverable workflow commit, completes
documentation/routes and source checks, and presents the exact registration and
commit for owner authority. No dispatch or performance acceptance follows from
the present admission.

## Admission-source validation

The final workflow parsed with isolated PyYAML 6.0.3 `BaseLoader`: only
`workflow_dispatch`, literal GitHub-hosted Ubuntu 24.04, a 100-minute job budget
and unconditional 90-day artifact retention. No source/artifact placeholders
remain. All three embedded Python blocks compiled. Independent and collector
schedules agree on all 56 rows.

Six isolated negative preflight cases rejected missing JSON, an empty receipt,
an explicitly false decision, duplicate JSON keys, a wrong registration hash and
a non-owner actor. None created an accepted authority file or timing output;
no affirmative owner authority was supplied. The provider-policy check,
documentation checker and `git diff --check` passed. These are source checks,
not a workflow execution or timing result. The original three S2P failure
contracts also passed before hosted qualification.
