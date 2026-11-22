# Original renderer failure classification

This review rechecks retained, source-bound original evidence. It is not a new
graphical run and does not qualify the PUBPRES-003 application or physical
Windows/NVIDIA hardware. The original ZIPs, raw bytes, process records and
failing assertions remain unchanged.

## Configuration-specific conclusions

| Configuration and original probe | Observation | Disposition |
| --- | --- | --- |
| Linux Safe, full staging-reachability fixture | The mixed-policy test fails `queued-history/reachable/R8/2` first current GPU read. The same fixture's eager cases do not report a byte mismatch. | Retain FAIL for the mixed test and reachable case. Safe/eager requires its own exact successor qualification. |
| Linux Separate, isolated queued material with two reachable slots | First current read contains an older full image; first previous read is correct. The immediate repeated current read is correct. | FAIL. A later successful read cannot satisfy the original first-read oracle. |
| Linux Separate, full staging-reachability fixture | First current reads fail for eager and reachable pools, R8 and R16 logical channels, and two and three slots. | FAIL; the isolated material observation does not establish one complete cause for every full-fixture failure. |
| Linux Separate, minimal native-independent font/text project | Actual process crashes with engine fatal out-of-bounds error; Safe text and Separate text with font mipmaps complete. | Engine/backend limitation reproduced outside CyberSand native/application code, scoped to the pinned software renderer. The mipmap control is diagnostic, not a proposed production workaround. |
| Windows Separate/ANGLE, minimal empty native-independent project | GL initialization error, no script-start marker or completed receipt, process exit `0xC0000005`; matching Safe empty project completes. | Engine/backend startup limitation reproduced without CyberSand or native extensions. No NVIDIA hardware conclusion. |

The native-independent project contains only the committed probe script and
minimal project settings. Successful controls additionally attest that no
extensions were loaded. The Windows failed process crashes before the script
can issue that runtime assertion; its source projection and absence of
extension inputs provide the narrower source-level exclusion.

No renderer or publication implementation was changed on the strength of
these original diagnostics alone. In particular, the Safe/reachable failure
is not excused by a later isolated Safe run that happens to pass. Separate
remains optional and unsupported in the demonstrated configurations; these
failures do not turn a separately passing Safe/eager gate into a failure, or
a failed Separate gate into a pass.

## Exact identities and custody

Probe source: `0940114ddf8ef65b1f7b088dc5812776a1c02e25`.
Pinned Godot: `4.7-stable`, engine commit
`5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`.

- Linux engine SHA-256:
  `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`.
- Windows engine SHA-256:
  `b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8`.
- Linux controls identify `llvmpipe (LLVM 20.1.2, 256 bits)`, Mesa 25.2.8.
- Windows Safe control identifies ANGLE, Microsoft Basic Render Driver,
  Direct3D11 `10.0.20348.5756`. The crashing process does not reach adapter
  enumeration in its completed receipt because no such receipt exists.

The material probe copies the publisher, shader and original fixture from
source `a7074ab1bb4fede30d75a7924b4a5bfb7ea963d1`; its own committed copy
manifest and exact per-file hashes are retained. This is deliberately
distinct from frozen application source `d316c281...` and the successor.

| Original archive | SHA-256 |
| --- | --- |
| `pubpres-playability-linux-renderer-probes-44962312107-1` | `02bc560e7335d15ffe3b3ee6511070fbaa099b3360dc6d9605521ffa940cee85` |
| `pubpres-playability-windows-renderer-probes-44962312107-1` | `dd6aafaff49907c344c8656b32a5c5bceed7ca76c8e4f8a449b939f676304e3a` |
| `pubpres-playability-linux-correctness-44963596029-1` | `5100a0cfdcb6d3c89c4e835008ae7bc9b6cf75509f3c4fa9742c80328cd1d81c` |

`original-classification.json` records 14 isolated arms (9 PASS, 5 FAIL), the
two failed mixed-policy full-fixture runs, exact project inputs, receipt and
log hashes, process outcomes, and strict first-current/previous hashes. Every
retained project input and each process-recorded log hash was checked again;
the original strict `receipt_errors()` oracle was reused without changes.

The isolated two-slot Separate current read was
`d0cbbe1153a738d094ebf131a9e715794e05b3ef9da03ba95da02bbcfc5e679e`;
the expected and subsequent current read was
`d04fd79c20949cf1cbf243bf3be6b497caaedb88ddc29e0b7648e3d07f85eea3`.
Both identities remain in the negative record.

## Repeat the reduction

Extract the three original archives under one recovery directory, preserving
their named top-level directories, then run:

```sh
python tools/pubpres003/evidence/renderer-classification/reduce_recovered.py \
  --repository . \
  --recovery-root /path/to/renderer-evidence \
  --output /path/to/new-classification.json
```

The reducer refuses to overwrite prior output. It reads existing GPU evidence;
it does not launch Godot, install a driver, fabricate a new runtime identity,
or treat a skipped graphical test as passing.
