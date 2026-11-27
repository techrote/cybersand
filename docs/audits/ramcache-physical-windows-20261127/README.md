# Persistent Areas on Windows 11 with a TITAN RTX

The registered graphical RAMCACHE writer and fresh reader ran on Windows 11 Pro with Godot 4.7, native OpenGL 3.3 and NVIDIA driver 581.80. The application came from `9cc106b312b080b5bd6d079c23be918722f5cea4`. Its Windows DLL came from the [same source and producer attempt](https://github.com/techrote/cybersand/actions/runs/45939972097/artifacts/15173136608). The 114 native source hashes, engine, Rapier library and source inputs passed the runner's custody checks before and after execution.

| Workers | HOT median / p95 / maximum | WARM median / p95 / maximum |
| --- | --- | --- |
| 1 | 91 / 100 / 100 ms | 2,033 / 2,201 / 2,265 ms |
| 4 | 99 / 100 / 100 ms | 2,032 / 2,231 / 2,299 ms |

Each table entry covers 30 completed transfers with zero simulation debt. All 60 HOT transfers reused a resident World and left the counters for disk reads, native deserialization, source construction and synchronous publication unchanged. Each writer passed 1,822 cache checks. Its separate fresh reader passed 163. These measurements cover the three actor-free Current/FreeMass areas and meet the owner's few-second HOT return target. Handling and appearance remain for the owner to assess.

The [120 original travel records](travel-operations.jsonl) retain each transfer's clocks, before/after I/O and main-thread frame observations. The [summary](summary.json) identifies all four processes, commands, hashes and memory scope. The writer captured the [cache controls at 1280 × 720](ramcache-controls-720-after-travel.png) and the [Workbench at 1920 × 1080](layout-1920x1080.png).
