# Retained Water can permanently withhold an ordinary actor

**Status: reproduced playability defect; Draft/HOLD.** This is a separate
headless causal diagnostic. It does not qualify a renderer, physical NVIDIA
behavior, visible pixels, or matched performance, and it does not change the
production presentation policy.

## Finding and scope

The third Linux campaign's eight-actor captures completed genuine physical
steps while withholding many passive actor submissions. The independent
qualification lane found 1,463 of 5,632 body submissions withheld on the 512
case, and 1,286 of 5,200 on the 1024 case. Long hidden episodes usually occurred
outside the current Follow view. Counts of centers inside that submitted view
are a diagnostic, not proof of visible pixels. In particular, the historical
observer did not record the later endpoint-clearance results, so its first
`bounded_pose_delta` reason cannot establish the final cause of those particular
frames.

A separately declared reproduction now establishes a concrete mechanism with
the actual Main, native worker, Rapier bodies and copied material histories.
After 600 ordinary completed session/manual steps, three passive Needle actors
settled at the basin floor. Each actor's 7 by 3 footprint contained **21 Water
cell centers in both current and previous material images**. Its native GCR row
reported **21 unresolved overlaps and zero displaced cells**. The real query
order for each of those bodies was:

| Query | Actual result |
| --- | --- |
| Retained previously shown pose to current physical pose | `bounded_pose_delta` |
| Native-bound endpoint to that same endpoint | `material_in_swept_mask` |
| Current completed Rapier endpoint to that same endpoint | `material_in_swept_mask` |

The last two queries inspected the exact current physical endpoint in this
settled stimulus. Their cells contained material ID 3, Water, with no hard
material in the body footprint. The terminal frame examined only 200 charged
cells and recorded zero guard-budget vetoes. The first refusal label therefore
obscured the later, more decisive material refusals. Raising the 32-cell motion
limit would not make either endpoint clear.

The probe then paused and requested the bottom-of-basin camera view while
selecting one of the withheld actors. The same three actors remained withheld.
This records CPU presentation admission after that ordinary view request; the
probe did not capture a submitted camera matrix or graphical framebuffer.
Source inspection independently establishes that camera position does not
participate in coherent pose admission.

## Why the native result is legitimate

`CyberNativeCellWorld::reconcile_overlap` retains stored movable material when
its bounded `find_ejection_target` search finds no reachable Empty destination.
It records the unresolved overlap and applies the existing reaction impulse;
it does not destroy Water to make the body mask empty. A hard material follows
the separate Rapier contact path. `World::copy_render_cells` copies the actual
stored cell material rather than erasing material beneath transient masks.
Wave's negative scratch mass for masked cells preserves that underlying stored
state.

Those contracts preserve native mass and ownership. They also mean that a
physically valid, submerged actor need not have an empty material footprint.
Main's current coherent policy requires both material footprints to be empty,
even for its explicitly discontinuous endpoint re-entry after a prior omitted
submission. This is a conflict between valid simulation state and the display
admission contract. It is a playability defect, not a successful result merely
because physics and geometry validators pass.

The bounded ejection contract and stored-material rendering were independently
source-reviewed by the native specialist. Relevant primary implementation:

- [Native overlap handling](../../../godot/native_extension/cyber_native_cell_world.cpp).
- [Stored render bytes and Wave semantics](../../../native/src/world.cpp).
- [Continuous swept clearance](../../../godot/scripts/workbench_presentation_coherence.gd).
- [Actual Main endpoint admission](../../../godot/scripts/main.gd).

## Exact reproduction identity

