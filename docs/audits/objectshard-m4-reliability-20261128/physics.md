# M4 physics convergence — 28 November 2026

## Implemented correction and its boundary

The owner-recorded rotational refusal was independently reproduced using the
pinned actual Rapier backend. A one-cell, unit-mass fragment with inertia 1/6
lands partly beyond a ledge. Its initial spin is zero; contact generates the
angular velocity. Five of twenty matched position/initial-fall-speed cases
exceeded the former fixed 0.20-radian ceiling and held despite modest geometric
travel. At initial downward speed 140 cells/s, the solver reached 65.4129 rad/s
and a completed segment rotated 0.296370 radians with 0.236561 cells of lattice
translation and 1.49395 cells of conservative corner movement. This is a
representative collision reproduction, not the owner's original pointer trace.

The native coordinator and actual Rapier bridge now use a physical material
reference: the current installed centre of mass. The motion domain encloses
every occupied Structural, Cargo and Product carrier and its bounded one-cell
contact ring. Empty columns retained after erosion do not count as material.
`min(pi/2, max(0.20, 4/d))` bounds rotation, where `d` is that active domain's
diagonal. Active spans of at least twenty cells retain 0.20 radians. The actual
corner-motion bound uses the farthest domain corner's radius about COM, which
is no larger than `d`. Additional allowed rotation therefore costs at most four
cells of corner arc. This is the retained eight-cell total corner allowance
minus the retained four-cell COM translation allowance; it introduces no larger
total material-motion budget.

The exact supplied continuous angular interval still enters native
`contact::plan_sweep`. Its half-cell spacing and 32-sample capacity are unchanged;
the eight-cell corner bound requires at most seventeen samples. Dense independent
corner samples verify the spacing guarantee. Native occupancy, Water contact,
Sand pocket admission and its curved-trajectory obstruction check all receive
the same geometry-sensitive envelope. No pose acknowledgement, native time,
physical step or material accounting is omitted or duplicated. Velocity and
momentum are unchanged. Unresolvable turns, nonfinite state, excessive
translation/corner motion and exhausted work still refuse safely.

Native interpolation follows a straight physical COM path and the continuous
angle, then reconstructs the unchanged storage-origin pose. Water samples and
the Sand pocket curve proof use that same reference. In the pocket proof,
`q(t) = R(-angle(t)) * (grain - COM_world(t)) + COM_local`; its chord-error bound
retains the second-derivative terms for angular curvature and COM translation.
This prevents empty storage columns from creating fictitious bowed material
trajectories. No carrier index, storage origin, pose identity or collision shape
is rewritten to make a completed segment fit.

Actual geometry replacement refreshes the bridge's domain. Product changes
without rigid geometry changes refresh at the exact between-interval material
barrier. Native publications bind the domain to material and geometry revisions;
missing, undersized, stale and same-revision conflicting domains refuse. Native
motion acceptance does not transfer material into owned carriers: its Sand
pass only records contact fences. Real lodging, chemistry and product motion
occur at semantic completion, before the next domain refresh and physics lease.
The domain therefore remains conservative throughout a compact-receipt interval.
The ordinary erosion fixture verifies that shrinking colliders preserve the
lattice pose, update mass/COM/inertia, wake for the changed contact graph, fall
through the removed supporting volume, and eventually sleep naturally.

The first two-cell-arc trial passed the twenty initial contact probes but an
additional natural-gravity fall exposed a further ordinary refusal: a fragment
with only 1.3 cells/s initial horizontal speed fell 35 cells, collided with the
ledge, and reached 126.745 rad/s with 0.553996 radians of segment rotation,
1.22324 cells of translation and 3.57365 cells of total corner travel. The
four-cell complement derives directly from the existing geometric budgets and
addresses this additional case. The original failed two-cell trial is retained
in `physics-natural-fall-comparison.json`; it is not relabeled as a pass.

## Ordinary erosion and storage-reference invariance

