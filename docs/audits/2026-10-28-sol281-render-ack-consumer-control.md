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
