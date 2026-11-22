# Independent CI/failure delta review: repaired worldgen scheduling

**Verdict: GO for the repaired CI, failure and diagnostic contract. No remaining P1/P2 finding identified.** Actual final-source hosted qualification and measured performance admission remain required.

Reviewed immutable candidate: `19023b4016facfda2b13b9a1503742e4a9fe1982`, tree `39b658c5de9c5e541312b5190bd5d8ba797c6bed`, parent `28ec075afab840cf6fbb35190a7b1915808904f3`. Every byte of the eight-file delta matches the independently inspected and tested source hashes in `worldgen-runtime-ci-delta.json`.

## Confirmed P2 and repair

The superseded candidate buffered a running showcase's output inside GNU Make. Killing Make at the real watchdog could discard a hung peer's already-flushed stdout and stderr, despite correctly failing the family. The initial CI review did not check this output-custody invariant; its earlier GO remains explicitly superseded in `worldgen-runtime-ci.md`.

`Makefile:465–469` now opens each original per-case log and writes its source/run/attempt/binary header before launching the native process. Both output streams go directly into that file, before any replay through GNU Make. The original test's nonzero exit takes priority over a later replay error. A successful child with failed replay still fails. No pipeline converts failure to success, and the same two-job Make dependency barrier still guards all nine principal tests.

`tools/ci/verify_native_shards.py:207–246` requires exactly fourteen original showcase logs in the scientific-output inventory, along with the original physics outputs. It checks explicit source/run/attempt context, exact binary headers and nonempty raw payload. The existing inventory hashes bind the full bytes. Missing, extra, stale, misidentified, empty or changed logs cannot satisfy acceptance even when summary inventories are resealed. Both recording and final verification pass their expected source/run/attempt directly; the reader's ambient GitHub environment grants no authority.

`.github/workflows/native.yml:235` adds the original showcase-log directory to the existing always-upload step. All other workflow bytes remain unchanged. Required contexts, scope policy, final aggregation and watchdog behavior stay intact. The new verifier remains source-fingerprinted by the original Native source envelope.

## Independent verification

- Actual production Make graph plus original timed-command owner: timeout and SIGINT cancellation controls **2 passed**, 5.254 seconds. Both explicitly require the hung peer's previously flushed stdout and stderr to remain in its original source-bound log and require no live peer or principal-tail execution.
- Actual log-replay failure control: **1 passed**, 2.394 seconds. Successful-child replay failure remains red; original child failure has priority.
- Canonical Native shard verifier regressions: **51 passed**, 3.212 seconds, including all fourteen missing-log permutations, resealed stale context, missing payload, extra output, failed-record partial custody and always-upload preservation.

These are deterministic boundary/control tests, not claims of live native scientific execution. The complete-worldgen proof uses the original three commands and will require all 154 physics invocations plus sixteen normal and sixteen sanitizer binaries. Its controller is separately authored by this reviewer and therefore still requires root/performance review before publication/admission.
