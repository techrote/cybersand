# Explicit font publication engine experiment

**Draft / HOLD.** This is a third, separately identified engine. Official Godot
4.7 and the original `cybersand_egl_handoff` engine remain unchanged. It is not
included in the ordinary evaluator and has no application or physical NVIDIA
qualification until the corresponding execution receipts exist.

The first built artifact is retained unchanged after a pre-execution reader
failure on Git's equivalent brace/hunk alignment. The
[strict canonical-edit correction and artifact replay](../../docs/audits/2026-11-24-pubpres-playability-final/font-engine-patch-reader.md)
preserve exact changed bytes, coordinates, file/mode closure and every other
engine provenance gate. Any focused retry must keep application/build and
changed driver identities separate; the original failed job remains evidence.

## Scoped repair

The original pinned TextServerAdvanced and TextServerFallback pass their mutable
glyph-cache Image to ImageTexture creation and updates. Separate rendering can
retain that reference after the font mutex is released. Another glyph modifies
the same Image while the render owner copies its byte array. Godot's CowData
copy-on-write temporarily clears its buffer pointer while allocating a new one;
an unsynchronized reader can observe empty data despite nonzero Image dimensions.
The GLES upload then indexes byte zero. See the source and recovered negative
evidence in the [second-campaign audit](../../docs/audits/2026-11-24-pubpres-playability-final/second-campaign-renderer-and-evaluator.md).

`godot-font-image-snapshot.patch` adds a private Image at all five publication
boundaries in each of the two text servers: the explicit texture setter, glyph
texture RID lookup, glyph texture size lookup, glyph draw and glyph outline
draw. Duplication occurs after the existing alpha-edge and mipmap preparation.
If mipmap preparation already made a private Image, no second copy is created.
The font cache, glyph layout, colors, mipmap policy and shader inputs retain their
existing behavior. Queue ordering, Main/render synchronization and material
publication are unchanged. Image storage still uses Godot copy-on-write; the
queued resource no longer shares the mutable Image object itself.

The patch is tied to exact upstream blobs and output SHA-256 values. Original
EGL repair and all compiler/dependency flags are retained. Its engine identity is
`4.7.stable.cybersand_egl_font_snapshot.5b4e0cb0f`. The new builder is an explicit
copy of the original source-bound builder with only input admission, the new
lock path and the admission receipt added. `engine_contract.py` rejects changes
to any other builder byte, dependency, compiler flag, original patch or ABI gate.

## Build interface

Use a clean, disposable checkout of Godot commit
`5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`, Windows x64, Python 3.12 and the
same hosted Visual Studio environment as the original engine builder:

```powershell
python tools/pubpres_final_engine/engine_contract.py --verify
python tools/pubpres_final_engine/build_engine.py `
  --source-dir $GodotSource --output $Payload --evidence $Evidence `
  --workers 2 --archive $Archive
```

All paths must be new. The original builder downloads the exact dependency
archives, checks patch input/output and source deltas, records toolchain and
compiler flags, produces GUI and console executables, verifies PE imports and
compares all public GDExtension API/interface bytes against official 4.7. It
retains API dumps, logs and failures. Output contains `bin/`, notices, the new
lock under the compatibility filename `workbench-godot.lock.json`, combined
`engine-source.patch`, `api-equivalence.json` and `build-provenance.json`. The
proof now also binds every committed input in `input_admission`.

Do not send this payload through the frozen #609 restorer: that restorer must
continue to reject any new engine identity. A new explicit runtime admission
must bind this payload, build source, GitHub run/artifact digest, lock, patch,
actual executable hash and public API proof. Retain original EGL separately.

`payload.py` provides that separate admission. Supply expected values from the
producing workflow or independently recovered artifact metadata, never values
read only from the payload being admitted:

```powershell
python tools/pubpres_final_engine/payload.py `
  --directory $Payload --evidence $AdmissionReceipt `
  --engine-build-source $ExpectedBuildSource --engine-build-run $ExpectedRun `
  --engine-build-attempt $ExpectedAttempt --engine-proof-sha256 $ExpectedProofHash
