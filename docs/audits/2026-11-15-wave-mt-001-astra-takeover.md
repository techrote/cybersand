---
title: WAVE-MT-001 PR 631 ownership and qualification
status: Current
document-kind: evidence
scope: Independent Astra takeover from the repaired PR 618 source; branch isolation, mandatory qualification, runtime custody and owner acceptance boundaries
canonical-for: []
last-reviewed: 2026-11-15
related-documents: [2026-11-15-wave-mt-001-completion.md, ../architecture/wave-flow-v1.md, ../operations/wave-flow-evaluation.md, ../operations/github-development-and-release.md]
---

# WAVE-MT-001 PR #631 Astra takeover

The owner assigned [PR #631](https://github.com/techrote/cybersand/pull/631)
and only `astra/wave-mt-001-669-finisher` for implementation completion,
qualification, an independent Astra review and the Windows evaluation handoff.
PR #617, PR #618 and accepted main remain read-only. Merge, auto-merge and
production Water-default changes are not authorized. A temporary Ready state
may activate mandatory CI; it does not confer merge or human acceptance.

## Inherited custody

| Reference | Immutable identity |
|---|---|
| Accepted main | `018bd09503d7f079ddac52e225c2f7daf8d678bf` |
| Exact inherited PR #618 source/checkpoint | `2a4edafa1c0b81b1f654bab28baae0e511c9a761` |
| Inherited tree | `10ad5b378cb4aba07a2c735e8c296318177ce1d5` |
| Repaired source used by publication 8 | `764fa1ff82c3a098d55c1917b7560942effbdeff` |
| Publication 8 runtime-only append | `d8002d555bd0a8d7d4d778a55ad6c797eb42dbfd` |
| Publication 8 run | [43766546888](https://github.com/techrote/cybersand/actions/runs/43766546888) |

The [original completion record](2026-11-15-wave-mt-001-completion.md)
retains numerical law version 2, the state-hash correction, the reviewed
protected-source transitions and the distant-mask overflow repair. Its earlier
results describe their recorded source identities, not this successor's final
HEAD. No inherited evidence or protected-source hash is rewritten.

## Ownership repair

The inherited workflows could not qualify this PR as requested: the full
480-row Windows scene matrix and 48-process accepted-main control admitted only
PR #618, and the runtime publisher could write only its old branch. The takeover
adds #631 to the explicitly scoped performance campaign and moves every Wave
publisher branch condition, helper check and final destination exclusively to
the owned #631 branch. A regression exercises successful context admission on
the new branch and refusal of the former owner's ref or workflow identity.
The old branch's committed workflows remain unchanged.

Publication request 9 authorizes fresh source-matched Linux and Windows
libraries and the extracted Windows evaluation package. Although this routing
change does not change the numerical law, these workflows are exact build and
qualification inputs, so predecessor binaries alone cannot satisfy the complete
new publication ledger. Source checks, target-OS execution, ABI limits, four-file
staging and the atomic branch-tip lease remain intact.

## Admission repair: ASTRA-631-001

An independent engineering audit reproduced a refusal-before-mutation defect
in the inherited native API. `World::set_cell_state(10, 10, Water, 0, 1)`
converted the requested Water tuple to Empty before the lower-level
`write_cell` guard could reject unsupported coherence. On an occupied Water
cell it returned success, removed all quantity and changed physical identity.
The inherited reproduction reported `refused=0 accepted=1 hash_unchanged=0`.
Godot's fill/brush admission already rejects coherence; this was a public native
setter gap, not a new numerical-law failure.

Commit `66b7107dca129b85f5bcb1099b4d60149f87f429` adds the same Wave-only
coherence refusal at the public setter entry, before normalization or any
mutation. The lower-level defense remains. A separate auditor inspected the
four-line repair and its regression: no ordinary World behavior, quantity
codec, physical hash version, material identity or Wave law version changes.

The new registered case fails against the inherited source and checks the
repair with one/four workers, zero/positive/full-uint16 mass, occupied Water,
hard terrain, resident Empty and absent chunks. Refused attempts preserve
complete physical/state hashes, quantity ledger, chunk count, hard-surface
revision and healthy status. Valid Wave zero-mass erasure and historical
default-off coherent-zero normalization remain explicitly accepted. The
standalone suite now contains 30 cases; final hosted sanitizer and complete
runtime results remain separately required.

The identical new case was compiled with GCC 14.2.0 against the inherited
native source and the repaired native source. The former exited 1 with one
failure; the latter exited 0 with one pass, each reporting 30 registered cases.
These focused local controls establish the repair and do not replace the final
hosted normal/ASan-UBSan/TSan or deployed-runtime evidence.

The inherited optimized suite separately passed 29/29 and the repaired suite
passed 30/30, each with exit 0. The repaired executable SHA-256 is
`6d6f13da59e3a3ccb9146e60b17ed7fed995883aa629ee98fb9a4d4e66d7ade3`.
The source tree reviewed and compiled locally is
`c72a922a9023b2c06716b77ec0fab0efa0bfc8dc`, identical to the retained repair
commit. An extracted mask-clipping helper also matched 251,944 boundary/random
intersections against a signed-128-bit oracle under UBSan. That arithmetic
probe does not substitute for public-World or deployed mask execution.

The reviewed protected-source transition is appended; all previous transition
entries and the immutable catalogue lock remain unchanged:

| Field | Value |
|---|---|
| Path | `native/src/world.cpp` |
| Previous LF SHA-256 | `09a34956642a203ae9b725875f0773001ab70bc22b478a904588604c7de866c1` |
| Repaired LF SHA-256 | `911ac9df96c34f7bbc24e9de8b53099ba779ff6cc999c6ff349b61e4379ee143` |
| Retained source commit | `66b7107dca129b85f5bcb1099b4d60149f87f429` |
| Regression LF SHA-256 | `153a9a4f548de967a86019ad2fd10cabe666e431f179e01131e0b7573cc45d8d` |

Future integration must retain this commit in ancestry, using a history-preserving
merge. The source repair invalidates both native runtimes, so request 9 includes
the repaired setter and all 30 registered regressions in fresh qualification.

## Final qualification and review contract

The final [PR #631 ledger](https://github.com/techrote/cybersand/pull/631)
records the source/tree, runtime append, exact final CI head, run/job/attempt
identities, raw artifacts and package digest after they exist. This preparation
record does not claim those pending results. Required evidence comprises:

- Native Wave normal, ASan/UBSan and TSan execution; full applicable Native,
  protected-source, ABI, compatibility and Water controls.
- Source-built Windows and Linux Godot suites, the actual graphical Wave
  fixtures and original per-case coverage/custody readbacks.
- All 480 matched complete-tick rows and 48 alternating accepted-main/candidate
  processes with source, executable and host identity; retain p50/p95 timings
  and negative results without inventing a performance PASS threshold.
- Both runtime input ledgers and actual bytes; an independently extracted
  Windows ZIP, payload hashes, import, Wave tests and delivered `Test It.cmd`.
- A fresh, separate Astra reviewer after qualification, with the entire diff,
  original evidence, package and limitations. Blocking findings require repair
  and renewed applicable qualification before the owner handoff.

The package opens the dedicated Wave Flow evaluation through `Test It.cmd`.
It uses native Workbench actor/coupling infrastructure and the real Needle;
it does not add Wave to the ordinary Shared Workbench solver menu. The
[evaluation guide](../operations/wave-flow-evaluation.md) owns the controls and
ten fixtures. Physical Windows 11/NVIDIA observation remains the owner's gate.
Wave stays experimental, opt-in and default off, with the existing persistence,
chemistry, buoyancy and falling-momentum limitations.
