---
title: SOL281 headless CPU render-consumption and acknowledgement control
status: Current
document-kind: audit
scope: Source-level diagnostic implementation and pending actual Linux/Windows Rapier qualification; not GPU upload or interactive throughput
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
