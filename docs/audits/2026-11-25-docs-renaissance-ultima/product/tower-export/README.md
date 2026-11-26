---
title: ULTIMA Tower observation export correction
status: Current
document-kind: evidence
authority: historical-non-authoritative
retrieval: explicit-history-only
scope: Source-qualified public export, real Linux failure tests and separate actual X11 clipboard controls; no physical or formal blind-study acceptance
last-reviewed: 2026-11-25
---

# Tower observation export

**B-ULT-08 / P1 — fixed and independently verified within the recorded native
per-file contract.** The predecessor's public `tower_observation` method could
silently destroy a valid report. Its method body was byte-identical to #774
`20170bd6259498c3d2774ab274567febb043fc1d`: a real Linux
`RLIMIT_FSIZE=128`, with `SIGXFSZ` ignored, replaced a valid 374-byte JSON report
with 128 invalid bytes. The old method returned void and supplied no failure
acknowledgement; this record does not invent a boolean success result.

Candidate source **`f778898565fbc3cc235525c557e61f8345f59797`** verifies the
complete closed staging bytes before native replacement, returns a truthful
boolean, exposes a separate result beneath Tower controls, and copies to the
clipboard only after commit. A clipboard readback gates the copied message.
The report format and existing Water/blind `hidden_mapping` are unchanged.

## Evidence and independent review

| Evidence | Observed result |
|---|---|
| [Before](before.json), [executed fixture](before-child.gd) | Actual Linux file-size failure; 374 → 128 bytes and failed JSON reload. |
| [Linux after](linux-after.json) | Six public controller/button cases: normal, real buffered-tail failure and permission denial for ordinary and Water/blind reports. Old digests preserved on refusal; retry loads the new value. |
| [A's independent execution](independent-linux.json) | Six cases independently repeated; all eleven executed input digests equal the committed candidate. Source and caller behavior approved. This was headless. |
| [Actual X11 clipboard](x11-clipboard.json) | Two additional native-window cases: a successful export copies committed bytes; real 128-byte refusal preserves the clipboard control and old file. Each child restores the prior clipboard without logging its contents. |
| [Finding and limits](finding.json) | Implementer, independent reviewer, expected contract and remaining platform/physical boundaries. |
| [Custody](custody.json) | Every copied artifact's bytes/digest, actual runtime payload digests and equality of all eleven qualification inputs to the source commit. |

The Water/blind report was 143,159 bytes; the Linux tail test used a real
139,392-byte limit. It retained the previous complete report, including its
engineering metadata. The clipboard run used pinned Godot 4.7 on native X11,
OpenGL compatibility/Mesa llvmpipe. Its processes ended naturally. The terminal
showed PASS and was closed; a fresh desktop inventory confirmed no test window
remained. This was an automatic public-call clipboard test, not another
interactive Workbench walkthrough.

The first before harness is also retained: its call to `JSON.parse_string` on
the deliberately corrupt file emitted an engine diagnostic, so the strict
runner rejected that attempt. The corrected fixture uses a JSON instance and
checks its parse result. Engine-error rejection was not weakened.

## Reproduction and scope

From a source-matched checkout with the pinned engine and materialized native
runtime, use a new disposable evidence directory:

```text
python3 tools/ci/run_tower_observation_qualification.py --godot /path/to/pinned-godot --project godot --evidence /path/to/new-disposable-evidence
```

The [runner](../../../../../tools/ci/run_tower_observation_qualification.py)
executes six Linux cases or four Windows cases; the latter hold the existing
destination open without delete sharing. Windows execution is a separate hosted
gate, not inferred from these Linux receipts. The [executed X11 wrapper](x11-clipboard-executed.py.txt)
retains its exact local launch; its absolute paths describe this evidence host,
not a portable installation requirement. Raw logs are byte-preserved under
`before/`, `linux/` and `x11/` with a `.txt` suffix; the receipts retain their
original log names and digests.

The fixed filename still intentionally replaces the previous observation after
a successful export. It is not an append-only study archive, a runtime-state
save, a browser storage guarantee or an fsync/power-loss guarantee. Existing
revealed candidate metadata and the owner-not-planned formal study boundary
remain unchanged.
