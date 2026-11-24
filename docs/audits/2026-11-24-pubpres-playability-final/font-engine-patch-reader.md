---
title: Font engine combined-patch reader correction
status: Current
document-kind: audit
scope: Exact original engine artifact custody and detached reader correction; no runtime or physical acceptance
canonical-for: []
last-reviewed: 2026-11-24
related-documents: [../../operations/pubpres-playability-final-001.md, renderer-source-review.md]
---

# Font engine combined-patch reader correction

The font engine build in [run45452580606, attempt1](https://github.com/techrote/cybersand/actions/runs/45452580606)
completed at application/build source `c2f8a73d34448bc1496ecd84bca02f0812c80d27`.
The following renderer qualification stopped **before process execution** because
the source reader compared Git hunk alignment literally. The failed original job
and all original artifacts remain unchanged. This correction does not establish
font pixel parity, ordinary Separate startup, gameplay or NVIDIA acceptance.

## Exact discrepancy and correction

The committed font patch and the build's combined `git diff` align four identical
closing braces differently: Advanced glyph-size/outline and Fallback
glyph-size/outline. In each case, a closing brace is an added line in one hunk
and unchanged context in the other. The hunk starts differ by one line, while
the complete old/new source and actual inserted code are identical.

The reader now reconstructs each complete hunk's old/new line vectors, validates
both declared counts, trims only their equal prefix and suffix, and retains the
exact resulting old/new coordinates and removed/added bytes. Comparison still
requires the same ordered three-file closure, regular-file mode and eleven
nonempty edits. The parser rejects duplicate/aliased paths, renames, modes,
overlapping or reordered hunks, inconsistent cumulative new coordinates,
malformed or truncated bodies, additional/no-op edits and noncanonical encoding.
Changed line bytes and their whitespace are never normalized. Function labels
and Git blob decoration remain non-authoritative presentation metadata.

The separate full payload verification remains mandatory: externally expected
proof SHA, exact build source/run/attempt, committed build-input closure, patched
source hashes, compiler/dependencies, API/ABI equivalence, actual executable PE
imports/subsystems, complete file inventory and all payload hashes. No source,
engine, font, startup, history or physical gate is removed.

## Immutable artifact verification

| Identity | Exact value |
|---|---|
| Engine artifact | `14952148161` |
| Engine artifact ZIP SHA256 | `fe4440d0975b4121d037c50477facb1d1596c76eb759199e26e0cff250e2cfd1` |
| Build proof artifact | `14952637070` |
| Proof artifact ZIP SHA256 | `af2b64b2557649d4ef9536a0d809540fc64cffc1e3e7efb8f393533f28d00439` |
| Expected build-provenance SHA256 | `0f1d6059578d4505043fe11f1286cd7395c5cc64df7aa379106f7a0bcafdf1c5` |
| Combined source patch SHA256 | `3dd0d224ad0a0a4187bfbc71fad3bf7c3030f0601b76284f0ff64d0cb38f229e` |
| Canonical ordered-edit SHA256 | `5f9098ed6d249ef497555656af46e0d63507d578d483f17cd9ef70de3dab3d08` |
| Exact GUI executable SHA256 | `b0c608bc47bdc05cdd2083df4dfd67861c5d36b876a1ccf7086374059c7bad15` |
| Exact console wrapper SHA256 | `d9ee4fe2aee05fce8a3b01d835f2c7d0db4a40e944c539eec032ddf736ac6d5b` |

The independent source replay fetched pinned EGL source and reused the separately
verified pinned Advanced/Fallback source. Every original file SHA matched the
lock. `git apply --check` and actual application of the captured combined patch
then reproduced every declared postimage SHA exactly. The
[retained replay receipt](font-engine-patch-reader-replay.json) binds those values
to the corrected reader bytes. Full payload admission passed all ten recorded
payload members plus the externally pinned provenance.

`python -m unittest discover -s tools/pubpres_final_engine -p 'test_*.py' -v`
passed **20 tests**. The suite contains the exact captured patch as a small
immutable textual regression fixture and independently alters insertion bytes,
whitespace, old/new coordinates, file closure, mode, ordering, extra/no-op hunks,
counts and encoding. Self-consistent rehashing does not admit changed edits.

## Execution boundary

The next focused execution must retain the original application, native runtime,
engine build and artifact identities. Its changed reader/driver needs a distinct
committed identity; it cannot relabel the application or engine as that newer
driver. Four font controls, both actual ordinary startup owners, both two-slot
first-read history controls and the same-engine Safe/Separate comparison remain
required before any renderer performance decision. All work remains Draft/HOLD.
