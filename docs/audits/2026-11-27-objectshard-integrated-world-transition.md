# ObjectShard on the integrated Workbench World

ObjectShard M4 composes immutable actor proxies and moving structural material
into a single transient occupancy mask. The integrated World keeps the Actor
body-capacity accounting, the material-audition World token and the resident-size
accounting. Clearing a World retires its structural journal and rotates the
material profile identity. The native adapter refuses to attach structural
ownership to a resident-area World and refuses continuation while the structural
coordinator owns the World.

| Identity | Source | LF SHA-256 of `native/src/world.cpp` |
| --- | --- | --- |
| Areas, SWARM, Actor, Material and Gentek | `a194a5ac9d1a1c4a3e6fbe3b75bdc1e78abad795` | `54a727f6eb0543c2d9cdd868ed0486bf6e68d1b98c03c7a86a260891b49b1c24` |
| ObjectShard on that source | `150efbef147f9f92f8df1cb58395c112ac5016f7` | `b568775acb67639ca1e6de96450ea9bd1e7ca1ef1fea34e244038f43f8ed9865` |

The original [mutation witness](2026-11-22-objectshard-world-transition.md),
[external Fire opportunity](2026-11-22-objectshard-external-fire-world-transition.md)
and [derived occupancy](2026-11-24-objectshard-m4-world-transition.md)
records retain the standalone M4 source and scope. The native catalogue gate
authenticates the integrated path against the protected source in this table.
Owner GPU performance and production eligibility remain separate evaluations.

## Windows Workbench execution on NVIDIA TITAN RTX

On 2026-11-27 the local pinned Windows crossbuild at
`570f416665f76ed208d90470359653d2f755def5` produced a 7,260,160-byte DLL
with SHA-256 `1bb3af9b14621c3a44b3c6801f789c71235d35a6f67e94904cebab2ed28a9668`.
The candidate verifier matched all 126 native input hashes, the exact build
tree and the DLL. Godot 4.7 stable and Rapier 0.35.2 ran in the ordinary
Workbench on NVIDIA TITAN RTX, driver 581.80. The shipped ANGLE D3D11 renderer
was selected explicitly.

| Workload | Checks | Renderer submissions/s | Native ticks/s | Physical observation |
| --- | ---: | ---: | ---: | --- |
| Tower intact, playing for 12 s | 132 across the four pause/play intervals | 59.90 | 7.83 | No detached body |
| Tower detached, playing for 12 s | Same fixture | 59.90 | 8.58 | One awake Rapier body at both boundaries |
| Eight-body collapse, overview, 26.43 s | 370 | 59.70 | 6.81 | Eight bodies throughout, 721 physical segment steps |

The two tower pause controls submitted approximately 60 frames/s with zero
native ticks or physical steps. The eight-body case passed its inventory and
display-coherence checks. It advanced 0.1135 simulated physical seconds per
wall second. Its main-thread receipt pump used 17.09 of 26.43 wall seconds,
including deliberate bounded waits. The measured Rapier segments used 0.151
seconds in total. These counters do not isolate elapsed native compute or
establish a safe scheduling change.

The running user session did not obtain PresentMon per-process display
events. Rendering submissions and native progression therefore retain their
own units. The owner's previous below-10 displayed-FPS observation and the
[hardware playtest](../operations/objectshard-workbench-playtest.md) remain
open.

To reproduce, run `res://tests/profile_object_shard_m4_render_control.gd`
and `res://tests/profile_object_shard_m4_workbench.gd` with
`--rendering-driver opengl3_angle` and `-- --objectshard-m4-workbench`.
The stress case also used `--scene=stress --camera=overview --sampling=light
--recording=off`. The respective JSON receipts had SHA-256
`76ef9efae40b39bd5af307113c7513bdeac2f1742de72221a4c085fb14064e71`
and `03e463d02ef8a3dd755ff6d2c6eed01ce3df8fbfb6381abf73c9f9e4ea628bf4`.

## Integrated native memory budget

