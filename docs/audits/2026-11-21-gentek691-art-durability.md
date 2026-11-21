# GENTEK-691 Art durability repair — qualification record

**Implementation candidate; Draft/HOLD.** This record describes the repair of
the two P2 findings in [review 6005545284](https://github.com/techrote/cybersand/pull/691#pullrequestreview-6005545284).
The [PR qualification ledger](https://github.com/techrote/cybersand/pull/691)
owns subsequent exact source, workflow, publication, package and review results.
No source-only or Linux-only result here establishes Windows/NVIDIA acceptance.

## Baseline and reproduced failures

The unmodified reviewed source was
`c163f1af722e37f802eb0a89a7aff6fa76634e04`, already descending from accepted
main `69209acaffb34ebe18c45e19290b5976b7fb2c82`. The prior combined runtime
publication came from source `16dd1e225ed974789c8b1fbc46718a06b1f61fc8` in
[run 44895953263](https://github.com/techrote/cybersand/actions/runs/44895953263).

The [original failure log](gentek691-art-durability-20261121/before-failure.log.txt),
[isolated reproducer](gentek691-art-durability-20261121/before-reproducer.gd)
and [identity manifest](gentek691-art-durability-20261121/baseline.json) preserve
13 original assertions: 10 passed, three failed, process exit 1. The actual
native-backed Workbench delivered the completion signal while real filesystem
directories obstructed file writes. No provider request or mocked archive writer
was used. Original archive SHA-256 values remained unchanged.

| Finding | Original observable failure | Repair |
|---|---|---|
| Unreadable existing profile | A directory at `art-provider.cfg` produced no journal and no persistence error | Cache the small session association at Workbench setup; distinguish virgin/no-session, valid, incomplete and unreadable profiles; retain known-session receipts through outages; report unknown association explicitly |
| Loaded Art, refused raw append | The native result had no durable journal after the append failed | Atomically stage every associated completion before writing raw or visible traffic |
| Loaded Art, raw committed but visible append refused | A raw event existed without a conversation turn or recovery record | Track raw and conversation commits separately by exact receipt identity and payload; retry only the uncommitted stage |

## Transaction and failure contract

The implementation retains the existing append-only archive and per-receipt
journal. A receipt freezes its source path, native completion data, world epoch
and stable unique identity. Its JSON number representation is normalized at
capture so journal reload cannot change its expected text or content digest.
Schema-2 receipts also freeze the sanitized visible turn, binding its SHA-256 and
world epoch in the raw result. Retry and restart therefore match the original
representation even after the process-local credential list changes. Only
registered, exactly matching frozen history writes bypass a second redaction;
ordinary traffic keeps the existing redactor. Schema-1 records remain readable.
Publication order is separate from identity and established from validated
journal filenames only when enumeration succeeds. Earlier volatile receipts
stage before later grouped completions, including after clock rollback.
The journal remains until a visible result and its profile checkpoint have
committed. Cleanup interruption is deduplicated by exact source, payload,
role/content and epoch during the existing incremental restore.

An existing profile that becomes corrupt, locked, missing or a directory does
not erase an already-known session association. If no trustworthy association
was ever available, the completed native edit produces an explicit persistence
failure; the UI says that its Art receipt was not retained and that the native
edit must not be repeated. Later session selection cannot adopt that result.
Missing configuration with retained archives is not classified as virgin storage.

Archive failures preserve the journal. Journal failures retain at most 64
receipts / 4 MiB in process while Workbench stays open, block subsequent history
actions and retry after access returns. Overflow is an explicit nonrecoverable
persistence refusal for the excess result, not an unbounded memory queue or a
successful durable result. Committed journal capacity is 4096 entries / 64 MiB,
with 256 KiB per receipt. Invalid filenames, aliases, metadata, UTF-8, incomplete
records and capacity violations fail closed without rewriting valid data.

The source association remains the established saved path plus validated linked
archive ancestry. This repair does not introduce a new session identity store
or inspect historical transcript headers during the native callback. Existing
archive identity and parent-hash validation remain authoritative.

## Focused qualification

The existing provider, lazy-traffic, integrity and mounted-panel suites remain
unchanged. The added identity suite tests exact commit matching, provisional
replay state, cancelled/corrupt replay, session isolation, legacy ID recovery,
clear/edit semantics, capacity and redaction. The added durability suite covers
the real filesystem boundary, original archive hashes and actual PAINT/native
Undo/Redo interactions.

`tools/ci/run_art_history_recovery.py` records source/script/native/Godot hashes,
positive assertions, full return codes and original process logs. Its restart
seed leaves 76 receipts, including one raw-only result followed by 75 deferred
completions, for a separate process. Its crash seed flushes a witness at the
conversation-commit boundary; the parent then uses SIGKILL or TerminateProcess
before journal deletion, and a separate process verifies exactly-once recovery.
Printed successful assertions cannot excuse a later process crash.

The original mounted-panel suite passed 55 assertions after the repair; the
original lazy suite passed 23; the independent provider identity suite passed
66. The adversarial development suite initially passed 241 assertions, the separate-process
restart phases passed 14 and 13, and the SIGKILL recovery passed eight. These are
Linux development observations, not the final commit/platform acceptance record.
The combined runner and hosted workflow must independently reproduce them from
the frozen source before the broader campaign begins.

The subsequent independent review reproduced an additional cleanup-path P2:
replaying an older already-committed pending receipt rewound the compacted
context's latest-result summary. The fix makes that path cleanup-only, preserving
authoritative replay state. The independent probe failed before the fix and
passed afterwards; both original logs are retained beside the baseline. A
46-assertion regression also covers a late journal record while an active writer
exists, requiring incremental revalidation and preserving the newest result.
Before the subsequent redaction-state correction, the combined local runner
passed **704 assertions** with zero failures,
including the expanded **286-assertion** adversarial suite; all ordinary processes
exited 0, and the deliberate crash process exited -9 at its verified boundary.
The [development summary](gentek691-art-durability-20261121/linux-development.json)
records each full return code, log hash and changed-script identity. Hosted
frozen-source qualification remains a distinct gate.

The same independent review then reproduced two further P2 branches: a pending
receipt whose committed visible text used a process-local secret could refuse
replay after restart without that secret, and an execute-only prior-storage
directory could be mistaken for empty because opening it succeeded while listing
failed. The schema-2 frozen projection closes the first boundary. Explicit
directory-enumeration checks close the second in profile discovery, journal
reading and quota accounting. Separate-process redaction-state recovery and real
directory-permission probes supplement the original cross-platform filesystem
obstructions. Their final results must be recorded under their actual tested
source rather than attributed to the earlier 704-assertion run.

Two further retry boundaries were independently reproduced and corrected before
source freeze. Repeated first-segment checkpoint refusal previously allocated
another orphan segment on each retry; it now retains and verifies one bounded
segment and retries only its checkpoint. A clock rollback combined with a
temporarily unlistable journal could previously order a new volatile receipt
before an older durable one. Separate publication ordering and serialized
volatile staging preserve chronology without changing the captured identity or
reading historical transcript data. These cases retain independent negative
logs and formal regressions in the final evidence.

After those corrections, the [combined Linux development run](gentek691-art-durability-20261121/linux-development-v2.json)
passed **964 positive assertions, zero failures**, with unchanged source/runtime
identities throughout. The complete adversarial suite passed 345 assertions
across 13 scenario families, and the receipt-identity suite passed 122. All
ordinary processes returned 0. The two deliberately terminated processes
returned -9 at their flushed, verified commit boundaries; their independent
recovery processes passed. The [original combined log](gentek691-art-durability-20261121/linux-development-v2.log.txt)
retains the full per-process counts and return codes.

The [independent source review](gentek691-art-durability-20261121/independent-source-review.md)
finds no remaining confirmed source blocker and authorizes focused
qualification only. Its [original before/after reproductions](gentek691-art-durability-20261121/independent-reproductions.json)
retain five additional findings' disposition, including the observational
checkpoint probe whose exit was 0 while its file counts demonstrated the leak.
The reviewer also independently exercised the exact
[publication transport lease](gentek691-art-durability-20261121/independent-publication-lease-probe.json)
against accepted, rewound, advanced, deleted and concurrently changed refs.
These are prequalification records; hosted target-OS and final-source CI remain
separate acceptance gates.

The first hosted [focused run 44914680994](https://github.com/techrote/cybersand/actions/runs/44914680994)
tested frozen source `0d961464cf0afe20e8b8d5594faa901b1c7853f0`.
Its [independently checked artifacts](gentek691-art-durability-20261121/first-hosted-artifact-audit.json)
show Linux passed 964 Art assertions and the unchanged 439-assertion graphical
Flatten/storage qualification, including all required framebuffers and full
process exits.
Its Windows Art processes passed 906 assertions, including actual exit codes,
but the overall Windows gate correctly **failed**: the final checkout-status
comparison found four changed Rapier import descriptors. The original graphical
Flatten step was not reached and is not counted as passed. The
[original failure record](gentek691-art-durability-20261121/windows-first-hosted-failure.json)
retains the exact report/artifact hashes, process outcomes and original runner
log bytes. The existing Windows regression runner already defines a narrowly
scoped CRLF-to-LF normalization policy for these same four descriptors. The
focused runner now records that import transition, permits only canonically
identical descriptor bytes, verifies unchanged source images and all other
inputs, and then requires exact post-import identity throughout the tests.
A complete hosted rerun is required; the failed gate is not relabelled.
The correction passed [13 real filesystem/Git transition checks](gentek691-art-durability-20261121/import-transition-negative-tests.json),
[seven independent review checks](gentek691-art-durability-20261121/independent-import-transition-review.json)
and an [actual pinned Linux editor-import smoke](gentek691-art-durability-20261121/import-transition-linux-smoke.json).
Semantic descriptor changes, source-image changes, aliases and application drift
remain refusals. The Windows owner guide now identifies accepted main correctly
and points to the delivered manifest and current handoff for package identities.

The focused workflow retains the complete original graphical 512×512 Flatten
author/reopen and failed-owner/storage recovery commands on Linux X11 and Windows
ANGLE. A narrowly scoped push trigger on
`qualification/gentek691-art-durability` permits this first gate before the
owning integration branch starts its expensive guarded publisher. No new PR,
Ready promotion or CI-OPT-002 integration is required.
The publisher retains its source lease and single-parent/four-path guards, and
uses an ordinary fast-forward push after rechecking the remote source SHA. It
does not request a forced ref update.

## Native and final-source qualification boundary

All 105 compiled native input hashes are unchanged by this Art repair. The
existing Linux runtime `a15fc422313eb01e79bc904f44cc8879816484ae4fc98c63ac4b815afdb6a5e7`
and Windows runtime `3692fe02eeb1adf383ed2abdce6641efadbaf7a0009c4574ec2c5d536bcd8e73`
can therefore serve the focused first gate under the existing provenance checks.
The pinned Godot is `4.7.stable.official.5b4e0cb0f`; the Linux executable SHA-256
is `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`.

The full project/build/test input identity does change. Previous gallery,
Workbench, Windows package and broad final-head results are retained under their
original identities and are not relabelled as repaired-source acceptance. After
focused Linux/Windows success, the existing guarded mechanism must qualify and
publish the final source using only its allowed runtime/provenance paths and a
verified branch lease. All 80 styles, 520 captures, 240 refusals, 80 independent
replays, exact default parity and original graphical/package coverage remain
mandatory. No Gentek geometry, Water behavior, native history semantics, actor
composition or production defaults are changed by this repair.

An independent reviewer must inspect the frozen source and final evidence. The
owner then receives the verified Windows package for physical NVIDIA testing.
Merge and Ready promotion remain unauthorized.
