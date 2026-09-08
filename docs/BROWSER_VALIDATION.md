# Chromium smoke flow

**Status: Current procedure, reviewed 2026-09-08.** This workspace guide covers
interactive Chromium acceptance of an identified local Web export. The dated
results below are historical checkpoint evidence; this documentation audit did
not execute a browser. Use [source identity](../source/docs/operations/source-checkpoint-and-recovery.md)
for the established checkout and [validation evidence](../source/docs/reference/validation-evidence.md)
for dated Windows/browser checks. Existing-export checksums do not prove current browser acceptance.

Use the [Web profile guide](../source/docs/operations/web-threading.md) for
compatibility/threaded build and hosting requirements. Both profiles currently
include Rapier2D; Web ticks synchronously on the Godot main thread, with native
parallel jobs in the threaded profile. Fully asynchronous Web ownership is
**Deferred**. This page owns the interactive smoke procedure, not the threading
or replay contract.

Start from `C:/kybersand` and select the export explicitly:

```powershell
python preview.py --directory source/build/web --port 8000 --open
# For the threaded export, use source/build/web-threaded and a distinct port.
```

`0Preview.cmd` / `python preview.py --open` can select `static-web/` when present;
they do not by themselves prove that the browser uses the rebuilt output.
Record the export directory, URL, profile, date, browser version and OS. Verify
its `SHA256SUMS` entries and retain `build-info.json` with the relevant build
logs and source fingerprint. Its `source_commit` may name only the acquisition
base while the tree contains local changes; it is not proof of a current Git commit. See the
[builder](../source/tools/build_web.py), especially `main`'s identity/manifest
generation, and the [audit evidence](../source/docs/audits/2026-09-08-documentation-audit-evidence.json).

Open `http://127.0.0.1:8000/` with Chromium's console open; reload after an export
change. Append `?test=1` for the existing opt-in acceptance diagnostics. The JSON
DOM element `#cybersand-test-state` mirrors them for read-only browser tools.
Normal play URLs do not expose these diagnostics.

1. Confirm the main menu says `CYBERSAND/WASM` and `RAPIER2D`, with `COMPAT` /
   `1 WORKER` for compatibility or the threaded profile and Auto's actual worker
   count for threaded builds. Physics Pit should be
   enabled and `WEB_RAPIER_PROBE` should pass. Record the console's Godot version
   and verify Godot `4.7.stable.official.5b4e0cb0f` and Emscripten `4.0.20` against
   the identified export's build information, checksums and build logs. The
   Godot console alone does not establish compiler or complete build identity.
   With `?test=1`, also require
   `WEB_CPP_EXCEPTION_PROBE true`, proving a real native C++ exception is caught
   safely by the WASM adapter. The normal URL does not run that probe.
   Add `&rapier=1` to run the shared 600-tick coupling/lifecycle/save fixture;
   require `rapier_test.ok=true`. See the
   [Rapier runbook](../source/docs/operations/rapier-2d-migration-runbook.md).
2. Launch Material Lab, Waterworks, Foundry and Neon Works. Confirm increasing
   native tick/movement counts and changing liquid/fire/sand. Inspect shaders,
   textures, neon/glow, player visibility and spawn clearance. Magenta neon
   strips are intentional; a whole magenta fallback surface is not.
3. In Neon Works at the normal quality profile, press 3 for wall and paint near native cell
   (420,25), above the installation. `probe` should become 1. Erase with RMB;
   it should become 0. A/D should move the cyan player; Space powers its jetpack.
   P pauses, Esc opens the menu, R and Restart world reset the level. Hold inputs
   long enough to span simulation ticks; instantaneous automation taps can miss
   a tick. Do not infer held-input failure from a single zero-duration tap.
4. Select LOW, NORMAL and HIGH; diagnostics should show logical view sizes
   320×180, 480×270 and 640×360. Check the canvas fits a desktop viewport and
   scales proportionally in a narrow panel. Restore NORMAL for later checks.
