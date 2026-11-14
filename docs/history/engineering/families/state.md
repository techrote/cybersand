---
title: M1 state family evidence
status: Historical
document-kind: evidence
authority: historical-non-authoritative
retrieval: explicit-history-only
scope: Dated engineering evidence; no current instructions or execution permission
last-reviewed: 2026-11-14
---

> **Historical evidence only.** This family packet is a dated research record. Source statements, old approvals and proposed fates do not grant current authority. The separate [owner clarification](../../../decisions/2026-11-14-owner-authoring-intent.md) records present intent. All ticket/implementation actions remain gated.

# Milestone 1 state, persistence and generation research packet

**Read-only research lane.** Capture baseline: accepted `main` **`ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742`**, M1 inventory **14 November 2026, 04:19:41 UTC**. The root investigator owns the capture branch and any authorised publication. This packet makes no repository, issue, PR, workflow, schedule or implementation changes. Private source-response caches and analytical notes are working evidence; GitHub links and the returned capture must carry the durable provenance.

**Coverage:** 60 individually accounted items: carrier 14; streaming 18; recording 5; map design/capture/generation 20; save/Flatten 2; newly observed active architectural generator PR #582. [coverage.json](../coverage.json) records every assigned item, separate ticket/idea/code/evidence fates, source links, depth, confidence, protection and limitations. [findings.json](../findings.json) contains 24 linked findings. These are proposed archaeological dispositions, not technical merge approvals or GitHub actions.

**Depth key.** D2 means the full issue body, substantive discussion and dependency/successor evidence were assessed; D3 adds actual current or pinned historical implementation/test inspection. D4 means original archived observations were independently re-read. D3 is a substantive source assessment, not an exhaustive line-by-line security review or execution qualification. For large compound branches, the individual limitation names incomplete subcampaign coverage. Full PR file lists and patches were captured; significant reviews and comments, including later corrections, were read. The 116-comment atlas thread was captured completely and read selectively for consolidation, ownership, critique, ending state and source evolution; every artistic revision was not independently visually evaluated.

## Contents

1. **Carrier and material-state architecture** — Actual storage, experimental alternatives, epoch evidence and doctrine drift.
2. **Streaming and persistence** — Distinct prototypes, reusable refusal tests and the remaining dynamic-state gap.
3. **Recording and observation** — Landed core, unmerged analysis tools, clocks and negative evidence.
4. **Maps and authoring knowledge** — Wide scenes, overlapping guides and the source-preserved atlas corpus.
5. **Capture and ownership experiments** — Graphical proof, repeated recovery failures and a simpler donor path.
6. **Design steering and new architecture work** — Technical pilots, current planning, active #582 and practical limits.
7. **Save and Flatten** — Explicitly superseded doctrine, active implementation and current owner semantics.

## 1. Carrier and material-state architecture

**Members:** #14, #18, #20, #204, #208, #211, #218, #219, #220, #221, #230, #231, #235, #238. Findings STATE-001–004.

### What the sources establish

