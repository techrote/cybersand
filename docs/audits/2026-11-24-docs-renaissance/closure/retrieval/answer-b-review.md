---
title: Closure answer applicability review by Specialist B
status: Current
document-kind: evidence
authority: historical-non-authoritative
retrieval: explicit-history-only
scope: Fresh review of 15 additive retrieval questions and all 75 saved contexts; bounded source checks, no external model benchmark
last-reviewed: 2026-11-25
---

# Product and workflow answers independently reviewed

**13 sufficient, 2 partial, 0 wrong-context answers across 15 questions.** B read
all five saved passages for DR01–05 and DR21–30 and wrote a bounded answer from
those contexts before grading consequential details against accepted source.
Canonical-document rank was not treated as answer completeness. This is a fresh
closure review, not an original-mission report or a benchmark of an external model.

The [machine-readable review](answer-b-review.json) binds the input packet,
evaluation report, evaluator, policy, every passage digest and the source files
actually spot-checked. Accepted source is `00cdb02f103265b6dc5224c68283e9a0c8cb449f`.

## Failures, correction and limits

**DR02 is partial:** the exact Godot executable pin is present, but none of the
five chunks supplies the godot-cpp commit or API pin. The bounded answer explicitly
declines to name them. The source lock confirms the missing values in the grading
record; they were not smuggled into the retrieved-context answer.

**DR04 is partial:** first-launch checks, provenance and isolated test data are
available, but the C header syntax probe and a focused engineering-test route are
missing. The answer gives the supported preliminary checks and identifies the gap.
The native build page ranks second; that does not make its selected chunk complete.

The initial DR22/DR23 context exposed **B-CLOSE-05 (P1)**: an integrated runbook
overstated prior-file preservation for all failed saves. B read all writer paths;
A corrected the runbook and duplicate architectural/generation routes. The separate
[delta cross-review](../product/review-technical-delta-by-b.md) records that closure.
The initial contexts and negative finding remain evidence. The qualified final packet
carries the corrected format-specific boundary and was freshly read. The related generated reopening
exercise now includes verified preview and explicit installation.

No paid provider request, external model test, embedding index, cache or agent
integration was exercised. An acceptable answer remains limited to declared source
and historical/intent scope; it does not prove a runtime or physical playtest.

## Final context binding

The reviewed final packet is [answer-b-delivered-input.json](answer-b-delivered-input.json),
SHA-256 `4cd86c209df86c070b0ab0b8524517a268ff934fae7950ecd4b044a3ad12093f`.
Its source report is [qualified-v2/candidate/renaissance.json](qualified-v2/candidate/renaissance.json),
SHA-256 `cf99fb78c12aa2f3a9e94e58d42d59b54f35a408cd22f3a25b043d8ef668abc5`.
B independently compared passage text, order and metadata across both packet
deltas. The first retained review transfers 74 equal passages; the one changed
exercise passage was freshly read. The final correction transfers 72 equal
positions; DR22 ranks 3/4 and DR23 rank 3 were freshly read. The JSON retains
those comparisons and passage hashes, without using scores to infer answer quality.
After the final desktop/Water Lab reopening correction, B independently verified
that all 75 delivered passages remain text/order/metadata-identical. The judgments
transfer to that final packet; [the prior review](answer-b-review-before-final-reopen.json)
is preserved with its original binding. A final wording correction identifies
DR29 rank 5 as `owner-confirmed-intent`; its stored metadata was already correct,
and its bounded answer already respected that scope. The previous JSON is retained
as [the pre-correction review](answer-b-review-before-authority-wording.json).

## Per-question answers

### DR01 — sufficient

I cloned CyberSand on Windows. Must I have C:/kybersand and dev.cmd before I can open the Workbench?

**Bounded answer.** No. A source-only checkout has its own launch-desktop.cmd; dev.cmd belongs to the separate companion workspace. Materialize the intended Git LFS runtime objects, run the repository/provenance check, and use the exactly pinned Godot executable. The repository launcher accepts an explicit Godot path or CYBERSAND_GODOT, so C:/kybersand is not a required checkout location. Its default project opens the Feature Launcher, which routes to the Shared Workbench. The wrapper checks runtime presence, the CyberSand DLL hash and the Godot version; the separate repository check compares source provenance. These are launch instructions, not proof that a launch or graphical acceptance has occurred.

