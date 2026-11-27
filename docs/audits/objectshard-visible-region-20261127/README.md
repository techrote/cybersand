# Visible Workbench region on a TITAN RTX

The actual Windows runtime built at `24f92190d7933a4f22d03cb0d0ddf72ce3918e0c`
ran the mixed Wood/Brick/Water scene and eight-body stress scene using pinned
Godot 4.7, Rapier 0.35.2, ANGLE D3D11 and driver 581.80. The roots of both
applications matched all 126 native source hashes. Instrumented application
`33aa6eeb52c07ccb089d5125db53376bedd614af` adds a paused scene control and
observation markers. It retains the same simulation, overlay and material inputs.

Windows desktop duplication supplied the visible primary DisplayPort output.
The probe validated the exact Godot PID, client window, monitor, position and
stacking order. It copied only a crop derived from world coordinates and the
ordinary shader's aspect fit. The toolbar, status rows and cursor were outside
the measurement. No image was stored. Both acquisitions observed zero occluded
or accumulated samples. The physical primary monitor used 2560 × 1440.

The eight-body scene passed 372 checks and held eight bodies throughout
12.51 seconds. All 178 paused comparisons were pixel-identical. Motion produced
267 changed region images, or 21.35 changes/s. Inter-change intervals had a
33.9 ms median, 67.4 ms 95th percentile and 1.734 s maximum. An exploratory
0.5% area threshold selected 69 larger updates, or 5.52/s. The native clock
advanced at 14.39 ticks/s. This bounded interval included no synchronized
witness of whether each body was awake during the longest visible gap.

The mixed scene passed 148 checks with one body and authored Water. The paused
shader animated between every captured pair even though its native tick stayed
at one. During 10.21 seconds of active simulation, 124 updates changed more
pixels than the largest paused update. This gives 12.15 such updates/s. The
native rate was 17.63 ticks/s. The physical owner evaluation remains open.

[Machine-readable summary](summary.json) · [Mixed samples](mixed.csv) ·
[Eight-body samples](stress.csv) · [Source-bound runtime build](https://github.com/techrote/cybersand/actions/runs/45926980128)
