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

## Independent Windows request3 review and comparative scope

The Windows artifact `14988048860` from run `45538643315`, ZIP SHA-256 `60c0e25fbec428bb767eb2c2a923a0e39566579327d08653d78b8cab1e6f3922`, executes clean source `d849be8ef99cd9226cfc3ca0925752e42b691515`, tree `b6da28e8df80247bbfffb968cbe66e99b386959a`. An independent read-only audit passed **211/211 predicates**, preserving every input byte. The complete audit and reader are retained in Git blob `7207eda6e44fc12ed38d4495f0d34a01321ac980`; its final JSON SHA-256 is `8096d28857931e27e87fc35ddd1ba9621cf2b0682a349330c4b6a47a9f8aaabb`. The concise review is blob `7925f2f668651dfde8c2587dff3cb2d9393cc20e`.

Five source campaigns and one semantic replay completed **448/448 actual admitted actions**, with zero partial actions, refusals or failing action assertions in those executions. Three modern policies each ran64 actions from initial Alchemy, seed1701. Their observed action-vocabulary counts were17 (STATEFUL),28 (NOVELTY) and27 (COVERAGE_HUNTER); observed state-transition counts were63,64,64. These are **one episode per policy**, not an estimate of comparative improvement. STATEFUL stayed in Alchemy. NOVELTY and COVERAGE_HUNTER both selected ordinary replacement with history_edges as their first action and later visited additional fixtures. Their continuing environment exposure therefore differs even though the initial fixture and budget match. The source CONTROL replay matched64/64 semantic fingerprints and0/64 exact observation fingerprints; those exact fingerprints also include timings and receipts, so this difference does not independently isolate physical divergence.

The Windows native laboratory independently repeats the actual four-action corpus edit prefix and source-matched64-cell empty→material58 edit. Its six reduction probes have lengths4,4,2,2,1,1, accepting the same legal last-pause semantic target; four actions reduce to one. All ten archived authored sessions contain28 completed admitted actions and252 passing action assertions inside one OS process. The process took34.203 seconds with sampled peak tree RSS553308160 bytes and no surviving owned process. This is actual Windows source-run evidence; request3's separate extracted-package self-test failed and is not accepted by this audit.

For the full Linux matrix, a frozen23-file d849 Python reader snapshot is retained at `evidence/reader-source-d849` in the mission workspace; manifest SHA-256 `f52a3d57e7fb56a9b8b10cf5f689e27034775caedf07072ee4fb459e0a1d4436`. The independent read-only analyzer is Git blob `d434bb1429f9ecd0527cdfacd56c1b300ea43a0d`, SHA-256 `b6fca378de50e2a764b2f8b10da6fb3959827bff8cb67560ed6f2c330295c24f`. It rechecks the108 matched /8 long /16 personality /10 scenario plan, all raw custody, nine coverage dimensions, direct modern-policy pair intersections, initial and subsequently observed fixtures, terminal-class inventories, and all-attempt resource costs. Missing observations remain unknown. The main matrix uses fresh profiles and no imported corpus, so it can compare within-episode search but cannot establish cross-episode learning.

Source review also establishes a timing qualification: a row's adapter/action duration includes the synchronous admission evidence checkpoint, and the controller repeatedly writes growing tapes. Frame samples are bounded to a recorded prefix. Those metrics must be described as observed action-pipeline/resource costs, not native-engine latency or a causal claim about performance degradation. No throughput optimization was introduced on the strength of this source-only concern.

## Registered cross-episode memory experiment

`tools/gip014/qualify_memory.py` adds a fixed Linux qualification experiment through the existing ordinary campaign entrypoint and typed Controller options. Its API is `qualify(godot, output, *, source_project=None)`; `analyze(output)` and `--analyze` perform data-only evidence review. It does not add a new game adapter, policy, corpus format, replay command or CLI reuse option. A fresh source snapshot and import are shared across seven sequential gameplay processes; every gameplay process uses a new marked disposable profile.