5. For a **non-body level** (Material Lab, Waterworks, Foundry or Neon Works),
   mutate the level, pause it, open Save / Load and Export Current. Preserve the
   full Base64 string. Save Slot too. Switch to a different world; verify the
   mutation is absent. Return to Save / Load, import the preserved Base64 and
   re-export without advancing the simulation. Compare **the entire string**,
   not just the demo name or a success message. This verifies level/metadata
   restoration, not deterministic future replay. For **Physics Pit**, use the
   shared `?test=1&rapier=1` fixture: it requires exact decoded cellular payload
   restoration, each of the six numerical body components within `1e-5`, and
   exact sleep flags. Angle/matrix reconstruction can round, so the complete
   body-bearing Base64 string need not match. See
   [web_rapier_probe.gd](../source/godot/scripts/web_rapier_probe.gd) `run`,
   [web_demo_controller.gd](../source/godot/scripts/web_demo_controller.gd)
   `_encode_current` / `_import_decoded`, and the
   [save/replay contract](../source/docs/operations/testing-validation-and-replay.md).
   CYSD1 omits complete native scheduler and Rapier contact-cache state; exact
   replay persistence remains **Planned**.
6. With the paused non-body level and its export retained, replace the field
   with `a` and Import. Require `Malformed Base64`. Re-export and compare against
   the prior string: the level must be unchanged. Also exercise corruption
   rejection through [test_web_demo_setup.gd](../source/godot/tests/test_web_demo_setup.gd).
7. For the same non-body level, switch/reset again, Load Slot, and compare a new
   export against the saved string. Reload the browser, Load Slot, and repeat
   the exact comparison before claiming persistence. Use the same origin, port
   and browser profile.
8. Inspect the console for new errors/warnings. Verify successful browser
   requests for `libcybersand_native.web.nothreads.wasm` in compatibility or
   `libcybersand_native.web.threads.wasm` in threaded mode, plus the appropriate
   `godot_rapier.wasm`. Bind those requests to the export manifest recorded
   above; a PCK download or an HTTP smoke pass is not browser runtime acceptance.
   Record input actions, observed state, diagnostics, console output and any
   unperformed checks separately from passes.

## Historical observations and limits

The [2026-09-07 browser record](../validation/browser-results.json) describes the
earlier compatibility-only export with Physics Pit disabled. It is not evidence
for the current Rapier-enabled profiles.

On 2026-09-07 the connected Chromium 152 browser passed all four demos, native
painting/erasing and movement, quality/restart, exact 23,040-character Base64
restoration, malformed-save preservation and local-slot persistence across reload.
The test used the retained export field for portable import. This browser
automation interface did not deliver external clipboard paste into Godot's
canvas TextEdit; external paste interoperability is not claimed by that result.
Held jetpack input and browser restart persistence were also unverified. The
same record says input/save checks preceded the final clean rebuild; four demos
and the exception probe were repeated afterward, with an identical side-module
hash. See the preserved [setup report](../LOCAL-DEV-SETUP-REPORT.md) for its scope.

The [2026-09-08 Rapier record](../validation/local/rapier-web-20260908/browser-results.json)
reports 600 ticks in Chromium compatibility (1 worker) and threaded (6 workers),
308,087 cellular contacts and 151 displaced cells, with no reported browser
errors/warnings. Its three-rectangle fixture covers lifecycle and the exact
cellular/tolerant body restoration described above, allowing about 1.32 px
transient floor penetration. It does not establish arbitrary-shape coupling,
exact Rapier replay, or high-count performance. That summary lacks a complete
immutable source/export manifest; consult the [Rapier runbook](../source/docs/operations/rapier-2d-migration-runbook.md)
for evidence details. Earlier worker parity and Auto benchmarks are scoped in
the [Web profile guide](../source/docs/operations/web-threading.md).

Firefox and Safari remain untested. Current browser acceptance requires a new
record tied to the actual source and served artifacts; historical successes and
the audit's 18/18 checksum matches for each retained export do not supply it.
