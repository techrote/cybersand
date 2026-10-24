---
title: MAT-003 reconciliation after the LCB-001 main advance
status: Current
document-kind: audit
scope: Import landed PR239 through the unmerged MAT stack, preserve registered historical controls, and separate current-source integration checks from historical MAT regressions
canonical-for: []
last-reviewed: 2026-10-24
related-documents: [2026-10-24-mat003-stack-reconciliation.md, 2026-10-24-issue-200-policy-foundation.md, ../architecture/liquid-solver-family-policy.md, ../operations/mat-003prepass-registration.md]
---

# MAT-003 and the landed policy foundation — 2026-10-24

## New main and preserved checkpoints

While the first reconciled stack's hosted gates were running, main advanced at
07:01:19 UTC from `1002b9201006b572180a12cbc4c3b21fc234e8fa` to
`1e032e492cafb232e604baf6e2b823b13d779aa8`, the merge of
[PR239](https://github.com/techrote/cybersand/pull/239), source
`cc01899331bf3010a2a9a98f1e7450e4f1cfc4be`. That separately authorized bounded
#200 foundation changes native policy admission, adapters and runtime artifacts.
It is now part of the integration baseline; no separate Claude branch is edited
or merged by this task. #212 and pressure/inertial ports remain held.

The second reconciliation imports this landed main into #208 and propagates it
through #211, #221, #235 and #238 using merge ancestry. It preserves both the
original stack and these first reconciliation heads as ancestors:

| PR | First reconciliation head, retained |
|---|---|
|208|`dc2b610ef563bd395104d154302f0a97417957d8`|
|211|`c160b4509857370f8065f7d64a9cb1c9d2847260`|
|221|`7dd1373d999d91e52e6f29e9c9832f106a77da14`|
|235|`82c8aef3990e6852c17b5c3cf2bf6ff7b0ff44b3`|
|238|`f48a133c58fb7a21b57613837538b4eef45ff951`|

Completed first-pass Native, Godot and Documentation/provenance checks remain
evidence for those exact revisions against the earlier main. They cannot qualify
the new native/runtime integration. The first #238 Godot attempt's 180.005-second
MicroScenarios timeout and its single unchanged successful retry (141.337 seconds,
8,855 assertions, zero failures) remain separate retained outcomes. No watchdog
or source change was used to obtain that retry result; its cause remains uncertain.

## Historical MAT controls are immutable

The new policy-enabled World is not the World registered by the S1/S2 apparatus.
Three of S1's 31 registered control inputs now differ: `c_api.h`, `world.hpp` and
`world.cpp`. The policy headers also introduce dependencies outside the old
snapshot closure. S1 overlay tests and collectors, S2F source/twins, S2A and
continuation/S2P/C128 correctly refuse a mutable checkout that has those changes.
Changing the registered hashes would silently change the experiment and is not
part of reconciliation.

The existing untimed workflows instead select explicit immutable historical
checkouts **inside their ephemeral CI jobs**, after checking the current provider
policy and requiring the relevant current MAT apparatus files and toolchain lock
to equal that checkout. This guard fails if a later apparatus edit has not been
reviewed. The collector, candidate twins and independent reader run in the same
selected checkout; their records report its actual source revision. Relative
output paths, complete diagnostics and artifact retention stay intact.

The prepass workflow uses a distinct historical-control concurrency group. An
already running pre-reconciliation collection keeps its original group and is
not canceled when the current-source stack is published. Both hosted jobs retain
their declared limits and per-collection serial execution; no paired timing or
cross-host performance comparison is admitted by running these untimed checks.

| Historical regression | Explicit apparatus checkout |
|---|---|
| S1 World | `dc2b610ef563bd395104d154302f0a97417957d8` |
| S2F source qualification and candidate twins | `c160b4509857370f8065f7d64a9cb1c9d2847260` |
| Continuation, S2P and C128 | `7dd1373d999d91e52e6f29e9c9832f106a77da14` |

These are fresh regression executions of the registered **historical** baseline,
not MAT candidate qualification against the policy-enabled World. S0's two pinned
inputs are unchanged and its standalone checks continue in the current checkout.
Current small verifier/publication/comparison and bounds contracts also continue
in the current checkout. A MAT experiment on the new native baseline requires a
separate registration, dependency closure and qualification; this task starts no
such campaign and dispatches no MAT paired timing workflow.

## Current-source gates and final reporting

Ordinary Native, GDExtension/Godot and Documentation/materialized provenance must
execute afresh on every second-reconciled head. They use the current source and
the landed source-matched runtime publications, including the new native/Godot
policy regression. They are separate from historical MAT regression execution.
The ordinary hosted Native smoke benchmark remains characterization, not MAT
performance acceptance. No production source, runtime library or pin is changed
relative to the landed main by the MAT reconciliation.

The final source, exact head/base pairs, head/synthetic-merge tree equality, run
IDs, decoded logs, tool versions, timeouts and any failures are recorded in the PR
descriptions and the #238 integration report after checks finish. This is a
pre-CI source checkpoint, not a prediction of their result. No additional source
commit merely records a green check, because that would invalidate the tested head.

All historical audit/experiment files, registrations, v4 seal and nine revised
readers remain byte-unchanged. Retrieval retains the main-approved LCB01 update,
adds LCB02 and preserves every other prior question object; the frozen32 bytes are
unchanged. Local documentation, provider, provenance, M11, retrieval and focused
contracts are checked separately from the hosted runtime gates. Local Windows
S1 CRLF/symlink limitations remain in the earlier record; historical Linux S1
execution supplies its own platform-qualified result.

No PR is merged, #204 remains open and the scientific packet remains author
validation pending independent acceptance. #213's closed final Gates A–E PASS,
all90 blocked candidate arms, #212 hold and the prohibitions on ports, changed
defaults, schema/ABI freeze and Rapier integration are preserved.
