# Complete original final Linux artifact

This directory durably retains the **exact 42,774,281 original ZIP bytes** from
GitHub artifact `14990266435`, workflow run `45540569052`. Its SHA-256 is
`eac23768f3b18dc95a35554328f700daa8a81fa9920bab39fa7148aca1958e30`.
No ZIP member was regenerated, recompressed, renamed or edited when making these
parts. The only operation was copying consecutive byte ranges from the verified
original artifact.

Application source: `a7250e15495667b2fcf564cbed1eaa8dea217c45`.
Application tree: `a038e6df65d58529f4c496c01f26c65975654fa6`.

The complete artifact contains 719 entries, including the original 194-actor,
122-World scientific programme; every original per-process report, console and
execution receipt; the full 119,644,773-byte aggregate physical report; complete
source/runtime custody; headless qualification; 29 graphical captures; and the
reduced scientific figures and independent readback. This retention is separate
from the owner-facing portable Windows evaluator.

## Verify or reconstruct

The five `.part-XX` files are consecutive raw byte segments, **not five separate
ZIP archives**. Keep all five beside `manifest.json` and `reconstruct.py`.

Verify every part and the concatenated outer SHA-256 without writing another copy:

```sh
python3 reconstruct.py
```

Reconstruct to a new output path:

```sh
python3 reconstruct.py --output /absolute/new/ambient-002-linux-a725.zip
```

On Windows, use `python` in place of `python3` and an ordinary Windows output
path. The standard-library helper reads 64-KiB chunks, verifies each size/hash and
the complete outer identity, and refuses an existing output path. A failed write
may leave an incomplete new output; the successful terminal and matching complete
SHA-256 are required before using it.

The parts can also be concatenated directly in their listed order with any
binary-safe file tool. `manifest.json` records exact offsets, lengths, SHA-256
values and Git blob identities. The first four parts are 10,420,224 bytes each;
the fifth is 1,093,385 bytes. `reconstruction-verification.json` is the actual
verification-only receipt over these retained part files.

## Recovery and evidence joins

The first downloaded copy and locally verified byte parts were lost during a
second executor reset before their upload/commit completed. No such lost commit
is claimed. Recovery retrieved the **same original GitHub artifact**, matched
its complete outer SHA-256 and size, and reproduced all five exact Git blob
identities already retained in the earlier tool output. `recovery-verification.json`
records that fresh verification. It is not a regenerated physical report or a
relabelled new run. No simulation was re-executed.

The full original aggregate report SHA-256 is
`090394a0a0f7e7a876481c935fcd2245691bf38a30f24f3c602dd5cd92c5b894`.
The verified physical programme contains 178 subjects and 16 passive physical
companions; actors sharing a World are clustered observations. This archive
adds no episodes and makes no new execution claim.

The [final independent scientific findings](../hosted-a725-independent/scientific-findings.md)
explain the successful and negative outcomes. Its compact custody archive and
figures support convenient review; this complete byte archive ensures that
Actions artifact retention is not the sole home of the underlying raw evidence.
