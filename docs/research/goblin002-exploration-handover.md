---
title: GIP-014-goblin-002 exploration specialist handover
status: Planned
document-kind: research
scope: Branch-scoped goblin exploration mechanisms and bounded experiment memory; Draft/HOLD
canonical-for: [goblin002-exploration-handover]
last-reviewed: 2026-11-25
related-documents: [gip014-goblin-gameplay-qa.md]
---

# Exploration specialist handover — Draft/HOLD

## Source and ownership

This successor begins at predecessor `d4484bd5b488cb419bfaa94f1e69be8128734405`,
including the separately documented shared CI repair. Predecessor native gameplay
qualification and evaluator identities are preserved by ancestry; the additions
below do not relabel that evidence.

The exploration lane owns `godot/goblin/goblin_policy.gd`,
`goblin_state.gd`, `goblin_coverage.gd`, `goblin_corpus.gd` and
`godot/goblin/tests/test_exploration.gd`. The lead owns the controller,
laboratory and fixed-profile file controls. The gameplay lane owns the actual
action adapter and its observations; the replay lane owns tapes, independently
recomputed campaign results and regression packages.

## Current source behavior

The six original policy generators remain intact: CONTROL, WANDERER, BUILDER,
TINKERER, CURIOSITY and RANDOM. Ten additional personalities share finite
intentions and weighted state-sensitive action selection: STATEFUL, NOVELTY,
COVERAGE_HUNTER, DISASTER_ARTIST, BOUNDARY_GOBLIN, HISTORY_GOBLIN,
MATERIAL_ALCHEMIST, ACTOR_ENTHUSIAST, IMPATIENT_SWITCHER and
OBSESSIVE_REPRODUCER. Their action families and parameter choices differ under
matched synthetic observations; native behavioural diversity remains a separate
campaign result.

New personalities use the actual offered adapter menu. Reusable primitives
construct cups, place two admitted materials, advance simulation, breach and
repair gates, exercise reversible edits and authored persistence, visit bounded
corners, or investigate observed actor capabilities. An offered or queued action
is never treated as a successful action. A proposed actor placement does not
make its intended identity selectable.

`goblin_state.gd` produces a bounded state projection from actual observations.
Missing facts stay unknown. The projection includes fixture, observed world size,
pause state, tool/material/radius, history, bounded selection and clipboard state,
actor models and spatial zones, pilot role, saved-state availability, camera,
configuration and coarse native progression phase. Exact generation, revision,
tick and physical epoch remain separately available as observation identity.
Their increasing integers do not create unlimited novelty.

Material composition is explicitly a source-matched captured-region sample.
It is not inferred from selected material, fixture recipe, nominal capability or
the entire World. Every accepted material sample checks its capture operation,
native identity, paused source stability, bounds and array shape.

## Coverage contract

Current-episode coverage and historical search hints are separate. Persistent
hints retain up to 256 action frequencies, state/action visits, adjacent action
pairs and parameter variants per map. They affect priorities only; imported
values never populate the current-episode evidence maps.

| Dimension | Required observation and meaning |
| --- | --- |
| Action vocabulary | Actual admission, observed native before/after and completed terminal status |
| Action transition | Adjacent completed admitted actions; a refusal or partial operation breaks adjacency |
| State transition | Admitted completed or partial operation between bounded factual state signatures |
| Material interaction | Source-matched captured-region adjacency or independently read edit transformations; no inferred chemical reaction |
| Tool/material | Completed native edit and an actual observed tool/material pair |
| Actor/environment | Observed actor model, authored fixture, world spatial zone and pilot role; no inferred contact or route success |
| Lifecycle | Observed pause/play, world replacement, authored identity, actor population, control or saved-state transitions |
| Boundary/refusal | Actual refused outcome with its explicit classification and reason |
| Outcome | Observed terminal status, receipt/change bucket, native progression relation and independent failed-assertion identities |

Each map holds at most 2,048 keys, then reports saturation explicitly. Counts
cap at one million. Refused parameter variants reduce their repeat-selection
priority without being promoted to completed-action evidence. Parameter variants,
native observations absent from a record, partials and refusals have separate
reported counts. The predecessor's `observed_action_counts` remain attempted
policy-history statistics; the new `coverage` object is the admitted-coverage
authority.

