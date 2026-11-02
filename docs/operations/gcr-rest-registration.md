---
title: GCR budget and contact-rest comparisons
status: Planned
document-kind: design
scope: Preregistered isolated budget, persistence, correction and constrained-catch experiments; no sleep or merge
canonical-for: [gcr-rest-experiment]
last-reviewed: 2026-11-02
related-documents: [gcr-load-aware-registration.md, ../architecture/compound-granular-coupling.md]
---

# GCR-REST-001 registration

## Source and authorization

Owner authorizes varying the inherited20 budget, mass/inertia payload multipliers
through64, and comparisons of contact persistence, rest-aware correction and
residual catch. Sleep, material-law changes, production promotion and merge stay
excluded. Start from PR350 d3e90e6bffa99a7724a4b94d5ec3840d80f0604a, fresh isolated
codex/gcr-rest-comparison-20261102. Fetched main remains
a8f08a67fea3c58f6df7473cbae1831334fcc04e. PR349/350 remain unmerged/read-only controls.
One native response owner and main-thread Rapier application remain authoritative.
No body is cached into native cells and payload mass520 is preserved by default.

## Frozen budget and control changes

Developer base budget B is finite5..80, default20. Preregister sweep5,10,20,40,80.
LA total is B*max(1,min(actual_mass,4096)); passive capacity is the minimum of
remaining total after event cost and2*source_count*scale. Per-source2 remains
fixed. Moving events retain ceiling20 but may not exceed the shared total.
Record global/source limiter, requests, acceptance, event cost and normalization
saturation. A null change when per-source capacity dominates is a result.
Rest arms are always tested at20; no sweep winner is selected to tune rest.

Raise mass/inertia multiplier admission/UI0.01..64, retain friction0..4 and
gravity0..368.48. Absolute barrel mass remains0.01..32; its inertia factor also
reaches64. Preserve the separate4096 mass-normalization ceiling and label actual
mass, inertia and effective scale. At defaults original LA numerical behavior
must be unchanged. Test64 acceptance,64.01 refusal and friction4.01 refusal.

## Frozen rest variants

Explicit fresh-session modes: control LA, P persistence, R correction, C catch,
and PRC combined. No ordinary/default promotion. New reset token and immutable
same-sample experimental context bind gravity, known external drive and hard
clearance; unknown context never grants catch. Metadata is not a second owner.

P retains one bounded quiet history per physical body. Require fresh sample,
stable admitted support signature, no observed granular events, measured zero
post-ejection overlap, known hard clearance>2cells, and small actual same-phase
contact-point displacement plus small proposed residual contact velocity,
including angular motion. Enter after30 fresh accepted sample observations at
speed<=0.1cell/s; exit at>0.25 or immediately on changed support/overlap/event.
Use validated cached node impulses to warm-start the same four-pass solver only
while admitted; preserve authored mu for both sticking and sliding. Re-clamp
cached values to current node capacities/cones, seed provisional velocity once,
and serialize the final total once. Cache at most1024 normal/tangent pairs
(16KiB plus fixed metadata); source coordinates/material/state/face, geometry,
mass/inertia/mu/dt and session/sample compatibility bind reuse. Clear on any
invalidating support/event/context change. No saved blocked external impulses
or unbounded history. False/no admission is reportable,
not permission to relax thresholds after outcomes. Gentle driving may be resisted
within the cone; it vetoes catch and cannot be smoothed away.

R suppresses positional withdrawal only with explicit current native zero
post-ejection overlap. With positive/unknown overlap retain bounded translation.
Omit opposing-velocity zeroing before the already computed native J/L in R/PRC.
Record translation, old zeroing counterfactual and actual pre/post wrench energy
separately; translation is not kinetic-energy dissipation. This tests the retained
double-arrest accounting; it does not assume every late motion has one cause.

C is a constrained native residual wrench, never a main-thread velocity snap.
After the same30-sample quiet/support gate, require no known drive, no events or
non-granular reaction, explicit zero overlap and hard clearance. Certify both
the gravity-support wrench(0,-m*g*dt,0) and full residual linear/angular arrest
within actual contact cones, node capacities and the shared budget. A bounded
3x3 contact-wrench Gram solve may conservatively refuse singular/infeasible
patches, including unsupported pivots. Finite/passive guards remain mandatory.
No certificate means unchanged uncaught response and an explicit refusal reason.
Catch output requires age0 and unchanged actual sampled velocity at main-thread
application; otherwise refuse, never apply stale arrest. Report counterfactual
uncaught J/L, catch delta J/L, predicted and actual energy removed. The same
single accumulated physical wrench is applied once. Quiet history alone is not
proof of equilibrium. No sleep, pose latch, masked-overlap hiding or material edit.

Storage remains fixed; extra Gram/certificate scans are explicitly metered and
bounded by1024 nodes per physical solve, with no tick-time heap allocation.
Original modes retain their four-pass8192 scalar-update ceiling. Experimental
certificate work adds at most six bounded node scans and constant3x3 algebra;
report separately from ordinary scalar updates. No unbounded convergence loop.

## Registered population before candidate acquisition

