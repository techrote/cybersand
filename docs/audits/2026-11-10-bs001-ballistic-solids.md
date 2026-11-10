---
title: BS-001 ballistic solids and solids equipment — implementation evidence
status: Current
document-kind: audit
scope: Dated evidence for the Draft-branch BS-001 native flying-solids owner, raised ballistic capacities and the workbench solids equipment; source/runtime identities, commands, results and gaps
last-reviewed: 2026-11-10
related-documents: [../architecture/ballistic-solids-v1.md, ../systems/workbench-liquid-equipment.md, 2026-11-09-in-tools-361-workbench-equipment.md]
---

# BS-001 ballistic solids — 2026-11-10

## Source and runtime identity

- Branch `feat/ballistic-solids-20261110`, stacked on the #361 equipment branch
  after it was refreshed onto accepted `main` (which now includes #542). The exact
  commit is recorded in the PR; local results below used the working tree that
  became that commit.
- **Native source changed** (new owner, hooks, adapter calls), so the committed
  runtimes are stale for this branch until the
  [BS-001 publisher](../../.github/workflows/bs001-runtime-publication.yml)
  rebuilds them from exact source on GitHub-hosted Linux and Windows. Local
  results used locally built libraries:
  - Windows GDExtension built by the repository toolchain script (LLVM-MinGW
    20260826, godot-cpp `101ae380`), sha256
    `6589501cad53ad58049aa3fee37869769c74a450dcbefed6234568b291913540`;
  - native Makefile test binary built with g++ 13.3 in WSL Ubuntu 24.04.
- Godot 4.7-stable official.

## Results

| Case | Platform | Result |
|---|---|---|
| Native test binary, full suite (`-O1 -g`) | WSL Linux | 199 tests passed, 7 BS-001 cases |
| Native suite under AddressSanitizer + UBSan | WSL Linux | 198 passed (before the buried-climb case was added; rerun pending on final source) |
| `test_workbench_solids_lab.gd` | Windows headless, request 4 | 31/0; 4 observed task claimants |
| same, windowed (ANGLE, NVIDIA) with frame capture | Windows | 31/0 on a second launch; the first launch hit the known pre-existing "Controlled liquid replacement retired before commit" startup flake before any equipment code ran |
| `test_workbench_liquid_equipment.gd`, `test_workbench_reservoir_lab.gd` on the new library | Windows headless | 103/0 and 81/0 |

BS-001 native cases: admission and defaults (disabled refusals, orphan/invalid
configuration refused, material admission, capacity, spawn-in-wall refusal);
arc and landing (Sand rises and lands as the same cell, population conserved every
tick); liquid-surface landing then sinking below the surface; exact body impulse
(`delivered == −body_px`); CYPS save mid-flight, exact restored continuation and
identical 1- and 4-worker hashes; presentation overlay without authority writes;
buried-solid climb.

## solids-lab observations (Windows, request 4)

- Raised capacities: ballistic Water 16 384 and flying solids 8 192 slots were
  admitted and reported natively.
- Hopper: opening the floor valve for 240 ticks poured Sand into the collector
  pit; 1 534 cells were collected and fed the conveyor exactly (stock 200 → 1 734).
- Launcher: 720 shots in 240 ticks, each a native flying solid (`injected` delta
  equals shots); peak 231 in flight; 264 body contacts; with **Hit force ×** 10
  the top barrel was knocked about 72 cells. Grid Sand + flying + conveyor stock
  stayed exactly constant (7 400) at every sampled frame.
- Stop: every device closed and every flying solid landed (0 deferred, 0 forced
  after the buried-climb repair). Restore start reset the devices and kept the
  authored launcher aim; Save/read-back of the block was identical.

Frame: [launcher arc knocking over the barrel stack](../images/in-tools-361/solids-lab-launcher.png).

## Defects found and repaired

- **Sampling skew:** the device receipt read the Sand population before the tick
  but the flying roster after it. The worker now samples the population at
  publication.
- **Buried solids:** a resting solid buried by a moving Sand pile found no free
  cell within radius 2 and retried indefinitely (≈ 55 700 deferrals, 10 solids).
  It now climbs through powders and liquids to the first free cell.

## Runtime publication — 2026-11-10

[Publisher run 42901114315](https://github.com/techrote/cybersand/actions/runs/42901114315)
built source `e890d50d` on GitHub-hosted runners: native BS-001 and BW-001 groups
passed, then the Linux and Windows libraries were built from exact source and
solids-lab, liquid-lab, reservoir-lab and the workbench canvas passed on actual
Linux and Windows. The bot fast-forwarded the branch with `b0ac29e9`:
Windows sha256 `0a9c14d790910308f37f1d16b648d612a52a5020f29a500c71326a007afe4f7c`,
Linux sha256 `8080fb48eb52c85ceb3e6f48f3653691ce53a28d1a562354bc643c82d00b89e7`.
`check_repository` then passed, and the native suite under ASan/UBSan passed
199/199 on the final source.

## Gaps

- Hosted Ready-PR Native/GDExtension gates run only once the PR is Ready.
- Human feel acceptance is open.
