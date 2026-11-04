# Independent displacement review for SOL-DETACH-001

Date: 1 November 2026. Read-only review of `809fd30dfac0c5e127302997075be9c4b279e5aa`, frozen #283 `254235ec4c3d58782bba44b478caca86bf57c856`, #336 `7e04e8fde1496c5f32d3f83099ec2a6bfb6bb7d6`, and #338 `61f0398e5a6d63432be681dc4a4d32da769f2b20`. No implementation source, branches or remote records modified by this review. This report is implementation input, not runtime qualification or owner approval.

## Evidence that changes the implementation choice

The #338 full finite cohort contains 1,301 contacts: 1,231 no-target, 70 direct successes. The unchanged <=4-parcel copied-state chain oracle recovers only two failures (0.16247%), both a single Sand parcel into an adjacent Empty. Chains of length 2–4 add zero. 1,094 failures have no interior void; 919 have no interior or diagnostic-ring void. This is an independently qualified primary-mechanism NO-GO, not a missing radius setting. Preserve it alongside the older B=289 NO-GO.

The two apparent adjacent positives are NOT full square/body clearance proofs. I independently evaluated oriented rectangle versus unit cell-square separating axes using the exact captured geometry. Tick106 `(108,163)->(108,164)` has greatest separating-axis gap -0.4918590297620271. Tick103 `(107,163)->(106,163)` has greatest gap -0.5277558049855722. All four axes overlap. The original oracle conserves parcels and clears the center-sampled mask, exactly as claimed; these results do not retract it. They show why center occupancy alone cannot admit the new stronger path.

The #338 source is a single-rectangle Sand cohort. The frozen #283 compound/tree cohort is distinct; do not transfer its recovery rate or sampled timing without a new source-matched run. Full-square geometry will intentionally refuse cases that historical center-mask geometry admitted.

## Smallest defensible admitted increment

An explicitly opt-in structural-contact policy may move a bounded cardinal chain, tail-first, under one serialized native World owner. Each nonempty parcel moves exactly one cell. A terminal existing Empty is required. Hard/immovable material, foreign masks, unsupported material/solver state, unknown/unresident/excluded cells, repeated cells, excessive chain length, stale ownership and insufficient capacity refuse before any mutation. Ordinary generic coupling can retain its established default.

Require finite, nonzero trusted contact normals. Each edge has nonnegative projection on the actual outward normal and total projection is positive. Do not flip a valid face normal to match body travel: exit contacts naturally disagree. Use deterministic declared traversal and an explicit ambiguity rule. A choice among equally safe paths needs a documented deterministic policy; ambiguous ownership or incomplete geometry must refuse.

For every destination, check the entire unit cell square against every current compound proxy rectangle, not only center masks. Reject touch/near-zero gap under one declared tolerance. Retain swept-mask barriers as well. For cardinal unit steps, the swept cell volume is covered by the union of the two endpoint squares; this prevents intermediate barrier crossing when both endpoints satisfy the full-cell barrier checks. The initial overlapped source is a deliberate exception for its own aggregate, and must not gain an exception for an unrelated body. All subsequent cells are outside every body.

Strict policy must govern every detachment displacement; adding it only after ordinary permissive direct search leaves successful teleports through occupied Sand/Water in the supposedly conservative path. No-target does not authorize larger search, deep compaction, deletion or unobserved rasterization elsewhere.

This is an independently useful shallow-boundary rearrangement primitive, NOT a solution to packed-bed high-energy penetration. A fully packed local volume has no legal parcel permutation into Empty. Correct refusal preserves material; body resistance remains GCR/current-main contact owner work.

## Transaction and bookkeeping review

`World::relocate_stored_cell` is not a complete transaction: it only validates nonempty/Empty/mask and calls `move_cell`. `move_cell` writes payload before its temperature writer may allocate. Before the first move, preflight resident chunks and every required destination thermal field for the complete chain. Preallocation can happen at setup; do not allocate during the admitted commit. Reject pressure/inertial sidecars and non-Current Water until exact sidecar semantics are independently qualified.

Preflight the complete path against current stored tuples, current masks, source revision/owner identity and contact sample. Perform the whole commit without yield or owner handoff. Copy full semantic material/state/temperature values. The existing mover intentionally sets scheduling epochs to the current update epoch; preserve raw spare bits where applicable and state explicitly that scheduling epoch is operational metadata, not conserved semantic payload. Ambient temperature on the vacated Empty is the existing convention.

Use existing move bookkeeping for activity wake, dirty render cells, pressure-input invalidation and settled-discovery mutation witnesses. Do not substitute direct payload assignment without recreating those invariants. Measure chunk and temperature allocations; check explicit refusal on missing residency/capacity before mutations.