## Corpus and controller integration

`goblin_corpus.gd` is pure data. It accepts no path, executes no action and
performs no file or network access. Controller-owned verified-profile operations
provide fixed-path clear/import/export controls.

A corpus holds at most 64 interesting records and 2 MiB of serialized data.
Complete action prefixes stop at 128 actions. Observations later in a 1,024-action
episode retain identity and classification, but no truncated setup prefix and
no claim of a resumable physical state. Retention favors higher-scored discoveries
and independently failed assertions; equally scored oldest records retire first.

A record binds exact fixture ID/version, authored fixture digest and provenance
digest. Successful complete prefixes may be explicitly reused only from a newly
installed matching authored fixture and before the first policy decision.
The preserved six baseline personalities do not use prefix replay, maintaining
their controlled comparison role. Imported records are marked
`imported_unverified`; serialized confirmed findings are downgraded to unresolved.
No import creates current-episode coverage, and no failed assertion is automatically
classified as a production defect.

Import is transactional and requires the finite adapter action validator.
Malformed or oversized nested values, unknown actions, duplicate record identities,
wrong numeric bounds, stale semantic record hashes, incomplete prefixes and
failure-as-success claims refuse before any retained memory changes.

Controller sequence:

1. Construct one corpus for the isolated laboratory session and optionally import
   a bounded supported record through `import_data(value, adapter_validator)`.
2. Configure a policy, install the disposable fixture and call
   `policy.bind_memory(corpus, context, reuse_prefix)`.
3. Supply context `fixture_id`, `fixture_version`, `fixture_sha256`,
   `provenance_sha256`, `seed` and `personality`; the provenance digest is the
   canonical digest of the validated portable replay-identity tuple plus source-dirty
   flag when available; legacy provenance retains strict full-value identity.
   The tuple still binds source, executable-input and runtime hashes. Host/Python
   labels remain preserved as evidence without preventing same-input package reuse.
4. After actual execution and independent assertions, append the transcript row,
   then call `policy.observe_result(transcript.steps.back())`.
5. Persist the bounded `corpus.export_data()` through the controller's fixed
   profile location. A subsequent process resumes an experiment queue or reuses an
   authored prefix, never an asynchronous physics snapshot.

Policy API remains `configure`, `next_action`, `observe_result` and `summary`,
with additive `bind_memory`, `coverage_memory` and `describe`. Summary includes
the current intention, last novelty, coverage, memory classifications and the
explicit prefix-reuse request. Corpus exposes `begin_episode`, `observe`,
`export_data`, `import_data`, `clear`, `summary`, `reuse_actions`,
`search_hints` and `compatible_context`.

## Qualification and retained limits

The execution host disappeared during intake before any local implementation
existed. Implementation continued as tool-store source and recoverable Git blob
objects. After replacement, the shared predecessor checkout and pinned runtime
were restored. Neither the outage nor the original workspace capacity problem
is classified as a CyberSand defect.

A separate pure temporary Godot project ran the exploration tests on Linux x86_64,
first with available Godot 4.7.2 for parser feedback, then with exact
`4.7.stable.official.5b4e0cb0f`. The latest exact-version synthetic test run
passes **154 checks**, including all 16 policies, distinct action-only sequences,
source/capture admission, fresh material probes, actual configuration fields, refusal starvation, exact-context memory reuse,
transactional hostile imports, exact paint-tool/material accounting and 1,024 synthetic observations with bounded
retention. It is mechanism evidence only: no native gameplay occurred in that
pure project and no game-engine defect was found by it.

Command:

```text
Godot_v4.7-stable_linux.x86_64 --headless --path <isolated-pure-project> --script res://goblin/tests/test_exploration.gd
```

Shared-project/native, graphical, long-horizon, replay, Windows and extracted
package qualification belongs to the integrated mission ledger. A pure test pass
does not close those gates. The exact final integrated source, campaign outcomes
and runtime/package identities must be supplied by the lead.

## Documentation change map

