---
title: Frozen Milestone 0 report — 14 November 2026
status: Historical
document-kind: evidence
authority: historical-non-authoritative
retrieval: explicit-history-only
scope: Dated engineering evidence; no current instructions or execution permission
last-reviewed: 2026-11-14
---

> **Frozen source report.** The original M0 body below is preserved as an earlier checkpoint. Its nine pilots and proposals are not current instructions. M1 corrections, subsequent owner clarification and new evidence are recorded in [the M1 report](../REPORT.md) and the separate [owner-intent record](../../../decisions/2026-11-14-owner-authoring-intent.md). Original body SHA-256: `ad5ee63759117df168b5fac684a4bd44e081b12bcd3d73f222268315f98c8971`.

# CyberSand — Engineering Archaeology
## Milestone 0: investigation, pilot excavation and proposed programme

**Read-only investigation • 14 November 2026 • Programme authority: [issue #571](https://github.com/techrote/cybersand/issues/571)**

**Snapshot:** 2026-11-14 00:29:51 UTC. Accepted main: **\`ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742\`**, tree \`05d2960d569719cdc85b44228950eb14fa0d4c66\`. Main was independently rechecked at 00:41 UTC and remained unchanged.

**Milestone 0 is complete.** The investigation found a recoverable but heavily interleaved engineering history, with substantial successor adoption, important negative results, active work that must remain protected, and several demonstrably superseded architectural mandates. The next capture phase is sufficiently defined for owner review. No later phase is authorised by this report.

This report is an investigation deliverable, not the proposed historical index, a replacement engineering policy, a new backlog, or an instruction to resume any old branch. No repository or GitHub state was modified. No CI runs, benchmarks, implementation tasks or scheduled workers were launched. Private analysis notes were used; all substantive conclusions and the frozen inventory are returned here.

### Contents

1. [Executive assessment](#s1) — Baseline, principal opportunities, risks and evidential limits.
2. [Inventory and family map](#s2) — Exact open counts, twelve work queues, accepted lineage and protected development.
3. [Nine representative excavations](#s3) — Code- and history-based assessments using all twelve dimensions of #571.
4. [Promising technical salvage](#s4) — Small reusable assets, important negative results and preservation priorities.
5. [Historical doctrine hazards](#s5) — Claims whose scope, authority or current validity has changed.
6. [Knowledge and indexing design](#s6) — Lightweight records, provenance, separate authority classes and testable isolation.
7. [Subsequent programme](#s7) — Work packages, coordination, quality controls, dependencies and approval gates.
8. [Owner clarification agenda](#s8) — Contextual architectural decisions, separated from empirical questions.
9. [Readiness assessment](#s9) — What is established, what remains uncertain and the concrete next approval package.

[Appendix: complete frozen open inventory](#inventory) — All 271 open records, grouped once; all 179 PR head identities, base branches and Draft states.

### Reading the evidence

- **Verified source/state:** inspected GitHub metadata, a specific source revision, a diff, a test definition or a recorded discussion. Source inspection establishes what code says, not a new runtime qualification.
- **Recorded result:** a historical experiment, reducer result, test report or acceptance record inspected during this investigation. Its original platform, workload and limitations remain attached.
- **Interpretation:** this report's synthesis of those observations; it is neither an owner decision nor proof of future performance.
- **Unresolved / uninvestigated:** explicitly incomplete. An inventory entry is not a completed assessment.

The investigation followed references into closed issues, merged PRs and historical commits, read the governing issue completely, and divided substantive excavation across physics, runtime/rendering and persistence/state specialists, with integration and cross-checking by the lead investigator. Nine contrasting families were examined; the remainder received metadata/family coverage, not a superficial claim of deep adjudication. Historical results were not rerun.

<a id="s1"></a>
## 1. Executive assessment

### The repository is not simply carrying an old backlog

At the frozen snapshot there were **92 open issues and 179 open PRs: 271 open records**. Of the PRs, **160 were Draft and 19 were not Draft**; **92 targeted main and 87 targeted other branches**. The latter is a structural observation, not proof of 87 semantic dependencies. All 271 records had empty label lists. Additional complete search counts found **77 closed issues, 178 merged PRs and 53 closed-unmerged PRs**: **579 issue/PR records in total**, of which 308 were closed. The closed set is a reference universe, not 308 completed excavations. Sources are the repository's paginated [issues API](https://api.github.com/repos/techrote/cybersand/issues?state=open&per_page=100&page=1), [PR API](https://api.github.com/repos/techrote/cybersand/pulls?state=open&per_page=100&page=1) and state-specific GitHub searches.

The accepted baseline is the normal merge of [#565](https://github.com/techrote/cybersand/pull/565), integrating Workbench editing and art authoring after recent liquid, ballistic, Lab and capability work. The [merge record](https://github.com/techrote/cybersand/pull/565#issuecomment-6861038842) and API state establish acceptance even though the PR body still contains HOLD/unmerged language. Main's tree is identical to qualified publication commit \`266d43a33e9eefc3e93a9dce1aaab6e5267492b8\`. This is a concrete reason to reconcile claims against evidence rather than reading titles or status prose as authoritative.

The most significant findings are:

- **Adoption is often hidden by open predecessors.** Native render-copy work, shared-host Player integration, generated playable maps, material capability queries, the Materials Lab and direct art authoring have accepted successors. Their old tickets still contain valuable reasoning but cannot be treated as unimplemented obligations wholesale.
- **Some important capabilities remain missing.** Main does not provide a production reversible soliding lifecycle or general selective streaming of a continuously interacting dynamic world. A Lab that can compile isolated candidates is not a production runtime material installer.
- **Failed experiments contain reusable engineering.** Conservative displacement controls, epoch-wrap fixtures, pressure-flow comparators, retained-baseline exposure tests, crash/ACK controls and old provider failures are more useful than a simple “failed” label.
- **The most dangerous losses are interpretive.** A green workflow can carry a negative engineering verdict; a narrower successful experiment can fail to satisfy the original product intent; a small patch can carry a large compatibility burden.
- **Obsolete authority is already present in plausible-looking current material.** The dedicated Player owner mandate was superseded; Flatten's accepted-main documentation still describes behaviour the revised owner specification withdrew; some audit prose still tells readers to keep a now-merged PR Draft.

The programme should preserve original evidence and recover small useful assets, while replacing historical obligations with a much smaller set of coherent opportunities. It should not optimise for closure count.

### Immediate preservation concern

The MAT-003 S2A artifact is still advertised as available but is scheduled to expire on **22 November 2026 at 00:13:13 UTC**—less than eight days after this snapshot. The [artifact](https://github.com/techrote/cybersand/actions/runs/39876455400/artifacts/12468697797) is 517,177 bytes, with API digest \`sha256:9de681dde221093dcd740673f50a9549240d1858c86c44c1f85182696dc0a1db\`. Its metadata was independently checked; the bytes were **not downloaded or preserved** in M0. Authorising capture should prioritise expiring evidence, without bundling permission to create issues or retire anything.

<a id="s2"></a>
## 2. Inventory and family map

### A bounded baseline, with a separate change lane

Freeze the 271-record inventory below as the initial open scope. Record subsequent arrivals, head changes, merges and owner decisions as dated deltas. Do not silently replace the baseline or declare an old assessment current after its implementation changes.

| Primary research queue | Issues | PRs | Total | Initial engineering focus |
|---|---:|---:|---:|---|
| Soliding, granular contact and rigid-body coupling | 13 | 45 | 58 | Reversibility, detachment, geometry, displacement and negative gates |
| Water, liquid solvers and liquid performance | 14 | 27 | 41 | Hydraulic intent, alternative families, pressure/gas performance |
| Cell carrier, epochs and semantic state | 7 | 7 | 14 | Storage alternatives, state semantics, wrap behaviour and oracle lineage |
| Streaming, checkpointing and durable edits | 1 | 17 | 18 | Selective residency, durable intent, ownership, ACK/crash safety |
| Materials catalogue, chemistry and Lab | 9 | 4 | 13 | Accepted Lab/query work, remaining chemistry, H1/H2/H3 |
| Actors, traversal and composed gameplay | 12 | 18 | 30 | Shared-host adoption, remaining product acceptance, actor work |
| Rendering, graphical startup and platform diagnostics | 2 | 25 | 27 | Copy adoption, retention alternatives, shader experiments, active uploads |
| Recording and review evidence | 2 | 3 | 5 | Capture/replay intent and evidence tooling |
| Generation, maps, atlas and capture tooling | 6 | 14 | 20 | Generator history, playable adoption, mapping and new opportunities |
| Workbench editing, agent collaboration and transport | 10 | 10 | 20 | Direct authoring, legacy transport, save semantics and Flatten |
| Painter model/controller research | 2 | 6 | 8 | Protected new model/controller programme and frozen donors |
| Programme governance, investigation and policy | 14 | 3 | 17 | Intent provenance, policy changes and investigative programmes |
| **Total** | **92** | **179** | **271** | **Every open record assigned once** |

These are coordination queues, not canonical future issues or disposition categories. Cross-links are necessary: material #358, rendering handoff work and authoring/generation overlaps should not be independently excavated twice. The complete per-record mapping, titles and PR refs appear in the appendix.

### Recent accepted lineage

| Work | Accepted identity / relationship | Archaeological implication |
|---|---|---|
| [#542 generated playable maps](https://github.com/techrote/cybersand/pull/542) | \`d4b18e7f06839b35c8f6a66195206da0f33c5fa3\`, 9 Nov | Original “not yet playable” assumptions require reassessment |
| [#553 liquid equipment](https://github.com/techrote/cybersand/pull/553) | \`d8588716becb0dc42019faf23f721378d8adc84a\`, 12 Nov | Current gameplay is a richer comparison baseline |
| [#561 ballistic solids](https://github.com/techrote/cybersand/pull/561) | \`e679879f144f3602bd9d37d7a73aee031f6564ef\`, merged into #553 lineage | Accepted ancestry must be followed beyond direct-to-main PRs |
| [#562 Materials Lab](https://github.com/techrote/cybersand/pull/562) | \`e0fb05b8e0500641f0f25c62c5fb7e721da02d6a\`, 13 Nov | Old Lab non-delivery claims are stale |
| [#563 capability queries](https://github.com/techrote/cybersand/pull/563) | \`63f8b1ba6559906fe85f3ad0269aa296e4141d67\` | Narrow production consumers exist; broader catalogue work is not thereby complete |
| [#544 PAINT](https://github.com/techrote/cybersand/pull/544), [#560 art](https://github.com/techrote/cybersand/pull/560), [#564 combined integration](https://github.com/techrote/cybersand/pull/564) | Preserved heads \`c9b5084…\`, \`381307e…\`, \`00017c6…\`; accepted through #565 | Do not resume predecessor stacks to recreate already integrated work |
| [#565 final integration](https://github.com/techrote/cybersand/pull/565) | Qualified \`266d43a…\`; main merge \`ac0d9fb…\`, 13 Nov | Baseline for this report; inspect semantic coverage, not only ancestry |

### Protected current development

Protection means “do not retire, rewrite, absorb or disturb without a fresh explicit handoff.” It is not a claim that every protected branch should merge.

| Item | Snapshot head / state | Protection reason |
|---|---|---|
| [#539](https://github.com/techrote/cybersand/pull/539) | \`5d8c41a4eb03ec4bd1779feae85273d5af4a6df0\`; non-Draft | Finishing main-push qualification after accepted copy-boundary repair |
| [#566](https://github.com/techrote/cybersand/pull/566) | \`f8041847bc7627b3fdd3d7426d45f646f79995fd\`; Draft | Active camera work |
| [#572](https://github.com/techrote/cybersand/pull/572) | \`0b026f6bd6c1c8ffbe5ef458a8f2b6aebccc13f3\`; Draft | Revised Flatten implementation and associated documentation |
| [#577](https://github.com/techrote/cybersand/issues/577) / [#578](https://github.com/techrote/cybersand/pull/578) | \`3eccbdf11ecf054389e246db99eeefa332a506e7\`; Draft | Current GPU upload opportunity; distinct from old native copy work |
| [#568](https://github.com/techrote/cybersand/issues/568) / [#569](https://github.com/techrote/cybersand/pull/569) | \`2a565df45efc568eb96a2166e0b77f299e289625\`; Draft foundation | Active independent painter-family programme |
| [#573](https://github.com/techrote/cybersand/pull/573), [#574](https://github.com/techrote/cybersand/pull/574), [#575](https://github.com/techrote/cybersand/pull/575), [#576](https://github.com/techrote/cybersand/pull/576) | Four Draft model branches based on #569; full heads in appendix | Separate model experiments, not abandoned historical clones |
| [#570](https://github.com/techrote/cybersand/issues/570) | Current controller programme | Planning/launch context must remain protected |
| [#512](https://github.com/techrote/cybersand/pull/512) / [#523](https://github.com/techrote/cybersand/pull/523) | \`af5ab47…\` / \`61a534a…\`; paused experimental lineages | Explicit source custody persists; proposed handoff was not granted |
| [#283](https://github.com/techrote/cybersand/pull/283) / [#567](https://github.com/techrote/cybersand/pull/567) | Frozen evidence/donor lineages | Preserve original evidence even if not a default continuation route |
| [#554](https://github.com/techrote/cybersand/pull/554)–[#556](https://github.com/techrote/cybersand/pull/556), [#549](https://github.com/techrote/cybersand/issues/549), [#579](https://github.com/techrote/cybersand/issues/579) | Research and recent intent | No inferred abandonment or closure based on age/status alone |

The [GEN-006 custody record](https://github.com/techrote/cybersand/issues/194#issuecomment-6710927940) is particularly important: paused work can still own an integration surface. A read-only investigator may inspect it; a later implementation worker may not infer handoff.

<a id="s3"></a>
## 3. Nine representative excavations

Each pilot below separates the fate of the **ticket**, **idea**, **implementation** and **technical evidence**, then explicitly applies the twelve assessment dimensions. Proposed dispositions are recommendations only.

### Pilot A — Soliding, detachment and conservative displacement

**Members and intent.** [#8](https://github.com/techrote/cybersand/issues/8), [#12](https://github.com/techrote/cybersand/issues/12), [#23](https://github.com/techrote/cybersand/pull/23), [#283](https://github.com/techrote/cybersand/pull/283), [#347](https://github.com/techrote/cybersand/pull/347), [#364](https://github.com/techrote/cybersand/issues/364), [#365](https://github.com/techrote/cybersand/issues/365) and their adjacent stacks contain two enduring purposes: accelerate settled cellular material and create physically detachable/reversible structures. They should not be collapsed into one acceptance ladder.

The early #23 prototype handled a narrow near-rest payload and authored rectangles with quarter-turn restoration. Its reported 32-cycle Windows/Web experiment also reported about **85% p95 observer overhead** on a small active fixture. It did not establish production fracture, arbitrary asynchronous lifecycle or persistence. The [September supersession of the close recommendation](https://github.com/techrote/cybersand/issues/12#issuecomment-5737492839) and [gameplay/fracture clarification](https://github.com/techrote/cybersand/issues/12#issuecomment-5737519787) broadened the programme. The later 27 October addendum in [#12](https://github.com/techrote/cybersand/issues/12) explicitly separated the tracks: Stage 3B was not a universal prerequisite for finite dynamic detachment.

Current main still defaults settled discovery/connectivity off, and [the lifecycle header](https://github.com/techrote/cybersand/blob/@MAIN@/native/include/cybersand/soliding_lifecycle.hpp#L9-L24) explicitly describes a model, not integration into World/Rapier. Therefore the original reversible lifecycle is **not satisfied by a class or test bearing the right name**.

Frozen #283 is valuable negative evidence. Increasing search A81→B289 yielded only **0.4302 percentage points on Linux and 0.6119 on Windows**, against a 20-point requirement. In 7,892/8,084 no-target events there was no strict empty, unmasked four-connected route: topology dominated search radius. The [frozen handoff](https://github.com/techrote/cybersand/pull/283#issuecomment-6549527549) should survive. Current adapter ejection can traverse Sand/Water while rejecting foreign masks and hard obstacles; that source observation is not a fresh frequency measurement.

The [#347 corridor report at its handover commit](https://github.com/techrote/cybersand/blob/1598115c9065239cc1eaec11e99077274b457be1/docs/audits/2026-11-04-sol364b-corridor-result.md) records an eight-axis search with 0.125-cell steps and a four-cell lifetime budget. All 1,452 states, 349 unique, refused; the highlighted stationary/rotated controls required registered-direction clearance distances of 5.78 and 5.25 cells. Live clearance failed 84/84 cases while CPU controls passed 24/24. A separate publication exceeded an archive-size cap, and the unchanged MAT-AUTH protected-source guard blocked integration. These are distinct outcomes: physical NO-GO under the registered budget, passing CPU controls, a publication failure and an integration blocker. Repairing publication or the guard would not reverse the physical result.

**Separate fates.** Historical tickets can eventually consolidate after transfer. The two ideas remain distinct candidates. The useful implementation unit is the [bounded conservative displacement primitive](https://github.com/techrote/cybersand/blob/1598115c9065239cc1eaec11e99077274b457be1/native/src/world_conservative_displacement.inc) and its preflight/fence tests, not the whole old stack. Preserve the topology, clearance and publication failures with their scope.

| #571 dimension | Pilot assessment |
|---|---|
| Applicability | Reversible dynamic structures remain unmet; quiet-region acceleration is a separate opportunity. |
| Recoverable value | Vacancy-path preflight, conservative movement tests, detachment fixtures, topology and budget negatives. |
| Staleness | Prototype shape/rotation assumptions, old stage ordering and prior close recommendations are not universal requirements. |
| Philosophy / architecture | [ADR-007](https://github.com/techrote/cybersand/blob/@MAIN@/docs/decisions/ADR-007-rigid-body-cellular-coupling.md#L29-L52) protects against false Empty during unsafe per-tick erase/simulate/restore; a one-time atomic bijection is a materially different proposal. |
| Implementation salvageability | Small displacement/test units are plausible donors; full lifecycle and native/Rapier integration need fresh design. |
| Empirical evidence / performance | Recorded negatives have exact exposure and thresholds; no new runtime experiment was conducted. |
| Functional completeness / UX | Model-level lifecycle and narrow demos do not deliver reversible production structures. |
| Correctness / risk | Collision barriers, occupancy conservation, foreign masks, clearance, deterministic restoration and persistence remain central. |
| Dependencies / overlaps | Rigid masks, granular interaction, native ownership, restore semantics and water/PF exclusions intersect. |
| Intent / decision provenance | Preserve the original workaround rationale and later reframing; do not infer a permanent ban from repeated old prose. |
| Future potential | Strong capability value if dynamic structures are a desired product direction. |
| Cost / priority | High preservation value; low cost to retain tests; high implementation and validation cost. Owner ranks the capability. |

**Confidence:** high for missing main integration and scoped recorded results; unresolved for the best future architecture. The owner should decide the product priority, while tests decide whether a restoration mechanism is safe.

### Pilot B — Water intent, liquid alternatives and pressure-flow optimisation

**Members and evolution.** [#45](https://github.com/techrote/cybersand/issues/45), [#95](https://github.com/techrote/cybersand/issues/95), merged [#214](https://github.com/techrote/cybersand/pull/214), [#476](https://github.com/techrote/cybersand/pull/476), [#532](https://github.com/techrote/cybersand/pull/532) and [#533](https://github.com/techrote/cybersand/pull/533) combine product water behaviour, successive apparatus corrections and very different optimisation mechanisms.

The old hydraulic ladder was revised after local negative results and apparatus problems. The [scope clarification on #95](https://github.com/techrote/cybersand/issues/95#issuecomment-6355196086) distinguishes #45's narrow vented/shared-atmosphere admission from later sealed-gas work. Untested or blocked water-sheet work is not disproved work. Main's [mixed liquid-family tests](https://github.com/techrote/cybersand/blob/@MAIN@/native/tests/test_lcb_inertial.cpp#L594-L648) exercise different Water, Oil and Brine policies together, worker parity and continuation. This supports composability as implemented; it does not establish a single preferred family or unrestricted hot-switch semantics.

PR #476, inspected at head `5d8ab2ef09530c19c6013e21667a57725771a0a1`, records source-pinned results at `4a80af2a891332176a3912a235582d77d076a185`: reducing writes from roughly **527,000 to 134,000** did not translate into speed. The head phase rose **2.502→3.798 ms**, including **1.648 ms preflight**; whole time changed **20.338→20.502 ms**. This was a native six-worker, gas-off, four-warm/eight-measured-tick experiment, not graphical gameplay or a fresh measurement of the latest PR head. Its three-arm reference/candidate/forced-fallback comparator and same-policy versus cross-policy oracle distinction are valuable salvage.

#533's certificate guard avoided catastrophic maintenance, but the inspected full-size campaign at recorded source `0d818716…` produced **zero certificate builds/reuses**, leaving decisive cost counts unchanged. This is not a fresh measurement of latest head `fa1b2e398acb1986158cb1652b49c935227416ca`. The [negative readback](https://github.com/techrote/cybersand/pull/533#issuecomment-6708207596) should not be translated into a demonstrated full-size acceleration.

Most importantly, [#532's successful workflow](https://github.com/techrote/cybersand/actions/runs/42382862809/job/128436529709), exact head `dce10ccefc395e598aaf2338ccbf58a210b239f8`, reduced to **HOLD_NEGATIVE_FULLSIZE**. Gas process CPU improved about **3.215%**, gas wall time worsened **0.755%**, owner CPU worsened **3.983%**, and whole native p50 improved only **0.5458%**. It exercised eight Rapier barrels in headless Linux; it was not GPU performance evidence. The independently evolving Rapier input streams were not replay-locked, so their differing early checkpoint hashes were not an identical-input equivalence test. A separate exact-input native replay passed.

**Separate fates.** Retire stale experimental obligations only after transfer. Preserve liquid behaviour as a product/research concern. Extract comparators, causal work accounting and fixtures; do not promote candidates solely because they reduce writes or return green CI. Preserve negative verdicts and apparatus corrections.

| #571 dimension | Pilot assessment |
|---|---|
| Applicability | Hydraulic behaviour and coupled cost remain relevant; obsolete admission ladders do not govern all current liquid families. |
| Recoverable value | Corrected fixtures, mixed-family controls, fallback comparators, work ledgers and negative scaling evidence. |
| Staleness | Older apparatus, blanket fluid restrictions and pending-body status conflict with later scopes and completed reducers. |
| Philosophy / architecture | Distinguish physical fidelity, supported product alternatives and optimisation; no evidence supports one mandatory algorithm. |
| Implementation salvageability | Harnesses and guards are smaller, safer units than complete experimental branches. |
| Empirical evidence / performance | Preserve platform, worker count, warm-up, workload, policy/oracle and exposure; green workflow is not a positive verdict. |
| Functional completeness / UX | Native controls and headless barrels do not qualify visible water feel or full gameplay experience. |
| Correctness / risk | Quantity/state contracts, continuation, worker parity and asynchronous comparisons require different oracles. |
| Dependencies / overlaps | PF, gas maintenance, inertial policies, material semantics, bodies and renderer costs overlap. |
| Intent / decision provenance | #95/#214 changed scope; blocked or untested work must not become a historical impossibility claim. |
| Future potential | Better coupled performance and richer liquid behaviour remain credible opportunities. |
| Cost / priority | High evidence value; medium harness recovery cost; potentially high solver revalidation cost. Prioritise measured bottlenecks. |

**Confidence:** high for the recorded verdicts and inspected controls; no claim of current graphical speed or universal solver ranking.

### Pilot C — Cell carriers, packed alternatives and epoch clearing

**Members and question.** [#14](https://github.com/techrote/cybersand/issues/14), closed #16/#17, [#18](https://github.com/techrote/cybersand/issues/18), [#20](https://github.com/techrote/cybersand/issues/20), [#204](https://github.com/techrote/cybersand/issues/204), and the #208→#211→#221→#235→#238 experimental sequence examine how representation, semantics and epoch strategy interact.

Current [precision storage](https://github.com/techrote/cybersand/blob/@MAIN@/native/include/cybersand/precision_storage.hpp#L23-L49) is an **eight-byte, eight-aligned uint64 carrier**: 16 storage bits for material, 16 for state A, eight for state B, 16 spare and eight for epoch. The current Material enum's eight-bit underlying type is a separate fact. Neither means material-only saves must use eight bytes per cell. Main still clears resident epochs on wrap.

Early packed candidates were slower in one active workload. Later [safe memcpy-based candidates](https://github.com/techrote/cybersand/blob/800e16f02d4f87c5e38757a702ff8f098bc886fa/tools/experiments/mat003_continuation/candidates.hpp) are nine/ten bytes and should not inherit the earlier byte-loop implementation’s performance result. Conversely, near-unity ratios in [#231's synthesis](https://github.com/techrote/cybersand/blob/3510e6d1bf1e4e3b3be0299f0a8d7c2bd97bce45/docs/decisions/ADR-016-mat003-carrier-evidence-synthesis.md) are not a proof of equivalence: direct P2/C64 values included **0.996224 and 1.008852** under their specific campaign. That ADR is **Planned**, not adopted. Its shortlist and negative U128 findings are evidence, not a representation mandate.

The synthesis reports independent re-reduction of **1,022 process records / 511 pairs**, with **89,600 World tick samples and 89,600 input samples**. That is stronger than a title-level claim, but still must retain candidate, oracle and campaign identities. Ratios from different campaigns cannot be multiplied into a synthetic speedup.

Wider epochs defer clearing; they do not eliminate the worst clear. Some quiet campaigns observed natural E8 clearing but no E16 clear. The [WCLEAR fixture](https://github.com/techrote/cybersand/blob/800e16f02d4f87c5e38757a702ff8f098bc886fa/tools/experiments/mat003_continuation/wclear.cpp#L50-L117) prepares a real tick at the boundary; it is not a claim to have naturally simulated billions of ticks. Later oracle fixes in #235/#238 also matter when interpreting earlier output. #238’s revised-reader archived-data validation was author-reported; #231 still treated independent scientific acceptance as outstanding.

**Separate fates.** Historical experiment tickets can consolidate. The semantic question—what cell state future capabilities require—survives. Candidate adapters, safe access code, prepared-wrap fixtures and reduction scripts are plausible salvage. Preserve raw campaigns before artifact expiry, including negative layouts and oracle corrections.

| #571 dimension | Pilot assessment |
|---|---|
| Applicability | Current C64 and wrap clear remain; a new representation needs a current semantic or performance case. |
| Recoverable value | Safe packed adapters, comparison harnesses, wrap fixtures, reduction methodology and candidate negatives. |
| Staleness | Four-byte control preferences, “no history/velocity” assumptions and old byte-loop packing costs are scoped historical positions. |
| Philosophy / architecture | Storage follows required semantics and measured trade-offs; current C64 is not automatically the desired long-term design. |
| Implementation salvageability | Experimental adapters/tests can be recovered independently; production migration would touch serialization and hot loops. |
| Empirical evidence / performance | Distinguish active/quiet, natural/prepared wraps, P1/P2, worker counts, oracle revisions and uncertainty. |
| Functional completeness / UX | A carrier benchmark is not evidence of an end-user feature or a hitch-free application. |
| Correctness / risk | Alignment, aliasing, field preservation, epoch wrap, persistence and oracle validity are material risks. |
| Dependencies / overlaps | Material semantics, inertial sidecars, durable state and cache behaviour constrain interpretation. |
| Intent / decision provenance | #14's control is provisional; ADR-016 is planned; later author readbacks are not production admission. |
| Future potential | Worth reconsidering if richer state or measured memory/hitch costs justify it. |
| Cost / priority | Urgent low-cost evidence capture; high-cost production migration. Do not choose a layout before a concrete need. |

**Confidence:** high for current layout and experiment identities; medium for transferability of historical relative timings to current main.

### Pilot D — GEN-006: streaming, checkpoints and durable intent

**Members and original purpose.** [#194](https://github.com/techrote/cybersand/issues/194) and the related experimental lineage, including #486, #512, #518 and #523, seek persistent, selectively resident worlds with durable mutations and recipe reconciliation. This goes beyond saving a finite authored level or comparing native simulation continuation.

Main's [save/replay reference](https://github.com/techrote/cybersand/blob/@MAIN@/docs/reference/level-saves-and-replay.md#L139-L167) distinguishes finite-level CYSD authoring data from native CYPS state. Neither automatically captures host Rapier state or implements general streaming.

There is real prototype implementation. [#486](https://github.com/techrote/cybersand/pull/486), head \`43dc378593050cb7de67389e62d3c672243e3de4\`, provides an interactive native-backed persistent slice, but its residents each have their own World; that does not demonstrate continuous cross-resident physics. [#512](https://github.com/techrote/cybersand/pull/512), head \`af5ab47e210bac53d70b51e923588a4ad630aea9\`, implements same-World checkpoint/eviction controls for isolated inactive Wall/Empty regions. Its [checkpoint code](https://github.com/techrote/cybersand/blob/af5ab47e210bac53d70b51e923588a4ad630aea9/native/src/world_chunk_checkpoint.inc#L37-L85) excludes adjacent and unsupported dynamic domains, then [checks incarnation, generation, tick and recaptured bytes](https://github.com/techrote/cybersand/blob/af5ab47e210bac53d70b51e923588a4ad630aea9/native/src/world_chunk_checkpoint.inc#L133-L181) before ACK-based eviction.

The [#518 journal experiment](https://github.com/techrote/cybersand/pull/518#issuecomment-6707875439) reduced **serialized payload bytes by 80.80%** for five frozen-tick edits. It did not prove equivalent disk-write reduction or gameplay speed. Windows one-worker ACK was **16.430 ms**, compared with **15.942 ms** for the full path, while native cloning remained. Its crash/ACK evidence is nevertheless useful.

[#523's latest positive result](https://github.com/techrote/cybersand/pull/523#issuecomment-6713384639), at \`61a534a90b6fac539c8196788458831023b247f8\`, evicted a **static third resident beside two dynamic Sand/Water residents**. Resident-cell allocation changed **107,264→66,048→107,264 bytes**: 41,216 static bytes reclaimed, **zero moving-bundle bytes reclaimed**. It includes cold-process continuation and late-ACK refusal. This is neither “nothing implemented” nor “dynamic selective streaming complete.” The [full-World staging helper](https://github.com/techrote/cybersand/blob/61a534a90b6fac539c8196788458831023b247f8/native/include/cybersand/gen006_dynamic_full_world_stage.hpp) serializes the whole CYPS state into a private World before a fenced swap; checking a budget after serialization is not a pre-allocation memory guarantee.

Negative knowledge is especially valuable here: [interest narrowing is not reclamation](https://github.com/techrote/cybersand/issues/194#issuecomment-6699409017); render dirty state is not durable mutation intent; explicit Empty and same-value edits matter; same-content ABA must not accept stale identity. Some two-writer and garbage-collector witnesses exercised a synthetic experimental Store, not defects proven in production CyberSand.

**Separate fates.** Protect paused source custody pending clarification. Preserve the original continuous-world and durable-intent ideas. Salvage transaction/refusal tests, ACK fences, journal primitives and continuation oracles. Retain static/dynamic and native/synthetic distinctions in evidence. Do not redefine the original objective to match the easiest successful prototype.

| #571 dimension | Pilot assessment |
|---|---|
| Applicability | General dynamic selective residency and recipe-aware durable mutation reconciliation remain unmet on main. |
| Recoverable value | Static transactions, ACK fences, crash controls, identity tests, journals and continuation oracles. |
| Staleness | Early summaries understate later scoped progress; prototype branches and custody require fresh checks before future work. |
| Philosophy / architecture | Generation baseline, mutation intent, native continuation and host state are separate authorities. Shards are not a continuous World. |
| Implementation salvageability | Tests and transaction primitives are tractable donors; codecs, controllers and dynamic bundle ownership need current design. |
| Empirical evidence / performance | Preserve payload versus I/O, resident cells versus RSS, configured versus observed workers, and synthetic versus real-native execution. |
| Functional completeness / UX | Interactive/static prototypes exist; arbitrary moving-region unloading and reconciliation are not delivered. |
| Correctness / risk | ABA, late ACK/save, explicit Empty, same-value intent, cross-boundary state and unsupported actors/sidecars dominate. |
| Dependencies / overlaps | #486 controller, #512 residency, #518 storage, #523 dynamics, material state and carrier semantics. |
| Intent / decision provenance | #194's capability remains broader than prototypes; latest inspected custody record requests but does not grant transfer. |
| Future potential | Persistent continuous worlds are credible; a smaller editor capability could be a separately scoped opportunity. |
| Cost / priority | High value and substantial integration risk; preserve evidence early, then clarify product priority and custody. |

**Confidence:** high for the scoped implementations and recorded outcomes; unresolved for production architecture and acceptable first capability.

### Pilot E — Player ownership, shared composition and acceptance

**Members and original rationale.** [#263](https://github.com/techrote/cybersand/issues/263), [#264](https://github.com/techrote/cybersand/issues/264), [#270](https://github.com/techrote/cybersand/issues/270), [#272](https://github.com/techrote/cybersand/pull/272), [#274](https://github.com/techrote/cybersand/pull/274), [#304](https://github.com/techrote/cybersand/pull/304) and [#308](https://github.com/techrote/cybersand/pull/308) show why historical “binding” language cannot be imported as present policy.

[#272's ADR-015](https://github.com/techrote/cybersand/blob/00c76b338f65f15d01d7b8c2cba8ebc1a5b23753/docs/decisions/ADR-015-player-playground-asynchronous-owner.md) prescribed a dedicated CyberPlayerCellOwner and rejected reuse of an existing, roughly 2,200-line worker because of coupling and maintenance concerns. That rationale deserves preservation. Later direction preferred shared composition where feasible; a real existing-host spike and accepted #274, merge \`7500c1ccdd31a02f6c4da30c7ed4db1d1c225819\`, changed the evidence. Current [integration tests](https://github.com/techrote/cybersand/blob/@MAIN@/godot/tests/test_play_comp001_existing_host_spike.gd#L134-L215) exercise real worker, input, native ticking and Rapier/course/actor participation. The old dedicated-owner path is a conditional fallback, not a required second engine.

Stopped-session recovery subsequently landed through [#332](https://github.com/techrote/cybersand/pull/332), merge \`89020b9eb6d540383a5bb64b58dcd29a87592c32\`, and PACE004 measurement and qualification apparatus through [#334](https://github.com/techrote/cybersand/pull/334), merge \`070c7a22ad51ea9206931cd9d56fd1e7cfe212aa\`. An epic's last STOP/unmerged checkpoint predates those merges.

The [explicit decision about #304](https://github.com/techrote/cybersand/issues/263#issuecomment-6522029843) made its held-native framebuffer experiment optional; accepted #302 satisfied the specified native-busy lifecycle gate. Optional does not mean passed: the unresolved Windows graphical result retains its failure classification. Nor does a current opt-in coupling fence establish universal strict replay: [the threading contract](https://github.com/techrote/cybersand/blob/@MAIN@/docs/architecture/simulation-tick-and-threading.md#L117-L132) retains exclusions and timeout behaviour.

**Separate fates.** Old dedicated-owner and recovery tickets are candidates for later consolidation after successor comparison. Shared composition is already accepted; a separate dedicated gameplay owner remains a conditional alternative for a genuinely incompatible future host. Salvage missing message/generation/input/lifecycle tests, not whole old Main/worker files. Preserve both successful integration and optional failed experiments. A fresh product acceptance brief may still be useful: source presence does not demonstrate all historical physical-controller, display and human-feel requirements.

| #571 dimension | Pilot assessment |
|---|---|
| Applicability | Shared-host composition and recovery exist; complete current product acceptance is not established by those facts. |
| Recoverable value | Ownership/message contracts, input-edge tests, generation fences, actor/course fixtures and shutdown evidence. |
| Staleness | Synchronous Playground assumptions, mandatory separate-owner chains and old merge statuses have changed. |
| Philosophy / architecture | Shared gameplay composition does not forbid independent scientific or training Worlds. |
| Implementation salvageability | Most main mechanisms already landed; recover only absent value rather than resurrecting obsolete files. |
| Empirical evidence / performance | Spike and native-busy tests prove bounded properties; historical pacing cohorts are not general hardware UX proof. |
| Functional completeness / UX | Code, automated qualification and owner acceptance are separate; human device acceptance remains uncertain. |
| Correctness / risk | Mutable ownership, epoch reuse, input loss, terrain readiness, async skew, shutdown and recovery. |
| Dependencies / overlaps | #272→#273/#274, #308→#332, #334 pacing, optional #304, later central Workbench host. |
| Intent / decision provenance | Revised #263/#264/#273 and the #304 owner decision supersede old mandatory paths within scope. |
| Future potential | Current composition, specialist rigs and future swarm/replay questions can survive without old obligations. |
| Cost / priority | High preservation value, low archive cost; any renewed product qualification should be scoped to today's supported experiences. |

**Confidence:** high for adoption and decision transitions; medium for completeness of present human-facing acceptance. Do not ask the owner to choose dedicated versus shared host again merely because the old ADR survives.

### Pilot F — Native rendering, retained baselines, startup experiments and current uploads

**Four mechanisms must stay separate:** native pixel extraction; retained publication accounting; GPU texture submission; camera/display transforms.

The #290→#295→#298→#301→#333 sequence culminated in accepted [#344](https://github.com/techrote/cybersand/pull/344), merge \`809fd30dfac0c5e127302997075be9c4b279e5aa\`. Current [copy code](https://github.com/techrote/cybersand/blob/@MAIN@/native/src/world.cpp#L5414-L5456) contains chunk-run extraction, endpoint protection and later ballistic behaviour. A historical dense-copy Linux p50 improvement **30.945→1.516 ms** is a source-qualified native-copy result, not a displayed-frame or GPU result. An old audit still saying “E NOT NEEDED” and “leave #344 Draft” is useful historical evidence but stale operational guidance.

The alternative “E” in [#345](https://github.com/techrote/cybersand/pull/345), head \`2461a6a9da130a39dcf2578059f3d47337db4c58\`, changes retained-baseline byte accounting while preserving identity and bounded dirty suffixes. The agent re-summed the source-controlled curated [paired summary](https://github.com/techrote/cybersand/blob/2461a6a9da130a39dcf2578059f3d47337db4c58/docs/audits/render-retention-2026-11-01/linux-paired-summary.json); it did not rerun raw experiments. Of 36 process observations, six failed intended 50 ms slow-consumer exposure qualifications, leaving 15 qualified pairs. Delayed ACK produced **1,356/1,795→10/1,679 retries per refresh**; withheld ACK **1,783/1,792→9/1,655**. The runs completed different refresh counts. Ordinary-ACK cohorts had **zero E exposure**. CPU patch p95 nevertheless regressed **8.4%, 31.6% and 13.6%** across the three paired repeats of the delayed-ACK cohort. There were **zero measured Windows performance pairs**; the admission timeouts provide no Windows performance comparison or hardware-GPU result.

E also assumes 1024-square dimensions, while the current worker accounts for larger Workbench extents. Any extraction must adapt dimensions and packet contracts; replacing whole old worker files would discard later functionality.

Boundary correctness follows another lineage: [#538](https://github.com/techrote/cybersand/pull/538), merge \`1f82dac1cebc9b38a319153354e4bcc774289417\`, repaired the sibling #292 issue, while [#539](https://github.com/techrote/cybersand/pull/539#issuecomment-6865828155) still supplies permanent main-push coverage. A repaired function does not make that workflow finisher redundant.

Main still performs full CPU-image texture submission through [\`texture.update(image)\`](https://github.com/techrote/cybersand/blob/@MAIN@/godot/scripts/main.gd#L4631-L4650). Camera #566 did not originate that cost. Active #577/#578 address a distinct opportunity and remain protected.

The startup subhistory supplies another useful negative. [#316](https://github.com/techrote/cybersand/pull/316), measured executable source `4982e767317c3348d5c6c5ea735fb931e0a86eb3`, recorded the ordinary-material component at **42.4748 s**; complete coarse/fine decomposition families took **60.3297/57.6522 s**, including that component and failing the registered screen. Result-publication source was `8bdebfa3f81e4c1c6a98df3bada2a23955096610`. The whole baseline did not return within the former 180-second allowance, so an exact whole-run speedup cannot be inferred. Later [#330](https://github.com/techrote/cybersand/pull/330), merge \`15b3a4012b9d5998e808fb371792dd7a71398507\`, revised execution allowances. Neither the old ceiling nor the negative decomposition is a permanent architecture ban; execution budgets are also not acceptable startup UX targets.

**Separate fates.** Old R tickets may retire after adopted-value verification. R's idea/code is present. E remains a conditional alternative requiring representative exposure and adaptation. Preserve byte-equivalence controls, endpoint regressions, ACK-pressure findings, consumer-cost regressions and failed exposure/Windows campaigns. Keep current camera/upload/coverage work outside retirement.

| #571 dimension | Pilot assessment |
|---|---|
| Applicability | R adopted; E absent; full-image submission remains; #539's main coverage is still outstanding. |
| Recoverable value | Copy oracles, signed endpoint refusals, causal traces, E budget controls and paired negative/positive evidence. |
| Staleness | Fixed dimensions, old packet contracts, Draft instructions and “E NOT NEEDED” are source-specific. |
| Philosophy / architecture | Extraction, retention, submission and camera concerns are distinct; no historical budget becomes an immutable law. |
| Implementation salvageability | E accounting/tests may transfer; old whole World/worker files are unsafe donors. |
| Empirical evidence / performance | Native wins do not prove GPU smoothness; E benefits require exposure and carry consumer costs. |
| Functional completeness / UX | Byte equality and automated timing do not establish physical display cadence or accepted camera experience. |
| Correctness / risk | Endpoint arithmetic, dirty retirement, generations/serials, immutable buffers and complete temporal history. |
| Dependencies / overlaps | #283→R/#344; #335→E/#345; #292→#538/#539; #566 and #577/#578 are distinct protected work. |
| Intent / decision provenance | R acceptance was narrow; E remained conditional; watchdog changes superseded old execution ceilings. |
| Future potential | E may help large canvases or delayed consumers; current upload work should inform any competing proposal. |
| Cost / priority | High evidence value; moderate adaptation/qualification cost; preserve first and profile current bottlenecks. |

**Confidence:** high for source/adoption and recorded campaigns; no claim of current hardware frame-time gains.

### Pilot G — Materials Lab, capability queries and the deferred H1 defect

**Members.** [#352](https://github.com/techrote/cybersand/issues/352)–[#356](https://github.com/techrote/cybersand/issues/356), [#395](https://github.com/techrote/cybersand/pull/395), [#397](https://github.com/techrote/cybersand/issues/397), [#398](https://github.com/techrote/cybersand/issues/398), accepted #562/#563 and #565.

Older checkpoint prose says the catalogue has no production consumer and the Lab is unimplemented. Current main contradicts those narrow claims. [Capability query code](https://github.com/techrote/cybersand/blob/@MAIN@/native/src/material_rules.cpp#L89-L95) supplies \`is_hard_surface\` and \`supports_granular\` from generated immutable bits with exhaustive parity checks. The accepted Lab exposes the 132-slot catalogue, inspected properties, isolated candidate compilation, bounded World recipes, actual native-contact experiments and preset saving. This does not complete every catalogue, naming or chemistry objective.

The important boundary is visible in [\`world_candidate.py\`](https://github.com/techrote/cybersand/blob/@MAIN@/tools/material_catalogue/world_candidate.py): candidates are compiled outside the installed runtime, unsupported synthetic-ID/capability combinations are refused, and persistence is qualified to the same build. [Reaction effects](https://github.com/techrote/cybersand/blob/@MAIN@/tools/material_catalogue/reaction_effects.py#L15-L49) support bounded replacement/retention behaviours; Water retention is deliberately refused pending its quantity/state contract. [#355's readback](https://github.com/techrote/cybersand/issues/355#issuecomment-6807875891) demonstrates concrete state preservation experiments, not unrestricted production installation.

H1 is a separate dormant MoltenGlass scheduling defect, distinguished from H2's thermal law and H3's rheology. The [explicit #354 decision](https://github.com/techrote/cybersand/issues/354#issuecomment-6807875559) excludes H1 from the Lab milestone; it does not mean H1 was fixed or abandoned forever.

[#395](https://github.com/techrote/cybersand/pull/395), head \`1dd0d9975bf118cb082ac32dadce328b12f57e2b\`, contains a small future-wake scheduling change—13 additions and one deletion—rather than a general thermal rewrite. Recorded controls show cooling progressing where the baseline stalls. Main's current scheduling section still lacks that MoltenGlass continuation. However, [#397](https://github.com/techrote/cybersand/issues/397) retains unexplained empty-control wrap costs: CPU wrap **142.125→253.675 μs** at one worker and **158.075→206.4875 μs** at four, despite small whole-run changes. The experimental threshold was one rather than production eight. Some new work is the required cost of previously skipped cooling, so a ratio alone cannot classify it as waste.

[#398](https://github.com/techrote/cybersand/issues/398) adds a separate compatibility question: an old CYPS snapshot with sleeping MoltenGlass at 180 is accepted but schedules no jobs for 1,024 ticks. Region re-entry wakes it; that is not a general import migration. Preserve the snapshot and its source identity.

**Separate fates.** #356 has substantial successor delivery; #353/#355 are only partly satisfied; #354 remains a scoped deferred problem. Do not close #352 as a unit. Retain Lab/compiler/query assets and H1 fixtures; keep installation policy, Water state semantics and old-save compatibility as separate questions.

| #571 dimension | Pilot assessment |
|---|---|
| Applicability | Lab/query subgoals adopted; full catalogue migration, broader chemistry and H1 compatibility remain distinct gaps. |
| Recoverable value | Candidate compiler, actual-native experiment harness, pure-query parity tests, wake fixtures and old snapshots. |
| Staleness | “No production consumer” and “Lab unimplemented” checkpoints predate #562/#563/#565. |
| Philosophy / architecture | Isolated scientific candidates and production material installation are different contracts; Lab did not authorise H1. |
| Implementation salvageability | Accepted Lab stays; narrow H1 patch is a donor only after fresh cost/compatibility qualification. |
| Empirical evidence / performance | Separate necessary newly executed cooling from unexplained overhead; retain experimental threshold and worker scope. |
| Functional completeness / UX | Real Lab use exists; arbitrary runtime installation and all reaction effects are not established. |
| Correctness / risk | Capability truth, state retention, Water quantity, scheduler wake, save identity and stale sleeping data. |
| Dependencies / overlaps | Catalogue, H1/H2/H3, current capability consumers, save policy and authoring integration. |
| Intent / decision provenance | Explicit owner exclusion keeps H1 outside Lab; no implicit permission to reattach it as a blocker. |
| Future potential | Controlled material authoring and dependable chemistry remain valuable coherent opportunities. |
| Cost / priority | High salvage value; low apparent patch size hides wider validation cost; product installation scope needs owner intent. |

**Confidence:** high for accepted source and scope boundaries; recorded H1 results do not constitute current-main admission.

### Pilot H — From the restrictive Workbench agent to permissive direct art

**Members and shift.** [#525](https://github.com/techrote/cybersand/issues/525)–[#531](https://github.com/techrote/cybersand/pull/531), [#545](https://github.com/techrote/cybersand/pull/545), [#547](https://github.com/techrote/cybersand/pull/547), [#551](https://github.com/techrote/cybersand/pull/551), [#552](https://github.com/techrote/cybersand/pull/552), [#559](https://github.com/techrote/cybersand/issues/559), #560/#564/#565, and protected #568–#576.

The original agent used observe→prepare→apply, small fixed tool limits and a narrow Sandhopper trial. Some safety mechanics were valuable; others became friction presented as policy. A [pricing gate rejection](https://github.com/techrote/cybersand/pull/531#issuecomment-6731027832) and a [successful HTTP response rejected by exact model-name checking](https://github.com/techrote/cybersand/pull/531#issuecomment-6755220736) are useful negative UX findings.

#559 explicitly chose a **fresh implementation from main**, using #531 as a read-only donor. It removed mandatory prepare/apply ceremony, Git-clean/pricing attestations and brittle model-name gates from the product flow, while retaining native host authority, bounds/protection, truthful ACKs and Stop. That is a scoped relaxation supported by an explicit successor brief, not an invitation to discard all safeguards.

Accepted #560→#564→#565 supplies provider/context controls, multi-turn direct art and shared PAINT/art history. Current [art execution](https://github.com/techrote/cybersand/blob/@MAIN@/godot/scripts/art_batch_executor.gd#L31-L73) validates admission and epoch; later code accumulates actual native receipts, handles partial outcomes and Stop, and chunks operations at the native boundary. A native per-chunk limit is not the same thing as a mandatory small user-visible batch limit.

Functional quality remains separate. Recorded local model trials included reasoning truncation, unusable output and thousands of applied cells without a convincing intended image. “Cells applied” does not establish image quality or complete agent acceptance. Current [#568](https://github.com/techrote/cybersand/issues/568) describes a new independent painter-family programme, with #567 frozen as donor material. Its active foundation and four model PRs are protected.

The old remote transport stack is not present in main simply because art authoring is. Its request identity, ACK, Stop and reconnect tests may be salvageable, but would need requalification against current contracts. Do not merge the old #531-based transport files wholesale.

**Separate fates.** Historical restrictive-agent obligations can later retire after contract and evidence transfer. The enduring collaboration idea survives in accepted successors and active research. Preserve useful host authority/receipt tests and transport lessons, while retaining the failed ritual/alias/model-quality findings as negative evidence.

| #571 dimension | Pilot assessment |
|---|---|
| Applicability | Direct art and common history are adopted; remote transport and convincing model quality are separate, incompletely satisfied concerns. |
| Recoverable value | Native receipt semantics, Stop/epoch tests, reconnect contracts, provider handling and negative UX/model evidence. |
| Staleness | Mandatory prepare/apply, Git/pricing ceremony and exact alias gates were explicitly displaced by #559. |
| Philosophy / architecture | Permissive product flow coexists with native authority and truthful application; these are not contradictory goals. |
| Implementation salvageability | Accepted executor is baseline; legacy transport/tests are selective donors, not a branch to resume. |
| Empirical evidence / performance | HTTP success, valid tool output, applied cells and useful image quality are different outcomes. |
| Functional completeness / UX | Old Sandhopper acceptance is not silently passed by the new art flow; current model studies remain active. |
| Correctness / risk | Partial application, cancellation, epoch changes, actual ACK counts, protected cells and history coherence. |
| Dependencies / overlaps | #559→#560→#564→#565, shared PAINT, legacy transport, new #568/#570 programmes. |
| Intent / decision provenance | Fresh-from-main and removed product ritual are explicit; the current painter work must not be recast as resumed #531. |
| Future potential | Better model quality and optional remote collaboration can form distinct opportunities if wanted. |
| Cost / priority | Low-cost evidence preservation; variable model-research cost; substantial legacy transport adaptation. Avoid duplicate active work. |

**Confidence:** high for source/adoption and explicit change of direction; image quality and remote transport completeness remain limited.

### Pilot I — Generated maps, PAINT, saves and the revised Flatten contract

**Members.** [#541](https://github.com/techrote/cybersand/issues/541)/#542, [#543](https://github.com/techrote/cybersand/issues/543)/#544, #564/#565, [#548](https://github.com/techrote/cybersand/issues/548) and protected [#572](https://github.com/techrote/cybersand/pull/572).

Generated maps are now playable in the ordinary host. #541's [later checkpoint](https://github.com/techrote/cybersand/issues/541#issuecomment-6752669975) records accepted main qualification and remaining convergence; its earlier draft prose is not a reliable present implementation description.

PAINT provides brush/fill/copy/cancel and shared Undo through accepted successors. The [executor](https://github.com/techrote/cybersand/blob/@MAIN@/godot/scripts/workbench_paint_editor_executor.gd#L131-L234) uses epoch, generation, tick/revision and settings/pause fences, actual native readback and explicit partial/complete outcomes. Current limits remain real: 262,144 cells per operation and bounded history; setup uses 32,768 run/stamp limits with a 1 MiB file budget. Do not replace the obsolete small-rectangle cap with a new claim of unlimited authoring.

The [combined integration test](https://github.com/techrote/cybersand/blob/@MAIN@/godot/tests/test_workbench_combined_authoring.gd#L181-L203) exercises a 147,456-cell Fill with actual stored material IDs; later sections cover fresh-process generator/edits/actors/policy/copy/Undo/reopen. Tests were inspected, not rerun. Generator-discovery history also records a packaging failure where the installed dropdown was empty; recovery testing matters beyond a working source checkout.

Flatten remains unmerged. The revised 11 November #548 specification requires **the same live World**, a **material-only uint16 little-endian baseline**, discarded old authoring history and a new baseline for subsequent edits. It does not reset actors/ticks or autosave. A later fresh load performs ordinary initialization; it is not a physical continuation snapshot.

Yet main's [shared authoring document](https://github.com/techrote/cybersand/blob/@MAIN@/docs/architecture/shared-workbench-authoring-data.md#L72-L109) still labels the earlier design Approved and describes prepared-World replacement, actor respawn and reset/rollback behaviour. This is a direct authority conflict with a traceable withdrawal, not an abstract stylistic inconsistency. #572 already owns the revised implementation/document correction; archaeology should flag and protect it.

The two-byte material baseline means **0.5 MiB at 512², 2 MiB at 1024² and 8 MiB at 2048²**, before container overhead. Those arithmetic sizes follow the specified encoding; they do not follow the current enum width or eight-byte runtime carrier. Nor does material-only Flatten satisfy GEN-006 dynamic persistence.

**Separate fates.** Transfer accepted generator/PAINT coverage before considering old-ticket retirement. Preserve authoring intent, transactional application, shared-history tests and packaging failures. Retire the withdrawn reset/replacement requirement as authority, while retaining it historically. Keep Flatten active and unmerged until its own qualification and acceptance.

| #571 dimension | Pilot assessment |
|---|---|
| Applicability | Generated play and broad PAINT are adopted; remaining convergence and Flatten are not complete by implication. |
| Recoverable value | Native-readback authoring controls, combined history tests, fresh-process round trips and installation-discovery regressions. |
| Staleness | Draft status prose, old 4096-cell rectangle assumptions and the withdrawn World-reset contract. |
| Philosophy / architecture | Authored initial state, native physical continuation and full host resume are different products and formats. |
| Implementation salvageability | Accepted paths stay; old cap fixes/tests can transfer; active #572 owns the revised Flatten path. |
| Empirical evidence / performance | Large-fill and fresh-process tests establish scoped qualification; no fresh M0 runtime or unrestricted-size claim. |
| Functional completeness / UX | Installed generator discovery and cancellation/history behaviour matter beyond file presence. |
| Correctness / risk | Partial edits, native truth, epoch fences, shared Undo, baseline reset, persistence and package discovery. |
| Dependencies / overlaps | #542/#544/#564/#565 adoption, #548/#572 active work, generation, material identifiers and GEN-006 semantics. |
| Intent / decision provenance | Revised #548 explicitly withdraws the earlier live-World replacement/reset design. |
| Future potential | Coherent authoring/save experience remains valuable; streaming or physical resume needs separate scope. |
| Cost / priority | High test/documentation value; low archival cost; avoid parallel changes on active Flatten. |

**Confidence:** high for accepted source and the specification conflict; no claim that Draft #572 is accepted or fully qualified.

<a id="s4"></a>
## 4. Promising technical salvage

The unit of salvage should be the smallest independently understandable asset: a helper plus invariants, a test fixture plus oracle, an experiment plus its threshold, or a decision plus its rationale. Branch resurrection is usually a much larger and less justified operation.

| Asset to preserve | Why it matters | Preferred treatment / limitation |
|---|---|---|
| MAT-003 raw campaigns, reducers and oracle corrections | Distinguish genuinely changed packed implementations and natural/prepared epoch cost | First capture priority because of 22 Nov expiry; retain original bytes and integrity result, not just a URL |
| Conservative vacancy displacement and adversarial fixtures | Reusable preflight/fence reasoning for representation changes | Extract only after checking excluded pressure/inertial domains; retain physical NO-GO separately |
| Soliding topology/contact corpus | Avoid repeating “increase radius” work when the route does not exist | Preserve search budget, masks, strict-route definition and negative threshold |
| Water/PF three-arm comparators and cost ledgers | Separate semantic equivalence, fallback behaviour and expensive maintenance | Requalify against then-current solver/policy; keep #532 negative verdict attached |
| GEN-006 ACK/incarnation/ABA and crash controls | Durable identity and late-result mistakes recur across architectures | Separate synthetic Store witnesses from real-native tests; preserve exact refusal scenarios |
| GEN-006 journal and static residency prototypes | Demonstrate useful subproblems without pretending to solve dynamic streaming | Record bytes, allocation domain, executed worker exposure and unsupported state |
| Rendering byte-equivalence/endpoints and E exposure tests | Distinguish correct extraction from bounded publication and consumer work | Preserve failed exposures and Windows admission failures, not only favourable pairs |
| PLAY ownership, input-edge, recovery and shutdown tests | Accepted composition still needs these invariants during later refactors | Map which tests are already adopted; retain optional failure evidence without reinstating its gate |
| Lab compiler/query harness and H1 snapshot | Support actual-native material experiments and a real compatibility witness | Keep isolated candidate authority separate from production install permission |
| Shared PAINT/art receipts, partial Stop and Undo tests | Valuable product-facing correctness, already accepted in part | Verify semantic successor coverage instead of copying old files |
| Old provider/alias/pricing and generator packaging failures | Explain why apparently “safer” product rituals or checkout-only testing failed | Preserve concise causal accounts and regression targets, not the old UX mandates |

### Candidate future opportunities—not created issues

The pilot suggests coherent themes that could later become a **small number of independently discussed briefs**, not one successor per old ticket:

- Reversible dynamic structures, separately from quiet-region acceleration.
- Current-workload liquid cost and behaviour, using corrected hydraulic and comparison apparatus.
- State representation and epoch-maintenance policy, only if tied to a named semantic capability or latency/memory problem.
- Continuous-world persistence and durable edit intent, with a clearly chosen first capability.
- Materials authoring contracts, bounded chemistry and explicit compatibility.
- Current gameplay/device acceptance, drawing from adopted shared-host work.
- Publication and rendering performance, coordinated with active camera/upload work.
- Workbench authoring/save coherence and optional remote collaboration, preserving active Flatten and painter ownership.

These are synthesis hypotheses. No theme has been assigned implementation approval, urgency merely from age, or a mandatory old solution.

<a id="s5"></a>
## 5. Historical doctrine hazards

A useful doctrine record tracks an individual claim, not a whole issue as “obsolete.” Validity is scoped: **still valid, superseded, contradicted, partially valid or unverified**.

| Historical statement or hazardous extrapolation—paraphrased | What changed or remains unresolved | Current assessment |
|---|---|---|
| Use the original compact cell layout; no history/velocity protected footprint and simplicity | Main uses C64; optional sidecar state and later packed research exist; #14 retained a control pending evidence | **Partially valid:** cost concern survives; a universal representation ban is unsupported |
| Wider epochs solve clearing | Short campaigns avoided a natural wide wrap; main still clears on E8 wrap; prepared WCLEAR exposes the event | **Unverified as a latency solution:** frequency reduction is not elimination |
| Do not erase/restore rigid bodies protected against false Empty and split collision authority | Proposed fenced one-time transfer differs from unsafe per-tick erase/simulate/restore | **Partially valid:** preserve the safety invariant; do not silently forbid every atomic representation change |
| Soliding must follow one fixed stage ladder | #12 explicitly separated stationary acceleration and dynamic structures | **Superseded within scope:** capabilities need independent rationale |
| Old Water hydraulic scope is the only admitted liquid architecture | #95/#214 separated narrow production scope from optional LCB work | **Superseded as a blanket restriction:** retain specific admission contracts |
| Dedicated Player owner is binding | Accepted #274 demonstrated shared-host composition; later recovery adopted | **Superseded as mandatory path:** original coupling rationale remains conditional evidence |
| Held framebuffer #304 must block PLAY | Explicit owner decision accepted another native-busy gate | **Superseded gate:** unresolved test failure remains a failure |
| 30/180-second graphical limits are immutable | #330 revised execution policy | **Superseded execution limits:** neither old nor new watchdog allowance is a product UX target |
| R adoption means E is never needed | E exposed distinct delayed-consumer benefits and costs; current extents changed | **Unverified universally:** R and E address different mechanisms |
| Lab absent / catalogue has no production consumer | #562/#563/#565 accepted real Lab and narrow capability consumers | **Contradicted as a current claim:** broad catalogue/chemistry objectives remain only partly fulfilled |
| H1 must block material authoring | Explicit Lab scope excluded H1 | **Superseded dependency:** H1's scheduler and compatibility evidence remain valid |
| Prepare/apply, pricing and model-name ceremony are mandatory safety | #559 explicitly removed product ritual while preserving native checks | **Superseded within the direct-art product:** authority/receipt invariants remain |
| Flatten replaces World and resets actors/ticks | Revised #548 withdraws those requirements; #572 is active | **Superseded contract:** main's Approved prose is stale |
| GPU deferral is a permanent ban | [ADR-006](https://github.com/techrote/cybersand/blob/@MAIN@/docs/decisions/ADR-006-gpu-compute-deferral.md) records deferral and authority/readback concerns, not a universal prohibition on rendering or bounded auxiliary work | **Partially valid:** preserve ownership/synchronisation rationale and scope |
| Backend-first ordering remains current because it is on main | [Current product reference](https://github.com/techrote/cybersand/blob/@MAIN@/docs/reference/product-intent-and-priorities.md#L177-L207) and [#534](https://github.com/techrote/cybersand/pull/534) differ materially | **Unresolved owner provenance:** do not choose main-wins or newest-wins |

### The #534 authority gap deserves explicit treatment

#534, head \`62422e83a40ab571c3b920accf2d0579d79a6c12\`, records a 7 November direction favouring gameplay/Workbench/vertical slices over open-ended backend-first sequencing, including bounded deliberately nonconservative gameplay effects. Its patch labels this owner-approved direction. However, inspection of its six-file patch, four comments and review did **not locate a linked originating human instruction**. The [review](https://github.com/techrote/cybersand/pull/534#pullrequestreview-5814636101) is technical, and the [later comment](https://github.com/techrote/cybersand/pull/534#issuecomment-6716858827) still awaits merge authorisation.

An OWNER-associated account or connector-authored text is not proof of direct owner approval. Equally, absence of a linked instruction does not prove the direction false. The correct state is **recorded claimed intent requiring provenance recovery or confirmation**. Confirming the architectural content would not itself authorise merging #534.

<a id="s6"></a>
## 6. Knowledge and indexing design

### Six logical products, few maintained sources

Use three small historical stores plus a separate current decision area; generate index/register views rather than manually maintaining six overlapping narratives. The following paths are **proposals only** and were not created.

| Required product | Proposed source/location | Purpose and authority |
|---|---|---|
| Historical engineering index | \`docs/history/engineering/README.md\` generated from \`families/*.md\` and finding links | Deliberate navigation and chronology; always historical, non-normative |
| Coverage ledger | \`docs/history/engineering/coverage.jsonl\` | One row per issue/PR; depth, four fates, protection, transfer and retirement state |
| Technical salvage register | Typed records in \`docs/history/engineering/findings.jsonl\`; generated salvage view | Ideas, code, tests, benchmarks, failures and recoverability; no implementation mandate |
| Doctrine/constraint register | Claim records in the same findings store; generated doctrine view | Original rationale, scope, contradiction and supersession; never inherit quoted authority |
| Owner intent/decision register | Existing decision conventions, with a proposed \`docs/decisions/owner-intent/\` index if useful | Explicit present decisions, rationale, scope, uncertainty and owner confirmation |
| Canonical successor issues | New GitHub issues only at a separately approved M2 write gate | Current opportunities worth considering; not permission to implement |

A finding should be written once and linked by many families. An artifact manifest can be part of the finding's evidence references, avoiding another hand-maintained register. Large raw data need not live in the main source repository; one approved durable evidence location with hashes and recoverability references is sufficient.

### Minimal schemas

**Coverage row.** Store stable \`item_id\`/\`kind\`/\`url\`, snapshot/head identity, primary family and cross-links, significance, and distinct fields for:

- \`coverage_depth\`: indexed / discussion read / code traced / evidence examined / independently checked.
- \`assessment_state\`: provisional / reviewed / disputed / blocked.
- \`transfer_state\`: not required / identified / captured / independently verified.
- \`retirement_state\`: protected / ineligible / proposed / owner approved / closed and verified.
- Four dispositions: ticket, idea, implementation and evidence; linked finding IDs and destinations.
- Protection reason, provenance and refresh date; unresolved questions and confidence.
- Reviewer, transfer verification method and remaining limitations.

“Not applicable” needs a reason. Independent checking should identify the exact claim checked: reading code is not independently reproducing an experiment.

**Family note.** Include original intent, meaningful chronology, current baseline, relationships, compact twelve-dimension assessment, four fates, significant claims/negative results, active dependencies, owner questions and confidence. Do not paste whole conversations into it.

**Finding/evidence record.** Include type (idea/code/test/experiment/negative/constraint), scoped assertion, source URLs, historical validity, original author/decision provenance, source SHA, executed SHA/runtime identity, platform/workload/workers, method/oracle/reducer, original result and decision threshold, limitations, artifact URL/hash/expiry, actual capture/integrity status and successor destinations.

A source commit, an executed commit and a current PR head are different fields. A URL plus copied hash is not proof that bytes were fetched or will remain recoverable. A source-controlled summary, downloaded original, independently recomputed result, author assertion and unavailable artifact must remain distinct evidence classes.

**Owner decision record.** Store question, relevant history and evidence, alternatives, practical consequences, proposed recommendation, exact owner answer/source, rationale, scope, provisional/final state, superseded claims and unresolved uncertainties. Worker recommendations remain proposals. Current implementation facts can be cited without elevating them into chosen long-term architecture.

**Canonical issue.** State the present problem/capability, why it matters, evidence and alternative approaches, known constraints and their authority, dependencies/active conflicts, uncertainty, proposed validation and historical references. Carry an explicit “requires fresh refinement and execution approval” state. Avoid copying old ladders, temporary quotas, obsolete branch paths or a complete transient execution plan.

### Relationships that prevent accidental authority

Use distinct edges: \`stacked_on\`, \`implements\`, \`adopted_via\`, \`superseded_by\`, \`qualified_against\`, \`contradicts_within_scope\` and \`evidence_for\`. Git ancestry does not prove semantic adoption. In particular, #290's value reached main through reconciliation #344; #345's old fixed-size worker is not equivalent to current variable-size Workbench code.

A historical claim may support a new issue as evidence while remaining non-normative. A present owner decision may supersede the claim without deleting it. A new issue does not need to exist for every old ticket: “preserve negative finding, no further work” is a complete legitimate outcome.

### Historical isolation must be effective from the first capture

The repository already has a useful starting mechanism. Main's [retrieval manifest](https://github.com/techrote/cybersand/blob/@MAIN@/docs/reference/retrieval-corpus.json) explicitly lists **131 documents**, with separate navigation and exclusions. [The evaluator](https://github.com/techrote/cybersand/blob/@MAIN@/tools/docs/retrieval_eval.py) validates selected paths and copies available document-kind/status/scope/canonical-for/last-reviewed front-matter fields into each chunk’s envelope. [Documentation checks](https://github.com/techrote/cybersand/blob/@MAIN@/tools/ci/check_docs.py) also exclude default audits. These are verified local mechanisms, not proof that every external RAG or coding-agent route obeys them.

Extend that design rather than inventing a parallel knowledge platform:

- Put history outside the default focused directories and default manifest. Use a separate opt-in historical corpus/namespace.
- Force an ingestion envelope of **\`authority_class: historical\`**. Imported “Current,” “Approved,” “binding,” or “must” language belongs in \`quoted_source_status\`/quoted content and cannot override the envelope.
- Preserve that classification on every chunk, including extracted code/comments, links and summaries. Ordinary instruction builders must not auto-follow history citations into authority.
- Fail closed if the history corpus lacks authority metadata or a default ingestion route would include it. Review manifest-missing fallback behaviour explicitly.
- Keep archive navigation discoverable without injecting archive content into ordinary coding instructions.
- Test default current-development queries, deliberate historical queries, superseded/current claim pairs, link expansion, warm caches and metadata after chunking. Default answers must not acquire the obsolete mandate.
- Review every actual ingress—agent context assembly, search/embedding jobs, connector imports and cached corpora. A directory name and a local BM25 test do not establish global isolation.

The narrow containment necessary to create the archive safely belongs in the separately approved M1 package. The full Markdown/RAG rewrite remains a later, separately authorised programme. Deferring all isolation until that later programme would create the very contamination window #571 is intended to prevent.

### How this supports later documentation reconciliation

The archive becomes a **claim map**, not a new instruction source. A later documentation worker can map each present claim to current code/runtime evidence, explicit owner intent, an active implementation, a superseded historical claim or unresolved uncertainty. It can then propose corrections with provenance and verify that retrieval returns the approved current interpretation.

The pilot already supplies concrete test pairs: dedicated Player owner versus accepted shared composition; old Flatten reset versus revised same-World baseline; absent Lab versus accepted isolated Lab; R-native speed versus GPU upload; and C64 implementation versus an unchosen long-term representation. These pairs are better reconciliation fixtures than generic “check docs are current” instructions.

<a id="s7"></a>
## 7. Subsequent multi-pass programme

### Approval gates are separate actions

M0 authorises none of these later writes. Approval to capture history, approval of architectural intent, approval to create a canonical issue, approval to retire a batch and approval to implement an issue must remain separate records.

| Stage / work package | Work and ordering | Reviewable exit product | Gate / limits |
|---|---|---|---|
| **M1-A: freeze and preserve** | Freeze the 271-open baseline; metadata-account for the 308 closed references; define deltas and protection; capture expiring artifacts first | Coverage skeleton, actual recoverability manifest, protected set, effective initial archive isolation | Owner approves capture locations, writes, evidence policy and research scope; no issues/closures/implementation |
| **M1-B: full family archaeology** | Investigate all in-scope historical open records; follow closed predecessors/successors as needed; use pilot findings as starting evidence | Reviewed family notes, scoped findings, four fates and unresolved questions | Research assignments confer no policy or code ownership; new experiments need explicit scope if required |
| **M1-C: cross-family reconciliation** | Compare authority, state, persistence, performance and product claims across queues | Contradiction map, deduplicated salvage, evidence gaps and contextual owner batches | Independent review of high-risk doctrine/extraction; preserve unresolved claims |
| **M2-A: owner decisions** | Resolve product/architecture questions with evidence and consequences | Confirmed decision records, or explicit defer/uncertainty | Owner alone approves material intent; technical uncertainty can remain open |
| **M2-B: canonical synthesis** | Draft a small number of coherent present opportunities with alternatives and validation needs | Concrete proposed issue texts and transfer mappings | Separate approval before GitHub creation; creation is not execution approval |
| **M3: transfer verification and retirement** | Verify every significant claim/asset destination; refresh active protection and exact heads; present a closure batch | Item-level transfer receipts, exceptions and reviewable closure text | Owner approves the concrete batch; no automatic branch deletion or merging |
| **M4: fresh issue refinement** | Revisit each issue against then-current main, active work and intent | Refined scope, alternatives, acceptance and execution plan | Individual implementation approval; fresh work, not silent revival of old tickets |
| **Later Markdown/RAG programme** | Reconcile documents using captured history and decisions; audit actual retrieval routes and caches | Proposed corrections and authority/retrieval validation | Separate programme and write authority; does not delay initial archive containment |

### Practical ordering

**First wave: recoverability and authority.** Prioritise the expiring MAT-003 artifacts and other finite-retention experiment outputs; protect active heads; establish the authority envelope before any searchable archive is produced. Carry forward the nine pilot assessments, but mark which evidence was inspected versus actually captured. Resolve easy provenance questions before asking the owner substantive preferences.

**Second wave: densely interdependent native families.** Investigate soliding/rigid contact, liquid algorithms, carrier/state, GEN-006 and material contracts. These share ownership, identity, quantity, continuation and scheduling assumptions. Parallel investigations are useful, but a lead reconciler should review those common invariants weekly or at each completed batch—not wait until every family is “done.”

**Third wave: adopted product lineages and remaining specialised work.** Complete actors/traversal, rendering/platform, recording, generation/capture, legacy transport and governance. Check successor coverage carefully because these are the easiest places to misclassify already adopted work. Active camera, Flatten and painter programmes receive protection/delta tracking rather than archival intervention.

The waves may overlap. A family blocked on an owner decision should produce a useful evidence packet and release its researcher to another bounded family; it should not invent a policy to finish a checklist.

### Parallel coordination without duplicated excavation

Use **one primary family lead per item**, with a short research lease recording scope, inspected head and intended handoff. Secondary workers add cross-links or request a specific fact check rather than opening a competing full excavation. A practical working shape is three research lanes plus one integrator/reviewer, matching the major native/runtime/state intersections revealed by the pilot.

Keep work packets bounded by a question or lineage—for example “#290 to #344 adoption and #345 divergence”—rather than “review every rendering issue.” Split a large queue when its coherent subfamilies become clear. The twelve queues are starting partitions, not mandatory twelve monographs.

Cross-family findings use stable finding IDs. If two workers discover the same invariant or artifact, reconcile the finding once and link it. An evidence disagreement is recorded as disputed with scope, not resolved by whichever worker wrote last.

### Depth and quality controls

- Every open item gets a ledger entry, discussion-level examination and a justified assessment depth. Implementations, subtle “already satisfied” claims and valuable experiments require relevant code/test/evidence tracing.
- Closed records receive metadata coverage; deep review follows engineering relevance. “Indexed only” remains an honest status and is not called investigated.
- A “satisfied” claim needs a requirement-to-successor comparison. Ancestry or filename presence is insufficient.
- A “no useful value” disposition needs a reason and is sampled for independent review. This is where valuable quiet failures are easiest to lose.
- High-risk doctrine changes, destructive-state implications and implementation salvage get an independent reviewer. Reproduction is targeted at disputed conclusions, not an automatic rerun of every historical benchmark.
- Preserve negative findings with their mechanism exposure, threshold, source and limitations. Successful execution and engineering success are separate.
- Record artifact capture and integrity, missing data, unavailable links and reproduction entry points. Do not demand huge binary evidence inside the code repository.
- Use lightweight automated checks for uniqueness, broken internal refs, missing source identities, unsupported authority promotion and retirement without transfer. Avoid elaborate dashboards unless the simple records fail.

Effort is dominated by threaded stacks and empirical evidence, not the number of titles. The pilot found material work in nine families but cannot justify a precise repository-wide hour estimate. After the first full M1 wave, use measured family throughput and evidence-access cost to forecast the remaining work. Do not impose a closure quota or uniform per-ticket paperwork.

### Transfer receipts and safe retirement

Before any historical item can enter an owner review batch, record:

**Source claim or asset → disposition → destination → verification method → unresolved limitation.**

A destination may be a historical finding, preserved code/test/artifact, an owner decision, a canonical issue or an explicit “no further action” rationale. A new issue is optional; preservation and accurate explanation are not.

For adopted code, check relevant semantics/tests against current main. For an architectural decision, retain rationale, original scope, approving evidence and supersession. For a performance experiment, ensure recoverable source, executed identity, oracle and original verdict. A merely copied URL is not a complete transfer where the linked artifact is expiring.

Immediately before retirement, refresh PR heads, active branches, ownership records and successors. Treat #571 and ongoing programme work as protected; assignment to an inventory queue does not make a record legacy retirement material. Close only the individually approved batch with concise destination links. Do not merge, delete branches, remove artifacts or rewrite conversations as a cleanup side effect.

<a id="s8"></a>
## 8. Owner clarification agenda

These are proposed discussion packets. None is an invitation to choose algorithms without evidence, and none is needed merely to finish indexing. Separately approved capture can proceed while substantive decisions remain open.

### Priority A — Confirm the current product and fidelity direction

**History and change.** Main's product guidance retains backend-first sequencing and an older Water ordering. #534 records a later gameplay/Workbench/vertical-slice reset and bounded nonconservative effects, but its originating human instruction was not found in the inspected record. Recent accepted Workbench work is consistent with the reset, but implementation alone does not establish intent.

**Alternatives and consequences.** Confirm the recorded reset; confirm it with boundaries; or retain a different order. This changes whether future soliding/solver research is an enabling dependency for named gameplay or a broad prerequisite imposed on all product work. It also affects what physical conservation should mean in a deliberately authored gameplay effect.

**Recommendation.** Recover the primary instruction if available; otherwise confirm or correct the content directly. Avoid silently imposing the older backend-first order merely because it remains on main.

**Decision requested later:** “Does #534 accurately state your current product priority and the permitted scope of deliberately nonconservative gameplay effects? Which parts, if any, need correction?” This is separate from permission to merge that PR.

### Priority A — Choose the desired soliding capability before its mechanism

**History and evidence.** The programme grew from stationary acceleration into cohesive detachable structures. Current main does not provide the reversible lifecycle. Wider search and bounded corridor recovery failed their registered efficacy/clearance gates; those failures do not invalidate every representation transfer.

**Alternatives and consequences.** Prioritise quiet-region acceleration; prioritise reversible/destructible structures; preserve both for later; or select a small use case that needs one. Dynamic structures entail payload ownership, collision barriers, restoration and host continuity. Quiet acceleration has a different product payoff and may not need rigidification at all.

**Recommendation.** Retain two distinct opportunities and name a useful gameplay/scale scenario before choosing an algorithm.

**Decision requested later:** “Which of those capabilities matters enough for a fresh investigation, and what observable use case should it enable?” Safety of atomic restoration, conservation and displacement budgets should be established technically.

### Priority A — Define the first persistence capability without shrinking the original goal by accident

**History and evidence.** #194 seeks continuous dynamic residency and durable edits. Current prototypes demonstrate isolated Worlds, constrained static eviction, journal savings and static reclamation alongside a dynamic bundle. They do not demonstrate arbitrary moving-bundle unloading. Finite authoring saves and material-only Flatten solve different problems.

**Alternatives and consequences.** Pursue continuous-world streaming; deliver a separately named bounded editor/persistent-map capability; or defer streaming. A bounded capability may deliver value sooner, but must not be recorded as completion of the continuous-world goal.

**Recommendation.** Preserve the original objective and define the first useful capability explicitly. Treat paused #512/#523 custody as a current protection flag pending clarification, not a timeless lock.

**Decision requested later:** “What world behaviour should the first persistence milestone guarantee, and what may it explicitly exclude?” Clarify source handoff only before new implementation; it does not block read-only archaeology.

### Priority B — Decide what material authoring should eventually install

**History and evidence.** The accepted Lab compiles isolated candidates and runs real native experiments; it is not a general production installer. Query consumers now exist, while Water state/quantity retention and broader chemistry remain bounded. H1 was explicitly excluded from Lab scope.

**Alternatives and consequences.** Keep Lab primarily an experimental tool; support curated production material installation; or permit broader user-authored runtime catalogues. Each adds different identity, capability validation, persistence/versioning, compatibility and recovery obligations.

**Recommendation.** Preserve the present isolation boundary until a production use case justifies changing it. Do not make H1 a retroactive Lab acceptance blocker.

**Decision requested later:** “Is the intended next capability experimental material exploration or installing authored materials into ordinary play, and what portability/compatibility promise should that make?”

### Priority B — Set future save compatibility policy

**History and evidence.** CYSD authored state, CYPS native continuation and full host resume are different contracts. #398 shows a real old sleeping-state snapshot that is accepted but does not wake; region re-entry is not a general migration strategy. Candidate builds already qualify some persistence to the same build.

**Alternatives and consequences.** Explicitly refuse incompatible source/kernel generations; offer bounded migration; or promise wider backward continuation. Refusal simplifies correctness but loses convenience. Migration requires versioned semantic identity and tested repairs. Broad continuation is the most expensive commitment, especially for host/sidecar state.

**Recommendation.** First specify which format promises authored intent and which promises continuation, then choose compatibility per format. Prefer explicit, truthful compatibility bounds over silent acceptance that stalls or changes meaning.

**Decision requested later:** “Which saved experiences must remain loadable across engine/material changes, and is clear refusal or bounded migration acceptable for the others?” The correct H1 wake repair is then an engineering matter.

### Priority B — Refresh current gameplay/device acceptance scope

**History and evidence.** Historical PLAY includes five-rig, physical-device and Windows/Linux human acceptance requirements. Shared composition and recovery are now accepted and central to Workbench, but those facts do not prove every original human-feel obligation.

**Alternatives and consequences.** Carry forward the entire matrix; select a smaller current product matrix; or preserve specialised rigs as optional research. This changes validation cost and the experience a future issue actually promises.

**Recommendation.** Write a current experience-based acceptance brief after deciding supported modes/devices/platforms. Keep specialist fixtures useful without letting old test counts define product scope.

**Decision requested later:** “Which current play/Workbench experiences and device/platform combinations should a fresh acceptance brief guarantee?”

### Questions for technical work, not owner preference polling

| Question | Correct next evidence |
|---|---|
| Does an E-style retained-baseline policy help today? | Current large-extent, delayed-consumer exposure with producer/consumer and memory costs |
| Which carrier/epoch design is worthwhile? | Named semantic need, current workloads, wrap-event exposure, oracle-correct paired measurements |
| Can PF maintenance become cheaper? | Representative current profiling, an explicit benefit target and full-cost/fallback controls |
| How much GPU upload work is avoidable? | Protected #577/#578 results distinguishing API time, queued work, GPU completion and displayed cadence |
| Can conservative restoration be safe/useful? | Ownership, topology, collision-barrier and payload-preservation tests on a defined capability |
| What causes H1's unexplained control overhead? | Source-qualified experiment separating necessary work, wrap scheduling and baseline variation |

Already explicit directions should be recorded, not reopened: shared-host Player composition; #304's optional status; #559's fresh permissive authoring route; #548's same-World material baseline; and the independent active painter programme. None of these is implementation approval for archaeology workers.

<a id="s9"></a>
## 9. Readiness assessment

### Established

- Exact accepted main and tree, investigation date, complete open enumeration and all open PR heads/base/Draft states.
- 92 open issues, 179 open PRs, and a complete one-primary-queue mapping of all 271.
- Counts for the closed reference universe, without claiming it has been deeply reviewed.
- Nine substantive contrasting pilots covering adoption, abandoned code, contradictory doctrine, performance, complex stacks, partial product intent and valuable negative results.
- Concrete stale claims and protected work, with source/commit/decision links.
- A lightweight proposed capture model, testable authority isolation, staged execution and contextual owner agenda.

### Still uncertain or deliberately outside M0

- Full substantive dispositions for the remaining open items and most closed references.
- Recoverability of every historical artifact: one expiring artifact's metadata was checked, but M0 did not archive its bytes or all other originals.
- New performance or runtime qualification against this main. Historical reports/tests were inspected; no new benchmarks or CI were run.
- The best long-term carrier, liquid, streaming, restoration or rendering architecture.
- Current product direction where original owner provenance is missing, especially #534.
- Completeness of human/device acceptance and eventual cross-version save promises.
- Isolation across every external retrieval/agent ingress; existing local manifest behaviour is a starting point, not global proof.
- Future movements in active PRs and custody after this frozen snapshot.

### Recommended next approval package

The programme is ready for **review and refinement of an M1 capture package**, comprising:

1. The frozen open scope, metadata coverage of related closed history, and a separate delta lane.
2. Approved record/evidence destinations and permission for those capture writes.
3. Initial historical isolation controls effective before capture is searchable.
4. Expiring-evidence preservation and integrity policy.
5. Primary research ownership, bounded work packets, review depth and independent checks.
6. An explicit protected set and a rule to refresh it before any later action.
7. Confirmation that canonical issue creation, material owner decisions, retirement, documentation rewriting and implementation remain separate gates.

No list of tickets is ready for automatic closure. No old implementation is approved for resumption. No proposed canonical opportunity is an authorised task.

**M0 exit conclusion:** the repository history is tractable, the pilot has exposed real methodological failure modes, and the subsequent programme can be run with substantially less context contamination and less risk of knowledge loss. Proceeding beyond this report requires the owner's explicit next-phase authorisation.





<!-- End of the unchanged frozen M0 source body. -->