A second defect was demonstrated after the initial small-fragment correction.
Twenty-five ordinary endpoint erases reduced a connected 26-cell Wood strip
to one cell, preserving the existing RID, carrier indices and 28-by-3 storage.
Its mass and inertia were correctly one and 1/6, but its COM was now at local
`(26.5,1.5)`. A natural 175-cell gravity fall with only 0.5 cells/s initial
horizontal drift generated 55.8113 rad/s and 0.232286 radians of rotation.
The actual COM moved only 0.287659 cells. The abandoned storage origin moved
6.292388 cells, yielding a fictitious 12.833608-cell corner bound and protective
refusal after 360 acknowledged segments and 90 completed native intervals.
This ordinary repeated-cut defect was corrected within M4, not deferred to M5.

The final actual-native/Rapier regression compares the same occupied world cell
in tight 3-by-3 storage, a 28-by-3 parent eroded at the near end, and a 28-by-3
parent eroded at the far end. All three retain the exact material owner through
ordinary native edit/geometry acknowledgement, complete 480 physical segments
and 120 native intervals, and produce the same natural high-spin impact. The
largest world-COM trajectory difference is 0.0000612 cells. The far storage
origin travels up to 6.497911 cells per segment while actual COM travel stays
below 0.971255 cells. Every one of the 1,440 segments has an actual native ACK
and independent full native pose echo. Duplicate final poses refuse without
advancing time or changing the one-cell inventory. Seven domain-corruption
controls per storage case preserve the usable owner after refusal.

Native tests independently compare every occupied/contact corner against an
algebraic physical trajectory, then test 64 curved Sand trajectories in tight
and 25-cell-padded storage. Accepted and refused pocket outcomes, destinations,
apertures and sample counts agree. Dense independent samples verify accepted
grain paths do not cross solid material. Product carriers outside the rigid
cover expand the domain; large/slender shapes, excessive COM translation,
excessive corner travel, unresolved turns and work capacities retain refusal.
The original failing executable and precise negative/positive results are
preserved beside this report.

## Focused evidence

| Scope | Result |
|---|---|
| Matched actual-Rapier ledge-impact probe | Prior bridge: 5/20 protective refusals; corrected bridge: 0/20; same initial conditions and solver outputs |
| Final native contact and coordinator suites | 87,235 checks, zero failures; independent COM/storage/Sand invariance plus previous motion/ownership coverage |
| Final actual Rapier fragment and negative controls | 386 checks, zero failures; 20 initial collision cases, two complete gravity falls and independent large-angle, translation, corner and corrupt-readback controls |
| Final rest/contact/erosion | 37 checks, zero failures; real wake, fall, contact, settling and material-domain refresh |
| Final three-case sparse-parent regression | 6,223 checks, zero failures; 1,440 actual segments and native ACKs, 360 semantic intervals; storage-reference invariance and copied-domain fault controls |
| Final physical bridge / identity / incremental segments | 28 / 70 / 137 checks, zero failures; actual mass/COM/inertia and owner/barrier contracts |
| Final bounded segment planner | 47 checks, zero failures; actual COM readback and independent motion limits |
| Final standalone worker rehearsal / laboratory | 41 / 379 checks, zero failures; both legacy hosts consume the new native domain correctly |
| Ordinary Tower and independent barrel | 114 checks, zero failures; live ordinary worker/native/Rapier path, quantity and installed-pose validation |
| Same-World natural small-fragment chain | 8,471 checks, zero failures; five native Wood promotions, 2,400 actual Rapier segments, every native ACK plus independent full native pose readback, 600 semantic ticks |
| Fresh Tower barrel controls | Four-case follow-up: 212 checks, zero failures; Structures-disabled ordinary reference, pristine enabled owner, cut before Resume and cut after four native ticks; all fall freely to the same floor contact |

These are local Linux/headless results. The native suites compile their own
current source. The ordinary Tower fixture used the exact retained `1ec3f214`
native GDExtension and the changed bridge; its motion did not require the new
small-body envelope. That result does not substitute for final source-matched
native/Godot or Windows qualification. Raw result data, exact input hashes,
commands and the repeatable collision probe accompany this record.