The predecessor guide remains the preserved evidence home. This branch-scoped
handover records the new mechanism contracts and test limitations. The lead's
successor guide, mission ledger, retrieval exclusion and developer controls will
route this candidate explicitly. Accepted startup, production physics, ordinary
Workbench behavior, the historical archaeology corpus and other active programme
branches are unaffected by this lane.


## Independent laboratory review and retained follow-ups

Source review identified and the lead repaired these harness issues before
qualification: a Step credit could be consumed while no action was available;
reduction acceptance needed the failing action identity and completed terminal
classification; reduced export needed exact original/reduced tape relationship
checks; unexplained gameplay refusals needed unresolved classification; and
paced reduction probes needed a real-time deadline as well as an active-time
deadline. These are goblin harness review findings, not production gameplay
discoveries.

The separate `test_laboratory.gd` contains two explicit evidence modes. Its
ordinary mode exercises actual paused decision stepping, isolated corpus
clear/export/import, reuse in a fresh native fixture, and a positive ordinary
four-Pause reduction with two fresh confirmations and a matching exported bundle.
That reduction is legal semantic-outcome reduction, never a failing game
regression. Deliberately malformed corpus, Findings triage and reduction
acceptance controls are recorded in their own array. The fixed test-only
`CYBERSAND_GOBLIN_LAB_CONTRACTS_ONLY=1` mode constructs no World and reports
`native_cases: 0`; it must not stand in for the actual laboratory gate.

| Retained local attempt | Outcome and interpretation |
| --- | --- |
| `laboratory-001` | Direct headless actual-laboratory attempt, without a clean editor import because no generated cache remained. External signal 9 after 0.507 seconds, sampled peak 150,646,784 bytes, no Godot diagnostic or test outcome, no surviving owned process. No gameplay result is inferred. |
| `laboratory-contracts-001` | Exact Godot 4.7; 16/16 checks pass, 15 explicitly synthetic controls, zero native campaigns, 2.718 seconds, sampled peak 268,902,400 bytes. Relevant source hashes remained unchanged. |
| `laboratory-contracts-002` | Automatic-capture controls exposed two test-oracle failures: the test compared integer-valued in-memory dictionaries with JSON parser floats using an unnormalized digest. Independent parsed-file comparison showed candidate, raw archive and transcript values equal; raw archive/transcript bytes were equal. This attempt is retained as a test-oracle defect, not a custody or gameplay defect. |
| `laboratory-contracts-003` | Exact Godot 4.7; 27/27 checks pass after canonical JSON normalization, 26 explicitly synthetic controls, zero native campaigns, 3.416 seconds, sampled peak 270,331,904 bytes. Actual fixed-path automatic-candidate writing and separate raw-archive custody were checked with a unit-fixture tape. Relevant source hashes remained unchanged. |
| `laboratory-contracts-004` | Latest exact Godot 4.7 control run passes 30/30, 29 explicitly synthetic controls, zero native campaigns, 3.225 seconds, sampled peak 269,180,928 bytes. Added valid-fingerprint controls accept JSON-equivalent numeric arguments/expectations and reject a changed action parameter or expected contract. Relevant source hashes remained unchanged. |
| `policies-legacy-001` | Existing policy/fixture suite: 333 checks, one failure because the first Alchemy recipe exceeded its original 20-edit bound. This was a fixture/harness issue, not a production defect. |
| `policies-legacy-002` | The gameplay lane simplified Alchemy to 18 ordinary rectangles, preserving the original bound. Exact 4.7 rerun passes 333/333 with 16 policies, 10 recipes and 64/128/256 synthetic decision budgets; 9.059 seconds, sampled peak 138,412,032 bytes, relevant source hashes unchanged. |
| Later laboratory parser attempt | Exit 137 without a parse diagnostic while the host was intermittently killing processes. The new actual positive-reduction case still needs its integrated hosted runtime gate. |

