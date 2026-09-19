---
title: Issue 58 Stage 3B observer lifecycle hardening audit
status: Current
document-kind: audit
scope: Observer retirement, reset/replacement failure ordering, identity exhaustion and source-matched runtime publication for Stage 3B issue 58
canonical-for: []
last-reviewed: 2026-09-19
related-documents: [issue-12-2026-09-19/stage3b-parent-decision.md, ../operations/soliding-stage3b-production-plan.md, ../operations/soliding-stage3-freeze.md, issue-12-2026-09-19/stage3-exit-review.md]
---

# Issue 58 Stage 3B observer lifecycle hardening audit

Implementation branch: `codex/issue-58-stage3b-lifecycle`.

Initial reconciled production base: `910717aac101363ec2b1b89e4041a22bc9a97b97`,
the merge of PR #55 / issue #29 into the Stage-3B production base. Final #58
integration then merges current `main` `210da4978ba020a177da99236b18cd4de10d5fc1`,
which includes PR #75's canonical worker-parity runner repair. This merge-based
reconciliation deliberately preserves the published runtime source commit
`204ae8e1ebdc1f6e782a3278804d0ac92ef871ce` and source tree
`8be7f2baac37a355c89cebc76526c57e35d807a0` in branch ancestry.

The controlling Stage-3B parent decision and production plan remain authoritative.
Stage 3A remains the bounded correctness/reference implementation and Stage 4
remains blocked.

## Lifecycle defect found

Before #58, `World::clear()` destructively cleared authoritative World state and
only then called `initialize_settled_discovery()`. That function constructed a
new `SettledWorldDiscoveryCoordinator` as the right-hand side of a
`std::unique_ptr` assignment.

If replacement construction/allocation threw, C++ assignment semantics preserved
the old coordinator because the new right-hand side had never completed. The World
authority had already been cleared, so the old discovery incarnation could remain
consumable against authority that no longer existed.

## Corrected ordering and failure policy

The implementation now retires the current coordinator with
`settled_discovery_.reset()` immediately after the existing in-tick clear guard
and before destructive World reset begins. That retirement is allocation-free.

`initialize_settled_discovery()` is also retire-first defensively. A replacement
construction failure therefore leaves the coordinator absent; it cannot resurrect
the old incarnation.

The existing World clear/reset contract is preserved rather than upgraded to an
allocate-first strong guarantee. A post-reset discovery construction failure does
not roll authoritative state back, fabricate material state, or set failed-World
quarantine. Discovery accessors retain their established neutral unavailable
behavior until a later successful clear constructs a fresh coordinator.

Actual failed-tick quarantine remains separate: the existing failed World still
marks discovery failed and refuses authoritative use until clear.

## Deterministic fault and identity coverage

A bounded one-shot testing seam,
`testing::fail_next_settled_world_discovery_construction()`, injects
`std::bad_alloc` at coordinator construction without touching simulation state.

The focused World-discovery regression exercises that seam through the real
`World::clear()` path. It proves:

- live observation followed by clear retires the old incarnation immediately;
- a successful replacement uses a strictly newer incarnation;
- repeated reset/replacement can reuse a slot without revalidating an old handle;
- injected construction failure occurs after the authoritative clear contract but
  leaves discovery absent and the World not failed;
- a discovery-unavailable World remains content-hash/work-statistics equivalent to
  a discovery-disabled control over subsequent authoritative ticks;
- a later successful clear constructs a fresh incarnation rather than reviving the
  failed replacement or any prior observer.

The settled-region focused suite adds a bounded generation-limit case proving that
slot-generation exhaustion reports `GenerationExhausted` and never wraps into an
old valid-looking handle. Existing settled-discovery tests retain their stale
incarnation and revision-exhaustion coverage.

## Source-matched runtime publication

Because `world.cpp` and settled-discovery sources are tracked inputs of the
materialized Godot native extension, the normal provenance gate correctly required
new Linux and Windows runtimes.

Exact runtime build source:
`204ae8e1ebdc1f6e782a3278804d0ac92ef871ce` /
tree `8be7f2baac37a355c89cebc76526c57e35d807a0`.

Actions run `35463292615` produced retained artifact
`issue58-source-matched-runtimes-204ae8e1ebdc1f6e782a3278804d0ac92ef871ce`
(artifact ID `10590033042`, archive digest
`sha256:1072468c445d12dfccffb9d44bbe6f45b3f0237b5c5f2414e1eded7f3eac4f51`).

Published runtime identities:

- Linux x86_64:
  `4c7803d7412ba9008b6de3d2ae4f8fef698e184956f5e9c1e308f5946475045b`,
  1,456,488 bytes;
- Windows x86_64 cross-build:
  `f7611acf0d18612b11a90f7746a2d94e6286d5660332c7bfd47351aec1e12740`,
  1,963,520 bytes.

