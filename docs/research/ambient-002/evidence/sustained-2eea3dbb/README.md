# Sustained ordinary-Workbench originals — a725 / observer 2eea

This directory preserves the actual hosted observation from [run 45544614719](https://github.com/techrote/cybersand/actions/runs/45544614719), artifact **14992866806**. The ordinary application is frozen at `a7250e15495667b2fcf564cbed1eaa8dea217c45`; the external observer is `2eea3dbb921058db418fbb243b4abc493cddbdb9`. Read the [qualitative review](../../graphical-watch-review.md) for findings and retained negative results, including the home-rest/recharge radius inconsistency.

The full artifact is **66,483,275 bytes**, SHA-256 **907f8bcdd11ef4c7150dc252844ec8545a0a7a46e66abf41ff10e889ad868cef**. All 435 archive members passed CRC verification. The archive contains all 183 original PNGs, original partial/final process and observation receipts, runtime/source custody, and the original sampled-media conversions. No original image has been modified.

## View the evidence

| Scene | Actual-frame sampled movie | Contact sheet | Original copied decisions |
| --- | --- | --- | --- |
| Common Ground | [MP4](ambient2-courtyard/media/ambient2-courtyard-sampled-timelapse.mp4) | [PNG](ambient2-courtyard/media/ambient2-courtyard-contact-sheet.png) | [JSON, gzip](ambient2-courtyard/frames/watch-report.json.gz) |
| Pipe Orchard | [MP4](ambient2-refinery/media/ambient2-refinery-sampled-timelapse.mp4) | [PNG](ambient2-refinery/media/ambient2-refinery-contact-sheet.png) | [JSON, gzip](ambient2-refinery/frames/watch-report.json.gz) |
| Foundry Row | [MP4](ambient2-settlement/media/ambient2-settlement-sampled-timelapse.mp4) | [PNG](ambient2-settlement/media/ambient2-settlement-contact-sheet.png) | [JSON, gzip](ambient2-settlement/frames/watch-report.json.gz) |

Movies are **sampled timelapses**, assembled from 61 actual frames at six samples per playback second. They represent approximately one frame per simulation second and are not continuous real-time video or hardware FPS measurements. The added movie banner makes this explicit. Contact-sheet times are requested sample seconds; actual tick, simulation and wall timestamps are retained in each JSON report.

Selected original PNGs at requested seconds 0, 5, 12, 24, 36, 48 and 60 are directly available under each scene's `frames/` directory. Every other original frame is in the full archive. The gzip convenience copies decompress byte-for-byte to the original report files; their original SHA-256 values are recorded by the campaign and independent readback.

## Restore the exact artifact

Run this Python snippet from this directory. It checks every part before constructing the original ZIP and checks the final length and SHA-256. It refuses to overwrite an existing output.

```python
import hashlib, json, pathlib

root = pathlib.Path('.')
manifest = json.loads((root / 'archive-manifest.json').read_text())
output = root / manifest['file_name']
with output.open('xb') as dst:
    for part in manifest['parts']:
        data = (root / part['path']).read_bytes()
        assert len(data) == part['bytes']
        assert hashlib.sha256(data).hexdigest() == part['sha256']
        dst.write(data)
assert output.stat().st_size == manifest['bytes']
with output.open('rb') as src:
    assert hashlib.file_digest(src, 'sha256').hexdigest() == manifest['sha256']
print(output)
```

To repeat the independent readback without running Godot, place that ZIP in a scratch folder, extract it beneath a child directory named `original`, and run:

```text
python audit_sustained.py SCRATCH_FOLDER --output SCRATCH_FOLDER/readback.json
```

The audit verifies the original outer artifact, process/log/report/image/media hashes, compile-to-observation application/runtime identities, 855 project-input custody, actual physical/native horizons, copied roster/control authority and displayed material/actor publication compatibility. Its trajectory summaries explicitly use coarse samples after requested second 3; they are not a reconstruction of every physics tick.

## Scope

This evidence covers three additional observational Worlds and 22 physically instantiated inhabitants, always at or below the eight-actor ordinary host limit. It is separate from the registered 194-episode experiment. Hosted Mesa llvmpipe rendering, diagnostic overhead and sampled playback provide no physical NVIDIA or owner-display playfeel acceptance. The original a725 home-rest/recharge defect remains preserved here even if a later application revision repairs it.
