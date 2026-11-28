# Complete local 83a physical baseline archive

This is the original complete local execution of source `83a3db6ffb207761df999abedac77eb1401604a8`, before the finite obstacle-steering latch correction. It preserves 122 fresh World campaigns and 194 actual actor episodes:178 subjects and 16 real passive catalogue companions. At most 8 actors exist in any World. All 30-second, 120-second and 300-second horizons completed with 273,600 native steps, 273,600 Rapier steps, 62,400 accepted commands, zero rejected commands and zero actor-center canvas incidents.

The ZIP contains 384 entries: every original registered process report, console and execution receipt; the whole-source/project/runtime custody manifest; complete aggregate and final runner receipt; reduced metrics/CSV data; five scientific figures; and the archive builder. Its total size is 20,808,554 bytes and SHA-256 is `7cbe9d219568f911573a72b3e07a29bfd030e6de40cd07c889e88feb4ce9be7c`.

The two parts are unmodified consecutive byte ranges of one ZIP. They were split only because the Git Hub connector rejects requests larger than 16 Mi B after base 64 encoding. Neither part is a standalone ZIP. Run the following Python code in this directory to reconstruct and verify it:

```python
from pathlib import Path
import hashlib, json
m = json.loads(Path('split-archive.json').read_text())
data = bytearray()
for part in sorted(m['parts'], key=lambda item: item['index']):
    value = Path(Path(part['path']).name).read_bytes()
    assert len(value) == part['bytes']
    assert hashlib.sha256(value).hexdigest() == part['sha256']
    data.extend(value)
assert len(data) == m['archive_bytes']
assert hashlib.sha256(data).hexdigest() == m['archive_sha256']
Path(m['original_archive']).write_bytes(data)
```

`archive-manifest.json` binds every original member; `archive-verification.json` identifies the complete ZIP and final runner receipt. Paths inside execution receipts intentionally retain their original machine locations.

This local run and the hosted run execute the same registered 194 case IDs. Do not add them to claim 388 independent experiments. The local run became contended after approximately 03:20 UTC when a separately authorized targeted probe began; its later elapsed call timings are retained but are not clean causal performance estimates. The hosted artifact is the primary baseline cost source. See [the independent hosted readback](../hosted-83a-independent/scientific-findings.md) for source-host variability, retained negative results and measured costs. Neither archive qualifies physical NVIDIA playfeel or the later corrected candidate.
