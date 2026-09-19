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

Reconciled production base: `910717aac101363ec2b1b89e4041a22bc9a97b97`,
the merge of PR #55 / issue #29 into the Stage-3B production base. The #58 branch
was rebased/squashed onto that actual main after #29 landed rather than preserving
its earlier CI-only base.

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

## Final validation checkpoint

This documentation checkpoint intentionally changes no tracked native runtime input.
It exists to trigger the normal human-authored exact-head pull-request workflows
after the Actions-authored runtime publication commit.

Final acceptance still requires the resulting exact-head documentation/provenance,
native behavioral/determinism, ASan/UBSan, TSan where enabled by the normal gate,
and GDExtension/Godot regression jobs to pass. Their run identities and final head
are recorded in the issue/PR checkpoint after completion.
