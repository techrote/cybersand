# Windows equipment fixture exit on November 27, 2026

The local Windows 11 equipment extent fixture intermittently exits with `0xC0000005` after reporting 29 checks and zero assertion failures. Each nonzero process exit counts as a failure. The original full Windows general-suite shard exhibited it once. A repeat of that complete shard passed all 16 assigned cases.

## Original fixture results

Each process used the pinned Godot 4.7 Windows GUI executable in headless mode or its console wrapper, the checkout's verified Windows native DLL and the unchanged test entry point. Both engine hashes, all five source and runtime identities, the 72 process outcomes, log hashes and invocation arguments are in [original-fixture.json](original-fixture.json).

| Source | Role | Nonzero exits / processes |
| --- | --- | --- |
| `b178f10ae993` | Commissioning main | 0 / 24 |
| `80caeece153a` | Main after Live Material Audition | 0 / 16 |
| `b1d33a18549a` | Main after Actor Compose | 2 / 16 |
| `7a15691a7c53` | Delivered main after SWARM | 2 / 8 |
| `7f8f731d4755` | Persistent Areas candidate with Water handoff fix | 2 / 8 |

## Lifetime controls

The equipment fixture with four additional World lifetime assertions completed all 33 checks, including destruction of all four Worlds, before encountering the same exit in 3 of 16 processes. Four direct native World constructions, 2048 × 1024 resets, coupling mask queries and verified releases passed in 16 of 16 processes. A smaller GDScript fixture that retains the original preloads and exercises only the physical usable runtime's construction, reset and snapshot produced the exit once in 16 processes. It creates no CyberNativeCellWorld itself. The three basic worker controls each exited normally in eight processes. The executed GDScripts, hashes and individual outcomes are retained alongside [lifetime.json](lifetime.json) and [worker.json](worker.json).

LLDB stopped on the main thread after the terminal summary on the Areas source. The nine application frames visible on the stack belong to the pinned Godot executable. Its nearest exported symbol cannot identify the failing engine function. [Debugger record](debugger.json)

An independent 272-process comparison held the Actor Compose binary fixed. All expected terminal markers appeared. Twenty-one processes exited with the access violation. The fault recurred after restoring both earlier equipment scripts or removing the new coupling-constant dependency. A wider rollback of 18 previously existing modified game scripts had zero exits in 16 trials against two in 16 concurrent stock controls. The comparison did not identify a single responsible source change. [Source variants, portable runner and individual records](https://github.com/techrote/cybersand/commit/da492f568ef5d490722fd6121d8da0ae7108b654)

The downloaded accepted-main Windows evaluator also ran its ordinary `Open Workbench.cmd` on the same TITAN RTX in three additional fresh processes. Each acknowledged Workbench admission and Rapier startup and exited zero. These executions establish the launcher result for this route and hardware. The frequency across gameplay remains unknown. [Original launcher outcomes](shipped-workbench.json) · [Qualified application download](https://github.com/techrote/cybersand/actions/runs/45936095825/artifacts/15172236802)
