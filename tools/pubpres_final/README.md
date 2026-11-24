# PUBPRES final physical-progression comparisons

This prospective apparatus measures two new questions: a source change with
two Full-image slots, or the same source's optional two-versus-three Full-image
slots. It does not rerun the rejected Full/Target or Early/Combined experiments.
All results and source changes remain Draft/HOLD.

`run_comparison.py` imports the original V3 observer and reducer unchanged. Its
small GDScript subclass only adds its own source hash, the ring helper hash
(explicitly absent on historical controls), and the requested slot selector.
Every successful arm must still pass the original source, real callback, actual
Rapier step, native completion, exact terrain, actor/input, Water and current-GPU
checks. Previous-history correctness is separately qualified by the actual-size
transition oracle. A successful capture is not a performance acceptance.

The runner requires clean committed application sources, exact-source native
build receipts, the pinned official Godot 4.7 executable and committed Rapier
provenance. Source-comparison builds must have matching native compiler and
dependency identities. The measurement driver and each new registration are
bound to committed bytes. Each arm gets a fresh project/profile and executes
serially; failed arms and original process evidence remain retained. Production
selectors and frozen historical records are not changed.

## Primary commands

From a clean committed successor checkout, with separately built runtimes:

```sh
python tools/pubpres_final/run_comparison.py \
  --control-source /path/frozen --control-runtime /path/runtime-D \
  --candidate-source /path/successor --candidate-runtime /path/runtime-C \
  --engine /path/pinned-godot --output /path/new-evidence \
  --case wave_512_follow --case wave_gameplay_2048_follow --mode source-abba
```

`--mode slots-abba` uses only the exact candidate source/runtime and registers
2/3/3/2 slots. The mandatory control arguments remain explicit but are not
consumed by that same-source mode. `--mode single --slots 3 --sustained` records
a separate minimum 60-second capture. The original 90-second capture ceiling
and independent minimum 144 real completions remain in force. Ordinary short
arms retain the original 10-second minimum. `--rapier-runtime` supplies a
materialized binary, whose bytes must match the committed platform receipt.
Linux graphics may use `--display-wrapper`; Windows uses the direct executable.

`--allow-development-toolchain-drift` is only for explicitly labelled local
development builds. It does not rewrite their runtime receipts or make them
locked-toolchain qualification. Source and dependency closure remain mandatory.

The primary small fixture preserves the historical one-round Wave profile.
The primary large fixture is the accepted two-round Wave/spill/ballistic profile.
Their outcomes are separate cohorts and must not be pooled. The 1024-square,
landscape, PressureFlow and FreeMass confirmations are separately selectable.

## Interpretation

The original strict source-direction rule remains: both candidate rates must
exceed both controls, both candidate p95/p99 gaps must be lower than both
controls, and the worst candidate maximum and severe-gap counts must not exceed
the worse control. This is a directional result for that host and workload,
not proof of playable 60 Hz physics. `SUMMARY.json` always retains
`physical_acceptance: HOLD`; physical Windows/NVIDIA playfeel is separate.

`supplementary.json` adds command-admission-to-step, material-generation-to-
matching-draw-delivery and latest-physical-completion-age clocks. Repeated
commands cannot hide the interval since the first command admitted for a tick.
Superseded material serials are counted rather than assigned an unrelated draw.
These clocks are not hardware input latency, a guarantee of which pose was
displayed, GPU completion or scanout. Native tick duration may contain CPU
preemption. Reported texture bytes are logical allocation, not physical VRAM.

Run the narrow adversarial evidence contract checks with:

```sh
python -m unittest discover -s tools/pubpres_final -p 'test_*.py' -v
```