```

For archive extraction, additionally supply `--archive $Archive` and
`--archive-sha256 $ExpectedArchiveHash`; the destination must not exist. The
verifier checks the external proof hash first, exact source/run/attempt,
committed build input closure at that build source, current critical inputs,
the complete payload inventory, actual executable PE imports, exact compiler
and dependency policy, both public interface hashes and API header evidence.
Combined patch validation ignores only Git index/function-label decoration;
every changed file and source hunk must still match the two committed patches.
Additional files, changed executables, symlinks and Windows path aliases fail.

## Mandatory font and ordinary startup qualification

The source-bound wrapper preserves the old standalone fixture bytes, executes
all four registered arms with private profiles, and then opens the unchanged
ordinary Main Workbench with the same independently built native DLL and
retained Rapier under repaired Safe and Separate owners:

```powershell
python tools/pubpres_final_engine/run_font_qualification.py `
  --source $Checkout --runtime $CandidateRuntime --rapier-runtime $RapierDll `
  --original-engine-root $OriginalEglPayload --repaired-engine-root $Payload `
  --engine-build-source $ExpectedBuildSource --engine-build-run $ExpectedRun `
  --engine-build-attempt $ExpectedAttempt --engine-proof-sha256 $ExpectedProofHash `
  --output $FreshQualificationDirectory
```

This registration requires Windows with actual `opengl3_angle`; it makes no
physical NVIDIA or native WGL inference. Original EGL uses the unchanged #609
restorer and its existing artifact pin. Every font arm requests text with font
mipmaps **off**, completes 64 draw calls and 6,016 glyph submissions, and reads
the complete 1024×640 viewport. Repaired Safe and Separate must have exactly the
same framebuffer hash as original Safe on the same observed adapter.

Only the original Separate arm may retain the specifically identified
CowData byte-zero/empty-buffer native crash after script initialization and
clean process-tree teardown. A timeout, GLAD failure, script error, different
native failure or a partial receipt invalidates the experiment. An intermittent
successful old Separate run must pass the same complete receipt and pixel
checks. Its native crash is recorded as `passed: false`; the summary separately
reports `repair_gate_passed` and `all_arms_passed`.

Both new-engine startup arms are mandatory. They execute the ordinary
`owner_start.gd` observer, instantiate actual Main, apply the representative
Wave512 World, install a real actor, native Wave Flow and Full two-slot material
publication, and bind actual engine/native/Rapier/Main/observer/project bytes,
World identity and render owner. Headless import and graphical startup use
the retained Windows process-owner/timeout implementation; all `ERROR:` output
fails a required arm. Startup remains paused and grants no Rapier-step or
sustained-playability credit.

Before timing, call:

```python
from run_font_qualification import verify_qualification
gate = verify_qualification(
    summary_path, source=exact_source_with_native_runtime,
    repaired_payload=payload_path, build_source=expected_build_source,
    build_run=expected_run, build_attempt=expected_attempt,
    proof_sha256=expected_proof_sha256)
```

This rereads every raw receipt, process result and strict log, both immutable
engine proof files, actual source/runtime joins and all font framebuffer hashes.
It does not accept a summary boolean as qualification. The runner performs this
same replay itself and writes `verified-qualification.json`. Failed controls
and their logs remain available. No actual repaired-engine execution is claimed
by the local Python tamper tests.

## Required next execution

1. Run the original finite font fixture with its default non-mipmap text on
   original EGL Safe/Separate and repaired Safe/Separate; retain all failures.
   Its source remains `tools/pubpres_render_probes/projects/font/`. Compare
   complete repaired font framebuffers against the original Safe control.
2. Run the strict two-slot and three-slot current/previous GPU history oracles
   on the repaired engine, then ordinary Workbench startup, active physics,
   paint, actors, Follow and fresh-process persistence. A font-only pass is
   insufficient.
3. Only after those gates, compare repaired Safe and repaired Separate with the
   same native runtime, source, input, material and observer policy. Keep stock
   Safe as a distinct engine control. No engine scheduling change is bundled
   into this lifetime repair.

Local validation checks the declared builder/lock derivation and rejects
modified API gates, dependency/flag changes and patch/identity drift:

```text
python3 -m unittest discover -s tools/pubpres_final_engine -p 'test_*.py' -v
```

Exact upstream font blobs were independently matched to their Git blob IDs;
`git apply --check`, actual patch application and both output hashes passed.
Those checks do not claim a compiled engine or a successful graphical repair.
Independent specialists A and C also reviewed both text servers and found no
source ownership blocker. C independently fetched the pinned upstream blobs and
reproduced both output hashes. Runtime lifetime, exact pixels and ordinary
Separate startup still require the explicit gates above.
