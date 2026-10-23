---
title: MAT-003 Windows correctness verifier repair and readback-only admission proposal
status: Current
document-kind: audit
scope: Repaired resident sleep/exclusion witness, focused verifier-only qualification and proposed immutable-evidence full readback; no candidate execution or timing
canonical-for: []
last-reviewed: 2026-10-23
related-documents: [2026-10-23-mat003-reentry-correctness-attempt.md, 2026-10-23-mat003-reentry-build-admission.md, 2026-10-23-mat003-resident-reentry-repair.md]
---

# State and boundary

This checkpoint repairs only the independent MAT-003 correctness verifier that
refused the completed Windows 152-process archive. Production Cell/World source,
candidate binaries, the original reader, all prior failures, accepted experiments,
performance registrations, LCB and GEN-006 remain unchanged.

The repair branch is based exactly on PR #221 head
`7648e94fd8954d235ffd2723dc67b290dfe2e9e3`. The revised verifier source was
frozen before registration at commit
`2df156468931ae9d7abdd088a99376b450004a6d`.

The original campaign remains immutable:

- execution registration SHA-256:
  `9b1dbfb70d90102b1a95a9fedb360daab7e1d14036b13757bbeb05d1cc5dc59e`;
- executable source:
  `e655166989661617cd8d6cb4d58a71b9d88c9467`;
- 152/152 processes exited zero, with empty stderr and no watchdog stop;
- complete retained archive SHA-256:
  `5c658fb6a5df41e36e539a442d739d4316e4cfbc8a2460da31ac850bceb0e948`;
- original frozen readback remains REFUSED at
  `resident-015/event/B` with
  `resident sleep/exclusion witness absent`.

No new candidate process, build, benchmark or timing path was executed by this
repair.

# Source-proven sleep/exclusion invariant

The old predicate required every block of one inactive selected chunk to have
`quiet_ticks >= 3`. That does not match native World.

The checked source establishes:

1. `World::Chunk::ActivityBlock` initializes with `active=false` and
   `quiet_ticks=0`.
2. `World::finish_tick` immediately skips already-inactive blocks, so a block
   that was never activated legitimately remains at quiet zero forever.
3. An active selected block is made inactive only when its quiet counter reaches
   `sleep_after_quiet_ticks`; the same branch records `PhysicsEvent::BlockSleep`.
4. When no block remains active, the containing chunk is marked inactive and its
   chunk-level quiet counter is set to the sleep threshold irrespective of
   untouched block counters.
5. Phased exclusion does not age excluded active blocks. Narrow-to-wide re-entry
   wakes newly included inactive resident blocks at `begin_tick`, resets their
   quiet counter and records `PhysicsEvent::BlockWake`.

The repaired verifier therefore requires a two-part, non-vacuous sleep witness:
an internally consistent inactive selected chunk containing at least one inactive
block exactly at the sleep threshold, **and** a nonzero cumulative BlockSleep
diagnostic. Untouched inactive blocks may remain at zero. It separately requires
the deliberately excluded resident chunk `(3,0)` to remain active with at least
one sub-threshold active block.

Across B/P/Q/R it additionally requires monotonic cumulative sleep/wake counters,
no fabricated activity event between co-timed B and prepared P, and a strict
BlockWake increase from Q to R. Final R active flags are intentionally not used
as the re-entry proof because four subsequent ticks may legitimately sleep a
woken block again.

This does not relax cell decode, state, temperature, work, conservation,
scheduling, refusal, exact-state or cross-arm checks.

# Retained evidence compatibility

The independently retained refusal diagnosis already inspected all 384 resident
B/P/Q metadata observations. Every one contains:

- no old all-blocks-aged witness;
- an inactive selected chunk with at least one aged inactive block; and
- an active excluded chunk.

The archive also retains every R endpoint and cumulative physics diagnostics.
Given the source path above, the aged inactive blocks imply actual BlockSleep
events, while the narrow-to-512 transition necessarily wakes previously inactive
resident blocks and therefore increments BlockWake. No new observation is
required by the repaired predicate.

Accordingly, the complete 152-case archive is **sufficient for a full
readback-only requalification** if and only if the revised source/protocol is
independently admitted and the owner separately authorizes that exact readback.
This is a sufficiency determination, not correctness acceptance.

# Isolated verifier changes

Exact canonical-LF SHA-256 values for the frozen verifier source at
`2df156468931ae9d7abdd088a99376b450004a6d`:

