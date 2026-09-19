---
title: MS-000 MicroScenarios implementation and validation
status: Current
document-kind: evidence
scope: Dated Linux native and controller validation of the declarative scenario harness; explicit Windows/browser gaps and concurrent-branch publication boundary
canonical-for: []
last-reviewed: 2026-09-19
related-documents: [../operations/microscenarios.md, ../operations/microscenarios-programme.md, ../reference/validation-evidence.md]
---

# MS-000 implementation checkpoint

## Identity and publication boundary

This checkpoint implements issue #27 as apparatus, not physics work. Source intake
is `781a2d7cb5d5a66bf1cff8fc6654e0ab708e419c`. The isolated #24 prerequisite
from PR #34 is `b148cc2d799e6c333df466a6ddb0c35f060314a0`; it sets the root
Tower button's focus mode without importing PR #25 or PR #33.

The tested working delta is identified file-by-file in the
[compact evidence manifest](2026-09-19-issue-27-microscenarios.json). Recovery/publication
branch is `codex/issue-27-ms000-validated`. Its reviewed implementation commit must
be read from the PR/branch; the manifest deliberately avoids a self-referential
source commit hash. Raw logs are outside the source checkout under
`/mnt/data/ms000-work/validation/`; their digests are retained in the manifest.

During publication, `codex/issue-27-microscenarios-harness` advanced with a distinct
implementation using `micro_scenario_*.gd` and an incompatible schema. That work
was not overwritten, force-pushed or merged into this implementation. This branch
uses `microscenario_*.gd`. The two alternatives must be reconciled before merging;
**do not merge both**, because they declare overlapping class names and ownership.
This checkpoint makes no acceptance claim for the other implementation.

Execution occurred late on 2026-09-18 UTC / 2026-09-19 Europe/London. Godot is the
pinned `4.7.stable.official.5b4e0cb0f` Linux x86_64 engine, Rapier2D is 0.35.2.
The native library SHA-256 is
`f44360702d942386bf515a201cf72018bed1568e14061cf0e586d2e30c351492`.
It is the verified intake LFS artifact, not a newly rebuilt extension. No native
C++ source changed. The separate native unit executable was rebuilt with the
available GCC toolchain using `make test`.

## Implemented scope and reviewed invariants

The [canonical contract](../operations/microscenarios.md) owns the new schema,
capacity limits, lifecycle, controls and capture semantics. The validator,
catalogue, host, provenance helper and panel are shared by the existing desktop
and synchronous Web controllers. No worker/Rapier ownership migration occurred.

The catalogue preserves the exact ancestral Tower v4 and 35 Water v1 recipes,
plus two new exploratory fixtures: unequal-head Water and Sand support release.
The same complete JSON definition is usable in the UI and native-only headless
runner. The generic editor applies only through a fresh validated reset. Invalid
replacement preserves both World and host state. Fixed proving fixtures admit a
fixed region/cadence/adhesion configuration, independent of live camera controls.

Scheduled events, observations, histories and timing retention have explicit
bounds. Missed tick boundaries fail visibly instead of executing catch-up.
Native failure still quarantines the World, suppresses successful native captures,
and requires reset. Desktop captures are recursively frozen before publication.
Observer-off comparisons preserve physics and objective semantics. Existing blind
Water evaluation and transactional Apply + Reset remain on their original route.

No Water solver, Cell layout, material interaction, transport default, ballistics,
soliding, persistent velocity or production precision change is included. Old
#13/#19 recipe/evidence files and all historical M11 hashes remain unchanged.
This does not admit #18/#20 or complete G-final. The new Water fixture is not a
registered #26 baseline, and #28 Materials Laboratory readiness remains separate.

## Executed correctness and regression checks

Commands used the pinned engine as `$GODOT`, source working directory and explicit
process timeouts. All relevant logs have retained digests; no timed-out result is
reported as a pass.

