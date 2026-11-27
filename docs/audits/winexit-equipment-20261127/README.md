---
title: Windows equipment shutdown investigation
status: Current
document-kind: audit
scope: Historical Windows exits and November 27 cross-platform equipment ownership checks for issue 787
canonical-for: []
last-reviewed: 2026-11-27
related-documents: [../../operations/local-build-and-validation.md, ../../architecture/data-ownership-and-lifetimes.md]
---

# Windows equipment shutdown investigation

**Open, 27 November 2026.** All 72 retained executions of the original equipment extent fixture produced byte-identical console output. Sixty-six processes exited zero and six exited with `0xC0000005`. The final line in every log was `Workbench actor equipment extent: 29 checks, 0 failures`. Checking each raw log against its retained SHA-256 gave the same digest, `9684fd48fbe1d362489e657c2defd16ef6ce6016fec71bc10c96926bd00b10c8`. The crash remains unresolved. [Issue #787](https://github.com/techrote/cybersand/issues/787) · [Original per-process records](https://github.com/techrote/cybersand/blob/c21987d0b760114c1759b78ccc303a63d556b7f5/docs/audits/native-consolidation-windows-exit-20261127/original-fixture.json)

## How far the evidence reaches

| Historical source | Access violations / executions |
|---|---:|
| Before native consolidation, `b178f10ae993` | 0/24 |
| Material Audition, `80caeece153a` | 0/16 |
| Actor Compose, `b1d33a18549a` | 2/16 |
| Accepted main after SWARM, `7a15691a7c53` | 2/8 |
| Persistent Areas candidate, `7f8f731d4755` | 2/8 |

The original fixture had the same SHA-256 at all five revisions. Across the archived runs the exit occurred with both the GUI executable in headless mode and the console wrapper. The debugger observed a main-thread fault after the summary on the Areas source. Nine application frames were in the Windows Godot editor. Its PE header reports zero COFF symbols and an empty debug directory. The 4.7-stable release lists debug-symbol archives for Android only. The engine version resolves to source commit `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`. The engine function and the object it was handling remain unknown. [Debugger record](https://github.com/techrote/cybersand/blob/c21987d0b760114c1759b78ccc303a63d556b7f5/docs/audits/native-consolidation-windows-exit-20261127/debugger.json) · [Official release assets](https://github.com/godotengine/godot-builds/releases/tag/4.7-stable)

The original fixture uses the worker API synchronously. The smaller script case, which recorded one access violation in 16 runs, constructs the physical usable runtime and calls reset and snapshot. It starts no simulation worker thread, creates no gameplay body and constructs no native World directly. It still loads a project with both extensions and explicitly preloads the worker, coupling, sampled effects and sampled usables. Including the physical runtime, following literal script preloads and script inheritance recursively reaches 77 production scripts on the Material Audition revision and 79 on Actor Compose. The additions are the actor manipulator and sandbox capacity scripts. Those counts describe source dependencies. Runtime load order, dynamic loads and object destruction order are unmeasured. [Retained smaller fixture and lifetime controls](https://github.com/techrote/cybersand/tree/c21987d0b760114c1759b78ccc303a63d556b7f5/docs/audits/native-consolidation-windows-exit-20261127)

Four native Worlds were verified destroyed before the later exit in 3/16 historical runs. The simpler direct native case exited normally 16/16. In production, the physical engine borrows its World during a step and clears the reference on both paths after assignment. The ordinary desktop scene joins its GDScript worker on exit. Neither that gameplay worker nor live actor bodies are needed to observe the reduced failure. Earlier memory damage, extension cleanup, and GDScript resource cleanup remain possible. Godot later changed how the language releases static data, pending functions and surviving scripts. No observed object or matched frame connects that upstream repair to CyberSand. [Physical runtime](../../../godot/scripts/physical_usable_runtime.gd) · [Desktop shutdown](../../../godot/scripts/main.gd) · [Upstream shutdown change](https://github.com/godotengine/godot/pull/120976)

The archived fixed-binary comparison recorded 21 access violations in 272 processes. The exit recurred with both earlier equipment scripts and after isolating the coupling constant. The 18-script rollback had 0/16 failures alongside 2/16 stock runs. Even under an independent, constant per-run failure probability, zero in 16 gives a one-sided 95% upper bound of 17.1%. The evidence does not isolate a commit, script or upstream defect. [Variant results](https://github.com/techrote/cybersand/blob/da492f568ef5d490722fd6121d8da0ae7108b654/docs/audits/2026-11-27-actor-equipment-exit/qualification.json)

## New ownership regression

The ordinary native usables test keeps a real processor's deployment snapshot while the equipment runtime resets. It releases the World while the runtime is alive, then releases the runtime. Three weak references check destruction of the World, wrapper and inner engine. A fourth check reads the original stock and accepted deployment receipt after release. This exercises the application's lifetime contract deterministically. The original 29-check fixture is unchanged. [Regression fixture](../../../godot/tests/test_physical_usables_runtime.gd)

| Fresh-process qualification | Windows 11 x86-64 | Ubuntu 24.04.5 x86-64 on WSL2 |
|---|---:|---:|
| Physical usables, original ordinary fixture | 272 checks, exit 0 | 272 checks, exit 0 |
| Same fixture with ownership assertions | 276 checks, exit 0 | 276 checks, exit 0 |
| Physical usable lifecycle | 39 checks, exit 0 | 39 checks, exit 0 |
| Physical usable equipment | 307 checks, exit 0 | 307 checks, exit 0 |
| Actor manipulation | 78 checks, exit 0 | 78 checks, exit 0 |
| Desktop and Web scene lifecycle under desktop Godot | 15 checks, exit 0 | 15 checks, exit 0 |
| Headless Workbench startup and ordinary timed quit | Ready marker, exit 0 | Ready marker, exit 0 |

Each platform imported a private project and used fresh application data per process. Both used Godot `4.7.stable.official.5b4e0cb0f`, Rapier 0.35.2, and the production native libraries built from `466d34506feb62132d5b1badd4a0f9ab4fbb6886`. The application source was accepted main `7a15691a7c537d07ff10a1bc4da9d46491c0b9d6`. The only changed script in the amended ordinary run was the fixture, SHA-256 `62a3a46c4aaca59ed2329d81030370b16025f7fa64fe5bdd5e4be9f5386619f4`. Per-process arguments, deadlines, timestamps, runtime and log hashes are in the [process ledger](processes.json).

Four additional Windows runs tested the sensitivity of the new assertions. In disposable fixture copies, each run temporarily kept one extra reference or altered the copied stock. Each produced its single registered assertion failure and exited normally with code 1. Restoring the exact fixture produced 276 checks, zero failures and exit 0. [Registration](ownership-controls.json) · [Observed process outcomes](processes.json)

**Disposition.** Keep the issue open and the PR in Draft. This checkpoint adds ownership coverage. There is no production repair or post-repair failure rate. The new experiments did not rerun the original or reduced fault-targeted fixtures. The original 100-process corrected-fixture qualification and contemporaneous red control remain outstanding. Attribution still requires evidence that connects the historical shutdown to a specific owner or cleanup operation before changing runtime behavior. The previously delivered evaluator's graphical sessions remain separate historical evidence. [Delivery record](https://github.com/techrote/cybersand/pull/784#issuecomment-7209864040)