The stronger same-World and fresh-barrel tests use the local native binary
`aa015a895c091f67d6d07a7f6dab6b18d6e1e55247ff880c10fcef7425a2149b`,
built from private composition `3479c621c`: the final four-cell physics contract,
accepted-main/presentation integration and the throughput specialist's native
applied-pose echo. `physics-combined-inputs.json` records the exact source hashes
and explicit local compiler drift; this is not the guarded production runtime.

The final COM-domain replay and focused results instead use native binary
`547c8f6f3474bc6f6406176239cefe3ae42d63326423f219d68a26d6a75032a0`,
with native source committed at `062670c1e75c43a0e72fc3727fbe0f62bb3736f6`.
The 126-file native input ledger has canonical SHA-256
`4356c2472f0572bc853712d478ec7f681bae189b655307a4e36268d56cfa7927`.
`physics-com-inputs.json` records the build source, dependency/library identities,
binary size, raw build hash and explicit GCC 14.2/binutils 2.44 local drift.
The source build started before committing these edits; native bytes remained
unchanged through the recorded source commit. This remains a focused local test
runtime, not the guarded production publication. The unchanged five-case small
fragment chain also passed all 8,471 checks against this final native binary.

The same-World fixture authors one Wood cell, performs real reservation/debit,
terrain installation and activation, then lets gravity drop it approximately
175 cells onto an ordinary native Metal ledge. Metal is a hard native surface
outside M4's admitted structural roster, so it remains terrain. Five modest
initial horizontal velocities (0.5–0.9 cells/s), with zero initial vertical or
angular velocity, generate peak spin of 55.8–87.7 rad/s and segment rotations of
0.232–0.364 radians. Every segment is natively applied, then independently read
back from a full native snapshot. A semantic tick occurs only after four exact
ACKs; duplicate final poses refuse without advancing either material inventory
or the native clock. The one-cell mass, 1/6 inertia, three-by-three padded bounds,
material quantity and original World identity remain intact. Initial shorter
falls did not generate enough spin in this full native terrain setup; those
exploratory fixtures were not reported as successful regressions.

The initial fragment test's attempted full-turn negative control was invalid:
Rapier itself bounds angular speed during a solver step, so supplying 1000 rad/s
before the step yielded a valid smaller completed rotation. The final control
explicitly injects an unresolvable angular readback after one genuine solver
step and verifies protective refusal. This is corruption fault injection,
separate from the natural positive collision cases; no application limit was
weakened to pass it.

## Barrel investigation

The ordinary Tower barrel was allowed to settle for 180 native ticks. An
ordinary Erase notch then severed one distant support; 60 ticks followed. Full
lower-support removal, actual structural detachment and 120 further ticks
followed. The same barrel RID remained at its settled position: maximum
displacement was zero cells and maximum upward speed zero cells/s. Conservation,
actual structural mass/COM/inertia and source-coherent presentation also passed.

A separate actual-Rapier control replaces a static compound eight times while
changing a distant support in the **same compound** as the barrel's floor.
Every replacement has exactly the two current shapes. The independent barrel
is absent from the structural registry and is never frozen by the test. Maximum
barrel displacement was zero cells and maximum upward speed approximately
3.66e-19 cells/s. No duplicate/stale collision shape or unrelated impulse was
observed in these tested paths.

Fresh-load controls start at native tick one with the barrel at
`(408,432.016)`, before it has settled. One leaves the Tower pristine, one erases
both support stems while initially paused, and one starts cutting after four
ordinary native ticks. All then run for 120 further ticks. Every barrel falls
freely to `y=457`; the largest upward velocity is approximately `3.72e-9` cells/s
(numerical rest noise), and none rises above its initial height. Both cut cases
produce an actual detached structure while preserving the barrel RID and
coherent presentation. `physics-fresh-barrel.json` retains the separate cases. A later four-case
follow-up on the complete throughput application adds the Structures-disabled
ordinary Tower reference. That reference falls from `y=432` to `457.000366`,
with only `1.48e-8` cells/s upward rest noise. All enabled cases settle at `457`
with zero observed upward speed. The 212-check result and exact fixture hash
are in `physics-fresh-barrel-four-cases.json`. Run this test without the
`--objectshard-m4-workbench` flag: only its three enabled cases explicitly
enable the feature.