Linux build and ABI-floor validation passed. Windows evidence is a pinned
LLVM-MinGW x86_64 cross-build only; actual Windows execution is not claimed.

The first publication job deliberately preserved its successful build artifact
after a publication-order error: an extra pre-commit repository check compared the
new staged runtimes with the old committed LFS identities. A recovery publication
then exposed that the same all-in-one checker also requires the companion workspace
checkout supplied by the normal documentation workflow. Neither failure was a
runtime/source mismatch. The retained artifact was reverified without rebuilding,
and run `35463635626` successfully published the exact bytes, manifests and LFS
objects in commit `a31b82fb54458428874824c79926586ce6e44cd7`; the one-shot
publisher deleted itself.

## Coordination and bounded scope

Issue #29 / PR #55 is merged in the #58 base. Its native ownership touched
`native/src/material_rules.cpp`, `native/include/cybersand/interaction_rules.hpp`
and `native/tests/test_world.cpp`, plus MicroScenario/workbench/retrieval
surfaces. #58 does not modify those files.

No #59 runtime-capacity conversion, #60 spatial indexing, #61-#63 sparse
producer/signals, graph/reverse-dependency work, split reconstruction/fairness,
publication/digest semantics, local observation API changes, material/intermaterial
behavior, Water tuning, or Stage-4 work is included.

No newly discovered defect was absorbed from those later packages. Their planned
work remains deferred to their owning issues.

## Independent worker-parity CI routing defect

Exact-head GDExtension validation initially exposed one failure in
`test_web_worker_parity`. Investigation proved that this was not a #58 semantic
or determinism regression.

The exact failing #58 run `35463708883`, shard-2 job `105953462439`, reported
both the nominal one-worker and four-worker samples as `workers=1`, with zero
parallel phases. Their move counts were identical at 120,283 and all 120 exported
level hashes were byte-for-byte equal; there was no hash divergence.

The same failure independently reproduces on landed base
`910717aac101363ec2b1b89e4041a22bc9a97b97` in run `35462990569`, shard-2
job `105950805298`: both samples are one worker, zero parallel phases, equal
moves and all hashes equal. It therefore predates and is independent of #58.

The transition is CI routing. At last-green source `35d0300`, run
`35452666646`, shard-2 job `105922839649` used the prior 2-vCPU regression
runner. The same parity test executed one worker versus two workers, observed 480
parallel phases, retained identical 120-hash sequences and equal move counts, and
passed. Commit `8e48ea732702e7a0b3a0f8d13136ff78f7472279` changed all Godot
regression shards to a 1-vCPU default. Its run `35462379884`, shard-2 job
`105949728031`, immediately reproduced the one-worker/one-worker refusal with
otherwise identical results.

This is expected from the current native adapter: requested
`cybersand/native_worker_threads` is intentionally clamped to
`std::thread::hardware_concurrency()`. A 1-vCPU runner therefore cannot satisfy
the parity test's independent requirement that the second arm actually execute
with more than one native worker.

The CI correction is deliberately narrow: regression shard 2, which owns
`test_web_worker_parity`, uses
`GDEXT_PARITY_SHARD_RUNNER` with a 2-vCPU Avrea default; shards 0/1/3 retain the
1-vCPU default. No simulation scheduler, material behavior, Water behavior or
parity assertion changed.

Focused run `35464828124` at head
`f04c2840562fe1c0be93b9a256e4576fb1219519` then passed the unchanged parity
test: one worker versus two workers, 480 parallel phases in the parallel arm,
120,283 moves in each arm and all 120 hashes identical.

## Final integration reconciliation

After #58's original exact-head acceptance passed, PR #75 merged the repository-wide
worker-parity runner repair to `main` as
`210da4978ba020a177da99236b18cd4de10d5fc1`. Final #58 integration therefore
merges that `main` head instead of rebasing or retaining an independent workflow
delta. The resulting branch uses PR #75's canonical `gdextension.yml` routing and
its shard-planner regression test; #58 owns no separate worker-parity CI policy.

This reconciliation changes no tracked native runtime input. The published Linux
and Windows runtimes therefore remain source-matched to
`204ae8e1ebdc1f6e782a3278804d0ac92ef871ce` /
`8be7f2baac37a355c89cebc76526c57e35d807a0`, and no runtime rebuild or
republish is required solely for this merge.

## Final validation checkpoint

Final acceptance requires the reconciled exact head to pass the normal
documentation/provenance, native behavioral/determinism, ASan/UBSan, TSan where
enabled by the normal gate, and GDExtension/Godot regression jobs. The
GDExtension workflow also executes PR #75's shard-planner unit test, so no separate
focused parity workflow is required. Final run identities and the exact head are
recorded in the issue/PR checkpoint after completion.
