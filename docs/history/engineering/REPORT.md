---
title: Milestone 1 investigation and knowledge capture report
status: Historical
document-kind: evidence
authority: historical-non-authoritative
retrieval: explicit-history-only
scope: Dated M1 capture; no current instructions or execution permission
last-reviewed: 2026-11-14
---

# Milestone 1 — Investigation and knowledge capture

**Prepared for owner review in one isolated Draft/HOLD capture.** Programme [#571](https://github.com/techrote/cybersand/issues/571); explicit scope and owner clarifications recorded in [the authorised plan](https://github.com/techrote/cybersand/issues/571#issuecomment-6871615830). Investigation date **14 November 2026 UTC**. Accepted source baseline **`ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742`**, tree **`05d2960d569719cdc85b44228950eb14fa0d4c66`**. This report is historical evidence; the separate [owner-intent record](../../decisions/2026-11-14-owner-authoring-intent.md) is the current clarification source.

## Contents

1. **Outcome and scope** — What M1 captured, how deeply and what it does not certify.
2. **Repository state and protected work** — Frozen counts, changed branches and custody boundaries.
3. **Material findings and M0 corrections** — Consequential adoption, contradiction and negative-result discoveries.
4. **Salvage and thematic opportunities** — Reusable assets and coherent inputs for later discussion.
5. **Evidence recovery and remaining loss** — Original bytes verified, scope limits and unavailable material.
6. **Authority, isolation and quality review** — Record design, containment, challenge and validation.
7. **Owner agenda and remaining engineering work** — Dense grouped questions for concrete future briefs.
8. **Readiness and next gates** — A bounded path from this draft capture to reconciliation and retirement.

## 1. Outcome and scope

M1 has moved the programme from representative excavation to **individual assessment of every item in the agreed open-history scope**. It contains **274 assessed open records**, **38 family analyses**, and **98 linked findings**: 37 salvage, 30 negative-knowledge, 22 doctrine and nine opportunity records. Every family applies all twelve #571 dimensions; every in-scope item has separate ticket, idea, code and evidence fates, source links, depth, confidence, protection and limitations. The [ledger](coverage.json) also indexes **308 closed/merged records**, producing 582 accounted records in total.

The distinction matters: **308 closed records indexed does not mean 308 closed records independently excavated.** Important closed bridges were followed when they affected adoption, chronology or qualification. Remaining closed-history questions are visible reference work, not hidden claims of completeness. D2 assessment is substantive discussion/lineage work; D3 adds selective source/test inspection; D4 here is original-artifact readback. No fresh engine build, runtime benchmark or gameplay/feel evaluation was needed or performed by the investigators.

The most useful result is the separation of *what happened*, *what survives*, *what is implemented*, and *what the owner now wants*. The repository contains partial adoption, abandoned but useful donors, repaired apparatus, negative results, explicitly deferred integration, and historical prose that no longer describes source or intent. A single “obsolete” label would discard useful information. Conversely, keeping each old ticket as a live obligation would retain incompatible assumptions and duplicate work.

The owner explained that attempts were often left behind because a better parallel route, newly available supporting system, disappointing result or changed short-term priority overtook them. The capture uses an explicit stopping reason only where the evidence supports one. Unknown endings remain unknown; silence is neither rejection of an idea nor owner approval of its implementation.

## 2. Repository state and protected work

The M0 freeze at **00:29:51 UTC** contained 92 open issues and 179 open PRs, or 271 items. The M1 intake at **04:19:41 UTC** contained **93 open issues and 181 open PRs**, or 274 items. Of those PRs, **162 were Draft and 19 were non-Draft**. The closed reference universe comprises 77 closed issues, 178 merged PRs and 53 closed unmerged PRs. Accepted main was unchanged at intake. These are dated counts, not a promise that development stopped during investigation.

The three intake additions are protected: [#580](https://github.com/techrote/cybersand/pull/580), the DRIV3R Stage A/B continuation; [#581](https://github.com/techrote/cybersand/issues/581), stochastic detailing painter design; and [#582](https://github.com/techrote/cybersand/pull/582), the architectural generator. Six existing heads moved between M0 and intake: #566 and #572–#576. Exact old/new SHAs are retained in [deltas.json](deltas.json), with a final live-state refresh before publication. Claims about earlier qualified heads remain pinned; they do not migrate automatically to a new head. At the 04:56:47 UTC refresh, totals and main were unchanged, #573–#576 had moved again, and #566 had independently changed from Draft to non-Draft (161 Draft / 20 non-Draft). This capture did not make those changes.

The capture highlights **74 records for active or paused custody**. Protection includes the current integration, material authoring, Flatten, agent and painter work, plus explicit deferred stacks. All pre-existing branches and historical tickets are untouched whether or not the flag is set. In particular:

- **#519 and its SOL lineage** remain explicitly owner-paused. New interest in prepared/declared destruction does not restart #347 → #393 → #460 → #461 → #466 → #510 → #519.
- **#512/#523** retain the later paused streaming custody. An already-produced 3→2→3 residency result is evidence, not authorisation to proceed.
- **#572 and #573–#576** are moving active sources. Earlier body summaries are not sufficient final-head qualification.
- **#568–#570 and #577/#578/#580/#581** retain current painter coordination and source-specific results. Successful publication or CI is not useful model behavior.
- **#517/#534** remain unmerged proposals. Broad owner agreement with #534 is now documented, but no line-by-line adoption or merge was implied.

The [coverage view](views/coverage.md) groups all 274 assessed items into 38 lineages. Stacked-on relationships are recorded separately from semantic adoption, and cumulative diffs are not counted as independent implementations. The frozen M0 report remains intact with an additive M1 correction path.

## 3. Material findings and M0 corrections

### Gas-cache #533: preserve the rejection and its counterexample

The [latest independent review](https://github.com/techrote/cybersand/pull/533#pullrequestreview-5814148617) at **`fa1b2e398acb1986158cb1652b49c935227416ca`** records **REJECT/PARK**. A small two-room alternating-ceiling-edit test fails exact physical parity in normal, ASan/UBSan and TSan runs. A larger scripted replay passing does not negate that counterexample. M1 inspected the candidate/test source and recorded review, but did not rerun the native tests or freshly retrieve their entire logs.

The original actual-Workbench performance ZIP was separately recovered and reduced. It used headless Godot and native World/Rapier, with baseline **`81bbd5ff5cf366159e2b8a630609359c13560080`**, which predates #522. The two paired tick-p50 gains are approximately **+2.707% and −2.233%**, yielding a median **+0.237%**; process CPU is approximately **0.394% worse**. This demonstrates neither a repeatable useful improvement in that campaign nor an incremental benefit against current main. The useful transfer is the failing churn case, cache assumptions, paired negative performance evidence and review method. It is not a candidate revival. See SIM-F24 and the [readback receipt](evidence/pf533_original_readback.json).

### Carrier and motion doctrine: current facts changed; architecture remains a choice

Accepted [PrecisionStorage](https://github.com/techrote/cybersand/blob/ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742/native/include/cybersand/precision_storage.hpp) is **eight bytes with eight-byte alignment**, including a 16-bit material field; the [Material enum](https://github.com/techrote/cybersand/blob/ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742/native/include/cybersand/material.hpp) remains eight-bit. Several active documents still call a four-byte Cell “Current.” The original staged decision deferred G-final. Neither the old four-byte control nor the current eight-byte implementation settles the ideal long-term carrier. The packed-carrier performance penalty belongs to its access method/workload, not a universal compact-storage prohibition. See STATE-001–004.

Likewise, a blanket “IN cannot have upward/negative vertical velocity” restriction is obsolete. Accepted [#406](https://github.com/techrote/cybersand/pull/406) adds an identified signed IN-B1 option, and current Workbench exposes it. Unsigned-v1 behavior remains valid in its own scope; the optional law does not magically satisfy every liquid or submerged-volume requirement. State #20 and SIM-F18 are explicitly cross-linked. Current implementation establishes availability, not permanent policy.

### Adoption must be semantic and granular

The earlier #11 repair was **never integrated**, rather than integrated and later regressed. [#128](https://github.com/techrote/cybersand/pull/128) adapted the useful semantics later. Correcting that history changes the appropriate future investigation.

[#387](https://github.com/techrote/cybersand/pull/387)'s previous-entry-face contact algorithm is present in accepted Workbench coupling, so a successor should not propose implementing it again. In contrast, [#455](https://github.com/techrote/cybersand/pull/455)'s whole copied-input preflight composition is absent from current contact response. Its guards and counterexamples are potential donors; synthetic malformed input does not prove a reachable production exploit.

[#95/#214](https://github.com/techrote/cybersand/pull/214) accepted an evidence synthesis and narrowed pressure-experiment admission proposal. That documentation merge selected no solver implementation and did not turn LCB-000 into a pass. This distinction was corrected during independent review of the M1 draft.

Runtime examples are equally mixed: selected #385 flyer-authoring files exactly match accepted source, while most of [#262](https://github.com/techrote/cybersand/pull/262)'s map playground and [#409](https://github.com/techrote/cybersand/pull/409)'s broader actor/usable catalogue remain absent. Current flyer/barrel support does not satisfy all of that original composition intent.

### Negative results and superseding corrections survive together

Blocked-cell contact-event suppression helped one burial symptom but lost genuine grain-loading behavior in other cases. Keep both observations. Owner preference for Y1/load-aware feel is separately evidenced; it does not erase failed registered technical envelopes. Source-bound counterexamples remain useful under the current “convincing>consistent” product direction.

[#456](https://github.com/techrote/cybersand/pull/456)'s final “OFF-CPU DOMINATED” classification followed an earlier inconclusive clock-resolution result. Its final reducer still uses raw quantized thread-CPU occupancy without interval propagation. Preserve the result as recorded and require a resolution-aware reduction before a stronger causal claim; it does not prove that Rapier is universally off-CPU dominated.

Capture tooling alternatives #478 and #479 have **different** claim-ownership repair findings. Later #487/#506 reused adapters/rendering with fresh output directories, suggesting a smaller donor route than adoption of the entire recovery protocol. Recording tools #419/#424/#432 likewise contain valuable work and independent REPAIR findings. A real Windows writer using synthetic snapshots and zero reported drops does not establish complete transient-event observation.

Finally, several earlier status statements are overtaken by later evidence: #459 has later Linux↔Windows interchange and malformed-decoder controls; #580's Stage B workflow and release completed despite pending prose. Those later observations improve the historical record without establishing general persistence completeness or useful model output. See the family reports for exact dates, SHAs and limits.

## 4. Salvage and thematic opportunities

The typed register separates individual assets from product opportunities. These are **inputs to M2 discussion**, not new issues or implementation briefs. Existing active work must be reconciled before any successor is proposed.

| Coherent opportunity | Valuable surviving material | Present boundary |
|---|---|---|
| **Workbench authoring continuity** | Evolved occupancy versus construction replay; explicit Flatten; ordinary Save/Undo distinction; live agent/transport receipts and cancellation failures | #572 is active. Do not duplicate it or silently change its contract. |
| **Actors and authored experiences** | #262 maps and moving-prop mask tests; #409 actor/usable catalogue; #402 atomic per-flyer preferences; #148 contour traversal; #224 bounded joint-target/session protocol | Selective donors need current host/controller integration. No scoring/combat programme is implied. |
| **Live material audition** | Accepted catalogue/Lab, source-derived capability queries, phase/quantity experiments, cooling/liveness failures, owner need for Workbench tweaks | Separate external comparison Worlds do not provide all desired live-scene authoring. Material application semantics remain a design question. |
| **Layered Workbench presentation** | Strata's editable play/scripted/effects/background layers and independent clocks | Owner wants this available. Independent layer Worlds do not automatically violate native ownership; composition/interaction requires design. |
| **Prepared destructible structures** | Detachment/publication/ACK invariants, ownership-bijection tests, shape/contact experience and intentionally lossy debris alternatives | The SOL integration stack is paused. Author-declared chunks/break rules are exploratory; no full structural solver prerequisite. |
| **Large authored canvases and persistent areas** | Checkpoint decoding, durable edits, transaction/refusal tests, static residency, cross-OS chronology and state-domain distinctions | Fixed broad canvases and areas are desired; general dynamic-area lifecycle and approximate catch-up are not implemented by this capture. |
| **Agent and painter composition** | Accepted permissive Art path, native authority boundaries, useful failed tests and real producer evidence across four current lanes | Protect active training/integration. Genuine generated output is not demonstrated control over requested topology, layout or style. |
| **Selective robustness and performance work** | Copied-input guards, cache counterexamples, quantized-clock warnings, carrier benchmark apparatus, partial-texture negative cases | Choose a measured current need before reviving a campaign. No automatic rerun or blanket old gate. |

More than one historical ticket can feed one opportunity, and one donor can support several without being copied into multiple records. No “replacement ticket for every old ticket” transformation has been performed. Some assets merit archival preservation alone until a concrete use appears.

## 5. Evidence recovery and remaining loss

Three original hosted archives were reacquired before expiry and checked as bytes. [The custody manifest](evidence/manifest.json) records exact hashes, IDs, sizes, recovery references and limitations; it also describes the portable source-response bundle. Investigators did not merely copy an old claim that someone else had verified a hash.

| Original | M1 verification | What it does not establish |
|---|---|---|
| **MAT-003 S2A**, run 39876455400, artifact 12468697797; 517,177 bytes; expires 22 November | ZIP integrity; 448 stdout/stderr seals; 224 process records, 112 pairs, 16 contrasts; 57,344 tick and equally many input samples; representative pair-ratio arithmetic reproduced | Not a new candidate run; not the broader historical four-campaign 1,022-process review; not Windows requalification |
| **#533 actual Workbench stress**, run 42387965594, artifact 13579714630; 29,101 bytes | Four raw log hashes, matching observation records, process CPU and paired gains re-reduced | Headless, pre-#522 baseline; no graphical target-GPU claim; raw per-timing arrays were not retained; native parity failure independently recorded, not rerun here |
| **#187 retrieval evidence**, run 39472204492, artifact 12288075182; 790,623 bytes; expires 19 November | Original ZIP/hash/CRC; frozen/challenge results and retrieved contexts preserved | No fresh historical evaluator execution or answer-quality reattestation |

Important remaining gaps are explicit: #366's 49.6 MB local-only bundle and #463's 971 MiB local-only raw capture were not recovered. Earlier #358 raw material and private #151 analysis originals are not presumed available merely because later dossiers cite hashes. The #154/#305 records mention a previously retained slop evidence ZIP; it was not reacquired in this M1 session. #580's published Stage B artifact has a recovery route, but its full original model results were not independently reduced here.

The archive therefore provides **verified record transfer and selected original-evidence custody**, not an assertion that every historical byte has been rescued. A later retirement batch must check whether any unrecovered original could change the intended successor or disposition. Where the loss is acceptable, record that judgement explicitly rather than inventing recovery.

## 6. Authority, isolation and quality review

The archive uses two maintained JSON stores, four authored lane analyses and generated coverage/salvage/doctrine/opportunity views. [SCHEMA.md](SCHEMA.md) defines depth and transfer semantics. The current owner clarification is outside history and names the direct conversation and authorised assistant transcription. “Prepare then declare” remains exploratory; a fracture piece is not assumed to equal a storage chunk; richer Save formats and in-session Undo are not converted into a full physical-checkpoint promise.

Containment is enforced in the repository retrieval path: default manifests reject historical paths and tagged copies; fallback selection preserves the boundary; aliases resolve before classification; direct chunking cannot bypass selection; explicit historical search requires its own manifest; every historical chunk overrides old status with a non-authoritative envelope. No links are expanded and no persistent cache is read. Older external indexes must be rebuilt with the policy. These controls do not claim to govern arbitrary external crawlers, nor do they repair all stale text still present in the current corpus.

Independent lane review challenged doctrine, adoption, artifact scope and sampled four-fate records. It found and corrected: a quoted-frontmatter scalar bypass; the #95/#214 adoption overstatement; #533 current-main timing wording; missing new owner-provenance links; and a STATE-001 primary-SHA binding that pointed to the older prepass rather than accepted main. Small owner-record wording changes avoid confusing material occupancy with chunk residency and clarify cross-version compatibility. Exact review scope and remaining limits are in [qa/review.md](qa/review.md).

The [validation receipt](qa/validation.json) records actual commands/results, current default versus explicit historical retrieval checks, structural/generated-view checks and retained historical consistency. Passing structural or lexical checks is not proof of correct engine behavior, complete historical truth, graphical performance or owner feel. The checkout retained 18 unmaterialized runtime LFS pointers; runtime execution was not claimed. Normal PR CI may run under the repository's existing policy; no investigative benchmark campaign or manual workflow dispatch is part of M1.

## 7. Owner agenda and remaining engineering work

Your clarifications already resolve the product-level questions that blocked clean reconciliation: Workbench as the central workshop; convincing results and selectable behavior; owner-led representative play; Save/Flatten separation; live materials; Strata; broad canvases/areas; game-time catch-up, occasional short transitions and optional simulate-ahead. They are recorded together. You do not need to answer those questions again to review this capture.

M2 should bring a small number of concrete, contextual choices, grouped as follows:

**Authoring, materials and composition.** Choose a representative first authored experience and the useful controls it needs, using the actor/map/Strata donors above. For a live material editor, the practical choice is whether a change applies to existing cells in the running scene, only newly painted material, or an audition copy with explicit application. That choice affects identity/version handling, Undo and reproduction. It is a product interaction decision to settle with a small concrete proposal; the internal API belongs to engineering.

**World continuity and state fidelity.** Broad fixed canvases and persistent areas are agreed. A later area brief should state whether adjacent areas need physical cross-boundary exchange or behave as authored room transitions, and which evolving effects must remain convincing on return. Game time and a few seconds of catch-up are already chosen. Timestamp accounting, approximation tiers, directional active margins and storage representation should be evaluated technically; no owner algorithm questionnaire is needed now.

**Destruction and feel.** Use an authored blast/cut/rolling-piece scene to compare a prepared-declaration approach with useful surviving SOL mechanics. Ask about visible controllability and desired results. Keep source/ownership safety and actual integration cost as engineering evidence. The current paused stack remains paused until a concrete brief is authorised; no obligation to restore old automatic-discovery prerequisites or whole-building analysis should leak in.

Technical work, rather than owner preference, should resolve copied-input reachability, current cache correctness, dynamic-state persistence, cancellation/receipt ordering, quantized-clock inference and whether particular donor tests still bind to current semantics. Their existence is not a reason to start those tasks during M1.

## 8. Readiness and next gates

**The programme is ready for review of the M1 capture and for a separately authorised M2 synthesis.** The open-history scope is individually accounted for, valuable assets and negatives have destinations, material doctrine conflicts are exposed, owner intent is separately recorded, active work is protected and the remaining evidence gaps are explicit. “Ready” does not mean every implementation is salvage-ready or every historical ticket can be closed.

| Gate | Concrete package to review | Actions still reserved |
|---|---|---|
| **M1 capture acceptance** | This Draft/HOLD PR, family evidence, individual ledger, original-custody gaps and validation | Merge or Ready promotion requires explicit approval |
| **M2 reconciliation** | A small set of thematic opportunity briefs, checked against then-current main and active work; draft actual successor text | No successor issues until their text is approved |
| **M3 retirement** | Itemised batches with four fates, verified transfers, active-state refresh, proposed closure text and acknowledged unrecovered evidence | No closures, relabels, comments on historical items, branch deletion or old-code merges as side effects |
| **Separate Markdown/RAG reconciliation** | Dated current-claim audit using this archive and owner decisions; source/authority reconciliation and real retrieval evaluation | Broad documentation rewriting remains separate |
| **Issue-level implementation** | Individually clarified desired experience, current source, alternatives, reused assets and targeted qualification | Implementation and campaigns require their own authorisation |

Keep the next phase small in procedure: reuse the existing records, assign one primary investigator per family, link cross-cutting findings, batch owner choices and verify transfers before proposing retirement. No perpetual dispatcher, new approval machine or one-for-one successor backlog is needed. Preserve the evidence; let future obligations be deliberately selected.
