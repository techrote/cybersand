---
title: MAT-003 reconciliation after the physical-timeout diagnostic main advance
status: Current
document-kind: audit
scope: Import landed PR241 through the unmerged MAT stack, preserve completed and superseded checks at their recorded sources, and require fresh integration evidence
canonical-for: []
last-reviewed: 2026-10-24
related-documents: [2026-10-24-mat003-post-240-integration-checkpoint.md, 2026-10-24-mat003-lcb001-integration-checkpoint.md, 2026-10-24-issue-233-physical-regression-timeouts.md, 2026-10-24-issue-200-policy-foundation.md, ../operations/testing-validation-and-replay.md, ../reference/status-and-roadmap.md]
---

# MAT-003 and the landed #241 diagnostics — 2026-10-24

## Current main and the preceding evidence

At 09:40:23 UTC, main advanced from
`a395e33dc0632f5c3f41e8b8b1c18c89f0aaa131` to
`4348516aba4c8e7036370d73afc14e86a19ea6a2`, merging
[PR #241](https://github.com/techrote/cybersand/pull/241). Main retains
[PR #239](https://github.com/techrote/cybersand/pull/239)'s bounded defaults-only
#200 foundation and [PR #240](https://github.com/techrote/cybersand/pull/240)'s
worker/allocation-failure regressions. #241 changes regression diagnostics,
three physical-test progress markers, the GDExtension workflow and a separate
manual stress apparatus. It changes no production Native runtime source.

The [post-#240 checkpoint](2026-10-24-mat003-post-240-integration-checkpoint.md)
preserves the **15 current-source and seven scoped workflow passes** completed
by 09:11 UTC on the earlier main `1e032e4` and its exact stacked heads. Their
run links, original failures, cancellations and unchanged retries remain
historical evidence. Those results do not qualify a later head or runner.

The next reconciliation incorporated `a395e33` and was still executing when
main advanced again. Its completed checks are retained at these exact heads:

| PR | Superseded exact head | Completed ready Documentation/materialized provenance |
|---|---|---|
| #208 | `c4887789048cf90636d68e93c8d07a7aab1745dd` | [40082216346](https://github.com/techrote/cybersand/actions/runs/40082216346) |
| #211 | `e149c207eb8e25c8c7e65716f9ab95e58a04f354` | [40082311532](https://github.com/techrote/cybersand/actions/runs/40082311532) |
| #221 | `dc55df6ddebd9773cf55af2cce468fef6cc68425` | [40082313647](https://github.com/techrote/cybersand/actions/runs/40082313647) |
| #235 | `1a5aa3741cb6c10ea0b322bc73e40f39bc3d031d` | [40082316116](https://github.com/techrote/cybersand/actions/runs/40082316116) |
| #238 | `61edd2c5d98e54de24cf523acd9a493e2b210d39` | [40082317275](https://github.com/techrote/cybersand/actions/runs/40082317275) |

Those ready-state provenance steps actually executed; draft synchronization
passes with provenance skipped are separate. Current verifier contracts passed
at [#235 run 40082214856](https://github.com/techrote/cybersand/actions/runs/40082214856)
and [#238 run 40082214741](https://github.com/techrote/cybersand/actions/runs/40082214741).
The latter executed the actual v4 historical publication check. S0 storage
passed in [40082216227](https://github.com/techrote/cybersand/actions/runs/40082216227),
and S2F source/twin checks passed in
[40082215247](https://github.com/techrote/cybersand/actions/runs/40082215247);
their sealed artifacts and independent reader outcomes retain their own scope.
The S1 World changed-input guard selected no new collection; its qualified
historical source and retained earlier result remain explicit.

Current Native/Godot execution at these superseded heads was incomplete at the
main advance. Some build jobs had completed, but no complete new Native/Godot
PASS is claimed here. Any intentional cancellation during supersession is
recorded as superseded work, not as an assertion failure or a successful test.
Partial logs and metadata remain retained, and any eventual outcome keeps its
exact old source identity. No result is silently carried onto the next head.

## Fourth reconciliation and preservation

This reconciliation imports main `4348516` into #208 and propagates merge
ancestry through #211, #221, #235 and #238. It preserves the prior heads and
checkpoint records. The incoming [#233 audit](2026-10-24-issue-233-physical-regression-timeouts.md)
and its canonical procedure additions are imported exactly from main; the
earlier #200 audit additions remain intact. Registered MAT historical audits,
experiments, controls, archives, producer revisions and the v4 registration and
nine revised readers are unchanged. Separate source branches and unrelated
primary-checkout work remain untouched.

New main contains **679 protected blobs** across Native, Godot, dependencies,
CI/checker/LCB/documentation tools and core build/current-gate files, and
**781 non-documentation paths** overall. Upstream current-source bytes are
preserved; the existing five MAT workflow wrappers retain their separately
documented historical-checkout boundaries. They do not change registered
apparatus or reinterpret historical outputs against a new World.

The **56 canonical runtime source inputs** are unchanged, and the published
Windows/Linux Native runtime identities and provenance remain unchanged. The
provenance's **394 build inputs** are a sealed historical build snapshot at
`c8f14c7bc18d6ed8349d568cb00e47a826313cf9`. Test and CI files in that build map
may differ in the current source; they are validated against the recorded build
revision, not falsely asserted equal to the new checkout. Current runtime
source equivalence is established separately by the 56 canonical source-input
hashes and actual runtime bytes. This import requires no runtime republication.

Main adds the exact retrieval question `TEST04` and changes no prior question
object. The union has **124 questions at #208/#211**, **142 at #221/#235** and
an expected **147 at #238** after propagation. All original MAT objects and the
frozen question file are preserved. `TEST04` retains the unchanged 180-second
failure bound, source/run/attempt binding, 600 physical attempts plus 20
preflights, and separate diagnostic/repair ownership.

## New required checks and unchanged authority

Fresh Documentation/materialized provenance, Native, GDExtension/Godot and
applicable scoped checks are pending on the new heads. Native **94 per mode**
and Godot **139 total / 127 Windows-applicable cases** remain expected source
counts, not claims of completed execution. The new ordinary GDExtension
**physical regression timing distribution** job is part of the required workflow
outcome. Its source-bound aggregation must retain missing or timed-out evidence;
a previous runner result cannot qualify these new diagnostic semantics.

The separate `physical-timeout-stress.yml` workflow is manual and is **not
dispatched by this task**. Importing it does not complete #233, identify the
cause of earlier stalls, start #234's repair/watchdog, or establish zero-timeout
qualification under #232. The ordinary physical-case timeout remains 180 seconds.
No paired MAT timing campaign or new performance acceptance is admitted.

Final head/base pairs, tested merge parents/tree equality, run IDs, decoded
logs, artifacts, versions and command limits belong in the PR reports once
the new checks finish. GitHub-reported execution, independent artifact/hash
inspection, characterization and contract-model results remain distinct.

No PR is merged or issue closed by this reconciliation. #204 and independent
scientific acceptance remain open. #213's closed final Gates A–E PASS and landed
evidence remain valid. The #200 foundation remains defaults-only, all 90 candidate
arms remain blocked, and #212, pressure/inertial ports, changed defaults,
schema/ABI freeze and Rapier integration remain outside scope.
