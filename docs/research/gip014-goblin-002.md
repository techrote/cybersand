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
| Save and reopen | Asymmetric material pattern and a barrel; compare authored persistence only with proved compatible material history |
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

This committed ledger precedes execution of its own source. In a sealed evaluator,
`OPEN-ME.md` and `delivery/qualified-delivery.json` record that package's later
actual extracted qualification; this source guide retains earlier checkpoints
without rewriting their results.

**Qualified Windows evaluator:** request 8 at exact source
`5ee5dffc78d59a721f62be49fd51d24b870556c7` passed focused native, graphical,
replay, isolation and extracted-package gates. Independent delivery review passed
3,841 custody checks; independent gameplay review passed 248 checks. The actual
95,549,310-byte final evaluator has SHA-256
`513cba95be9465540dca46975a48a77f89b241daea0db7859839acb0f6ec69ee`.
The corrected-source Linux matrix and registered memory experiment are still in
progress at this checkpoint. Their pending results receive no coverage credit.
The later070diagnostic independently established a Save/Reopen applicability
defect in the5ee oracle. Its known limitation is retained beside that historical
qualification; the version3 corrective evaluator requires its own qualification.

The earlier d849 Linux programme retained all 142 attempted episodes and 8,389
completed actions, including 35 processes stopped by the subsequently corrected
Monowheel test oracle. A separate exact-source historical programme reproduced
that real finding and reduced its 44-action tape to one action with two fresh
confirmations per accepted length. Its exported unchanged-oracle unittest fails
as expected. It is a test-oracle defect, not a production gameplay defect.

Every retained pass and failure remains bound to its actual source/runtime and
process receipt. Later diagnostics and documents do not relabel the 5ee evaluator
as qualification of their source. No novel production gameplay defect has yet
been established. The predecessor evaluator remains independently valid at its
original source. Draft/HOLD, no default activation and no physical NVIDIA claim
remain explicit.

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

