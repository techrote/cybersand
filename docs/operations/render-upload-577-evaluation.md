---
title: RENDER-UPLOAD-577 owner evaluation
status: Current
document-kind: guide
scope: Opt-in sparse and dense material publication, exact-source evaluation and owner hardware gate
canonical-for: [render-upload-577-evaluation]
last-reviewed: 2026-11-16
related-documents: [../architecture/rendering-and-gameplay-bridges.md, ../architecture/data-ownership-and-lifetimes.md, current-and-historical-validation.md]
---

# RENDER-UPLOAD-577 owner evaluation

**Candidate / Draft / HOLD until qualification is recorded.** The production
default remains full-image `ImageTexture.update()`. Issue #577 owns this bounded
implementation; #578, #583 and #585 are evidence predecessors, while #609, #628
and #631 remain independently owned, unmerged branches.

## Publication choice

`--render-upload=full` is the unchanged accepted-main upload policy.
`--render-upload=hybrid` enables
[`material_upload_hybrid.gd`](../../godot/scripts/material_upload_hybrid.gd)
through [Main](../../godot/scripts/main.gd). It initially keeps two compact R8/RG8
textures. Dense packets, explicit full refreshes and reconstruction always use
an ordinary compact full-image update. A canonical full CPU packet uses the
validated `Image.set_data()` path adapted from #609, avoiding another full
temporary Image and blit. That CPU optimization is also opt-in on this branch.

After four consecutive sparse publications, each covering at most one sixteenth
of the plane and at most eight merged 64-cell tile regions, the candidate may
enter sparse mode. It lazily allocates two RGBA8 drawable targets. Each target
is seeded once from the complete accepted current texture, then receives sparse
regions from the complete validated CPU Image. Reuse repairs every changed tile
that destination missed. The previous texture remains the complete preceding
accepted publication, including across compact/drawable transitions.

The two transition seeds are full GPU drawable writes and are charged explicitly.
They are not sparse transfers. Dense/sparse alternation restarts admission and
does not seed; excessive history coverage, fragmentation or staging pressure
returns to the compact path. The criteria are bounded implementation choices,
not a claimed universal hardware optimum.

R8/RG8 array layers would permit compact tile replacement but would require
changing all current/previous material and effect samplers. RenderingDevice
solutions do not supply a universal Compatibility backend. The selected first
candidate preserves the existing complete `Texture2D` shader interface. Its
extra memory and sparse-entry cost must be assessed in the measured decision.