Accepted [`precision_storage.hpp`](https://github.com/techrote/cybersand/blob/ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742/native/include/cybersand/precision_storage.hpp) uses `uint64_t`, with an explicit size/alignment assertion of **8/8 bytes**. Its fields reserve material16, state_a16, state_b8 and epoch8, leaving 16 unassigned bits. [`Material`](https://github.com/techrote/cybersand/blob/ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742/native/include/cybersand/material.hpp) still has an 8-bit underlying type; a 16-bit carrier field does not itself enlarge the catalogue. Current `World::begin_tick` increments the eight-bit epoch and clears resident stamps on wrap. The old [G-L checkpoint](https://github.com/techrote/cybersand/issues/14#issuecomment-5632025699) retained a four-byte *experimental control pending G-final*, not a permanent architecture choice.

There is genuine residual authority drift. At this accepted main, [`architecture-programme-source-ledger.md`](https://github.com/techrote/cybersand/blob/ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742/docs/operations/architecture-programme-source-ledger.md) still labels a four-byte Cell CURRENT, and [`retrieval-index.md`](https://github.com/techrote/cybersand/blob/ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742/docs/reference/retrieval-index.md) repeats “Current 4-byte Cell remains baseline.” Other current documents explicitly correct this. Archive both the original rationale and the transition; fix active routing only in the separately authorised documentation reconciliation. Likewise #18's exclusion of a full velocity vector describes that experiment, not a permanent prohibition on dense velocity; #20's sparse motion proposal is an alternative, not a mandate that every future motion model use a sidecar.

Cross-lane doctrine link: accepted [#406](https://github.com/techrote/cybersand/pull/406) and simulation finding [SIM-F18](../findings.json) separately establish that blanket no-ballistic-Water/no-negative-IN-vy claims are superseded by opt-in BW-001/IN-B1. Unsigned v1 retains its negative-vy refusal. This is a policy-specific accepted capability, not a selection of future carrier width or dense versus sidecar storage.

The unmerged carrier stack is **#208 → #211 → #221 → #235 → #238**; #231 is the independent evidence synthesis and #230 the separate proposed semantic persistence handoff. [#221 candidates](https://github.com/techrote/cybersand/blob/800e16f02d4f87c5e38757a702ff8f098bc886fa/tools/experiments/mat003_continuation/candidates.hpp) distinguish a safe byte-loop packed representation from later safe `memcpy` compact carriers. P1's result is an implementation-specific reconstruction penalty, **not an unsafe-memory verdict** or rejection of compact storage.

### Original evidence actually preserved in M1

The root acquired the original [S2A artifact](https://github.com/techrote/cybersand/actions/runs/39876455400/artifacts/12468697797), 517,177 bytes, SHA-256 `9de681dde221093dcd740673f50a9549240d1858c86c44c1f85182696dc0a1db`. This lane independently read the archive without running candidate binaries: **450 entries**, **448 stdout/stderr seals checked with zero mismatch**, **224 process records**, **112 process-pair units**, **16 contrasts**, **57,344 tick samples and 57,344 input samples**. Pair-ratio arithmetic from raw stdout reproduces active-512/w4 P1 C72/C80 medians **1.4960451251 / 1.5116526074**. The 256 samples inside a process are not 256 independent process replications. A private readback receipt is supplied at [S2A readback receipt](../evidence/mat003_original_s2a_readback.json); the root handles durable artifact custody.

[Independent #231 review](https://github.com/techrote/cybersand/pull/231#pullrequestreview-5645271229) previously re-reduced **four** original campaigns: 1,022 process records / 511 pair units; 89,600 S2A/S2P/C128 timed ticks and equally many input samples; separate WCLEAR process observations. That historical review is broader than this M1 S2A readback. Its conditional P2 shortlist had direct process-pair medians 0.996224/1.008852; those observations do not establish equivalence or permit a paired comparison across independent campaigns. C128's quiet E8 native-U128 disadvantage and Dual64 result similarly remain workload/toolchain-specific.

#219's body still describes preparation, whereas downstream #221/#231 records a completed WCLEAR campaign. Natural E8 clear events and *prepared* wider events must remain separately labelled; short no-wrap E16 windows do not prove long-run epoch benefits. [#235's independent review](https://github.com/techrote/cybersand/pull/235#pullrequestreview-5631799145) admits the exact revised v3 **protocol**, explaining why inactive never-activated blocks can legitimately retain quiet zero. It does not accept Windows correctness. #238's v4 152-case/96-comparison archived author readback and portability/tail specimens are further evidence, not automatically independent scientific acceptance.

### Twelve-dimension assessment

| Dimension | Assessment |
|---|---|
| Applicability | State capacity, access cost and epoch lifecycle remain real questions; the four-byte factual premise is obsolete for accepted source. |
| Recoverable value | Carrier wrappers, state/consumer inventory, process-pair timing, negative controls, prepared-clear methods and repaired reader contracts. |
| Staleness | Old Cell size, earlier Water limitations, fixed Windows paths and source-specific registration/applicability; correct claims individually. |
| Philosophy / architecture | Controlled alternatives fit owner preference for practical approximations; none selects dense state, sidecars or a final ABI. |
| Implementation salvageability | Apparatus and tests can be extracted; old World twins, wrappers and stacked current-main reconciliations are costly to merge wholesale. |
| Empirical evidence / performance | Original S2A bytes independently checked in M1; other campaigns rely on named independent historical review; narrow medians and prepared wraps retain their scope. |
| Functional completeness / UX | Experimental feasibility and some source integration checks were completed, but production carrier choice and new semantic fields were never established. |
| Correctness / risk | Epoch consumers, support recent-write semantics, overflow, sleep/reentry oracles, portability and accidentally treating unused bits as solver state. |
| Dependencies / overlaps | Liquid/pressure history, #204 state prepass, #230 persistence, #194 streaming and material catalogue authority; #231 synthesis is not stack head. |
| Intent / decision provenance | Explicit bounded prepass and G-final deferral; repeated experimental restrictions and silence do not create owner policy. |
| Future potential | Revisit compact or wider carriers when a credible scene/material requirement needs state or measured memory/clear cost matters. |
| Cost / priority | High preservation value and low cost to retain evidence; medium/high experimental revalidation cost, low justification for immediate migration. |

**Four fates:** historical gate tickets may eventually consolidate; the alternatives survive; code becomes selective apparatus donors; raw measurements, refusals and revised-readback chronology remain first-class evidence. No carrier stack merge is recommended by capture alone. Future owner input concerns desired material/motion capability, while width/access performance and epoch correctness are empirical questions.

## 2. Streaming and persistence

**Members:** #194, #415, #422, #426, #435, #442, #448, #458, #459, #486, #490, #507, #511, #512, #513, #514, #518, #523. Also #230 and save #548/#572. Findings STATE-004–011, 023–024.

### Separate capabilities, not a single near-finished streamer

Current main has sparse native chunks, simulation interest regions and whole-World CYPS continuation. The [storage/interest contract](https://github.com/techrote/cybersand/blob/ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742/docs/systems/world-storage-and-interest-region.md) and [save contract](https://github.com/techrote/cybersand/blob/ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742/docs/reference/level-saves-and-replay.md) distinguish these from durable selective eviction. Excluding a resident region from simulation does not reclaim it. The old “no catch-up” behaviour and deferred broad streaming are current/historical implementation and sequencing, not prohibitions on the owner's newly clarified game-time approximate area progression.

The final archaeological comparison is:

| Branch family | Implemented contribution | Material limit |
|---|---|---|
| #415 / #458 | Real filesystem and OS-process publication/lease/GC/quota models | Synthetic data; no complete native owner or power-loss semantics. |
| #422 / #435 / #459 | Actual native continuation, state-loss and ownership controls; CYPS cost and restart/interchange | Whole World; physical hash does not cover every optional or host-owned state. |
| #426 / #442 / #448 | Session/cancellation, finite residency saturation and multi-chunk atomicity discriminators | Some host fences are models; private full-World copies are not an admitted production transaction. |
| #486 + #490/#507/#511/#513 | Usable sharded generation/demand/LRU/edit persistence and graphical recovery | One native World per shard; no continuous cross-shard physics. |
| #512 + #514 | Real shared-World static capture/eviction/re-admission with repaired ABA fence | Isolated inactive Wall/Empty domain; unsupported dynamic/neighbour/actor/event states refuse or pin. |
| #518 | Frozen-tick G6J1 edit journal, torn-tail and native-replay pilot | Bounded static domain; final prototype still clones full native state. |
| #523 | Real dynamic Sand/Water full-World staging/continuation/cold restart and later static-neighbour release | Moving-material 2-of-3 selective eviction remains unimplemented. |

[The #230 independent review](https://github.com/techrote/cybersand/pull/230#pullrequestreview-5631513744) provides valuable counterexamples rather than an approved schema: A and B can each have valid chunk checksums yet form a mixed checkpoint cut that loses or duplicates a transfer. Global clock/events, recent-write predicates, same-value intent and host pin ownership need explicit treatment in whichever supported domain is chosen. Its Python codec's syntax checks and in-memory `seen` dictionary do not prove native crash-safe exactly-once mutation.

[The #422 test](https://github.com/techrote/cybersand/blob/6a21a04c2fce6e5db05c59dcf188dd266131accb/native/tests/test_gen006_material_only_rehydration.cpp) contrasts real material-only rebuilding with CYPS: current material IDs survive, fractional Water17 and temperature417 do not. [#435](https://github.com/techrote/cybersand/blob/d6d9c6b8a1249fa109145e74066b799a6a8a9aca/native/tests/test_gen006_selective_domain_refusal.cpp) shows ordinary physical hash/continuation can match while optional witness allocation and transient actor occupancy disappear. Its witness starts with zero events: this proves omitted allocation/configuration, not destruction of a nonzero collision history. These findings support honest state domains, not a rule that material-only Flatten is invalid.

### Negative findings and chronology worth preserving

#426 actually generates proposals on OS threads, but one-slot mailbox activity does not prove four native simulation workers. Its final interest-budget addition has actual source and retained failed compilation, while the earlier passing body refers to a different source. #442's native single-chunk installer commits the west half of a semantic seam before east refuses; this is an expected single-chunk API boundary, not a production bug. #448 demonstrates all-or-none staging only through a restricted private full-World candidate.

#459 is especially easy to misclassify. Its body stops at a Windows checkpoint that explicitly excludes interchange; later comments add [actual cross-OS interchange](https://github.com/techrote/cybersand/pull/459#issuecomment-6683712378), [queued-event interchange](https://github.com/techrote/cybersand/pull/459#issuecomment-6689538177), signed-domain continuation and [SHA-valid malformed decoder controls](https://github.com/techrote/cybersand/pull/459#issuecomment-6692088389). Those scoped positives supersede the older “not tested” statement. They do not establish arbitrary cross-version or host-actor portability. The native cost fixture retains five samples per cohort; its `p95_of_five` is the maximum, not a robust tail estimate. A one-cell change still produces the full checkpoint byte length.

The most reusable #459 result is that display-dirty draining, material equality and persistence acknowledgement are separate. [A drained render-dirty set](https://github.com/techrote/cybersand/pull/459#issuecomment-6693265760) does not imply a newer Empty edit was saved; [simulation-only evolution](https://github.com/techrote/cybersand/pull/459#issuecomment-6694498680) matters even without a host edit. Mutation generations and incarnation/session identity must be checked at commit.

The sharded controller's [Resident implementation](https://github.com/techrote/cybersand/blob/43dc378593050cb7de67389e62d3c672243e3de4/native/tests/gen006_streaming_slice.cpp) owns an independent `World`. #490 exposed outer-coordinate relabelling and supplied a narrow no-ABI membership discriminator. #507 reproduced a genuine surface tick killing the controller and losing unsaved intent; [later integration comment](https://github.com/techrote/cybersand/pull/507#issuecomment-6701822226) records repaired containment. The negative branch's expected-crash assertion must not become present acceptance. #511 adds framebuffer-visible pin/stall recovery. #513 records actual Windows11/NVIDIA interaction and a response-read sharing repair, while explicitly leaving human playtest acceptance pending and the original spontaneous file-denial process unidentified.

[The #512 checkpoint code](https://github.com/techrote/cybersand/blob/af5ab47e210bac53d70b51e923588a4ad630aea9/native/src/world_chunk_checkpoint.inc) is substantive, but its narrow refusal predicates are central. [Independent #514 red-to-green evidence](https://github.com/techrote/cybersand/pull/514#issuecomment-6706060753) preserves a real stale ACK(A) deleting a restored B before the monotonic-incarnation repair. [The source-transition review](https://github.com/techrote/cybersand/pull/512#pullrequestreview-5812330994) admits exact static protected-source bytes, not general streaming, defaults or merge. Host-provided `durable=true` does not itself prove a filesystem flush.

[The last #518 checkpoint](https://github.com/techrote/cybersand/pull/518#issuecomment-6707875439) connects native-derived edits to fsync before outer ACK in a scratch variant. Its **80.80% reduction in serialized payload** is not disk-write reduction or a stable latency victory; full clones and frozen tick zero remain. The former worker was [repurposed](https://github.com/techrote/cybersand/pull/518#issuecomment-6707908212), not documented as rejecting the journal idea. [The last #523 checkpoint](https://github.com/techrote/cybersand/pull/523#issuecomment-6713384639) runs dynamic seam ticks while a separate static resident is absent: 3→2→3 residents, 41,216 static bytes reclaimed. It explicitly does **not** release the moving 2-of-3 bundle.

### Twelve-dimension assessment

| Dimension | Assessment |
|---|---|
| Applicability | Persistent areas remain relevant; historical unrestricted continuous streaming is a broader goal than current owner needs. |
| Recoverable value | State inventory, fail-closed native tests, durable ACK/GC controls, sharded playable prototype and static selective residency. |
| Staleness | Source-specific CYPS formats, earlier untested statuses, pre-repair ABA/crash behaviour and scheduler-owner claims; follow dated transitions. |
| Philosophy / architecture | Approximate game-time return progression can use bounded area state without exact globally active simulation; no design chosen here. |
| Implementation salvageability | Prefer isolated tests and narrow mechanisms; shared ownership, full clones and old branch ancestry make whole-stack adoption expensive. |
| Empirical evidence / performance | Genuine native/OS/graphical results exist alongside synthetic models; report actual workers, source, sample count and real versus modelled fault. |
| Functional completeness / UX | #486 is usable experimentally; #512 static residency is real; dynamic selective eviction, complete actor lifecycle and current owner return UX are not complete. |
| Correctness / risk | Stale/late ACKs, resets/incarnations, intent loss, mixed cuts, actor/halo pins, journal durability, failed World containment and capacity refusal. |
| Dependencies / overlaps | #230 state contract, carrier semantics, material schemas, actor/Rapier ownership, generated starts, Flatten and active #512/#523 integration. |
| Intent / decision provenance | Active source ownership/HOLD must survive; repurposed workers and abandoned alternatives do not equal rejection; source admissions are narrow. |
| Future potential | Persistent-area travel and approximate catch-up provide a credible smaller destination; journals/selective chunks become useful as measured needs emerge. |
| Cost / priority | High knowledge value; high integrated correctness burden. Prioritise state/identity tests and a small user scenario over completing every historical prerequisite. |

**Four fates:** tickets eventually consolidate around coherent area lifecycle; ideas and alternative topologies survive; code is a donor menu plus protected active candidates; evidence retains genuine failures and scoped positives. Current owner decisions settle game time, approximate progress and tolerable occasional transition delay. Timestamp alone does not restore missing state; how much state suffices, bounded catch-up, actors/Rapier and cross-area effects remain technical design/empirical scope questions, not reasons to reopen settled preferences or launch implementation in M1.

## 3. Recording and observation

**Members:** #130, #135, #419, #424, #432. Findings STATE-012–013.

The [current recorder](https://github.com/techrote/cybersand/blob/ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742/godot/scripts/gameplay_recorder.gd) consumes immutable snapshots, folds render patches into a private ROI and queues detached output for a writer thread. Queue pressure drops captures, not simulation ticks. It declares `simulation-state-evidence-not-exact-replay`. [#135's merge notice](https://github.com/techrote/cybersand/issues/135#issuecomment-5834997489) confirms #140 landed at `8a92768a213be8d135726c2369fb251ab721088f`, while retaining a separate owner/desktop gate: matched real gameplay OFF/ON and useful REM003/falling-material evidence. The core is present; the original intent is only partly qualified.

[Independent #419 review](https://github.com/techrote/cybersand/pull/419#pullrequestreview-5782585716) finds malformed BMP header fields and contradictory drop accounting accepted despite nine positive synthetic tests. [#424 review](https://github.com/techrote/cybersand/pull/424#pullrequestreview-5783359835) adds impossible incomplete counters, omitted rigid-body membership under a reused actor serial, and finite inputs whose subtraction produces invalid Infinity/nan output. The source implements those inadequate boundaries; these are useful concrete negative tests, not speculative criticism or an allegation the production recorder emits malformed files.

[#432](https://github.com/techrote/cybersand/pull/432#pullrequestreview-5784875032) really ran the unchanged Godot writer on Windows, producing 46 authenticated frame triplets. Its input snapshots were **synthetic**, Godot was **headless**, and native World/Rapier were not stepped. All four observed publication p50s were about 20.7 ms rather than the requested 17 ms. Per-frame source fields are unavailable despite session provenance, and raw per-arm timing arrays were not retained. The authentic writer bytes and pixel oracles remain valuable; neither gameplay overhead nor exact 60 Hz operation is established.

The [temporal-observability control](https://github.com/techrote/cybersand/pull/424#issuecomment-6666413747) is a particularly useful negative result: zero queue drops still leaves ~372.6 ms between synthetic material-generation observations. A hypothetical 30 ms change-and-revert between them is indistinguishable from no change. This is a sampling argument, **not** an observed or physically simulated pulse. Event bookmarks must mean “first observed,” not “first occurred.”

| Dimension | Assessment |
|---|---|
| Applicability | Low-friction recorded gameplay comparison remains relevant to current owner scene-based evaluation. |
| Recoverable value | Current recorder, raw-ID/BMP split, source-clock comparison, timelines, independent projection oracles and adversarial validation. |
| Staleness | “Implementation absent” is false after #140; “parent must stay open forever” is historical workflow, not a permanent obligation. |
| Philosophy / architecture | Observation supports human feel; mathematical/source checks complement rather than replace scene judgment. |
| Implementation salvageability | Reuse core and repair small offline tools; do not build another recording owner. |
| Empirical evidence / performance | Real Windows writer on synthetic stimulus; aggregate-only latency and missing frame identities limit reuse. |
| Functional completeness / UX | Recording code landed, analysis tools unmerged/REPAIR, real REM003/falling-scene acceptance still open. |
| Correctness / risk | Loss accounting, source identity, actor/material clock skew, malformed media/derived arithmetic and temporal blind intervals. |
| Dependencies / overlaps | #130 infrastructure, #135 actual acceptance, #419/#424 different observers, #432 writer evidence; runtime lane covers gameplay. |
| Intent / decision provenance | Original explicit remaining desktop gate is preserved; synthetic passes are not owner acceptance. |
| Future potential | Reusable review recordings and actor/material inspection can improve practical physics iteration. |
| Cost / priority | High donor value; modest validator repair cost; actual useful-scene evaluation needs focused execution later. |

**Four fates:** consolidate evergreen tickets later; retain the observation capability; repair/reuse source; preserve malformed-input findings and sparse-clock evidence. The next empirical question is recorder usefulness/cost on actual authored gameplay, not a new abstract owner decision.

## 4. Maps and authoring knowledge

**Members:** #184, #186, #187, #454, with #501/#549 relationships. Findings STATE-014, 019.

[#184](https://github.com/techrote/cybersand/pull/184) contains a real **960×192** Grey Area51 composition with five 192-cell districts and aligned 24-cell portals, not five disconnected saves. The [scene source](https://github.com/techrote/cybersand/blob/1a84e87d22d490f17d79e50b538e62fc4ede0dff/godot/scripts/grey_area_51.gd) and [native traversal tests](https://github.com/techrote/cybersand/blob/1a84e87d22d490f17d79e50b538e62fc4ede0dff/godot/tests/test_grey_area_51.gd) are substantial donors for broad non-square canvases and camera-preserving connected scenes. The reported tour uses the default sampled character with material ticks paused after a stability run; do not promote that to arbitrary dynamic or Windows/browser playability. It remains absent from accepted main.

[#186](https://github.com/techrote/cybersand/pull/186) and [#187](https://github.com/techrote/cybersand/pull/187) are overlapping, independently authored guide packages. They cover real material mechanisms, complete layer accounting, source/runtime distinction and measurable visual acceptance, but start from different Deepworks checkpoints. #186 refers to a separately pinned unmerged example; #187 follows merged `4f3685b71366218e82e7c2188e4ecdf27553f4cf`. Their retrieval results are source-specific routing evidence; neither a new-query development score nor hit@5 proves answer quality. Preserve the initial retrieval regression and later recovery, then use these as donors for the separately authorised Markdown/RAG synthesis instead of installing both corpora unchanged.

[#454's consolidation checkpoint](https://github.com/techrote/cybersand/pull/454#issuecomment-6668295348) records closure of 15 originals as superseded, **not merged/deleted**. The current branch preserves 15 collections/120 original modules, provisional pack data, variants, validators, renders and a long revision/critique sequence. A [representative validator](https://github.com/techrote/cybersand/blob/c4aab63eed538a25687c66d368b0801d2d2e04d0/docs/world-design/coral-telegraph/validate_pack.mjs) checks material metadata, static/dynamic classifications, bounds, variants and placements against source pins. It cannot demonstrate containment, collision, traversal or artistic superiority. The [quality bar](https://github.com/techrote/cybersand/blob/c4aab63eed538a25687c66d368b0801d2d2e04d0/docs/world-design/QUALITY_BAR.md) explicitly treats superiority to reference galleries as an unmet objective.

A critical distinction is owner evolution: #454 still contains old instructions to run hourly art workers; [#549](https://github.com/techrote/cybersand/issues/549) records they were intentionally stopped when repetitive detail became noise. Valuable modules and lessons survive without preserving perpetual production obligations.

| Dimension | Assessment |
|---|---|
| Applicability | Broad authored scenes, discoverable good examples and useful authoring guidance fit the current Workbench direction. |
| Recoverable value | Scene geometry/shaders/tests, exhibition process, material witnesses, layer-composition guidance, module sources and critiques. |
| Staleness | Old launcher wiring, local APIs/limits, obsolete corpus membership and stopped scheduled-worker instructions. |
| Philosophy / architecture | Human curation and meaningful composition now dominate volume; original source remains historical inspiration. |
| Implementation salvageability | Reuse selected modules and tests; curate overlays and reconcile guide sections rather than merge all art or duplicate long guides. |
| Empirical evidence / performance | Native/render evidence exists for Grey; atlas validators/source-colour reviews establish narrower properties; routing scores are not taste. |
| Functional completeness / UX | Grey is unmerged; guides are unmerged alternatives; atlas has no accepted runtime importer or full human-reference acceptance. |
| Correctness / risk | Native ID drift, active-material false assumptions, geometry-only traversal claims and stale instructions entering coding/RAG context. |
| Dependencies / overlaps | Deepworks #185, existing GEN005/007, #457/#487/#506 capture, #549 curation and #501 native four-plane translation. |
| Intent / decision provenance | Owner preserved corpus but stopped noisy mass production; no inference that every module or old branch was rejected. |
| Future potential | High-context modules and rejected alternatives can support a compact practical design guide and local variation. |
| Cost / priority | High preservation value; cheap index/links, costly full artistic/physical requalification. Start with representative curation later. |

**Four fates:** original art/guide tickets can retire after knowledge transfer; design ideas remain candidates; selected source is salvaged; provenance and criticism remain discoverable. No new artistic verdict is asserted in this packet, and no original image/module was edited.

## 5. Capture and ownership experiments

**Members:** #457, #462, #467, #468, #469, #478, #479, #487; #506 is the unattended successor. Findings STATE-015–017.

The actual lineage is **#457 → #462 → #467 → #469**, with #468 an independent adverse test based on an earlier corrective checkpoint, and **#478 / #479 parallel corrective alternatives** from #469. #487 is a different viewer approach, reusing the geometry adapter and production shaders; #506 adds unattended capture. Treating the whole set as one linear stack would lose the alternatives and encourage unnecessary integration.

The original adapter really can render packs using Godot, but later comments—not its initial unexecuted body—establish that [graphical baseline](https://github.com/techrote/cybersand/pull/457#issuecomment-6673507282). Repair work added staged output, exact schema checks, Windows renderer selection, bounded allocation and truthful declared-versus-verified source identity. Independent review repeatedly found narrower boundaries not covered by large passing suites:

| Evidence | Result to preserve |
|---|---|
| [#462 review](https://github.com/techrote/cybersand/pull/462#issuecomment-6688330597) | Authentic graphical tests did not establish arbitrary output custody/failure-safe publication. |
| [#468 negative](https://github.com/techrote/cybersand/pull/468#issuecomment-6694320323) | Real Linux and Windows Godot processes: known recovery token displaced a still-live owner; four checks failed per OS. |
| [#469 review](https://github.com/techrote/cybersand/pull/469#issuecomment-6697021419) | Same-host PID/hostname checks did not bind process visibility across namespaces. |
| [#478 review](https://github.com/techrote/cybersand/pull/478#issuecomment-6698854827) | Genuine cross-PID-namespace test passed; source still equates absent or mismatched PID in unverified procfs with death. This remaining result is source/OS-semantics plus a model, not an observed Godot exploit. |
| [#479 review](https://github.com/techrote/cybersand/pull/479#issuecomment-6697782476) | Archive-then-reacquire leaves fixed claim absent so a no-token normal capture can acquire it. This is not proof of simultaneous manifest writers. |

Actual [`#478 _owner_liveness`](https://github.com/techrote/cybersand/blob/8116c6245757c3dceb3b38af01da2e29c9c82448/godot/tools/capture_world_design_pack.gd) returns dead from absent `/proc/<pid>` or a different start tick; [`#479`](https://github.com/techrote/cybersand/blob/cae8333a49232aee84e06bf92893bf09c11f1e7d/godot/tools/capture_world_design_pack.gd) calls `_archive_claim` before `make_dir_absolute` reacquisition. These source checks support the historical reviews without executing exploits here.

The tile evidence also needs precise retention. A historical Linux comparison changed 1,253/655,360 pixels, max 5/255, with no difference in then-tested vertical bands. Later sources reduced the residual to one Lumen pixel and nine square scale-2 pixels at max 1/255, some within tested bands. Windows listed fixtures were exact. Preserve the original failed criterion and the narrow revised scope; neither “all seams identical” nor “all GPUs identical” follows.

The useful salvage alternative is already implemented: [#487 render rig](https://github.com/techrote/cybersand/blob/a3f469eb4d91bf3c0c41134f684d439e5e7fff2c/godot/tools/world_art_render_rig.gd) uses genuine production shader pixels without native World, while [#506](https://github.com/techrote/cybersand/pull/506) requires a new or empty output folder and shares the tiled export. Reusable geometry, rendering, PNG verification and source provenance do not require adopting the entire old shared-output recovery protocol. That is an architectural interpretation, not a declaration that the new path has no defects or that the owner must abandon output replacement.

| Dimension | Assessment |
|---|---|
| Applicability | Reliable actual-pixel review remains important; complicated shared-directory takeover may be unnecessary for fresh-output capture. |
| Recoverable value | RG8 oracle, source-bound renderer, tiled halo export, malformed input/budget controls, real OS adversaries and readable viewer. |
| Staleness | Initial “not run” bodies, old repair completeness claims, moving art hashes and obsolete liveness assumptions. |
| Philosophy / architecture | Preserve useful output while reducing mechanisms to the actual user workflow; no requirement to finish every historical repair stack. |
| Implementation salvageability | Adapter/render rig/checks are high-value donors; unsafe shared-claim code needs redesign if reused. |
| Empirical evidence / performance | Authentic graphical campaigns and original failures exist; model/source arguments are labelled separately; no global GPU parity. |
| Functional completeness / UX | #487/#506 provide practical viewing/capture; #478/#479 remain independently REPAIR; artistic/native acceptance is separate. |
| Correctness / risk | Input/output aliasing, stale manifests, interrupted publication, live-owner takeover, process visibility and no-token handoff gap. |
| Dependencies / overlaps | Art #454 remains independent; frozen pack source differs from moving art; #478/#479 are alternatives, #487 a simpler descendant by donation. |
| Intent / decision provenance | Repeated owner requests for independent review do not authorize merge; safer alternative does not erase prior negative findings. |
| Future potential | Workbench-facing compare/capture tools, readable immutable exports and targeted independent fault tests. |
| Cost / priority | High salvage value, modest renderer integration, potentially disproportionate shared-output recovery burden. Prefer scope-led selection later. |

**Four fates:** historical correction tickets need not remain obligations; their safety ideas and negative evidence survive; working renderer pieces are reusable; whole unsafe protocols are not promoted. No new OS process or graphical campaign ran in M1.

## 6. Design steering and new architecture work

**Members:** #497, #498, #500, #501, #506, #536, #549, #579, newly observed #582. Findings STATE-017–022.

[#506](https://github.com/techrote/cybersand/pull/506) is a substantive actual-Godot batch capture implementation on #487: shared render rig, full/viewport/detail/feature capture, source-preserving manifest and independent PNG verification. The reported exact-head 23-test Linux/Windows campaigns include 11 genuinely graphical cases per platform. Synthetic material condition bytes remain presentation fixtures, not native simulation. Cross-renderer comparison is about geometry and completeness, not equal pixels.

[#536's final checkpoint](https://github.com/techrote/cybersand/pull/536#issuecomment-6711162038) supersedes the body claiming a #516 stack: final `e1f4dcade2531ebe542a764b34a4f2c158b25d7d` is main-based after #516 merged. Three real before/edit/after render lanes are technically qualified. The [`pilot_quality.py`](https://github.com/techrote/cybersand/blob/e1f4dcade2531ebe542a764b34a4f2c158b25d7d/tools/atlas_agent/pilot_quality.py) checks structural custody, changed cells and source identity; it explicitly does not judge art. Scripted planners and changes affecting 0.059–0.213% of full-image pixels do not satisfy #500's substantive model-guided artistic improvement. #501's real native four-plane flagship remains separate from both existing GEN005 engine capability and simulation-free screenshots.

[#549](https://github.com/techrote/cybersand/issues/549) and [#579](https://github.com/techrote/cybersand/issues/579) are current planning records, not archaeological execution orders. #549 preserves the owner's preference for curated examples, deliberate structure, local variation, rejected attempts and design rationale. Its dated 13 November update puts native-grid prompt research first; older “first” milestone language lower in the body is historical. #579 proposes a 2×2 static feasibility slice before 4×4 and a broader matched experiment; its 108 attempts are a possible matrix, not an authorised budget. Images are reference material, not native ground truth. P3 changing tools is a tool-capability comparison, not pure prompt improvement. Existing model pilots and Workbench owners must remain undisturbed.

### Protected inventory delta: #582

[#582](https://github.com/techrote/cybersand/pull/582) is new active work at **`28f6e10ead3faa065c0130b614cb6c8dcdd96b3a`**, based on accepted main. It provides an Architectural Generator UI/project plus native recipe schema4/algorithm5 and module-v2 controls. The inspected [project compiler](https://github.com/techrote/cybersand/blob/28f6e10ead3faa065c0130b614cb6c8dcdd96b3a/godot/scripts/architectural_generator_project.gd) assigns largest-remainder quotas to contiguous intervals along a seeded/transformed Hilbert ordering. This supports one four-connected component per chosen style on a finite grid. It does not imply convexity, minimum zone width, unclipped room integrity or player connectivity. Zone shares include Empty cells, not merely occupied material. Native Arcology/Vault controls separately enable tunnels, doors and windows; a “door” is an aperture, not an interactive actor.

The final body records real Linux/Windows graphical/native/package qualification and a retained failed first legacy comparison. Typed-spatial fingerprint/receipt identity incorporates an ABI-dependent memory ledger; comparing Linux/libstdc++ to Windows/libc++ can differ while material and canonical recipes agree. The repair uses an independently built same-platform accepted base and preserves legacy identities. **Cross-ABI saved typed-map portability is not established.** [Source contract and limitations](https://github.com/techrote/cybersand/blob/28f6e10ead3faa065c0130b614cb6c8dcdd96b3a/docs/systems/architectural-generator.md) remain candidate-specific. Its square finite prototype does not override the owner's long-term broader non-square canvas direction. Human Windows11/display-scale acceptance and accepted-runtime publication remain separate. Protect this Draft/HOLD; no retirement or integration action is proposed.

| Dimension | Assessment |
|---|---|
| Applicability | Workbench-accessible generation, curated design and actual visual iteration strongly match present direction. |
| Recoverable value | Batch capture, guarded real-render loop, structural validator, design-trace plan, bounded native architectural UI and quota algorithms. |
| Staleness | #536 old branch-base wording, #497 implementation checkboxes, older #549 sequencing and historical resource/model assumptions. |
| Philosophy / architecture | Human control and meaningful scenes over volume; current owner preferences support optional modular tools without exact global simulation. |
| Implementation salvageability | #506/#536 tools are donors; #582 is active implementation to protect, not extract now; #579 is a plan, not code. |
| Empirical evidence / performance | Keyless real-render loop is genuine but not live critique; #582 timings are single-run hosted observations, not owner hardware guarantees. |
| Functional completeness / UX | Capture works experimentally; artistic improvement and #501 flagship not established; #582 physical owner acceptance pending. |
| Correctness / risk | Native/proxy confusion, style quota interpretation, cross-ABI fingerprint mismatch, source drift, cost claims and overlapping agents. |
| Dependencies / overlaps | Merged #516 runner, unmerged #487/#506, existing GEN005/007 and Workbench/SLM lanes; GEN006 is not prerequisite. |
| Intent / decision provenance | #549/#579 explicit roadmap-only authority; #582 explicit Draft/HOLD; prior failed art/model patch remains evidence. |
| Future potential | Small curated modules, genuine prompt research and flexible architectural scenes; actual research determines further scale. |
| Cost / priority | Valuable bounded opportunities, but avoid costly broad RAG/training/schedule infrastructure before demonstrated utility. |

**Four fates:** thematic opportunities replace fragmented automation obligations later; useful design direction survives; existing tools and active native candidates remain identifiable; weak/negative quality and portability results remain visible. M1 does not start Batch Lab, generate maps, call paid models, train or schedule workers.

## 7. Save and Flatten

**Members:** #548, #572, related current owner clarification. Findings STATE-005, 020.

[#548's dated 11 November correction](https://github.com/techrote/cybersand/issues/548) explicitly withdraws earlier World replacement, actor respawn, tick-zero reset, full physical continuation and complex rollback requirements. Its older [contract comment](https://github.com/techrote/cybersand/issues/548#issuecomment-6725828937) still names those behaviours; it is superseded evidence. The current owner wants the actual material layout after settling, erosion or reactions—not replayed original airborne oil/acid/water brushes. Explicit Flatten creates a **two-byte-per-cell** material baseline, retires old construction/history requirements and keeps the same live World. No general cell-carrier widening follows from LE16 storage.

The active [#572](https://github.com/techrote/cybersand/pull/572) source at snapshot **`8055a4a46f58b7afcd245ee344db2beb34ffb69c`** implements [bounded native bulk copy](https://github.com/techrote/cybersand/blob/8055a4a46f58b7afcd245ee344db2beb34ffb69c/native/include/cybersand/material_baseline.hpp) from `World::stored_material` into detached LE16 bytes under the existing exclusive owner. Its checks are not a lock; the caller must already own the World. The [authoring adoption](https://github.com/techrote/cybersand/blob/8055a4a46f58b7afcd245ee344db2beb34ffb69c/godot/scripts/shared_workbench.gd) changes the baseline, recipe/history references and related pending author responses without reconstructing physical World state. [The versioned container](https://github.com/techrote/cybersand/blob/8055a4a46f58b7afcd245ee344db2beb34ffb69c/godot/scripts/workbench_material_baseline.gd) stores bounded metadata plus the exact plane. [Native replacement](https://github.com/techrote/cybersand/blob/8055a4a46f58b7afcd245ee344db2beb34ffb69c/godot/native_extension/material_baseline_file.cpp) uses same-directory POSIX rename / Windows replace, with no predelete or copy/delete fallback; it explicitly does not promise general power-loss durability.

This work is protected active integration. The refreshed issue body describes source qualification at `0b026f6b…`, while snapshot tip is `8055a4…` and runtime/provenance paths are in the diff. Do not infer final-tip technical GO from older body counts or pending package language; the root performs final delta refresh. Preserve genuine earlier prepared-host baseline omission and failed-owner recovery errors, plus harness negatives: an ineffective Windows source-lock probe and console-launcher RSS measurements. Correcting a fixture or measuring the real engine is not evidence that an original product failure never happened.

Latest conversational owner intent also says ordinary Save should preserve the desired layout without unexpectedly destroying in-session Undo, maps need not always flatten, and no sweeping backward-compatibility guarantee is desired. Record that separately from historical evidence and the explicit active Flatten contract. This packet neither silently rewrites #572 nor turns it into a broad new save framework. Numeric ID reuse/remapping and actors/multiple layers are limits beyond a two-byte material plane; they are technical scope to resolve when that capability is implemented, not reasons to re-open settled intent.

| Dimension | Assessment |
|---|---|
| Applicability | Concrete current authoring/history pain; active implementation addresses the explicit revised Flatten operation. |
| Recoverable value | Owner clarification, LE16 copy/validation, authoring-only adoption, old-reader compatibility, atomic saved-start replacement and fault tests. |
| Staleness | Old 8-bit estimates, reset/respawn/rollback contract, earlier source qualification status and invalid launcher memory observations. |
| Philosophy / architecture | Practical material layout preservation; running physical state remains untouched, fresh loading is intentionally normal initialization. |
| Implementation salvageability | Protect #572 as current implementation; do not fork competing save work or cherry-pick during archaeology. |
| Empirical evidence / performance | Source-built native/Linux/Windows reports and full-plane readbacks exist; final tip/package qualification and physical owner acceptance remain source-bound. |
| Functional completeness / UX | Explicit Flatten implemented on Draft; ordinary Save and optional flatten semantics must follow current owner intent without forced history destruction. |
| Correctness / risk | Stale authoring generation, queued/unconsumed edits, partial capture/adoption, named-save replacement, failed owner and material identity drift. |
| Dependencies / overlaps | Shared Workbench, painting/agent execution, prepared starts, generated-start readers and active owner custody; no GEN006 prerequisite. |
| Intent / decision provenance | Explicit revised issue withdraws old scope; conversational decisions are current owner intent, not inferred from code. |
| Future potential | Layout fallback and bounded history compaction; broad persistence and area catch-up are separate capabilities. |
| Cost / priority | High immediate practical value; low conceptual scope, substantial native/platform integration already underway; avoid procedural expansion. |

**Four fates:** preserve current #548/#572 while active; retain the material-only snapshot idea; protect implementation/source identity; preserve withdrawn doctrine and all positive/negative qualification evidence. Retirement and successor issue creation are outside M1. The current programme is ready for the root's knowledge-transfer audit, subject to final live delta checks and named unresolved evidence scope—not a new engine implementation gate.

### Packet validation and remaining evidence limitations

All 60 assigned IDs appear exactly once and link to one or more of 24 finding IDs. Source URLs use immutable PR heads/current-main SHA where code claims depend on bytes, and comment/review URLs where historical state changed. Source-path validation found and corrected the semantic-plane runtime path to `godot/scripts/depth/semantic_plane_runtime.gd`.

Only the original S2A archive received a new raw-byte reduction in this lane. Historical reviews of other original ZIPs remain cited evidence; neither this packet nor a copied PASS table should imply fresh independent reacquisition. Several capture reviews cite external durable folders, but those folder contents were not verified here. The root also captured [#187's original retrieval artifact](https://github.com/techrote/cybersand/actions/runs/39472204492/artifacts/12288075182) before 19 November expiry: 790,623 bytes, SHA-256 `229f86f07a90ba83392b42a6a65abaceba3ad5da3ecd53f9e261307a22ac781b`, CRC passed, four frozen/challenge result/context members. Receipt: `archaeology_private/evidence/187_retrieval_capture.json`. This preserves historical contexts; no new retrieval execution or answer-quality claim follows. #454 visual quality, #513 local desktop originals, large Windows carrier readback and fresh current-main execution are explicit limits. No tests, benchmarks or application workflows were executed during M1 research.
