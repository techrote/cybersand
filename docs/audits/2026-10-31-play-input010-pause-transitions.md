---
title: PLAY INPUT010 immediate pause transitions
status: Current
document-kind: audit
scope: Shared-course immediate input revocation and pause-control parity; source-bound headless evidence
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [../systems/player-control-playground.md, ../operations/github-development-and-release.md, 2026-10-31-play-life009-automatic-pause.md]
---

# INPUT010: immediate shared-course pause transitions

## Defect and correction

Original Main at `1686d449d979a47e0b6520c5f048716a128cf700` changed only the
`paused` boolean on P. Cancellation happened in a later physics callback, so a
pause/resume pair between callbacks retained pending input and its generation.
The same shared route also lacked the legacy playground's Escape/Start pause
controls. This is a production defect and a control-parity gap, not shader work.

The correction centralizes the shared-course setter and ownership-gated toggle.
It cancels through the original physical session before changing/publishing pause,
preserving the existing worker/native World/main-thread Rapier. P, Escape,
selected-pad Start and the explicit panel Resume use that path. Resume refuses
pending construction/reset, unready terrain and a failed native worker. The
selected-pad, keyboard-only, focus and modal boundaries remain authoritative.
Analog inputs retain latest-state semantics; ordered button/equipment edges
retain their existing FIFO. No rig tuning or solver/physics defaults change.

## Actual failing-before comparison

The identical new acrobat fixture ran with the original three production scripts
from1686. It failed16 assertions/1 failure, exit1, in2.432s, specifically
`p: pause immediately revokes authority before any callback`. Before/after P:
pending edges2, control generation6, physical tick4 and Main callback91 remain
unchanged. The candidate restores those production files byte-for-byte afterward.

The original negative log SHA-256 is
`315b0d918be649831479d1a1fc4ea70419b50f539a51e26da991e242d497ffc4`;
its source-identity receipt SHA-256 is
`e1feeb85718820c7d07a89c5b53ca7b3922e6dbaac413d09f40e385375e5fbd5`.
This is an actual source-baseline failure, not a model or timeout counterexample.

## Candidate execution and limits

Local source checkpoint `b7ceab2136a888d98f9050f18ebb3eb9377f6bef` contains three
production scripts, the shared fixture and five discoverable wrappers. Pinned
Linux Godot `4.7.stable.official.5b4e0cb0f` and committed native/Rapier LFS
libraries execute actual `main.tscn`, automatic callbacks and normal input dispatch.
Only window focus/device enumeration are explicit seams. No manual physics step,
owner replacement for pause, fabricated pose or production native hook is used.

| Case | Assertions | Failures | Local process seconds |
|---|---:|---:|---:|
| INPUT010 stuntbuggy | 101 | 0 | 3.832 |
| INPUT010 trialsbike | 101 | 0 | 3.824 |
| INPUT010 acrobat | 101 | 0 | 3.824 |
| INPUT010 arcadelander | 101 | 0 | 3.927 |
| INPUT010 jetbarrel | 101 | 0 | 4.027 |
| Unchanged UI004 | 32 | 0 | 1.217 |
| Unchanged UI005 | 90 | 0 | 12.652 |
| Original LIFE009 acrobat | 103 | 0 | 2.972 |

Total730 assertions/zero failures at that source delta. The integrated candidate
also requires explicit15s teardown and150s total-fixture checks; those additional
assertions need fresh execution and are not attributed to the preceding table.
The resulting reviewed source overlay on LIFE009ca426 passed a fresh acrobat
smoke103/0 with clean import,2.657921s fixture and51,988us teardown. It uses a
task-local writable engine config/data/log location; this is a distinct local
execution, not a replacement of the preserved first launch failure.
External cases retain180s and import240s. The five wrappers are automatically
discovered by the complete ordinary Windows/Linux Godot suites; no existing
coverage or scientific case is replaced. The accepted50-real-lifetimes-per-OS
suite remains intact.

The fixture contains a matched toggle-only stale-edge negative, before-callback
generation/queue checks for all three controls, non-expired old-observation
refusal, held-neutral and fresh-nonneutral completed Rapier steps, native pause
acknowledgement/quiescence, modal/focus/other-pad refusal and explicit-panel rearm.
A real keyboard-only reconstruction verifies Start refusal and newer actor/World
identities on the same worker. Shutdown observes session destruction and join.

First local launch failed before gameplay on an unwritable default user-log path;
the crash log remains failed. A writable explicit `--log-file` corrected only the
launch environment. Editor import socket/config errors are retained separately,
not called clean hosted import qualification. Source-delta receipts, commands and
original per-case logs accompany the qualification evidence.

## Reproduction and integration boundary

Use the repository's pinned runtime preparation and ordinary regression runner.
The focused scripts are `res://tests/test_play_input010_<rig>.gd`, with rig IDs
`stuntbuggy`, `trialsbike`, `acrobat`, `arcadelander`, `jetbarrel`. For example:

```text
<pinned-godot> --headless --path godot --script res://tests/test_play_input010_acrobat.gd
```

The external180s bound, original output log, process return code, source SHA/tree,
runtime hashes and `PLAY_INPUT010_RESULT` must be retained. A passed process must
contain the actual result, zero failed assertions, native/Rapier identities,
complete waits and teardown; counters alone do not establish applied input.

This candidate consumes the reviewed LIFE009 correction without modifying its
historical evidence. Full applicable exact-head Documentation/materialized
provenance, Native, Windows/Linux Godot, scope checks and final independent
review remain required before guarded integration. Local Linux is not Windows,
graphical, physical-device, real OS-focus or human-feel acceptance. #268/#269,
#270/#263 remain open. Held #308/#310, frozen #312/#316, owner-deferred shader
work and paused Scheduswarm remain unchanged.