Per OS, workers1, fixed60Hz physics; genuine asynchronous compound ownership,
retained synchronous barrel apparatus. Budget lane: barrel mass2/speed90 and
actual520 isolated_full at each of five B values (10 captures). Partial guards:
half/narrow at B20/B80 (4). Rest lane at20: gentle driven barrel, edge barrel,
isolated_full520, conditional excavation520, Water-only, each LA/P/R/C/PRC
(25), reusing the shared isolated_full LA20 capture exactly once. Original packed
structure LA/PRC (2), original mass1/high barrel LA/PRC (2), Salt23 gentle LA/PRC
(2). Total44 per OS,88 valid primary captures maximum; no repeats or efficacy
tuning. Budget captures1200 ticks; rest captures1800; tail300 observations.
Machine coordinates, drive schedule, modes and output fields must be committed
before acquisition. Source-matched mechanics and native/sanitizer controls first.
The reused isolated_full LA20 control captures1800 ticks: budget comparisons use
only its first1200; rest comparisons use its1800 horizon and final300. Preserve
both window definitions instead of comparing mismatched tail periods.
Gentle-drive barrel uses explicit main-thread Jx0.02 each tick600..659, then
Jx2.0 each tick900..905, before the Rapier step. Record actual commanded impulses
and veto catch during those intervals; never store blocked input for later release.

Excavation is conditional on a genuinely admitted quiet-contact window before
hard contact; otherwise report NO_VALID_REST and do not claim support-loss
qualification. A separate held-body mechanical test proves immediate retirement
under source changes/drive/stale contexts without pretending to be gameplay.
Record actual hard clearance and floor/wall flags; hard-supported rest cannot
qualify granular rest. The original confounded stump fixture remains available.

## Gates and decisions

Exact original LA default equivalence, conservation/Water quantity, native payload
properties, one-wrench ownership, immutable copied context, finite refusal and
bounded work are mandatory. Budget high arms may not worsen penetration/overlap
beyond max(0.5cell,10%)/max(1cell,10%); rebound control+2cell/s. Unsupported or
incomplete overlap remains null. Positive rest claims require genuine admission,
no hidden overlap, nonincreasing sampled kinetic energy, explicit removed-energy
closure and no catch holding under gravity/torque demand outside contact capacity.
No drive suppression, persistent small-support hover, edge-angle lock, excavation
hold or Water-only friction. Tail span target<=0.5cell and |vy|p95<=0.1cell/s for
admitted hard-clear rest; nonadmission remains inconclusive/failed scope, not zero.
Preserve gentle lateral breakaway and free edge rotation. Report timing/work
amplification; investigate both>25% and>25us p95 increases, without treating local
functional timing as uncontended performance acceptance. Owner feel is separate.
All failures remain. Build fresh Windows/Linux runtimes, retain compact summaries
and hashes, open a focused draft successor and keep all PRs unmerged.

## Pre-implementation design clarification

Read-only review distinguishes persistence from a larger friction coefficient.
Replace the draft1.25 static-mu multiplier by same-mu cached-impulse warm starting
before any implementation/result; the frozen source coefficient remains unchanged.
The copied rest context also binds the last actually applied sample; repeated or
unacknowledged preparations cannot advance quiet dwell. Rest receipts are explicit
versioned copied values, not actionable fields smuggled through generic diagnostics.

The C arm deliberately tests full residual arrest at the existing application
phase. Post-step zero velocity does not guarantee same-phase position rest under
the following gravity integration; gravity-compensating velocity can be valid.
Record those phase boundaries and allow NO_ADMISSION/NO_REST rather than adding
an unregistered pre-step impulse, changing gravity, or claiming a velocity snap
proves rest. Any timing-law successor requires separate evidence/registration.
Standalone C additionally refuses when the old positional correction is nonzero;
otherwise old zeroing would change the velocity for which arrest was certified.
This does not silently add R to C. PRC may use its explicit R policy to remove
unnecessary correction and then qualify the constrained catch independently.

## Pre-acquisition safety review corrections

Read-only review found that source sampling precedes queued edits and the native
tick. Rest-only source predicates/signature and endpoint overlap must therefore
be revalidated at result generation; changed material vetoes catch/persistence
and clears quiet/cache state, without rerunning relocation or changing baseline
prepared force. Meter the extra bounded raster/source queries separately from
the six node scans. Cached getters cannot retain authority across same-tick edits.
Current measured overlap also governs R suppression. No candidate captures
preceded this correction.

Bridge admission additionally binds receipt base budget to configured budget and
rejects every caught response with nonzero correction, including PRC. Reduction
must enforce the same configuration identity and measure delivered-wrench velocity/
angular change, not just recompute an energy subtraction. Preserve preliminary
mechanical failures and explicitly distinguish arithmetic from delivered closure.
Late hard-terrain edits additionally retire rest authority through the native
hard-surface revision fence. Revalidation latches observed source/overlap changes;
an erase-and-restore completed entirely between queries with identical current
cells is not parcel-history tracking. Current support is still revalidated.

Pre-acquisition evidence review additionally requires exactly one physical-body
receipt and one accepted matching session/sample application at age0 for a current
quiet observation. A compound observation copied from an earlier physics call
cannot count again merely because its stored application age was0. Acquisition
records delivery within the current physics call; reduction verifies that marker
and the snapshot transition. Startup gaps, delayed samples and repeated stored
observations remain visible without qualifying current rest or triggering
conditional excavation. No physical candidate results preceded this correction.

Global conservation uses four existing bounded native diagnostic tiles covering
the complete1024x1024 stored-cell domain in one paused exclusive-owner inspection.
Only compact counts and exact stored Water quantity cross to the capture; pixel
arrays are discarded by that owner. Regional160x128 balances remain descriptive.
The native payload/cut and isolated stump removals are independently known setup
changes. A triggered brush excavation spans native ticks between observations;
without an independent brush-removal ledger, its observed edit-adjusted balance
is descriptive and strict conservation for that edited trajectory stays null.
Do not absorb arbitrary intervening loss as intentional removal or call that
mandatory gate passed. Admission and motion-target gates also remain separate
from overall physical acceptance, overlap coverage and delivered-energy closure.
