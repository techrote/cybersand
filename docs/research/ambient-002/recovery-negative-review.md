---
title: AMBIENT-002 observed obstacle oscillation and recovery review
status: Current
document-kind: evidence
scope: Independent diagnosis of two completed physical shards and a pure copied-value probe at source 83a3db6f; the full campaign remains separate
canonical-for: [ambient-002-recovery-negative-evidence]
last-reviewed: 2026-11-25
related-documents: [behaviour-ledger.md, independent-science-review.md, ../../systems/ambient-living-inhabitants.md]
---

# Observed obstacle oscillation and recovery review

The canonical source `83a3db6ffb207761df999abedac77eb1401604a8` contains a
reproducible obstacle-steering defect. A clear alternative heading is stored
with a finite deadline, but the module becomes inactive on the next decision
when that alternative is itself clear. An attractive goal can then reverse
the actor's requested heading again. Actual Runner and Monowheel trajectories
show sustained alternation at the ten-hertz decision cadence, with almost no
horizontal progress. Their internal obstruction memories record no failure.

The [original receipt](evidence/recovery-negative-83a3/receipt.json) binds the
two complete physical reports, lossless compressed originals, original command
receipts and consoles, copied-value probe, runtime pin and reviewed source
hashes. These two episodes are members of the ongoing local 194-episode
programme, not additional episodes. This note does not claim that the complete
122-World programme has passed or that the hosted repetition has completed.

## Actual physical negative result

Both actors use the ordinary editable Persistent Scavenger profile, seed 605,
the same initial material fixture, and their actual production actuators.
Each completed thirty simulation seconds and 1,800 native/physical ticks.
Neither actor was teleported. The reviewed interval is 6.5 through 8.5 seconds,
inclusive: twenty-one observations separated by 0.1 seconds.

| Recorded measure in that interval | Runner | Monowheel |
|---|---:|---:|
| Horizontal requested-direction reversals | 20 | 20 |
| Horizontal position range | 0.087875 cells | 0.089798 cells |
| Net horizontal displacement | -0.075729 cells | -0.025085 cells |
| Copied right-wall distance | 6.1245–6.2124 cells | 3.9739–4.0637 cells |
| Selected module throughout | `explore_unfamiliar` | `explore_unfamiliar` |
| Selected phase throughout | `approach` | `approach` |
| Final internal `memory.failure_events` | 0 | 0 |
| Final retained obstruction records | 0 | 0 |
| Selected `withdraw_obstruction` time in the full episode | 0 seconds | 0 seconds |

The original complete shard digests are:

- Runner: `dd01b967e4fdb5ff219c60a735f1d6eefe99ce91fed4a70778ad19caeec4fd66`.
- Monowheel: `600ad5644aebff633f3adbb26bc557a423c252a5289878841bbf4f49564af310`.

These movements are a physical negative result. A long centre path or frequent
decision-label changes would not demonstrate exploration here. The selected
goal module and phase do not change within this interval; final steering does.
The raw trace lacks `goal_key`, so it cannot establish whether a module renewed
an otherwise identical destination.

## Failure detector reconstruction and limits

At this source, memory increments its stall accumulator only while all of the
following hold on consecutive admitted decisions: prior intended pace exceeds
0.05; the prior direction is nonzero; projected forward speed is below one cell
per second; and actual observed contact lies within ten cells in a sufficiently
aligned direction. A missed interval exceeding 0.25 seconds, an idle intention,
faster forward progress or missing aligned contact resets the accumulator.
Recording a failure requires at least 0.8 accumulated seconds. Withdrawal then
requires the configured personality tolerance to be reached in a nearby retained
failure record.

Independent reconstruction from the recorded horizontal wall rays finds 52
low-progress/contact intervals for the Runner and 43 for the Monowheel. The
longest consecutive confirmed horizontal-contact interval is only 0.1 seconds
for both. Runner runs reset 43 times when the prior requested heading faces the
clear side, eight times on neutral intention and once on forward speed at least
one cell per second. All 43 Monowheel contact runs reset on the clear side.

The trace does not retain the additional hull-clearance navigation rays, so this
is explicitly a reconstruction of the horizontal fallback predicate, not a
complete replay of every private detector input. The engine's actual copied
final failure count of zero is independently observed. The documented main
failure mechanism in these intervals is alternating requested direction, not
an inference that vertical gait alone reset all contact evidence.

## Pure reproduction and bounded correction proposal

