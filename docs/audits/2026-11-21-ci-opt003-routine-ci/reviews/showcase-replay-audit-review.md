# Independent supplemental replay-audit review

**Verdict: GO for the corrected offline admission supplement. No remaining P1/P2/P3 finding identified within this fixed-source scope.** No hosted rerun is required to verify this reader-only correction. Actual evidence admission still requires both the frozen paired-family reader and this supplement to pass over the same original, source/run/attempt-matched hosted artifact.

Reviewed audit SHA-256: `540c4f5490529ec61f767736be8c23bc3451b0e1f383ec9ad5b0e7ce10e69c7a`.

Frozen producer remains `cc22fb8ffbba2a7c18a0bc1c0ad60413ad5c3147`; production candidate remains `19023b4016facfda2b13b9a1503742e4a9fe1982`. All seven local producer files were byte-compared to the immutable producer commit and matched. This reviewer did not modify the frozen producer, candidate, or supplemental auditor.

## Confirmed defect and repaired disposition

The initial supplement (`f31ed10e…`) counted whole raw-file substrings in command replay. At its line 35, that admitted two independently reproduced inconsistent bundles: a raw file truncated by a complete final output line while replay retained the full body, and a repeated source/binary header with a contradictory second replay body. Both bundles also passed the unchanged frozen reader after resealing inventories. Those were synthetic control failures, not evidence that the hosted producer emitted corrupt data.

The correction requires exactly one of every expected source/run/attempt/binary header and its adjacent unique Running marker (`audit_showcase_replay.py:70–79,104–106`). It derives exact compiler, directory and principal-test boundary lines from immutable candidate source using the digest-pinned frozen common module (`26–55,85–92`). It compares the entire resulting replay group byte-for-byte with the raw file (`107–109`), rather than using the raw length as the boundary. Both independently discovered cases now reject. The original divergent-body, failure-marker, duplicate-replay and wrong-attempt cases also reject.

## Legitimate output and false-positive checks

The parser permits independent showcase completion order and completed compiler groups between showcases. It does not split on generic compiler-looking prefixes; its boundaries are exact source-derived command lines. The fixed seven native fixtures emit newline-terminated success/failure summaries, and their outputs do not supply the Make recipe markers or shell command boundaries. The production recipe writes each source header and raw body before cat replay; GNU Make target grouping keeps the marker and replay contiguous.

Fresh controls accept multiline raw bodies, reversed showcase completion order, and a compiler completion between showcase groups. Independently retained replay from the actual production Makefile, executed locally with synthetic compiler/test processes, also passes with all fourteen raw logs. Those original control replay hashes remained unchanged during review.

**Version correction:** the local environment's installed Make is GNU Make 4.4.1, not 4.3 as initially stated in intermediate messages. Hosted run metadata identifies GNU Make 4.3. The local process-double control is not hosted or native qualification; actual hosted artifact admission remains mandatory and will exercise the reader on those original Make 4.3 bytes.

## Verification

- Supplied supplemental controls: **5 passed**, 2.558 seconds.
- Fresh independent adversarial and valid-schedule controls: **5 passed**, 3.288 seconds.
- Retained actual-Make/synthetic-process replay: **passed**, all fourteen raw logs.
- Frozen producer/candidate modifications: **none**.
- New hosted experiment: **none**.

Machine-readable review: `showcase-replay-audit-review.json`. The fresh controls are in `test_showcase_replay_independent.py`; the retained local control readback is `showcase-real-make-independent-admission.json`. These controls are deliberately synthetic and must not be counted as native/scientific execution evidence.