Mark all chain coordinates as used for the current coupling preparation, including the vacated contact and terminal. This prevents two contacts from relocating the same intermediate parcel repeatedly or sharing one void. Replaying a contact must not duplicate displacement or a cellular impulse. One accepted contact retains one existing contact reaction; intermediate moves do not independently add reactions. Force/torque ownership stays with existing coupling; Rapier stays motion authority.

Material/state/temperature conservation is defensible. Mechanical energy or momentum conservation is not established by the existing capped reaction law. Avoid describing the latter as proven.

## Frozen replay inputs produced by this review

`pr338-reduced-contacts.json` retains eight complete original copied capsules, their original B/C classifications, normal/travel values and independently computed geometry. They cover no local void, diagnostic-ring-only void, permissive routes through movable material, production-success control, rear-only strict Empty access, and both false full-clearance positives. They are deliberately chosen counterexamples, not a representative statistical sample.

Canonical #338 population SHA-256 is `d3c8bfeb19355e7bf20518bb7d6afd4b03e1f3790644a09414c4d8ea0955d33c`; source path and Git blob are in the file. Executed acquisition source was `8203d2d1bae2151c1a2d4909df5b08ab5b5012eb`. The report retains original identity and distinguishes it from current-main execution.

`new-boundary-chain-controls.json` is separate analytical data. Four positive cases use a shallow, rotated body boundary and one- or three-parcel Sand/partial-Water/mixed chains into an existing pocket, with strictly positive full-square clearance and per-edge normal projection. Negative controls add a foreign mask, a hot parcel outside the declared ambient scope, a second compound proxy that overlaps the cell square but misses its center, and exact touching. No actual runtime pass is implied by these generated controls.

Both files have reproducible extraction/construction scripts beside them. No historical artifact was rewritten.

## Required meaningful tests

Native transaction tests should cover full tuple/quantity conservation, exact source vacancy, mask invariance, expected order, no writes outside path, dirty/wake effects, current epoch, seam crossing, sleeping neighbors, duplicate/reused sites, cycles, invalid normal, rear step, over-capacity, blocked terminal, unsupported material/temperature/solver, missing resident or thermal capacity, and stale/failed/fenced World refusal with byte-identical before/after payload.

Adapter geometry tests should cover rotation, internal compound seams, holes, full-square/center-mask disagreement, foreign-proxy partial overlap, exact contact tolerance, swept-only contact and degenerate geometry. Assert refusal reason independently of aggregate unresolved totals. Test strict policy and unchanged ordinary default separately.

Actual-host tests should make at least one multi-parcel chain occur through the normal serialized owner path. Count accepted chains and moved parcels separately from displaced contact count. Include packed/no-void refusal, partially embedded pockets, mixed Sand/Water, multiple contacts sharing a proposed void, support excavation, compound motion/torque, reset/replacement and workers1/4 on Linux and Windows. Verify source-matched binaries and fixture identities. Native-owner contact totals and accepted main-thread result snapshots are different denominators.

For A/B efficacy use frozen identical contact geometry. Asynchronous host totals and trajectories are qualification observations, not causal per-contact recovery comparisons. Keep headless step cost separate from actual graphical frame pacing. Gameplay feel, GPU Windows execution, wider GCR integration, restoration/fracture and persistence remain separate gates.

## Exploratory execution correction

The first local replay attempt was a **failed prequalification**, retained in `../replay-initial.log`. The newly authored partial-Water boundary fixture assigned coherence values 11/12/13; Current Water permits only 0..12. Value13 was an invalid analytical input and caused the old unguarded replay facade to throw during import. The corrected synthetic tuple uses11/12/0. No historical #338 capsule changed. The complete inspected invalid fixture is preserved as `conservative_contacts.pre-water-state-fix.json`, SHA-256 `8c86e3d13d667b6b3f91dedd36e734bec00c4278c49c78e1f3c8d257456e64ca`; `water-state-prequalification-failure.json` records this correction and its source-identification limitation.

The same initial run's first two positive Sand cases refused. A separate minimal execution of each returned `TransactionRefused`, native outcome12=`Excluded`, because replay setup selected a simulation region without applying its owner boundary. This is apparatus setup, not evidence against the displacement path. The exact minimal outputs are retained in `../replay-single-case.log`. A corrected replay setup must apply its empty-world region before importing frozen material, or explicitly clear the diagnostic selection while preserving normal production fences; it must never advance the captured parcels to make the fixture pass.

The live test fixture now also separates three geometric refusal cases: foreign geometry at the source (center-mask first-writer hides it), foreign geometry at the destination with positive source clearance, and exact destination touching with positive source clearance. Their expected exclusive causes distinguish the source check from the destination check; refusal alone is insufficient to identify which guard executed.