The API boundary is pinned to Godot 4.7: [`ImageTexture.update()`](https://docs.godotengine.org/en/4.7/classes/class_imagetexture.html#class-imagetexture-method-update)
replaces an image with matching dimensions and format; it has no rectangle
argument. [`DrawableTexture2D.blit_rect()`](https://docs.godotengine.org/en/4.7/classes/class_drawabletexture2d.html#class-drawabletexture2d-method-blit-rect)
is a documented experimental public API, so this candidate pins the runtime and
runs a byte canary on the selected backend.
[`ImageTextureLayered.update_layer()`](https://docs.godotengine.org/en/4.7/classes/class_imagetexturelayered.html#class-imagetexturelayered-method-update-layer)
is the supported layer alternative, with the shader-interface cost described
above. [Compute shaders](https://docs.godotengine.org/en/4.7/tutorials/shaders/compute_shaders.html)
require an RD renderer, excluding a transparent replacement of Compatibility.

## Pending data and acknowledgements

The hybrid launch also enables the independent
[`render_pending_journal.gd`](../../godot/scripts/render_pending_journal.gd)
policy. `--render-pending=baseline` isolates the upload change;
`--render-upload=full --render-pending=compact` isolates the ACK change.

The exclusive simulation owner retires acknowledged capture prefixes and exact
superseded rectangle batches. Capture continues at its ordinary cadence. If a
missing ACK exhausts bounded sparse retention, one complete CPU image can retain
the current state, with per-tile serials allowing later ACKs to restore sparse
publication. This avoids repeated native full captures without gating simulation
or declaring an unaccepted publication acknowledged. Generation changes and
explicit refreshes preserve their original identity and recovery rules.

Main still ACKs only an accepted material publication. A malformed/refused
candidate retains its accepted GPU pair, withholds the ACK, requests a complete
refresh and recovers to ordinary textures. A void rendering API returning means
validated command submission, not measured GPU completion or device-loss proof.
Native World, material laws, physics stepping, collider invalidation and camera
coordinates remain owned by their existing implementations.

## Bounds and observations

The journal has at most 4,096 tiles. Sparse staging is bounded to 32 submitted
batches / 16 MiB and is retained through the rendering frame boundary. A reusable
pool retains at most 16 staging textures / 2 MiB. A 2048-square RG8 compact pair
has 16 MiB nominal target storage; the lazy drawable pair adds 32 MiB. These are
logical resource sizes, not physical VRAM or total process RSS measurements.
The optional pending CPU cache is at most 8 MiB for a 2048-square RG8 plane.

Receipts separate validation, CPU image work, staging extraction, staging texture
creation/update, drawable calls, total publication and frame intervals. Comparing
only `blit_submit_usec` with full `ImageTexture.update()` would omit candidate
work. Logical bytes are not measured PCIe traffic; `frame_post_draw` is not
physical scanout. Final texture readback runs outside timed cohorts.

## Workbench comparison

The self-contained Windows package provides `Open Workbench.cmd` for the full
baseline and `Open Candidate Workbench.cmd` for the opt-in hybrid. No Python,
Godot, Git or development tools need separate installation. Extract into a fresh
writable folder and run one application at a time.

1. Start each arm from the same canvas, generator settings, Water family, native
   worker count and actor setup. Keep display size, effects, VSync and pacing
   settings the same.
2. While paused, paint repeated small strokes, separated strokes and large areas
   on 512-, 1024- and 2048-square canvases. Include several small strokes after a
   full generation or reconstruction to expose sparse-entry cost.
3. Run heavy Sand/Water activity with one and four workers. Compare PressureFlow,
   FreeMass and the other supported families without changing their laws or
   input workload between arms. Watch material age and actual actor motion,
   rather than relying on FPS alone.
4. Move a Rapier actor through terrain contact while panning/following. Check
   current/previous blending, picking, paint/Undo/Redo, generator installation,
   Flatten, Save and fresh-process reopen.
5. Use Engine Lab to select upload policy or record ten seconds of ordinary
   play. Its live switch preserves the accepted current/previous pair and does
   not advance the material serial or reset blending. The accepted-main panel is
   a focused adaptation of #609's Engine Lab; it does not import that branch's
   independent-clock or presentation-coordinator experiment.

`Test It.cmd` runs matched, sequential ABBA subprocesses and writes a portable
evidence ZIP. The raw receipts identify source/tree, runtime hashes, backend,
case, requested/actual workers, publication distributions, actual native and
Rapier cadence, material age, resource observations and refusal/recovery events.
Source-bound final qualification, downloadable artifact identity, negative cases
and the independent-review verdict belong in the dedicated PR ledger.

## Reproduction and acceptance boundary

On a real graphical display with the pinned runtime and materialized matching
native libraries:

```sh
python3 tools/render_upload_577/run_campaign.py \
  --godot /absolute/path/to/Godot_4.7 \
  --source-sha FULL_COMMIT_SHA \
  --output /absolute/new/evidence \
  --cases manual_2048_w1,dense_2048_w1,active_2048_w4 \
  --frames 180 --warmup 30 --rounds 1
```

Each case retains a complete same-host ABBA. No hardware percentages are inferred
from different hosts. R8/RG8 exact per-publication history, native/CPU/texture
identity, full fallback, delayed/missing ACK recovery and mounted Workbench
authoring must pass before performance is considered. Dense/full and active
four-worker regressions can hold the candidate even if sparse calls improve.

**Owner Windows 11 NVIDIA acceptance remains outstanding.** Hosted Windows ANGLE
software rendering and Linux llvmpipe are real graphical execution but cannot
establish physical NVIDIA speedup. No merge, auto-merge, Ready promotion or
production-default activation is authorized by this evaluation.