| Check | Command / timeout | Actual result |
|---|---|---|
| Baseline before extraction | `$GODOT --headless --path godot --script res://tests/<name>.gd`, 180 seconds each | Existing Tower, Water recipes, Water integration and Water controller suites all passed |
| Final complete fixture sweep | Import with `--editor --quit`, 240 seconds; every `godot/tests/test_*.gd`, 180 seconds each | 33 invocations: import + 32 test scripts; all exit 0, no ERROR diagnostics; one render test explicitly skipped headless |
| New harness tests | `test_microscenarios.gd`, 180 seconds | 6,471 assertions, zero failures |
| New controller/input tests | `test_microscenario_controllers.gd`, 180 seconds | 52 assertions, zero failures |
| Native unit suite | `timeout 300 make test` | 61 tests passed; existing compiler warnings retained |
| Actual pixel render check | `timeout 120 xvfb-run -a $GODOT --path godot --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/test_water_presentation_render.gd` | Passed coverage 2/4 at 2x and 8/16 at 4x plus oriented right edge, using Mesa llvmpipe |
| Graphical scenario smoke | Same software OpenGL host, ordinary desktop scene, unequal-head Inspect fixture | Frame captured and inspected; not a hardware-performance claim |
| Validation checker contracts | `python -m unittest discover -s tools/ci -p test_validation_contracts.py`, 120 seconds | 8 tests passed |
| Retained M11 integrity | `python tools/ci/check_m11_consistency.py`, 300 seconds | 18 retained records and 28 source hashes passed against their historical revision |

The complete fixture sweep is not the full release command: it does not include
the separate long-running `profile_native_world` and `profile_scheduler` programs.
The repository CI runner already discovers both new `test_*.gd` files. Functional
runs overlapped other functional checks, so their elapsed times are not a registered
performance comparison, CPU scaling result or production budget claim.

### Comparator coverage

All 35 Water wrappers were checked against the existing native recipe builder
with mass3/mass8, seed 31, coherence controls and exact matching-config state at
setup and subsequent ticks. Additional delayed-event comparisons cover drips,
trickle, Mercury samples and connected pools. Tower setup remains source-matched.

Both generic fixtures were exercised for 120 ticks across all three modes,
one/four workers and optional instrumentation on/off. Same-worker comparisons use
exact native state; cross-worker comparisons normalize the worker configuration
in state-hash identity and retain exact material content/quantity. The headless
Water JSON round-trip compared Benchmark/one worker/observers on to Play/four
workers/observers off: identical definition, content hash `8b412006301ee75a` and
4,553,280 integer Water units. No cross-ABI raw-hash equivalence is claimed.

Tests also cover invalid/reserved IDs, oversized definitions/events/observations,
nonintegral JSON, transactional rejection, immutable retained captures, missed
boundaries, genuine native capacity failure/quarantine and fresh reset recovery.
Controller tests use real viewport mouse input for Tower entry, Space press/repeat/
release, F9 echo rejection, pause/single-step, pending reset guards, pasted invalid
JSON, HUD visibility, pinned controls and return from a generic fixture to Tower.

## Negative results and repairs retained

Initial iterations exposed integral JSON floats changing transport metadata hashes;
normalization now preserves canonical round trips. Legacy Mercury sample events
carry material ID 33; validation now preserves that read-only metadata instead of
rejecting it as an erase payload. GUI tests initially injected mouse coordinates in
the wrong viewport space; the explicit local-coordinate route fixed that test.
A modal focus warning was removed by giving the JSON text editor normal focus.
The final source freeze re-ran the complete fixture sweep after these repairs.

Headless rendering emitted an explicit skip; the separate actual-pixel software
OpenGL test supplies that limited pixel evidence, not inferred GPU acceptance.
Windows execution and real compatibility/threaded Web exports were unavailable in
this checkout. Exercising the Web controller on Linux is not browser validation.

## Documentation and acceptance disposition

The contract, programme, roadmap, handover, ownership, interfaces, capacity,
Tower runbook, build guide, saves/replay limits, validation ledger and retrieval
routes are updated together. The existing frozen retrieval set remains unchanged;
three additional challenge questions cover apparatus boundaries and capture truth.
Historical evidence is retained, not retroactively attributed to this implementation.

Initial documentation checks failed because the source-only bundle lacked six
companion-workspace fact-source references. The exact companion revision
`6a58311982941b75f46e22109a0829e5acb83c7e` was then obtained through the existing
read-authorized workflow artifact rather than fabricated placeholders. Final
`check_docs.py` and `check_repository.py` both passed with no errors or warnings.
The frozen 32-question retrieval set reached 32/32 canonical hit@5 (21/32 hit@1,
MRR 0.8073). The 19-question challenge set reached 19/19 hit@5 (14/19 hit@1,
MRR 0.8596). The three new routes were inspected for schema/mode, capture-truth and
owner/reset answer coverage; lexical hits alone are not correctness evidence.
Only nine required LFS payloads are materialized locally (the Linux/Android .so
set); complete all-platform LFS validation belongs to CI's fresh checkout.

This branch is an implementation/review checkpoint, **not automatic issue closure**.
Actual Windows/browser acceptance, CI readback, concurrent-schema reconciliation
and any owner-required live #24 smoke remain explicit. Captures are recipes plus
observations, never complete resumed replay or restorable runtime snapshots.
