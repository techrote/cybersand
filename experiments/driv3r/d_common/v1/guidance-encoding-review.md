# D-COMMON-001 — guidance field semantics and encoding options (OWNER DECISION OPEN)

**Status: REVIEW ONLY.** The Owner selected "Review alternative encodings or meanings", **not** "approve positive-only u16 forever". The existing `guidance` schema retains its **provisional interoperability baseline** (`u16le` with higher = stronger soft attraction, 0 = neutral) so the D-1B worker can continue isolated development without an incompatible midstream guess. This note contrasts semantic meaning (what values mean) with storage encoding (how bits represent them). The guidance part of v1 is **not yet owner-approved/frozen**, even if the strict common contract passes syntactic tests.

All choices below are **soft guidance**. Neither any positive nor any negative hint is a native material prohibition, collision rule, focus extension or permission grant. Protected-material constraints always reside in the host-authoritative `observation.rules` / native admission.

## Comparison

| Proposal | Meaning and suggested encoding | Advantages | Risks / costs |
|---|---|---|---|
| **A — Positive scalar desirability (current candidate)** | 0 = neutral; max = maximally preferred. Little-endian `u16` per pixel; intensity renders as seeded sparse→dense speckles | Simple brush, fixed-point replay, small footprint, naturally supports highlighted path/target and scalar scoring | Cannot express dislike without a separate host constraint/penalty; zero may be mistaken for prohibition unless explicitly called neutral; density plateaus cannot encode travel direction |
| **B — Signed scalar preference** | Negative = discourage; zero = neutral; positive = attract. Could use signed `i16` or pair of nonnegative `u16` layers | Elegant combined attraction/repulsion for corridors, n-flakes, erosion limits | Requires declared scale and clipping, semantic "repulsion" never a hard mask; signed combination may allow unrelated positive and negative preferences to cancel |
| **C — Multiple named nonnegative channels** | `u16` attraction, optional `u16` avoidance, optional target and age masks; combine via explicitly versioned recipe | Prevents cancellation ambiguity; per-channel inspection and ablation; configurable analogue-synth routing | More data, more ports, runtime complexity; blend rules and priorities must be defined and versioned |
| **D — Signed distance field** | Integer signed cell-distance from a boundary (e.g. `i16`), explicitly specify interior/exterior sign and distance transform; derive a 6–10 pixel band preference | Especially suited to wall offset, erosion depth, reentry hysteresis and contours; makes objective geometrically interpretable | Not inherently "how desirable" a point is; gradient/brush rendering is derived; overflow/transform direction and multiple walls need metadata |
| **E — Vector/flow guidance** | `(dx,dy)` steering vector per cell, e.g. two signed fixed-point channels and magnitude or unit convention | Encodes clockwise/counter-clockwise contour following, planned routes, winding paths, worm heading | Larger records, undefined vectors at junctions, not a substitute for scalar "goodness" or legal path checks |
| **F — Greyscale/colour/alpha PNG as primary** | Image channels interpreted as guidance intensities or labels with pinned decoder settings | Human-friendly import and editing | Colour-space, gamma, alpha handling, quantisation and speckle stochastic gaps make raw images less reproducible as primary semantic data |

## Recommendation for the owner to consider (not yet approved)

**Recommended minimal v1: A, with an explicit extensibility principle.** Keep one `u16le` positive-preference field that can be painted by a long-gradient stippling airbrush, imported from grayscale, or procedurally rasterized. Require named unit/coordinate conventions and distinguish numeric field from its optional seeded image. **Guidance zero is neutral, not "outside the lines" illegality.**

Permit deterministic, versioned **derived features** in experiment recipes (e.g. signed distance to original n-flake perimeter, local gradient direction, normalized guide-field intensity, material avoidance from native geometry) without adding multiple wire encodings now. They must be recorded with generator algorithm/revision and never redefine the base u16 samples.

If an early D-2 research case genuinely needs repulsion, add a **separate typed channel** only after observing that need and comparing with a conventional deterministic penalty. A signed scalar (B) is smaller and simpler than C but makes multi-objective attribution more ambiguous; C is preferable if independent source-defined control signals become central to a node/synth authoring system.

For line-following specifically, the most useful initial host data may be **both** a scalar preference field and a separate geometric signed distance metric, not forcing one to impersonate the other. For self-avoidance, the *visited-cell set* remains an authoritative controller/history constraint, not another attractive-colour overlay.

## Unresolved M1 decision

Choose one of:

- **A1 — Freeze the positive-only u16 scalar baseline for v1; log other encodings as future experimental extensions (recommended).**
- **A2 — Require a generic typed multi-channel container in v1, including signed and directional channels, before freeze; accept a wider contract and more qualification.**
- **A3 — Separate guidance into independent `preference` (u16) and `geometry_metrics` (signed distance/vector) records now; avoid general multi-channel graph design.**
- **A4 — Other owner-authored meaning/encoding; record exact sign, zero, clipping, blend and sample semantics before altering schema.**

No choice means v1 remains a **candidate**, even though other owner-approved refinements are implemented and qualified. Do not silently change the current D-1B worker's u16 research or infer a choice from its progress.

## Semantics invariant across options

- Source World coordinate frame is integer XY, origin upper left, row-major raster. Every guidance record states its **canvas_size** and bounded frame. Field dimensions must match the referenced World when consumed.
- Numeric samples are the authority for numeric experiments; PNG/speckles are evidence/display and may differ visually due to seed, gamma or sampling, with source converter/hash recorded.
- A preferred region threshold is a suggestion to consider a recovery candidate. The native host still decides legal operations, materials, focus, protected regions and Stop.
- Long-horizon comparisons must account for extra information exposed by a channel and retain equivalent controls and frozen interpretations. Typed conversions and ablations are recorded rather than treated as prompt paraphrases.