Request8 Windows completed successfully at exact source`5ee5dffc78d59a721f62be49fd51d24b870556c7`; the uploaded qualified evaluator is[artifact14994660661](https://github.com/techrote/cybersand/actions/runs/45550152509/artifacts/14994660661). The actual inner evaluator ZIP is95549310bytes, SHA256`513cba95be9465540dca46975a48a77f89b241daea0db7859839acb0f6ec69ee`. Its base ZIP is separately identified by SHA256`a9efed4856bef37454bfc0c0169a252c639aeed7d80c97155942ac5ff7aabbd6`. Independent delivery/source/EOL custody review subsequently passed3,841checks over1,230base payload files and22supplements; source bindings and all36owned-process receipts matched, with no survivors. Five launcher files differ from raw Git only by exact attribute-authorized Windows archive newline conversion, individually proved. Report blob`e4321ad82203bb9a3a516cfa425795fa8cbd71d6` and reproducible audit packet`3bd9fcfe697e46fa046480ee0944aa22410a6dec` retain that proof. The lead visually inspected all three actual1600×900extracted Windows screenshots: ordinary Workbench, green goblin pointer and scrollable Play/Discovery/Memory controls are visible and readable. Actual extracted campaigns completed64actions each for Control actor_workshop, Control save_reopen and Coverage Hunter alchemy. Portable64-action semantic replay passed; exact asynchronous observation identity was false, as separately reported. The actual47-record then64-record corpora exercised backup/import/clear while preserving two native archives. No physical NVIDIA acceptance is claimed.

The Linux comparison remains in progress. Source refresh reconfirmed main`00cdb02f103265b6dc5224c68283e9a0c8cb449f`, Draft/HOLD successor ancestry through all four recorded predecessor identities, and no imported candidate programmes. Current repository identity/docs checks passed; retained M11 integrity passed18records/28historical source hashes. The frozen retrieval set returned30/32canonical hits at k,19at rank1,MRR0.7292; these are retrieval metrics, not answer correctness or gameplay evidence.

B's deeper lifecycle examination identified a new hypothesis, separate from all current qualification claims: retaining World replacement can copy evolved cells while publishing native tick zero, whereas ordinary Save writes the authored recipe. The current native-equality applicability oracle uses tick zero. A fixed nine-action diagnostic now compares an actor-free positive-tick Save/Reopen control with a fresh variant adding one actually offered response-mode replacement. Independent2304-cell captures establish initial geometry, real Sand movement, retained evolved cells and authored Reopen; named-file readback checks the original recipe. No production state is injected, and no oracle is altered. The added entrypoint is the only permitted Godot input difference from5ee; exact executed instrumentation/source archives are retained separately.

A independently reviewed the GDS decision/capture fences. C reviewed the fixed driver and found an archive-retention exception could mask cancellation; B repaired it and five artificial controls passed. C withdrew an earlier cwd concern after verifying the existing wrapper supplies it. These are source/pure reviews only. The separate12-minute hosted diagnostic permits a120-second import then one90-second/3072MiB game process, with bounded reports/logs. A positive result remains an applicability candidate until raw evidence and product contracts are independently examined.


### Retained-clock request 1 setup refusal and stricter observation proof

[Diagnostic run45553057659](https://github.com/techrote/cybersand/actions/runs/45553057659) executed source`f97f694f407a64b9e6577a1e0c98ae3f55e693c7`, retaining the5ee product/oracle unchanged with one separately identified diagnostic entrypoint. Fresh import passed in5.712seconds; the game stopped in4.902seconds before any gameplay action, with644489216bytes peak sampled tree RSS and no surviving owned process. Its initial2,304-cell plane exactly matched the independently specified64Sand/368wall/1,872empty authored geometry at generation3/revision3/tick0. The observation reported no actors, no authored source, a disarmed zero-emission source receipt and one pending command. The diagnostic's zero-pending-only precondition rejected that setup. The raw record did **not** identify the pending command; ordinary source code's ability to queue an inert Stop is not evidence that this particular command was Stop.

[Artifact14994352640](https://github.com/techrote/cybersand/actions/runs/45553057659/artifacts/14994352640) is2,816,450bytes, SHA-256`846d8bea66ab406466cfcf659148115a6774f10c10aab58285f0ee8864250f24`. SpecialistA's actual setup audit is`ed08590af02f28c353bc55bd200ff8e5793b2eb3`; B's independent11-check adjudication is`23f2a7c8373a41272fa9695503f3331d06f76ca3`; the complete job log is`846e0b839b1dcfc82d405671f53a34fb56feef70`. All classify the attempt as setup-unqualified with zero actions and no Save/Reopen hypothesis result.

The revised diagnostic records bounded read-only source queue and current owner receipts under the existing worker mutex at the initial, action-started and action-observed boundaries. Positive counts require exact ordinary Stop entries, fully disarmed owner state, matching phase/count/generation and unchanged paused native fences. No queue or tape is mutated, and final state is never used as proof of a historical row. Independent review caught an initial zero-count shortcut that could trust stale published disarm without checking current owner state; the final revision closes that shortcut too. All eight artificial driver controls pass; A independently re-reviewed the actual queue/owner proof. Running zero-queue observations may legitimately advance their native clocks, so the stricter proof must distinguish generation identity from frozen tick identity.

Request2 dispatch uses final diagnostic GDS blob`0d3b01ded8d674853139e6577859ef7b5c2badd8`, driver`fa36371f3a849ab26ebd11486cb9d5319975cacf` and controls`e51dcb3b03ccc5367b43b4c51c8cf81f22cb1f99`. A's final independent review is`09b1bbb21b46de2bd8e45bbc174763fbdc211b35`; C separately approved the repaired zero-count path and preserved cancellation/custody bounds. Root re-executed all eight artificial controls under a60-second/1024MiB owned process:0.303seconds,22,585,344bytes sampled peak, no survivors. CI provider and documentation checks passed. An initial root documentation command referenced a nonexistent script path; the corrected committed path passed and both command receipts remain retained. These are driver/source checks, not the still-pending native hypothesis result.


### Retained-clock request 2: all actions retained, observation race unresolved

[Run45554974942](https://github.com/techrote/cybersand/actions/runs/45554974942) executed exact instrumented source`dcf6581b952a8e5854bbbac258430521e39d121b`, tree`a769f9be44452532e07b3023594d72cb6a8f1f15`. All nine prescribed actions completed. The positive-tick control passed all fourteen experiment checks. The variant preserved evolved cells across response-mode replacement at a new generation/tick0, saved the original authored recipe, reopened that recipe and triggered exactly `authored_reopen_materials` at its fifth action. The automatic unresolved candidate exists with SHA-256`695f68ea635e7e322a95b64392de438b4e121a1db78436081b1bfb90ec0ba2a2` and exactly preserves the five-action tape. The experiment nevertheless remained unresolved and exited2: its continuous source-absence predicate did not pass.

Independent raw examination isolated one boundary out of twenty: response_mode.after recorded one pending command, while its subsequent callback's copied queue was already empty. Generation4/revision20/tick0, paused/healthy state and zero-emission receipts matched; the vanished command's contents were never observed. The strict gate correctly refused to infer that it was Stop. No retrospective pass or confirmed hypothesis is assigned to this request.

[Artifact14995746214](https://github.com/techrote/cybersand/actions/runs/45554974942/artifacts/14995746214) is2,872,743bytes, SHA-256`4cc4dd7f80c891e1c1ecf0b67af718a70ae44121bf230358e5dd34f166bd3273`, with19members/3,775,047uncompressed bytes. Import passed in4.090seconds with752,173,056bytes peak sampled tree RSS; the game stopped in12.513seconds with648,290,304bytes. Both recorded no diagnostics and no surviving owned process. A's actual boundary audit is`8d98a6d3fdd545e92bbbbd4f6533a4263577ef40`. C's independent2,825-check custody packet is`bb84370357f0798c28ff0e3eddbbe4e702eeaddd`, decoded SHA-256`7a071b66b80190884f1c0790047bb929799512c6e04d06043c06bdca2ed0068a`; it verifies974staged inputs,814archived game-source files against Git,105native and fourRapier source inputs, receipts/logs and exact automatic candidate. Full job log is`4f0bbc75afd5d56d4aa1a2767ecb792c4564de0b`.

The lead's next instrumentation candidate adds a bounded `source.queue_evidence` record inside the goblin adapter's existing worker mutex: actual count, copied commands, current source receipt, owner generation and owner paused state come from that same critical section. JSON conversion stays outside the lock; no gameplay command, native mutation or oracle change is introduced. This closes the separate-callback observation gap. It is an explicit changed adapter input, not a claim that every5ee game input remains byte-identical. The diagnostic source guard pins the exact base and approved adapter bytes plus its added entrypoint. A independently approved the ten-line additive delta in review`9b0b105ed2cefdd29c52ebff76984c2ee21e31a4`; actual source/timing identity remains distinct from qualified5ee.

Request3 freezes diagnostic`e6faec53a1e005e51dec602cb82c30a9f8868bc1`, driver`fe31ce90d03fe80ffd0be6dfdbcfc48b317b9ee6`, ten-control suite`9e9c4d48a94f789781151190d5158fea1b32652b` and the exact adapter`7f0fa3fbcab7de85350d0ca99154adc615d75cbf`. A's combined review is`5d33911ef77de0465dfc9116880cb3c857ca5d9f`; C's source-guard review is in`19b8ac00e489de6a4018a196ddf9562f7138e066`. A subsequent metadata-only correction names unchanged product/oracle **logic**, while explicitly recording the changed adapter file. No native hypothesis result is claimed before this separately instrumented source runs.

Independent acceptance review of the qualified5ee package is`557bf1f12beaec62a6b43d9960f008bbb9720b70`. It found no package custody blocker and identified two documentation corrections: the GitHub artifact's actual inner member is `CyberSand-goblin.zip`, while the locally renamed audit copy has identical bytes; the interactive reducer's240-second threshold stops new deletion-loop iterations but is not a hard overall deadline for already admitted probes. Both are corrected in the decision packet. The actual final portable catalogue contains eight raw tape files but four unique parsed tapes: three original experiments totaling256completed actions and one64-action semantic replay. Duplicate serialized copies do not create new execution evidence. C's direct catalogue audit shares packet`19b8ac00e489de6a4018a196ddf9562f7138e066`.

Final request3 metadata/source approvals are retained by A in`8ed9123a6115da9bebce4c78454867d65655a4d3` and C in`96baa822ee5e64af0abf49ff10ef941dbcd6f2f6`. Root's exact final ten artificial controls passed in0.015seconds (owned0.303seconds,22,663,168bytes peak sampled RSS, no survivors); documentation checks passed. These preparation receipts remain distinct from the forthcoming native result.


### Retained-clock request 3: independently confirmed oracle applicability defect

[Run45556434887](https://github.com/techrote/cybersand/actions/runs/45556434887) passed its separately instrumented nine-action diagnostic at`070addb0fdae2240f22e663a2299cef739f83c05`, tree`174e9dbf32a5e4014f731008461a310b3a723f37`. All20actual observation boundaries had their own valid mutex-copied queue/source evidence:19empty queues and one observed exact inert Stop at the control's initial boundary. The original callback race is not inferred away or relabelled; request2 remains unresolved.

Both actual cases completed all prescribed actions. The positive-clock control paused after17native ticks and correctly treated evolved Save/Reopen equality as inapplicable. The variant paused after16ticks, preserved the exact evolved material plane through the ordinary response replacement at generation4/tick0, then reopened the authored material recipe into generation5/tick0. It triggered only the old `authored_reopen_materials` assertion. Different actual tick counts are reported; no cross-case asynchronous trajectory equality is assumed.

B independently passed78checks and rendered the actual authored rectangles into a512-by-512material plane. Its SHA-256`acea5f8e573d757af5c560778bbd2222f96065c298e62fcfb8996817486da14a` matched both actual reopened full planes. In the isolated2,304-cell cell,64Sand cells and368walls remained conserved; Sand vertical-coordinate sums changed from736to1,794(control) and1,730(variant). The variant's saved evolved full plane had SHA-256`70fc348668c692888d972870afbae2ae349ec303375b12cdb29d06271627cdb1`. The product did what its authored-save contract requires. The independently established finding is a **test-oracle applicability defect**, not a production gameplay defect: a zero local World clock does not establish fresh authored material history.

[Artifact14995732784](https://github.com/techrote/cybersand/actions/runs/45556434887/artifacts/14995732784) is2,872,758bytes, SHA-256`2f2dc54b6c8af392364e915776cdae4f384e3dacc8f8209dc97c2a7beef25fd8`, with19members/3,682,255uncompressed bytes. Import passed in7.955seconds with752,177,152bytes peak sampled tree RSS. The game passed in17.928seconds with648,253,440bytes; all owned-process receipts report no survivors and no diagnostics. Raw report SHA-256 is`138e320b6bc8d4477e7a702abb1994c25f5357b523f27d47cda28f89e3d49221`; the113,454-byte automatic candidate is`ff835fb875d2764345f6cc28e52af74aa8b7048b2b5b35522b02394e04364d62`. That original candidate remains an unchanged unresolved automatic record; independent triage is separately recorded.

Independent review records: B adjudication`00cf2ff7900e72c7df38cf6db6945c3929014ac2` and auditor`ba8441d311516cf7995d1e2cc8ce494bd5e907de`; A atomic-source audit`d5025f1b7313951500b609313f621012cc2d3d82`; C2,942-check source/custody packet`c38779145bc4a61797df2d80ce3ba7e7d665b7f7`; complete hosted log`608d9fddd736ae39914ebe374be73f5cba197be2`. C verifies974staged inputs,814archived source files,105native and fourRapier source inputs, all7regional captures and the exact automatic candidate.

The exact original five-action tape is now committed as bounded data at`tools/gip014/cases/retained-clock-070-original.json.gz`, with separate custody metadata. Original bytes107,553, SHA-256`d2e84a85941484e5090d27c56ea5c723722fae10bc4625f3463c67afcb02c914`; deterministic gzip11,539bytes, SHA-256`d5da6299fbb1ac372296436700f95799fff724b4d101e735bdfab5b97f17f81e`. It is a compact observed failure, not an automatically minimized case. Reproducing that historical oracle requires the exact070source; the fixed before-diagnostic driver intentionally rejects a later changed adapter/oracle. Corrected applicability is qualified by a separate new-source native gate.

The corrective candidate tracks bounded material history across retaining World replacements. Positive observed native progression establishes simulation exposure, not necessarily material movement. Only a separately proved fresh authored installation/restore/reopen can re-establish authored compatibility; Reset selected retains cell history. Producer metadata and independent oracle/readback reconstruction remain separate. Four native Controller cases totaling20actions will check fresh equality, retained exposed inequality applicability, Restore start re-enabling equality, and actor Reset preserving exposure. The same fixed gate is required in the extracted Windows evaluator. At this checkpoint the corrective candidate is under implementation, not yet qualified; the earlier5ee qualification remains exact historical evidence with this subsequently identified oracle limitation.


### Corrective request9 scope and independent source review

The version3 candidate preserves fresh-authored equality but reconstructs material-history applicability from actual fixture installation, admitted actions, canonical construction receipts and native endpoints. A retaining response/actor operation cannot erase prior simulation exposure. Actor Reset is explicitly retaining; actual Restore start and Reopen are fresh constructions. The lead integrated initialization of the independent Assertions reader from the actual installed fixture and registered the new fixed native gate in both platform drivers.

Independent review found and repaired two draft proof defects before execution: stale canonical receipt bytes could not be rebound merely by relabelling an outer generation, and an exposure witness must equal a recorded positive native endpoint rather than carry an invented identity. These are corrective-candidate evidence defects caught in source/artificial controls, not discoveries of game-engine bugs. Adapter, GDS assertions and Python readback retain independent reconstruction paths.

The state projection explicitly versions the new observation contract. Absent/version1/version2 observations retain their exact historical state-v1 encoding, including its legacy phase label. Exact adapter version3 uses state-v2 with `zero_tick`, which makes no authored-history assertion. Unsupported versions produce no observed coverage. A's frozen four-file change and tests are independently reviewed by C; source review packet`f413b4c85ac4e6ad89b63314004a8027da5b10a8`, C approval`bb5c426d685a6d679f0eda49ee3750a4350beb2c`. Native GDS/Python parity remains a hosted gate, not a local claim.

Request9 selects both platforms. Linux runs every focused/source gate, the four-case20-action native lineage regression, graphical QA, the separately registered seven-episode memory experiment, then the existing eight-episode long plan: RANDOM and COVERAGE_HUNTER at128,256,512 and1024actions. The finite committed-request selector now accepts `long` alongside the previously supported `full` and `smoke`; queue and process resource bounds are unchanged. Windows runs full source and extracted-package qualification. Package contract3 requires the actual four lineage tapes, captures, independent readback, strict positive equality and justified negative applicability before sealing. Contract2 evidence remains readable without retroactive requirements. The5ee full142comparison remains a separate exact-source cohort; request9 does not rerun or relabel it.

The lead prepared a frozen descriptive cost supplement for the5ee142comparison, source blob`b05a70a4448feb4e35519a9555b60ea402bd9cfc`, SHA-256`584d523ee23ece26f86d35e6aec9ace259b0298db855035d146eac9771470e40`; A independent review`6e6a2eecae7258806beef48612da9336b603b839`. It requires the separately frozen primary analyzer's passing custody report and exact consumed-file hashes. It reports missing/latest attempts explicitly, uses only budget-complete episodes of at least128slots for positional comparisons, and compares admitted completed actions within equal action/arguments/fixture/paused strata having at least three observations in each quarter. Action time includes harness/native waiting and checkpoint I/O; neither an engine FPS claim nor causal slowdown/leak inference is supported. Four guard controls and five arithmetic/selection controls passed in bounded pure processes. No actual timing result is credited before the raw campaign is available.


Request9 integration source review is complete. B froze13owned files in manifest blob`21f1f27c18bdc00a8eaec2f6afc215b6d3a9d002`;47focused pure controls passed, and independent before/after verification of23unique legacy tapes/1,187records was byte-for-byte equivalent, preserving historical failures (review`89beb59370de2f73ed3deb8f693287f5d6ea9581`). A's final review`0ff72f4834260f9df808c8632183a6da24320aff` binds the exact helper, adapter, independent GDS/Python reader, unit controls and20-action native gate. C's custody review`53d2cada24ea42c9627a027061fb86c2a1cac677` and final native/package contract review`b12d16e31995781c153b9aa9f2d72db71a540634` independently check exact literal action dictionaries, actual Controller dispatch, marker/report fields, provenance and package acceptance.

The lead ran the combined pure integration suite once against unchanged candidate sources:130tests, one explicitly skipped GDS parity group,1.686seconds of test time and2.012seconds owned elapsed,34,205,696bytes peak sampled tree RSS, no diagnostic errors or surviving owned process. Source hashes, full log and process receipt are durable in blob`8366c62c5e4ac900005ec035aaa05680ac0220d6`. This is not native gameplay qualification. Both hosted platform drivers require the exact Godot parity group and all native gates before a new evaluator can be sealed.

C also checked13actual retained construction receipts from four unique5eeWindows tapes against the new canonical header/source binding. All13were accepted at their actual source identities; this is read-only compatibility evidence, not new gameplay. Frozen-source addendum`59216f4a0c735aae92752df2222137ee462ad502` binds that check and confirms the reviewed gate/core hashes match B's final manifest.


### Request9 native parser failure and minimal request10 repair

Request9 source`6afae9c149b48e6bbcd4a92a50c98d057c0e8067`, tree`8da586b7f06430de95dc38bbe7193927db8174c5`, [run45561928752](https://github.com/techrote/cybersand/actions/runs/45561928752), failed on both platforms before the new authored-lineage gate dispatched an action. The exact GDScript diagnostic was inability to infer the type of `all_cases` from a Dictionary property expression. Linux gate process: exit1 after0.312seconds,133,971,968bytes peak sampled tree RSS, no owned survivors and no completion marker. Windows gate: exit1 after0.313seconds. This is a test-fixture parser defect; it supplies no material-history after-case result and no production gameplay defect.

Hosted Python/GDS parity and unit, discovery, adapter, expanded, controller, laboratory, gameplay and metamorphic source groups passed. Linux also completed its baseline group after retaining the earlier failure; Windows correctly stopped before later packaging. The Linux graphical, memory and long queues were not reached. Missing episodes receive no credit. Original Linux artifact`14998227645` is28,974,336bytes, SHA-256`1222f5a348b111bac784b3c22b957c5571cdf0ad5371ef6906363ba4a02cdfa9`,152members/42,679,171expanded bytes. Original Windows artifact`14997564894` is55,513,000bytes, SHA-256`2248d88bb5bfa92b56b72000c45eb1f4594deaa073f58e1ac219d13499b3cc6f`,174members/69,322,650expanded bytes. Full Linux/Windows job logs are blobs`adebbeb1ad751be82b241cd02179b78ad7dc6b21` and`68a894a5250a9c88d8575513de88f604fee2e452`.

B changed only `var all_cases := ...` to `var all_cases: bool = ...` in the fixed test. Corrected script blob`3cd7be4fde44514532dc961f78358edffa6cb6a0`, SHA-256`3d98564b00187e9f53e1aa67507b5de6a5666ed738cb2b4a12880db966b0330a`; old script`1d28b1fa0130f1d52ebe48e3575bde3d43ec62c8`. Root and C independently checked the exact one-line delta; A's raw-source/parse-failure review`9712a4734a48de3cd2d41fb66940e57332811dad` acknowledges that source review had not caught this parser restriction. No adapter, oracle, policy, action list, report contract, runtime or package-acceptance change is made. Request10 repeats both platforms and the same8long/7memory scope. The frozen6af analysis reader remains its own pre-outcome record; a new exact-source binding will precede any request10 outcomes.

The exact6af static source/documentation/artifact identity checks passed, as did historical M11 integrity (18records/28source hashes), CI provider policy and97-workflow scheduling. Lexical retrieval returned30/32canonical hits at k,19at rank1,MRR0.7292; this is not answer correctness or gameplay evidence. Complete compressed review packet`5d3f3fa43b7e4c75d92a15088b85aa397f817bc2` is hash-verified against local bytes. Two oversized tool-output transports were rejected by their mismatching Git hashes before use; they do not substitute for the complete retained report.

Both request9 platforms passed136Python tests including actual pinned Godot cross-language parity (Linux2.270seconds, Windows3.514seconds). A independently checked172synthetic GDS exploration assertions/16policy configurations at the exact archived State and exploration-test blobs; scoped review`caebfe78854410846271ab0cd35ac6d13f8e5925`. Those controls close state-projection/parity obligations at6af, while the separate lineage parser failure keeps the overall candidate unqualified.

### Request10 actual lineage cases and request11 provenance comparator

[Run45563325767](https://github.com/techrote/cybersand/actions/runs/45563325767) at source`4050bc31526558cb99024251d29ec1183c086d6a`, tree`0bdee227e83c26a74f1dabeec79cba486a4a9ef7`, executed all four native lineage cases and20ordinary actions on both platforms. Every tape ended budget-complete with zero runtime assertion failures. Both qualification jobs nevertheless failed the same four test-local `exact_source` checks. Actual parsed provenance differs only in three integral-number representations introduced by `Transcript.create`: native source count105/105.0, Rapier count4/4.0 and nested game-source count956/956.0. Every field and value is otherwise identical. Direct Dictionary equality was the wrong test comparator; the original outcomes remain failed.

Windows native report SHA-256`c2809f0f01269f54c60164095340de302a461bbebb2d74df546be70a96af1cb6` retains20/20actions, two equal fresh-authored relationships and two unequal evolved-versus-reopened relationships. B's strict auditor passed1,087of1,094checks; its seven failed obligations preserve the original process/log/report and four-case failures. Review packet`ffce4e27f140db802438ff8b1553be0d923bad29` and C's full raw/custody packet`6bbd1271d6b7da0b4d5d12cbf24958ac8e5372e9` retain the evidence without promoting the run. The Windows process exited1 after38.141seconds, sampled553,431,040bytes peak tree RSS and left no owned survivor. Original artifact`14999251073` is55,720,644bytes, SHA-256`3d5ff4dec8d8531a0e4115089d3068a612ef0ff968498ef72429631791bd1e67`; full job log`716e38b33f947df1f42ffa65d175ce7c7b7011d8`.

Linux report SHA-256`48661825a833760b2b33e0b6df7c7e75dfde0604f2a1f1b87f4437d8d15ac6fa` independently retains the same four source-check failures with20/20completed actions and zero runtime assertion failures. Its process exited1 after23.974seconds, sampled649,887,744bytes peak tree RSS and left no owned survivor. Original artifact`14998773016` is29,181,299bytes, SHA-256`a12e900a85f61e7ea0794cd9b40e51a84a65604b5ec53a50aad0207285e3c895`,164members/44,977,230expanded bytes. Full log`4124b2738a7ebfe265f412a687496ca81ce5b281`. An expired signed download URL produced a bounded0.403-second403failure; a fresh descriptor downloaded the exact artifact in7.746seconds. Both download receipts remain, and neither is gameplay.

The reviewed test-only repair is gate blob`4bdd1f625d84dc6a0095b76768cfe861ef07014c`, SHA-256`303112825c5d9760c5293f77cc0fb207443fa57f49180afe327e1cbf1e195d56`. It compares the complete sorted canonical transcript JSON on both sides, preserving every provenance field rather than using the portable replay subset. Fourteen separately recorded artificial controls reject changed source/runtime/project/incidental values, fractional or nested counts, Boolean substitution and missing/extra fields. They add no gameplay-action credit. A independently verified the raw report and exact fix in`6aefa469508985ecb4d61dba7ce475cfbc9be6f2`; C reviewed unchanged package acceptance. Request11 repeats both platforms and the same8long/7memory scope. The runtime adapter, material-history helper, assertions, independent reader, coverage definitions and package acceptance are unchanged by this comparator repair.

### Full5ee Linux campaign completed, independent review in progress

The separate5ee [run45550152509](https://github.com/techrote/cybersand/actions/runs/45550152509) completed its Linux queue at07:01UTC. Its runner reports142observed episodes/142retained attempts,139budget completions and three retained failures. Overall qualification remains failed. Artifact`15000115723` is75,777,228bytes, SHA-256`e4548f77291076ea289ec90415789ef24eb1944dff349bc1d73d7f2755e63170`,2,235members/704,194,137expanded bytes, independently downloaded with exact digest/CRC/path checks. Full hosted log`56e1c12e829f68252593a6bf6c961614b7b89677` is retained. A is executing the frozen coverage/memory analysis, B is adjudicating the three actual failures, and C is auditing source and process custody. The lead's frozen position-cost supplement waits for the primary reader's exact passing custody result. No fresh coverage or performance total is claimed at this preliminary checkpoint.


### Exact5ee full matrix, memory experiment and independent adjudication

The raw5ee Linux artifact has now completed independent analysis. A's frozen primary reader validated all142tapes and recomputed coverage from1,138consumed file hashes; actual analysis SHA-256`49de3782a724baba68284cf9f934518efe58b5bc2d1ed45ac15cfd160269d28c`, exact queue SHA-256`41ff6d67e9366674d741fcd73ff71303ec635ca68d8ca58525265783738a307a`. The reader ran as data-only Python for13.409seconds, sampled157,270,016bytes peak tree RSS and left no owned process. It did not rerun or relabel gameplay.

All142episodes were attempted and retained:139budget-complete,11,554attempted actions,11,538completed,16expected refusals and zero partial actions or failed gameplay assertions. All108matched64episodes completed(6,912attempts/6,909completed); all16personality episodes completed(1,024/1,022); allten scenario episodes completed(640/640). Five of eight long episodes completed(2,978attempted/2,967completed across all eight). Deduplicated observed unions are53action IDs,975adjacent transitions,5,889state transitions,96material keys,69tool/material keys,127actor/environment keys, eight lifecycle keys, three refusal keys and77outcomes. No map saturated. These unions include valid partial long tapes and never impute missing suffixes.

A's compact source-bound comparison SHA-256`8b8f78acafff0b8dd9d560914af9941720d2c006417807e990836cf4f499f929` retains all nine12-episode policy rows, spreads and three focal paired contrasts. Every comparison has12complete initial-fixture/seed blocks. Coverage Hunter minus Random has paired medians+1action ID,0adjacent transitions,0state transitions,−4material keys,+1tool/material key. Coverage Hunter minus Novelty has+3/+1/0/−3/−2; Novelty minus Random has−1/+2/0/+3/+3. A median of paired differences is not the difference between group medians. Coverage Hunter's material difference is negative against Novelty in all12blocks(−7..−1), and never positive against Random(−7..0). Curiosity has the largest per-episode median action-ID count35in this cohort. No general policy winner, reaction-discovery benefit or cross-episode learning claim follows.

State-v1 includes observed Undo/Redo availability, selected tool/material/brush, selection/clipboard, authored-save presence, actor modes/capabilities/coarse zones, camera/UI, coarse native phase/source and admitted regional material samples. It does not concatenate a recent-action window. A state-transition key combines before/after projections with action ID and completion status. Counts reaching64in a64-row episode are opportunity-limited and do not establish64physically distinct Worlds or increased defect yield. Later fixture replacement is ordinary policy behaviour, so only the initial authored starts are matched. All142matrix profiles start with fresh memory.

B's166-check completed-action ledger independently hashes all142campaign tapes plus the focused reports. The matrix's two missing completed IDs are `actor_trigger` and `preview_cancel`. Both complete with accepted admission in the expanded native group: preview_cancel ends an actual drag through the ordinary Cancel button; actor_trigger is delivered through the human Runner and its equipment receipt records accepted/consumed/applied with five changed native cells. The expanded86attempts/83completed actions contain completed instances of every29new ID; its three expected refusals do not erase those distinct positive instances. Matrix plus focused evidence therefore covers all55completed contracts at exact5ee, with no nominal-only ID credit. Per-ID path/hash/row evidence and parameter exclusions are retained in`debabd50e4d2110481791d57166fa64e1faf2dc7`; these focused rows are not added to matrix counts or substituted for later6fqualification.

The three retained long failures are bounded campaign attrition. RANDOM512has466attempts/464completed and active616.431seconds against614.4configured, outer622.944seconds against674. RANDOM1024has570/568 and active901.918seconds against900, outer909.517against960. COVERAGE_HUNTER1024has662/660 and active902.175against900, outer908.820against960. Decision-boundary active checks allow a currently admitted bounded operation to finish; every outer process cap is respected. Each has a terminal marker, no pending action, no assertion/native failure, and no surviving owned process. B passed62deadline/source/readback checks in`666c5b94bfce2412abb1d66728631080b652f406`; the original failed runner results and unresolved automatic classifications remain intact. A review-only assumption that configured0ms pacing implies measured0ms overhead was corrected, and the failed review attempt was retained.

C's exact5ee custody packet`9b366a385c45bcfa33c8948c80bc6bf6f16bab93` passed20,696checks over169process receipts and ten archived game-source snapshots. All observed owned trees had no survivor. The142game processes cost6,693.686aggregate seconds, maximum848,502,784bytes sampled tree RSS; queue6,733.147seconds stayed within7,200. The actual4-action controller and24-action graphical semantic replays pass while exact asynchronous equality remains separately false. The existing legal4→1reduction retains six fresh probes4,4,2,2,1,1; it remains a legal outcome, not a discovered defect.

The separate7episode memory experiment at5ee passed all448actual admitted/completed actions. Its read-only analysis SHA-256 is`07d5477506d0c28e9738c3ce35843e6e43b34c2124ea9ee25c72f56259ba1904`. Control64cultivation supplies an unchanged corpus; seeds65and129 compare fresh, hints-only and explicit-prefix Coverage Hunter64. Both hint-only runs choose a different first action at equal initial abstract state and matching paused native identity. Both prefix runs propose the exact four retained actions and independently reproduce64Empty→58cell edits. Hints versus fresh change action coverage−2/+3and material0/−2; prefix versus fresh changes action−2/+2and material−1/0. Imported history contributes zero fresh coverage. The measured mechanism works, but one corpus/two paired seeds do not establish an advantage. Cultivation20.315seconds; all seven game processes177.241seconds; supervisor188.633seconds, peak780,333,056bytes, no survivor.

The preregistered one-episode/seed605personality readout distinguishes actual interactions: Builder20rectangles; Tinkerer28history-family operations; Disaster Artist23rectangles/four reservoir-breach-repair intentions begun; Actor Enthusiast29actor+35simulation; Impatient14UI+17actor operations. History Goblin and Obsessive Reproducer both perform40history-family operations, but goals refer to five versus two repeated experiment locations. Counts of goal text are not counts of spatial edits. Alchemist performs no completed history-family operation and skips eight unavailable intention steps; no chemical-reaction success is inferred. These are observed signatures at one seed, not proof of human recognizability or broad reliability.

### Preregistered positional cost result and independent source-boundary review

The lead's frozen cost reader ran once against the passing exact primary custody result:6.273seconds,152,465,408bytes peak sampled tree RSS, no survivor. Full output503,810bytes, SHA-256`60d669a5fc311e482f8bfa3800dafe15df9736aa300f4cd0e6b947d7e228874d`, binds142records and286input hashes with no missing record. The five budget-complete long episodes have all-action late/early quartile median ratios2.473,3.390,4.736,7.324and6.042. **Zero** exact action/arguments/current-fixture/pause strata meet the preregistered minimum of three observations in each quarter. The adjusted comparison remains empty; the rule was not relaxed after seeing results. Three budget-incomplete episodes are retained for resource accounting and excluded from positional comparison.

Complete source/output/process/summary packet`84bc5ddb3f09cc75743d62db4b868c31b3ef43a7` is66,755bytes encoded, SHA-256`45096aa681d881bcc7a5a741b574b0f29394ba5cfde3adaa0ab68943457da036`,566,694decoded bytes. A draft summary accidentally included separate editor import in the process denominator; source review corrected that wording before publication. C independently recomputed898checks in`5f63438f0b01639a2bd2f59f3330a0beec4175d1`, including286input hashes, all eight process denominators and the five quartile/stratum calculations. Process elapsed begins before Popen and includes game initialization, teardown and monitor cleanup/log hashing; it excludes separate import, prelaunch profile preparation and postprocess reader/coverage/result writing. Adapter row duration includes admission checkpoint serialization/I/O and native waits, then stops before controller assertions, append, coverage and completed-snapshot work. Changing action/environment mixtures remain uncontrolled. No engine FPS, causal component slowdown, leak or statistical-significance conclusion is supported.

### Request11 exact source and preservation checkpoint

Request11 source`6f359ce2b24291ee219810773c641d53802fd31d`, tree`a4f389cd3cc1a21dfe3d5566703eb946b66734ed`, [run45565621408](https://github.com/techrote/cybersand/actions/runs/45565621408), is separately qualifying the reviewed material-history correction and repaired test comparator. Linux owns the focused and graphical gates followed by the registered eight-long/seven-memory programme. Windows owns the source and extracted-evaluator gates, including the same four native lineage cases. A froze its distinct reader before outcomes: source blob`fe0b8a5c522f3495dfdf7d9f43690c07d73a60d2`, preparation envelope`c6cc7d548263b3bd38db2d8ce6beeceeeefe6d13`; all24reader-file bytes and metric code are unchanged from the earlier binding, ten pure controls pass. Earlier9/10readers and failures remain. Linux4050's strict after-audit also confirms1,087of1,094checks pass with only original failed process/report/four-case status obligations,20completed actions and all independent material/lineage relationships preserved; full review`48fcff66a32f4e5060d9769f887bb0bfb183390a` and process receipt`e247a98961d2efc785ee8085847268a599123675` retain that failed outcome.

At07:10UTC the lead refreshed main to unchanged`00cdb02f103265b6dc5224c68283e9a0c8cb449f` and inspected current open programme heads, including AMBIENT779, Art780/782, Strata776, Materials768, Gentek758andObjectShard754. No branch or native implementation was imported or modified. Optional capability families remain disabled until a separately qualified adapter is compiled.

C assembled the already retained predecessor evidence without new execution/download: six original raw tapes with recovery-matching hashes and all seven qualification/profile/log records, retaining five completions/two unattributed SIGKILLs/988observed actions. The missing seventh tape stays unknown. Passive bundle1,343,584bytes, SHA-256`75b4f7832ea91718f252a42cd023af27c2e8dfe7487f8eed7f7e93eae68df4cc`,59members/21,539,771expanded bytes. The original predecessor Windows evaluator remains linked at its original artifact; this bundle does not pretend to contain it. Final durable evidence retains original successor ZIPs, full frozen reader closures and complete independent outputs rather than relying solely on unreferenced Git blobs.


A's complete independent evidence is now durable in binary Gitblob`b8ad23fb9ca847650a89f5a1346cb930c25a37c1`:1,566,720bytes of XZ-compressed versioned ZIP, SHA-256`262f5bd5190809fa97ed1190a4bcf5f7fb93e6119d7b29e24f16d5e236dd0beb`. The contained2,062,035-byte archive has SHA-256`3c54d0a1afbf1af48f93bead0b159bed18c97ded918e06507100db73bf5613f4`,228payload files and manifest`183fb52fe4262894ba715c47818528280f89d7964b4ee43ab55dd610e323a883`. It includes six frozen source closures, complete historical/5eeprimary/memory outputs, executed analyzers, preregistered personality controls and actual reviews. Owner readout`b6b6be2db0ea7ca68b47658d3c3da4bb3688b55c` is separately readable. C includes the actual passive ZIP in the durable archive;11outcomes will be a separate subsequent packet, never an overwrite of prior records.

B independently approved the decision packet's actual comparison/deadline/capability section in`0007dcf2eccbe08bd277294c20d5048285c6b0ca`. All16matrix refusals were inspected:11bounded Fill, four body-protected captures and one out-of-view geometry. Each was preadmission with native and authored identities unchanged; inventory`88ff75e1ff2aaedf90d26958b9b11c008184a36f`. A reviewed the numeric tables and corrected two prose ambiguities: zero partial action statuses do not prove the absence of every incidental physical effect, and material-interaction key differences are not changed-cell counts. A separately recomputed the actual timing output at286input hashes/142records/five eligible long episodes, with zero eligible adjusted strata among566candidate strata; review SHA-256`0153353cd87e971429307b401004316e8c6bae9c464679587622fea711061a48`.


### Corrected Windows evaluator qualified and independently accepted

Request 11 Windows job `139039653335` completed successfully at exact source
`6f359ce2b24291ee219810773c641d53802fd31d`, tree
`a4f389cd3cc1a21dfe3d5566703eb946b66734ed`. Qualified artifact
`15001055330` is 95,315,154 bytes, SHA-256
`edfa20c4d6aca64d32396139642db7bee3f70ff7d54e536ac616a4043b7ca7d6`.
Its sealed inner evaluator is 95,816,253 bytes, SHA-256
`daca112474286798950977909b1be000cd5b75657b231c028d366515836cdc4e`.
Original Windows evidence artifact `15000825524` is 201,496,963 bytes,
SHA-256 `75c3e351e1c9459516c6708508adfdd2b669dc916d40af459c040fdacee67314`.
The complete job log is `764c58279208261200db2dbe052262e19b112c30`.

The actual source passed 136 Python controls in 3.266 seconds, including hosted
GDS parity. The expanded native group passed 2,030 gate checks over 86 action
rows: 83 completed and three expected refusals. All 29 added IDs have completed
observations. B's 731-check action/origin review found a completed union of all
55 operation IDs across the source groups and six representative source tapes,
including ordinary preview cancellation, acknowledged actor equipment use and
reset_fixture at Coverage Hunter row 23. These observations are separate from
the 5ee comparative matrix's 53-ID union.

The four native material-lineage cases completed 20 actions in source and 20
more in the extracted evaluator. B's independent source audit passed 1,094
checks; its extracted audit passed 273, including independently rendered
authored planes, current source/receipt fences, latest progression witnesses,
immutable Save proof and both positive/negative equality relationships.
Complete review manifest `621448b4456b77c0acab8a7eeb88b627a9561f12` binds these
results and the current action review. Earlier parser/comparator failures remain
failed records; this result does not relabel them or establish a production bug.

C's full package/source/custody audit passed 3,995 checks over 1,243 payload files,
24 supplements and 38 observed process receipts, all without owned survivors.
The inherited-environment PowerShell probe remains an expected failed control;
the cleaned child environment passed. The extracted wrapper used 261.094 seconds
and peaked at 993,378,304 sampled tree-RSS bytes. Three fresh extracted campaigns
completed 192/192 actions, and the separate 64-action semantic replay passed
while exact asynchronous observation equality was false. Graphical qualification
passed 36 checks. The lead inspected all three actual 1600-by-900 PNGs individually:
the Workbench construction, animated pointer and readable, scrollable Play,
Discovery and Memory controls are visible. No physical NVIDIA acceptance follows.

The first local attempt to dispatch C's read-only audit lost its tool connection
before any audit process/result was observed. A minimal read-only host check
confirmed the files remained. The lead then ran the exact frozen reader once:
5.432 seconds, 80,896,000 sampled RSS bytes and no owned survivor. Full packet
`6dadaa33179ce4bb665daf7be7a5a1988f0ce0cf` retains the transport failure, successful
audit, unchanged reader, actual outputs and recovery receipt separately. It is
48,083 bytes encoded, SHA-256
`abbd83e7c5223af22f4f4bc15fe21d970d24f22867b9456124068f2bdef8cba1`.

A independently verified the exact archived GDS and frozen Python reader bytes,
172 synthetic exploration controls/16 policies, actual Python/GDS parity and all
nine recomputed coverage counts from the four actual native lineage tapes.
All 40 adapter-v3 endpoints use State-v2: 28 zero-tick and 12 early. These state
categories do not infer authorship or add nominal material coverage. Packet
`a4368dca6478402432c08e7c5fe1982df1afa5e1` includes 15 actual review files. The
temporary parity-driver log is retained by its recorded digest/receipt, not
claimed as a saved set of raw vectors. A's separate decision/index snapshot
review `d288c46a5614f3a589e37bc84714fabe414ad737` found no numerical or source-scope
blocker; its initial presentation-parser failure is retained. The lead clarified
that Linux owns long8/memory7 while Windows owns source/extracted qualification.

The corrected primary owner download was replaced only after root visual review,
B's extracted material-contract signoff and C's full custody pass. Its bytes were
verified again against the exact sealed ZIP; the earlier qualified version remains
historical evidence. The new portable sample contains eight raw serializations
of four parsed tapes: three originals with 199/199 completed actions plus one
64/64 semantic replay, totaling 263 rows without duplicate execution credit.
The seven-action original is the actual actor-reset lineage case.

General documentation CI run `45565629200`, job `139039584949`, completed
successfully at the same source, including workflow policy, source-derived
contracts, material catalogue parity, documentation and retrieval checks.
Its dependency-provenance step was skipped; skipped gates receive no pass credit.
Linux request 11 remains running at this checkpoint. Its eight long and seven
memory episodes will retain their own source-bound outcomes, independent of both
this Windows pass and the earlier full142 comparison. C's frozen Linux custody
reader SHA-256 is
`80c3d813938a38b9028db0ed7c0e77494b466ac2f0e25b682ab60f6fe4d63745`;
the lead independently reviewed its six exact binding/label/count changes from
the already used 5ee reader before outcomes. Acceptance rules are unchanged.


### Baseline decision-procedure ancestry and comparison scope

The lead challenged why Curiosity's matched median reaches 35 action IDs when
its predecessor supported only 26. A independently compared nine exact source
inputs and 12 function texts. Closing66ee and foundationd448 policy files are
byte-identical; current5ee and corrected6f policy files are also byte-identical.
The five legacy goal bodies, helpers/preconditions/state key and RANDOM's uniform
legal-menu draw preserve the predecessor procedures. The successor's common menu
adds 29 contracts, expands palette choices from five to18, actor model choices
from two to six and bounded logical IDs from eight to64. Its reference-barrel
menu placement also changes from288,128 to256,96. Curiosity's already adaptive
8×action+3×pair+5×from-state scoring can select any offered candidate through its
existing general arm. RANDOM samples actual menu entries, not uniform action IDs.

The exact comparison is preserved predecessor decision procedures against new
strategies on one common expanded successor interface. The four scripted baseline
recipes retain their original palette and waypoints, while admission/observations
and generic fallback use that interface. No matched original26-menu or unchanged
predecessor-executable cohort was executed. The comparison remains useful at
exact5ee but cannot establish an engine-version or original-action-universe
performance improvement. The decision packet and machine index state this scope.

Full14-file source/diff/review/receipt packet
`3a3746110cfc3246d310bc24b668ccdd488741dd` preserves297,154decoded bytes;
envelope SHA-256
`499d46e9d1db2a6f43801252e30a3f9634bf1ce5f54f01ee3c9f07eac82c9ca3`.
The review ran0.202seconds with12,570,624sampled RSS bytes and no survivor.
It executed no policy, game, replay or new experiment. Campaign metrics are unchanged.

### Local preservation interruption and independent hosted continuation

After corrected Windows delivery, the local execution environment became
unavailable during one bounded predecessor-evidence download. The launched
process had300-second,512-MiB sampled-tree and16-MiB-log limits. The tool connection
failed before its final receipt was observed; completion and survivors remain
unknown. The lead's single minimal read-only probe confirmed that no usable
execution environment was available. No cause is inferred and the download is
not credited as successful. The interruption/actual metadata record is
`79c047f717a6760912ae056c898c6e9239488037`; it contains no signed URL.

The original predecessor run45474099351 remains independently successful at
source`3e3aa217b49036ac4a87dd57073ad2cbb5a314c8`,
tree`3ee2a02e13cde1a1a4ff67321cb7c3d6f9bd1e37`.
Its original qualified artifact14958249728 is92,570,931bytes, SHA-256
`3d75ea0add4bb5a690c6c46c021f09f35b8e88e007c87df3107ac6b4a49a5fe3`;
raw Windows evidence14959436637 is53,552,174bytes, SHA-256
`c7ff1cda1e08750cd884d5b33dc324b7329594394a8d1569d4527479ace51952`.
Those are verified remote artifact identities, not a completed local download.

The qualified current Windows download and committed results remain available.
The independently bounded GitHub Linux11 job continues at its original6f source.
All specialist review closures and latest handovers were already preserved as
exact Git blobs. The team is preparing a bounded passive hosted analysis and
consolidation path using the frozen readers, exact artifact catalogue and
read-only repository permissions. That fallback has not yet been launched at
this checkpoint. It adds no gameplay execution, changes no acceptance rule and
will retain failed/incomplete observations. Creating the final downloadable
evidence archive through the file service still requires a supported executor;
private upload credentials will not be transferred to a hosted workflow.

## Passive hosted evidence recovery after local executor loss

The local executor became unavailable while the bounded predecessor download was in progress. Its completion and surviving-owned-process outcome remain unknown; no host recovery or global process audit is claimed. The qualified Windows download was already sealed, verified and delivered, and the separately hosted Linux campaign continued independently.

A separate passive workflow restores exact frozen independent readers and downloads a closed catalogue of thirteen original GitHub artifacts, totaling 661,216,192 compressed bytes. It binds artifact, workflow, source, size and SHA-256 identities, preserves original failed outcomes, uses no native/editor/game process, and keeps its driver checkout separate from the qualified game source 6f359ce2b24291ee219810773c641d53802fd31d / tree a4f389cd3cc1a21dfe3d5566703eb946b66734ed. The historical reducer's workflow driver702 and executed game sourced849 remain distinct.

The lead, A and B reviewed the driver before activation. The review corrected lexical parent traversal, file/directory alias handling, report overwrite checks, live resource-scan rename races, bytecode contamination of the clean source checkout, and dict/null handling in the bounded summary projection. Authenticated GitHub metadata requests cannot redirect; artifact storage requests are fresh unauthenticated requests to the constrained official storage host. Reader subprocesses receive a small environment without Actions or upload credentials. Complete outputs and failures are retained separately from the bounded log projections. These are passive recovery-tool corrections, not production gameplay findings.

The workflow has fixed Python commands, per-reader memory/log/wall bounds, a 1,800-second monitored worker bound, an outer alarm, a sampled four-GiB output bound and a two-GiB free-space reserve. It uploads only explicit disposable evidence/review/supervision roots. A passing reader validates retained evidence; it cannot change an original incomplete campaign into a completed one. The new driver does not rerun gameplay or modify the frozen expected-result readers.

Sealing is deliberately separate from analysis: after actual outputs are adjudicated and the RESULTS documentation commit is published, a second passive phase will restore the exact staging artifact, snapshot those exact documents and use the unchanged reviewed archive builder. The final archive hash will be recorded by a later delivery commit to avoid a circular hash dependency.

The six predecessor Linux raw tape bodies previously read from the workspace are not present in any durably recovered archive currently available to this execution. Their exact recorded hashes and recovery summaries survive. The passive catalogue preserves the actual predecessor Windows artifacts; it does not manufacture Linux tape bodies or substitute Windows evidence for them. The interrupted predecessor transfer remains an infrastructure observation with unknown process outcome.

Frozen driver blob: `6b9c3e327437f5426776da78abef02ef62636212`. A's source review is `539e9328a5fac3fb3b3b5085d4c1f75d5b7f89e5`; B independently cleared the same final files and the root's activation, run-isolated concurrency and historical-source metadata edits. This commit registers the passive attempt; it contains no successful-execution claim. The last repository refresh found main `00cdb02f103265b6dc5224c68283e9a0c8cb449f` unchanged and PR #781 still open/Draft.

B's durable source review is `6037bc1c388b56f6430d1bd4e7ac2c00080d1733` (seventeen explicit checks). Both independent source-review records are committed under `tools/gip014/evidence/passive/`. These are reviews of the recovery source and closed inputs, not raw campaign adjudications.

## Corrected-source Linux actual results and passive recovery closure

The Linux job at the qualified game source `6f359ce2b24291ee219810773c641d53802fd31d`
has finished. [Original run 45565621408](https://github.com/techrote/cybersand/actions/runs/45565621408),
job `139039653373`, remains **failed** because four requested long budgets were
incomplete. Its [raw artifact 15003384515](https://github.com/techrote/cybersand/actions/runs/45565621408/artifacts/15003384515)
contains 432 files, is 50,241,858 bytes and has SHA-256
`c5ab54aa45062bf12912e29743058019bc1db38ae59c0a4b234172d6b371fe6e`.
Independent analysis validates all eight tapes and their observed coverage; it
does not change the original campaign outcomes.

The registered long programme used the Construction initial fixture, seed 1701,
RANDOM and COVERAGE_HUNTER, and four requested horizons. It is a separate
eight-episode programme, with one observation per policy/budget and no replicated
uncertainty estimate. Ordinary world replacement subsequently visited other
authored fixtures and remains part of each recorded strategy.

| Policy | Requested slots | Attempted | Completed | Refused | Original terminal | Process seconds | Peak sampled RSS (MiB) |
| --- | ---: | ---: | ---: | ---: | --- | ---: | ---: |
| Coverage Hunter | 128 | 128 | 128 | 0 | budget_complete | 57.475 | 570.6 |
| Seeded random | 128 | 128 | 128 | 0 | budget_complete | 82.765 | 584.5 |
| Coverage Hunter | 256 | 256 | 255 | 1 | budget_complete | 191.335 | 627.1 |
| Seeded random | 256 | 256 | 254 | 2 | budget_complete | 258.265 | 662.8 |
| Coverage Hunter | 512 | 501 | 499 | 2 | campaign_timeout | 622.547 | 742.5 |
| Seeded random | 512 | 436 | 434 | 2 | campaign_timeout | 622.892 | 765.5 |
| Coverage Hunter | 1,024 | 616 | 614 | 2 | campaign_timeout | 909.762 | 787.0 |
| Seeded random | 1,024 | 537 | 535 | 2 | campaign_timeout | 909.588 | 841.0 |

Of 3,840 planned attempt slots, 2,858 actions were attempted, **2,847 were
admitted and completed**, and eleven were refused. There were no admitted
partial actions, no failed gameplay assertions and no retained pending action.
Both policies completed 128 and 256 requested slots. Neither policy completed
512 or 1,024 slots at this source. The four incomplete tapes retain
`campaign_timeout`, their `test_failure` process status and their original
`unresolved_observation` triage label. Each process exited normally with code 1
within its 674- or 960-second external bound; this is not an external process
kill or an established gameplay defect. The transported reports do not expose
the complete decision-pause/pacing subtraction or final native pause, so the
historical exact active-clock audit is not silently reused for these episodes.

The eight gameplay processes consumed 3,654.629 recorded process seconds in
total. The queue took 3,659.166 seconds against its 7,200-second bound; its import
took a separately recorded 6.573 seconds. Maximum sampled gameplay-process tree
RSS was 881,831,936 bytes. These are process costs and sampled peaks, not engine
FPS, a memory-leak proof or a continuous allocation curve.

The deduplicated State-v2 observed unions are **51 action IDs, 593 adjacent
action transitions, 1,129 state transitions, 43 material interactions, 46
tool/material combinations, 62 actor/environment combinations, eight lifecycle
keys, one refusal key and 66 outcome keys**. None of these episode maps saturated.
The numbers describe admitted observations and include the valid incomplete
episodes. They are not a fraction of all possible gameplay. They remain separate
from the State-v1 `5ee5dffc` comparative results above; the source, horizon mix and
state namespaces differ.

### Memory reuse at the corrected source

The independent seven-episode memory experiment completed **448 of 448 actions**:
one cultivation episode and fresh, hints-only and explicit-prefix arms for seeds
65 and 129. Both prefix arms queued and proposed the same four retained actions:
Pause, a bounded camera choice, material 58, and the 8 by 8 rectangle at
coordinates 32 through 39. Each arm's native capture proves exactly 64 changed
cells and the expected before/after material planes. The imported observations
were not counted as fresh coverage.

Hints changed the first action in both seed pairs while the recorded initial
abstract state and paused native generation/revision/tick were equal. The
descriptive coverage changes remained mixed:

| Comparison to fresh | Seed | Distinct action difference | Adjacent transition difference | Material interaction difference | Tool/material difference |
| --- | ---: | ---: | ---: | ---: | ---: |
| Hints only | 65 | -2 | -2 | 0 | -1 |
| Hints only | 129 | +3 | -1 | -2 | +1 |
| Explicit prefix | 65 | -2 | -3 | -1 | -4 |
| Explicit prefix | 129 | +1 | +1 | 0 | 0 |

Cultivation took 21.496 process seconds; training-inclusive gameplay cost was
188.301 seconds. The memory supervisor took 199.883 seconds and peaked at
780,529,664 sampled tree-RSS bytes. Two measured seeds and one corpus demonstrate
working persistence and actual prefix reuse; they do not establish a general
search advantage.

### Independent native and delivery checks

The unchanged lineage auditor passed all **1,094 checks** against four Linux
cases and twenty admitted, completed actions. Fresh-authored and Restore cases
equal the independently rendered authored material plane. Retaining response
replacement and selected-actor Reset preserve actual simulation exposure; their
saved live planes differ, while Reopen returns the authored plane and equality
is correctly inapplicable. Different evolved hashes across Windows and Linux do
not invalidate this relation or establish identical asynchronous trajectories.

The frozen custody auditor passed **18,667 checks** with no errors, covering
eleven focused source archives with the same 816-file closure and 37 owned
process receipts. Those receipts retain the four failed long processes; they
are not 37 successful gameplay tests. No surviving owned PID was recorded.
The graphical gate retains 36 checks and actual 1600 by 900 llvmpipe evidence,
without physical-owner or NVIDIA acceptance. Controller 4-action and graphical
24-action replay pairs matched semantically while exact observations differed.
The laboratory also performed a legal 4-to-1 reduction through six fresh probes
(4, 4, 2, 2, 1, 1 actions), then exported a passing ordinary unittest case. This
legal semantic control is separate from the historical 44-to-1 oracle-defect case.

### Preservation after the local executor interruption

The qualified Windows download was completed before the local executor became
unavailable. A separately reviewed passive recovery workflow subsequently
verified **all thirteen original artifacts**, totaling 661,216,192 compressed
bytes, and ran the exact frozen data readers without launching the game.
[Passive run 45579669046](https://github.com/techrote/cybersand/actions/runs/45579669046)
used driver `2a627a3131be72fcb876acec0d0b848a7e42c3e3`, distinct from game source
`6f359ce2b24291ee219810773c641d53802fd31d`. Its worker took 31.765 seconds,
peaked at 229,445,632 sampled tree-RSS bytes and recorded no surviving owned PID.

The complete [passive stage artifact 15005776720](https://github.com/techrote/cybersand/actions/runs/45579669046/artifacts/15005776720)
is 942,877,571 bytes with SHA-256
`8621cf2811e14fdda3e98749f84b7d0887228f0c64b91967ae67485627552da9`.
It retains the original inputs, exact readers, complete reports, process
receipts and failure history. The primary analysis is 1,040,902 bytes
(`c32ab2dcbd84f969a8dff36c9e0b31122a0e7664e70516d7fc0334d9046306dd`);
the memory report is 123,204 bytes
(`6d60a463843c99ba3eb1cb30596ed7d0085f5314de77f1fb4e4df9dfdc565ccb`).
The lineage and custody reports and their hashes are in the machine index.
Decoded log projections are clearly distinguished from original report bytes.

At the pre-seal RESULTS checkpoint, the six predecessor Linux raw tape bodies
were unavailable after the executor interruption. Their exact metadata survived.
After sealing, all six selected native bodies were recovered at their original
byte/hash identities and saved in a separate supplement, as recorded in
the final delivery and late predecessor custody section below.
The sealed RESULTS snapshot remains unchanged. Windows bytes were never treated
as substitutes for those Linux tapes. Completion and process-survivor status of
the interrupted local predecessor download remain unknown; later receipts
describe only their own owned processes.

This was the pre-seal RESULTS checkpoint. The sealed archive contains that exact
`e8df89b48757096428ee6a9d12e55c7e417c10d5` documentation snapshot. The final
delivery entry below records actual archive identity, later recovery and
transfer limitations without changing historical gameplay outcomes.

Two substantive test-oracle defects were established. The Monowheel oracle incorrectly equated the authored assembly origin with the offset physical root; independent native reproduction preserved that wrong expectation and automatically reduced a retained 44-action tape to one action. The persistence oracle incorrectly treated a reset native tick as proof that live materials still matched the authored layout. Its five-action retained-clock counterexample was automatically captured and independently verified, but was not automatically minimized. The corrected checks follow the pinned actor-part geometry and observed material lineage, with fresh-authored equality checks retained. No novel production gameplay defect was confirmed. Test-fixture setup, parser declarations, numeric provenance comparison and other harness repairs are recorded separately from these two oracle findings. Original failed, unresolved and incomplete attempts retain their original statuses; later corrections do not retroactively turn them into passes.

The final actual-result readout packets are A `2cc2e185e1654bb2701224e5fdb459457c653eab`, B `097ac6bd740192173792c0d5cfc61bf4a2ae4394` and C `e809acb4dbfdeace11f64bce60ee749a9bed9a57`. Their updated complete handovers are committed alongside this RESULTS checkpoint. A's twenty-five output consistency checks do not add gameplay executions. The existing exact frozen readers consumed the raw evidence in the successful passive run, with full reports retained in its stage.


## Final passive seal and late predecessor custody closure

The final archive was actually sealed by run 45582958798 / job 139097304609 at
driver f3324f462091d1778b9472ebcafbab35372e6411. It preserves the exact e8df89b4
RESULTS snapshot and retains the thirteen unchanged original artifact ZIPs,
fourteen review inputs, evidence index and README. The 29-member inner
CyberSand-goblin-campaign-evidence.zip is 666,742,658 bytes,
SHA-256 0bf98d07e9375c61eaf77869d560b2b9eca08604ed1493a69dab52cbf376f84f.
The separate artifact 15008615196 wrapper is 666,742,848 bytes,
SHA-256 104e680cf4e85f445a549886a0b847efac288e9e30535e508c5ef2ac67e2bbce.
Every member was rehashed after write. The 2.357-second builder and 30.148-second
outer supervisor passed with no observed surviving owned PID. This packaging
executed no game, reran no reader and downloaded none of the original 13
artifact endpoints again.

The executor later returned. Specialist A read six exact selected native
predecessor tape bodies from the surviving old workspace; all six byte sizes
and SHA-256 values matched the unchanged original recovery metadata. Five
compact aliases also matched, for eleven paths total. The six pretty runner
serializations were not reverified. The selected bodies total 20,516,496 bytes.
The old 1,343,584-byte 75b4f783 ZIP was not located in the two scoped search
directories, so a clearly NEW supplementary archive was made instead.
The sealed evidence archive was not modified.

Historical outcome accounting remains unchanged: five completed predecessor
processes, two unattributed -9 interruptions, 988 observed completed actions,
and no tape or inferred action count for Random a01. This is passive byte
preservation, not another gameplay execution or resolution of an old process
outcome. The original local transfer interruption record retains its unknown
completion/survivor status.

The qualified Windows evaluator remains saved and unchanged. The new
predecessor-six-tapes-recovery-v1.zip was saved as a direct owner download:
960,187 bytes, SHA-256
c34a9f0e1d520c6a45f6bff7073cd2c54e11ea28425ef755ce8f2b2ce6840f74.
A verified all original body hashes and reopened member hashes/CRC; B passed
13 metadata/custody checks; C and the lead independently rehashed the completed
ZIP and checked its inventory. C's bounded save took 8.056 seconds, peaked at
53,104,640 sampled tree-RSS bytes and recorded no surviving owned PID.

The large sealed archive remains downloadable from GitHub artifact 15008615196,
currently expiring 2026-12-25 09:12:25 UTC. A second direct copy was blocked
before download by the connector's 536,870,912-byte limit and the workspace's
observed 69,832,704 free bytes. No retry, alternate transfer, split, repackaging
or deletion of existing evidence was performed. That limitation is retained,
not relabelled as a successful direct save.

Final review records: A RESULTS b946696c686598936f43f176312923e084851b73,
B seal binding e8981dff499a2a836d712ba7b2b2eca4f33e70c9,
C actual seal 71d44072202b6be2bfc5367d3e0d9ce4c4aba1af,
lead actual seal e071192947400c93c6af7329232e6237b06d887f,
A recovery ba46c0d4fcde350923ee796aa9bd691e1b58e75c,
B recovery a7273bfcdd601940e273ee094317052d594afd58,
lead supplement dd8ec240e2f54bc0cedf36361ad6ff4ee02e5f19 and
C final delivery 86e1dc88d8863e5d69fa2d73bf1addf7a9e5f31e.
The actual seal job log is 4a1102beef673b8fbd6f6229f0ec2b80a712e132.
The committed final delivery JSON binds these public records; private owner
identifiers and signed transfer URLs are not committed.

The final qualified runtime is still 6f359ce2b24291ee219810773c641d53802fd31d.
The final current-source Linux cohort has four budget-complete long episodes
and four retained timeouts; Windows qualification remains a separate pass.
The broad 142-episode comparative experiment remains attributed to 5ee5dffc.
No production defect, default activation, Ready promotion, merge, candidate
programme import or physical NVIDIA acceptance is claimed. PR #781 remains
Draft/HOLD. The deferred CONTROL 1024 experiment was not launched.
