# CyberSand recovery owner observations

Record PASS, FAIL or NOT RUN. Physical Windows 11/NVIDIA acceptance remains HOLD until actual device observations are reviewed.

Package/source identity:
Windows build:
NVIDIA model and driver:
Monitor resolution and refresh rate:
Window mode and render driver:
Date and session duration:
Selected or fallback profile:
Water composition readback:
Camera mode:
Optional instrumentation used:

| Workload | Duration | Result | Freezes, stale trails, double images, Water visibility, input response |
| --- | --- | --- | --- |
| Wave512: flight, active Water, Follow/Free, paint/erase | | NOT RUN | |
| Wave1024: multiple actors, contact, camera, picking | | NOT RUN | |
| Wave2048: flight, large fill then repeated small edits | | NOT RUN | |
| Mixed2048: Water/Sand, obstacles, actor switching | | NOT RUN | |
| Dry/wet transition, partial/full submersion, moving Water | | NOT RUN | |
| Pause, Step, resume, reset and Restore start | | NOT RUN | |
| Named authored Save, close, reopen, Load start | | NOT RUN | |
| Longer demanding ordinary session | | NOT RUN | |
| Same-scene Stock Safe fallback comparison, if needed | | NOT RUN | |

## Reproduction notes

Record the shortest sequence that reproduces a concern, approximate freeze duration, whether physical movement actually stopped, and whether a problem worsens later in the session. Note each configuration or scene change. Link any screenshots or video stills placed in `Runs/Screenshots`.

## Collection

Close Workbench, run `Collect Results.cmd`, and retain its ZIP, SHA-256 and any original files listed as omitted by `INDEX.json`. The collector records limited OS/CPU/graphics readback at collection time; confirm monitor settings above because Windows can return missing or stale display values.