One ordinary CONTROL64 construction campaign at seed13 supplies an unchanged actual corpus. Qualification requires its first four completed admitted actions to be pause, the ordinary480×270 camera view, material58 selection and the8×8 rectangle at32,32. Actual before/after native captures must show64 empty cells becoming material58. The eligible corpus records are ordered exactly as the in-game policy orders them. If the four-action record has rankr, measured seedsr+64 andr+128 both select that same existing prefix through the game's bounded seed-offset rule. This choice is recorded before any measured outcome; no actions or records are injected and no later episode feeds memory back into the experiment.

Each seed then runs COVERAGE_HUNTER64 with fresh memory, imported hints only, and the same imported corpus with explicit prefix reuse. Treatment order reverses for the second seed. The comparison reports the first actually differing fresh-versus-hint action, prior action-prefix equality, abstract-state equality and native paused facts. It does not require hints to improve coverage or even to change a choice. An imported-memory flag alone is not evidence: empty hint dictionaries also set that flag. Fixed input custody and actual corpus counters are checked, and explicit reuse additionally requires queued4/proposed4, exact actual ID/argument equality and the repeated native64-cell edit.

The report separates actual admitted/completed/partial/refused actions, all nine current-episode coverage classes and keys absent from the cultivation episode. It records training cost separately and includes it in total process cost. Two seeds and one corpus support descriptive observations only. Prefix reuse consumes four of64 attempted slots; the main142-episode matrix remains a separate experiment without memory imports. Later world replacement is reported as actual strategy behavior, not treated as fixed continuing fixture exposure.

Bounds are900 seconds for the complete owned worker tree,180 seconds per gameplay process,240 seconds for one import,3072MiB sampled process-tree RSS,16MiB per log and1GiB sampled aggregate output. A bounded15-second engine-version query is inside the outer worker monitor. Every attempted process has a durable registration and retained raw evidence. Interrupted attempts retain any available checked process receipt and cost while remaining incomplete. Missing slots never receive zero coverage. Source/runtime/reader or immutable-input corruption is marked `source_custody_failure`; explicit operator interruption is exposed separately so the parent qualifier can stop. Ordinary failed episodes remain evidence for the separately scheduled full campaign. Exact executed scripts/scenes/configuration are retained in a checked source ZIP before the large staged project is retired.

The new module's **19/19 synthetic Python controls pass** in a monitored0.202 seconds, sampled peak tree RSS15826944 bytes, no surviving owned process. The two new source inputs remained unchanged. The retained log SHA-256 is `9db56afd9332778af896c3434f6f8eb3296883c2bd10abdcf1253fab282de720`; report SHA-256 `2409601a067ad4950fb705cd3eb2daa7bbc24a1d6fbf84db7cea6ae51ac6e4c6`, at `/home/agent/goblin002/evidence/memory-module-pure-001/`. These tests cover matching/foreign prefix contexts, import demotion, actual-proposal accounting, source-matched edit proof, changed-choice limitations, attrition/cost reporting, archive custody, bounded admission and read-only analysis. They launch no Godot and supply zero native gameplay evidence. Actual cross-episode results remain pending hosted execution on the newly published source.

## Retained-clock source-proof challenge and versioned state labels

The separate retained-clock request3 executes observation-instrumented source `070addb0fdae2240f22e663a2299cef739f83c05`, tree `174e9dbf32a5e4014f731008461a310b3a723f37`. Artifact `14995732784` has SHA-256 `2f2dc54b6c8af392364e915776cdae4f384e3dacc8f8209dc97c2a7beef25fd8`. Independent A review qualifies all **20 actual initial/before/after source boundaries** across nine admitted, completed actions. Nineteen queues are empty; the control initial observation directly records one exact ordinary Stop with zero origin/material, disarmed current/published receipts and paused owner/host/native states. Every count, bounded copy and owner generation agrees with its own action observation. The archived adapter and diagnostic match reviewed blobs `7f0fa3fbcab7de85350d0ca99154adc615d75cbf` and `e6faec53a1e005e51dec602cb82c30a9f8868bc1`; the worker/source implementation hashes remain unchanged.

The complete source-obligation audit is blob `d5025f1b7313951500b609313f621012cc2d3d82`, JSON SHA-256 `1a40b4385fed0b926e73f7a2b48ba163fe1ace38778277dba8a2069505326c17`. Control paused at tick17 and variant at16, both satisfying the at-least16 contract without assuming equal asynchronous trajectories. The actual response transaction changes generation3/tick16 to generation4/tick0; Save retains that source and Reopen creates generation5/tick0. B owns the separate material/sole-target adjudication. Earlier request1's zero-action setup failure and request2's unresolved19-of20 boundary result remain unchanged; the newly observed Stop does not identify their unrecorded commands retroactively.

