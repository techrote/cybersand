# Exploratory review of declared clearance relationships

This small read-only diagnostic makes the access limitations in the nine viewed native constructions more concrete for owner review. It is **not a new acceptance gate**, a change to the frozen thirty-attempt experiment, or evidence of actor playability. It evaluates only relationships between explicit stage-level clearance rectangles. Module-local clearances and cavities are outside this probe set. Enclosed machinery and planting-container cavities are not treated as route failures or scored.

The input is the exact Linux native geometry from hosted run **45447549238**, source **`1fb4fbb5b1edd6cee16ee9094691f3438f8577eb`**. The nine planes already passed the separate [native and visual review](hosted-architecture-review-45447549238.md). The [reproducible script](review_negative_space.py) checks the source declarations, plane lengths, and hashes before analysis; the [retained result](exploratory-negative-space-review.json) records the manifest hashes, every plane hash, and each actual probe coordinate.

## Explicit assumptions

The geometric probe is a **5 × 5-cell square**. Its center moves by one cell in any of four axis directions, and all twenty-five occupied probe positions must remain Empty and inside the native crop. This artificial motion has no gravity, jump limit, fall damage, velocity, collision response, or material evolution. Five cells is a declared diagnostic size, not an asserted actor dimension.

Probe points are the integer centers of every unique explicit stage-level clearance rectangle, transformed from World coordinates to the local native crop. No spawn, goal, equipment access point, or preferred player route is invented. Component membership compares those centers pairwise; it does not require that the author intended every pair to connect. Full-crop voids and sealed cavity component counts are deliberately omitted from the result.

## Observed relationships

Every declared probe point accommodates the square. The table describes which declared spaces share a continuous path under the artificial movement rule.

| Construction | Declared centers | Connected groups among those centers | Owner-review implication |
| --- | ---: | ---: | --- |
| Assembly hangar | 2 | 1 | The central bay probe and lower-band probe share free square space; access to elevated galleries is outside these probes. |
| Interconnected arcology | 3 | 3 | The lower corridor and two upper clearance probes are separate spaces under this rule. A room-access or vertical circulation design must declare its intended connections. |
| Biomechanical arboretum | 2 | 2 | The middle band and lower slot are separate. Access between them should not be inferred from the material continuity of the galleries. |
| Irregular megastructure | 2 | 2 | The central vertical void and lower corridor do not share a free-square component. Their separate placement is not automatically an authoring failure. |
| Service network | 7 | 1 | All declared corridor and gap probes share free square space. This allows unrestricted vertical motion and does not establish stairs, climbing, or a real actor route. |
| Constructed cavern | 4 | 1 | The central, lower, and two ledge-clearance probes share free square space. Jump reach and usable ledges remain untested. |
| Modular assembly hangar | 1 | 1 | Only one declared region is probed; no inter-region connectivity claim follows. |
| Modular service stack | 3 | 3 | Each of the three reserved service-level bands is separate. This supports the visual observation that vertical access has not yet been demonstrated. |
| Modular transfer viaduct | 1 | 1 | Only one declared region is probed; access onto the deck is not established. |

The script was checked against a small synthetic separator: a solid wall separates two fitting square probes, while an exact five-cell opening connects them. Those checks exercise the square footprint and component calculation; they do not add gameplay qualification.

Specialist A independently repeated all nine planes and all twenty-five probes using obstacle-centered radius-two dilation followed by four-neighbor flood fill, instead of this script's integral-image footprint calculation. Every admissibility result and probe partition matched. The retained independent cross-review is `clearance-space-cross-review-a.json`, SHA-256 `5be358d83449bb9d952e95d31060695c3679f1fbd772ca699adda8c960e08d16`.

This review stops at those relationships. It supplies concrete questions for owner-led construction revision and playtesting, without applying a quality penalty to intentionally separate spaces or declaring that connected empty pixels are a playable level.
