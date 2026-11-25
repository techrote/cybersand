---
title: GIP-014 goblin 002 experimental playtester
status: Planned
document-kind: research
scope: Branch-scoped in-game gameplay discovery, persistent experimental memory and qualification; Draft/HOLD
canonical-for: [gip014-goblin-002]
last-reviewed: 2026-11-25
related-documents: [gip014-goblin-gameplay-qa.md, ../operations/local-build-and-validation.md, ../operations/github-development-and-release.md]
---

# GIP-014-goblin-002 — experimental playtester

**Draft / HOLD.** The owner authorizes an ancestry-preserving successor, substantial
implementation, isolated gameplay campaigns and a self-contained Windows developer
evaluator. There is no authority to merge, mark Ready, activate goblin by default,
import unfinished programmes or claim physical Windows/NVIDIA acceptance.

## Foundation and evidence custody

The live predecessor [PR #772](https://github.com/techrote/cybersand/pull/772) was
refreshed before selecting the foundation. It is open and Ready at
`d4484bd5b488cb419bfaa94f1e69be8128734405`. Its two parents preserve the closing
source `66ee554a9faaac6776599a676fd95acb39942450` and the CI-only repair
`585520e7e62b67ce8c4c86605b08e1f8cc920bba` from #778. This successor starts there,
on `experiment/gip014-goblin-002-20261125`, without altering #772 or its state.

The [predecessor guide](gip014-goblin-gameplay-qa.md) retains its original evidence:
Linux gameplay source `1649f086a5795d88d03d19fd161ad549365a3fc4`; qualified Windows
source `3e3aa217b49036ac4a87dd57073ad2cbb5a314c8`; qualified
[run 45474099351](https://github.com/techrote/cybersand/actions/runs/45474099351)
and [evaluator artifact 14958249728](https://github.com/techrote/cybersand/actions/runs/45474099351/artifacts/14958249728).
Neither those passes nor the prototype #749 establish a newly discovered production
bug. The retained CURIOSITY256 original ended after 220 completed actions with an
unattributed SIGKILL and a pending brush; RANDOM256 ended before a fixed tape.
A separate CURIOSITY256 repeat passed. There was no qualified matched256 comparison.

The initial source-only clone exhausted the shared workspace. An attempted move
was followed by execution-host replacement. The fresh checkout is isolated in
`/home/agent/goblin002/cybersand`; no unrelated workspace data was deleted. Prepared
specialist sources were preserved as unattached Git blobs during the outage, then
materialized after host recovery. This interruption is infrastructure evidence,
not a game defect. Runtime observations and source checkpoints below remain separate.

## Ownership and mission ledger

| Lane | Source ownership | Responsibility |
| --- | --- | --- |
| Lead | Controller, UI, findings, guide, integration | Lifecycle, bounded execution, interactive reduction and evidence adjudication |
| A | State, coverage, corpus, policies, exploration tests | Observation-driven search, finite intentions, memory and behavioural diversity |
| B | Adapter, expanded actions, assertions/oracles, fixtures, capabilities | Ordinary gameplay authority, independent contracts and defect investigation |
| C | Transcript, Python tools, package and focused workflows | Replay, queue, bounded processes, comparative campaigns and Windows custody |

At the initial implementation checkpoint, source supplies 55 distinct admitted
operation contracts, 16 policy identities and ten fixture definitions. These are
**source capability counts**, not proof that every operation has completed or that
every policy has been gameplay-qualified. Exact runtime results belong in the
qualification ledger, with every failed and incomplete attempt retained.

The lead preserves ordinary startup. Native C++ remains authoritative for cells;
the mounted ordinary Workbench owns tools, configuration, actors and UI. Goblin
proposes finite typed commands, then records actual acknowledgements and copied
observations. Its optional feature seam requires explicit versioned capability
negotiation; unfinished AMBIENT, ObjectShard, Strata, Materials Lab, Gentek and Art
candidate branches are not imported.

### 2026-11-25 intake and implementation

- Refreshed main remains `00cdb02f103265b6dc5224c68283e9a0c8cb449f`.
- Pinned Linux Godot is `4.7.stable.official.5b4e0cb0f`; the official release ZIP
  matches SHA-256 `0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c`.
- Retained native Linux SHA-256 is `a15fc422313eb01e79bc904f44cc8879816484ae4fc98c63ac4b815afdb6a5e7`;
  retained Rapier is `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`.
  Those bytes match this branch's Git LFS pointers. The launcher separately verifies
  all source-input manifests before each admitted runtime programme.
- Initial exploration checks passed on the exact pinned engine. They are synthetic
  mechanism and tamper controls, not game-engine discoveries. Expanded gameplay,
  metamorphic, controller, graphical and campaign qualification are pending at this
  checkpoint.

### Initial native and infrastructure results

`expanded-001` exercised the new operations and exposed harness assumptions about
articulated collision proxies, empty actor sessions, the RFT budget precondition
and additive camera observation fields. After checking the ordinary Workbench and
native contracts, corrections stayed within goblin. `expanded-002` completed all
29 additional operation IDs in 20.488 seconds, peak observed process-tree RSS
583,782,400 bytes, with no diagnostics or surviving owned processes. Its source
was local checkpoint `06893e99` plus a recorded dirty source snapshot; this is
development evidence, not qualification of the later published source. The raw local
artifact bytes were subsequently lost with the execution host. The recorded checks
are not a substitute for fresh hosted evidence.

`metamorphic-001` was externally killed during import (exit -9 at 4.137 seconds,
peak sampled RSS 665,964,544 bytes). `laboratory-001` was externally killed without
import, before the first test output (exit -9 at 0.507 seconds, peak sampled RSS
150,646,784 bytes). Neither reached its gameplay assertions. The configured child
RSS ceiling did not attribute these kills, and no surviving owned process remained.
The cause is unresolved infrastructure; further equivalent local retries were
stopped in favor of dedicated hosted qualification. Their process results and identities remain recorded; the second host loss described below removed the local raw files.

The first published successor source is `c947143a7cb62bc8b56acd0b78b683a9fef749e0`,
tree `4c234199b1db9934aa5ba40e84b96fbb57c2c844`, in
[Draft PR #781](https://github.com/techrote/cybersand/pull/781). GitHub blob/tree
publication reproduced the exact local committed tree after CLI authentication
was unavailable. Local and remote commit IDs differ; their trees were explicitly
compared before switching the local parent while preserving uncommitted work.


### First hosted qualification and independent challenge

[Run 45527805069](https://github.com/techrote/cybersand/actions/runs/45527805069)
executed exact clean source `be64fa7896a37672c3e5d0652517789e469b9061`,
tree `c0d2875b01c41f7287fa9191922e2b3bf88b222b`. Both platforms failed the
existing fixture-edit budget control: the new Alchemy recipe contained 22 initial
edits, above the established 20-edit contract. The recipe was simplified to 18
ordinary rectangles; the gate was preserved. This was a goblin fixture defect.

The Linux run retained passing focused discovery, original adapter, expanded
adapter, controller, laboratory, gameplay, metamorphic, ordinary deferred-paint
and ordinary input checks. Graphical and full campaign execution did not start
after the failed unit gate. Windows stopped at that gate and did not qualify a
package. These partial passes do not qualify either platform as a whole.

- [Linux evidence artifact 14983617239](https://github.com/techrote/cybersand/actions/runs/45527805069/artifacts/14983617239):
  25,349,638 bytes; ZIP SHA-256
  `99b6a53dd8dd20ac5efa290e459d91a22c8f77c319ca31d9c42d6d4a1721893e`.
- [Windows evidence artifact 14983177716](https://github.com/techrote/cybersand/actions/runs/45527805069/artifacts/14983177716):
  6,029,271 bytes; ZIP SHA-256
  `19092618b62cbe440fc85cdcd7b64a61cce0f6585f9807ec34e8ed27b97dfe9f`.

Independent examination of the first native laboratory tape found two campaigns,
six completed admitted actions and zero simulation ticks. The retained-prefix
selection reused one Pause action, followed by new history actions. This proves
a native corpus round trip and selected-prefix dispatch, not an edited construction
replay, behavioral improvement or successful native reduction. The next laboratory
gate therefore cultivates a real four-action construction prefix, demands positive
native material readback on reuse, and separately reduces an actual legal semantic
outcome through fresh repeated probes.

### Recovery and stricter regression capture

The integrated local checkpoint `eaf193eaca9330a4e49ed9a5430047e0c5f82f57`,
tree `a33744521d8b4b14183f4757b58163cf5f52a59c`, passed 60 Python controls
before a second execution-host replacement. No gameplay process was running.
That local commit was not published. Exact Git blobs recovered most specialist
sources; several lead files and one gameplay action file were reconstructed from
the retained design and patches. The next published candidate is explicitly a
new source tree, and receives fresh qualification. The lost tree's local test
result does not qualify the reconstructed tree.

Automatic failing-invariant capture writes a fixed `candidate-NNN.json` beside
the raw tape. Original action arguments, semantic admission, disposition, assertion
identity and expected value are bound into reduction acceptance. Interrupted,
timed-out or unrelated failing probes cannot substitute for the target. A passing
regression must complete the originally accepted operation; changing an accepted
partial effect into a refusal cannot make the regression pass.

A subsequent independent artificial counterexample found that an earlier duplicate
successful action could still mask refusal at the actual failing occurrence. The
reader now derives the target occurrence from the chosen retained tape and checks
that aligned step in fresh observed evidence. The same before-fix counterexample
is rejected after correction. This is a confirmed regression-reader defect, not a
production gameplay defect; exact challenge and reader identities are retained in
the gameplay handover.

The data-only `regression_bundle.py` exporter supplies original and reduced tapes,
authored fixture, material evidence, exact source/runtime provenance, a hashed
fixed-member manifest, a reproduction plan and a constant ordinary unittest.
The test reads a separately produced `observed-transcript.json`; it never executes
commands supplied by a tape. Corrective-source provenance must be explicit.
Export itself makes no claim that a fresh reproduction has occurred.

An ordinary finite-canvas body stop is legal product behavior. Classification now
requires the exact authoritative refusal reason in a healthy paused immutable
Workbench publication, matching World generation and tick, plus matching action
interval evidence. Arbitrary partial effects remain unresolved. The new native
metamorphic gate must actually encounter this stop and recover through ordinary
actor reset; inability to reach it is unqualified coverage, not a production bug.


### Second hosted qualification and native regression evidence

[Run 45536048675](https://github.com/techrote/cybersand/actions/runs/45536048675)
tested clean source `89c91ba5342d485e787d39e64103fc6c91c5f92b`,
tree `18facfba0ce5a93afd00200a7f6a971458f40aa8`. Both platforms passed
63 Python/tooling controls, 333 original policy controls and 82 pure gameplay
oracle controls. A new synthetic 1024-action tape omitted all per-row assertions,
so the strict transcript validator correctly rejected it. The test fixture was
repaired to use the existing independent assertion evaluator, and an explicit
missing-assertion negative control was added. The validator was not weakened.
The repaired pure contract gate passed 194 checks.

Linux also passed discovery, original and expanded adapters, controller,
laboratory, gameplay, metamorphic and ordinary Workbench baseline groups.
The failed unit gate prevented graphical, comparative campaign and package
qualification. Windows stopped at the unit gate.

- [Linux artifact 14987252426](https://github.com/techrote/cybersand/actions/runs/45536048675/artifacts/14987252426):
  25,666,356 bytes; SHA-256
  `1b0a78406835332dc4a350273c5b2ad1543fc77a6404c6490422d0fb630a640f`.
- [Windows artifact 14987073203](https://github.com/techrote/cybersand/actions/runs/45536048675/artifacts/14987073203):
  6,049,477 bytes; SHA-256
  `08fb0ddfe01fddb20cbb702b8756d7dc8f184de270839f2881a1ec453d442061`.

The actual Linux laboratory passed 70 checks, including 29 separately labelled
synthetic controls. Its cultivated prefix was Pause, Camera, material 58 selection
and Rectangle (32,32)-(39,39). Both original cultivation and reuse completed the
same four admitted inputs. Independent before/after material arrays and native
receipts both show 64 changed cells. Memory import did not inherit completed
coverage; the reused episode earned new observations.

The laboratory also reduced four actual Pause operations to one, retaining six
fresh-World probes with action counts 4, 4, 2, 2, 1, 1. Both baseline and every shorter
accepted case were observed twice. This is legal semantic-outcome reduction,
not a discovered bug or a full physical checkpoint. The retained native bundle
was exported separately through the fixed Python tool; its occurrence-bound
reader and constant unittest passed on the actual reduced tape. The Python
export step did not run new gameplay.

### Native finite-edge follow-up repair

Independent source review identified a recovery gap after a legal finite-canvas
actor stop. A new bounded native diagnostic reproduced it: ordinary Kestrel up
input reached the edge; the next Brush was refused before gameplay admission,
with unchanged healthy paused generation/revision/tick and the exact worker
reason, but goblin classified it as `adapter_failure`. Ordinary Reset and
Play recovered the game. This was a goblin classification defect.

The narrowly scoped repair requires the exact current immutable-publication proof,
a matching refused capture admission, unchanged healthy paused source and no
successful native receipt or materials. Unrelated capture refusals remain
unresolved. No production engine code changed. The same diagnostic failed one
of 194 checks before the repair and passed 195 after it; both had 11 actual rows,
four up pulses, ordinary recovery, bounded wall/RSS monitoring and no surviving
owned process. The runs took 11.594 s and 10.658 s, with peak sampled tree RSS
585,859,072 and 585,789,440 bytes. Their exact source overlays, raw observations and
hashes are retained in the gameplay handover.

The added hostile pure oracle controls passed 110/110. The next hosted candidate
must requalify this repair, the transcript fixture correction, graphical controls,
full comparative queue and extracted Windows package together.

### Third hosted qualification and extracted-launch environment

[Run 45538643315](https://github.com/techrote/cybersand/actions/runs/45538643315)
executes clean source `d849be8ef99cd9226cfc3ca0925752e42b691515`, tree
`b6da28e8df80247bbfffb968cbe66e99b386959a`. The Windows source gates passed,
including the repaired strict transcript fixture, finite-edge recovery, native
edited-prefix reuse, repeated reduction and fixed regression export. Its six
representative campaign/replay executions retained 448 completed actions; 64 of
those belong to the separately identified replay, not a new random episode.

The base Windows package was created, then extracted qualification stopped before
launching a game process: Windows PowerShell could not discover `Get-FileHash`.
The extracted monitor retained exit 1 after 4.859 seconds, sampled peak tree RSS
98,684,928 bytes, one observed process and no surviving owned process. This is an
extracted-test environment failure, not a gameplay defect or a qualified evaluator.

- [Windows evidence artifact 14988048860](https://github.com/techrote/cybersand/actions/runs/45538643315/artifacts/14988048860):
  188,047,155 bytes; SHA-256
  `60c0e25fbec428bb767eb2c2a923a0e39566579327d08653d78b8cab1e6f3922`.
- Retained unqualified base ZIP SHA-256:
  `be5d7e6cce09ff2d3d7c4a2dba9fdc6798c001fa8bd8876ba3d5a48efb32032e`.

Microsoft documents the precise [PowerShell module-path inheritance boundary](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_psmodulepath?view=powershell-7.6#starting-windows-powershell-from-powershell-7):
a Python intermediary can pass PowerShell 7 module paths to Windows PowerShell,
preventing standard module autoload. The focused qualifier removes only that
variable, case-insensitively, from its child environment. Actual extracted execution
must still establish the repair; the package launcher, Godot sources and native
bytes are preserved.

The wrapper includes a fixed, bounded inherited/clean environment probe which
checks the discovered standard command by hashing its own exact script. It records
command/version identity without dumping environment values. The four added
environment-boundary controls and existing Python suite passed 67/67, including
actual pinned-engine pure parity, in 3.422 seconds with no surviving owned process.
These are local tooling controls; actual Windows repair evidence is still required.

Request 4 explicitly selects all Linux focused/regression/graphical gates plus
the existing two-episode smoke, and all Windows source/extracted-package gates.
The original 142-episode Linux programme continues separately at request 3's exact
source. Its results must retain that identity. The command-line Linux qualifier
still defaults to the full programme; `--qualification-request` selects only the
committed `full` or `smoke` plan and records that scope in its ledger.

A separate source review raised a possible cached-pause-field issue for Step then
Save. A bounded controller diagnostic did not reproduce it: both Pause/Save and
Step/Save completed with valid full captures, four total completed actions and
39 passing action assertions. A preceding diagnostic setup error correctly hit
the authored-fixture identity fence before dispatching any actions. Both attempts
are retained in the gameplay handover. No oracle relaxation or game-code change
followed the negative result.

### Fourth hosted qualification and articulated-origin oracle finding

[Run 45541023949](https://github.com/techrote/cybersand/actions/runs/45541023949)
tested clean source `a6abb07aa8374dc2a870c2a6c9d0aca4f1981402`, tree
`1dac01a01e4f8947a2e7d80f3ace34b9de6dd5ea`. Its explicitly scoped Linux
qualification passed all thirteen stages: Python controls, nine focused source
groups, actual native regression export, graphical laboratory and the two-episode
smoke. Both smoke episodes completed all sixteen actions.

The Linux [evidence artifact 14990021487](https://github.com/techrote/cybersand/actions/runs/45541023949/artifacts/14990021487)
is 29,358,298 bytes, SHA-256
`d5f2c27509392a88a2faededbcd8d70072b50a57e90d7b12b3513545c8d914e1`.
The lead independently checked 813 executed source files and passed 839 source,
graphical and regression-custody checks. All three actual 1600x900 captures were
visually inspected. The graphical script passed 36 controls and retained a
24-action Builder campaign plus its separate 24-action semantic replay. Every
semantic fingerprint matched; exact observation fingerprints differed. These
fingerprints also contain receipt/timing information, so their differences alone
do not isolate physical-trajectory differences. Rendering used Mesa llvmpipe
under X11, with no physical NVIDIA acceptance. The inner graphical process took
213.757 seconds and peaked at 1,371,246,592 sampled process-tree RSS bytes.

The gameplay specialist separately passed 117 native evidence checks. Expanded
gameplay retained 54 attempts, 51 completions and all 29 additional action IDs;
the metamorphic suite retained 36 attempts and 33 completions. The noncomplete
rows were explicit negative controls, an actual RFT budget refusal, an unavailable
runner actuator, an already-active source refusal and independently justified
finite-edge outcomes. The actor recovered through ordinary Reset and Play.
The native laboratory again reduced four actual Pause actions to one through
six fresh probes of lengths 4, 4, 2, 2, 1, 1. The fixed exported unittest passed;
this remains legal semantic-outcome reduction.

Windows established the module-boundary repair with actual child processes:
the inherited environment could not discover `Get-FileHash`; the corrected
environment resolved `Microsoft.PowerShell.Utility` under Windows PowerShell
5.1.20348.5773 and hashed the exact probe script in 0.735 seconds. The unchanged
launcher then ran real extracted gameplay. Both 64-action Control cases passed.
The Coverage Hunter case, initially Alchemy/seed 13, stopped after 61 completed
actions at step 60's `actor_place_position` assertion.

That retained row exposes a **test-oracle defect**. Ordinary Monowheel placement
stored authored origin (256,96), placed its weighted cab at (256,97.5), and placed
its rim at (256,96), all at tick zero with neutral motion. The product catalogue
defines the cab's local offset as (0,1.5); the physical constructor adds each part's
offset to the assembly origin, and the body-state API reports part zero. Goblin
incorrectly required that body position equal the authored origin. The related
Move, Reset and Replace expectations require the same distinction. The production
constructor was behaving according to its contract.

The game automatically retained the failed tape and `candidate-001.json`, with
an unresolved classification and zero defect confirmations. Independent review
classifies the finding as a test-oracle defect without rewriting that historical
candidate. The exact tape is 817,872 bytes, SHA-256
`9476a8bcf39c188a811eed6f9dc05dc8056515362af27a4bf473cf5905a0e302`.
The generic regression checker continues to require the original expected value;
an oracle correction cannot masquerade as a successful unchanged-invariant
production fix.

The Windows [attempt artifact 14989104342](https://github.com/techrote/cybersand/actions/runs/45541023949/artifacts/14989104342)
has SHA-256 `807742a6941a411b498bb28181cb0d64cb89085723254708847d652152893de1`.
Its failed extracted process remained bounded at 87.843 seconds, with seventeen
observed owned processes and no survivors. No successor evaluator was sealed.

The next candidate receives a fresh full 142-episode Linux programme. The old
oracle can end actor-rich policies earlier than the baselines; reclassifying those
failures cannot recover their missing action suffixes. All request-3 attempts
remain retained at their exact source, while the corrected-source matched-budget
comparison is separately identified. This is a justified repeated experiment,
not a transfer of the prior candidate's qualification.

### Corrected candidate and registered memory experiment

The correction independently distinguishes authored assembly origins from
physical part positions for all six supported actor models. Only Monowheel has
a nonzero part-zero offset, (0,1.5), in the pinned catalogue. Placement, Move,
Reset and Replace now check the authored origin and observed parts separately.
Capture retains its ordinary product meaning; no unestablished capture/reset
idempotence requirement is introduced. The expanded native gate will exercise
every supported model through those ordinary lifecycle operations.

Pure local verification passed 218 Godot contract checks, six focused Python
origin controls and an independent 22-check review of retained native evidence.
The complete Python/pure suite passed 99 tests before the lead added three
top-level orchestration tests; those three tests passed separately, including
four explicit interruption boundaries. A subsequent integrated attempt was
externally killed with exit -9 after 0.905 seconds, at 140,304,384 bytes sampled
RSS, with no owned survivors and no test failure reported. The captured process
result and exact 37-byte log are retained; this is an unattributed infrastructure
interruption, not a successful integrated run. The workspace was subsequently
replaced. Specialist inputs were restored from verified immutable Git blobs;
the lead's small integration changes were reconstructed and rechecked. Hosted
qualification must run the final suite.

The next Linux qualification includes a separate seven-episode persistent-memory
experiment before its fresh-memory 142-episode queue. One actual Control64
construction campaign supplies its complete unchanged corpus. Two matched seeds
then run Coverage Hunter64 with fresh memory, imported hints, and explicit
retained-prefix reuse. The second seed reverses treatment order. The two seeds
are chosen from the actual retained prefix's bounded selection rank before any
measured outcome; this is a registered adaptive selection rule, not an outcome
search. Measured outputs never feed later treatments.

Explicit reuse requires the actual four admitted actions and source-matched
native captures showing a 64-cell empty region becoming material 58. Imported
hints receive credit only through observed choices; imported coverage is never
counted as current-episode coverage. The report separates paired observed
coverage, newly observed keys beyond cultivation, actual choice divergence and
training/attempt costs. Seven episodes cannot establish a general learning or
performance advantage.

The memory worker has a 900-second whole-process-tree bound, 3072 MiB sampled
RSS bound, 1 GiB sampled aggregate output bound and 16 MiB log bounds. Each game
process has 180 seconds and the one shared import has 240 seconds. Attempts are
registered before dispatch and missing results remain missing. Source or evidence
custody failure stops qualification. An ordinary retained episode failure permits
the independent full queue to run. Explicit interruption stops the entire
programme before another child process or campaign starts, with exit code 130
and durable cancellation receipts. The same stop rule applies to fixed source
tests, reducer probes and extracted-package PowerShell preflight.

### Request 5 Windows control failure and request 6

[Request 5](https://github.com/techrote/cybersand/actions/runs/45546330774) runs at
`7097b338750f06f74ae742c9bea07aa0b1949b94`, tree
`1f03f596daba13b01c31addd31f506b07a03de42`. Its Windows Python gate ran 102 tests
in 2.636 seconds and reported four errors in the new mocked cancellation controls,
before native qualification began. The failed control used Windows' short
temporary-directory alias (`RUNNER~1`) while the ordinary runner canonicalized
its output path. The mock's relative-path conversion therefore failed before
its expected terminal receipt existed. This is a test-harness defect, not a
gameplay or cancellation failure observed in Godot.

The exact Windows attempt remains in
[artifact 14991218704](https://github.com/techrote/cybersand/actions/runs/45546330774/artifacts/14991218704),
2,117 bytes, SHA-256
`dfa6d942cd3651e973a6f7c50cc4fdc5e8a002b959065883c00029d8780146ce`.
An ordinary existing-directory/`..` alias reproduced the mismatch in the pure
fixture. Canonicalizing the fixture root repairs it; a fifth mocked control
preserves that portable regression without requiring symlink privileges.
Independent review passed all five controls. Actual Windows re-execution is
still required.

Request 6 changes only that Python test fixture, this ledger and the finite
qualification request. All game scripts, gameplay adapters, policy generators,
oracles, runtimes and owner launchers remain byte-identical to request 5.
Its Linux scope repeats focused, graphical, regression-export and seven-episode
memory gates plus a two-episode smoke. The full 142-episode request-5 Linux
comparison continues independently at its exact source; it is not relabelled
as a request-6 run. Windows repeats the complete source and extracted evaluator
qualification. Neither attempt is a qualified successor evaluator yet.

### Request 6 Windows byte-custody control and request 7

[Request 6](https://github.com/techrote/cybersand/actions/runs/45546944291), source
`955a7fb89302d0aaa733e8868b047f3b82061e8d`, passed the path-normalization boundary
and exposed a second portability assumption in the same synthetic fixture.
Windows translated its authored text fixture to CRLF; the strict archived-source
assertion expected LF bytes. All 103 Python tests ran and five cancellation
controls failed only that exact-byte assertion. Native qualification did not
begin. The actual failed artifact is
[14991199645](https://github.com/techrote/cybersand/actions/runs/45546944291/artifacts/14991199645),
1,900 bytes, SHA-256
`d1698c924af1c5d2bd0c4bd156059110199f5e6efae2ee7643870bcadbfb580e`.

The fixture now writes its two synthetic source members as explicit LF bytes.
The exact archive assertion remains unchanged. Five focused mocked controls
passed, with independent review of the import/custody path; actual Windows
re-execution remains required. This correction changes no game or production
runner behavior.

Request 7 selects Windows only through an explicit finite platform list in the
committed qualification request. A small workflow planning job validates that
list and gates the two existing jobs. Defaults still select both platforms;
unknown, duplicate or empty platform lists fail. Every Windows gate remains
unchanged. The request-5 full Linux and request-6 focused/memory/smoke programmes
continue at their exact sources, avoiding another equivalent Linux campaign.
The new job's explicit Linux skip is not a Linux qualification pass.

### Completed request-3 Linux campaign audit

The original full campaign is retained at exact source
`d849be8ef99cd9226cfc3ca0925752e42b691515`, tree
`b6da28e8df80247bbfffb968cbe66e99b386959a`. Its
[Linux artifact 14990308987](https://github.com/techrote/cybersand/actions/runs/45538643315/artifacts/14990308987)
contains 2,153 members, 507,414,310 uncompressed bytes, and has archive SHA-256
`9da70daac1b69235311540debf7c42bd067dc7776cc2c680223f54b5eff1da8d`.
The independently pinned d849 readers validated all 142 tapes and recomputed
all 142 coverage records. The campaign itself retains 107 passes and 35 failures.

| Cohort | Episodes | Budget-complete | Actual rows | Completed admitted actions | Refusals |
| --- | ---: | ---: | ---: | ---: | ---: |
| Matched nine-policy comparison | 108 | 92 | 6,486 | 6,483 | 3 |
| Long-horizon probes | 8 | 1 | 733 | 733 | 0 |
| Personality catalogue | 16 | 14 | 912 | 910 | 2 |
| Scenario catalogue | 10 | 0 | 263 | 263 | 0 |
| Total | 142 | 107 | 8,394 | 8,389 | 5 |

Independent gameplay review passed 1,185 custody and contract checks. All 35
failed rows are accepted, completed Monowheel placements at tick zero: authored
origin (256,96), actual cab/part zero (256,97.5), rim (256,96), healthy native
state and zero motion. The corrected reader finds no other independent product
failure across these unchanged rows. The original tapes retain their failed
assertions; this is a reviewed test-oracle correction, not an unchanged-invariant
game fix. Four refusals have current native body-protection proof and one is
an ordinary off-camera rectangle preflight. No production defect is established.

Observed unions include 52 completed action IDs, 655 adjacent action transitions,
4,362 state transitions, 75 sampled material-interaction keys, 57 tool/material
pairs, 86 actor/environment keys, eight lifecycle keys, two refusal keys and
76 outcome keys. No per-episode dimension saturated. These are finite observed
key unions, not fractions of all possible gameplay or chemical-reaction counts.

The comparison is censored by the old oracle: no matched block has all nine
policies complete. Novelty versus Random has zero complete pairs. Coverage
Hunter versus Random has four pairs, with median differences of +3 action IDs,
+4 action transitions and -4 material keys. Coverage Hunter versus Novelty has
five pairs and no median action-ID advantage. These conditional subsets support
no universal policy ranking. Of the long probes, only Coverage Hunter128
completed; the remaining seven ended at the old position oracle, so they do
not establish longer-horizon resource limits or completion reliability.

The complete exploration analysis is preserved in immutable Git blob
`742b95cc1ad278b96f6d739bf934e549d516b1a3` (custody envelope), with decoded report
SHA-256 `97ecd8f957ee3294d4d2006ebb13f18f8c1cd752dac50bf2403f906895e58ad1`.
The independent gameplay audit and auditor are preserved in blob
`2f830bbc531b38d25cd73084c8262ba5f23834c8`, ZIP SHA-256
`e3633f538977bfd025f5c5d238c3a1d31d71769700aec24d4e141208d478e9a4`.
The corrected-source full comparison remains separately pending.

### Native fixture correction and request 8

Completed request-5 and request-6 Linux evidence supersedes the earlier running
status: both stopped at the newly expanded six-model gate, before graphical,
memory or comparative execution. Request 5 retained 86 native rows and 1,621
test checks with 50 test-local failures. Every row's runtime oracle assertions
passed. Two assumptions in the added test were wrong: exact Variant-array
equality distinguished expected integer coordinates from observed float
coordinates, and the test requested replacement into an absent non-flyer model.

The ordinary compact picker intentionally contains flyers, the barrel and
currently placed non-flyers. Its six refused replacements were legal. The
repair compares finite numeric coordinate components exactly, with no tolerance,
and performs same-model Replace for each of the six lifecycle cycles. Those
models are actually present in the picker and each replacement creates a fresh
actor identity. The pre-existing Runner-to-Kestrel cross-model test remains.
Only the native test fixture changes; the corrected runtime oracles, gameplay
adapters, policies and product code remain unchanged. Independent source review
confirmed the authority and exact comparison; a native pass is still required.

Request-5 Linux evidence is
[14991816351](https://github.com/techrote/cybersand/actions/runs/45546330774/artifacts/14991816351),
25,889,266 bytes, SHA-256
`535f955d4f2bd1f378d58bc038eb5d77db8da8a9bbadc90437b24056531572a7`.
Request-6 Linux evidence is
[14991867139](https://github.com/techrote/cybersand/actions/runs/45546944291/artifacts/14991867139),
25,887,507 bytes, SHA-256
`270fb06e878cdcb450d9b4a227e6e9e767c34b2fafc9e7c34acb22bf37e5c8c8`.

[Request 7](https://github.com/techrote/cybersand/actions/runs/45547821984) verified
the finite Windows-only selection and both Python-fixture repairs: all 103
controls passed in 3.014 seconds on Windows. Unit, discovery and adapter native
groups passed, then the same expanded native fixture failed before packaging.
Its artifact
[14992221745](https://github.com/techrote/cybersand/actions/runs/45547821984/artifacts/14992221745)
is 24,637,570 bytes, SHA-256
`25d17227a77ef95affb07139fbde6f0c9e3a3d6384e22ad58b9da7e02177d2d4`.

Request 8 explicitly selects both platforms, including a complete new 142-episode
Linux comparison and the separate seven-episode memory programme after focused
and graphical gates pass. The historical d849 campaign remains the only
completed full comparative programme at this checkpoint. No successor evaluator
is yet qualified, and no new production defect has been established.

## Experimental contract

`godot/goblin/goblin_state.gd` abstracts admitted observations. Monotonically growing
clocks and instance identities do not create artificial novelty. Unknown or stale
material samples remain unknown. Coverage separates action vocabulary, adjacent
admitted actions, state transitions, sampled material interactions, tool/material
pairs, observed actor/environment combinations, lifecycle, boundaries/refusals and
outcomes. Nominal menu entries and proposed commands receive no completed coverage.

The original six policy generators are retained. Ten additional personalities use
shared finite weighted choices and construction/history/actor intentions. Random,
stateful, novelty and coverage cohorts use matched fixture/seed/action budgets.
Imported history can inform search only in a separately labelled reuse cohort.
The original six personalities preserve their baseline behavior; the UI enables
explicit prefix reuse only for successor personalities.

The corpus holds at most 64 bounded records and 2 MiB. Reusable prefixes are limited
to 128 actions from an exact matching authored fixture and source/runtime identity.
Longer discoveries retain observation identities without pretending to contain a
full setup or physics checkpoint. Imported confirmed labels are downgraded; imported
coverage remains a heuristic prior, never this campaign's measured coverage.

Candidate anomalies are triaged into unresolved observation, legal unusual gameplay,
unsupported action, expected refusal, harness defect, oracle defect, infrastructure
failure, deliberate negative control or independently confirmed production defect.
The live UI cannot promote an observation to a confirmed defect. Reproduction and
reduction provide evidence; independent examination establishes the classification.

## Laboratory controls

Open the supplied developer evaluator with **Open goblin.cmd** when qualified.
For source use, run the committed isolated launcher:

```text
python tools/gip014/run_goblin.py --godot /path/to/pinned-godot --case interactive --out /path/to/new-test-run --fixture construction --policy COVERAGE_HUNTER --seed 605 --budget 128 --pacing-ms 150
```

The ordinary game remains usable without goblin. The dedicated scene requires a
marked disposable profile before mounting a Workbench. The panel has Play,
Discovery, Memory and Guide tabs, a visible animated pointer and optional observed
trajectory/edit overlays. Start installs a fresh fixture; Pause holds decisions;
Step admits one decision; Stop drains input and pauses the game. Native simulation
and actor clocks are displayed separately from action count and elapsed real time.

Budgets are 1..1024 actions. Active campaign bounds grow from 150 seconds to at most
900 seconds; absolute session bounds include pacing and manual decision pauses and
never exceed 5400 seconds. Each action still has its own existing bounded native
receipt/operation completion contract. The launcher supplies a separate owned-process
wall/memory bound. A profile admits at most 64 campaigns and 512 MiB of retained
run archives. Tapes are capped at 32 MiB; failures to retain evidence fail closed.

Memory import reads only the launcher's staged `goblin-corpus.json`. Memory export
and clear use fixed files below the marked test profile. Clearing experimental
memory preserves existing campaign evidence. No gameplay action accepts an arbitrary
file path, network destination, shell command or external desktop operation.

### Choosing a personality

All policies use the same finite gameplay adapter and observation contracts.
The first six retain their predecessor decision rules and do not dispatch retained
prefixes. Persistent hints affect the successor search mechanisms; explicit prefix
reuse is a separate choice. A named personality is a strategy configuration,
not proof of a particular outcome or discovered defect.

| Personality | What to watch |
| --- | --- |
| Control | Repeatable tour through paint, copy, history, persistence and real Play |
| Wanderer | Waypoints, material trails and control of an actually observed actor |
| Builder | Small cups, material placement and removal of supporting ledges |
| Tinkerer | Editing, copying, authoring history and reopening starts |
| Curiosity | The predecessor's least-exercised-control search |
| Seeded random | Selection from the adapter's currently applicable legal menu |
| Stateful explorer | Finite construction, editing and actor intentions chosen from observations |
| Novelty seeker | Under-observed state/action combinations and parameter variants |
| Coverage hunter | Admitted action, transition and parameter coverage |
| Disaster artist | Reservoir construction, material insertion and bounded wall breaches |
| Boundary goblin | World-edge geometry, view limits and actual refusals |
| History goblin | Reversible edits, copy/paste and authored persistence |
| Material alchemist | Admitted material combinations and their observed development |
| Actor enthusiast | Actual actor capabilities, controls and supported equipment |
| Impatient switcher | Rapid alternation between action families and simulation/UI states |
| Obsessive reproducer | Repeated small edit relationships and optional matching-prefix reuse |

### Choosing a scenario

Each scenario is an ordinary authored 512x512 Setup-v2 recipe installed in a
fresh disposable World. These are authored starts, not evolved physics checkpoints.
The complete source catalogue is `godot/goblin/goblin_fixtures.gd`.

| Scenario | Authored conditions and useful question |
| --- | --- |
| Material playground | Sand, Water and Wood above a hard floor; observe bounded edits and mixed material arrangements |
| Actor workshop | Kestrel, passive barrel and a stepped route; investigate control, actor lifetime and obstacles |
| Construction table | Wood frame and open space; build, erase, select, copy and revisit history |
| Liquid channel | Water reservoir and editable Wood gate; compare release, containment and repair |
| Save and reopen | Asymmetric material pattern and a barrel; compare authored persistence under its tick-zero preconditions |
| History and editing | Asymmetric Wood/Metal tiles and an empty translation control; check reversible operations |
| World boundary laboratory | Hard boundary markers and narrow passages; exercise view clipping, replacement and refusals |
| Material alchemy | Separate Oil, Water, Ice and Wood pockets; observe combinations without inventing a chemistry law |
| Mixed interaction yard | Runner, Kestrel, barrel, Water, Sand and an editable wall; combine ordinary gameplay families |
| Closed Sand cell | Exactly 64 Sand cells in a hard enclosure; apply the separately justified nonreactive conservation experiment |

For a first visible session, select Construction table and Builder with a budget
of 64 and pacing around 150 ms. Use Discovery to inspect measured coverage and
the observation queue, then Memory to export the bounded corpus. A later fresh
session can import that corpus and select a successor personality. Explicitly
enable matching-prefix reuse when the intention is to revisit a construction.
The UI shows proposed reused actions separately from actual observed outcomes.

The ordinary source launcher accepts `--corpus` for supported historical search
hints. Explicit retained-prefix reuse is currently exposed by the laboratory
control and typed Controller launch contract; `--corpus` alone does not request
prefix dispatch. Clearing memory leaves raw campaign archives available for review.

## Replay, reduction and regression export

Semantic replay compares documented game outcomes. Exact asynchronous observation
replay has a distinct result and is not inferred from semantic equality. Authored
Save/Reopen and experiment-queue resume do not resume evolved physical state.

Interactive reduction admits up to 128 actions, at most twelve fresh-world probes,
30 seconds active time and 60 seconds absolute time per probe. The original target
must reproduce twice before deletion search begins. Every accepted shorter candidate
must reproduce twice; failed attempts remain separate run archives. Original pacing
is retained, so a case whose timing cannot fit the bound remains unqualified.

A target is either the same independently evaluated failing invariant or a precise
completed semantic outcome. Reducing a legal successful outcome is not a discovered
bug. The exported bounded bundle includes original and reduced tapes, the actual
initial authored fixture, exact provenance, required action IDs, acceptance rule,
observed failures and fixed-entrypoint reproduction instructions. Longer sequences
use the separately bounded Python reducer.

## Qualification and decision status

**Pending for the corrected candidate:** a fresh matched-budget comparative
programme, long-horizon completion and extracted package qualification, together
with source-matched focused and graphical gates. Request 4 passed its complete
declared Linux scope but failed the separate Windows extracted campaign because
of the articulated-origin oracle defect. Prior passes remain attached to their
exact published source. No successor Windows evaluator is yet qualified. The
predecessor evaluator remains independently valid at its original source.

Qualification will retain every process, exit code, watchdog/cancellation result,
source snapshot, native/runtime identity and raw terminal or incomplete tape. No
novel production gameplay defect has yet been established by this successor.

## Documentation impact

This is a branch-scoped developer-only candidate. Production subsystem contracts,
startup defaults, material laws, native interfaces, owner profiles and accepted
runtime provenance are unchanged. The focused research guide and specialist
handovers own the candidate facts; the documentation index routes to them and the
retrieval manifest excludes them from ordinary accepted-product answers. Historical
records and the predecessor guide remain unchanged.

### Independent historical failing-case reduction request

Request8 is pinned to `5ee5dffc78d59a721f62be49fd51d24b870556c7`, tree `287795a8534c5622ede5d71710714ea467197e79`, run[45550152509](https://github.com/techrote/cybersand/actions/runs/45550152509). Both Linux and Windows jobs started. Their qualification results remain pending; later forensic/documentation commits do not change the evaluator source under test.

The lead added a separate fixed historical reduction programme, independently source-reviewed by SpecialistA. It consumes the original44-row native tape from request3 long-0108 (RANDOM, construction, seed1701, requested128), original SHA256`050155da6012b4eed736b66d998315dc479914549475bab048a8a65c9ff3fb67`. The exact d849 checkout, tree, fixture and Linux runtime are mandatory. Its original actor-place invariant remains unchanged: the final Monowheel assertion is a **test-oracle defect** because the product catalogue places the root cab1.5cells below the authored origin. The case is retained as deterministic gzip data, not an executable action source.

The driver invokes only the historical fixed launcher and exporter. Every replay probe starts a fresh marked fixture. Bounds are24probes with two confirmations,600seconds of reduction within a900-second owned worker,3072MiB sampled RSS and1GiB sampled output; runtime acquisition and the fixed Python export/check stages have their own deadlines inside a30-minute hosted job. Cancellation stops advancement and retains attempted evidence. The program requires a shorter repeatedly reproduced tape, a passing reproduction check, and an ordinary generated unittest that fails precisely on the unchanged historical invariant. An expected regression failure is recorded explicitly; it is never relabelled as a passing corrective candidate. Product-contract proof and test-oracle classification are separate from the immutable failure manifest.

SpecialistA found and blocked an early driver comparison that incorrectly required the complete action dictionary to contain only `id` and `args`; real actions also retain their proposed `goal`. The lead corrected the pure proof to check exact action identity and arguments while preserving all raw metadata. The resulting source review is retained in Git blob`5e1ad576340fd7b653d5a4d243b8e1899623ac37`. This section records preparation only: no new native reproduction or reduction result is claimed before the hosted job and its raw artifacts are independently examined.

SpecialistC independently checked the historical driver's process ownership and expected-failure acceptance. C identified a late-write gap in the sampled output limit; the lead added a final closed-worker scan bounded at100000entries/10seconds, with explicit monitor join and unexpected-link rejection. An isolated5-byte last write against a4-byte limit was correctly rejected even with periodic sampling stopped. The actual original tape's separate product-contract proof passed. C then approved the final narrow repair. These are source/pure controls, not native reproduction evidence. CI provider policy and the96-workflow scheduling inventory passed.

### Historical native failure reproduced and reduced

The independent[historical run45550580312](https://github.com/techrote/cybersand/actions/runs/45550580312) passed at driver source`7029661d1dbe373b97b3da5aaaf175dae153001e` while executing the unchanged d849 game/oracle. The actual44-row finding reduced to one Monowheel Place through12fresh probes:44,44,22,22,11,11,5,5,2,2,1,1. Each accepted length retained two independent confirmations of the exact action, admission, failure and expected value. The probes contain170attempted rows,168completed actions and two expected unavailable-actor-setting refusals. Every target Place completed. The original authored construction fixture remains required; no minimal-fixture or parameter-optimality claim is made.

The native worker completed in140.553seconds with781647872bytes peak sampled process-tree RSS,17observed owned processes and no survivors. The sampled/final evidence size was385244832bytes below1GiB. The data-only exported case passed reproduction verification. Its constant unittest correctly exited1 with exactly the unchanged historical acceptance assertion, preserving the original failure rather than claiming a corrective pass. The product-contract examination still classifies this as a test-oracle defect, with no production gameplay defect.

[Artifact14994110507](https://github.com/techrote/cybersand/actions/runs/45550580312/artifacts/14994110507) contains187members/36402316uncompressed bytes; ZIP5255383bytes, SHA256`211322dcb6f91da534420b1694ad6f4ef302f5a6f2e6a82e8cb10fcd1b5d7640`. Lead independent review passed1970checks, including all813archived source files against the exact Git source, twelve raw tape/receipt/log bindings, accepted failure keys and product offsets. SpecialistC independently passed208checks and caught an initial verbal denominator mistake:170was attempted rows, not completed actions. The corrected exact evidence/auditor packet is Git blob`54112e671e8706311616e4c9e084d172024d3a6e`, decoded SHA256`871e8650ac516dc7d0a775d107b13e1da4366f6fc5594dee3805887ac8893e9e`; the earlier report and two pure reviewer-schema errors are retained. C's independent report is`71e31d855dda060bb5d2d15c322e2be1f6b28604`; full hosted job log is`03adf338fb6bf64001c9c34a3ac1c79a7331af98`. These source/custody checks are not1970new gameplay assertions.

### Qualified Windows result and separate retained-clock hypothesis

Request8 Windows completed successfully at exact source`5ee5dffc78d59a721f62be49fd51d24b870556c7`; the uploaded qualified evaluator is[artifact14994660661](https://github.com/techrote/cybersand/actions/runs/45550152509/artifacts/14994660661). The actual inner evaluator ZIP is95549310bytes, SHA256`513cba95be9465540dca46975a48a77f89b241daea0db7859839acb0f6ec69ee`. Its base ZIP is separately identified by SHA256`a9efed4856bef37454bfc0c0169a252c639aeed7d80c97155942ac5ff7aabbd6`. Independent delivery/source/EOL custody review is still in progress at this checkpoint. The lead visually inspected all three actual1600×900extracted Windows screenshots: ordinary Workbench, green goblin pointer and scrollable Play/Discovery/Memory controls are visible and readable. Actual extracted campaigns completed64actions each for Control actor_workshop, Control save_reopen and Coverage Hunter alchemy. Portable64-action semantic replay passed; exact asynchronous observation identity was false, as separately reported. The actual47-record then64-record corpora exercised backup/import/clear while preserving two native archives. No physical NVIDIA acceptance is claimed.

The Linux comparison remains in progress. Source refresh reconfirmed main`00cdb02f103265b6dc5224c68283e9a0c8cb449f`, Draft/HOLD successor ancestry through all four recorded predecessor identities, and no imported candidate programmes. Current repository identity/docs checks passed; retained M11 integrity passed18records/28historical source hashes. The frozen retrieval set returned30/32canonical hits at k,19at rank1,MRR0.7292; these are retrieval metrics, not answer correctness or gameplay evidence.

B's deeper lifecycle examination identified a new hypothesis, separate from all current qualification claims: retaining World replacement can copy evolved cells while publishing native tick zero, whereas ordinary Save writes the authored recipe. The current native-equality applicability oracle uses tick zero. A fixed nine-action diagnostic now compares an actor-free positive-tick Save/Reopen control with a fresh variant adding one actually offered response-mode replacement. Independent2304-cell captures establish initial geometry, real Sand movement, retained evolved cells and authored Reopen; named-file readback checks the original recipe. No production state is injected, and no oracle is altered. The added entrypoint is the only permitted Godot input difference from5ee; exact executed instrumentation/source archives are retained separately.

A independently reviewed the GDS decision/capture fences. C reviewed the fixed driver and found an archive-retention exception could mask cancellation; B repaired it and five artificial controls passed. C withdrew an earlier cwd concern after verifying the existing wrapper supplies it. These are source/pure reviews only. The separate12-minute hosted diagnostic permits a120-second import then one90-second/3072MiB game process, with bounded reports/logs. A positive result remains an applicability candidate until raw evidence and product contracts are independently examined.