The future lineage-bearing adapter observation version3 uses state schema `cybersand-goblin-state-v2` and the clock label `zero_tick`. Tick zero supplies no authored-material guarantee, and material-lineage metadata adds no coverage dimension. Explicit integral versions1/2, including JSON2.0, and absent historical versions retain the exact state-v1 projection and legacy `authored_start` key solely for replay/readback compatibility. Unsupported future versions, zero/negative versions, booleans, nonintegral/nonfinite values and strings produce one fixed unsupported projection and cannot earn observed coverage. The existing corpus/coverage formats and finite hint bounds remain unchanged; imported historical hints do not become current-episode evidence.

Three focused artificial Python controls pass on the final local delta in a monitored0.202 seconds, sampled peak tree RSS12984320 bytes, two resource samples and no surviving owned process. The log SHA-256 is `e129f306fdc588728c0196979b363fac4855cba8f2a6952a3ecdecfb05c4e605`, retained with exact source hashes under `evidence/state-projection-v3/final-controls`. Five legacy state signatures and the complete nine-dimension synthetic coverage key-set digest `8b5d6cdb06ace1ca7e2b69c4634e0816a68b604f33eff7135890055b0bef08a6` exactly match the independently frozen5ee reader. Additional GDS exploration and cross-language parity controls are prepared for the hosted exact4.7 gate; they have not been run locally. This validation launches no Godot or native game process. Frozen d849/5ee readers, the preregistered comparison rules and request8 analyzer SHA-256 `1ede7cbec24363718bb265bcafb2921f6581f708a25db53465ef1358e42932d4` remain unchanged.

## Actual comparison, memory and current Windows handover

The full hosted matrix at **`5ee5dffc78d59a721f62be49fd51d24b870556c7`**, tree `287795a8534c5622ede5d71710714ea467197e79`, is now independently reviewed. All 142 registered episodes and raw tapes are retained: 139 reach their attempt budgets, with **11,554 attempted / 11,538 admitted-completed actions**, 16 expected refusals and zero partial admitted actions or failed gameplay assertions. The original overall Linux qualification remains failed because three long budgets are incomplete. This result does not relabel the earlier d849 matrix or the later corrected source.

All 108 matched episodes finish their 64-attempt budgets. Each policy has 12 initial-fixture/seed blocks; refusals consume slots. The following are medians of within-block differences, not differences between policy medians:

| Candidate minus baseline | Action IDs | Adjacent pairs | State transitions | Material interactions | Tool/material |
| --- | ---: | ---: | ---: | ---: | ---: |
| Coverage Hunter minus Random | +1 | 0 | 0 | −4 | +1 |
| Coverage Hunter minus Novelty | +3 | +1 | 0 | −3 | −2 |
| Novelty minus Random | −1 | +2 | 0 | +3 | +3 |

Coverage Hunter has fewer material-interaction keys than Novelty in all 12 blocks and never exceeds Random on that dimension. No universal advantage or greater defect yield is established. State keys describe bounded observed gameplay context; their history field contains Undo/Redo availability, not a recent-action sequence. Material keys describe sampled adjacency/edit variants, not verified reactions. Later ordinary fixture replacement is part of each strategy. All matrix profiles start fresh, so this comparison measures within-episode search.

The 16-personality cohort supplies one initial `mixed_stress` episode per policy at seed 605. Actual parameters support different behavior: History Goblin places five rectangles at five locations; Obsessive Reproducer repeats the same rectangle four times before moving the fifth. This is a one-seed signature, not a human recognizability study. Material Alchemist completes no history-family action and skips eight unavailable goal steps; a proposed intention is not proof that every step completed.

