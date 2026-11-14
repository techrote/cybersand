# S1-2B-DRIV3R — Stage A

**Owner-authorized Stage B continuation:** the qualified Stage A checkpoint is
`ee95f547f31fb1ac9cdd34536bf36dffe7af1d0c`. See the
[Stage B operating guide](../../docs/operations/driv3r-stage-b.md) and
[frozen protocol](stage_b/protocol.json) for held-out direct/fuzzy comparisons,
reversible prompt compaction, paired probes and direction/distance plus path
modulation. The separate [workflow](../../.github/workflows/driv3r-stage-b.yml)
requires an explicit Stage B request. Keep the same PR #580 Draft/HOLD. Original
Stage A evidence remains frozen; new source needs its own qualification.

Opt-in, no-training investigation for [issue #570](https://github.com/techrote/cybersand/issues/570).
One resident official d1-2B Q8 CPU process answers typed `choice` questions; the
host validates IDs, state freshness and permissions before invoking the existing
Shared Workbench Art owner. Keep this branch/PR **Draft/HOLD**.

## Entry points

| Responsibility | Implementation |
| --- | --- |
| Strict versioned records, IDs, budgets and permissions | [contracts.py](contracts.py) |
| Official model/runtime acquisition and resident decision process | [backend.py](backend.py), [pins.json](pins.json), [backend semantics](BACKEND.md) |
| One-cell vehicle and three-node host-defined procedural graph | [providers.py](providers.py) |
| Observation, holistic question, validation, native receipt and termination | [controller.py](controller.py) |
| One actual mounted native World and bounded local RPC | [native.py](native.py), [Godot harness](../../godot/tests/run_driv3r_stage_a.gd) |
| Frozen inference, native episodes, controls, baseline, replay and gallery | [qualify.py](qualify.py), [inference_smoke.py](inference_smoke.py), [replay.py](replay.py) |
| Exact source custody and immutable evidence package | [provenance.py](provenance.py), [source intake](SOURCE_BASELINE.json) |

The [operating contract](../../docs/operations/driv3r-stage-a.md) owns lifecycle,
limits and qualification semantics. The [Stage A report](STAGE_A_REPORT.md)
explains the measured diagnostic baseline, preserved failures and acceptance
ledger. Actual accepted source/run identities and final gate dispositions are
recorded in the PR and #570, with original generated `summary.json` evidence.

## Cheap offline checks

```sh
python3 -m unittest discover -s experiments/driv3r/tests -p 'test_*.py' -v
```

The explicitly skipped real-native test is run by the heavy qualifier. Synthetic
unit fixtures never count as d1 inference or native painting.

## Explicit real qualification

Use the dedicated [workflow](../../.github/workflows/driv3r-stage-a.yml): manual
dispatch, or a deliberate increment of the [request sequence](qualification-request.json)
on `research/570-driv3r-stage-a`. Ordinary code pushes and PR updates run no
model workloads. No #568 training workflow, lease or branch is modified.

The workflow downloads hashes pinned in source, builds the real native extension,
executes both model modes and the deterministic baseline, replays every original
episode through a fresh native World, tests refusal/cancellation and uploads
original evidence. It publishes a uniquely tagged research prerelease after
successful execution; a release tag itself does not establish any acceptance gate.

For an already source-built environment:

```sh
python3 -m experiments.driv3r.backend acquire --runtime-dir /absolute/runtime --evidence /absolute/acquisition
python3 -m experiments.driv3r.qualify --godot /absolute/Godot_v4.7-stable_linux.x86_64 --runtime-manifest /absolute/native-build.json --source-sha FULL_40_CHARACTER_SHA --runtime-dir /absolute/runtime --output /absolute/new-evidence-directory
```

Acquisition strictly reuses an intact existing runtime bundle without rewriting
files. Qualification refuses existing output directories. `--development` permits
explicitly non-qualifying retained-runtime diagnostics; it cannot pass Stage A.

## Evidence and interpretation

`gallery.html` embeds the **original native-material PNG bytes**. These visualize
stored cell IDs; they are not graphical framebuffer captures. `episode.json`
and append-only journals preserve all model answers, full distributions, candidate
order, actual native receipts, requested versus changed cells and terminal causes.
Fuzzy graph completion is separate from creating a useful structure. The ordinary
geometric baseline demonstrates that this simple direct-drive task does not
require a neural controller. No action repair or retry hides poor model choices.

Stage B/C, training, workers/schedules, default promotion, graphical/Windows
qualification, Ready and merging require subsequent Owner direction.