The actual laboratory attempt used a 120-second external wall bound and
2,048-MiB sampled process-tree RSS cap. Lightweight contract and legacy-policy
runs used 30–40/60 seconds and 1,024 MiB respectively. Sampling every 100 ms does
not rule out an unobserved allocation spike; signal 9's cause remains unestablished.
The full laboratory test now has a 240-second local watchdog, with a 300-second
external qualification budget requested. It preserves original and reduced
native tapes in the profile and excludes injected controls from game findings.

The lead retains these attempt directories with the integrated evidence packet.
Source blobs protect the implementation through another execution-host replacement;
they are recoverability checkpoints, not runtime verdicts.

## Independent comparison readiness review

The proposed matched cohort has nine selection modes, four authored fixtures
and three seeds: 108 episodes with 64 attempted-action slots each. Its sampling
unit is one fresh disposable episode. A comparison block is the tuple
(fixture, seed, budget), giving twelve blocks with nine expected modes per
block. The plan randomizes execution order with a fixed order seed and fixes
pacing, initial memory, source/runtime and process bounds. This supports a
descriptive paired comparison; three seeds do not establish broad statistical
generalization to all gameplay.

The independent Python coverage reader initially retained an older observable
state projection. Review identified missing actor control/capability fields,
current source-matched material probes, preview/source presence, and the actual
configuration/camera field locations. It also identified missing-key lifecycle
comparisons and refused-variant accounting that differed from GDScript.
These are evidence/harness concerns. The delivery specialist owns the correction
and synthetic cross-language differential checks before final qualification.
Sharing a coverage definition across languages checks accounting consistency;
it does not by itself provide an independent physical game oracle.

For the final comparison, retain these separate measurements:

| Measurement | Valid interpretation and denominator |
| --- | --- |
| Episode completion | Fraction that reached the requested attempted-action budget, with failures, cancellation, missing evidence and resource limits separately retained. This does not imply every action completed. |
| Actual work | Attempted records, admitted observed actions, completed admitted actions, partial effects and refusals. Compare both per requested budget and per admitted action. |
| State exploration | Per-episode unique observed transitions and state/action pairs, plus paired differences within identical fixture/seed/budget blocks. Pooled unique keys grow with exposure and must not substitute for matched exposure. |
| Material variety | Valid source-matched captured-region adjacency and edit transformations; it is neither chemical-reaction success nor whole-World coverage. Policies choose different probe regions, which is part of their behavior. |
| Actor variety | Observed model, fixture, spatial zone and pilot role; it is not route completion or a nearby-material interaction claim. |
| Behavior diversity | Actual completed-action/family distributions, action-transition variety and overlap across personalities on common fixtures/budgets. Synthetic sequence differences alone are insufficient for a native personality claim. |
| Resource cost | Per-attempt wall time and sampled process-tree peak RSS; report all-attempt cost alongside the selected latest attempt so retries retain their cost. Missing resource records remain unknown. |
| Failure handling | Candidate invariant failures, independent reproduction, reduction acceptance, confirmed classification and evidence failures remain separate counts. Novelty or a refusal is not a confirmed defect. |

The report should identify complete versus missing matched blocks before
summarizing policy gains, label its selected-attempt rule, and retain first-attempt
completion and all attempts in the evidence packet. A partial or infrastructure
failed episode may still contain valid observed actions; report those as partial
evidence without treating missing later actions as observed zero coverage.
Completion-conditioned comparisons and all-planned-case completion are different
questions and should be shown separately when failures are uneven.

The long-horizon cohort currently compares RANDOM and COVERAGE_HUNTER on one
construction fixture and one seed at 128, 256, 512 and 1,024 actions. Report actual
completion, wall/resource bounds and retained failures at every horizon. It
supports engineering capacity evidence at those settings, not a general claim
that one policy scales better across game worlds.

A further UI source-review concern was reported to the lead: replay could retain
a previous reduction result while replacing the selected original tape, causing
a safe but confusing export refusal. Clearing stale reduction metadata before
replay preserves the exact accepted-original binding without weakening export
validation.

### Paired-comparison appendix implementation

`tools/gip014/paired_comparison.py` consumes checked latest-episode results,
the immutable queue plan and optionally all checked attempt receipts from the
delivery lane. The queue report includes its output. The standalone fixed
reader can regenerate a separate appendix with:

