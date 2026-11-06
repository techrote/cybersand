---
title: SOL review findings and owner decisions
status: Current
document-kind: decision
scope: Dated record of the independent #461 review, the #463 bearing-gate diagnostic, owner decisions and open recommendations from 2026-11-06; not implementation evidence
canonical-for: []
last-reviewed: 2026-11-06
related-documents: [2026-11-06-sol-contact-gravity-order.md, 2026-11-06-sol-bearing-gate-diagnostic.md, ../systems/solid-detachment.md, ../operations/github-development-and-release.md]
---

# SOL review findings and owner decisions — 6 November 2026

This record has three parts:

- what was found about SOL ordering and integration;
- what the owner decided;
- what is still only a recommendation.

Claims are scoped to the cited sources. Runtime evidence stays in the linked dossiers. The independent review of #461 is reproduced verbatim in the appendix.

## Source checkpoints

| Item | State |
|---|---|
| [#460](https://github.com/techrote/cybersand/pull/460) | Draft, `61924a9788f507620706dfa19d28dc12d819156b`, unchanged |
| [#461](https://github.com/techrote/cybersand/pull/461) | Draft, `cba3c0de35c4fae410b2fa16fa821524308c1ce8`, unchanged; review and F1 correction posted as comments |
| [#463](https://github.com/techrote/cybersand/pull/463) | Draft, evidence-only bearing-gate diagnostic stacked on #461; not for merge |
| [#464](https://github.com/techrote/cybersand/pull/464) | Draft determinism feasibility (COUPLING-LOCKSTEP-001); independently reviewed, changes required |
| [#465](https://github.com/techrote/cybersand/pull/465) | Merged to main as `554d27b1`: reconcile-freely / record-design-choices policy |
| main before #465 | `06522e300dcf91efbab0ac8f4f4370af72cf2029`; CI green; material guard passes through the reviewed World transition |

## Findings

**Review of #461** (full text in the appendix):

- **Ownership/application safety:** PASS, scoped. No path was found by which a deferred contact observation reaches a retired owner. A failed readback keeps its lease, pauses the session and blocks publication.
- **F1, the bearing gate:** originally rated High. The diagnostic later downgraded it to *mechanism engaged, causal role unproven* (see below).
- **F2, scheduling-dependent acceptance:** confirmed. Post-arm acceptance swings with publication/tick phase, from 0.20 to 0.96 across hosts and runs.
- **F3:** cross-arm Sand impulse is not a support measure. Ordinary correction clips velocity without an impulse ledger.
- **F4, low:** the default pre path now deep-copies the contact observation every accepted tick.
- **F5, low:** dropped deferred work is only in the return value; there is no counter.
- **F6, low:** an unreachable owner-mismatch branch returns without `_fail()` after Rapier has stepped.
- **Post ordering as a settling fix:** NO-GO. Original SOL clearance/CPU: not proved. Integration: not admissible.

**#463 bearing-gate diagnostic** ([dossier](2026-11-06-sol-bearing-gate-diagnostic.md)):

- The registered attribution is INCONCLUSIVE, with one eligible pair.
- The native bearing law reproduces exactly: 0 failures in 83,133 checks.
- Post engages the `velocity.y <= 0` correction gate where post Sand is accepted.
- Non-perturbation is unresolved by its registered rule. Publication/tick races also occur without telemetry.
- Packed outcomes vary strongly from run to run, so single episodes cannot carry per-pair ordering claims.

**Integration with main:**

- Main contains no SOL code; SOL exists only on the Draft #347 chain.
- The chain and main diverged at `7ef4856e`: 97 stack commits against 72 on main.
- A trial merge conflicts in 12 files: native World, native extension, simulation worker, runtime binaries and provenance, and five shared docs.
- A merged native World file needs its own reviewed MAT transition, as #394 had.
- The SOL chain carries about 7 million lines of committed audit evidence.
- Main's workbench (#394) has two relevant features:
  - a per-body granular contact law (`accumulate_workbench_contacts` in `godot/native_extension/workbench_granular_coupling.inc`), whose response budget scales with body mass;
  - a completed-sample Rapier fence (commit `055925f1`).
- The workbench law keeps the same velocity-gated positional correction (`downward > 0`).

**Determinism ([#464](https://github.com/techrote/cybersand/pull/464)):**

- An independent review found the approach sound and the results promising, but the evidence reducer needs fixes before its exactness claims are accepted:
  - the registered snapshot `serial` is omitted from comparisons;
  - matrix and artifact completeness are not validated;
  - latched-publication semantics are wrong on pause/reset;
  - custody, merge conflicts and runtime CI are outstanding.
- Same-host repeatability, native worker-count parity and a Windows/Linux `atan2` rotation discrepancy remain plausible, qualified results.

## Owner decisions

| ID | Decision |
|---|---|
| D1 | **SOL adopts main's workbench granular contact law (LA-SELECTIVE),** subject to a registered experiment on the actual cut tree and building, with repeats, packed Sand and a Sand/Water split, and unchanged mass and caps. The SOL work continues in the Codex session that produced #461. |
| D2 | **Branch reconciliation runs freely, without an approval gate.** Design choices made while reconciling are recorded in plain language under "Design choices" in the PR ([policy](../operations/github-development-and-release.md#reconciliation-and-design-choices), merged in #465). |
| D3 | **Repository auto-merge stays off.** Agents merge when green, using context. GitHub's own auto-merge never reads PR text; earlier unwanted merges came from an agent or automation enabling or performing them. |
| D4 | **No main branch protection for now.** If ever needed, use the minimal form: one always-running check, no reviews, no up-to-date requirement, admin bypass. Required path-filtered checks would stall PRs. |
| D5 | **#463 is a permanent evidence record, not for merge.** |
| D6 | **Determinism matters for future demo playback, multiplayer and A/B testing.** #464 is the feasibility step. Whether lockstep becomes universal or an opt-in mode remains an open owner decision. |

## Recommendations not yet decided

- Carry forward #460's mass fix and #461's ownership/disposition hardening. Drop #461's post-ordering arm. Apply F4–F6.
- Do not merge the ~7 million lines of SOL evidence into main history. Choose companion, LFS or archive storage first.
- Refresh long-running branches after significant main merges, and land a base before stacking more than one dependent layer.
- Move the local raw evidence to permanent storage before cleaning up worktrees. The #463 matrix (971 MiB) is under `build/sol-bearing-gate` in its worktree, and the #461 evidence is under its Codex worktree's `build/sol-contact-order`.
- For #464: repair the reducer and re-reduce the existing traces before any new runs. Then fix publication semantics and complete exact-head CI.

## Open questions

- Is the workbench law's mass-scaled budget (5–80 × load scale) enough to bear a 520-member tree in packed Sand? This is unverified.
- Does the workbench law's velocity-gated correction matter once its event impulses supply real support? This is unverified.
- Should lockstep be universal or an opt-in mode? Owner decision, after #464 is repaired.

## Appendix — independent review of #461 (verbatim)

As posted on #461 ([comment](https://github.com/techrote/cybersand/pull/461#issuecomment-6685073384)). F1 was later qualified as described above.

#### Independent adversarial review — #461 at `cba3c0de` (Draft)

Read-only review. Heads requeried: #461 `cba3c0de35c4fae410b2fa16fa821524308c1ce8`, #460 `61924a9788f507620706dfa19d28dc12d819156b`; both open and Draft; parent is an ancestor. No branches, states or guards were changed.

**Bottom line:** no ownership/lifetime defect found. The negative result holds, but the dossier's explanation is incomplete: the post arm probably worsens burial because it switches off the only positional support the ordinary path has, not only because gravity integrates before Sand acts.

#### Findings, ranked

**F1 — High. Post changes what the unchanged ordinary law sees, so ordering is not isolated.** (Mechanism shown in source and raw data; causal link not yet isolated by experiment.)
- Native granular bearing skips both its impulse and its positional correction when published `velocity.y <= 0` (`godot/native_extension/cyber_native_cell_world.cpp:858`). The correction is 0.99 × downward travel, applied only when 0 < `velocity.y` <= 4 (`:875`).
- Post applies Sand after the Rapier step and before publication (`godot/scripts/solid_detachment_session.gd:709-713`). Sand stops approach velocity, so the step's descent is published with vy ≈ 0 and the gate suppresses the correction.
- Reviewer's own reduction of raw `live-001` episodes:

| Measure | Pre | Post (high acceptance) | g·dt² |
|---|---|---|---|
| Mean published vy, steps 600–719 | 0.87 to 1.09 | −0.014 to 0.19 | — |
| Total ordinary correction (cells) | −1.9 to −2.6 | −1.3 to −1.9 | — |
| COM drop inside the step, before post Sand (cells/step) | — | 0.018 to 0.028 | 0.0256 |
| Sink rate, steps 600–719 (cells/step) | 0.0058 to 0.0078 | 0.0125 to 0.0139 | — |

- Natural control: Linux tree w1 post had 609/707 attempts refused as `StaleContactSample` (85 accepted). Its published vy was 1.91, correction recovered to −4.78, and it had the least burial of any post tree (Sand area 78.4 vs 189–194; total drop 12.7 vs 18.1–18.3 cells). More accepted post Sand went with more burial.
- Recommendation: amend the mechanism sentences (dossier lines 150, 163); do not report post minus pre as a pure ordering effect. Treat the velocity-sign gate as a weakness of the existing ordinary law that post exposes, not a defect in this PR's code.

**F2 — Medium. Post acceptance depends on host scheduling and is reported only pooled.**
- Accepted post responses per episode range from 85/707 and 399/696 (Linux w1) to 546–698 elsewhere.
- Incoming age differs by host: Windows pre was age 0 in 720/720 frames; Linux w1 pre was age 1 in 716/718 and 718/719, which post turns into refused age 2.
- The per-episode ledger (dossier lines 289–322) has no accepted/stale/pose-drift/incoming-age columns, yet "8/8 worse" is stated per pair. Add those columns; the 8/8 is valid as an executed-arm outcome, not as a per-pair ordering effect.

**F3 — Medium. Upward Sand impulse is not comparable support across arms.**
- Ordinary correction also zeroes opposing velocity (`godot/scripts/rapier_physics_bridge.gd:252-259`), removing downward momentum with no impulse ledger. Ordinary impulse support is only ~0.3–0.5% of M·g·T in every arm.
- So 0.112 → 0.650 is mostly Sand substituting for what correction/clipping already did in pre, not extra support. Reword "increased support" (line 150).
- Native bearing capacity per proxy is at most min(20, 2 × samples), versus ~1.53 × area per tick of proxy gravity impulse, so bearing cannot hold heavy proxies and correction is the effective support. Uncalibrated; not a tuning recommendation.

**F4 — Low (demonstrated). Default pre path changed.** Every accepted tick now deep-copies the observation (`duplicate(true)`), builds the envelope and reads instance IDs/RID (`solid_detachment_session.gd:541-551`). Bounded, but an undisclosed new per-tick allocation on the default path, included in pre-arm timing. Minimal fix: copy only for post.

**F5 — Low. Dropped-deferred dispositions incomplete.** For HeldAfterConsume/OwnerRetired/StepNotAdvanced, `last_contact_response.outcome` stays `DeferredPostContact`; only TerrainPending relabels (`:693`). No metric counts dropped deferred work; the lab caller discards the return (`solid_detachment_lab.gd:148`); `live-001` ran at `c47f96e0`, before `physics_step()` returned dispositions. Denominators are still sound (every row has `manual_step == index+1`; fence episodes show 720/720 Published). Minimal fix: a dropped-deferred counter.

**F6 — Low (hypothetical).** A pre-application owner mismatch reaching `PostContactStopped` (`:710-712`) returns without `_fail()` after Rapier already stepped. Unreachable in practice given the post-step guard (`:697-701`); if reached, native would later see two steps of travel. Minimal fix: `_fail()` on that branch.

#### Checked and found sound
- Ownership: envelope is frame-local, never stored; post-step recheck of generation/epoch/token/worker/bridge/body/RID/sample/step count; all 11 retirement kinds tested (`test_sol_contact_order.gd:96-112`).
- Failed readback: lease recorded before impulses (`rapier_physics_bridge.gd:459`); `_fail()` pauses and returns before publication; unpause does not retry.
- Age +1 correct with modular arithmetic at 1,000,000 (`rapier_physics_bridge.gd:427`); 999999→0 wrap tested; source sample/timestamp preserved; one-use suppression unchanged.
- `physics_step()` return contract: all callers ignore it; the only override (test probe) was updated.
- Mass/inertia: native unit mass per member and Σ(dx²+dy²+1/6); reducer recomputes from tuples and checks every state. Gravity 92.12 = 980 × 0.094 (native constant 92/60: residual 0.13% mismatch).
- Registration fixtures precede the runs and are unchanged afterwards. Receipt hashes match the dossier. `checks-002` at the final head shows `repository` and `material-guard` exiting 1 (inherited blockers). Dispatch suite 38 checks / 0 failures per host.

**Not verified:** no Godot re-execution; values-003 checked by receipt only; Sand census areas and rest screens taken from the dossier reducer; timing not checked.

#### Decisions at these sources

| Question | Decision |
|---|---|
| Ownership/application safety | **PASS**, scoped; F5/F6 low |
| Scientific validity | **PARTIAL**: prospective, fresh sessions, full denominators; but arms differ in ordinary-law inputs (F1), host-dependent acceptance (F2), Sand-impulse reading (F3). Negative result holds; mechanism/generality overstated |
| Post ordering as a settling fix | **NO-GO**, probably harmful under the current bearing gate |
| Original SOL clearance | **NOT PROVED**; all preserved blockers stand (84/84, 64/84, 36/36, 1,452/1,452, CPU, #365, material guard, eight runtime mismatches) |
| Performance/integration | **NOT ADMISSIBLE**: inherited guard failures, no CPU gate, no memory observations, worker4 single claimer, F4. Don't carry the post arm toward integration; the post-step owner recheck is worth keeping separately |

#### Smallest next experiment (not implemented)
Same 520-member tree and 356-member building, packed Sand, unchanged mass/inertia/gravity/damping/caps, fresh sessions, both hosts and worker counts.
1. **Observation only:** enable existing native body diagnostics in current pre/post arms; record per proxy/step support samples, vy sign, bearing and correction emitted; compute correction lost to the `vy <= 0` gate.
2. **One new arm, P2:** ordinary → Rapier step → **publish** → Sand (S3 order, live). Differs from current post only in whether native sees Sand-stopped velocity. It weakens the failed-readback-blocks-publication guarantee, so register that in advance and still latch on failure before the next step.
3. Stratify every claim by accepted count and incoming age.

Discrimination:
- **Velocity gate (F1):** lost correction ≈ post's extra sink (~0.006 cells/step); P2 sink returns to pre while Sand impulse stays high.
- **Integration before Sand:** P2 sinks like current post.
- **Staleness/scheduling:** differences vanish when matched on acceptance and incoming age.

The proposed readiness gate would test only staleness; under F1 it would raise post acceptance and worsen burial. It cannot fix what remains in every arm: pre still sinks 0.006–0.008 cells/step late, failing the 0.5 span limit — a bearing/positional support problem.

Keep #460 and #461 Draft.
