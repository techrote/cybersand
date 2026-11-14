---
title: Flatten and Bake History qualification and owner evaluation
status: Current
document-kind: runbook
scope: GEN-008-FLAT-001 native material-baseline qualification, source-bound Windows evaluation and separate owner graphical acceptance
canonical-for: [flatten-baseline-qualification]
last-reviewed: 2026-11-13
related-documents: [../architecture/shared-workbench-authoring-data.md, wb-art-paint-integrated-candidate.md, ../audits/2026-11-13-gen008-flatten-qualification.md]
---

# Flatten / Bake History evaluation

This candidate implements issue [#548](https://github.com/techrote/cybersand/issues/548)'s
11 November 2026 contract. **Keep the PR Draft / HOLD.** Automated qualification,
owner graphical acceptance and permission to merge are separate decisions. The
[dated evidence](../audits/2026-11-13-gen008-flatten-qualification.md) records actual
source identities, successful and failed runs, performance and remaining gates.
Do not treat this runbook's commands or coverage as evidence they already passed.

## What Flatten does

**Flatten / Bake History…** makes the current native stored material layout the
new authored baseline and retires earlier construction instructions and Undo/Redo
history. The same live native World, tick, fluid quantities, temperatures, velocities
and physical actors continue unchanged. Empty and every currently supported
material ID use a complete row-major unsigned 16-bit little-endian plane.

Flatten does not Save. New acknowledged paint and agent edits are recorded relative
to that baseline. **Save named start** later saves the material baseline and those
edits. Simulation after Flatten is excluded unless another explicit Flatten captures
it. Reopening constructs ordinary initial material and actor state; the file is not
a simulation checkpoint. Existing Setup-v2 and generated-start-v1 files retain their
original readers and meanings.

The confirmation identifies the discarded history. While capture is pending, the
same compact control offers **Cancel Flatten**. Pending human or agent work must
finish or be stopped and acknowledged before Flatten. Refusal/cancellation leaves
the prior authored start and existing saves intact. Retry after the reported owner
operation settles; an incomplete capture never becomes the new baseline.

## Windows owner acceptance

Download the source-matched evaluation ZIP identified in the dated record or PR.
Verify its SHA-256, extract the complete archive into a new writable folder with a
short path, and run **Open Workbench.cmd**. Keep the included source, dependencies
and qualification records together. The full package also includes the accepted
Materials Lab authoring tools; its separate launcher remains available.

1. Open **New from generator…**, select a real profile and install a map. Paint
   several materials, erase some cells, and alternate a few manual and agent edits.
2. Run simulation long enough to move or transform material. Move an actor or let
   it fall, then click **Flatten / Bake History…** and confirm. Observe that the
   live simulation continues, actors retain their motion and no tick-zero restart
   occurs. The previous Undo history should now be empty.
3. Pause. Paint a distinctive new mark and erase part of the flattened map. Add a
   small agent mark. Undo and Redo the subsequent operations in chronological order.
4. Explicitly **Save named start** under a new name. Completely exit Godot.
5. Launch again and Load that name. The flattened material layout and subsequent
   acknowledged edits should return without regenerating the former profile. Actor
   spawns/settings reconstruct normally; transient physics from the earlier process
   is not expected to resume.
6. Continue painting and agent authoring, Undo/Redo those new edits, and try Restore
   start. Confirm ordinary input, Fill, Copy/Paste, generator preview and Materials
   Lab remain usable.
7. Start a longer drawing operation, attempt Flatten while it is pending, then
   Stop/wait for acknowledgement and retry. The refusal must explain why; no old
   history or existing save may disappear during a refused/cancelled preparation.

Report the evaluation source SHA, ZIP SHA-256, saved name and exact steps for any
failure. Automated graphical frames do not substitute for this owner interaction.

## Recovering after a native owner fault

If the native simulation reports a fault, keep the application open and explicitly
**Save named start**. A settled authored document can be saved even when its
flattened baseline has not previously been written to disk. The saved content is
the retained baseline, acknowledged edits and supported actor/configuration data.
Save does not capture the failed World or include simulation changes since Flatten.
The success message confirms that the native owner remains failed.

Pending edits, unconsumed completion receipts, partial edits, prepared replacements
and pending Flatten still block Save. Follow the stated refusal; the recovery path
does not bypass those guards. A failed Save preserves the prior valid named file.

Save also refuses after owner failure if the document contains any four-field
legacy disc instruction: its native execution has no individual acknowledgement.
The refusal retains all authored data. A flattened baseline with acknowledged
PAINT/Art edits can use the recovery route when the remaining guards are settled.
Healthy Save and the existing legacy readers retain their original behavior.

After Save succeeds, completely exit, restart and Load the saved name. The new
process reconstructs an ordinary authored start with normal initial physics.
Flatten and editing remain unavailable on the failed owner. Reset / R and Restore
start also refuse their unsafe recipe-only recovery path for generated or flattened
starts, with guidance to Save, restart and Load.

## Source-backed qualification

The dedicated `gen008-flatten-qualification.yml` workflow is limited to the feature
branch and an explicit source-bound request. It reuses the accepted MAT-AUTH and
integrated Workbench publisher, pinned Godot 4.7, godot-cpp, Linux compiler,
LLVM-MinGW Windows cross-build and Rapier. Original catalogue, Lab, integrated
Workbench, graphical and offline-package gates remain in place.

Windows first runs a separate, bounded 512² platform diagnostic with the same
pinned engine and candidate native library. Its original artifact checks the
storage-denial fixtures, actual engine memory measurement and owner-fault
Save/reopen path before the longer retained suites. This diagnostic does not
replace any final gate: the complete twelve-record Flatten inventory, accepted
regression families and delivered-copy smoke remain mandatory afterward.

The added native contract covers complete stored IDs, masked/fractional Water,
nonmutation of tick/thermal/physics state, actual simulation-derived material
transformation, output ownership, invalid dimensions/IDs/length/capacity, owner
failure and 512²/1024²/2048² planes. Normal and ASan/UBSan execution are separate.
Leak detection is enabled by the sanitizer Make target unless an explicitly recorded
local environment override is needed. Existing full Native and GDExtension/Godot,
Documentation/provenance and Palette workflows are requested on the four-path
runtime publication child; dispatch is not a PASS receipt.

The real Workbench fixture generates a native map, paints and erases, uses manual
and agent chronological history, simulates, captures the entire native plane and
Flattens it. Complete before/after arrays and the adopted baseline must agree. It
also checks the same native generation, actual Rapier session/body identities,
paused actor motion state, running simulation, stale human/agent work, cancellation
and failure atomicity. The subsequent Save is checked against an independent
expected material plane in a completely new Godot process. Later simulation is
explicitly excluded from the saved authored plane.

The default qualification cases are 512², 1024² and 2048² with one native worker,
plus 512² with four workers. Each author process must terminate before its paired
reopen process starts. Windows uses actual ANGLE; Linux uses X11. Original
framebuffers are retained with native material hashes and application/runtime input
hashes. The format regression separately covers truncated, corrupt, unsupported,
oversized and failed-write cases, plus legacy format routing; the retained native
history regression provides real legacy fresh-process compatibility evidence.

Two additional processes exercise a genuine native capacity failure after Flatten
and acknowledged edits, rather than setting a test failure flag or injecting a
synthetic completion. The fault must quarantine the real owner. Flatten and unsafe
Reset/Restore must refuse; explicit Save must preserve the quarantined owner and
its existing authored data without capturing, restarting or resetting that World.
The author process then terminates. A new process loads the saved start, checks
every reconstructed stored material against the independent pre-fault authored
plane, then continues painting and Undo/Redo. Pending edits, partial history,
transitions and captures retain their Save fences. The fault fixture also requires
explicit refusal for an unconfirmed four-field legacy disc recipe, with no new
file or loss of authored data.
The registered source and delivered-copy inventory therefore contains twelve
required records: import, format validation, eight ordinary author/reopen runs and
the two owner-failure recovery runs.

Real operating-system storage faults complement malformed-file fixtures. Linux
limits a child process to a 64 KiB file and exercises both a handled partial write
and termination by `SIGXFSZ` during preparation. Windows holds the prior named file
open without replacement sharing and checks explicit writer refusal. A second
Windows case locks only a complete, closed temporary source, leaving the old named
destination unlocked. It holds actual `GENERIC_READ` access with read/write sharing
and no delete sharing. Nonmutating `OPEN_EXISTING` probes must show source `DELETE`
access refused with Windows error 32 and destination `DELETE` access allowed;
neither probe requests deletion or delete-on-close. A metadata-only zero-access
handle does not establish the required sharing denial. The production native
replacement must refuse while both files remain byte-identical; releasing the
source lock and retrying the exact same file must publish its complete bytes and
consume the source. This catches a delete-before-move implementation that would
lose the unlocked destination.
The writer uses a native atomic replacement because Godot's Windows rename can
delete an existing destination before its move fails. Original child logs and
`storage-faults.json` accompany each platform's evidence. Windows also retains
`storage-faults/locked-source-probes.json`; the publisher verifies the original
probe facts, all retained file bytes and the same-source retry.

## Reproduce focused tests

Build the source-matched native extension first using the repository's pinned build
scripts. A retained runtime built before the new bulk APIs is insufficient.
The source-based native targets are:

```bash
make material-baseline-test
make material-baseline-sanitize
```

For a local Linux diagnostic (use the actual Godot 4.7 executable):

```bash
python3 tools/ci/run_flatten_qualification.py \
  --godot /absolute/path/Godot_v4.7-stable_linux.x86_64 \
  --project godot --evidence /absolute/path/flatten-local --headless
```

For a source-built Windows checkout in PowerShell:

```powershell
python tools/ci/run_flatten_qualification.py --godot C:/Godot_v4.7-stable_win64_console.exe --project godot --evidence C:/CyberSand-Flatten-Evidence
```

A focused iteration may use `--cases 512x1`. The final workflow retains the complete
case matrix and accepted regression families. Headless/local diagnostic results
must be labelled separately from pinned hosted Windows/Linux graphical execution.
When given the Windows console launcher path, the measured Flatten runner invokes
its sibling engine executable from the same pinned archive directly. The original
requested path, actual engine path/SHA-256 and measured PID remain in the result.

## Performance evidence and limits

The native contract reports raw copying and validation time. The Workbench reports
native copying/capture, the complete GDScript/native call (`native_boundary_usec`),
worker-result polling/handoff (`transfer_usec`), staging, adoption, Save and
Load-transaction durations within a fresh process. `load_usec` excludes Godot
startup. The runner also retains the complete reopen process wall time, which
includes startup, readback, continued authoring and Restore and therefore is not
a pure Load duration. The polling measurement alone is not the complete
cross-language transfer cost; native boundary time includes native-owned buffer
creation and the returned value conversion.
The qualification runner samples the real Godot process resident memory or Windows
working set every 20 ms, recording per-phase sampled peaks and the OS lifetime
peak separately. It binds the measured executable SHA-256 to the pinned engine
and the native-backed fixture's reported PID to the measured process PID. The
approximately 4.86 MiB Windows values from the earlier console-launcher measurement
are invalid engine-memory evidence and must not be reported as Workbench memory.
A phase peak is resident memory for the entire process at that phase, not an
estimate of incremental baseline allocation. Very short peaks can fall between
samples; the process lifetime peak bounds that measurement separately.

The fixture records the longest frame interval around Flatten as a responsiveness
observation. Software-rendered hosted times describe those hosts, not owner hardware.
Uncompressed payloads are exactly 524,288, 2,097,152 and 8,388,608 bytes at 512²,
1024² and 2048² respectively, excluding bounded metadata and temporary copies.
A flattened plane may be larger than a short construction recipe.
