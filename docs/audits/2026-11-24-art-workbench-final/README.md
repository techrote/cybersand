---
title: Art Workbench final integration evidence
status: Current
document-kind: audit
scope: ART-WORKBENCH-FINAL-001 source reconciliation, measured failures and qualification boundaries
canonical-for: []
last-reviewed: 2026-11-24
related-documents: [../../operations/art-workbench-final-evaluation.md, ../../systems/workbench-art-providers.md]
---

# Art Workbench final integration evidence

**Draft/HOLD.** The primary #744 no-listener freeze remains unproved on the
owner's physical Windows/NVIDIA system. The Linux absent-listener checks did not
reproduce it. This record separates that negative result from the independently
reproduced transport teardown and large-response processing defects.

The pull request carries the exact final head and its hosted run/artifact links.
Every matrix run records its source tree, harness hashes, runtime hashes, command
line and execution outcome. The Windows evaluator carries the same source
identity and per-file hashes in `candidate-manifest.json`. Native source and
retained runtime binaries are unchanged. No merge or Ready promotion is authorized.

## Reconciled sources

| Record | Exact source at intake | Disposition |
| --- | --- | --- |
| Accepted main / #727 | `00cdb02f103265b6dc5224c68283e9a0c8cb449f` | Baseline; one new JSONL and empty conversation per game session |
| #756 provider roster | `8093a782a13a078ad6fa4fc9fdf11b969cbbf52f` | Merge ancestry retained; exact IDs and historical config preservation |
| #763 bounded conversation UI | `2d63bba23932feb2c051c11df9d0775c24ea451d` | Final three-commit donor retained; its PR body named an older revision |
| #765 timing investigation | `cb88ab25d6dbdc8b459431d0189332bb7d37188a` | Metrics and prior fixture retained; HTTP404-heavy evidence is not original reproduction |
| #766 HTTP/hidden-window repair | `48970266ae3b1ae47d2278d25ea312328078ddbd` | Error audit semantics retained; hidden World invalidation and privacy strengthened |

All were owned/authored by `techrote` with no assigned reviewer at intake.
#756 was actually non-Draft despite its title/body. Donor metadata and branches
are preserved. [Intake](intake.json) contains refreshed identities, comments and
completed CI results. [Pre-publication refresh](prepublication-refresh.json)
records the subsequent unchanged donor heads, comments, ownership and CI
identities. Donor branch names and their source-specific evidence are retained.

## Controlled failures and qualification boundaries

