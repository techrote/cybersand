# Persistent Areas after the ordinary Water repair on Windows 11

This run used application `e48deb7fc292ded32bbfd6fb47ecafab4c1b31f4`, Godot 4.7, pinned Rapier and the original Windows DLL from its [guarded source build](https://github.com/techrote/cybersand/actions/runs/45943912926/artifacts/15173614883). The renderer reported native OpenGL 3.3 on NVIDIA TITAN RTX, driver 581.80. All 114 native hashes and each post-run source custody check matched.

| Workers | HOT median / p95 / maximum | WARM median / p95 / maximum |
| --- | --- | --- |
| 1 | 99 / 100 / 100 ms | 2,091.5 / 3,149 / 3,149 ms |
| 4 | 99 / 100 / 100 ms | 1,982 / 2,032 / 2,084 ms |

Each residency and worker combination contributed 30 completed zero-debt transfers. Across the 60 HOT transfers, the resident handoff counter advanced once per transfer with unchanged native restoration, construction, profile-read and synchronous publication counters. Each writer completed 1,822 checks. Both independent readers completed 163. The [120 original operations](travel-operations.jsonl) and [process summary](summary.json) cover the three actor-free Current/FreeMass areas. Handling and appearance remain for owner evaluation.

The app also captured the [cache controls at 1280 × 720](ramcache-controls-720-after-travel.png) and the [Workbench at 1920 × 1080](layout-1920x1080.png). The [earlier Windows observation](https://github.com/techrote/cybersand/tree/c64c30c0891955ded5d7db6176dc62ce1823da2b/docs/audits/ramcache-physical-windows-20261127) used the preceding application.