| Component | Identity |
| --- | --- |
| Application source | `498fa47da062db702a74665f177e06f454d956aa` |
| Explicit diagnostic source overlay | `godot/tests/pubpres_endpoint_diagnostic.gd`, SHA-256 `495a75aa49bc6470f3a9ff6c09d9417b9b0a062e880716855cc22073eadb698c` |
| Native build source | `c2f8a73d34448bc1496ecd84bca02f0812c80d27` |
| Native Linux runtime | SHA-256 `33d9c39ecfca71c800f538dbf3edbbb85675c0c65be35d6af525f699b7d15dc0` |
| Godot 4.7 stable Linux executable | SHA-256 `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75` |
| Rapier Linux runtime | SHA-256 `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |
| Full seven-capture receipt | SHA-256 `5b9bc187653ff32c5f6053cb43be7b59e017e84da2f33dc479a1a5763f3a70bf` |

The source overlay only records the results of actual inherited Main queries.
It never changes a query result, body state, World cell, sample admission,
simulation callback or physical clock. Extra observation costs are not treated
as ordinary performance. The application includes the count experiment, but
the probe explicitly selects count 0 and wall deadline 0. Full two-image
publication, coherent selection, measured material timing and Early physics
remain explicit. The source and native hashes differ intentionally: the
application-only count commit makes no native change.

The authored 512 geometry, eight actor positions and native gameplay Water
options match the mixed fixture, but controls are neutral and the live-paint
tape is omitted. It is not a matched replacement for the historical capture.
The exact original source, engine and runtime receipts remain retained.

## Reproduction and independent byte checks

The fixture runs through ordinary mounted Workbench Apply, waits for actual
native material and complete terrain, unpauses normally, and observes actual
steps 120, 240, 360, 480 and 600. It then pauses and requests the camera return.
All seven captures retain direct Rapier RID and copied bridge poses, copied
native GCR rows, actual query results, and bounded RG8 crops from each body in
both CPU material histories. The direct RID and copied bridge poses match.

Exact 4.7 parsing passed. The corrected diagnostic process exited zero in
19.333 seconds with seven captures and no diagnostic failures. That wall time
is process bookkeeping, not a gameplay performance result. A first exploratory
capture is retained separately because its query slot labels used deep Array
equality and conflated identical Needle rectangles. The corrected observer
uses reference identity; the first capture is not the slot-query authority.

Run the same explicit diagnostic with:

```sh
CYBERSAND_SOURCE_REVISION=498fa47da062db702a74665f177e06f454d956aa \
CYBERSAND_ENDPOINT_DIAGNOSTIC_OUTPUT=/absolute/evidence/receipt.json \
Godot_v4.7-stable_linux.x86_64 --headless --path godot \
  --script res://tests/pubpres_endpoint_diagnostic.gd
```

The caller must stage the exact runtimes and the exact application plus declared
fixture overlay. The command is not permission to relabel a different tree.
The retained invocation used an isolated ordinary user-data directory.

The separate [Python replay reader](../../../tools/pubpres_final_endpoints/replay.py)
reconstructs cell-center occupancy from decoded, hash-checked RG8 crop bytes.
It verifies all 112 body/history planes across the seven captures, actual
source/engine/native/Rapier identities, real paired session/manual counters,
actual RID/copy pose agreement, and the terminal native/query/material joins.
It refuses footprint boundaries too close to ambiguity when reconstructing
float32 transforms from the recorded rotation representation.

```sh
python tools/pubpres_final_endpoints/replay.py /absolute/evidence/receipt.json \
  --output /absolute/evidence/crop-reconstruction.json
```

The [retained full receipt](submerged-actor-reproduction.json),
[replay result](submerged-actor-replay.json), and
[six adversarial controls](submerged-actor-replay-adversaries.json) preserve the
complete causal evidence. The replay passed all 112 crop planes. It rejected
self-consistent hard-material substitution, a false direct-RID pose, missing
native unresolved overlap, false endpoint clearance, changed engine identity,
and a float physical counter. The [independent qualification review](submerged-actor-independent-peer.json)
also passed all 112 planes, complete footprint coverage, unique/stable actual
RIDs, actual runtime bytes and unchanged native inputs, and the terminal
World/session/epoch/sample/actor-generation joins. It identified 12 harmless
unused crop-border differences from float32 versus double trigonometry; all
actual body-cell centers agree. Full parent-image bytes were not exported, so
the crop origin remains source-bound `get_region` evidence rather than a second
cryptographic check against a retained full parent image.

The reusable reader now enforces that review's additional identity and complete
coverage predicates. The [follow-up replay](submerged-actor-identity-replay.json)
passed all 112 planes and rejected six further RID/World/session/epoch/actor
generation/sample substitutions. The probe and original receipt remain byte
identical. No source-policy change is certified here.

## Required repair boundary

A repair must preserve strict swept-motion proof for consecutive visible
poses, hard terrain refusal, World/session/generation identity, real native and
Rapier endpoint provenance, monotonic selected time, and both material histories.
Neither camera return, elapsed time nor a higher pose-delta allowance can erase
the observed Water or create a clear endpoint.

Displaying this legitimate submerged state requires an explicit composition
contract for a proven actor endpoint and retained soft material. Such a design
needs source-bound current/previous visual composition, an independently
reconstructed first-read framebuffer oracle, solid/stale-history adversaries,
and ordinary deep-fluid/camera-return qualification. Merely bypassing the
clearance refusal or claiming that an opaque overlay hides the disagreement is
insufficient. This diagnostic leaves that repair open and all defaults intact.

## Documentation impact

This checkpoint adds a diagnostic and evidence reader, with no changed runtime
API, ownership, scheduling, capacity, material law, save format or user control.
The canonical rendering/gameplay contract and the programme decision packet
must retain this as an outstanding physical-playability limitation until a
separately qualified visual repair exists. Historical mixed captures retain
their original physical and image-history results and their newly identified
presentation limitations.