A real loopback server accepting a request and sending no HTTP headers caused
actual native Workbench teardown to exceed a 30-second watchdog (30.060 seconds)
under Godot 4.7's threaded
HTTPRequest path. The pinned [HTTPRequest source](https://github.com/godotengine/godot/blob/5b4e0cb0f/scene/main/http_request.cpp)
joins its [blocking HTTP client](https://github.com/godotengine/godot/blob/5b4e0cb0f/core/io/http_client_tcp.cpp) thread
before closing the socket during cancellation. The candidate uses the engine's
nonblocking poll path with 64 KiB download chunks; Stop, timeout and teardown
are then exercised against the same stalled connection.

This does **not** establish the original no-listener Send/X root cause. Ten
absent-listener donor-control arms completed with 195 assertions on Linux
headless/native Workbench input routing and real material readback. Their worst
adjacent-frame gap was 60.114 ms. The original multi-second freeze was not
reproduced in that environment. The early donor fixture also emitted an empty-EOF JSON parser diagnostic; its
assertions passed, but the receipt is explicitly not classified as an error-free
run. The later harness corrected that parser. Exact commands, source and raw
negative evidence are retained in the qualification packet.

The clean integrated intermediate source `38abfde567215bacf44f929b498ff2d33425987b`
passed 615 of 616 checks across 31 cases. The remaining failure was a complete,
valid 16,773,309-byte response: its adjacent frame gap was 2,488.132 ms, including
2,476.178 ms of callback work and 1,815.756 ms of sanitization. The 2-second gate
was retained. This negative result prompted the value-only response preparation
repair; it is not presented as a successful final run.

On that same intermediate source, ten absent-listener cases had a maximum
25.411 ms adjacent frame gap, Send handlers of 2.416–11.874 ms and X handlers of
0.359–0.755 ms. No-header Workbench destruction completed in 104.949 ms. Twenty-nine
manual native edits had confirmed material readback; 26 were queued while
transport was active. Independent post-exit SHA-256 checks confirmed the complete
redacted response bodies for the near-limit, 1 MiB and credential-boundary cases.
The [baseline receipt](preparation-baseline-receipt.json) deliberately retains the
then-open findings and the exact source of each observation.

Further qualification identified a separate outgoing-context cost. On source
`2c432899`, a near-limit Full-context Send had a 3,329 ms frame gap. On the
reviewed request-worker/panel integration `1dfb2cf8`, the same focused native
probe passed 46 checks: Send took 3.479 ms, the largest frame gap was 386 ms,
request preparation took 740 ms off the main thread and the main request audit
took 332 ms. Synthetic direct conversation admission still took 1.993 seconds;
this is reported separately from Send and motivates the measured writer work.

The response-only lifecycle probe at `2c432899` passed 96 checks, including
actual unfinished CPU work during Hide/reopen, Stop, World replacement and owner
destruction. Its near-limit successful assistant had a 1.603-second maximum
frame gap, and its prefix-heavy complete response had a 604 ms maximum. A
separate 11-check actual process-exit test proved that a worker task was still
unfinished when quit was requested; Godot exited successfully in 347 ms.

A distinct Note stress probe passed its 1 MiB Apply assertions, then was
externally killed while assigning 16,769,024 bytes to the original TextEdit.
The near-limit Apply action was never reached, and no kill cause is asserted.
This exposed the full-message assignment in ordinary conversation selection.
The first reviewed pager at `cea4faaa` assigned a 65,536-character part.
Its 20-check regression selected a 16,769,051-character message in 120.316 ms
while retaining all text, Unicode, image references, multi-part edits and
Cancel/reopen behavior. Later Unicode qualification found that shaping even one
64 Ki-character part could take 4.68 seconds. The final `4e59604e` clipboard/pager
uses 4,096-character parts and direct part-number navigation. Its 57-check
regression pasted 16,769,029 characters in 778.873 ms and opened a full Unicode
part in 907.975 ms, without assigning a larger part to TextEdit. Copy/Cut/Paste
adapt the exact Godot `5b4e0cb0f` clipboard rules through public native methods;
the new script retains their MIT notice and source attribution. The displayed
CI differential is a separate mandatory gate; injected clipboard values do not
claim physical owner clipboard or mouse acceptance.

The first broad run at `09056f9b` was externally killed after 80.91 seconds,
before a final report. Its surviving audit records the configured 15-second run
deadline cancelling a near-limit response during preparation; a frame-bound
assertion also appeared without a surviving numeric case report. The next
harness checkpoint retains per-case progress outside measured intervals and
gives intended large-success cases a 40-second authoring-run budget for their
20-second transport budget. The 2-second frame gate is unchanged. Both separate
actual process-exit arms on `09056f9b` passed: incoming 11 checks/413 ms and
outgoing 13 checks/704 ms, with no outgoing HTTP dispatch after quit.

The next clean broad run at `d254751c` was externally terminated after 87.203
seconds, before its 300-second watchdog. Incremental receipts preserve 722
passing checks across 37 completed cases, no assertion failures and eight
independently verified complete redacted response hashes. The near-limit
successful assistant had a 791.491 ms maximum frame gap. The last checkpoint
preceded the near-limit outgoing Send; the whole run remains incomplete.
Peak child RSS was 1,077,384 KiB and cgroup counters were unavailable. No cause
is attributed to the external termination.

The separate outgoing group on that same clean source passed 122 checks across
four cases. Near-limit Full-context Send took 6.659 ms, with a 48.243 ms maximum
frame gap, 1.093 seconds of worker preparation and 41.173 ms of request audit.
World replacement, cancellation, one-slot reaping, zero stale dispatch and owner
destruction (139.834 ms) passed. A real changed 1 MiB Note Apply took 49.202 ms,
with complete text/audit fidelity, a 57.794 ms maximum frame gap and no model
request. Two subsequent native near-limit Note probes were externally killed
before Apply, so they supply no near-limit Apply verdict. The separate 57-check
paged-editor result above remains a distinct qualification tier.

The focused workflow runs equivalent network, incoming preparation, outgoing
preparation and native lifecycle groups in fresh processes, with both actual
process-exit groups retained and an additional isolated near-limit changed-Apply
group. This bounds fixture resource lifetimes without
changing coverage or the two-second stall threshold. It is not a diagnosis of
the interrupted monolithic run. Original logs and partial receipts remain in
the evidence packet, alongside every later completed group.

## Displayed qualification controls

[Run 45474493201](https://github.com/techrote/cybersand/actions/runs/45474493201)
used exact published source `2fc5974be7cd35aea6d5b1ad76d44d522e03bd17`, tree
`7e0505c5e675eec6e983ee474aca1e976075d802`. Linux passed all headless and displayed
groups, including complete redacted body hashes. Windows passed all headless
groups, displayed panel 272 checks, evaluator input 18, native OS clipboard 71,
outgoing preparation 125, native lifecycle 92 and changed near-cap Apply 23.
The Windows job still failed: its displayed network group hit the 300-second
process watchdog, and incoming preparation never received complete large bodies.
Neither the Windows package nor installed-launcher gates were reached in that run.

All five incoming preparation responses on Windows recorded transport timeout
13, HTTP status zero and an empty admitted body, with no assistant or usage turns.
The 16,773,283-byte assistant case timed out after 19.843 seconds of transport;
its measured interval contained only 113 frames, including post-timeout cleanup.
The largest frame gap in that case was 590.092 ms. The pinned engine calls one
`read_response_body_chunk` per process update and bounds that chunk by the
configured 64 KiB. At 250 ms per frame, about 1 MiB needs at least 17 body-read
frames (4.25 seconds), and a near-cap body needs 256 (64 seconds), before
connection/header overhead. The fixture's three- and twenty-second budgets
could therefore expire on Windows ANGLE over Microsoft Basic Render Driver.
A server-side `response_written` receipt does not establish client completion.
The independent complete-body verifier correctly refused those timeout receipts.

The follow-up keeps the 1280×720 native Workbench, actual input route, two-second
adjacent-frame limit, full-body hashes and unfinished-worker preconditions. It
uses explicit finite large-response transport/observation budgets and sufficient
bounded process time. Short timeout and absent-server conditions remain separate;
application defaults and provider implementation are unchanged by this fixture
correction. Slow rendering can still reduce real download throughput under any
owner-selected timeout, so this remains an explicit evaluator diagnostic boundary.

The same Linux and Windows screenshots exposed a separate usability defect:
the Conversation scroll body's direct child did not expand vertically, leaving
unused space below a short text pane. The product follow-up adds vertical
expansion and seven assertions through ordinary Conversation / + Note, including
at least 190 pixels of text-pane growth for 200 pixels of added dialog height,
reachable Apply/Cancel at both sizes and Cancel preserving live history. The
pre-fix screenshots remain negative visual controls. New runtime results must
be read against the follow-up source rather than attributed to `2fc5974b`.

## Qualified application and packaging boundary

[Run 45482969231](https://github.com/techrote/cybersand/actions/runs/45482969231)
qualified the application on source `981a740828decbeac04d5a14511d0222095de0a9`,
tree `9e37f6c4113e51b7aa9969bd7f3cc726405467bf`: Linux passed all 12 groups with
928 headless / 903 displayed matrix assertions; Windows passed all 12 groups
with 928 / 904. Both platforms passed panel 275/279, displayed native clipboard
71 and evaluator input 18. The short-note text pane grows 209 to 409 logical
pixels when the dialog grows by 200, and both displayed captures use the formerly
blank body while keeping the footer visible.

The Windows near-cap assistant actually received 16,773,283 bytes with transport
success and HTTP 200 after 48.129 seconds. Its complete redacted body hash matches
the fixture, and its maximum measured frame was 823.830 ms. Independent reviews
verified 16 complete body hashes and two complete changed-conversation hashes
per platform. The displayed 16,769,024-byte changed Apply took 354.215 ms on Linux
and 413.840 ms on Windows. Conditional assertion counts remain explicit: Linux's
incoming retry could not be observed after cancellation drained, and Windows's
intentional one-second header timeout completed before X in that one arm.

The overall Windows job then failed at the strict packaging source-input guard.
Its rejected filenames were not logged. All matrix provenance records showed no
tracked differences, so the repeated LF/CRLF warnings do not prove a cause or a
false-positive guard. The original refusal remains preserved; no evaluator ZIP,
installed launcher or loaded-module acceptance is inferred from that run.

Packaging now uses a second, fresh checkout of the committed candidate and its
own committed tools, with source-matched native LFS inputs and no prior Godot
import. The guard remains strict and reports rejected status rows. To avoid
repeating unchanged application tests, a separate proof permits reuse only for
an explicit packaging/workflow/test/guide change allowlist, unchanged protected
trees, the fixed prior run and application-step results, both immutable artifact
digests and all 12 complete successful receipts per platform. Any other source
change requires the full application workflow; an eligible reuse attempt with
missing or mismatched prior evidence fails. The prior Windows overall packaging
failure is never relabeled as success. Every successor must freshly qualify the
actual ZIP, extracted command launcher, native readiness/teardown, immutable
hashes and module paths. Its packaged source-scope receipt identifies both source
revisions and states that reuse proof alone does not establish package acceptance.

## Installed package integrity boundary

[Run 45493176632](https://github.com/techrote/cybersand/actions/runs/45493176632)
verified the complete source/evidence reuse proof for `2eedd8f3`, built the fresh
Windows ZIP and launched its actual extracted command file. Native Workbench
readiness and orderly teardown were observed with exit zero and no automatic
model request. Final immutable-file verification then refused
`godot/addons/godot-rapier2d/Radial2D.svg.import`; the module gate was not reached,
so that package remains unqualified.

Windows-style Git archive export reproducibly turns the committed LF vendor import
descriptors into CRLF text. The failed installation did not retain its rewritten
descriptor bytes; an interrupted minimal local import also establishes no completed
transformation result. The narrow packaging correction exports those descriptors
as committed LF, retaining every setting and the complete post-launch hash check.
The next installed run retains their exact before/after bytes to establish import
stability. Explicit file-specific line-ending attributes remain in effect. Archive
export also leaves LFS pointers intact so only the selected, size/hash-verified
Windows libraries are materialized. This does not establish the specific rejected
path in the earlier `981a7408` source-guard failure.

The actual installed software-rendered Windows run recorded readiness at 52.238
seconds, a 47.602-second startup frame, 168.370 ms maximum visible-idle frame and
394.253 ms teardown. Startup and owner-hardware behavior remain explicit limits;
the completed two-second matrix gates concern post-startup interaction cases.

## Ordinary desktop observation

The [Linux desktop receipt](linux-desktop-observation.json) records actual mouse
interaction on a 1280×720 X11 desktop using the exact Godot 4.7 binary and software
rendering. The loopback namespace was checked first and returned ECONNREFUSED for
127.0.0.1:1234. Send, ordinary X, reopen, manual painting, Note Apply/reopen and
Conversation Cancel/reopen were exercised. Painting changed 1,710 cells.

Send took 16.695 ms and X took 17.532 ms in this run. The request had already
failed when the physical X handler executed, so this observation does not prove
the outstanding-request immediate-X case. That ordering is covered separately
by the engine input harness. Software rendering had idle gaps as large as
461.951 ms and a 4.282-second startup gap; those costs remain in the receipt.
They are not silently removed or attributed to the absent provider.

## Independent review and resolved findings

Review rotated across provider transport, UI and qualification owners before
integration. The following findings changed the candidate or its qualification:

| Finding | Resolution and evidence |
| --- | --- |
| Threaded HTTP cancellation could join a blocked socket thread | Nonblocking engine polling; real accepted-POST/no-header before/after watchdog evidence |
| Hidden UI returned before checking a replaced World | Request epoch invalidation runs before the hidden-window optimization |
| Stop from a synchronous audit observer could dispatch or draw afterward | Generation checks before HTTP dispatch, after response/audit signals and before native admission; negative and passing regressions retained |
| Direct JSON audit observer Stop could admit a new batch | Capture and check the UI generation around the manual-program audit |
| Key dialog could assign a key to a provider selected after opening | Capture the dialog's provider; clear sensitive text on close/cancel |
| Error excerpt could cut a secret before redaction | Redact complete admitted content first, then bound the display excerpt |
| Malformed usage could put a key or megabyte string into status | Accept finite, nonnegative integer counters only; preserve the complete redacted envelope |
| Conversation list and repeated guard rebuilt/scanned all content | Bounded per-frame item population, revision polling and a full stale-content check on Apply |
| Large selected messages shaped all text in one widget | Bounded editable parts preserve the complete draft and image references; no truncation on Apply or Cancel |
| Deferred HTTP preparation could remember a turn too early | Match the captured UI/World generation and successful request-start signal; use the actual new image offset |
| Worker response inputs shared mutable packed buffers | Copy body/header buffers before handoff; later signal observers cannot alter them |
| A short registered key could rename the audit's body property | Keep an independent sanitized body projection without weakening property-name redaction |
| Scaled dialogs could push Apply/Cancel out of reach | Correct scaled minima and scrollable bodies; rendered geometry checks distinguish actual display space from headless dummy geometry |
| Conversation text pane left most added dialog height unused | Direct scroll child expands vertically; short-note resize, footer containment and Cancel checks |
| Windows clipboard fixture bypassed native LF-to-CRLF conversion | Native and production controls now use the same actual OS boundary; raw Copy/Cut values, Paste, selection and Undo are compared without normalization |
| Auxiliary windows lost their useful preferred size | Preserve Traffic/Guidance preferred dimensions where the host permits; clamp when space is small |
| Ctrl+F12 could miss a short tap or a child-window focus | Observe actual Window input events, deduplicate checkpoints and acknowledge saving in the title; 18 focused assertions |
| Packaging could consume changed transitive helpers | Gate tracked and untracked application/tools inputs before using committed Git archive sources |
| Packaging after use could include a private profile | ZIP only manifest-listed immutable files; regressions exclude profile, cache and diagnostics |
| Watchdog could leave a Windows wrapper's child alive | Terminate only the owned process tree before disposing the wrapper; preserve pre-teardown and execution receipts |

The 16,384-turn UI fixture, same-frame Cancel/reopen, Apply during list population,
key rotation, manual audit, native partial Stop and history identity regressions
retain their source-specific receipts. Historical v2 Art retrieval questions are
preserved [byte-exact](legacy-retrieval-questions-art-traffic-v2.json); the current
questions reflect accepted #727 session isolation.

## Evidence rules

Headless native, rendered synthetic Godot input, Linux desktop CUA clicks,
hosted Windows desktop and physical owner Windows/NVIDIA acceptance remain
separate tiers. Neither source inspection nor a passing workflow alone proves
physical responsiveness. No paid inference or private configuration is used.

The [owner guide](../../operations/art-workbench-final-evaluation.md) contains
the reproducible matrix and short physical checklist. The focused workflow requires
headless and displayed Godot runs, the extracted Windows launcher smoke and
loaded-module paths. Those receipts must be read against their exact source
identity; an earlier donor run is never relabeled as final candidate evidence.
