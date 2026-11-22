# PUBPRES-PLAYABILITY-003 causal measurement

The frozen PUBPRES-001 v2/v3 registrations, observers and reducers remain in
`tools/pubpres_playability`. This directory holds additive PUBPRES-003 evidence
tools. No retained receipt is rewritten or relabelled as a new execution.

## Retained-trace audit

`audit_traces.py` accepts extracted original campaign artifacts containing
`campaign.json`, arm/receipt/trace/analysis JSON, process receipts and the two
original framebuffer PNGs. It first reruns the unchanged v3 validator, including
real actor/body ownership, native response/terrain identity, fixed-step callback
credit, actual participating workers, input leases, Water ledger, registered
fixture and strict framebuffer hashes. It then independently recomputes the
selected timing statistics for all three registered windows and checks them
against the retained original analysis and the frozen reducer's fresh output.

```sh
python tools/pubpres003/audit_traces.py /path/to/retained/extracted \
  --output /path/to/new-evidence/retained-trace-audit.json
python -m unittest discover -s tools/pubpres003 -p 'test_*.py' -v
```

The output path must be new. Failures remain explicit records and return a
nonzero exit code. The tool does not re-run archived binaries or claim that
source hash receipts alone prove current runtime identity. Original ZIP hashes
and download custody remain separate records. Pairing checks bind source,
native runtime, engine, CPU/adapter, fixture, Water profile, worker count and all
non-intervention selectors. Equal-step body trajectory and admitted-move hashes
must agree before paired attribution is admitted.

The first healthy handoff is joined by native World, tick, body sample and
required terrain revision. Repeated status publications cannot reset its age.
The v3 worker trace does not expose session/epoch or actual Main mailbox
observation and terrain-install boundaries; unavailable causality remains
unavailable. Prefixes with no completed step retain their full censored freeze
duration. No step is inferred from an attempted continuation or a draw callback.

Rates are computed per run. The report averages paired run-level rates but
retains each run's gap quantiles. It does not pool different workload profiles,
platforms or intervention types, and does not average p95/p99 values.

## Prospective causal seams

PUBPRES-003 adds bounded, explicit diagnostic observation at existing Main and
worker boundaries. These observations must preserve their own source/runtime
identity and remain separate from the frozen v3 apparatus. Required joins are:

- Native request/start/completion and participating worker work.
- The first healthy immutable mailbox packet for the exact World, session,
  epoch, native tick, body sample and required terrain revision.
- Each existing mailbox read, including empty, contended and mismatched packets.
- Existing terrain queue/budget calls and their before/after pending counts;
  the queued revision alone is not evidence of a completed install.
- Final admitted packet immediately before the ordinary Rapier transaction,
  followed by the existing genuine completed-step/body/credit oracle.
- Material publication and Main/camera/draw callbacks, with no assertion of GPU
  completion or physical scanout from `frame_post_draw`.

The diagnostic must perform no additional mailbox reads, install work, physics
callbacks or solver work. No failed or unavailable boundary becomes a zero-time
success. Measurement is enabled explicitly and compared with the same-source
diagnostic OFF path to expose observer overhead.

## Focused hosted captures

`run_focus.py` stages a single exact committed source with its exact native build
and committed Rapier identity. It reuses the original strict v3 gameplay oracle
and fixed fixture/input/capture rules. The new observer is a separately hashed
derived script. Its primary trace retains the v3 contract; causal events live in
another bounded JSONL with source, fixture and primary-trace bindings. A native
and terrain gate observation is called `transaction_entry`; only a separately
validated genuine `rapier_step` supplies completed-step credit.

Run these sequentially in one hosted job. Each timed arm uses a new project and
profile; no simultaneous heavy CI job belongs in a paired comparison.

```sh
python tools/pubpres003/run_focus.py \
  --source /path/to/exact/source --runtime /path/to/native-build \
  --engine /path/to/Godot_v4.7-stable_linux.x86_64 \
  --rapier-runtime /path/to/source-matched-rapier.so \
  --display-wrapper tools/pubpres_playability_build/owned_xvfb.py \
  --mode baseline --case wave_512_follow --case wave_2048_follow \
  --case wave_gameplay_2048_follow --output /path/to/new-baseline
```

On Windows, use the pinned GUI executable and source-bound Rapier DLL; omit the
display wrapper. Compatibility/OpenGL, Safe, eager staging, four workers,
1600×900, VSync OFF, 60 requested callbacks/s and 60 presentation cap remain
fixed. Each capture retains at least ten wall-clock seconds **and** 144 real
Rapier steps, with a 90-second capture ceiling and 240-second setup deadline.

Then run `--mode causal --case wave_gameplay_2048_follow` into a new output
directory. It explicitly enables both causal observations and the native stage
probe; that single diagnostic arm is not an OFF/ON speed comparison. Mode
`native-probe-abba` isolates native probe overhead, including the separately
registered current-gameplay case; `causal-overhead-abba` isolates the additive
observer. `same-frame-abba` retains the old continuation experiment as a control.
Each ABBA order is OFF/ON/ON/OFF with all other selectors fixed. Equal-step
physical trajectories and admitted moves must match before causal attribution.

All modes are development captures and report physical acceptance HOLD. The
default native validator rejects compiler drift. A local diagnosis can opt in
explicitly with `--allow-development-toolchain-drift`; it still verifies exact
source/tree, complete native inputs, actual binary, build log and dependency
custody, and labels the result `DEVELOPMENT_TOOLCHAIN_DRIFT`. Such a capture
cannot replace the final pinned hosted builds or Windows/NVIDIA owner trial.

The independent causal reducer refuses altered sidecars, wrong owner/sample or
terrain joins, duplicated completion credit, fabricated admission authority and
overflow. Unknown producer identities at early boundaries remain `-1`; missing
edge observations remain unavailable rather than becoming zero-age packets.

Each receipt must match the specific requested fixture, Water variant/profile,
camera, workers, renderer/thread, input, and fixed full-observer/repeated-callback
apparatus. Being another valid registered case is insufficient. Every planned
arm must complete in order, and the frozen reducer's complete hardware/workload
matching map must be identical across the comparison. A repaired validator can
audit retained captures separately; it must not rewrite their original driver
identity or failure record.

## Native-phase diagnosis before graphical qualification

`native_probe.py` runs the unchanged frozen v3 observer with the active
`reference2048`/`gameplay_main846f` fixture under explicitly headless Godot. It
checks exact fixture hashes, the original input tape, real actor/Rapier/native
sample and terrain identities, four participating native workers, callback
credit, Water accounting, two native rounds, spill and ballistic transport.
Native current-gameplay parameters and requested/effective treatments are fixed.

```sh
python tools/pubpres003/native_probe.py \
  --source /path/to/exact/source --runtime /path/to/native-build \
  --engine /path/to/pinned/Godot --rapier-runtime /path/to/matched/rapier \
  --output /path/to/new-native-diagnostic
```

The original graphical validator's refusal is retained. The independent native
checks are not a relaxed graphical pass, and headless step rates cannot qualify
playability or camera/material freshness. Their purpose is to distinguish the
native column, flux, apply and preparation costs before spending hosted graphics
time. Compare the same first 144 physical steps as well as the first ten seconds;
faster runs can reach a different amount of settled Water within a time window.

Identical actor trajectories and admitted moves do not establish complete live
material-map parity. `water_identity().construction` describes the prepared
source. A separate exact-module native differential corpus must compare actual
live World state and inventory before a native correction is accepted.