| File | SHA-256 |
|---|---|
| `tools/experiments/mat003_correctness/world_oracle.py` | `b007036867c1fc2d03a224373e331561e8487fef59f1e7bfbac4ad279d6156c4` |
| `tools/experiments/mat003_correctness/readback.py` | `3224f005be4b2630139e773d7f1c80b041f7a69c9752431dcc783a04e6a8f9f2` |
| `tools/experiments/mat003_correctness/negative.py` | `88303f04dc0d5fd6556f004e679353e23c61e31c85d46e5d57758d6f5c18f0cd` |
| `tools/experiments/mat003_correctness/test_verifier_contracts.py` | `a53ca86913df5b5572523d5db21fb9e5920294536d985cd2ab1e550148ea8791` |

The focused fixture set preserves every prior negative contract and adds:

- positive mixed quiet3/quiet0 inactive blocks;
- all-unaged inactive blocks with no sleep transition;
- missing excluded activity;
- contradictory excluded chunk/block activity;
- missing/wrong block ownership;
- contradictory inactive-chunk/block activity after clear;
- prepared-clear activity-event fabrication;
- absent Q-to-R re-entry wake;
- the pre-existing excluded-Sand early-simulation and failed-reentry controls.

The focused verifier-only command is:

`python3 -B tools/experiments/mat003_correctness/test_verifier_contracts.py`

It exercises 32 rejection fixtures, the positive mixed-history fixture and all
704 independent decoder cross-check records without executing a candidate. The
first v2-focused run failed on fixture isolation as recorded below. After the
isolated fixture correction, v3 verifier run
[39989952813](https://github.com/techrote/cybersand/actions/runs/39989952813)
passed at PR head `95d999b7fa62ada7ebdbd046524e0e5cb2dc9a61`; provider-policy validation also
passed. Documentation/provenance run 39989952723 passed at the same head. Native
and Godot jobs remained intentionally skipped for the draft PR. This qualifies
the focused verifier contracts only; it is not a full archive readback or Windows
correctness acceptance.

# Readback-only registration

The first v2 proposal, SHA-256
`130dc475363585dd7d14095305d398d7cfcbb0cccd722b0ee5e802181b11ee7f`,
was **not admitted**. Focused verifier-only run
[39989589419](https://github.com/techrote/cybersand/actions/runs/39989589419)
exposed a synthetic-fixture isolation error: the prepared-clear negative also
caused a later counter regression, so it was rejected by the wrong guard. No
candidate/readback evidence ran. The v2 bytes are preserved and its refusal is
recorded in
`windows-reentry-readback-registration-v2-disposition.json`.

The current versioned proposal is
`docs/audits/mat003-correctness-2026-10-23/windows-reentry-readback-registration-v3.json`.

Canonical-LF v3 registration SHA-256:

`4869725932a59bdaad7ede819e520a352c8b9764bbffa019a8e000009add0344`

It binds the original archive/execution identity, revised verifier hashes,
complete 152-case/full-record coverage, semantic and cross-arm obligations,
negative fixtures, resource limits, failure rules and archive nonmutation.

The registration explicitly records:

- `independent_source_protocol_admitted=false`;
- `owner_readback_authorized=false`;
- `original_campaign_authorization_reused=false`;
- `full_revised_readback_executed=false`;
- zero candidate processes and zero builds allowed.

The original execution authorization therefore does not authorize this changed
reader.

# Qualification and independent admission

A dedicated GitHub-hosted verifier-only workflow runs the focused Python contract
suite without candidate execution:
`.github/workflows/mat003-correctness-verifier.yml`.

Repository/documentation qualification remains the ordinary documentation,
M11, retrieval, CI-provider and whitespace gates.

**Independent source/protocol admission is still required.** The implementation
author cannot self-certify it. An independent reviewer must inspect the frozen
verifier source, this audit, the v2 registration, the original refusal record and
native activity semantics, then publish an exact-hash PASS or REFUSE disposition.
Until that exists, the full revised readback is prohibited.

After independent admission, the owner must separately authorize the exact v2
registration hash before one complete revised readback is permitted. Any failure
must be retained; no retry, subset, omission, reconstructed evidence or candidate
rerun is permitted.

# Current disposition

- Verifier defect: **repaired in isolated experimental source**.
- Positive/negative contract suite: **focused v3 CI qualification PASSED (run 39989952813)**.
- Immutable archive sufficiency: **YES, conditionally for readback-only use**.
- Independent source/protocol admission: **PENDING**.
- Owner authorization of changed readback: **ABSENT**.
- Full revised readback: **NOT EXECUTED / STOP**.
- Windows correctness acceptance: **REFUSED pending the gates above**.
- Production carrier decision: **unchanged and not made**.
