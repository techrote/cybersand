---
title: Materials Lab and shared Workbench integration qualification
status: Current
document-kind: audit
scope: Separate integration of PR 562 Materials Lab and PR 564 Workbench onto accepted main including PR 563; source-matched Windows/Linux qualification and standalone evaluation
canonical-for: [mat-auth-workbench-integration-evidence]
last-reviewed: 2026-11-13
related-documents: [2026-11-11-materials-lab-completion.md, 2026-11-11-material-native-capability-cutover.md, ../operations/materials-lab-authoring.md, ../operations/wb-art-paint-integrated-candidate.md, ../architecture/shared-workbench-authoring-data.md, ../operations/current-and-historical-validation.md]
---

# Materials Lab and shared Workbench integration

The owner requested one independently qualified application containing the latest
Materials Lab and complete Workbench. This separate integration branch and
[Draft PR #565](https://github.com/techrote/cybersand/pull/565) preserve original
feature branches and worker ownership. No Ready promotion, merge into main,
auto-merge, material installation, physics default change or save-format change
is part of this work.

## Preserved source history

| Source | Inspected identity |
| --- | --- |
| Initial accepted main | `d8588716becb0dc42019faf23f721378d8adc84a` |
| Accepted #562 merge, incorporated normally | `e0fb05b8e0500641f0f25c62c5fb7e721da02d6a` |
| Materials Lab application and request 10 | `8540ee06f9ce0e4c6a00a6c61dce194c40fb7e04` |
| Latest Lab runtime publication | `2e86f4f38078130799820e414836e21f0c0f3e70` |
| Initial Workbench with shared agent Undo/Redo | `b9270611bde82f3d44e4f7f496c6dbd03aa5801e` |
| Latest incorporated Workbench UI and fixture repair | `6319ab1d94d85d01c9cdb44d973a92d224bfa9aa` |
| Initial two-parent integration | `4f37f836fa57189a1c5b0ab1582dbb39d6488c7f` |
| Initial combined source tree | `1a91ceebf18bb13c34225c3cd0bb573f288e51fe` |
| First frozen combined execution source | `90719c72b9fcf90593fb7878354051ad601b47fd` |
| Second frozen combined execution source | `88ba76f023e933b52d15f272263077e091bc9656` |
| Separately published capability follow-on #563 | `ecdf08cca10e96ce558d5d044896c709149b9198` |
| Current accepted main, #563 merged by separate action | `63f8b1ba6559906fe85f3ad0269aa296e4141d67` |
| Preserved authenticated capability transition ancestor | `b432d52d0d9acaa22f93eeb8d1fad48c64b4c087` |

The initial merge resolves six documentation overlaps by retaining both feature
contracts. The product merge keeps the Materials Lab mount and native inspection
bindings alongside all Workbench generator, PAINT, agent/provider, native receipt,
shared chronological Undo/Redo, persistence and equipment paths. The subsequent
ordinary merge retains the Lab publisher child in ancestry; its earlier binaries
do not qualify the combined native extension.

Compared with current accepted main, all 27 protected material-authority source
roles, canonical catalogue and frozen compatibility lock are byte-identical.
The accepted #563 consumer and its authenticated transition ancestry are retained
without rebaselining any compatibility hash. The combined native extension still
requires fresh Windows/Linux builds; neither earlier feature runtime qualifies it.

## Combined execution and delivery contract

The isolated integration publisher reuses the existing Materials Lab publication
engine with its own branch lease, request and artifact identities. Original Lab
and Workbench publishers retain their ownership. Qualification requires actual
complete catalogue discovery, native Lab/Workbench cases, rendered Lab execution,
full PAINT/agent regression and installed combined author/reopen campaigns.
A focused real-native regression covers opening/using/closing the Lab between
manual and agent history operations, keyboard isolation, isolated candidate
World comparison and fresh-process persistence at one/four workers.

The Windows bundle retains the Lab's pinned Python, Git, compiler, complete source
history and notices. It adds the Workbench launcher, all canonical generator
profiles in both package locations and app-local Microsoft runtime. Relocated
execution must use the delivered tools and source. Cross-compilation alone is
not Windows execution, and a feature's previous green result is not combined
qualification.

## Execution status and observed repair

Request 1, [run 43334477644](https://github.com/techrote/cybersand/actions/runs/43334477644),
executed exact source `90719c72b9fcf90593fb7878354051ad601b47fd`.
Linux passed the complete 209-case catalogue, native Lab cases, both graphical
Lab cases, all 36 Workbench regressions, all four new Lab/Workbench author/reopen
cases at one/four workers (278 checks), and all 12 installed-layout cases.
Independent readback matched all 88 native and 832 build inputs, original logs
and receipts, all 67 image hashes and reviewed representative actual frames.

Windows passed 206 catalogue cases with exactly three registered POSIX skips;
its real Windows timeout/cancel descendant controls passed. All native Lab,
graphical Lab and 36 Workbench regression stages passed, including shared
manual/agent Undo. The first new mounted Lab/Workbench case remained pending
until the unchanged 300-second deadline, then returned cancellation without a
candidate World receipt. The run correctly stopped before packaging,
publication or final-gate dispatch. [Original Windows failure artifact](https://github.com/techrote/cybersand/actions/runs/43334477644/artifacts/13998404661)
SHA256 is `0aa2f1b495879b39cbd956899ae6ede4b47a83c35f4badc388272a8bd96fd602`.
The successful Linux artifact is [13999396092](https://github.com/techrote/cybersand/actions/runs/43334477644/artifacts/13999396092),
SHA256 `6ca3266605d06e4cb0773eb105ab27442219baf23eec4d9a15468bc0091c398a`.

A separate [Windows diagnostic run 43342275664](https://github.com/techrote/cybersand/actions/runs/43342275664)
reused the exact frozen source/DLL and unchanged test. External Python phase
tracing and process sampling recorded software-renderer CPU contention:
with the 15 FPS cap, the first reference compile hit its original 180-second
limit. During that phase Godot used 3.704 CPU cores and the compiler received
0.100 core; host CPU averaged 96.18 percent. The exact request without Godot
compiled reference/candidate in 11.859/11.047 seconds, and the standalone Lab
in about 15 seconds each. With both windows capped at 5 FPS, both compiles
completed in 25 seconds and the unchanged author fixture passed all 102 checks.
All 88/832 source inputs and the DLL remained unchanged. These are diagnostic
results, not qualification. [Original diagnostic artifact 13999718293](https://github.com/techrote/cybersand/actions/runs/43342275664/artifacts/13999718293)
SHA256 is `07750995f9c828908adc836d7b141c1b61c3685d4117e3da4c29ecf3f9b4ef1a`.

Request 2 bounds only the new two-window graphical capture at 5 FPS, including
its installed replay. Standalone Lab captures retain 15 FPS. Application frame
rates, physics defaults, native ownership, test assertions and all compiler,
execution and service deadlines remain unchanged. It also incorporates #564's
new committed compact panel, Select focus and editable-conversation UI, plus its
visible-viewport pilot-test repair. The existing new panel test joins the
explicit Workbench campaign; full Godot discovery also includes it. These are
preserved upstream feature changes, not newly designed integration features.

Request 2, [run 43345030561](https://github.com/techrote/cybersand/actions/runs/43345030561),
froze source `88ba76f023e933b52d15f272263077e091bc9656`. Its complete Linux
catalogue passed 209 tests with no skips or failures; fresh Windows cross-build
and initial source Documentation passed. Independent readback matched 88 native
and 834 build inputs. At 2026-11-13 01:34:01 UTC, a separate action merged #563
into main while platform execution was running. Request 2 therefore cannot
qualify the resulting accepted-main/Workbench source; its original evidence is
retained under its own identity.

Request 3 incorporates accepted main `63f8b1ba` through a normal two-parent
merge. Product source merges cleanly. The sole integration guard repair updates
the expected independently owned Lab publisher branch to the accepted capability
publisher branch. The private integration branch lease and four-path publication
boundary are unchanged. The inherited verifier now requires all 231 discovered
catalogue cases, including the 22 accepted capability controls. The original
37 Workbench stages, all combined/installed fixtures and deadlines remain intact.

At this accepted-main replacement checkpoint, qualification is **IN PROGRESS / HOLD**.
Fresh uninstrumented Windows/Linux execution, standalone package verification,
runtime publication and actual complete final gates are required. PR #565 will
supply exact terminal source/run/artifact/checksum results. No earlier pass or
diagnostic is relabelled as qualification of the replacement source.

## Merge sequence and follow-on boundary

The initially requested sequence was **#562 → #564 → #563**. Separate owner
actions accepted #562 at `e0fb05b8` and then #563 at `63f8b1ba` before this
integration completed. This task performed neither main merge and does not
rewrite them. The current safe continuation is to retain both accepted merges
and qualify the reconciled Workbench on top. PR #565 remains the separate
integration/evaluation vehicle; original PAINT #544 and agent #560 must not be
merged independently from this preserved history.

The old #563 source `ba20acbd` failed Windows graphical publication in
[run 43123100407](https://github.com/techrote/cybersand/actions/runs/43123100407).
Its replacement source `c55a0724` normally merged accepted main and completed
its own platform/package publication in [run 43336935041](https://github.com/techrote/cybersand/actions/runs/43336935041),
producing `ecdf08cc`. All four exact-head full manual gates passed (Documentation
43342379587, Native 43342384177, Godot 43342388943, Palette 43342393818), as did
the 120-case Water apparatus campaign 43342445933. Its old failure is historical.
Those results qualify the accepted Lab/capability tree and remain distinct from
the new combined qualification. The integration retains the authenticated
`b432d52d0d9acaa22f93eeb8d1fad48c64b4c087` ancestor, exact generated consumer,
per-file route pins and independent B-only request. Do not squash away that
custody or reuse either earlier runtime as qualification of the later combination.

## Owner acceptance procedure

Extract the complete Windows archive to a writable directory and use **Open
Workbench.cmd**. Generate a profile; alternate manual and agent edits, Undo and
Redo while paused; Stop a longer edit and undo its confirmed prefix. Open
Materials Lab, inspect and duplicate an admitted existing material, edit a
supported property, compile and compare it in an isolated native World, and
save/reopen the preset. Return to Workbench and continue the shared history.
Exercise simulation/equipment, pause, save a named start, exit completely,
relaunch/load and verify the authored terrain, actors and settings before editing
again. **Open-Materials-Lab.cmd** opens the Lab directly.

Undo history remains session-local; Load/Reset/World replacement or simulation
retires unsafe history. Saved starts reconstruct authored layouts and existing
settings, not evolved simulation state. Authored candidates remain confined to
supported isolated Lab backends; no production installer is introduced.