The separate **seven-episode memory experiment completes all 448 actions**. One CONTROL64 cultivation supplies an unchanged corpus; two selected seeds compare fresh, hints-only and explicit-prefix Coverage Hunter runs. Both reuse arms propose and complete the exact four retained inputs and independently reproduce 64 Empty-to-material58 cell edits. Both hint-only arms change their first choice at matching initial abstract/native observations. Benefits remain mixed: hints-minus-fresh action-ID differences are −2/+3 and material-key differences 0/−2. One corpus and two selected seeds establish working memory mechanisms, not a population-level search advantage. Cultivation costs 20.315 seconds; all seven game processes total 177.241 seconds, with a 188.633-second supervisor and no surviving owned process.

Five of eight long episodes finish: both policies at 128/256 and Coverage Hunter at 512. Random512 stops at 466 attempts, Random1024 at 570, and Coverage Hunter1024 at 662, retaining their controller timeouts and healthy terminal evidence. No 1024 completion is claimed at this source. Across the 142 game processes, elapsed time totals 6,693.686 seconds and maximum sampled tree RSS is 848,502,784 bytes. The timing supplement retains **zero eligible adjusted strata**: none of 566 exact action/arguments/fixture/pause strata has three observations in both quarters. Unadjusted interval growth does not isolate engine latency, a leak or causal checkpoint overhead.

The complete primary report SHA-256 is `49de3782a724baba68284cf9f934518efe58b5bc2d1ed45ac15cfd160269d28c`; memory report is `07d5477506d0c28e9738c3ce35843e6e43b34c2124ea9ee25c72f56259ba1904`. Full actual reports, six frozen reader closures, executed analyzers, preregistrations and receipts are embedded in the 228-file passive A archive, ZIP SHA-256 `3c54d0a1afbf1af48f93bead0b159bed18c97ded918e06507100db73bf5613f4`, preserved as XZ Git blob `b8ad23fb9ca847650a89f5a1346cb930c25a37c1`. The [owner decision packet](gip014-goblin-002-decision.md) contains all nine policy medians and the source-scoped outcome tables.

The separately qualified Windows evaluator now executes **`6f359ce2b24291ee219810773c641d53802fd31d`**, tree `a4f389cd3cc1a21dfe3d5566703eb946b66734ed`. A's raw-source review verifies 172 synthetic GDS exploration checks and the passing 136-test Python suite, including the 13 discovery-module controls. These contribute no gameplay evidence. Separately, the four actual lineage tapes contain 20 completed actions and 40 adapter-v3 endpoints: 28 project to `zero_tick`, 12 to `early`, all in State-v2. Independently recomputed counts agree across the existing nine dimensions; material-lineage metadata creates no new dimension. Review packet `a4368dca6478402432c08e7c5fe1982df1afa5e1` retains exact source bodies, logs, receipts and the scoped report. B owns the material-contract adjudication and C the evaluator custody review.

At this handover, **Linux request11 long8/memory7 is still pending**. Its separate frozen analyzer is `fe0b8a5c522f3495dfdf7d9f43690c07d73a60d2`, preparation packet `c6cc7d548263b3bd38db2d8ce6beeceeeefe6d13`, bound to the exact 6f source before outcomes. No State-v1/v2 coverage is pooled and no Linux result is inferred from Windows. A later actual-data addendum and a new passive archive version must preserve earlier results unchanged. The byte-bound decision/index review `d288c46a5614f3a589e37bc84714fabe414ad737` confirms these distinctions, the empty adjusted timing comparison and Draft/HOLD status. No new local native execution or optional test expansion was performed for this handover.

### Meaning of the predecessor-policy baseline

The comparison uses **preserved predecessor decision procedures evaluated on the common expanded successor action menu**. Source inspection proves the complete policy files at closing `66ee` and foundation `d448` are byte-identical, as are the separate policy files at comparison `5ee` and corrected `6f`. Across those two versions, the five named legacy goal constructors, their helper/precondition/state-key functions, the four-material scripted palette and waypoints are unchanged. RANDOM retains its uniform sampling of supplied **menu entries**, not action IDs. Curiosity already used action-attempt, preceding-action-pair and from-state-transition counts with weights 8/3/5; its unchanged default branch queues any selected legal candidate. Coverage/corpus/intention bookkeeping was added, but supported baseline selection does not use imported-prefix or prior-memory weighting.

