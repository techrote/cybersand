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

The native coordinator and actual Rapier bridge now use
`min(pi/2, max(0.20, 4/r))`, where `r` is the conservative diagonal of the stable
material storage bounds. The empty product ring remains inside that bound. A
body with radius at least twenty cells retains 0.20 radians. Any additional allowed
rotation moves the conservative farthest corner along an arc of at most four
cells. This is the retained eight-cell total corner allowance minus the retained
four-cell translation allowance; it introduces no larger total motion budget.

The exact supplied continuous angular interval still enters native
`contact::plan_sweep`. Its half-cell spacing and 32-sample capacity are unchanged;
the eight-cell corner bound requires at most seventeen samples. Dense independent
corner samples verify the spacing guarantee. Native occupancy, Water contact,
Sand pocket admission and its curved-trajectory obstruction check all receive
the same geometry-sensitive envelope. No pose acknowledgement, native time,
physical step or material accounting is omitted or duplicated. Velocity and
momentum are unchanged. Unresolvable turns, nonfinite state, excessive
translation/corner motion and exhausted work still refuse safely.

Actual geometry replacement now refreshes the bridge's conservative radius.
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

## Focused evidence

| Scope | Result |
|---|---|
| Matched actual-Rapier ledge-impact probe | Prior bridge: 5/20 protective refusals; corrected bridge: 0/20; same initial conditions and solver outputs |
| Native contact and coordinator suites | 53,159 checks, zero failures; new owner-value and independent collision controls included |
| Actual Rapier fragment and negative controls | 384 checks, zero failures; 20 initial collision cases, two complete gravity falls and separate large-angle, translation, corner, corrupt-readback controls |
| Rest/contact/erosion | 35 checks, zero failures; real wake, fall, contact, settling and shrinking-radius readback |
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
The first partial support cut leaves other load-bearing material; a stationary
facade there can be a valid contact outcome. Full-support removal demonstrates
continued detachment and collapse. Later Windows/owner evaluation must retain
the barrel check and preserve a diagnostic trace if the jump recurs.

## Remaining integration work

The throughput specialist's `f25b1aaa2` consumes the same bridge helper in the
Main interval predictor. Independent physical review found no loss of native
ACKs, exact pose checks, actor-force cadence or final semantic ownership: compact
receipts carry authoritative native readback and the final interval completion
remains on the full ordinary owner path. The mid-lease Held presentation seam
has been referred to the presentation and throughput specialists for explicit
camera/resize qualification; the presentation specialist has now demonstrated
208 checks with a real pending motion lease, retained full-canvas pan/resize
and Restore clearing the lease. No fast-path repair was needed. Final source-matched native/Godot/Windows qualification,
portable archive verification and independent cross-review remain separate
gates. Large storage bounds around sparse offcuts remain conservative; changing
their origin/representation is a later scaling experiment, not part of this
bounded correction.
