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
