---
title: Bounded native sample distribution follow-up
status: Planned
document-kind: audit
scope: Separate context-quality change, outside frozen qualification source 2743f89a
last-reviewed: 2026-11-25
---

# Bounded native sample distribution follow-up

This additive native-lane change is **separate from the frozen principal source
`2743f89a0df6f6afcf7484e859c10790d521e74b`**. It must not be attributed to that
evaluator or treated as qualified without incorporation and fresh tests.

The prior sampler selected 32 equally spaced indices from a row-major plane.
For a 64 by 64 region, indices 0, 128, 256 and so on all have x=0; the 256 by 192
native fixture region has the same left-edge aliasing. This does not falsify the
reported values, change full-plane native validation or remove the separate
complete histogram/16-by-16 occupancy summary. It does reduce the usefulness of
the optional exact-cell observations.

The follow-up uses the centers of deterministic spatial bins. Ordinary regions
use up to eight columns and four rows. Short or narrow regions adapt while
retaining at most 32 distinct, inside native coordinates. A selection with at
most 32 cells reports every cell once. World-coordinate offsets and material
values come directly from the private copied capture.

The model-visible `native_sampling` metadata records the method
`stratified-bin-centers-v1`, grid shape, 32-cell maximum and the explicit limit
that unsampled cell identities are not inferred. Owner-disabled native summaries
omit both samples and this metadata. Inspector provenance retains the selection
method. There is no network, live World access, new mutation authority, changed
proposal geometry, changed source policy or changed context/payload budget.

Focused Godot regressions check power-of-two quadrant coverage, truthful sampled
values, translated one-cell-wide selections, complete small selections and
omission when disabled. The native specialist's executor remained unavailable;
the changes therefore require a fresh Godot run. A JavaScript arithmetic check
of 64×64, 256×192, 1×64, 64×1, 3×2 and 3×11 shapes found inside, distinct samples
within the 32-cell cap; that check is not a Godot or native qualification.