[Run 45924129713](https://github.com/techrote/cybersand/actions/runs/45924129713)
passed 96,500 sanitizer checks and 192 World cases at `8c6bc1e76`. Seven
retained Lab cohorts exceeded the 6 MiB native C++ allocation limit. The
empty Lab retained 6,619,244 bytes and three reacting bodies retained
6,768,272 bytes. The 4,096-slot integrated actor response workspace exposed
a redundant reservation in the structural owner. A 24,576-cell Lab reserved
49,152 relocation records despite visiting each occupied source index once.

Commit `551928f48` bounds that reservation by both the finite World area and
the existing carrier limit at construction. The complete g++-13 release
benchmark (`--ticks 1200 --repetitions 3 --qualify`, Ubuntu 24.04 WSL)
passed its original limits. The empty and three-reacting-body cases retained
5,636,204 and 5,785,232 bytes respectively. All nine scene cohorts recorded
zero steady-state allocations. The native response range and mutation
admission rules are unchanged.

## Main-thread receipt timing on TITAN RTX

The official Windows DLL from the same run was
`f79bc16ebf0a183219e0b1704fa65632187d5054265c4bfdf1714744378b99e0`.
Four alternating shipped-driver runs used the eight-body stress scene above.
All four passed 370 checks with 721 shared Rapier steps. Windows
`GetThreadTimes` measured the thread that owns the visible Godot window.
The removed rows already owned private deep copies of the result and frame.
The candidate transfers these values to Main under the existing queue mutex.

| Instrumented source | Elapsed s | Main CPU s | Dequeue copy ms | Explicit wait s | Native ticks/s | Renderer submissions/s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Control `3b72de339` | 11.51 | 2.84 | 174.0 | 4.01 | 15.64 | 59.70 |
| Transfer `fb1f8926f` | 11.39 | 2.83 | 5.4 | 4.13 | 15.80 | 59.87 |
| Control `3b72de339` | 11.84 | 3.09 | 186.3 | 3.96 | 15.20 | 59.79 |
| Transfer `fb1f8926f` | 10.46 | 2.47 | 4.6 | 4.16 | 17.21 | 59.68 |

The first control published 8,648 shard rows with unchanged carrier and
geometry revisions. Its 2,278 requested 100-microsecond waits consumed
4.01 seconds, while acquisition of the dequeue mutex consumed 0.94 ms.
Main CPU totals cover the full timed scene window. The timing observations
do not qualify display scanout, owner playfeel or a change to rendezvous
policy.

## Ground actor and flight clock boundaries

On source `24f92190d`, the hosted Linux equipment fixture exposed a paused
mount-pose refusal. An already admitted structural interval had completed
while a suspended actor retained its previous mount transform. Source
`bd2e155f5` reads completed body poses before publishing that interval;
six fresh Linux and four fresh Windows processes each passed 95 checks
against the same 126 native inputs. A three-actor ordinary Workbench control
completed 24 Play/Pause cycles and 147 checks without the structural owner.

The original 4LY fixed-step controller refused an admitted four-substep
interval with `flight_unexpected_physics_step`. Source `41db1872a` refuses
that owner combination before mutation in both directions. A complete flight
start retires the previous structural World. The independent Windows fixture
at `0da971b2b` executed both refusals, preserved the old owners, then advanced
the accepted flight on its ordinary single-step clock. Ground actors gained
1/60 second over four observed Rapier substeps, zero through Pause, and
1/60 after Resume.

## NVIDIA visible changes

The [TITAN RTX cropped desktop measurements](https://github.com/techrote/cybersand/blob/0df4a76410e5ac1f6d1368486dcfeae75280e773/docs/audits/objectshard-visible-region-20261127/summary.json)
use source `24f92190d` and its official Windows DLL. In the eight-body scene,
the static control stayed unchanged for all 178 observations. During 12.51 s
of activity, 267 changes reached the fixed material viewport (21.35/s).
Changes covering at least 0.5% of that region occurred 5.52/s and the
longest observed gap reached 1.734 s. The Water scene visibly animated
while paused. Its active changes exceeding the maximum paused change
occurred 12.15/s. These measures identify visible material-region changes.
Physical owner playfeel and the sustained displayed-FPS concern remain open.

## Held pointer and receipt layout

The source-bound Windows archive for `f7921ffa3` and its 126-input DLL
(`4ab4b9ff2577e6c200a0a611f53796ace241e04d0fbc11f503343520ea7ee2aa`)
passed four extracted launcher paths. One local downstream fragment case
received the correct native Cut acknowledgement, then lost its held pointer.
The next three controlled runs passed and the fourth traced the cancellation
to a real viewport resize from 853 to 874 pixels high. A shorter status
receipt had released one line of the toolbar. Structures now reserves its
two visible status lines using the mounted label's font, spacing and style.
The fragment case alternates short and wrapped text and checks the actual
content rectangle before running its original held Cut, split, quantity and
settlement proofs. Resizing the actual viewport continues to cancel a stroke.

An extracted run at `703652dec` also exposed an earlier completion-fixture
assumption. A valid Cut acknowledgement can arrive while the two displayed
frames still agree on the old inventory. The fixture now waits for the
authenticated transaction to appear in the displayed publication before
checking the one-cell debit, stale-target refusal and four subsequent Wood
ignitions. The per-cell, quantity and reaction checks still run.
