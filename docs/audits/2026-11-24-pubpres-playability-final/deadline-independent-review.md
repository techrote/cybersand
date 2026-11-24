# Independent deadline history and authority review

**Reviewer:** performance/qualification lane C. **Status:** source review and
three focused Python adversarial tests passed; actual graphical execution and
timing qualification remain separate. No performance or physical acceptance.

## Reviewed bytes

The review inspected these root integration bytes before their dispatch:

| File | SHA256 |
|---|---|
| `tools/pubpres_final/material_deadline_oracle.py` | `03483ba03ce2ee8eaa950a704b12cfcb7598856d6d2a61c2672ee76c5456e68c` |
| `tools/pubpres_final/test_material_deadline_oracle.py` | `3cce6c79f4959e026982fd9a1f4f7a92f684b19bca59416d753227630cca034f` |
| `godot/tests/test_material_deadline_main_history.gd` | `d4203240af3f265c0ead9a339fedc3b459b8f25788573447817d8c25e6f76200` |
| `tools/pubpres_final/run_qualification.py` | `7d471221c1ed1712eeafce8ed140ac615a5d3abdfd632c95acfc431658a88040` |

The fixture, actual Main transaction methods, standalone policy and identity
fixtures were read together. C did not implement the deadline policy or its
Python oracle. B independently reviewed the transaction/ACK implementation.

## Independently checked outcomes

There are eleven transaction observations per rate, at 30 Hz and 60 Hz. Write
`I=33334` or `I=16667` microseconds respectively. Initial serial 20 accepts at
100000, establishing the first next-upload boundary 100000+I. Offers 21, 22, 24
replace the one retained packet without moving that first deadline. Accepting 24
at 100000+I establishes 100000+2I. Accepting 25 there establishes 100000+3I. The
different-World full packet 30 replaces pending 26 and accepts immediately at
100002+2I, establishing 100002+3I. Closing the physical owner cancels pending 31
and clears the next boundary. These values and the offer, replacement,
consumption, acceptance and cancellation counts agree with all 22 independently
reduced boundaries.

Only 20, 24, 25, 30 appear in the actual ACK sequences, at every intermediate
boundary and the final rate receipts. Serials 21, 22, 26, 31 never earn ACK credit.
Both the strict scalar types and exact list shapes reject boolean/inexact step
counts, duplicate/missing/reordered boundaries, changed deadlines and invented
acceptance.

The eight real first-read GPU current/previous pairs are checked against Python
byte reconstruction from the registered 33×19 RG8 canvas and overlapping patch
tape. Both material and condition bytes matter. Serial 25 deliberately includes
the accumulated, not-yet-retired prefix from 21/22/24; replaying that prefix must
produce the same current pixels with actual plane 24 as previous. Different
World 30 produces the new full plane while previous texture storage retains
plane 25; the separate real Main timing assertion clears previous-World blending
authority. A fixture that reports matching but incorrect actual/expected hashes
fails the external byte reconstruction.

## Authority and qualification boundaries

Main, worker, policy, fixture, ring publisher, execution policy, engine and
actual renderer-owner identities are bound. Both two-slot and three-slot Full
graphics are wired into the successor suite. The two headless tests remain
explicit policy/identity checks and cannot substitute for GPU history evidence.
Every transaction/rate requires exactly zero actual Rapier steps. Synthetic
scheduling clocks and `performance_claim=false` are mandatory; this apparatus
cannot establish physical progression or a scheduling-speed improvement.

No blocking source/oracle finding was found in the reviewed bytes. Focused
execution was `python -m unittest discover -s tools/pubpres_final -p
'test_material_deadline_oracle.py'`: three tests passed, including negative
controls for wrong cumulative bytes, missing history, skipped/cancelled ACKs,
deadline renewal, pending-count inflation, false physical credit, source/engine
substitution and actual owner/slot mismatch. Graphical first-read results must
still be obtained from the source-exact hosted run.