**Context assessment.** Materials Lab and World Art evaluation passages describe separate routes. They do not override the source-only launcher route or establish that an old evaluator is presently available. No consequential conflict in the ordinary source-checkout route.

### DR02 — partial

Can I use any Godot 4 build, and which godot-cpp version matches the native library?

**Bounded answer.** No. The retrieved handover specifies Godot 4.7.stable.official.5b4e0cb0f and says a nearby patch release is a different qualification target. The native build passage requires pinned godot-cpp and enforces its revision through the build scripts; version similarity is not sufficient. However, none of these five passages supplies the exact godot-cpp commit or its API pin. I cannot identify that revision from the retrieved context alone. Read the native toolchain lock before choosing or rebuilding the dependency, then qualify the actual candidate runtime and provenance.

**Context assessment.** The canonical build page ranks first, but its selected section concerns commands and custody rather than the dependency table. Canonical page rank does not establish answer completeness. No contradictory dependency pin is present; the failure is omitted essential detail.

**Missing facts.** Exact godot-cpp revision is absent from all five passages. The godot-cpp API 4.7 pin is absent from all five passages.

### DR03 — sufficient

The native DLL is tiny text beginning version https://git-lfs.github.com/spec/v1. Is this a usable evaluator?

**Bounded answer.** No. That text is an unresolved Git LFS pointer, not executable native-library bytes. Obtain the intended committed runtime object with Git LFS and run check_repository.py --require-materialized to verify the materialized runtime, recorded source inputs and related dependencies. Use the exact platform and Godot pin. The Windows launcher additionally checks that the libraries are present and the CyberSand DLL matches its recorded hash. A pointer, a filename, a successful import or a provenance-only identity report does not qualify a running evaluator.

**Context assessment.** The World Art viewer passage that can run without native LFS describes its separate tool route; it is not an alternative native Workbench runtime. No conflict once the standalone viewer and native desktop scopes are separated.

### DR04 — partial

What is a small source-checkout validation before I launch expensive native and Godot matrices?

**Bounded answer.** Start by identifying the checkout HEAD and dirty state, materializing the required Git LFS objects, and running python3 tools/ci/check_repository.py --require-materialized from the source root. The retrieved procedure says this checks runtime bytes, recorded source inputs, documentation and dependencies, so inspect its actual failure. Verify the exact Godot version; on Windows, launch-desktop.cmd -PrintIdentityOnly checks the launcher prerequisites without launching or rebuilding. Any later Godot test should use an isolated test profile and preserve the actual result and first relevant error. These checks do not establish a complete native/Godot matrix or physical playability. The five passages do not provide a focused test selection or the bounded native interface probe requested by the full question; that part needs further retrieval.

**Context assessment.** Most retrieved material is first-launch/prerequisite guidance. It supports a safe partial procedure but not the complete bounded engineering validation request. No misleading pass claim or contradictory command; this is an answer-sufficiency gap despite canonical rank 2.

**Missing facts.** The C header syntax-only probe make c-header-check is not in these five passages. A concrete route to relevant focused tests and a small documentation structural-check command is missing; check_repository is only described as also checking documentation.

### DR05 — sufficient

Can native pool workers touch scene-tree objects and Rapier bodies?

**Bounded answer.** No. Native C++ owns authoritative cellular state and its internal pool workers call no Godot APIs. The exclusive desktop simulation owner may use its permitted adapter/value APIs, but live scene-tree and Rapier objects remain main-thread owned. Mutations are serialized through the owner boundary and consumers receive immutable owned observations; a worker must not share mutable World storage with presentation or use a Rapier body as native cellular authority.

**Context assessment.** The ownership table includes dated experimental LCB host rows. Those rows do not promote experimental full-host import or change the general native-worker/main-thread boundary used by this answer. No contradiction in the directly responsive ownership rules. Historical prototype qualification is kept separate.

### DR21 — sufficient

How do I configure a local LM Studio endpoint and custom model without sending a paid cloud request?

