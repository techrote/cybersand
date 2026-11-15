# D-1A — fair chance control for long-horizon experiments

**Design version:** `d1a-three-offline-controls/1` · DEVELOPMENT only · 36 host-admitted decisions.

The original `random_legal` baseline remains unchanged: uniform choice
includes STOP at every step, so many episodes terminate before acquiring a
meaningful path. This is a legitimate *unconditioned STOP* control but a poor
standalone movement-capability comparator. Do **not** revise, discard or
rescore the first-pass random traces.

A second explicitly versioned policy, `random_legal_persistent_v1`, draws
uniformly among **all currently legal movement candidates**, excluding STOP
until there is no legal move. It has no knowledge of the goal, selected wall,
visited cells or future geometry. The host supplies exactly the same
cardinal candidate menu and full swept-cell hard legality as before, including
1/2/4/8-cell macro arms. It stops on arrival, exhaustion of 36 decisions,
or no available movement. It may oscillate, retrace and fail; failures are
retained. A goal-aware random policy would be a *different* research arm.

`paired.run_development_controls()` independently replays three matched
controls: strong A*/contour, original random-legal with STOP, and persistent
random-legal. It compares the frozen initial legal menu and only the common
pre-divergence states, and labels all cursor effects **synthetic**. No native
permission, model inference, material effect, receipt, held-out behavioral
outcome or A1/A2/A3 superiority is claimed.

This addition is policy-versioned rather than changing `d1a-offline/1`
fixture serialization: all previous fixture SHA-256s, seed outcomes,
first-pass failures and original two-arm comparisons remain unchanged.

**Qualification:** six new authored unittest methods in
`test_persistent_random.py`. Run the entire exact-checkout CPU suite with
`python3 -m experiments.driv3r.stage_d.direct.qualification`.
Focused or static checks do not substitute for that execution. The M1 source
and schema remain immutable; adaptation to the M2/M3 native World/receipt
contract and a 36-decision native campaign require separate owner gates.