The supplied interface nevertheless changes: 26 to 55 contracts, five to 18 selectable materials, two to six actor-model choices and logical actor IDs up to 64 rather than 8, retaining the eight-live-actor cap. The barrel menu placement also changes, new ordinary actions are offered in paused and running modes, and one matched initial fixture, `history_edges`, is new. The four scripted policies retain their goal recipes but receive successor observations/admission and can use the expanded generic fallback. These are therefore **not unchanged 26-action predecessor executions**; Curiosity's observed median of 35 distinct action IDs is legitimate within the expanded menu. No matched cohort ran with the original 26-action menu or predecessor executable, and predecessor evidence at different sources/budgets is not substituted for one. Exact source bodies, function/menu diffs and this limitation are preserved in review blob `3a3746110cfc3246d310bc24b668ccdd488741dd`, report SHA-256 `95f26eda5d83a9a0efaa3515e02dfc90d3faad50fad5045af04e1c8bc61a8729`. This clarification required no game rerun or gameplay-code change.

## Final 6f Linux long8 and memory7 actual-data addendum

The pending Linux11 analysis above is now complete for exact source **`6f359ce2b24291ee219810773c641d53802fd31d`**, tree `a4f389cd3cc1a21dfe3d5566703eb946b66734ed`. Original run/job `45565621408 / 139039653373` remains failed. Its original artifact is `15003384515`, 50,241,858 bytes, SHA-256 `c5ab54aa45062bf12912e29743058019bc1db38ae59c0a4b234172d6b371fe6e`.

Host unavailability was handled with a separately reviewed, bounded, read-only hosted execution of the **unchanged frozen readers**. Passive run/job `45579669046 / 139086236044` at driver `2a627a3131be72fcb876acec0d0b848a7e42c3e3` passes source/custody review, including an explicit complete memory owner/ledger preflight. It launches no new game or editor. A's long reader takes 6.385 seconds, sampled peak RSS185,708,544 bytes; memory reanalysis takes 1.046 seconds, 70,897,664 bytes. Both leave no owned process. This data-review pass does not promote the original gameplay outcome.

All **eight long tapes validate**, with **2,858 attempted / 2,847 admitted-completed actions**, 11 refusals, zero partial admitted actions and zero recorded failed row assertions. Four of eight episodes finish their attempt budgets. Each starts at construction/seed1701; subsequent ordinary replacement is preserved as strategy behavior.

| Policy | Budget | Attempted | Completed | Refused | Original terminal | Process seconds |
| --- | ---: | ---: | ---: | ---: | --- | ---: |
| RANDOM | 128 | 128 | 128 | 0 | budget_complete | 82.765 |
| COVERAGE_HUNTER | 128 | 128 | 128 | 0 | budget_complete | 57.475 |
| RANDOM | 256 | 256 | 254 | 2 | budget_complete | 258.265 |
| COVERAGE_HUNTER | 256 | 256 | 255 | 1 | budget_complete | 191.335 |
| RANDOM | 512 | 436 | 434 | 2 | campaign_timeout | 622.892 |
| COVERAGE_HUNTER | 512 | 501 | 499 | 2 | campaign_timeout | 622.547 |
| RANDOM | 1024 | 537 | 535 | 2 | campaign_timeout | 909.588 |
| COVERAGE_HUNTER | 1024 | 616 | 614 | 2 | campaign_timeout | 909.762 |

No512 or1024 completion is established at6f. Every incomplete tape retains its original `test_failure / unresolved_observation` classification and no pending action; B owns the separate terminal-contract adjudication. All eight game processes cost3,654.629 seconds, with maximum sampled tree RSS881,831,936 bytes. The deduplicated State-v2 unions are51 action IDs,593 action transitions,1,129 state transitions,43 material interactions,46 tool/material combinations,62 actor/environment combinations,8 lifecycle transitions,1 boundary/refusal key and66 outcomes. No dimension reports saturation. These unions include valid incomplete prefixes and do not count physically distinct world configurations. Each512/1024 tape observes all ten fixture identities.

The separate **memory7 experiment finishes448/448 admitted actions**. One CONTROL64 cultivation yields the same four-action prefix selected at rank1 among54 eligible candidates; seeds65 and129 are fixed before measured outcomes. Both explicit-prefix arms queue/propose/complete exactly four retained inputs and reproduce64 actual Empty-to-material58 cells. Both hints-only arms change the first choice at matching paused initial abstract/native observations. The unchanged cultivation corpus has SHA-256 `a49f4d4dc5957da993a0486ff9d14db2685acd24a059060f5efa8114292f34a4`; measured outputs are not reused later. Hints-minus-fresh action differences are−2/+3 and material differences0/−2. Explicit-prefix-minus-fresh action differences are−2/+1 and material differences−1/0. This is working persistent memory with mixed coverage outcomes, not a demonstrated universal search advantage or physical checkpoint resume.