**Bounded answer.** Open Art batches, choose Model prompt and select the LM Studio provider preset. Use the local endpoint, normally http://127.0.0.1:1234/v1, and replace the model field with the exact model actually loaded by your local server. Leave the key empty unless that server requires one; do not fabricate a token. Keep the first turn count small and use the intended focus/work area. Configuration by itself does not need a paid cloud request; Direct JSON and the documented deterministic/keyless checks are available for a non-model walkthrough. Provider availability and parsed model output remain separate from native-confirmed geometry application, so inspect receipts.

**Context assessment.** The endpoint and model are editable source presets, not a promise that a local model is installed or currently available. No external provider was contacted in this review. No consequential conflict. Broader pacing and scanline sections are optional modes, not prerequisites for the small local setup.

### DR22 — sufficient

Does hiding the Art window mean its request was stopped?

**Bounded answer.** No. Hiding the Art window preserves its current session and does not mean a request stopped. Use Stop to cancel HTTP/capture/scheduled turns and request cancellation of native drawing at its admitted boundary. An already acknowledged or in-flight bounded part may remain, so wait for the terminal native result, inspect actual confirmed changed counts, and let pending work and receipts settle before Undo. Queued work alone is not applied success; Stop is not an automatic rollback of all prior drawing.

**Context assessment.** The responsive lifecycle passages distinguish window visibility, provider request cancellation, native execution and session end. The integrated save workflow is adjacent context, not a cancellation guarantee. The first packet included an unrelated overbroad failed-save preservation statement at rank 3. That was registered as B-CLOSE-05 and corrected against all writer paths before final-context approval. The bounded Hide/Stop answer never relied on that statement.

### DR23 — sufficient

After accepted ART-SESSION-LOG-001, are yesterday’s Art conversation messages automatically restored on the next game launch?

**Bounded answer.** No. The accepted session policy starts a new in-memory conversation for each game/session. Hiding and reopening the panel within that same session keeps its messages, while ending the session and launching again does not restore yesterday's chat. Provider preferences can persist separately. Each session has a write-only JSONL audit; old audit files may remain on disk but are not automatically reattached as model conversation. A World Save is not a provider-conversation save.

**Context assessment.** Session-local history and persistent provider preferences are separate data. Old traffic archives remain evidence, not an implicit request to restore chat. No current lazy-restore instruction competes with the accepted session-only rule. The unrelated save-preservation overstatement in the initial rank-3 passage was corrected as B-CLOSE-05 before final review.

### DR24 — sufficient

Which Art diagnostics can I attach to a public bug report without leaking prompts or credentials?

**Bounded answer.** Share a minimal, inspected and redacted failure report: source HEAD/dirty state, exact Godot and runtime/provenance identity, platform, command or synthetic reproduction, expected versus actual result, first relevant error and whether work was queued, applied, displayed or refused. Art traffic can include prompts, responses, endpoint information and images; automatic secret redaction does not make the whole file public-safe. Do not attach credentials, an entire user-data directory or an unreviewed conversation archive. Prefer a small synthetic setup and only the relevant sanitized excerpt.

**Context assessment.** This is practical minimization of the data the current diagnostics can contain, not a blanket claim that all redacted output is safe. No conflict: retained logs may aid reproduction while requiring user inspection before public attachment.

### DR25 — sufficient

Can I paint all four Strata Theatre planes in the ordinary Shared Workbench on main?

**Bounded answer.** No. The standalone Strata Theatre has its own layered presentation and authoring route; it is not evidence that ordinary Shared Workbench on the declared accepted source can edit those layers. The Workbench integration is a separately unmerged candidate at that source. Even the standalone controls do not mean every plane is freely paintable: the background is frozen, and standalone layer work has its own constraints rather than the ordinary Workbench Save/Flatten/history contract. Use the standalone guide for the demonstrated route and refresh candidate status before treating a later integration as accepted.

**Context assessment.** Accepted standalone availability, the background edit refusal and unmerged Workbench integration are explicitly separated. This answer is revision-sensitive. No authority promotion from standalone screenshots or candidate links into accepted integrated functionality.

### DR26 — sufficient

The render FPS is high and texture uploads are fast. Does that prove physical simulation and actor movement are playable?

