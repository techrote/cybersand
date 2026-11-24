# Optional submitted-presentation and CPU observations

**Draft / HOLD.** These observers supplement the independent completed-Rapier
oracle. They do not relax any native/body/terrain/input or process-ownership gate
and do not run in ordinary production Workbench.

## Observation boundary

`presentation_probe.gd` reads Main's already submitted overlay copy, camera and
selected physical-step history at `RenderingServer.frame_pre_draw`. The exact
Godot 4.7 source asserts that this signal is emitted on Main before either
queuing Separate draw or executing Safe draw:
[RenderingServerDefault::draw](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/servers/rendering/rendering_server_default.cpp).
It reads no World and calls no PhysicsServer, native exchange, mailbox, upload,
ACK, camera update or simulation method. Per-callback cost is recorded. Arrays
are bounded to 6,000 pre-draw submissions, 6,000 notifications, eight bodies and
512 overlay parts; loss/truncation refuses qualification.

The independent reader joins each known selected pose and Follow target to its
actual completed physical step in the original trace, including body RID and
authored instance identity. Its primary completion age uses the independent
Rapier event time; Main's separate completion clock must fall within that real
step's execution interval. Material age joins the latest actual texture-upload
serial, World and generation clock. Pre-capture poses and materials remain
explicitly unjoined, with source-reported ages kept separate.
The first visible overlay part also carries its full actual transform and the
actual `CollisionShape2D` node, parent body node/RID, local transform and shape
dimensions. The reader independently composes the selected physical matrix
with that local matrix for `rectangle_union`; the ordinary rectangle/circle
branch must submit the selected matrix unchanged. Production session, rig and
overlay bytes are all included in the executed identity. Collider identity and
local geometry must remain stable throughout these registered static actors.
Float32 compound multiplication permits four ULPs, four float32 epsilons
times the sum of absolute operand products (including translation), or an
absolute `1e-7` near zero. The operand bound covers cancellation under
multiply/add contraction; this is an arithmetic allowance, not a gameplay
position tolerance. Unsupported geometry remains explicitly
unverified, and the registered ordinary workload runner refuses qualification
if any visible first part lacks this proof. Additional compound parts are not
individually checked and no report may imply that they are.
Reports include submitted pose step lag, completion age, intentional holds,
withholding episodes, Follow lag/holds, material age and independently
recomputed overlay/shader projection residuals. A currently selected physical
step can itself be old because physics has stalled; these observations must be
read beside real completion gaps.

The post-draw hook records a separate delivery event. Only inline Safe delivery
can associate the preceding Main submission. Separate's deferred notification
always has submission index -1. Neither signal is a GPU fence, physical display
scanout, measured display refresh or input-device-to-visible response.

`execute_with_resources.py` is an explicitly derived copy of the retained
process runner. `execution_contract.py` pins its original source and verifies
every changed function byte: only same-iteration process CPU reads, bounded
state and a sidecar writer are added. Original process ownership, child cleanup,
cancellation, timeout, output and diagnostic gates remain exact. Windows
`GetProcessTimes` handles are closed within each iteration; Linux reads process
`utime`/`stime`. All Godot threads are included, other processes are excluded.

CPU records use their own process-lifetime sampling clock. They include scene
setup and capture; there is no join to Godot's independent clock and no claim of
capture-window-only CPU. First/last raw accounting counters, creation identity,
PID, interval delta, core equivalents and maximum sample gap are retained.
Unobserved launch/exit tails receive no estimated credit. Last cumulative
counters are lower bounds on lifetime CPU. GPU busy time is not measured.
Successful and failed CPU query durations are retained as external sampler wall
cost, with total and maximum read duration. They are not added to Godot CPU.
The sample's elapsed timestamp marks its query request, not an instantaneous
kernel accounting timestamp.

## Driver integration

Add this directory to the driver's executed-source inventory, call
`bundle.identity()` and record its file hashes in the comparison manifest.
Stage the helper with `bundle.stage(project)` before import; it becomes
`res://tests/pubpres_final_presentation_probe.gd`. Every matched arm must use the
same explicit `CYBERSAND_DIAG_PRESENTATION_OBSERVER=1` setting and helper bytes.
The observer's source identity must include the helper hash, and both requested
selector observations must include this setting. Frozen sources remain intact.

The small integration in an observational SceneTree subclass is:

```gdscript
const PresentationProbe = preload("res://tests/pubpres_final_presentation_probe.gd")
var presentation_probe = PresentationProbe.new()
var presentation_enabled := OS.get_environment("CYBERSAND_DIAG_PRESENTATION_OBSERVER") == "1"

func _initialize() -> void:
    super._initialize()
    if presentation_enabled:
        RenderingServer.frame_pre_draw.connect(_presentation_pre_draw)

func _presentation_pre_draw() -> void:
    if host != null and host.common_active and host.common_detailed:
        presentation_probe.observe_submission(host)

# Add to the existing, unchanged draw-notification observation:
# if presentation_enabled: presentation_probe.observe_draw(host, actual_inline)

func finish() -> void:
    if RenderingServer.frame_pre_draw.is_connected(_presentation_pre_draw):
        RenderingServer.frame_pre_draw.disconnect(_presentation_pre_draw)
    if presentation_enabled:
        var result: Dictionary = presentation_probe.write(
            output.trim_suffix(".json")+"-presentation.json",
            source_before,capture_start,capture_end)
        check(result.complete,"bounded submitted presentation sidecar retained")
    await super.finish()
```

Use `execute_with_resources.execute_with_resources` with the original execution
arguments. After the complete original physical oracle passes, call
`bundle.validate(receipt_path, process_result, staged_project)` and retain its
returned analysis plus both raw sidecars. It independently rechecks source,
actual executable, PID, owner, capture bounds, body identities, completed poses,
Follow targets, notification association and cumulative process CPU arithmetic.
Preserve failed or missing sidecars; do not label an older run instrumented.

## Focused checks

```sh
python3 -m unittest discover -s tools/pubpres_final_observers -p 'test_*.py' -v
python3 tools/pubpres_final_observers/bundle.py --verify
```

The tests include an actual short owned Python child for process accounting and
cleanup, plus independent source/pose/Follow/RID/clock/cost/Separate-notification
tamper controls. That child is not a substitute for actual Godot qualification.
Run the same tests on Windows to exercise `GetProcessTimes` inside the real
Windows Job owner. Godot parser checks and actual hosted observer integration
are separate gates; no graphical result is inferred from a synthetic fixture.
