---
title: SOL281 headless CPU render-consumption and acknowledgement control
status: Current
document-kind: audit
scope: Exact-source Linux/Windows scoped CPU-render qualification and causal native-buffer census; not GPU upload or interactive throughput
canonical-for: [sol281-render-ack-consumer-control-evidence]
last-reviewed: 2026-10-28
related-documents: [../systems/solid-detachment.md, 2026-10-28-sol281-render-exchange-microstages.md, sol281-2026-10-28/render-ack-control-receipt.json]
---

# SOL281 consumed-render ACK control — 28 October 2026

## Frozen predecessor and question

The [frozen preregistration](https://github.com/techrote/cybersand/pull/283#issuecomment-6478381684)
references exact previous draft head `1884eb1e38a32a29fd1a3f9e817a718999929411`,
whose executable source `d441a8a593f001d944d5f0691eab63d7614023c5`
passed [four-job scoped Linux/Windows CI 40724802526](https://github.com/techrote/cybersand/actions/runs/40724802526)
(1,414 assertions per OS, zero failures). The earlier
[render microstage audit](2026-10-28-sol281-render-exchange-microstages.md)
found two native render-exchange calls on **every** observed active refresh
in the headless detachment fixture and identified missing render-packet
ACK as a serious performance confound. The normal desktop renderer
ACKs only after successful texture upload. The new question is limited to
how an **actually consumed CPU image** changes this *headless* accounting.
This is not a GPU-frame or release criterion.

## Source and controlled changes

The current implemented executable/test/workflow source is
[`55aa72e5db6b23731a2ccdccbca91ccfd80bfe90`](https://github.com/techrote/cybersand/commit/55aa72e5db6b23731a2ccdccbca91ccfd80bfe90).
The exact source tree, CI, host observations and artifact identities must
be read back separately before any runtime qualification. This record
is a **source inspection**, not an assertion that current CI has passed.

Five path changes introduced the original code/control at `80c77505`:
`godot/scripts/solid_detachment_render_consumer.gd`,
`godot/scripts/solid_detachment_session.gd`,
`godot/tests/test_solid_detachment_render_ack.gd`,
`godot/tests/test_solid_detachment_coupling.gd`, and
`.github/workflows/sol281-targeted.yml`. Three corrective source
commits `cebfccd6`, `cdba95d8`, `55aa72e5` explicitly admit retained
full-frame packets **with appended dirty patches**, test the case,
and update the scoped expected count. Earlier exact-source CI runs
remain distinct (whether successful or failed), not silently
reclassified as this latest source.

`CyberSolidDetachmentRenderConsumer` is an opt-in main-thread-side
`RefCounted` helper. It reads only immutable copied snapshot fields;
there is no access to native World, no worker-side Godot API or GPU
texture object. The consumer requires strictly increasing serial,
valid world generation, one or two bytes/pixel, correct full-world
prefix on first/reset/channels-changed use, and complete finite
rectangles/row strides/byte extents. It stages every `Image` patch
before blitting into its private CPU image. A valid retained-full
packet with later appended dirty patches is applied in order.
On successful consumption alone, the session ACKs the exact copied
render serial to the worker. On rejection it never ACKs, requests
a full refresh, and retains its previous accepted image/serial.
The default isolated session remains the unacknowledged negative
control; no ordinary presentation, physics or liquid policy is
changed.

This is a **CPU consumption model** of the desktop's payload
validation/patch application, not proof of completed GPU texture
upload or a replacement for actual desktop frame telemetry.

## Bounded host qualification protocol and exclusions

The modified [scoped workflow](https://github.com/techrote/cybersand/blob/55aa72e5db6b23731a2ccdccbca91ccfd80bfe90/.github/workflows/sol281-targeted.yml)
must execute on source-matched actual Linux and Windows Godot 4.7/Rapier2D
0.35.2 with the existing pinned native toolchains and archive manifests:

- Seventeen direct CPU-payload checks (full/dirty pixels, stale serial,
  malformed stride/bounds, changed-generation partial, incomplete full,
  valid full plus appended dirty) with refusal preserving old state.
- The original six-proxy 81-candidate A and unpromoted 289-candidate B
  headless coupling controls, still deliberately without render ACK.
- An additional A=81 opt-in **actually consumed** CPU image cohort,
  asserting consumed/ACK counts match, no invalid/rejected packets,
  original source-owned 520 cells, two real compound holes, Sand104,
  Water mass1020, 12-field result ABI, safe epoch fences and zero
  unclassified stale outputs.
- Compare per-cohort accepted sample counts, render-active/exchange
  p95, one-vs-two native call counts, payload bytes and worker overruns.
  A and B are independently paced/unsynchronized histories and must
  not be called paired or deterministic cross-host comparisons.

The expected count, if all added scoped tests execute, is 17 direct
CPU assertions and 59 per six-proxy arm; historical 1,414-per-OS
statements apply **only to old source**, not to this revision.
Source-matched qualification status is deliberately tracked in
[the separate receipt](sol281-2026-10-28/render-ack-control-receipt.json).
No new native C++ relocation, native ownership, material law, liquid
construction policy, Rapier collision shape or asynchronous owner
handoff is introduced in this experiment.

## First controlled Linux observation — exact predecessor source 80c77505

This is **not** final-source qualification of `55aa72e5`. The
first implementation at [`80c775056cbe4e0b0e65ad901843cb7fe4ce3de7`](https://github.com/techrote/cybersand/commit/80c775056cbe4e0b0e65ad901843cb7fe4ce3de7)
passed the actual Linux Godot/Rapier portion of
[scoped run 40754078838](https://github.com/techrote/cybersand/actions/runs/40754078838).
The direct CPU payload unit suite passed **15/15 checks, zero failures**;
each of the three live compound arms passed **59/59 checks, zero failures**.
The focused native predecessor suite passed another 13,074 checks.
Independent download and `ZipFile.testzip` CRC verification of the
Linux execution ZIP matched the Actions-upload SHA-256
`07d21882f6cedd7c2dbb880f30766fc3dc7a8f656fac2199696eeb0ef867280d`.
Both `source.txt` and `report.json` in that ZIP bind to the
`80c77505` executable. The later `cebf`/ `cdba` / `55aa` correction
adds valid retained-full-plus-dirty semantics and two extra unit
checks; no older result is promoted to that corrected source.

| Actual Linux predecessor mode | Accepted latest-only samples | Active render refreshes | Two-call native refreshes | Native exchange p95 | Render p95 | Worker overruns | Successful CPU ACKs |
|---|---:|---:|---:|---:|---:|---:|---:|
| A=81, no ACK | 143 | 96 | **96/96** | 52.499 ms | 52.640 ms | 103 | 0 |
| A=81, CPU consumed | 128 | 108 | **108/108** | 51.400 ms | 51.559 ms | 109 | **109** |
| B=289, no ACK | 127 | 108 | **108/108** | 51.485 ms | 51.622 ms | 109 | 0 |

The CPU-consumed A cohort accepted **109** real full CPU image
applications and post-consumption ACKs, **zero** rejected payloads,
and accounted for **228,589,568** accepted render bytes. It still
made **two native calls on 108/108 sampled refreshes**, exactly
the same two-call prevalence as the unacknowledged A and B fixtures.
Each arm retained the 520-member native aggregate, six distinct
compound proxies and both declared holes; report assertions still
cover Sand104/Water1020, 12-field ABI, physical motion and source
ownership. The A modes are **unpaired asynchronous trajectories**:
the 1.099 ms difference in native exchange p95 is *not* a validated
speedup. The CPU-consumed A main-thread physics-step p95 was 1.561 ms
versus 0.216 ms in the unacknowledged A cohort, but that CPU image
processing overhead is not GPU upload or complete-frame pacing.

**Negative conclusion:** successful image consumption/ACK by itself
does **not** remove the double native-exchange pattern in this
fixture. The earlier suggestion that missing ACK alone explains the
expensive native exchange must remain **unproven**. Two-call behavior
could also arise from single-call dirty payload volume, patch-count
limit, native publish capacity or arrival/ACK timing; none is yet
separated by an observed first-packet status/buffer-before-after
counter. A further preregistered status/byte/overflow census, followed
by representative rendering/total-loop pacing, is needed before
optimizing. The final executable SHA and actual Windows host results
are separately pending. B=289 remains physical-efficacy NO-GO.

## First controlled Windows observation — same exact predecessor source 80c77505

The actual Windows-Godot 4.7/Rapier2D v0.35.2 execution job of
[run 40754078838](https://github.com/techrote/cybersand/actions/runs/40754078838)
also completed successfully. Its three 59/59-assertion compound arms and
15/15-assertion CPU payload unit suite reported zero failures.
The Windows execution ZIP independently passed ZIP CRC validation and
matched its Actions SHA-256
`dd7e2c1c94e43fbd06e0c6ffad46030c8fa609425cf3d32c74eab5bd6ee9bcff`.
The corresponding Windows-build ZIP matched SHA-256
`f6f137f5d3b730460573b5d6b1804bd709129cabf87a04288a7e88c634d31f97`.
Its 551 Git-input source manifest entries were verified by the hosted
source check; the independently compared build DLL bytes matched the
execution runtime SHA-256
`9ae8b8608a60aded3da6da8af5202c073513d546f9c51aa328cbd39e9ce3153d`.
Ten Windows execution log hashes matched the archived report.

| Actual Windows predecessor mode | Latest-only samples | Active refreshes | Two-call native refreshes | Native exchange p95 | Render p95 | Worker overruns | Successful CPU ACKs |
|---|---:|---:|---:|---:|---:|---:|---:|
| A=81, no ACK | 268 | 145 | **145/145** | 23.392 ms | 23.868 ms | 32 | 0 |
| A=81, CPU consumed | 312 | 135 | **104/135** | 23.802 ms | 24.257 ms | 27 | **136** |
| B=289, no ACK | 285 | 169 | **169/169** | 23.678 ms | 24.168 ms | 37 | 0 |

Windows' CPU-consumed A cohort successfully processed/ACKed **136** immutable
CPU packets containing **220,202,438 bytes** in total; refused
**zero**. Its two-call prevalence fell from 100% in the unacknowledged
control to about **77%** of sampled refreshes, whereas Linux
remained at 100% with or without ACK. Neither host demonstrated
a meaningful p95 render-stage improvement from ACK alone, and the
observed Windows CPU-consuming main-thread physics-step p95 rose from
0.403 ms (no ACK) to 2.727 ms. These are independent trajectories,
not a causal speed-up/slow-down trial for GPU presentation. The
**platform divergence** means missing render ACK can influence
some Windows refreshes but cannot be the sole cause of double
exchange or long render-stage p95 on either OS. Next attribution
must record per-call native `status`/`cells` byte counts,
pending-buffer size before/after accumulation and why the existing
overflow path requests a second full exchange.

**All four scoped jobs passed on source `80c77505`, not on the later
`55aa72e5` retained-full-plus-dirty correction.** The new final-source
Linux/Windows run and exact-head documentation consistency are
separate required gates, not inherited from these predecessor results.

## Final corrected-source qualification — exact `55aa72e5` (2026-10-28)

This paragraph **supersedes the historical pending-source qualification
status above** without altering the earlier `80c77505` results. The corrected
retained-full-plus-appended-dirty source
[`55aa72e5db6b23731a2ccdccbca91ccfd80bfe90`](https://github.com/techrote/cybersand/commit/55aa72e5db6b23731a2ccdccbca91ccfd80bfe90)
(tree `165643fdd94a3e68aac28cf073745a37b127033b`)
passed **all four** jobs in the
[exact-source Linux/Windows scoped run 40754382057](https://github.com/techrote/cybersand/actions/runs/40754382057).
Both actual Godot 4.7/Rapier2D v0.35.2 hosts passed 17/17 direct CPU
render-consumer assertions, three 59/59 live six-proxy compound arms,
21 motion checks, 20 rollback checks, 296 lifecycle checks across 18
owner replacements, 43 cause/ABI checks and 924 bounded ejection-policy
checks, totalling **1,498 per OS**, all with zero failures. The Linux
native suite separately passed 13,074 checks. The final-head documentation
successor [`a8fdb186`](https://github.com/techrote/cybersand/commit/a8fdb186d5dab3b7012857aa052990b1ff4a779e)
passed [documentation/provenance run 40755560034](https://github.com/techrote/cybersand/actions/runs/40755560034).

All four downloaded Actions ZIPs passed independent CRC/SHA-256 checks:
Linux execution `62ef39f9fa225292288df58c9ad7ad5e789a8c5f24135dd636ccd057a1db8299`;
Windows execution `e3f613e10bdde26d38ddd0338c824f0430b87530df90b7479fd33e4e8b7e9049`;
Windows build `2c13fb3d3fb9b1325769dceec013f6533155042df017ee9be13475fc0d0e5492`;
exact-source archive ZIP
`8562087c4e2dfbf059c53b11eb1df6cfc07d642fd3d1517ea5e0ca89b64c7a5a`.
The archived source and Git tree match the executed SHA, the Windows
source manifest's **551/551 Git inputs** match the archived exact source,
and the Windows DLL build/execution identity
`bea97f80f4f7c3f9aa2ff1f3b24b6f3489e8168a781244b1bb87c15393d64b3e`
plus all ten Windows execution log hashes were verified.

| Source 55aa host/cohort | Active sampled refreshes | Two native calls | Render-active p95 | Worker overruns | Consumed / ACK |
|---|---:|---:|---:|---:|---:|
| Linux A=81, no ACK | 139 | 139 | 29.141 ms | 50 | 0 / 0 |
| Linux A=81, CPU consumed | 99 | 87 | 29.356 ms | 41 | 99 / 99 |
| Linux B=289, no ACK | 122 | 122 | 28.894 ms | 49 | 0 / 0 |
| Windows A=81, no ACK | 150 | 150 | 22.620 ms | 28 | 0 / 0 |
| Windows A=81, CPU consumed | 118 | 102 | 23.312 ms | 25 | 123 / 123 |
| Windows B=289, no ACK | 141 | 141 | 22.852 ms | 29 | 0 / 0 |

All CPU-consumed packets were accepted and ACKed after real main-thread
CPU image application; zero refused. Distinct asynchronous trajectories
preclude causal speedup comparisons. The large **double-call prevalence**
persisted despite correct ACKs; therefore missing ACK alone is not the
explanation, and no desktop/GPU throughput or 60 FPS acceptance is claimed.

### Subsequent source-level diagnostic candidate (not inherited acceptance)

Before editing, [the next status/overflow-census protocol](https://github.com/techrote/cybersand/pull/283#issuecomment-6478970282)
was frozen on the above exact-source evidence. Executable candidate
[`5531ac7d47141e040a368c0057be640cbf0e3721`](https://github.com/techrote/cybersand/commit/5531ac7d47141e040a368c0057be640cbf0e3721)
adds only immutable scalar observations of first native packet
status/byte/full-refresh, retained pending bytes/rectangles, ACK clearing,
and the **actual existing** byte-limit vs rectangle-limit predicate that
triggers the second native exchange. Its seven new live assertions per
compound arm (59 to 66), and modified scoped CI, are separate tests.
Native World/C++ cell ownership, Rapier bodies, ejection policy,
material construction and render control flow are unchanged.
[Source-matched candidate scoped CI 40758417713](https://github.com/techrote/cybersand/actions/runs/40758417713)
was initiated; **its outcome, actual host metrics, full artifacts and
source qualification must be read back before calling this candidate
passed**. In particular, counters do not yet demonstrate a safe
optimization or justify promoting B=289.

## Qualified first-packet/overflow census — exact source 5531ac7d (2026-10-28)

Following the [frozen preimplementation protocol](https://github.com/techrote/cybersand/pull/283#issuecomment-6478970282),
executable and test/workflow commit
[`5531ac7d47141e040a368c0057be640cbf0e3721`](https://github.com/techrote/cybersand/commit/5531ac7d47141e040a368c0057be640cbf0e3721)
(tree `309a3de937f184b030a86e5aaacd58258e3b5970`)
passed all four jobs in
[scoped Linux + actual Windows Godot 4.7/Rapier2D v0.35.2 run 40758417713](https://github.com/techrote/cybersand/actions/runs/40758417713).
**Each OS passed 1,519 scoped assertions and zero failures**:
21 real motion, 20 failure/rollback, 296 lifecycle/18 replacement
cycles, 43 ABI/cause, 924 bounded ejection-policy protocol, 17 direct
CPU-render-consumer checks, and **three 66-check** six-proxy
Sand/Water compounds (A=81 unacknowledged, A=81 CPU-consumed/ACKed,
B=289 diagnostic unacknowledged). Linux native focused also passed
13,074 checks. Native 520 exact cells, the six disjoint non-filling
Rapier proxies and two geometrical holes, Sand104 and Water mass1020,
the 12-field ABI, epoch fences, zero stale or unclassified results,
and the native-worker/main-thread Rapier split remain scoped qualified.
**No native C++ cell/physics rule, motion policy, material/liquid
configuration, native exchange-call cadence or GDScript overflow threshold
was changed**; this commit adds immutable counters, host assertions and
workflow expectations only.

Archived artifacts were independently downloaded, CRC/SHA-256 validated,
and source/runtime identities reconciled:

| Artifact | Actions upload SHA-256 |
|---|---|
| Linux actual-host ZIP | `2dc7050d3c035bf0c396bb7c55992c4c0209ed610f383bb6a01409b079eeff2f` |
| Windows actual-host ZIP | `ef1178ed653f57029f8c1e84de0ace413bee20877c04c887bc194ae8070fb915` |
| Windows build ZIP | `5f0d45144fde2f6b08ee862fad51c42e002ce13ee799fe8f03b0a333e9968b07` |
| Source archive ZIP | `d6c859f49ac2590688e3991166cd5343c70039d0d6144e9002acb41747aa2bd5` |

Nested exact-source `source.tar.gz` SHA-256 is
`4730970b142e2ca6363f8d988907acdf970c7f423a166fc624ce162afd1ac612`.
The Windows build manifest authenticated **551/551 archived Git inputs**
with zero mismatches, its DLL SHA-256
`13108d6cf9291e43849738428483f7a016bebb53228f14ff42d84724833f429b`
matches the Windows execution runtime report, and all ten execution logs
match their archived SHA-256. No predecessor artifact was substituted.

### Measured first-packet and fallback classifications

All accepted latest-only *render-active* first native packets in
**both OSes** had `RenderPublishStatus::Published` (status 1) with
nonempty dirty bytes. The existing explicit **pending byte-size overflow**
alone caused **every observed second forced-full exchange**. There were
zero native backpressure/capacity first packets and zero
rectangle-metadata-only or combined overflow retries. Whenever a
second call occurred, the **existing pending full RG8 image**
was exactly 2,097,152 bytes before appending the dirty packet,
making the old `> 2,097,152` pending-buffer guard true.

| Actual host / search policy | Active refreshes | Single / double calls | First status Published | Byte-only / rect-only / both overflow | ACK-cleared samples | Render-active p95 |
|---|---:|---:|---:|---:|---:|---:|
| Linux A, no ACK | 109 | 0 / 109 | 109 | 109 / 0 / 0 | 0 | 38.800 ms |
| Linux A, CPU consumed | 93 | 0 / 93 | 93 | 93 / 0 / 0 | 0 | 38.872 ms |
| Linux B, no ACK | 105 | 0 / 105 | 105 | 105 / 0 / 0 | 0 | 40.024 ms |
| Windows A, no ACK | 108 | 0 / 108 | 108 | 108 / 0 / 0 | 0 | 23.431 ms |
| Windows A, CPU consumed | 124 | **23 / 101** | 124 | 101 / 0 / 0 | **23** | 24.643 ms |
| Windows B, no ACK | 140 | 0 / 140 | 140 | 140 / 0 / 0 | 0 | 24.123 ms |

In the Windows CPU-consumed A arm, all **23 single-call samples**
coincided with the recorded ACK-based pending-buffer clear before the
first packet; the remaining 101 had retained-full-before and
byte-overflow retries. Linux's consumed cohort successfully consumed
and acknowledged **94 packets**, Windows consumed/ACKed **125**, with
zero refusals, yet Linux's 93 sampled render-active iterations recorded
no ACK clear. ACKs therefore demonstrably occur, but do not necessarily
clear the retained full packet before each independently paced worker
refresh. Counts are **sampled latest-only observations**, not all worker
ticks or a causal timed A/B trial. Sampled first/retry byte sums reconcile
exactly with overall exchange bytes; all recorded timing consistency
checks passed.

**Causal resolution within the tested fixture:** the second native
call is provoked by appending a valid small dirty packet to a retained
full-sized render buffer and crossing the fixed byte guard. The
previous missing-ACK theory was only an incomplete hypothesis: on
Windows, occasional timely ACK clears prevent this particular retry;
on Linux, correct ACKs did not coincide with such clears in the
sampled refreshes. This does not establish a single cause for every
desktop render cost or a representative GPU/60 FPS result.

**Next separate decision gate:** preregister a capacity-explicit,
hole/material-independent *render-only* retained-full/dirty-patch
coalescing or bounded-budget candidate with correct consumer ACK
semantics, exact readback and failure/overflow tests before changing
any production fallback. Preserve the original negative B=289
physical-search result, full ownership and conservative material
relocation limitations. The current experiment is **diagnostic, not an
optimization**; #281 remains OPEN, #283 draft and unmerged on #282,
ready-PR CI and independent review remain outstanding.

## Retained negative evidence and outstanding gates

The previous extended B=289 ejection search **remains NO-GO** under
its frozen 20-percentage-point improvement criterion. The preceding
[failed count-expectation run 40694452595](https://github.com/techrote/cybersand/actions/runs/40694452595)
and original unacknowledged microstage timing remain separate negatives.
Even a materially lower CPU-consumed cohort p95 cannot demonstrate
desktop/GPU 60 FPS or safe physically admissible material
displacement. Completion of representative full worker publication,
main-thread renderer and frame pacing, a conservative bounded physical
relocation rule, reactive Wood/chemistry, fracture/desoliding,
restoration, multiple aggregates/persistence, independent source
review, broad ready-PR matrices, normal gameplay integration and
published runtime evidence remain open. Issue #281 is **open**;
PR #283 is **draft and unmerged**, stacked on draft #282.
