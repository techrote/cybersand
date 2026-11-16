# WORM-001 — replayable steering baseline (experimental v0)

**Current claim:** a runnable **non-model, non-native** procedural worm. This does NOT establish trained-model steering, Godot/Workbench material readback or completion of the original Art v2 full-scene curriculum.

Authority: [WORM-001 issue #612](https://github.com/techrote/cybersand/issues/612) and [owner pivot in #568](https://github.com/techrote/cybersand/issues/568#issuecomment-6891678794). Keep Draft/HOLD, no production promotion. Native Art host permissions/Stop/Undo/history stay authoritative.

## Tiny v0 contract

- **Observation**: `x`, `y`, `heading`, `local_5x5`, `legal`, `last_actions`, `family`, `tick`. The 5×5 uses `@` at the current cell, `#` for obstacle/out of bounds, `+` for occupied trail and `.` for unvisited floor. Heading IDs: east=0, south=1, west=2, north=3.
- **One raw action**: `STRAIGHT`, `LEFT`, `RIGHT`, `BRANCH`, `RETRACE`, `STOP` (uppercase). BRANCH records a junction and legally takes a fresh arm, RETRACE returns to previous path position.
- **Host-owned safety**: bounded 24–256 grid and at most 4096 steps; deterministic host RNG, obstacle truth, legal move list, Stop and invalid raw choice refusal/fallback. Every tick retains original raw choice separately from applied action.
- **Three non-learned policies**: random legal, deterministic right-hand wall preference, and theme-biased fidget heuristic. They supply controls for future comparisons. No trained model is claimed. External raw action sequence replay is a transport demonstration, not context-sensitive inference.
- **Live model adapter**: `run(..., mode='callback', selector=fn)` invokes `fn(deepcopy(observation))` after host legality is computed on **every step**. The unmodified returned raw text is recorded separately from the applied, host-authorized action; callback mutations cannot change a legal list or receipt. Only a primary worker may supply model-backed `fn`. Non-string results fail rather than being reinterpreted.
- **Outputs**: actual standard-library PNGs and paired canonical JSON traces; each emitted file SHA256 is printed to stdout. These are **source-faithful sandbox rasterizations**, not authentic native Godot readbacks.

## Run locally (Python standard library only)

~~~sh
python3 -m unittest discover -s experiments/agent_painter/worm/common -p 'test_worm.py' -v
python3 experiments/agent_painter/worm/common/worm.py --seeds 11,29 --steps 420 --output /tmp/worm001-gallery
~~~

The second command creates 18 PNG and 18 corresponding JSON outputs: 3 themes × 3 non-model controllers × 2 obstacle seeds. To exercise host refusal, pass `--replay-actions actions.json` containing a JSON array of model strings or a newline-separated list. Invalid actions are visible in receipts; they cannot bypass host legality.

## Live WORM action selection

~~~python
from worm import run

def choose(obs):
    # Replace with one bounded genuine model generation in the primary lane.
    return 'LEFT' if 'LEFT' in obs['legal'] else 'RETRACE'

record = run(11, 'callback', 'pipework', steps=240, selector=choose)
# Compare original raw_choice and host-applied actions; identical seed/budget controls.
~~~

This demo selector is deterministic hand-code, **not learned**. Model primaries must preserve raw completion, pin/model/checkpoint/recipe receipts, bound output size and latency and compare to random/wall/fidget on matched seeds. Invalid choices are contained by the host; do not repair raw output before recording.

## Ownership / next experiments

This common baseline is shepherd-owned at `experiments/agent_painter/worm/common/**`. SPROCKET support owns `worm/support_sprocket/**`; LFM support owns `worm/support_lfm/**`. Primary model workers own their existing `lanes/sprocket/**` and `lanes/lfm25_vl/**`, respectively, plus lane-specific workflows. Coordinate contract changes through issue #612 rather than racing shared files.

The owner explicitly opened a **new WORM-only synthetic TRAIN gate** for the pinned full LFM2.5-VL and SPROCKET models. A real training success requires actual optimizer updates, intact original model pin/processor/license, versioned objective/data/checkpoint receipts and raw held-out first passes. Legacy #568 complete Art program hold/DEV60/FINAL requirements remain separate and unchanged.

Near-term: actual interesting PNGs, honest random/deterministic/learned comparisons, obstacle recoveries, branching and repetition; W4 source-fenced Workbench native integration can follow. Do not claim source-only tests prove a learned model or native operation.

## Fleet evidence interpretation — independent cross-host clock (16 Nov 2026)

The optional `fleet_receipt_v1.summarise_fleet()` counts **supplied telemetry**, not authenticated CPU inference. Four unique claimed PID+runner identities set `four_active_per_wrangler_reported`, but `four_active_per_wrangler_proven` remains **false** until an independent auditor checks immutable original runner/model/source/forward receipts *and* a shared-clock/single-observer cross-runner liveness witness. The stdlib helper cannot elevate synthetic fixtures or self-reported timestamps to proof.

In particular, `monotonic_ns` values from different GitHub VMs **do not share an epoch**. Two locally verified resident models per runner cannot alone certify one global four-way overlap instant. New `active_per_wrangler_runner` and `cross_runner_four_requires_independent_clock_witness` report the missing witness. No native Godot, optimizer, W0 PNG/action semantics or training admission policy changes.