Cultivation costs21.496 seconds and is included in188.301 seconds of game-process cost. The memory supervisor takes199.883 seconds, sampled peak RSS780,529,664 bytes, no surviving owned process; its separate import takes6.637 seconds. Long timings retain requested final windows: Hunter512 observes53/64 final rows, while Random512 and both1024 trials have no observed requested final64 window. The largest recorded whole-process frame interval is20.313099 seconds; aggregate p95 values are7.026–9.470 milliseconds. These include startup, fixture work, native waits and evidence checkpoints and do not isolate engine latency, FPS, a leak or causal overhead.

Full actual reports are preserved: long1,040,902 bytes/SHA-256 `c32ab2dcbd84f969a8dff36c9e0b31122a0e7664e70516d7fc0334d9046306dd`; memory123,204 bytes/SHA-256 `6d60a463843c99ba3eb1cb30596ed7d0085f5314de77f1fb4e4df9dfdc565ccb`. Complete stage artifact `15005776720` is942,877,571 bytes, SHA-256 `8621cf2811e14fdda3e98749f84b7d0887228f0c64b91967ae67485627552da9`. Full passive job log is blob `7e99bc3d49a24ee31c9c87872063d664de2d5b33`; A's actual readout packet is `2cc2e185e1654bb2701224e5fdb459457c653eab`, readable report `5da3763f205b1c6a61fb85007f7d488b95464c74`. The packet retains the exact logged report projections, file identities, frozen wrapper/source review and25 consistency checks; complete original reports remain in the stage artifact. Metrics and acceptance rules were not changed.

This supplement has one observation per long policy/budget and two selected memory seeds from one corpus. It does not replace or pool the5ee full142 matched comparison. Adapter-v3/State-v2, material-lineage metadata, standalone execution order and observed paths differ; no cross-source causal improvement is claimed. No confirmed production gameplay defect or physical NVIDIA acceptance is added. The exact6f Windows evaluator remains separately qualified; Draft/HOLD and no default activation, merge or Ready promotion remain in force.


## Final delivery and late recovery addendum

The main evidence archive sealed successfully at driver f3324f462091d1778b9472ebcafbab35372e6411,
embedding the exact e8df89b48757096428ee6a9d12e55c7e417c10d5 RESULTS snapshot.
Its 666,742,658-byte inner ZIP is available through GitHub artifact 15008615196;
a second direct copy was blocked before local download by the connector size
limit and available workspace space. The qualified Windows evaluator remains
saved and unchanged at game source 6f359ce2b24291ee219810773c641d53802fd31d.

After sealing, all six selected predecessor native tape bodies were recovered
at their original byte/hash identities. A's new 960,187-byte supplement has
SHA-256 c34a9f0e1d520c6a45f6bff7073cd2c54e11ea28425ef755ce8f2b2ce6840f74
and was saved successfully. Eleven compact paths were checked in total: six
selected bodies and five identical aliases. The pretty serializations were not
reverified. Five historical completions, two unattributed -9 interruptions,
988 observed completed actions and Random a01's missing tape/count remain
unchanged. The old assembled 75b4 ZIP was not located in the two scoped roots;
this new supplement is not a reconstruction claim.

A recovery record ba46c0d4fcde350923ee796aa9bd691e1b58e75c, B's thirteen-check
review a7273bfcdd601940e273ee094317052d594afd58 and C's actual delivery record
86e1dc88d8863e5d69fa2d73bf1addf7a9e5f31e retain the distinct verification scopes.
The [final delivery record](../../tools/gip014/evidence/passive/final-delivery.json)
and [owner decision packet](gip014-goblin-002-decision.md) record the actual final
status. The sealed archive and historical incomplete outcomes are unchanged.
This final passive work adds no gameplay, analysis cohort, native qualification
or production defect. Draft/HOLD remains in force.
