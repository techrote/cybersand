# MAT-AUTH/SOL investigation probes

These are independently authored diagnostic apparatus, not a compatibility
checkpoint, production import or CI bypass. The frozen A-only guard is unchanged.
The [dated dossier](../../../docs/audits/2026-11-04-mat-sol-protected-consumer-review.md)
records REPAIR and all raw positive/negative results. Run probes against pinned
source in a separate checkout; never alter another session's active #347 worktree.

## Native comparison

Compile `mat_sol_legacy_probe.cpp` with the same C++20 compiler against each
source tree's `native/src/world.cpp`, `material_rules.cpp`, `scheduler_geometry.cpp`
and `settled_world_discovery.cpp`, and that tree's `native/include`. Use `-pthread`,
`-O1 -Wall -Wextra -Werror`; add `-DMAT_SOL_EXTENSION=1` only for the SOL source.
The exact compiler commands and binary hashes are retained in
`docs/audits/mat-sol-20261104/legacy-v2/builds.json`.

Invoke the binary with two arguments: worker count `1` or `4`, and mode
`disabled`, `idle`, `invalid` or `reset`. Main needs only `disabled` and `reset`;
compare its disabled run with SOL's disabled/idle/invalid runs of the same worker
count, and reset with reset. Each successful run emits 413 JSONL observations.
Compare every field exactly except `workers_observed`, which is scheduling
telemetry and remains recorded. Compare the two worker counts separately.
Do not mistake equal measured observations for universal physical equivalence.

The first apparatus incorrectly compared a masked physical hash with a save
which intentionally omits transient host masks. Its failed source/results remain
retained. The final probe records that distinction, preserves exact native save
round trips, and requires restored physical equality when no host mask is active.

## Godot facade boundaries

Authenticate the native runtime's complete bytes against the pinned SOL LFS
pointer and all 88 `source_inputs` in its published runtime provenance. Verify
the Godot archive size/SHA-256 against `third_party/godot-runtime.lock.json`,
the extracted editor against the archive and `--version` against the exact pin.
The retained experiment uses Linux; new Windows execution remains required.

Create an otherwise empty private project with this `project.godot`:

```ini
config_version=5
[application]
config/name="MAT-SOL boundary investigation"
[rendering]
renderer/rendering_method="gl_compatibility"
```

Copy the unchanged SOL `cybersand_native.gdextension` and verified runtime into
the same relative `addons/cybersand_native/` paths as the source project. Copy
`mat_sol_godot_boundary_probe.gd` to `probe.gd`. Create `.godot/extension_list.cfg`
containing only `res://addons/cybersand_native/cybersand_native.gdextension`.
No source/runtimes are edited and no Rapier library is necessary for this
native-facade fixture. It deliberately uses synthetic, source/shape-bound body
receipts; it does not test a live Rapier body or physical contact clearance.

Run each case in its own process with a 30-second watchdog and core dumps
disabled. Invoke the pinned editor as:

```text
GODOT --headless --path PRIVATE_PROJECT --script res://probe.gd -- PHASE CALL WORKERS
```

Phases are `disabled`, `idle`, `prepared`, `acknowledged`, `committed`,
`restored`, `active`, `cancel`, `rollback`, `reset`; workers are 1 or 4. Use
`physical`, `liquid1`, `liquid2`, `export`, `diagnostic` for every phase.
Add `window` at Idle through Active, and `adhesion` at Idle through Restored.
This yields 122 independent child processes. All fixture/transition operations
must succeed, the final native phase must match, and the actual 520 cells/six
proxies must be checked before target calls. Retain complete stdout/stderr,
return code, timeout and markers; do not continue a crashed process.

An uncaught C++ exception is observed as SIGABRT/return -6 under Python's process
API (often 134 through a shell). It is a product failure even when expected by
this investigation. `MAT_SOL_BEFORE_CALL` without `MAT_SOL_AFTER_CALL` distinguishes
the target abort from setup failure. For adhesion, the probe completes cancel or
rollback before exporting native CYPS, imports it into a different adapter and
compares the resulting authoritative value with the first facade's cached value.
The original frozen guard must still fail on the SOL composition afterward.

The full matrix receipt records the exact probe, editor, runtime, source and
per-case results. Earlier malformed-argument/private-project setup failures are
separately retained and excluded from SOL causal claims.
