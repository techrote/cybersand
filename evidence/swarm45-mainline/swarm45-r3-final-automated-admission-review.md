# Final independent automated-admission review — SWARM-004/005

**GO for the completed automated source, runtime-publication, Linux/Windows, extracted-package and final CI evidence at published head `919134a39d31461947c410c233d59d1965c48414`. No confirmed unresolved P1/P2 finding remains in this review's scope. Overall admission remains HOLD because the physical-owner evaluation of this exact reconstructed candidate is pending.**

All five requested final workflows are successful on their original attempt. The final Native aggregate has now been independently reproduced from all six families' original artifacts, closing the pending Native result in the previous checkpoint. This is an automated-evidence GO, not permission to record owner acceptance, mark Ready or merge while that mandatory owner gate remains open.

## Source and admission identity

| Identity | Verified value |
| --- | --- |
| Integration PR | [#715](https://github.com/techrote/cybersand/pull/715), targeting `main` |
| Integration branch | `integration/swarm004-005-mainline-20261121` |
| Accepted main and current PR base | `846fe0533b3170e7b01f690518da49fc40cc24d1` |
| Qualified R3 execution/build source | `96b8d3fb9d5a2e9f580d4b33293b1ab725269d4f` |
| Published and final-CI head | `919134a39d31461947c410c233d59d1965c48414` |
| Published tree | `78d6df75cb3534238c81b40e7bcdbe0cf693d012` |
| Native definition | `217bfa716e61198f5b3849f2ae14c30e85bc9f623fc1d05438c59df2296ce7f7` |

The final independent GitHub readback confirms PR715 is open, **Draft, unmerged and mergeable**, with `auto_merge: null`, exact head `919134a…`, and base/current main `846fe053…`. The same readback reports REST mergeable state `unstable`. All **77 check runs** are completed: **74 successful and three explicitly skipped**. The separate legacy combined-status endpoint has zero status contexts and reports `pending`; this is not a failed check, and no clean Ready state is claimed. No source modification, branch mutation, workflow trigger, rerun or merge was performed by this reviewer.

The publication-only chain retains the original R3 source identity. The request commit and eight-path publication commit do not relabel historical build receipts or change the 1,763 qualified build inputs. The separate immutable donor/source manifest remains the authoritative detailed mapping; this review does not turn preserved native V1 defaults into Workbench UI defaults or change transport V1/V2/V3 schema5 semantics.

## All five final workflows

Each run is `workflow_dispatch`, attempt **1**, on the integration branch at exact published head `919134a…`. Final status and job evidence were independently retrieved from GitHub.

| Workflow | Run | Result and actual scope | Elapsed |
| --- | --- | --- | --- |
| Documentation/provenance | [44957191341](https://github.com/techrote/cybersand/actions/runs/44957191341) | PASS; materialized-runtime/source checks, dependency/provenance checks, failure contracts, workflow inventory and Git LFS fsck | 9m09s |
| Native C++ | [44957198003](https://github.com/techrote/cybersand/actions/runs/44957198003) | PASS; policy, all six complete native families, exact-source final aggregate | 30m19s |
| GDExtension | [44957204571](https://github.com/techrote/cybersand/actions/runs/44957204571) | PASS; both builds, all 47 regression shards, Art graphical smoke, both coverage aggregates and timing history | 19m50s |
| Palette | [44957211504](https://github.com/techrote/cybersand/actions/runs/44957211504) | PASS under the unchanged registered v3 gate; older v2 finished-image diagnostic remains failed and retained | 7m08s |
| PLAY desktop packets | [44957219135](https://github.com/techrote/cybersand/actions/runs/44957219135) | PASS for identity/preflight only; physical/manual results remain untested | 1m27s |

No skipped job is counted as a passing test. The Ready-transition classifiers do not apply to these manual dispatches. The optional physical-actor stress campaign was not requested by the fixed default-input dispatch; it is distinct from the ordinary actor tests and from owner acceptance.

The final five-workflow batch took **30m23s** from the first run's creation to the final Native completion. The complete Native run is 19 seconds above the owner's desired ordinary-development feedback target. The measured dominant family was world generation: 28m46.749s of family execution, including **23m16.197s for the complete sanitizer build/test command**, 3m53.947s for normal world generation and 1m35.676s for sanitized physics characterization. This is a concrete follow-up bottleneck, not a reason to weaken coverage or import unrelated CI redesign.

## Final Native proof and executed catalogue coverage

The reviewer downloaded the remaining original worldgen artifact and final aggregate artifact and verified their GitHub archive sizes and SHA256 values. All six family artifacts were then re-read through the committed evidence verifier using fingerprints independently derived from immutable `919134a…` source blobs. The resulting JSON is **exactly equal to the hosted final aggregate**: six expected/received families, all successful, original shell and command exit codes zero, complete ordered command receipts, exact raw-log/scientific-output hashes and **no errors**.

The normal, ASan/UBSan and ThreadSanitizer families each executed all **192 registered core cases in source order**. Normal also completed its C-header, shared-library and benchmark commands. Both soliding families completed their registered lifecycle, discovery, storage, spatial-index, mutation and activity checks; the sanitizer path includes the complete eight-binary suite. Sanitizer settings remain those in the registered source, including the existing ASan leak-detection setting; this review does not claim additional leak-sanitizer coverage.

Both the normal and ASan/UBSan world-generation commands executed all **16 registered test binaries**. Their original logs contain the same following showcase outcomes:

| Existing showcase | Normal result | Sanitizer result |
| --- | ---: | ---: |
| Megatruss Station | 1,499 assertions, PASS | 1,499 assertions, PASS |
| Seeded Typology Megablock | 19,750 assertions, PASS | 19,750 assertions, PASS |
| Metabolist Spine | 204,424 assertions, PASS | 204,424 assertions, PASS |
| Interlaced Viaduct | 1,305 assertions, PASS | 1,305 assertions, PASS |
| Rosework Gatehouse | 166,489 assertions, PASS | 166,489 assertions, PASS |
| Interlock Brutalism | 1,725 assertions, PASS | 1,725 assertions, PASS |
| Suspended Arcology | 26,265 assertions, PASS | 26,265 assertions, PASS |
| Cathedral Megaframe | 552,616 assertions, PASS | 552,616 assertions, PASS |

Both Megablock logs also retain **148 repaired CLASSIC material maps** and **32/32 distinct declared seed maps**. The showcase JSON reports retain their actual structural, negative-space, continuity, parameter and refusal gates. Cathedral's count is part of the procedural executable's total; these numbers are not added together as independent totals.

The actual normal and sanitizer `test_world_generation` executions each finish with **969,803 assertions and exit zero**. Their exact compiled source calls `classic_architectural_genteks()` unconditionally before that success line. That function exercises all **80 catalogue entries** across four chunks each, checks ready generation, work-slicing and receipt equality, structure and negative space, schema/version refusals and **80 distinct material signatures**, and verifies the **72 CLASSIC material-stream oracle `0xe0aec65cb4c2b5f1`**. The test does not print a separate per-module PASS table; catalogue completion is established by these actual successful, source-bound executions and their unconditional assertions, not merely by unchanged source.

The normal and sanitizer logs additionally record successful world installation, fields/modifiers, typed-field integration, spatial generation, **208,725 semantic-grammar assertions**, and **774,842 semantic-plane assertions with zero failures**. The eight catalogue/showcase test-source blobs were also compared against accepted main `846fe053…` and are byte-identical.

Native final aggregate artifact: ID **14729310942**, 11,471 bytes, SHA256 `8b5f96cb9223caee85d27c81e53cd006721420beabcda3df57c721ea3f225177`. Worldgen original artifact: ID **14728099439**, 161,058 bytes, SHA256 `4ed75169870271b0450d1a378dc69f7ada3335b019c3a690f3a8e5a1009573ab`.

## Complete Godot coverage and runtime distinction

The completed GDExtension review remains GO. The independent offline replay covered all **49 original shard/runtime artifacts**, totaling 134,067,211 bytes, after validating their GitHub archive digests and sizes. It reproduced both source-derived hosted coverage reports and re-read 30 retained automated PLAY correctness packets.

| Platform | Completed cases | Shards | Verified original case/import logs |
| --- | ---: | ---: | ---: |
| Linux | 342 | 24 | 366 |
| Windows headless | 319 | 23 | 342 |

Windows headless coverage additionally verifies 1,104 source-input identities. Its **23 display-requiring exclusions remain explicit** and are not counted as passed Windows headless tests. The separate R3 Windows graphical/source/extracted-package campaign supplies the SWARM graphical qualification.

Final GDExtension builds use source `919134a…`. Their Windows candidate SHA256 is `a51594220c382090267bc92be1a495a64652251e504b6d46ba8343c32e7e66fb`; its 106 native source-input hashes exactly equal those of the published R3 adapter. It is correctly distinct from the **published** Windows adapter `c7fc1fbfea2999489ae83a6da100ca795b336dc6efa251af7e5003071a2bb43d`, whose build/source remains `96b8d3fb…` and whose actual execution is covered by R3. The final Linux adapter is byte-identical to its published counterpart. No candidate was substituted into publication during this review.

## Publication and Windows evaluator custody

The earlier actual-publication and R3 Windows reviews are complete and unchanged. Publisher run **44956855133** succeeded and changed exactly the authorized eight runtime/provenance paths. All four binary LFS OIDs and sizes, all four manifest byte streams, the sole parent and the Linux CLI executable mode match the exact qualified publication candidate. The bounded dispatcher then requested exactly the five fixed workflows above; it did not enable auto-merge, promote Ready or mutate product source.

Documentation and both PLAY packet prechecks prove hosted materialization of the published runtimes, including both reciprocal CLIs and native adapters, with successful Git LFS checks. The review machine's pointer-only checkout is not misrepresented as local execution.

The R3 Windows source and freshly extracted evaluator layouts each completed their **14 required integration processes**, including graphical transaction/create/reopen/blocking/lifecycle cases, and **17 existing integration smokes**. Raw native source, receipt, full-map, save/reopen, screenshot and package-manifest custody was independently verified. The positive reciprocal recipe retains eight foreign joints; the source-feasible local-completion example retains zero foreign joints; genuinely blocked controls remain blocked. Local welded completion is not relabelled as foreign reciprocal success.

The exact current evaluator remains:

- Filename: `CyberSand-SWARM45-Draft-HOLD-Windows-96b8d3fb9d5a.zip`
- Size: **95,359,907 bytes**
- ZIP SHA256: `ce50316be11caafe32879395b681ef7f131541732061ded5db36dc3af6236c6d`
- Candidate-manifest SHA256: `73ae92f19034bf8a9311430200c269df1b18e6c2a2ee18c8609ef62379daaf3b`
- Current primary owner-guide SHA256: `74688f455b2a60075ebcde3e21a0147b7e1ab5d936e7d048476ebceff4b3745e`

All 1,087 manifest payloads and the archive inventory were independently checked. The historical bundled donor guide remains historical; the current primary guide beside the unchanged ZIP binds the actual candidate and supplies the current immutable integration instructions. Its incomplete relative offline runbook link remains the previously disclosed P3 documentation limitation, not a hidden source or package retag.

## Preserved negative results and mandatory HOLD

Palette's registered **v3** gate passes with six cohorts and 19 process cases. Its outgoing CPU-base frames have zero pixels outside the original 2/255 tolerance. The older **v2 finished-image diagnostic remains failed**: six blended/full-current frames each have 11 of 2,304 pixels beyond that older threshold, with maximum recorded difference `0.3009393513202667`. The workflow, runner, contract, contract tests and shader remain byte-identical to accepted main. This is not a changed admission policy and does not establish pixel-identical native/ANGLE finished images.

Every one of the **51 manual PLAY rows per platform remains `untested`**. Those packets establish identity/preflight only. Their passing workflow does not perform physical desktop acceptance, and the automated correctness readbacks do not replace it.

The user-required physical-owner/original-map/NVIDIA evaluation of this **exact reconstructed evaluator** remains pending. Prior evaluation of donor builds is not current candidate acceptance. Frozen scientific receipts, held-out/control findings and negative cases remain intact; this experimental authoring integration is not evidence that reciprocal architectural negotiation is generally solved.

**Final review decision: automated admission GO; overall mainline admission HOLD until the exact-candidate physical-owner gate is completed and accurately recorded.** No additional automated campaign is requested by this review. Any later product-source change or base movement must be assessed against the immutable identities above before reusing this conclusion.

## Retained independent proof

The final machine checkpoint is `swarm45-publication-review-evidence/final-gates/final-automated-admission-checkpoint.json`, SHA256 **`f1227eadb82683c3262cc2c48b8a641aeab7ebcd53bb6a65d27b200bdc720d9d`**. It binds the final five-run/API snapshot, publication and platform reviews, raw artifact identities, native aggregate, catalogue/showcase proof and owner package.

The independently reproduced Native aggregate is `independent-native-complete.json`, SHA256 `06ebd57da3e08c77f6164262d3d2b9fcbd3b16fe7e083cea126e7781fbebe4f2`. The focused actual catalogue/showcase proof is `worldgen-catalogue-showcase-proof.json`, SHA256 `ae8d6b897b074368f3a793468f1153980e20c08ccb2b4e305f0e340cb28afbd2`.

This review is read-only with respect to repository source, branches, PRs, workflows and SWARM006. The completed offline operations only inspect/reduce original evidence and write independent review artifacts.

