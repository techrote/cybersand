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

## Remaining decision authority

The lead owns final source freeze, independent review disposition, hosted run
monitoring, exact artifact identities and the owner-ready decision packet.
All results remain Draft/HOLD. No default activation, merge, Ready promotion
or physical NVIDIA acceptance is authorized by these tools. No novel production
gameplay defect has been established by this handover.
