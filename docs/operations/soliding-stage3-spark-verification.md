---
title: Issue 12 Stage 3 Spark packet C - independent adversarial verification
status: Planned
document-kind: runbook
scope: Independent GPT-5.3-Codex-Spark verification of integrated Stage-3 producer and connectivity work; reviewer first, tests second, no architecture redesign
canonical-for: []
last-reviewed: 2026-09-19
related-documents: [soliding-stage3-freeze.md, soliding-stage3-spark-producer.md, soliding-stage3-spark-connectivity.md]
---

# Spark packet C: independent adversarial verification

## Role

Run only after the parent has integrated the first coherent Producer + Connectivity
candidate.

You did not author the core implementation. Review the actual integrated diff and
surrounding source independently.

Default mode is read-only review. If the parent explicitly assigns a tests-only
write branch, you may add adversarial tests/harnesses but must not repair core
implementation in the same pass.

## Attack targets

Search specifically for:

- missing mutation producer routes;
- ABA paths accidentally tied to render dirty state;
- worker threads touching shared discovery state;
- pre/post barrier timing gaps;
- same-tick direct edit -> scan publication races;
- mask clear/reconfigure coordinates lost before invalidation;
- pending event accepted without pending witness;
- requested inclusion changed while stale summaries remain consumable;
- clear/move/replacement reviving old handles;
- failed tick allowing a summary/region publication;
- epoch wrap causing a false payload invalidation or unmeasured full scan;
- tile geometry overlap/gap under custom chunk/activity dimensions;
- signed coordinate/halo overflow;
- hidden O(N^2) registration or unbounded structure;
- local component truncation;
- face/diagonal confusion;
- state/temperature seam merging;
- stale cross-tile adjacency after one side revises;
- neighbor region remaining "complete" when an invalidated tile may become a bridge;
- split/merge identity bugs;
- partial region publication on frontier/capacity exhaustion;
- nondeterminism from unordered_map/worker completion;
- discovery capacity affecting World material result;
- tests that pass while affected coverage is silently untracked.

Also inspect performance instrumentation for observer effects that would invalidate
the intended comparison.

## Required verification matrix

At minimum independently exercise or audit:

- direct material/state/temperature ABA;
- worker 1/4 parity;
- mask add/remove ABA and far-mask locality;
- accepted pending explosion;
- no-write active/deadline;
- exclusion request/re-entry;
- failed tick after partial discovery work;
- chunk/tile capacity saturation;
- multi-tile ring/hole;
- cross-chunk seam;
- split and merge;
- neighbor-new-bridge invalidation;
- region frontier saturation;
- repeated local churn plus remote progress;
- deterministic digests across repeat/order variations.

Use ASan/UBSan and feasible TSan. Preserve failures.

## Finding classification

Every finding is one of:

- confirmed defect;
- evidence-backed concern;
- plausible concern requiring targeted test;
- unsupported speculation.

Give exact file/symbol/test references.

Do not redesign architecture to solve a finding. Return it to the parent.

## Tests-only mode

If explicitly authorized, add new tests/fuzz/property harnesses in files that do not
modify core implementation. A failing adversarial test is a successful review result;
do not weaken it to restore green.

## Completion

Return:

- review scope and exact head;
- findings classified by severity/evidence;
- tests/commands and raw pass/fail;
- whether every frozen Stage-3 exit item is actually evidenced;
- what must be fixed before measurement or Stage-3 admission;
- any source/platform gap you could not execute.