The retained `inspect_latch.gd` probe runs the actual module with a blocked right
ray and clear left ray. At simulation time zero it selects left and stores a
deadline of 1.5 seconds. At time 0.1, with the same rays and previous direction
left, it becomes inactive with the reason that the requested direction has no
nearby obstruction. The stored deadline still equals 1.5. The probe identifies
the tested source files by their exact canonical hashes and uses the pinned
official Godot 4.7 executable. This synthetic probe adds zero physical episodes.

The narrow correction should retain the previously chosen heading until its
existing deadline only while a current copied ray still establishes that the
heading is available, capability appropriate, inside the canvas and adequately
clear. Unknown coverage or a newly blocked retained heading must release it
immediately. Clear motion must not silently renew the deadline. Existing urgent
overrides remain able to interrupt the steering contribution.

Required regressions include retention over multiple decisions, finite expiry,
loss or clipping of the retained ray, newly blocked retained direction, ground
rejection of diagonal-only clearance, and a valid flying alternative. Matched
physical reruns must show actual movement and reduced heading chatter before
claiming useful recovery. The original complete 83a3 campaign should remain
intact as evidence of the preceding behaviour.

A separate constant-size progress window may be needed if actual adverse
episodes still fail to learn obstruction. A candidate should bind a finite
simulation-time window to a stable selected goal and copied target, compare
net progress along supported movement axes, and require accumulated actual
aligned contact. It must tolerate a short gait burst or corrective steering
interval without treating absent contact as confirmed contact. World changes,
unavailable coverage, target changes, neutral phases and bounded expiry require
explicit invalidation. That is a proposal, not an implemented or qualified
mechanism at source 83a3.

## Subsequent matched repair review

The bounded latch repair was independently checked in nine existing registered
cases at candidate source `941b79154c890098350725f274b85f26b44f77b0`. Original
baseline reports remained at source 83a3. Complete loaded-project custody
permits exactly two changed Godot inputs: the stateful module and its pure
regression test. Native material state, actor pose, profile, seed, geometry,
engine and native/Rapier runtime identities match within every pair. The
[independent receipt](evidence/recovery-independent-941b/receipt.json) and its
reproducible post-run reader record 270 independently computed movement
comparisons, 72 comparison-table checks and 216 heading-readback checks, all
agreeing. The separately reviewed probe wrapper passes nine synthetic integrity
tests. These readers execute zero additional physical episodes.

In seed 605, Runner active low-progress intervals decrease from 111/246 to
21/233 (45.1% to 9.0%); Monowheel decreases from 91/227 to 19/236 (40.1% to
8.1%). Whole-episode active horizontal heading reversals decrease from 100 to
15 and from 91 to 10 respectively. Both actors make two reversals in the
original two-second negative interval instead of twenty. Their horizontal
ranges during that interval rise to 23.48 and 15.02 cells. The same ground
improvement is observed under seed 1701. The sampled 4LY treatment at seed 1701
is unchanged. This establishes actual movement improvement in the selected
cases, not universal exploration superiority.

Both sealed-goal seeds retain eight actual internal failure events. The
candidate's two selected withdrawal intervals move the Runner approximately
46.89 and 46.81 cells to the left. Both blocked-route seeds retain five failures
and 9.1 seconds of withdrawal; their complete movement traces remain unchanged.
The recorded blocked-route failures predate the new wall painted at fifteen
seconds, so this demonstrates remembered-obstruction withdrawal and continued
activity after the intervention, without proving learning of that new wall.
The original memory detector has therefore been preserved.

The nine reruns revisit existing case identities and are not nine additional
independent conditions. They qualify the narrowed comparison only. A complete
candidate programme, Windows execution, presentation and owner-hardware
playfeel remain separate evidence scopes. Concurrent local elapsed timings are
excluded from this comparison.

## Recovering the exact historical probe source

The targeted experiment executed local commit
`941b79154c890098350725f274b85f26b44f77b0`. Its exact Git objects are retained in
[evidence/probe-941b-source.bundle](evidence/probe-941b-source.bundle), with
[hashes and prerequisites](evidence/probe-941b-source.json), rather than assuming
that a later source with matching application bytes has the same commit identity.
All three bundle prerequisites are already published ancestors of83a3. In an
ordinary clone of this repository, restore the historical source as follows:

```sh
git fetch origin 83a3db6ffb207761df999abedac77eb1401604a8
git bundle verify /path/probe-941b-source.bundle
git fetch /path/probe-941b-source.bundle refs/ambient-002/probe-941b:refs/ambient-002/probe-941b
git worktree add --detach ../ambient-probe-941b 941b79154c890098350725f274b85f26b44f77b0
```

The source bundle does not contain an alternate engine or substitute native
runtime. Use the separately authenticated dependencies named in the original
probe custody, and preserve original execution reports when rerunning it.