```text
python tools/gip014/paired_comparison.py --out <existing-campaign-queue>
```

The analysis reports each matched block, unattempted or invalid modes, all
planned versus budget-complete distributions, paired candidate-minus-baseline
observations, medians and interpolated quartiles. An absent observation remains
null; an actually observed zero remains zero. Partial valid gameplay can
contribute to the all-planned observed distribution without qualifying its
episode as complete. An unavailable or mismatched coverage record contributes
no invented coverage, while independently measured process cost is retained.

All-attempt cost explicitly includes retries and first-attempt completion.
Missing cost records remain unknown. Completed-action frequencies and entropy
are descriptive behavior measurements; they are not a policy ranking or bug
yield metric. Paired comparisons condition on both selected episodes completing
their attempted-action budgets. The report states this condition, records all
excluded blocks, and performs no causal analysis, confidence interval or
significance test.

Eight artificial Python tests pass. They cover a full 108-episode/twelve-block
constructed cohort with known paired differences, a missing episode, partial
observations, an actually observed all-refusal zero, coverage mismatch, retry
cost, missing resource records and duplicate/foreign identities. These tests
establish reporting behavior only and are explicitly not native game evidence.

The matched queue starts with fresh memory and explicitly disables retained
prefix reuse. Its comparison measures within-episode exploration. A native
prefix-reuse laboratory pass would establish the persistence mechanism, while a
claim that retained memory improves discovery would require a separate matched
cold-versus-common-prior experiment.

Review tightened tool/material keys before qualification. They require a
completed paint action, completed native edit receipt, source-matched material
capture, the actual observed tool corresponding to the operation, and unchanged
integral selected material before/after execution. Admitted operation/tool pairs
are Brush/brush, Rectangle/rectangle, Outline/outline, Line/line, Brush/stroke and
Fill/fill. Fill only counts with Fill actually selected because the ordinary
fill method otherwise leaves the selector unchanged. Erase, Undo/Redo, Paste,
interrupted and live operations keep their separate action/effect evidence but
receive no credit in this paint-tool/material dimension. The Python reader uses
the same finite predicate with independently recomputed keys.

The focused pure exploration rerun `exploration-tool-material-001` passes
148/148 checks on exact Godot 4.7, with 16 personalities, zero native game actions,
3.531 seconds and 113,033,216-byte sampled process-tree peak. It includes six
excluded non-paint/cancellation operations, wrong observed tool, changed palette,
partial operation and a positive captured geometry-tool pair. The source files
were copied into a dedicated pure project before execution; no native library
or World was loaded. Log SHA-256:
`1d779e08dfe56ab6d5b85cb5c0afb06970be54b3f5c8fac01c56afb807ccbbe0`.

A final reporting review separated retained-prefix queue length from actual
proposals. `retained_prefix_actions_queued` reports the selected bounded
prefix length; `retained_prefix_actions_proposed` increments only when
`next_action` returns one of those candidates. Unavailable skipped steps and
budget-truncated suffixes do not inflate proposals. The added one-action synthetic
control verifies four queued candidates, one proposal and zero gameplay coverage.
The exact 4.7 pure rerun `exploration-prefix-counter-001` passes 149/149 checks
in 3.531 seconds with a 112,578,560-byte sampled peak. Its source files were copied
before execution and no native World was loaded. Log SHA-256:
`8310e3e64876af975d6caab341f200993e64a8fef0948649965f0e229b072542`.

After the lead additionally bound reduction acceptance to original action status,
classification and semantic admission, the unchanged no-World laboratory control
suite passed 30/30 again in `laboratory-contracts-005`, 3.226 seconds and
269,357,056-byte sampled peak. Exact source hashes remained unchanged during that
run. This is synthetic acceptance/custody evidence, not native gameplay.

### Finite-boundary classification alignment

Corpus and Findings now use the same pure
`GameplayOracles.expected_boundary_refusal(record)` proof check. Unknown
partial results remain unresolved. Only the exact current-source published
finite-canvas stop, matching native owner/tick, before-generation, paused healthy
state and interrupted interval, qualifies as an expected refusal. Failing
invariants and native/adapter failures take precedence. This adds no nominal
coverage and makes no production-defect claim.