**Bounded answer.** No. Render FPS and texture upload duration measure presentation work; they do not establish physical simulation progression, input responsiveness or playable actor motion. Desktop presentation and the native owner have separate schedules, and CPU upload timing does not by itself measure GPU completion. Use source-matched material/actor progression witnesses, actual input/result observations and the declared platform; keep native/Rapier progress distinct from render counters. Hosted/software rendering and dated owner observations cannot substitute for current physical Windows/GPU acceptance.

**Context assessment.** The October owner observation is a dated account of a problem and authorization, not a fresh acceptance result. Source-based ownership is general; playfeel needs actual execution evidence. No conflict when performance counters and physical owner acceptance retain their distinct meanings.

### DR27 — sufficient

Does enabling Web pthreads make the browser keep presenting while a native tick is running?

**Bounded answer.** No. In the current Web native profiles, _physics_process waits synchronously for the native simulation tick. Enabling pthreads permits internal native parallel work; it does not establish that browser presentation continues while that tick runs. Desktop has a separate simulation-owner scheduling path. Do not infer asynchronous Web presentation or exact backend parity from internal worker count, a successful compile/export or a separate desktop result.

**Context assessment.** Web compile, export and execution are separate checks. The historical physics baseline passage does not override the current synchronous ownership statement. No contradictory asynchronous Web claim in the five passages.

### DR28 — sufficient

Can I publish a rebuilt native DLL by editing its hash in the provenance JSON?

**Bounded answer.** No. Changing a provenance hash does not qualify or authorize publication. Retain the exact source and declared delta, dependency/build inputs, actual artifact bytes and hashes, scoped execution evidence and guarded branch/source custody. A runtime must match the recorded source inputs and intended committed LFS object; a predecessor pass, filename or edited metadata is insufficient. Follow the applicable guarded publisher and its authorization/lease, then verify the resulting head. A documentation-only change may retain an earlier build when its source inputs still match, without relabelling the build as the documentation commit.

**Context assessment.** The visual authoring/JSON passage at rank 5 is unrelated to native publication and contributes no publication authority. The launcher verifies a narrower prerequisite set than repository/source publication. The answer does not treat those checks as equivalent.

### DR29 — sufficient

A documentation or implementation Draft has skipped expensive jobs. Can I mark it Ready or merge it automatically?

**Bounded answer.** No. A Draft skip is an unexecuted gate, not a behavior pass or permission to promote. Ready and merge remain owner-controlled; this documentation mission stays Draft/HOLD until explicit owner adjudication. Implementation acceptance requires the applicable exact-resulting-head documentation/provenance, native, Godot, scoped apparatus and graphical evidence. Documentation qualification does not establish a runtime or physical acceptance result. A phase-specific owner instruction is not a general delegation to publish or merge.

**Context assessment.** Current repository policy and the phase-specific owner decision are authority boundaries. Dated platform test passages are limited evidence, not approval for this mission. No conflict after differentiating implementation qualification requirements from documentation-only scope.

### DR30 — sufficient

May I use the native-scope advisory to skip required jobs or copy an unmerged higher-fanout CI experiment into production policy?

**Bounded answer.** No. The native-scope advisory is informational and explicitly sets native_skip_authorized=false. It grants no exemption from required jobs. Use accepted workflow policy and preserve every mandatory case and sanitizer requirement; ongoing higher-fanout experiments are candidates until accepted. Scheduling estimates and concurrency limits do not turn incomplete, cancelled or failed evidence into success. Changing native-skip policy requires its own explicit decision and qualification.

**Context assessment.** Timing/scheduling advice is not scientific acceptance authority. Current accepted workflow behavior controls execution, while unmerged experiments remain candidates. No permission to skip is present; the explicit false authorization field is decisive.

## Independent source grading

The JSON records per-question symbols and file hashes. The documentation checker
is a candidate retrieval-validation tool and is labelled separately from accepted
runtime source. B inspected the launcher
and provenance checker; exact dependency locks; bounded C-header target; native
and desktop ownership; Art provider/session lifecycle; standalone layer refusal;
Web tick scheduling; runtime-publication safeguards; Draft policy; and the advisory
false authorization field. This is targeted source grading, not execution of those
paths. The launcher checkout uses CRLF while the accepted Git blob uses LF; its
normalized bytes match. No source edit is inferred from that representation change.
