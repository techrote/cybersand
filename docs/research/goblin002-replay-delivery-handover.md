---
title: GIP-014-goblin-002 replay and delivery specialist handover
status: Planned
document-kind: research
scope: Branch-scoped transcript custody, bounded experiments, replay, reduction and Windows evaluator; Draft/HOLD
canonical-for: [goblin002-replay-delivery-handover]
last-reviewed: 2026-11-25
related-documents: [gip014-goblin-002.md, goblin002-exploration-handover.md, goblin002-gameplay-handover.md]
---

# Replay and delivery handover — Draft/HOLD

## Qualification status and recovery

This document describes candidate source and its explicit acceptance gates. It
does not claim that a newly edited candidate has passed native or Windows
qualification before its retained hosted evidence exists.

The first successor source at `be64fa78` ran in Actions
[45527805069](https://github.com/techrote/cybersand/actions/runs/45527805069).
Both platforms exposed the same pure fixture-contract failure: the alchemy
fixture exceeded its existing rectangle count bound. The gameplay specialist
reduced that authored fixture to eighteen rectangles. Linux discovery, adapter,
expanded gameplay, controller, laboratory, gameplay, metamorphic and baseline
groups passed at that older exact source; the failed unit gate correctly
prevented graphical and comparative campaigns. Windows artifact
14983177716 and Linux artifact14983617239 preserve those results. They do not
qualify subsequent fixes.

A local checkpoint `eaf193eaca9330a4e49ed9a5430047e0c5f82f57`, tree
`a33744521d8b4b14183f4757b58163cf5f52a59c`, was lost when the execution host
disappeared before its final upload. Fourteen replay/delivery files were
recovered byte-for-byte from retained state and immediately secured as immutable
Git blobs. Remaining launcher/package/sealing files and controls were rebuilt
from their committed design and independently reviewed. Those replacements are
a new candidate, not a claim to have recovered the lost tree exactly. Concrete
review fixes and all final source/runtime/package identities belong in the
lead's decision packet. Reconstructed source must run the hosted gates again.

The final reconstructed Python suite passed **63/63 artificial controls with
no skips**, including exact Godot4.7 pure cross-language parity. Unittest time
was2.722 seconds; monitored wall time2.923 seconds; observed peak process-tree
RSS168,652,800 bytes. Six owned processes were observed and none survived cleanup.
The outer bounds were60 seconds,3,072 MiB and16 MiB of log output. Python source
hashes stayed unchanged during execution. Log SHA256:
`7b62aee96da7943c47794c7fd052d335fd3224d137e7eb8c553893d85ebe453b`;
input manifest SHA256:
`771799c39586850920e91a2543c5841635c3814784fcd53f9143d85721849a96`.
These are test-harness controls, not gameplay episodes, material coverage or
production defect findings. Native and extracted Windows gates remain separate.

## Owned interfaces and observed evidence

The replay lane owns `goblin_transcript.gd`, the independent Python reader,
`tools/gip014` campaign, replay, packaging and qualification tools, and the
focused successor workflow. The exploration lane owns state abstraction and
in-game coverage; the gameplay lane owns real adapters and authoritative
observations. The lead owns controller/UI integration and the regression bundle.

The supported transcript remains `cybersand-goblin-transcript-v1` with additive
bounded fields. It admits the expanded 55-action vocabulary, sixteen policy IDs
and ten installed authored scenarios. A tape is limited to 1,024 actions and
32 MiB. The in-memory writer maintains a private incremental byte estimate to
avoid serializing the entire tape on every append; serialized readers enforce
the actual byte and semantic limits independently.

A tape keeps exact initial fixture/source identity, seed, policy, proposed
intention, admitted action, actual acknowledgement, before/after observation,
native material receipts/readback, interval boundaries, assertions, refusals and
terminal state. Partial and refused operations remain observations. A retained
pending action is evidence of incompletion, never counted as a completion.
Source-matched immutable native observations are necessary for state and
interaction coverage; merely knowing an action ID is not coverage.

Python recomputes completion/admission/refusal accounting and the nine coverage
dimensions from raw rows. Its state projection follows the same documented
observations as the pure Godot abstraction, including actual actor controls and
capabilities, current material probe, nested configuration and camera mode,
preview state and native source presence. Synthetic cross-language tests compare
actual key sets and projected states, not just equally sized counts.

Tool/material coverage is deliberately conservative. It requires a completed
native paint operation, valid source-matched capture, stable before/after palette
material and the actual selected tool corresponding to brush, rectangle,
outline, line, stroke or fill. Undo, Redo, Paste, Eraser, interrupted edits and
non-atomic live edits do not receive invented palette/tool credit. Material
coverage records sampled adjacency and edit transformations; it is not a count
of chemical reactions or a whole-world coverage percentage.

## Replay identity and corpus custody

Legacy replay retains strict complete provenance equality. Versioned portable
identity is allowed only when both tapes supply a valid identical
`cybersand-goblin-replay-identity-v1`. It pins source commit/tree, platform,
Godot/native/Rapier executable digests, canonical game-source digest and source
dirty status. Full host provenance remains attached; incidental host/Python
metadata alone may differ.

Canonical game inputs exclude generated import cache and platform-irrelevant
runtime binaries. The only text normalization is CRLF to LF for the four
existing explicitly named Rapier import descriptors. Arbitrary descriptor edits
are rejected; all other shipped game inputs remain byte exact. Fixture ID,
version, authored fixture digest, initial scene identity, seed and pacing remain
independent replay/reduction preconditions.

Portable example tapes are copied byte-for-byte from actual complete, valid,
source-matched campaigns; they are never rewritten to manufacture package
identity. Up to eight cases and their supported bounded corpora are shipped
under fixed `replay-corpus/case-NNN.json` paths. They are explicit imports,
not automatically seeded owner memory. Semantic replay and exact asynchronous
observation comparison remain separate results.

The corpus reader bounds imported JSON to2 MiB,64 records and128 prefix actions,
checks finite action schemas, canonical record identities, search hints and
bounded metadata. The game demotes imported records to unverified hints.
Reusing a prefix replays actual ordinary actions into a fresh disposable world;
it does not restore an asynchronous physical checkpoint.

## Finite experiment queue and comparative design

`campaign_queue.py` persists an immutable plan and exact staged project.
Every attempt gets a new isolated application profile and immutable receipt.
Resuming a queue skips completed experiments and starts unfinished episodes
fresh. It never pretends to resume the physical state of a stopped worker.
Up to three attempts per episode are retained. A crash between receipt creation
and queue checkpoint is reconciled from the receipt without deleting the
interrupted history.

The full committed plan contains142 episodes and12,416 planned actions:

| Cohort | Design | Episodes | Budget |
|---|---|---:|---:|
| Matched | Six original policies plus STATEFUL, NOVELTY and COVERAGE_HUNTER; four scenarios; three seeds |108|64 each|
| Longer horizon | RANDOM and COVERAGE_HUNTER on construction, seed1701 |8|128,256,512,1024|
| Personality | All sixteen personalities |16|64 each|
| Scenario | All ten installed authored scenarios |10|64 each|

The matched comparison has twelve blocks, each defined by scenario, seed and
budget. `paired_comparison.py` reports block completeness, observed
distributions, descriptive paired deltas and actual admitted denominators.
Missing measurements stay unknown rather than becoming zeros. Latest-attempt
results, first-attempt completion and all-attempt cost are distinct estimands.
With only three seeds, the comparison does not claim significance or a general
causal policy ranking. The initial plan is immutable; changing its content
requires a new queue.

Each owned test process has explicit wall, memory and output bounds. RSS is
sampled every100 ms across only the launched process and observed children,
identified by PID and creation time. The default RSS limit is3,072 MiB.
Per-episode wall limits range from210 to960 seconds; queue time and disk
limits are separately configured. A fixed cancellation file stops only that
owned test tree. Cleanup records surviving owned PIDs and never scans or kills
unrelated processes.

Logs remain on disk even for fast-exit output overflow. A final size check
retains an `output_limit` result; streaming SHA256 covers the complete raw log
while diagnostic consumption is limited to16 MiB. Runner, queue and extracted
qualifier use the same bounded prefix reader. Incomplete/resource/cancelled
processes cannot become passing replay or reduction evidence even if they wrote
a final-looking tape.

## Predecessor incomplete results preserved

`predecessor-recovery.json` was regenerated from seven original retained
`long-final-*` directories, read-only, at predecessor Linux source
`1649f086a5795d88d03d19fd161ad549365a3fc4`. It includes exact qualification,
profile and raw tape digests/sizes, process status and timing, source identity,
campaign identity and retained summaries. Compact game tapes and the runner's
pretty-printed copy have different byte hashes; their semantic equality was
checked and their custody remains explicit.

Five processes completed. Curiosity/construction256 attempt1 exited with
signal9 after95.695 seconds, retaining220 completed actions and an accepted
pending brush. Its separate attempt2 completed256 actions in139.336 seconds.
Random/construction256 attempt1 exited with signal9 after22.021 seconds and
left no tape. Across the six surviving tapes988 completed actions are
observable. The records do not establish who sent SIGKILL or a production
engine fault. Neither incomplete process was relabeled as a pass.

The predecessor's qualified Windows run
[45474099351](https://github.com/techrote/cybersand/actions/runs/45474099351)
and evaluator artifact14958249728 remain original evidence. No predecessor
negative control, harness defect or successful check is described as a novel
production gameplay defect.

## Reduction and regression

The standalone minimizer accepts an injected fixed game replay callback; it
contains no command generation. The runner supplies only the committed
`res://goblin/run_campaign.gd` entrypoint with validated action fixtures.
Each probe starts from its authored fixture in a fresh disposable profile and
preserves original pacing.

A failed-invariant target includes the exact assertion, action/arguments,
expected value, row status, classification and admission. A refusal cannot
replace a completed operation and still confirm the same defect. Both original
and reproductions require the documented clean terminal outcome. Resource
limits, cancellation, crashes, output overflow and truncated legal-outcome
sequences fail acceptance.

Reduction first confirms the original with bounded repeats, then removes
chunks and unnecessary individual actions and tries finite non-target parameter
simplifications such as radius0 or ticks1. Every attempted probe remains
visible. Wall/probe/repeat bounds are independent. Acceptance requires exact
source/runtime/fixture preconditions and the same target under the documented
rule; necessary setup or timing cannot disappear without losing acceptance.

Healthy semantic-outcome reduction is explicit and labeled legal gameplay.
The native laboratory qualification cultivates a real four-action CONTROL
prefix including a captured rectangle edit, exports/imports its actual corpus
and checks actual reused IDs/arguments/material change. A separate four-Pause
positive reduction confirms fresh reproductions and reduces4 to1; that legal
case proves mechanism, not defect discovery.

`qualify_reproduction.py` finds the laboratory's actual
`profile-00-goblin_laboratory` reproduction bundle, uses the lead's fixed
`regression_bundle.export_case` API, copies its actual reduced tape, checks
reproduction and runs the generated constant standard-library unittest.
The compact bundle contains original/reduced tape, authored fixture,
material readback, finite action fixture, exact contract/source and instructions.
Regression-versus-reproduction meaning stays explicit. No arbitrary generated
shell or untrusted executable command is exported.

## Windows evaluator and persistent owner experience

The Windows qualifier pins the exact existing Godot4.7 distribution, licenses
and retained native/Rapier artifacts with source-input verification. It does
not rebuild another programme's engine or import candidate branches.
Source tests, actual campaigns and stable semantic replay must pass before
packaging.

The evaluator contains the ordinary Workbench, actual laboratory, scenario and
personality catalogue, developer guide, tools and raw portable replay examples.
`Open goblin.cmd` needs no separate engine, Python or compiler installation.
Owner interactive windows remain ordinary application windows; every goblin
campaign has its own action/active/absolute bounds.

On clean interactive exit, the launcher validates the actual fixed game corpus
through the in-process finite validator and atomically publishes it to
`test-output/goblin-memory.json`, retaining exactly one predecessor backup.
The next launch stages those bounded bytes into a fresh isolated profile.
An explicit `-Corpus` option chooses a supported imported data file;
`-ClearCorpus` removes only four fixed memory publication names and preserves
archived native tapes. These are launcher options, not arbitrary paths exposed
to game actions.

Extracted qualification is wrapped by the owned Python process monitor in CI
with1,200-second wall,3,072-MiB RSS and16-MiB output bounds. The packaged owner
launcher itself has no Python dependency. Actual extracted cases cover CONTROL
actor-workshop and save/reopen, plus COVERAGE_HUNTER alchemy requiring useful
completed expanded features. Actual portable replay, ordinary graphical
Workbench screenshots and the real persistent-memory roundtrip are additional
required gates.

The memory gate saves two distinct nonempty actual campaign corpora, verifies
exactly one predecessor backup, validates import into a fresh profile and checks
clear preserved archived tape hashes. The final evaluator begins with empty
mutable default memory; qualification memory remains only in immutable explicit
evidence paths.

`seal_evaluator.py` adds the actual extracted report, referenced immutable
observations and an owner index beside unchanged manifest-tracked payload.
It retains base and final ZIP digests separately, bounds archive members and
evidence, rejects path aliases/traversal and mutable default memory, re-extracts
the final ZIP and repeats independent package verification. It performs no
release publication. Final hosted evidence and package identity must be read
from the resulting delivery receipt, not inferred from this source description.

## Qualification2 observations and unit fixture repair

Actions [45536048675](https://github.com/techrote/cybersand/actions/runs/45536048675)
ran exact source `89c91ba5342d485e787d39e64103fc6c91c5f92b`, tree
`18facfba0ce5a93afd00200a7f6a971458f40aa8`. Windows artifact14987073203
retains the failed unit gate (archive SHA256
`08fb0ddfe01fddb20cbb702b8756d7dc8f184de270839f2881a1ec453d442061`).
The Python63-control gate passed on Windows, and the policy and gameplay-contract
GDScript tests passed. The tape-contract test failed exactly one check: its new
1,024-row synthetic fixture had omitted every row's independent assertions.
The strict production validator correctly rejected those rows.

An exact Godot4.7 local pure reproduction retained the same193-check result and
a diagnostic listing1,024 missing-assertion errors. The repair changes only the
synthetic tape test to retain `Assertions.evaluate(row)` on every append, and
adds a control proving missing assertions are still rejected. The production
validator is unchanged. All three isolated pure unit scripts then passed:
333 policy checks,194 tape-contract checks and82 gameplay-oracle controls.
Their elapsed times were9.454,6.436 and0.303 seconds; highest observed
process-tree RSS was284,528,640 bytes under a3,072-MiB/60-second per-process
bound. No editor import or native World was run. This is a confirmed harness
test-fixture defect, not a discovered production gameplay defect.

Before/diagnostic/after raw logs, process outcomes and source manifests are
durable in Git blob
`5f3decdb90b36d9c2e1595faec4fcb54a5e48f80`, a data-only gzip/base64 envelope
with per-file raw hashes and sizes. The repair report SHA256 is
`1dd67cda142f575708a3158cd99b4306361392adf59ba9567eebcf9eb61eb84d`;
the repaired unit script blob is
`58fa38ad53bc6eb4d154e93a952feca0df1eecd8`.

Linux artifact14987252426 preserves the same source's source groups. Discovery,
adapter, expanded gameplay, controller, laboratory, gameplay, metamorphic and
baseline groups all passed; discovery remains a pure control group. Unit
qualification failed only at the same long-tape fixture. Graphical,
comparative campaigns and final packaging were therefore still unqualified
for this run; no pass is inferred from the source-group results.

The actual native laboratory report contains70 checks with no failures and
29 separately labeled synthetic controls. Its cultivated construction prefix
and imported reuse each admit four exact ordinary actions; both rectangle
readbacks show64 changed native cells. Its legal four-Pause reproduction was
confirmed and reduced4 to1 through six fresh-World probes of lengths
4,4,2,2,1,1 in14.953 seconds. These observations establish actual prefix reuse
and bounded semantic reduction, not a novel defect.

A subsequent **data-only export** used this retained native reproduction bundle
without rerunning or relabeling its gameplay. The fixed
`qualify_reproduction.py` exported the original/reduced tapes and authored
fixture, copied the actual one-action observed tape, passed the reproduction
checker and ran the constant ordinary unittest successfully. The exported
qualification report explicitly records `legal_unusual_gameplay` and
`gameplay_defect_confirmed: false`, source89c91ba5, original4/reduced1.
Its raw bundle SHA256 is
`145e5696c4c8d30a09b0b2fc001a35b8d763ab1eb3776fbbb9268867f2232957`;
export qualification SHA256 is
`ab54fd88152ce7630b0bbc9949eaea52421c1111615c4ff7183d1047bd5a7a78`.
The generated unittest process exited0 in0.208 seconds with no owned survivors.
Final extracted Windows delivery still requires a passing later exact-source
qualification.

## Windows qualifications 3 and 4: separate harness findings

Request 3, Actions
[45538643315](https://github.com/techrote/cybersand/actions/runs/45538643315),
ran source `d849be8ef99cd9226cfc3ca0925752e42b691515`, tree
`b6da28e8df80247bbfffb968cbe66e99b386959a`. Its Windows source groups and
six campaign/replay executions passed. Those six executions contain 448 completed
actions; one is an explicit replay, not an independent exploratory episode.
The extracted evaluator failed before any Godot child started because Windows
PowerShell could not resolve `Get-FileHash`. Artifact 14988048860 retains that
failure (archive SHA256
`60c0e25fbec428bb767eb2c2a923a0e39566579327d08653d78b8cab1e6f3922`).

The narrow qualifier repair removes only the case-insensitive `PSMODULEPATH`
entry from the Windows PowerShell child's copied environment. Other environment
entries, the game and both launchers are unchanged. Microsoft documents this
[PowerShell 7 through Python inheritance boundary](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_psmodulepath#starting-windows-powershell-from-powershell-7).
Four added synthetic controls cover preservation, mixed-case names, the fixed
bounded probe, process failure and module/digest/marker rejection. The complete
local Python/pure suite passed 67/67 with exact Godot4.7 parity in 3.422 monitored
seconds, peak 168,722,432 bytes, six observed owned processes and no survivors.
Its 60-second/3,072-MiB bound and raw before/control evidence are retained in
blob `08a232bd8272e9d5e820c2ade97040e8d406724d`.

Request 4, Actions
[45541023949](https://github.com/techrote/cybersand/actions/runs/45541023949),
ran source `a6abb07aa8374dc2a870c2a6c9d0aca4f1981402`, tree
`1dac01a01e4f8947a2e7d80f3ace34b9de6dd5ea`. The actual inherited child failed
with `CommandNotFoundException`; the clean child passed in 0.735 seconds using
Windows PowerShell 5.1.20348.5773 and `Microsoft.PowerShell.Utility`. It hashed
the exact fixed probe bytes. Each probe had a 30-second/512-MiB process bound.
The unchanged launcher then imported the actual game and completed both
CONTROL 64 extracted cases, actor_workshop and save_reopen.

The next extracted case, COVERAGE_HUNTER/alchemy/seed 13, stopped after 61 completed
actions at `actor_place_position`. The authored Monowheel spawn was `[256,96]`,
its weighted cab was `[256,97.5]`, and its rim was `[256,96]`, at physical tick 0 with
neutral motion. Independent inspection of the existing physical catalogue and
constructor confirms that the cab's authored offset is `[0,1.5]`. The inherited
oracle incorrectly required the first physical part to equal the assembly
origin. This is a **test-oracle defect**, separate from the repaired PowerShell
boundary and from a production gameplay defect. Placement, reset and related
origin checks require a narrowly justified correction and fresh qualification.

The game automatically retained `candidate-001.json` before exit: 830,575 bytes,
SHA256 `37e6811604896d24f8f0c4b2341c08c977f0302bc3815916a26ea88d0e13f41a`.
Its historical classification remains `unresolved_observation`, with no
independent reproductions and no confirmed production defect. A data-only
regression export of that retained 61-row tape passes reproduction acceptance and
correctly refuses regression acceptance. It executes no new gameplay. Changing
the wrong expected value is not an unchanged-invariant production regression
pass. The raw candidate, transcript, Findings, corpus, profile, package failure
and actual module-probe evidence are durable in blob
`50516f7e83a8e24f8da5f0b2333016e4e3ee4ee0`, a data-only gzip/base64 envelope
with exact per-file hashes. Windows artifact 14989104342 has archive SHA256
`807742a6941a411b498bb28181cb0d64cb89085723254708847d652152893de1`.
Portable replay, extracted memory roundtrip, graphical execution and final
sealing were not reached in this attempt; the evaluator remains unqualified.

An adjacent read-only hypothesis concerns **Use body position** followed by
Reset on Monowheel. Source copies the first body's location into authored X/Y;
reconstruction adds the cab offset again. The existing
[Workbench contract](../systems/player-control-playground.md#development-workbench-on-desktop)
promises that capturing a reset spawn does not immediately move the live body,
while the newer [composition contract](../systems/workbench-actor-composition.md)
reconstructs authored spawns and the
[rig contract](../systems/physical-actor-rigs.md) assigns parts their own offsets.
The reviewed text does not explicitly settle positional idempotence for capture
of a multi-part actor versus literal selection of a new assembly-origin
coordinate. A native drift observation alone must therefore remain an unresolved
contract observation until that intended relationship is established. No
production change or issue is justified by this hypothesis alone.

The request3 base ZIP also passed an independent check of all 1,224 tracked
payload hashes, exact member closure and absence of mutable default memory.
Its eight portable raw tapes represent four distinct parsed transcripts,
including an explicit source replay; they must not inflate independent episode
or personality counts. That data-custody review is retained in blob
`56ed2e07df3dbd931c7593c2a62d835dd2aca937`. It does not establish extracted
Windows execution. After the oracle repair, a fresh full matched matrix is
needed: merely relabeling an old oracle failure cannot recover actions that
the historical controller never executed.

## Origin, memory and cancellation review before request 5

The independent Python origin reader now compares the exact finite float32
encodings used by the pinned engine. This preserves the distinction between
assembly origin and first physical part while accepting Godot's rounded JSON
spelling. The actual captured spawn `[95.8000030517578,224.130004882813]`
exercised this serialization boundary. Twenty-two independent read-only controls
passed against the retained Monowheel observation and explicitly synthetic
neighboring float32, part-position and malformed-input mutations. Both adjacent
representable positions are rejected; no general position epsilon is used.
The historical wrong assertion remains intact. This review is durable in blob
`2eaecfefd87d5bfb0113d477d24fc10ddc2b2595` and does not replace fresh native
qualification of the corrected oracle.

The seven-episode memory experiment received a separate source review of fresh
profile and source/runtime identity, whole-corpus input custody, actual admitted
prefix and material-plane proof, fixed treatment order, retained incomplete
process cost, missing-arm accounting and archived source membership. The final
module distinguishes source/custody failure from ordinary retained episode
failure and exposes explicit operator cancellation. Cultivation remains a
separate cost; imported hints earn no current-episode coverage. Its source
review passed, while its actual gameplay execution remains a request-5 gate.

Cancellation review established a narrow orchestration defect: an interrupted
test, reducer probe or extracted PowerShell preflight could otherwise be
followed by another fixed child process. The runner now checks the explicit
owned-process interruption before parsing a possibly incomplete tape, retains
current and earlier raw evidence, archives the source and returns exit 130.
Reduction interruption escapes the ordinary failed-probe retry path. The
extracted qualifier likewise retains the interrupted probe or self-test receipt
and stops before another child. Ordinary test failures retain their existing
continuation and exit-2 behavior. No game, launcher or fixed PowerShell probe
bytes changed for this repair.

The integrated pure/synthetic Python gate passed **99/99 with no skips**,
including exact Godot 4.7 state/coverage/corpus parity. It took 3.230 seconds of
unittest time and 3.542 seconds under the process monitor, with a sampled peak
tree RSS of 168,804,352 bytes, six observed owned processes and no survivors.
The outer limits were 60 seconds, 3,072 MiB and a 16-MiB diagnostic log. All Python
source hashes were unchanged during the run. These are harness controls, not
native gameplay episodes. Raw logs, process receipts, input hashes and the
independent review are retained in blob
`efd2e5ba6081b4d346c6559aa66fc10a98e0a299`; the evidence-envelope SHA256 is
`ee322c437916b4012d45b31878c4ec80094552a6b57eb4e05840ab2b498829a1`.

## Remaining decision authority

The lead owns final source freeze, independent review disposition, hosted run
monitoring, exact artifact identities and the owner-ready decision packet.
All results remain Draft/HOLD. No default activation, merge, Ready promotion
or physical NVIDIA acceptance is authorized by these tools. No novel production
gameplay defect has been established by this handover.

## Qualified owner delivery at source 6f359ce2b242

The current self-contained Windows evaluator is qualified at source
`6f359ce2b24291ee219810773c641d53802fd31d`, tree
`a4f389cd3cc1a21dfe3d5566703eb946b66734ed`, by
[request 11 run 45565621408](https://github.com/techrote/cybersand/actions/runs/45565621408),
Windows job 139039653335. Later documentation commits do not change that runtime
qualification identity. Earlier failed and unresolved attempts remain original
evidence; this result supersedes their provisional delivery status only.

| Identity | Exact value |
| --- | --- |
| Final owner ZIP | 95,816,253 bytes; SHA256 `daca112474286798950977909b1be000cd5b75657b231c028d366515836cdc4e` |
| Base ZIP before evidence sealing | 94,642,679 bytes; SHA256 `8e4a27ccbb389f4d06f73402aaba9f340333a2e08e88f4cbf639343c67ade950` |
| Qualified artifact wrapper | Artifact 15001055330; SHA256 `edfa20c4d6aca64d32396139642db7bee3f70ff7d54e536ac616a4043b7ca7d6` |
| Complete raw Windows artifact | Artifact 15000825524; 201,496,963 bytes; SHA256 `75c3e351e1c9459516c6708508adfdd2b669dc916d40af459c040fdacee67314` |
| Pinned Godot | `4.7.stable.official.5b4e0cb0f`; executable SHA256 `b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8` |
| Native extension | SHA256 `668f2dd094fca611a97c2b6aa38c4cd072179fe9cf591e53578ef57c7db1625e` |
| Rapier extension | SHA256 `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7` |

The ordinary Workbench, native libraries and Godot are included. The owner can
extract the package and launch **Open goblin.cmd** without installing an engine
or compiler. The existing owner download was replaced with these exact bytes;
the earlier qualified `5ee` version remains a distinct historical version.

The actual source qualification passed **136 Python controls**. Its expanded
native gate passed **2,030 checks over 86 attempts: 83 completed actions and three
refusals**, with no failed assertions. All 55 supported action IDs have completed
native evidence across the exact `6f` source campaigns and focused gates; this is
observed vocabulary coverage, not a claim that every policy exercised each ID.
The authored-lineage source gate and the extracted-package gate each completed
four cases and 20 actions. Both fresh/Restore cases established positive native
material equality; both simulation-exposed retained/reset cases correctly made
that equality inapplicable while independently preserving the observed material
divergence. The original `070` automatic candidate remains unchanged forensic
history, with its later test-oracle adjudication kept separate.

Independent C acceptance passed **3,995 checks** covering 1,243 tracked payload
files, 24 sealed supplementary files, exact source/runtime identity, 38 retained
process receipts and matching raw logs. Every audited launched-process receipt
reported no surviving owned child. B separately passed 1,094 source checks,
273 extracted lineage checks and 731 current action/origin checks. A independently
verified the actual version 3 State projection and all nine recomputed coverage
counts. Root individually inspected all three 1600-by900 Play, Discovery and
Memory views. The C full reader/results packet is immutable blob
`6dadaa33179ce4bb665daf7be7a5a1988f0ce0cf`; B's full current review packet is
`621448b4456b77c0acab8a7eeb88b627a9561f12`; A's actual State review is
`a4368dca6478402432c08e7c5fe1982df1afa5e1`. Their actual source bytes and full
outputs are also being collected in the passive evidence archive.

The portable catalogue contains **eight raw JSON serializations representing
four parsed tapes**. Three originals contain 64 CONTROL actor-workshop actions,
128 BUILDER liquid-channel actions and the seven-action
`actor_reset_retains_evolved` case. All 199 original actions completed. The fourth
tape is a 64-action semantic replay, giving **263 attempted and263 completed
rows across distinct parsed tapes including replay**. These are not 263 episodes;
serialization copies do not increase the experiment count. Exact asynchronous
physics replay is not claimed.

The extracted persistent-memory gate retained 47 then 64 records, validated
imports into fresh isolated profiles, exercised the one-backup rule and cleared
mutable memory while preserving two archived tapes. Qualification memory is not
installed as the owner's default. The fixed authored-lineage child has a
300-second bound; the extracted qualification's owned process-tree wrapper has
1,200-second and3,072-MiB bounds with a 16-MiB log bound. These are measured,
sampled owned-process limits, not global monitoring or physical NVIDIA evidence.
Interactive campaigns retain the 1,024-action/32-MiB tape ceiling, at most
900 seconds active time and a separately bounded absolute deadline. Interactive
reduction admits 1..128 actions and reserves at most 12 fresh trials, each with
30-second active and 60-second absolute limits. Its 240-second check bounds new
reduction dispatch, not the completion time of an already dispatched probe.
The observed legal 4-to-1 reduction and historical unchanged-oracle 44-to-1
reproduction remain different scientific results. No production defect is
established by either.

The passive preservation plan currently contains ten original artifact ZIPs,
including the complete newly qualified Windows raw artifact, plus full A/B/C
reader-and-result bundles and six original predecessor tapes. It retains the
request 9 parser failure, request 10 full-provenance comparison failure, unresolved
diagnostic prerequisites, historical oracle-stopped campaigns and the transport
failure before the first C request 11 audit dispatch. Root's single recovery run
of the unchanged C reader passed; the initial failure was not rewritten.
The separate exact `5ee` full 142 experiment remains 139 budget-complete episodes
with three bounded long-horizon timeouts. Its results are not pooled into the
new material-lineage source. The actual request 11 Linux long8, focused and memory
artifact and final passive archive sealing remain pending at this handover.
All delivery remains **Draft/HOLD**, with no default activation, merge, Ready
promotion, physical NVIDIA acceptance or confirmed novel production defect.

## Final Linux11 custody and passive preservation addendum

The exact runtime candidate remains `6f359ce2b24291ee219810773c641d53802fd31d` (tree `a4f389cd3cc1a21dfe3d5566703eb946b66734ed`). Linux job `139039653373` in run `45565621408` finished with the original failed conclusion because four of its eight long episodes reached their bounded Controller deadlines. Artifact `15003384515` contains 50,241,858 original bytes, SHA256 `c5ab54aa45062bf12912e29743058019bc1db38ae59c0a4b234172d6b371fe6e`, with 432 members and 267,817,164 expanded bytes. This result is separate from the earlier 142-episode experiment at 5ee.

The frozen C custody reader (SHA256 `80c3d813938a38b9028db0ed7c0e77494b466ac2f0e25b682ab60f6fe4d63745`) executed once in the passive recovery run `45579669046`, job `139086236044`, and passed 18,667 checks with no errors. Its original 66,553-byte report has SHA256 `37b91339a5cf53b5dd0c8df0ebedda8d33fc1df717d947fe2065e54c61ce1c95`. The C result packet is immutable Git blob `e809acb4dbfdeace11f64bce60ee749a9bed9a57`. The read-only review took 2.705 seconds, sampled 184,332,288 bytes of process-tree RSS, and retained no owned survivors. It launched no gameplay.

The review binds eleven focused source archives to the same 816-file source closure, all eight original long attempts, and 37 source, import, campaign, wrapper and regression receipts. Each receipt reports no surviving owned process. The campaign processes consumed 3,654.629 recorded seconds; their separate import consumed 6.573 seconds. Wrapper and child durations can overlap and must not be added as independent wall time.

Both policies completed their 128- and 256-attempt budgets. Neither completed its 512- or 1024-attempt budget in this exact-source cohort. All eight tapes together retain 2,858 attempted and 2,847 completed actions. The four incomplete tapes have the original `campaign_timeout` outcome, no failed gameplay assertion and no pending action. They remain failed campaign outcomes. A scalar sampled RSS maximum does not establish memory growth, and one episode per policy/budget does not support a causal performance ranking.

Two actual semantic replay pairs passed: Controller 4-to-4 actions and graphical 24-to-24 actions. Both explicitly report unequal exact asynchronous observations. The ordinary laboratory also reproduced and reduced a legal four-Pause outcome to one Pause through six fresh probes of lengths 4, 4, 2, 2, 1 and 1. Its exported ordinary unittest passed. This is a valid legal-outcome regression demonstration, not a discovered engine defect. The graphical receipt records a 1600-by-900 X11/llvmpipe Workbench and three retained screenshots; it supplies no physical NVIDIA acceptance.

The passive recovery driver at source `2a627a3131be72fcb876acec0d0b848a7e42c3e3` verified all thirteen original artifact ZIPs, totaling 661,216,192 bytes. It restored exact frozen A/B/C readers, ran only the five registered Python analysis processes, and retained all their outputs. The outer owned process completed in 31.765 seconds with sampled RSS 229,445,632 bytes and no surviving owned process. All original failed, incomplete and unresolved game outcomes remain unchanged. The original predecessor Windows evaluator and raw Windows evidence are included as historical artifacts, distinct from the current owner evaluator.

The complete passive stage is artifact `15005776720`, 942,877,571 bytes, SHA256 `8621cf2811e14fdda3e98749f84b7d0887228f0c64b91967ae67485627552da9`. The complete decoded recovery job log is Git blob `7e99bc3d49a24ee31c9c87872063d664de2d5b33`. This stage is awaiting the separately reviewed seal-only phase and the exact RESULTS documentation snapshot; no final passive-archive identity is claimed in this addendum.

At this RESULTS checkpoint, the six retained predecessor Linux tape bodies were inaccessible after the local execution host became unavailable, before their passive ZIP was durably uploaded. The later recovery addendum below updates their availability. The committed recovery metadata, episode summaries and exact original digests survive; those are not replacements for the missing bodies. The predecessor Windows artifacts are preserved as their own evidence, never relabelled as Linux. The interrupted local predecessor-download attempt retains unknown completion and survivor status; the later bounded hosted download has independent successful receipts.

The qualified Windows evaluator remains separately delivered at its exact 6f identity. Its source, native, extracted, replay, memory and sealed-payload evidence is not changed by the later passive driver or documentation commits. Draft/HOLD continues.


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