The original owner jump remains **unreproduced**, not dismissed or claimed fixed.
The barrel fixture's first partial support cut leaves another connected support.
A later representative ordinary-Tower fixture makes two narrow cuts, witnesses
an actual owned facade fall approximately five cells, and identifies its real
native-stump contact through a nonmutating physics query. The same body then
sleeps while native simulation continues for another 60 ticks. This establishes
that a detached, stationary facade can be a valid supported physical outcome;
it does not establish the cause of the owner's original stationary observation.
Some contact-row Wall cells remain protected by the existing transient-occupancy
edit refusal after lower-stump removal. The fixture preserves that boundary and
does not claim complete support erasure followed by renewed fall. Ordinary full
support removal before collapse and a separate box support-replacement fixture
cover the respective free-fall paths. Later Windows/owner evaluation must retain
the barrel check and preserve a diagnostic trace if the jump recurs.

## Paused contact-brush publication correction

The supported-Tower follow-up exposed a separate reproducible ordinary-edit
defect on the complete integrated application, not just the private physics
composition. A fine Erase stamp included protected contact Wall and already
empty neighbours. The coordinator correctly refused the Wall and accepted the
unchanged empty cells. The native facade incorrectly treated every accepted
cell as a mutation and advanced the application World revision even though no
native material or state changed. The renderer correctly produced no new
payload, leaving the exact paused publication fence unable to publish the
fictitious revision. The simulation remained Ready, with no Held condition,
pending brush or physical lease, but displayed inventory became unusable.

Before correction, the decisive receipt records World revision 55 to 56,
publication 656 to 657, unchanged render serial 20 and byte-identical World
materials. The displayed/uploaded revision remained 55 after ten seconds at
native tick 327. A diagnostic-only full-render request demonstrated the missing
publication at the same native/physical time; that workaround is not shipped.

`c3d6580e4` binds attached `emit_disc` revision changes to the coordinator's
authoritative `world_material_revision`, matching the established direct
ObjectShard edit facade. Actual material, condition and temperature mutations
still count. The non-ObjectShard branch, transient occupancy protection, hard
surface transitions, physics clocks and all publication fences are unchanged.

`test_object_shard_m4_brush_revision.gd` passes **154 checks** on the complete
integrated application plus this correction and exact local native
`656077181d398d33a74ecfe7c2a5bcdfb6addb20b7b2ba478e7ea019745f4d18`.
It covers supported rest, explicit protected-cell refusal, partly protected
no-op brushes, fully empty brushes, actual distant Wood painting and erasure,
exact paused publication coherence and zero edit-induced native/physical/actor
time. A separate actual same-World native control repaints Wood with unchanged
material identity but real condition values: state `(173,91)` resets to `(0,0)`,
temperature 371 is preserved, and revision advances 3 to 4. Repeating that exact
payload leaves revision 4. The initial extra-control setup requested an invalid
128-cell extent; its nonpassing receipt remains preserved alongside the valid
256-cell replay. `physics-brush-revision.json` retains both failures and the
corrected result; `physics-brush-revision-inputs.json` records all 126 native
inputs and the local build identity. Hosted Windows/source/extracted execution
is a separate final qualification gate.

## Physical cross-review and qualification boundary

The throughput specialist's `f25b1aaa2` and domain consumer `a3b596e0a` use
the same contract in the Main interval predictor. Independent physical review found no loss of native
ACKs, exact pose checks, actor-force cadence or final semantic ownership: compact
receipts carry authoritative native readback and the final interval completion
remains on the full ordinary owner path. The mid-lease Held presentation seam
has been referred to the presentation and throughput specialists for explicit
camera/resize qualification; the presentation specialist has now demonstrated
208 checks with a real pending motion lease, retained full-canvas pan/resize
and Restore clearing the lease. No fast-path repair was needed. Final source-matched native/Godot/Windows qualification,
portable archive verification and final combined cross-review remain separate
gates. Large empty storage still costs native scans and retained memory, but
does not by itself constrain physical motion. Later M5 experiments may compact
or hierarchically represent that storage only while preserving carrier identity,
curved contact proofs, geometry barriers and the single semantic clock.
