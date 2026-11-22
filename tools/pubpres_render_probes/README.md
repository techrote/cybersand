# Isolated PUBPRES renderer diagnostics

**Draft/HOLD; diagnostic only.** This bundle investigates pinned-engine font
upload, Separate/ANGLE startup, and queued material-history byte failures.
It does not run CyberSand's native simulation, Rapier, gameplay observer or
pacing experiment. It never qualifies a package, native build, performance
improvement or physical Windows/NVIDIA acceptance. Expected crashes and pixel
negatives remain failed arms and make the aggregate command return nonzero.

The source is a small standalone font project and a standalone material project.
The material publisher, shader and original queued fixture are frozen exact
copies from `a7074ab1bb4fede30d75a7924b4a5bfb7ea963d1`; their complete hashes are
in [the copied source manifest](projects/material/copied-source-manifest.json).
The runner checks those hashes independently. Production `godot/`, native
sources, defaults and the original fixture are unchanged.

## Dependencies and early execution

Only Python 3.11+, the exact official Godot
`4.7.stable.official.5b4e0cb0f`, and the existing process ownership helper are
required. Linux additionally needs Xvfb and the separately reviewed
`tools/pubpres_playability_build/owned_xvfb.py` in the same committed checkout.
Windows uses its hosted desktop and the direct official GUI executable. The
console executable is a launcher with a different PID and executable hash;
it is not the diagnostic process. Both official ZIP members are still verified. No
godot-cpp library, compiler, CyberSand DLL/SO, Rapier runtime, export template,
native import, package assembly or CI module is imported by the runner.

Run after the existing engine downloader and process/display prerequisites,
**before expensive native builds**. Preserve `ENGINE.json` and its original
official ZIP beside the executable. The runner verifies the pinned archive,
archive members, extracted executable hashes and download receipt. It also
checks the exact committed driver and project inputs. Each arm receives a fresh
project copy containing only the admitted source files and an isolated profile.
Both script receipts assert that `GDExtensionManager.get_loaded_extensions()`
is empty. These projects do not require repository LFS runtime materialization.

## Invocation

Linux, from the final committed source checkout with the owned display helper:

```sh
python tools/pubpres_render_probes/run_probes.py \
  --source-root . --source-sha <full-40-character-source-commit> \
  --platform linux --engine <engine-directory>/Godot_v4.7-stable_linux.x86_64 \
  --display-wrapper tools/pubpres_playability_build/owned_xvfb.py \
  --output <new-output-directory>
```

Windows PowerShell:

```powershell
python tools/pubpres_render_probes/run_probes.py `
  --source-root . --source-sha <full-40-character-source-commit> `
  --platform windows --engine <engine-directory>/Godot_v4.7-stable_win64.exe `
  --output <new-output-directory>
```

The output must not exist. The exact requested source must be checkout HEAD.
Linux requires the checked-in owned display helper; shell `xvfb-run` is not an
accepted substitute. The helper is integrated separately from this bundle.
There is no headless graphical qualification mode or automatic renderer fallback.

## Finite invocation matrix

Each row is a fresh process. Linux uses `opengl3`; Windows uses
`opengl3_angle`. Both request Compatibility, Dummy audio and explicit
Safe/Separate ownership.

| Platform | Arm | Thread | Font / material setting |
| --- | --- | --- | --- |
| Linux | font-safe-text | safe | Ordinary font atlas; mipmaps off |
| Linux | font-separate-text | separate | Ordinary font atlas; mipmaps off |
| Linux | font-separate-text-mipmaps | separate | Pinned font upload Image-copy branch |
| Linux | font-separate-empty | separate | Empty draw control |
| Windows | font-safe-empty | safe | Empty startup control |
| Windows | font-separate-empty | separate | Separate/ANGLE startup control |
| Both | material-safe-r8-slots2-reachable | safe | R8, reachable, two slots |
| Both | material-safe-r8-slots3-reachable | safe | R8, reachable, three slots |
| Both | material-separate-r8-slots2-reachable | separate | R8, reachable, two slots |
| Both | material-separate-r8-slots1-reachable | separate | R8, reachable, one slot |

Linux runs eight arms; Windows runs six. Each actual Godot child has a fixed
**60-second** deadline. `OwnedProcess` supplies bounded cleanup. An enclosing
180-second owner allowance includes private display readiness and cleanup; it
does not extend the Godot child deadline. Existing native and gameplay watchdog
allowances are unchanged.

Ordinary nonzero exits, missing script receipts, timeouts, startup errors and
pixel failures are retained, and later arms still run. Cancellation or uncertain
process ownership is terminal: remaining rows are explicitly recorded as not
run, and the aggregate fails. A negative arm's clean display teardown is recorded
independently of its failed application result.

## Receipts and original pixel oracle

`INPUTS.json` binds the full source/tree, driver/project files, frozen a707
inputs and exact engine. Per-arm outputs include `arm.json`, `request.json`,
actual `process.json`, enclosing `outer-process.json`, stdout/stderr,
`godot.log` when available, `receipt.json` when the script completes, and
`analysis.json`. Linux also retains `display-owner.json`. The aggregate
`SUMMARY.json` is written incrementally and finally. A complete matrix may
contain failures: `matrix_finished`, `all_arms_attempted` and `all_passed`
have distinct meanings. The command returns zero only if every arm passes.

The nested child owner records the actual Godot PID directly, including behind
the Linux display wrapper. A completed script receipt must match that PID,
source commit, per-arm nonce, engine executable hash, script/project hashes,
driver, requested rendering owner and native-independent assertion. A startup
crash may have no script receipt; its process status and raw error remain the
result. No receipt or PID is invented. Raw captures/logs are hashed in the arm's
analysis record.

The font probe completes 64 draws. Text arms issue 6,016 glyph calls and use the
engine's built-in font; empty arms issue none. A completed run reads the real
1024×640 viewport. The mipmap arm is an ownership isolation control, not a
proposed UI setting or product workaround.

The material diagnostic inherits the frozen `_queued_history_case` without
changing its publication loop, caller-image poisoning, ring wraps or queue gate.
The original two first reads and complete byte comparisons are identical.
There are 30 publications with two slots, 42 with three, and 18 with one.
Independent CPU reconstruction also checks the expected final current/previous
hashes. Only after the original oracle does the diagnostic collect:

- An immediate repeated current read, before capture hashing or disk I/O.
- First current/previous and expected raw bytes.
- Every slot of the ordinary capacity-4, history capacity-4 and full-image pools.
- Current bytes after staging reads and both histories after a later real draw.

Later exact pixels cannot repair an earlier failed comparison. There is no
renderer reset, forced draw, new await or readback inside the publication burst.
Selected-case diagnostics cannot replace the original complete twelve-case
queued fixture. Layer reads are another engine readback path and change GL
state after the first oracle; interpret them as observations, not proof that
the readback implementation is flawless.

## Validation and limits

Run focused helper controls with:

```text
python tools/pubpres_render_probes/test_probes.py
```

Syntax can be checked with the exact engine using `--headless --check-only`
and either project's script. Parsing does not execute a graphical arm. Actual
Windows Job ownership and both hosted graphical matrices require execution on
their respective host. The branch's local validation record reports what ran.

No source repair is selected by this bundle. The original Linux upload crash,
Windows startup failure and queued pixel negatives retain their separate
scopes. A passing finite probe cannot prove a race absent, qualify Separate,
erase a failed first read or establish native/playability acceptance.
