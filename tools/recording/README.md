# REC-001 v2 offline A/B evidence review (experimental tooling)

**Status:** experimental standalone observer; no production simulation, recorder, rendering, material policy or replay-contract changes. Targets REC programme #130 / child #135, with PLAY-VAL #134 and TEST-UX #131 as consumers.

## Source admission

Intake: accepted `main` commit `ba9cbc89029be88b812af59b19e5c59829bbcd90`, tree `3af18f50e6094776263119623b64a1b2f4ca0ab2`, on 2026-11-05 UTC. The existing recorder is `godot/scripts/gameplay_recorder.gd` (blob `e2d8d72361d38f48b15a8eba213a72ff7ca68c0d`); contract `docs/operations/gameplay-recording.md` (blob `19d941e3680bc1e91fe2e2233697d748ede6d99f`). Workbench is already accepted on `main` via #394. This tool does **not** create a second recorder: it consumes the existing three-file-per-frame REC-001 v2 output.

No current PLAY/workbench/LCB/SOL/MAT/GEN ownership is claimed, and no files in those subsystems are modified.

## Run

With **two finished** REC-001 v2 session directories (each containing `recording.json`, `frame-NNNNNN.json`, `.ids` and `.bmp`):

```sh
python3 tools/recording/compare_rec001.py /path/to/recordings/A /path/to/recordings/B --output /path/to/new-review
# Optional smaller transport package: --max-frames 48
# Open new-review/index.html in a local browser, keeping its A/ and B/ bitmap subdirectories.
```

The output contains `comparison.json` (manifest SHA-256s, source/native/session identity, ROI/config, drop counts/retained records/omissions, selected frame tick clocks, and descriptive identical-material-generation-tick differences), and an offline `index.html` with side-by-side indexed BMP frames.

**Alignment is by elapsed monotonic time since each independent session start, not by synchronized input or an authoritative simulation clock.** The viewer displays the last retained frame not later than the selected elapsed time, including its age. Material generation tick/serial and actor sample tick are kept separate: later actor-only movement cannot be silently relabelled as fresh material. Numerical per-cell differences are only calculated for identical fixed ROI + stable scenario ID/definition/seed/mode/recipe and unambiguous corresponding material-generation ticks. They are **descriptive**, not proof of causality, solver correctness or deterministic replay. Different source, runtime, worker, profile or input trajectories require human qualification before any physics conclusion.

Incomplete sessions are shown with warnings, not converted into passes. Drop counts and the original bounded event ledger survive in JSON (with any omitted-record count). Downsampled review frames are explicitly counted. Raw source `.ids` remain in the original session; review copies only sampled BMPs. Temperature, visual-condition channels, and hidden native state remain unavailable. Player/rig rotation is preserved as metadata but the recorder's original review BMP outlines remain unrotated.

## Refusal and resource bounds

The tool rejects unsupported v1/unknown evidence, noncontiguous or mismatched frames, missing raw IDs, wrong byte size, invalid indexed BMP, nonmonotonic capture elapsed timestamps, unexpected path components, symlinked frame input and existing output. It caps frame inventory at 2,000 per input, aggregate metadata at 64 MiB, single JSON at 2 MiB, ROI at 1,048,576 cells, selected frames at 240 per side and copied BMPs at 64 MiB. The destination must be new and outside either recording. Inputs are read-only and never mutated.

## Local experiment (not host qualification)

```sh
python3 -m unittest discover -s tests -p 'test_compare_rec001.py' -v
python3 -m py_compile tools/recording/compare_rec001.py
```

At intake, the Python 3.13.5/Linux x86-64 local run passed **9/9 synthetic fixture tests**: same-tick material-byte difference, separate actor/material clocks, dropped counts, manifest integrity, rejected traversal/malformed frames/unsupported schema, refusal on bad timestamp, session nonmutation, mismatched scenario and output bounds. Source tool SHA-256: `82f95d9409f9db5f579192d758f1a0e3d412ee3771f8b1eede73c950657098a5`; test file SHA-256 `ba8f9a7c6cba4b371d0dfa20f0e204115470c2481f42192f30cb5c21c2fe0852`.

**Not executed:** live Godot/native desktop capture, Windows host qualification, actual F10 recording, headless Godot suites, controlled recorder OFF/ON overhead measurement, Linux/Windows native worker parity, original gameplay fixture capture, and real human feel comparison. Neither this tool nor its synthetic tests close #135. Exact-head CI and independent review remain pending until separately observed.

## Next gate

Acquire two real, matched `rem003/player-granular-review` desktop recordings, one with a falling-material event, verify manifest/runtime/source IDs and actual drop clocks, and test the offline comparison against those outputs. Then execute the **separate** matched recorder OFF/ON performance qualification required by #135 (do not infer low overhead from an offline viewer). Record the observer's human gameplay assessment separately.
