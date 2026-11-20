---
title: Workbench Art conversation lifetime finisher
status: Current
document-kind: evidence
scope: PR 681 implementation, isolated engineering evidence, source-bound final qualification procedure and owner Windows acceptance boundary
canonical-for: []
last-reviewed: 2026-11-20
related-documents: [../systems/workbench-art-providers.md, ../operations/cybersand-codex-development-handover.md, ../reference/status-and-roadmap.md]
---

# Workbench Art conversation lifetime finisher

## Scope, identity and custody

WB-ART-TRAFFIC-LIFETIME-001 completes existing
[Draft PR #681](https://github.com/techrote/cybersand/pull/681), on
`fix/wb-art-lazy-linked-traffic-20261120`. The live starting head was verified as
`52badeef8358d7b2e038d241fd3d83b0d6c54726`; main was
`de109d0131641d6adc8d25bb9ced7ca3d4991105`. The final PR ledger records the
published commit, exact-source qualification, run identities and independent
verdict. **Keep Draft / HOLD; do not merge, enable auto-merge or mark Ready.**

All execution uses synthetic histories and separate test `XDG_DATA_HOME` or
`APPDATA` roots. No owner traffic file is read, copied, rewritten or deleted.
Historical files are treated as immutable. Generated fixtures, archives, native
payloads, imports and raw execution logs are not source changes.

Native source is unchanged. Qualification verifies every retained native source
input against the candidate before executing its libraries; this is reuse of
matching retained runtimes, not a new native build. The retained build source is
`e8c3aa6afd6ea2d53e1dab82cbb5b2c2e474b156`.

| Executed or required runtime | Identity |
|---|---|
| Godot | `4.7.stable.official.5b4e0cb0f` |
| Linux native SHA-256 | `3b373d944fcbe6c7db42a39617c800917603fe8abe8ad21e2ba422945c54cfe7` |
| Windows native SHA-256 | `926e164a11274fe02f3aa2ff41527dae102803a30685a5d7480ad0aa9840d165` |
| Linux Rapier SHA-256 | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |

## Confirmed root cause and repair

The eager implementation created the hidden Art window in the SceneTree before
hiding it. Control construction immediately restored saved traffic. Its
`resume_traffic()` copied the entire preceding JSONL into a new archive and then
parsed it. Ordinary Workbench construction, including local tests, therefore
performed archive writes without an Art action. A controlled execution of the
three original production files from main reproduced the copy.

The existing PR's lazy and linked-segment design is retained. The finisher fixes
its parse errors, completes validation and makes both restore and export
incremental and cancellable. The [canonical contract](../systems/workbench-art-providers.md#lazy-reopening-and-traffic-storage)
owns the current API, controls and exact capacities.

| Lifecycle | Archive behavior |
|---|---|
| Hidden construction, model selection, idle refresh, shutdown | Read the small configuration only; remember the saved path without opening its archive. |
| Explicit Art open or explicit history action | Validate and replay in bounded polls; expose progress and Stop. No archive copy or write. |
| First new event | Publish a small schema-2 segment with stable identity and predecessor committed length/hash; publish the config pointer before accepting the new session. |
| Later events | Append ordered events to the current segment; never rewrite a predecessor. |
| Edit or Clear | Append a conversation snapshot only after successful durable admission; retain the raw audit. |
| Fresh process | Recover the latest saved segment and validate its complete ancestry and image references. |
| Explicit full export | Stream the committed bytes into a temporary sibling; validate before atomic publication. |

New segments seal inherited path-only ancestors as well as their immediate
parent. Image references must point to preceding request records in the same
validated chain; actual base64 and PNG decoding are checked within bounded
capacities. A newest modern segment may recover a final unterminated crash tail
to its last complete record, with a warning and no source mutation. Truncated
legacy records and malformed completed records refuse restoration.

Both export and configuration publication use the existing native atomic
replacement primitive. Godot's Windows rename removes an existing destination
before moving the source, so it cannot provide the required interruption
behavior. A failed first config checkpoint leaves the previous conversation
selected and retains the unreferenced complete segment with a visible path.
An existing destination survives export failure and cancellation. Process-kill
partials remain visibly separate from successfully committed exports.

Legacy single files and path-only linked histories remain readable without
conversion. A narrowly identified historical numeric-token redaction artifact
is interpreted read-only with a warning; new structured redaction emits valid
JSON. The complete export is a byte-exact raw audit in segment order, including
headers and original segment-relative image references. It is not a portable
single-file conversation import format; reopening uses the retained chain.

## Measured engineering evidence before publication

The following are actual Linux Godot 4.7 executions, not mock-only results.
Engineering runs identify their executed file hashes. Source changed during
the long stress campaign; its guard correctly labels that campaign
`source_changed_during_execution`. Those measurements establish behavior under
development and must not be substituted for the final committed-source run.
The final PR ledger reports that separate clean-source result.

### Controlled before/after launch

Three uninstrumented fresh-process launches per variant used the same valid
67,108,991-byte synthetic legacy archive. The eager variant restored exactly
`art_provider.gd`, `art_batch_panel.gd` and `shared_workbench.gd` from
`de109d0131641d6adc8d25bb9ced7ca3d4991105`; the repaired variant used the candidate
files recorded in its measurement manifest. Startup was measured at the mounted
Workbench checkpoint, on the same host/runtime and fixture, not as a general
hardware-independent performance claim.

| Measurement | Eager baseline | Lazy candidate |
|---|---:|---:|
| Startup trials, ms | 4360.436 / 4335.877 / 4397.169 | 2430.192 / 2545.410 / 2602.275 |
| Median startup, ms | 4360.436 | 2545.410 |
| New archive bytes per launch | 67,108,991 | 0 |
| Historical archives changed | 0 | 0 |

A separate instrumented 67,108,987-byte fixture recorded 134,217,974 archive
bytes read and 67,108,987 written in the eager process; the lazy process recorded
zero archive opens, reads and writes. The four-byte fixture difference comes
from correcting the test PNG, not from omitted data. A test-only libc observer
counts real archive `fopen`/`fread`/`fwrite` calls; process I/O and RSS are sampled
separately. No observer is injected into owner sessions. Uninstrumented startup
trials avoid confusing the observer's per-character overhead with application
latency.

### Large-history campaign and regression coverage

The asynchronous engineering campaign generated an allocated, valid
2,148,526,396-byte JSONL history: it was neither a sparse hole nor a filename-only
stand-in. Three idle launches retained every archive name, byte count,
nanosecond modification time and SHA-256, with zero archive I/O. Explicit
continuation read the real archive and wrote only a small new linked segment.
The stress export was byte-equal to all committed segments in order.

Measured peak RSS was 427,991,040 bytes idle, 437,329,920 during continuation and
434,372,608 during export: 9,338,880 additional bytes above idle, against a
registered 256 MiB additional-memory limit. Restoration took approximately
35 seconds over 2051 processing frames, with a measured worst frame poll of
126 ms. Cancellation after 131,072 archive bytes left the original files and
saved pointer unchanged. These values describe this engineering run; final
source measurements are retained separately.

At the frozen production checkpoint, `test_art_traffic_integrity.gd` passed
130 checks and `test_art_traffic_panel_safety.gd` passed 38 checks with native
extensions. The mounted tests cover missing-file retry, Edit/Clear refusal,
configuration-write failure, preserved pointers, Stop, export cancellation,
queued native receipts and successful conversation editing/clearing. Broader
executions passed native Art, Art panel, stored-material, deferred manual,
shared edit ordering, deferred PAINT, shapes, executor, recovery, native PAINT,
Art Undo and ordinary Workbench input tests. Actual loopback HTTP fixtures
passed OpenAI, NVIDIA and LM Studio protocol paths, cancellation, timeout and
HTTP 429 handling. No paid/cloud inference is used or claimed.

## Independent review and repaired findings

An independent reviewer who did not implement the repair reproduced and
reviewed archive self-overwrite, missing-pointer loss, malformed record
acceptance, failed-write checkpoint advancement, image corruption acceptance,
non-atomic destination replacement, configuration-write failure, inherited
ancestor mutation, write/replay capacity disagreement, invalid UTF-8,
numeric-token redaction, same-writer replay and cancellation races.

Actionable production findings were repaired and covered by actual runtime
checks. A repeated-image export probe fell from an 8,852.563 ms worst poll to
14.708 ms with 64 KiB polling after bounded deduplication. The final audit
requires the reviewer to inspect the published source and complete qualification
receipts before issuing its final verdict. Harness review also strengthened
the process-kill export checkpoint and required proof of network dispatch before
testing Stop; a same-frame cancellation alone was insufficient evidence.

A final bounded-memory review also identified that the entry-limited legacy
duplicate-ID set retained entire arbitrary-length ID strings. A crafted valid
archive could therefore accumulate large amounts of metadata during export.
The repair retains fixed-size SHA-256 fingerprints under the same entry limit;
legacy bytes and duplicate refusal remain unchanged. Long-ID runtime and memory
results, together with the superseding source identity, belong to the final PR
ledger. Modern segment/event identities and optional legacy IDs are validated
in their respective schema domains; equal spelling across those domains is not
used for event merging, image lookup or parent selection.

An oversized image offset also exposed a conversion overflow: an unchecked
`1e30` value became a negative seek position. Image offsets now pass the common
exact-integer validator before conversion, and queued image reads defend their
seek bounds separately. Targeted restore, export and write regressions refuse
the malformed offset while preserving existing archives and destinations.

## Reproduction and platform boundaries

The focused driver is `tools/ci/qualify_art_traffic_lifetime.py`. It records
runtime/source hashes, source stability, archive manifests, process RSS/I/O,
real archive operations and individual runtime receipts. With an authenticated
Godot 4.7 executable and the source-matched native/Rapier libraries:

```sh
python tools/ci/qualify_art_traffic_lifetime.py \
  --godot /absolute/path/to/Godot_v4.7-stable_linux.x86_64 \
  --evidence /absolute/isolated/evidence \
  --stress-mib 2048
```

The source-bound Windows workflow
`.github/workflows/wb-art-traffic-lifetime.yml` runs on GitHub-hosted
`windows-2022`, triggered only on the existing branch or manual dispatch. It
verifies retained native inputs, authenticates official Godot 4.7, packages the
committed project, extracts that package, then executes graphical lifetime,
restart, crash, legacy and export tests using isolated `APPDATA`. It retains
JSON/log/screenshot receipts and the tested project ZIP. It does not require
promoting the PR out of Draft. A workflow definition or a successful package
construction is not Windows execution evidence; actual final run status and
artifact links belong in the PR ledger.

The Linux host has no usable graphical display; attempts to establish a dummy
X server are blocked by its AF_UNIX socket restriction. Linux qualification is
headless with real native execution. Hosted Windows graphical qualification,
if successful, still does not reproduce the owner's physical Windows/GPU setup.

Owner acceptance uses a separate controlled user-data directory and copies of
one legacy archive plus its linked continuation. Compare names, sizes, mtimes
and hashes before/after ordinary unopened Workbench launches; explicitly open
Art and inspect prior text/images; submit a local test event and verify the
small new child; close/reopen; export and compare complete history. Keep the
original owner data untouched and retain Draft/HOLD until authorized.

## Data accounting

Preserved data comprises every historical archive byte, identity and image
offset, unavailable saved path, and pre-existing export destination on failed or
canceled operations. Created data comprises explicit new-event segments, atomic
configuration staging files, user-requested exports and recognizable interrupted
partials. Idle Workbench creates no traffic archive. Owner traffic, unrelated
repositories, historical audit records and retained native binaries are never
rewritten, compressed or deleted by this repair.
