---
title: Persistent authored areas prototype
document-kind: contract
status: Current
scope: Opt-in GEN-006 three-area desktop vertical slice, native CYPS2 continuation, durable profiles and bounded accounted game time; broader streaming remains planned
canonical-for: [persistent-authored-areas-prototype]
keywords: [GEN-006, persistent areas, game time, catch-up, CYPS, durable checkpoint, Simulate Ahead]
related-documents: [../reference/level-saves-and-replay.md, ../architecture/data-ownership-and-lifetimes.md, ../reference/interfaces-and-message-contracts.md, ../decisions/ADR-015-persistent-authored-areas.md, ../operations/persistent-areas-evaluation.md, ../audits/2026-11-21-gen006-persistent-areas.md]
last-reviewed: 2026-11-22
---

# Persistent authored areas prototype

This opt-in desktop candidate implements the first persistent authored-area
milestone in [#591](https://github.com/techrote/cybersand/issues/591). It does not
complete the general streaming and recipe-reconciliation programme in
[#194](https://github.com/techrote/cybersand/issues/194). The ordinary application
and Workbench Water defaults are unchanged. The candidate remains Draft/HOLD.

The stacked [native RAM residency extension](persistent-area-residency.md), implemented in
[Draft PR #734](https://github.com/techrote/cybersand/pull/734), adds real inactive HOT Worlds,
WARM checkpoints, asynchronous durability and predictive preparation. This document owns
the common native continuation/time/profile domain. Its synchronous lifecycle below
describes the cache-disabled conservative path; strict cache-enabled travel also requires
durability but can transfer an existing HOT World without reconstructing it. The extension
contract owns those residency and write-behind differences.

The implementation owners are
`native/include/cybersand/persistent_area_continuation.hpp` (native domain),
`godot/native_extension/cyber_persistent_area_continuation.hpp` (bridge/candidate),
`godot/native_extension/persistent_area_storage.cpp` (durable filesystem),
`godot/scripts/persistent_area_store.gd` (validated transactions),
`godot/scripts/persistent_area_clock.gd` (completed-time accounting),
`godot/scripts/persistent_areas_controller.gd` (lifecycle), and
`godot/scripts/simulation_worker.gd::persistent_request` (exclusive owner lease).

Launch the **Persistent areas · experimental** entry, or pass
`-- --persistent-areas` to the ordinary application. The explicit scene is
`godot/persistent_areas.tscn`. The initial profile contains three independently
authored 512 × 512 areas: an industrial Wood/Oil/Coal fire, Water/Sand terraces
with an erasable wooden gate, and a recognisable metal/glass gallery with a Sand
chute. They use actual supported native materials and reactions. The editor and
camera travel; this prototype has no persistent traveller actor.

## Authority and supported domain

| State | Authority and retention |
| --- | --- |
| Live cellular state | The existing simulation worker exclusively owns one active `CyberNativeCellWorld`. |
| Inactive area continuation | HOT native World, WARM complete admitted CYPS2 checkpoint, or COLD durable checkpoint under the [residency contract](persistent-area-residency.md). Checkpoints retain checksum, physical hash, completed tick, configuration and area/session identity. |
| Target being loaded or advanced | One bounded private preparation at a time; retained HOT Worlds have separate fenced ownership. A private target cannot mutate the active World. |
| Latest authored starting map | The existing Workbench Setup, generated baseline or Flatten material baseline, retained separately from live CYPS. |
| Original native construction | The complete validated MicroScenario definition and digest; subsequent authoring edits do not rewrite this provenance. |
| Game time | A versioned profile clock with global completed game ticks and an independent accounted/native tick frontier for every area. |
| Durable selection | A manifest records the last acknowledged selected area; both source and target checkpoints remain recoverable during adoption. |
| Camera | Bounded copied position, view size, zoom and mode, restored on Main after native adoption. |
| Render caches | Derived and rebuilt; they have no persistence authority. |
| Host actors, Rapier bodies, controllers, body masks, sources and liquid equipment | Unsupported. Actual live dependencies or outstanding commands pin/refuse capture, preparation or commit. |

The admitted native domain is Current/FreeMass, physical-state format/hash v2,
the existing phased in-place backend, full 512 × 512 interest region, radius 2,
cadence off, and settled discovery off. Native continuation includes explicit
Empty edits, material transformations and movement, per-cell state/epochs,
temperature where present, activity and deadlines, native clocks, pending native
explosions, reaction/quantity ledgers and Current-Water solver quantities.
Wave and the other unqualified solver configurations are explicitly refused.
No World limit, material law, body capacity or ordinary production default is
increased by this prototype.

CYPS does not make host event/observation/condition cursors, external input
queues, actor AI, motors, equipment reservoirs, Rapier contacts or a general
replay durable. Capture and reconstruction both reject those dependencies.
The checks run at the actual exclusive owner and native preparation/commit
boundaries, not merely against a saved `actors: []` declaration.

Material edits, ordinary Paint, Art and Flatten remain available in the admitted
profile. Authoring history is saved alongside continuation, including explicit
Empty edits. Earlier Undo/Redo stacks and Art conversation state do not become
cross-area runtime authority. Native replacement, solver changes and actor or
emitter creation use the ordinary Workbench instead; the prototype visibly
refuses those operations. An unfinished authoring transaction must complete
before a persistent capture can acquire its lease.

## Lifecycle and atomic handoff

The conservative cache-disabled lifecycle is Active → Transition requested → Capturing → Durable →
Loading → Catching up → Capturing → Durable → Ready for activation → Active.
Inactive areas retain their independent durable checkpoint. A failed operation
retains the previous World; ambiguous publication or incompatible/corrupt state
enters a visible failed/quarantined state requiring recovery.

1. Pause and drain already admitted edits and host commands. Acquire one
   nonreusable operation lease at the native owner boundary.
2. Capture the current native continuation and reconcile any completed ticks
   that the most recent UI snapshot had not yet observed. Copy authoring state.
3. Publish a source checkpoint and its matching game clock. The source remains
   live and frozen until the operation completes.
4. Validate the target's stored identity and bytes, then restore it through the
   existing prepared-World constructor. Its native receipt is a typed
   `workbench_continuation`, distinct from tick-zero `applied_run` provenance.
5. Execute bounded private native work. Capture the resulting candidate and
   publish its exact completed-time frontier before native adoption.
6. Commit the native preparation with fresh ownership/dependency fences, then
   wait for the ordinary Main request serial, source digest and new-generation
   acknowledgement. Publish the selected-area hint and release the lease.

Source capture does not dispose of the only authoritative copy. A refused
target leaves the old live World available. Candidate cancellation discards
only private uncommitted work. If candidate work has already been durably
published, its accounted frontier is retained and cannot be repeated on retry.
An uncertain manifest publication pauses the old live incarnation and reopens
the store before deciding which completed frontier is authoritative.

Initial creation keeps authoring and simulation paused while all three initial
native capsules are collected. One complete first manifest publishes them
together. Existing files without a valid manifest are quarantined; they never
trigger silent seed regeneration. On process restart, the application may
prepare an empty temporary actor-free Workbench solely to retire Main's generic
startup bodies safely. That temporary owner is not an area and is never saved
as one; the selected area always comes from its validated native checkpoint.

## Game time, catch-up and Simulate Ahead

One game second is 60 completed native ticks. Real wall-clock absence has no
effect on the profile. For global time `G` and area accounted time `A`, remaining
debt is `G - A`. Accounted time is tied to completed native ticks and a declared
origin; it is not the time of the most recent visit.

| Operation | Time accounting |
| --- | --- |
| Ordinary active tick | Increment both `G` and the active area's accounted/native frontier by the actual completed tick delta. |
| Catch-up on a retained area | Advance its accounted/native frontier toward `G`; leave `G` unchanged. |
| Simulate Ahead | Pay existing debt first, then add only actually completed future ticks to both frontiers. |
| Cancellation or budget exhaustion | Commit only proven completed native work; show unpaid debt and unperformed requested future duration separately. |
| Repeated visit or completion | Stale clock/operation identities refuse; an already accounted interval receives no additional credit. |

The selected strategy is bounded real native stepping. A coarse/idle-skip
admission probe intentionally grants zero skipped ticks because this native
domain has no future-rest certificate. A retained negative fixture has no active
chunks at tick 20 but executes a scheduled Ice/Water interaction at tick 21.
Another crosses an epoch wrap while a coarse quiescent projection stays equal.
Neither proves that state may safely be held constant while its clock advances.
Different native work slices are an exact scheduling comparison, not an
approximate solver. The prototype reports this limitation instead of claiming
that approximate skipped time was simulated.

The panel offers finite 5/30/120-second requests, Pay catch-up debt, progress,
Cancel, Save and exit/recovery controls. A request admits at most 600 native
ticks and checks a 3-second stepping budget between slices. Each native slice
admits at most 32 ticks and checks a 100 ms budget between complete ticks. A
single tick is not preempted; measured overruns are retained. Capture, storage,
restore and acknowledgement latency are measured separately and are additional
to useful native stepping. Large debt can remain after activation and stays
visible. Repeated requests can pay it in bounded operations.

## Durable profile and failure semantics

The default isolated directory is `user://persistent-areas/three-areas-v1`.
`--persistent-profile=/absolute/path` selects a separate evaluation profile.
The profile is versioned and bound to the admitted domain and actual native
runtime file digest. Incompatible runtime/schema/area identities refuse; no
universal format migration is promised.

`CyberPersistentAreaStorage` supplies OS-backed single-writer locking, bounded
regular filenames, immutable new files, file flush, expected-target and
expected-stage SHA checks, and atomic manifest replacement. POSIX uses file and
directory sync; Windows uses `FlushFileBuffers` and write-through replacement.
Godot `FileAccess.flush()` alone was insufficient for this boundary. A lock is
released by the OS on actual process termination. Directory replacement, path
escape, symlink/reparse and malformed-entry cases refuse under the supported
desktop contract.

Each manifest binds profile/session/area identities, area incarnations,
monotonic checkpoint and mutation generations, completed tick frontiers,
checkpoint/container/source digests and all area records. An immutable owner
fence is checked again after asynchronous I/O. Current and previous valid
manifests retain their referenced blobs; recognised unreachable files can be
collected after successful publication. Recovery from a corrupt current file
requires explicit selection of the retained previous generation and preserves
the refused bytes for inspection.

The storage bounds are 64 directory entries, 512 MiB total profile storage,
64 MiB per native storage file, 32 MiB per admitted CYPS payload, 8 MiB combined
typed authoring/capsule metadata and 256 KiB per manifest. Native residency is
bounded by the existing 128-chunk configuration. These are refusal bounds, not
claims that peak process memory equals serialized payload size. During initial
creation three capsules coexist; transitions retain one live World, at most one
candidate and bounded serialization/I/O copies. Qualification records process
RSS and retained disk size separately.

Crash recovery restores the last durably published checkpoint. Active edits or
ticks after it can be lost if the process is killed before successful capture
and publication. Save, travel and bounded progression acknowledge their durable
state; there is no always-on edit journal. Ordinary save failures retain the
current live World, and normal departure attempts a durable save.

The durability claim covers executed process-crash and I/O failure recovery on
the tested platforms. It does not promise hardware power-loss behaviour for
every filesystem, disk controller or device cache. Ordinary named Workbench
Save and Flatten keep their existing material-start contract; they do not
replace native dynamic continuation.

## Qualification and evaluation boundary

The focused campaign is
`python tools/ci/run_persistent_areas_qualification.py --godot <pinned-engine> --evidence <new-directory>`.
Its headless option is diagnostic only. Publication additionally requires clean
exact source, the actual native build ledger, pinned Linux/Windows dependencies,
real target-OS graphical execution, independent-process restart, original logs,
framebuffer captures and package verification.

The [dated qualification ledger](../audits/2026-11-21-gen006-persistent-areas.md)
owns actual outcomes and remaining blockers. The native test compares complete
CYPS continuation through different slices, worker counts and an epoch wrap.
The storage suite kills real processes after immutable staging and manifest
publication, proves concurrent lock refusal and compares fresh restores. The
Main/Workbench test performs active native play, actual material edits,
A → B → C → A, repeated/cancelled Ahead, malformed native replacement, storage
fault/retry/quarantine and fresh-process reopen. Both supported graphical sizes
keep essential actions reachable.

Windows CI/software rendering and an extracted portable ZIP are separate from
physical Windows 11/NVIDIA owner acceptance. The next bounded milestone should
be selected from measured transition cost and the demonstrated dependency
boundary, rather than treating arbitrary chunk eviction or universal actor
persistence as already solved.