Corpus therefore has one additional pure script dependency,
`goblin_gameplay_oracles.gd`, included in isolated unit/parity staging. Five
focused controls cover an unknown partial, supported proof, stale source,
failed invariant and native failure. The source-copied pure run
`exploration-boundary-classification-001` passes 154/154 on exact Godot 4.7,
3.524 seconds, sampled peak 115,228,672 bytes; no native World was loaded.
Log SHA-256:
`56809671f3767799586ee3aaf55749224e9ada92b41d0449aeaef933c06d9be5`.

## Recovered candidate pure preflight — 25 November 2026

After the second host replacement, the nine Specialist A source files were restored from their immutable blobs and byte-verified. The lead reconstructed the controller and UI as an explicitly recovered candidate; this is not a claim that the lost final tree was reproduced byte-for-byte. Read-only review found the expected reduction action/argument/admission/status/classification binding, numeric JSON normalization, automatic unresolved candidate capture, fixed evidence bounds, and portable memory identity. An inconsistent reproduction fixture-hash header check was reported and corrected before this preflight. The adapter already hashes the entire authored recipe into its scene identity.

A fresh staged project from base commit `be64fa7896a37672c3e5d0652517789e469b9061`, tree `c0d2875b01c41f7287fa9191922e2b3bf88b222b`, with explicit working changes (`source_dirty=true`), executed controller blob `db682dd494adc938cdf6862dae2728797bc2d004`, UI `390a0973f54a10dc1e4104a767c04fe015bc91dc`, and laboratory test `7ddfa44ce8b7ae1cba915d5e1d017b5577f94634`. All 973 staged project files remained unchanged during execution. The complete project-file manifest digest is `efd911730be695f4845e8766bb68c47c2760c4294c65cc181dbd1f41f77f5e53`; this manifest counts all staged files, separately from the portable replay identity's filtered game-source manifest.

The engine was the retained exact Godot 4.7 binary, SHA-256 `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`. The native library `a15fc422313eb01e79bc904f44cc8879816484ae4fc98c63ac4b815afdb6a5e7` matched all 105 declared source inputs; Rapier `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` matched all 4. Only these two fixed LFS library pointers were materialized. No native rebuild, resource import, World mount, or gameplay campaign was performed.

| Check | Result | Elapsed seconds | Sampled peak tree RSS bytes | Raw log SHA-256 |
| --- | --- | ---: | ---: | --- |
| Exploration controls | 154/154 pass; 16 personalities; synthetic fixtures | 3.523 | 152588288 | `288292f457910f778de2e6f0cfaed9203835b053e5ac52c5a1ae99d5e08856b5` |
| Laboratory contracts | 30/30 pass; 29 labelled synthetic controls; zero native cases | 2.614 | 299483136 | `9665bf0b14948dd44fafa1fdb43f580b91dbde33b432a63482dffc5e03ee610e` |
| Controller parse | pass; no execution of gameplay | 2.414 | 292618240 | `f66ca65263a48a44c5427a16a497d7d74315863a6d8effd230e19be782d4cbd1` |
| Interactive test parse | pass; no graphical acceptance | 2.517 | 295481344 | `f66ca65263a48a44c5427a16a497d7d74315863a6d8effd230e19be782d4cbd1` |

Every check had a 60-second process limit, 3072 MiB sampled process-tree RSS bound, and 16 MiB log bound; all retained terminal reports have no surviving owned PID and no diagnostic error. Engine version inspection used the same monitor with a 15-second limit. RSS sampling is evidence of observed resource cost, not an allocator guarantee.

Raw logs, complete source-input identities, per-process reports, and the exact harness source are retained locally at `/home/agent/goblin002/evidence/recovered-pure-001/` and durably in Git blob `4cc8a2e6f454e8197e44d7e508ad54875b40dc98` (JSON SHA-256 `f698707eb79d05313154a568b860755bc25d594a1668b156dfb2b29345b0ed92`). The qualification JSON hashes to `7fa0d526f09790f35c9d917563da1307e8398e927afd6723a8501ff6a9c4ae70`; the retained executed-source ZIP hashes to `8fc19893a1ce55b42255b170b38e2bc75eda88bee68f29a79c0b61bda766f9a3`. These controls qualify pure contracts only. The new four-action native edit-prefix reuse and positive native reduction still require hosted execution on the published recovered candidate.

