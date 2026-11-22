---
title: Workbench actor sandbox protected material-source transition
status: Current
document-kind: evidence
scope: Scoped technical review of transient-body observation bookkeeping for the Draft/HOLD actor sandbox; material identities and the immutable compatibility lock are retained
canonical-for: []
last-reviewed: 2026-11-22
related-documents: [../../operations/material-catalogue-shadow.md, ../../systems/workbench-actor-composition.md, capacity/README.md]
---

# Actor sandbox material-source transition

This record concerns the owner-authorized capacity expansion in issue #737 and
Draft/HOLD PR #742. It uses the existing reviewed per-file transition contract.
It does not authorize a material-law change, a catalogue cutover, production
default promotion, merge or owner acceptance.

## Exact retained source

| Item | Identity |
|---|---|
| Accepted main comparison | `662df51cd8409a52332fa7ef15d06d8ab8945aed` |
| Protected consumer | `native/src/world.cpp` |
| Currently admitted LF SHA-256 | `ec3034850af97e790dfc3855411bba5be60c820cb623a6df62ca09c70aeb761a` |
| Candidate LF SHA-256 | `7a8ee79b188a94b54793e4241b189554e1199f86760923714d8f1d7684e08546` |
| Retained candidate source commit | `1b5001072cd703488c6c0ba566c71f12b8f21840` |
| Source-authority issue / PR | #737 / #742 |

The target is already present in the retained source commit. A read-only
inventory against accepted main found this one changed protected consumer,
26 unchanged protected consumers, and all 12 identity inputs unchanged.
The compatibility lock and its historical transition chain remain unchanged.
The guard correctly refused this unadmitted source hash before the new entry;
the original refusal is retained with the development evidence.

The source commit must remain reachable in any eventual integration. A squash or
rebase that drops it fails the existing ancestry guard. This requirement does not
grant merge authority; the PR remains Draft/HOLD.

## Reviewed change and invariants

The protected diff has four insertions and two deletions. It adds a
`body_high_water` index to the existing heap-owned transient-obstacle state,
updates it only after a valid nonzero mask ID is registered, and clears contact
and impulse observation arrays through that greatest-ever-used index. Granular
and arrival clearing retain the existing enabled/toggle behavior. Higher entries
are value-initialized zero and have never had a registered mask owner. Contact
writers retain their existing registered-mask source, including Wave's nondefault
scaled-push route that writes the same observation atomics directly.

The high-water index is deliberately not lowered when masks are cleared or their
region is reconfigured. Formerly used high IDs are therefore still cleared after
retirement and reuse. Clearing remains on the existing World owner boundary;
worker-side observation additions remain atomic. Native masks and material cells
retain their existing separate ownership.

The other change keeps the ordinary partial occupancy reservation at
`64 * 256` indices after the independent body-ID allocation ceiling grows to
4,096. This is vector reservation, not a cap: the vector still grows for admitted
occupancy, while the full-occupancy path reserves the complete finite region.
This preserves the previous allocation request for ordinary configurations.

Material descriptors, stable IDs, reaction rules, movement laws, thermal rules,
quantity storage, scheduling rules, pressure policy and serialized material
identity are unchanged. Additional admitted physical masks intentionally allow
additional body/material contacts in expanded scenes; this is not a claim that
a scene with more obstacles evolves identically to a smaller scene.

## Executed supporting evidence

| Evidence | Result and limits |
|---|---|
| Native transient-owner fixture | 14 cases at 16/32/64/128/256/512/4,096 registered IDs and one/four workers. Every case completes three ticks, keeps per-ID contact and impulse routing, preserves the fixture's authoritative material hash, refuses invalid IDs, clears retired contacts and reuses the highest ID. |
| Native sanitizers | The same 14 cases pass AddressSanitizer and UndefinedBehaviorSanitizer. LeakSanitizer is unavailable under this host's ptrace environment; its failed infrastructure attempt is retained, and no LSAN pass is claimed. |
| Material baseline native contracts | Compiled from the candidate source and executed successfully on Linux with the explicitly documented GCC 14.2 local toolchain. Includes finite baseline validation/copy paths through 2,048-square canvases. |
| Integrated ordinary Workbench regressions | Material baseline, Flatten, combined authoring and running PAINT cases pass on published source `1b500107`. Materials Lab reached its source-custody guard and correctly refused the missing transition; its repaired execution must be recorded separately. |
| Real native/Rapier composition | The expanded-boundary test revision passes 351 checks and 300 coupled gameplay ticks, admitting 64/65/4,096 native owners and refusing 4,097 atomically. This is separate from the actual logical-actor capacity matrix. |

The [capacity evidence](capacity/README.md) records actual logical populations,
native source hashes, runtime identities and limits. Native registration counts
are not interchangeable with actual Rapier actor counts. The original build,
test and guard failure logs remain in the downloadable development evidence.

## Independent review and disposition

An independent reviewer who did not author the capacity implementation gave
**GO for this exact, narrowly scoped technical transition**. The reviewer checked
the complete protected diff and inventory, source-blob hashes and retained
ancestry, every contact writer (including Wave vertical and horizontal faces),
zero initialization, monotonic retirement/reconfiguration behavior and the
synchronous worker barrier preceding owner clearing. The reviewer independently
reproduced the pre-entry refusal and reran the native material-baseline executable
successfully. No material-law or native ownership defect was found.

The reviewer requested the explicit granular/arrival toggle and direct Wave
writer qualifications above; both are incorporated. The transition appends one
entry only. The immutable lock, baseline, checker logic and all prior entries
remain byte-identical. Technical admission does not assert hosted Windows
qualification or owner acceptance.

After committing the entry and record at
`b96837e6b4448cd20a6b6fda8ced12795f04fc15`, the authenticating guard passed with
27 protected sources and 53 retained reviewed transitions. The independent
reviewer repeated that pass and verified that removing only this new block
reproduces the previous checker file exactly. The existing compatibility guard
suite passed all 41 tests.

The actual Materials Lab/Workbench author flow then passed **97 checks, zero
failures**, including isolated native comparison, deterministic repetition,
one/four-worker equality, persistence replay, quantity balance, cancellation and
preservation of shared PAINT history. Its separate fresh-process reopen passed
**35 checks, zero failures** against the retained authored userdata. The lead's
source-matched wrapper completed successfully, including its final source-input
and runtime-byte checks. The native module was the previously recorded local
Linux build `7a8bf38fcfdfa92a770a67879477a708cfceb6c606b03c3c0a5fd55b5a028a4a`;
these results are not relabeled as pinned hosted Windows evidence.

Original pre-entry refusals and the successful guard, 41-test suite, author and
reopen logs are retained together in the development evidence bundle. No failed
run was overwritten or reclassified as passing.