At Specialist C's request, the Windows qualification wrapper was reconstructed from the retained base plus the agreed pipeline: parity, actual regression export, evidence-bearing base package, monitored extracted self-test, graphical verification, and final sealing. The regenerated wrapper is blob `473178cc0241ff7a9c015a24d159471edf0b0e44`, SHA-256 `298e3f0f20e72222d26ad19ada0fa5aa47213e685bd3f5a5d99a4d01c418c1b6`; it is explicitly distinct from the lost target `88dcef94ac07787aa1ca7f2ccd7f3eae3ffba5d6` and was not executed on Linux.

## Recovered discovery-tooling qualification gate

Specialist C delegated reconstruction of the missing `tools/gip014/test_discovery_tooling.py`. The recovered file is an explicitly new candidate, blob `d33c48cdf66b41ca251c3a89c6c63e26128ae979`; no claim of identity with the lost test file is made. Its nine controls compare independently computed Python and actual pure GDScript state projections/signatures, all nine coverage key sets and counters, paint/tool/material exclusions, numeric corpus identity, import demotion and transactional unsupported-action refusal. They also check the twelve matched blocks, all-attempt custody with missing resource measurements left absent, immutable episode identity, and CRLF normalization limited to the four named Rapier descriptors.

The Godot parity project contains only State, Coverage, Corpus, and GameplayOracles plus its synthetic driver. It loads no native extension and never mounts a World or Workbench. The fields shaped like native receipts in this gate are deliberately constructed fixtures, not gameplay observations. Exact engine version fields and the pinned commit are checked; module and runtime hashes are printed into the enclosing qualification log.

The first focused run retained one test-oracle error: the test compared the human-readable `Engine.get_version_info().string` with the differently formatted CLI `--version` output. The corrected assertion checks the authoritative major, minor, patch, status, build, and commit fields. The original failure remains retained (log SHA-256 `0c7e110ae0b4a1e558af9a026d61515c5dac93e07b36860e7d19cfacf26d5577`); it was not a gameplay or implementation defect. The corrected focused run passed 9/9 in 1.509 monitored seconds, peak sampled process-tree RSS 163053568 bytes.

The final complete recovered Python suite passed **63/63 with no skips**, including the actual pure GDS/Python differential. The unittest timer reported 2.722 seconds; the enclosing monitor reported 2.923 seconds, peak sampled tree RSS 168652800 bytes, six observed processes, zero surviving owned PIDs, and no diagnostic error. The limits were 60 seconds, 3072 MiB sampled tree RSS, and 16 MiB retained log. Every `tools/gip014/*.py` input hash remained unchanged during this run; the input-manifest SHA-256 is `771799c39586850920e91a2543c5841635c3814784fcd53f9143d85721849a96`. The complete qualification log hashes to `7b62aee96da7943c47794c7fd052d335fd3224d137e7eb8c553893d85ebe453b`.

The original focused failure, corrected focused result, final full-suite raw logs, source-input hashes, and process reports are durable in Git blob `9d1b66da16d4244e00d35f5404b10662b810092a` (JSON SHA-256 `24bca45350582f50506bab194cbaacd9633adfdcb2be3ead6a118811eae4ef4d`) and locally under `/home/agent/goblin002/evidence/recovered-python-suite-001/`. This is a synthetic tooling qualification, not a native campaign, Windows acceptance, or confirmed production defect.

The lead's final RANDOM-prefix review was resolved without changing policy behavior: the six baseline personalities intentionally do not receive retained prefixes through `bind_memory`, as documented above. The RANDOM early-return branch is therefore not a reachable prefix-loss path under the supported API. A baseline-disabled reuse checkbox is the appropriate UI clarification; enabling prefix replay for baseline policies would be a separate design change.

## Independent audit of qualification2 native laboratory — 25 November 2026

The retained Linux artifact `14987252426` from hosted run `45536048675` was independently inspected without running Godot or changing the evidence. Its ZIP SHA-256 is `1b0a78406835332dc4a350273c5b2ad1543fc77a6404c6490422d0fb630a640f`. This evidence executes clean source `89c91ba5342d485e787d39e64103fc6c91c5f92b`, tree `18facfba0ce5a93afd00200a7f6a971458f40aa8`, exact Godot 4.7 `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`, and the source-matched Linux native/Rapier libraries identified above. The executed source ZIP and seven relevant GDScript files match the claimed Git objects. The portable identity independently recomputes to 953 game-source files and SHA-256 `b78b56007a377789f816ea36e4189b6130441ba6115cda17a07d5c65ebd85583`.

The actual laboratory reports **70 checks, no failures, four native cases and 29 explicitly synthetic controls**. Its ten archived authored starts contain **28 completed admitted gameplay actions and 252 passing per-action assertions**, with no failed or inapplicable action assertion. These are fresh authored sessions inside **one Godot process**, not ten independent OS processes. The process completed in 28.232 seconds, sampled peak tree RSS 648880128 bytes, under 300 seconds / 3072 MiB; no owned process survived.

| Actual evidence | Independent finding |
| --- | --- |
| Bounded Step, run-001 | Exactly two admitted actions, pause then camera, before explicit stop; its archive remains unchanged. |
| Cultivated prefix, run-002 | Ordinary CONTROL seed13 completes pause; camera `{x:0,y:0,width:480,height:270}`; select_material58; rectangle `{x0:32,y0:32,x1:39,y1:39}`. |
| Export, clear, import and reuse, run-003 | The four-record corpus preserves the actually cultivated prefix. OBSESSIVE_REPRODUCER seed0 selects its highest-scored four-action record; every returned ID and argument equals run-002, with retained-prefix queued4 and actually proposed4. Imported evidence remains unverified. |
| Native edit effects in runs002/003 | Independent enumeration finds all64 cells in the inclusive8×8 rectangle change from0 to58. Each native receipt reports requested/checked/applied/changed64. Source-matched capture/edit/capture operations1/2/3, generation3 and revisions3→67 agree with both raw material planes. Their binary plane hashes independently recompute. |
| Positive reduction, runs004–010 | A real four-pause original is followed by two fresh four-action baselines, two-action candidate/confirmation, then one-action candidate/confirmation: probe lengths4,4,2,2,1,1. All six archived probes complete and satisfy the original last-completed-pause semantic acceptance rule. Original/reduced tapes, exact source, authored fixture and pacing match the exported bundle. |

The reduction is **legal semantic outcome reduction from4→1**, with six probes in14.953 seconds; it is not a discovered defect or a full physical checkpoint. The reproduction bundle hashes to `145e5696c4c8d30a09b0b2fc001a35b8d763ab1eb3776fbbb9268867f2232957`. The later local regression exporter consumed that exact bundle and its constant ordinary Python unittest passed against the retained one-action native tape. That later Python step supplies no new native gameplay evidence.

All **138 read-only audit predicates pass**, including independent transcript readback, recomputed coverage, corpus identity, source/runtime custody and before/after evidence-file hashes. The complete audit, reader script and retained initial audit are durable in Git blob `9e622a55790f0153407dc4014d204f58c2a90346`; the final audit JSON SHA-256 is `2a77026d58524e99f2710025da9e4effc17eb4c1bca65529760100c792c4fcfb`. Two initial review predicates were corrected to follow documented serialization contracts: integral floating JSON values normalize before the Godot evidence digest, and a wrapper's reformatted JSON has content equality with the raw tape while the process receipt hashes the raw bytes. Both initial and corrected reader results are retained; neither was a gameplay or harness failure.

This materially strengthens the earlier historical artifact, which demonstrated only one reused pause. Scope remains exact: qualification2's overall Linux job failed its separate synthetic long-tape unit fixture; graphical qualification and the full142-episode campaign did not start. This native laboratory result does not qualify a later source, Windows evaluator, comparative policy improvement or a production defect.
