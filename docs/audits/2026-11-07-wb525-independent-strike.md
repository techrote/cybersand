---
title: WB525 independent integration, capacity repair and physical cause
status: Current
document-kind: audit
scope: One-off source composition, source-built desktop qualification and unresolved owner acceptance
canonical-for: []
last-reviewed: 2026-11-07
related-documents: [../systems/shared-workbench-agent-authoring.md, ../operations/local-build-and-validation.md, ../operations/current-and-historical-validation.md]
---

# WB525 independent integration, capacity repair and physical cause

## Source and ownership

Inspected on 7 November 2026: accepted main
`662ed4d88c08070dbb6f313931146a23e3631471`, tree
`49a00e4b0e8e0da123b0fec2b5739a31fbbba886`; Draft #529
`6a9967fbd47c992c8f1bcd109163563d0f3ab18f`; Draft #530
`ffde819818556c61a335674fc366ab3b4a865af2`; Draft #531 initially
`a8c06fa058ae8d8e031f4887a1e5c5b4c3f48761`, then refreshed to
`8425758fcfc1d4fa589c5ee3a5258760741ef191`, tree
`6d1b994338640bdf6565aeeb4203eb2444e3c216`. Closed/no-merge physical
experiment #537 is `c930fb20074f993fdab7cd00e0a66bd18d85d570`, tree
`dc3650e67b8d32df7f5db047a865c5e669eb5baa`.

An isolated composition first consumed the #526/#527 handoffs. The #528 owner
then independently delivered that composition at `8425758f`; final repair work
uses that exact owner source. It preserves accepted-main Atlas routes, native
physics, material authority, World ownership and all frozen fixture bytes.
The dirty `C:/khybersand` MAT checkout at `620826f5` was not modified.

The human explicitly authorized **only two isolated production repairs** after
the [ownership request](https://github.com/techrote/cybersand/pull/531#issuecomment-6712055184).
The [handoff notice](https://github.com/techrote/cybersand/pull/531#issuecomment-6712114667)
reserves those slices; no original worker branch was written. Recoverable code
checkpoint `5d5d8bc6a98ddb115efe789f113fd8c656b6ae36`, tree
`171107ef0ad22cf9bc269817ae4abc80f88f2daa`, is published on
`codex/wb525-strike-evidence-20261107` for the existing #531 owner to consume.
There is no new integration PR, Ready transition, merge or production admission.

## Reproduced defects and repairs

**Current in this isolated patch:** `workbench_agent_client.gd` permits a finite
524288-character native JSON receipt. The previous65536 limit discarded a
valid4096-cell proposal. A separately reproduced1400-cell apply had already
performed and confirmed every native write and recorded authored construction,
but lost its known `applied` result at the client boundary. The new allowance is
4096 rows times112 characters plus65536 metadata characters; original image,
edit, request, tool and token limits remain separate. No mutation is retried.

**Current in this isolated patch:** `workbench_agent_mount.gd` redraws scope and
proposal overlays when camera origin, view size, content rectangle or signed
presentation origin changes. Previously cached draw commands stayed in old
screen positions after same-size camera pan. It disconnects its global frame
callback when the host exits; camera-only motion does not retire native proposal
authority. World/snapshot/interface ownership and native work capacity are unchanged.

The real mounted Windows regression prepares4096 cells without mutation, pans
and zooms with that proposal still valid, applies and verifies4096 actual native
material IDs, replays the same retained duplicate receipt, observes4096 Walls
and receives native Stop. It also verifies callback retirement on scene exit.
Observed JSON sizes:201010 proposed and258648 applied characters; native tick0.
Initial/final original PNGs and receipts remain under the execution directory.

An independent review accepted both narrow production changes and reran the
existing client86/86. It found an initial qualification-runner false-positive
path: zero exit without a positive test summary. The runner now requires the
case-specific positive-count/zero-failure summary, rejects Godot script/runtime
errors and preserves failed/timeout logs. Explicit zero-assertion and missing
summary controls refuse. Historical failed attempts are not relabelled.

## Why do 26 translated NORMAL states differ?

**Measured:** native `World::deterministic_direction` hashes absolute x/y and tick.
At the first branching update, original(-1,8) chooses-1; translated(511,520)
chooses+1 with the same local occupancy. Unchanged physics therefore chooses
opposite legal diagonal moves. The +512 shift preserves chunk/core/color/scan
parity but not the direction hash. Original #537 compares two unrestricted
signed Worlds: finite boundaries cannot cause those26 differences.

Independent GCC13.3 source builds reproduce NORMAL mismatches at ticks
7,8,9,10,38,39,41,42,43,44,45,48,49,50,51,52,53,55,56,57,58,59,60,61,62,63
with configured workers1 and4. Maximum symmetric occupancy difference is4
sites. REVISED matches all481 sampled states. Corresponding finite2048-square
scheduling coverage preserves the same result. A **test-only copied** World that
subtracts512 before that hash removes all differences in all four arms. This
causal intervention is **Rejected as a production repair**: it changes the
coordinate-dependent physical law. The original source and fixture stay intact.

Every arm conserves32 Sand and17 protected Walls, completes480 native ticks,
matches catchment counts at all481 states, first completes at NORMAL57 and
REVISED40, and has identical terminal occupancy. This proves terminal/count
equivalence, not trajectory equivalence. Actual participating worker maximum
in the frozen native control remains1; configured4 is not a concurrency claim.

**Approved owner disposition, later in this execution:** after the difference
was explained in plain language, the human explicitly answered **“Yes—use the
moved hopper and record the difference.”** The +512 hopper is admitted as the
workbench acceptance control, preserving original logical geometry, counts,
protection, materials and total480 ticks. The
[owner decision record](https://github.com/techrote/cybersand/issues/525#issuecomment-6712294815)
supersedes the earlier fixture-admission HOLD. It does not claim identical grain
trajectories, approve a hash/physics change, merge, paid spending or human verdict.
Literal signed trajectory reproduction remains separately unqualified; it would
need bounded adapter/canvas/render/camera work, not a new physics engine.

## Executed platform evidence and retained failures

Official Godot4.7 `4.7.stable.official.5b4e0cb0f`, Windows NVIDIA OpenGL
compatibility and WSL Ubuntu24.04 GCC13.3/ld2.42 were used. The pinned
godot-cpp revision remains `101ae38034304346a46ea9ea84ae156d3e860496`.
Both extensions were freshly compiled from unchanged current native source
using `tools/build_native_extension.sh` and
`tools/build_native_extension_windows.sh`; the Windows build's first attempt
failed on the machine's python3 Store alias, then passed using the existing
local Python shim. That failure is retained.

| Runtime | SHA256 |
|---|---|
| Rebuilt Windows CyberSand DLL | `33484119fa2026e42c997d990088fb8fcd3666186502bfac0c6c26cd94e6cac8` |
| Rebuilt Linux CyberSand SO | `23cb57d97b31aeb6720c4363dc90dfb437e6dd25566ae8a5865c2b6a4fafa605` |
| Retained Windows Rapier DLL | `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7` |
| Retained Linux Rapier SO | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |
| Frozen v2 TSV | `549a1db2520bcfb35f068f46b62320d7325d6297037ca2faf23c3b488d80347c` |

The Linux rebuild is byte-identical to the retained SO and passes the GLIBC2.34
bundle floor. The local Windows DLL differs from committed LFS identity and is
**not published**. `check_repository.py` consequently reports that local
runtime mismatch; it must not be suppressed or treated as source publication.
The clean retained-runtime source validation is a separate gate.

Windows source-built execution passed native owner141, four-tool join46,
signed join16, direct experimental frozen hopper106, mounted client68,
manual input24, native render bridge, manual save6 and separate-process reopen3.
The new mounted **panel -> asynchronous fake Responses -> native dispatcher**
hopper passed both destinations: four applied native batches, exactly480 ticks,
32 catchment Sand,17 protected cells, original PNGs and acknowledged Stop.
This extends the prior direct-bridge hopper through the actual panel/client.
The full fake transcript uses20 HTTP turns from an explicit **test-only24**
budget; the paid default12 has not changed. Real live trials need a predeclared
adequate request allowance and aggregate480-tick accounting.

The unchanged canonical Step test exposed a test synchronization failure on
Windows: its manual-step predicate observes the serial before the paused native
publication, and the next agent call correctly refuses. Its four failed
assertions/final127 ticks are preserved. A separately owned wrapper waits for
the actual paused publication and passes33/33 with130 total ticks and Stop
after3 completed ticks. The [#527 handoff](https://github.com/techrote/cybersand/pull/530#issuecomment-6712145130)
requests that predicate correction. An initial headless invocation incorrectly
waited for graphical post-draw; it was terminated and is not a qualification pass.

Full production workflows were explicitly dispatched on code checkpoint5d5d8bc6:
[Native42408005905](https://github.com/techrote/cybersand/actions/runs/42408005905),
[GDExtension42408008040](https://github.com/techrote/cybersand/actions/runs/42408008040),
[Documentation42408010135](https://github.com/techrote/cybersand/actions/runs/42408010135).
Read actual final conclusions; dispatch and Draft-skipped jobs are not passes.
Documentation passed on5d5d8bc6. The initial full GDExtension run was cancelled
after detecting that the three new graphical tests needed the repository's
`_render` naming convention. Follow-up code commit
`ecdbc6ab603af0302a0675b7bfea36fe62263e7a` classifies them correctly and selects
Dummy audio in the offline runner. Linux's first graphical diagnostic passed
its native assertions but emitted an unavailable-ALSA-device error; the strict
runner correctly refused it. Windows-worktree Git under WSL uses an explicit
Windows-Git shim; initial native-WSL-Git path failure is also retained.
Local platform JSON reports/logs include exact commands, timeouts, source file
hashes, runtime hashes, process exits, failures and original image hashes.

## Reproduce and launch on Windows

The isolated working checkout is
`C:/Users/_/.codex/worktrees/wb525-strike-20261107/khybersand`.
Run the graphical application from PowerShell:

```powershell
& C:/Godot47/Godot_v4.7-stable_win64.exe --path C:/Users/_/.codex/worktrees/wb525-strike-20261107/khybersand/godot --rendering-method gl_compatibility -- --workbench
```

Ordinary brush, Step and named authored starts work with agent features disabled.
Enable **Agent authoring (opt-in)** for the panel. Choose task, model, bounded
region, protection and Hard Wall/Empty permissions. The experimental +512
checkbox is off by default; selecting it is not physical acceptance. Start
needs a process-local `OPENAI_API_KEY`; do not store a key in project/saves/logs.
Stop retires native authority before another task can begin. No credentials or
genuine service attempts were used by this execution.

From that source root, run the offline automated native/UI gate (output must be
a new directory):

```powershell
python tools/wb_agent/qualify_integrated.py --godot C:/Godot47/Godot_v4.7-stable_win64.exe --output build/wb525-new-run --cases client capacity-camera step-paused-boundary mounted mounted-hopper manual-input render-bridge manual-save manual-reopen
```

The generic default also runs the original Step test and deliberately preserves
its failure if its publication race occurs. The wrapper is separately named.
Graphical cases have420-second process bounds; headless/import cases240.
The runner removes `OPENAI_API_KEY` from child environments and makes no paid
calls. For Linux use the same Python entry point with the locked Linux Godot
path and `--xvfb`, after source-building its extension.

Physical causal evidence remains in the independent worktree's ignored
`build/wb525-physical` directory. From PowerShell:

```powershell
wsl -d Ubuntu-24.04 -- bash -lc 'cd /mnt/c/Users/_/.codex/worktrees/wb525-physical-20261107/khybersand && bash build/wb525-physical/reproduce.sh'
```

It compiles original, copied-hash-counterfactual and finite-coverage controls
with90-second execution bounds. Generated diagnostic World copies, binaries,
PNGs, logs and machine-local toolchains are excluded from the commit.

## Completion and shortest remaining route

Engineering has substantial source-built desktop evidence, with full hosted
production results, canonical Step-test correction and resulting #531 owner
consumption/review still separately required. MAT-AUTH and GEN-006 files,
native laws/defaults, failure quarantine and immutable render authority were
not modified. Save/reopen qualification concerns authored starts, never evolved
runtime persistence. No new ADR is needed for these bounded UI/transport repairs.

Live remains **0/3 genuine attempts, HOLD**. The moved fixture is now owner
admitted; the owner must still approve registered spending/model/turn limits and use a
trial driver that counts actual cumulative ticks. All three actual attempts,
at most one repair each, must be preserved. This offline fake transport cannot
supply that gate. Human Windows graphical preview/intervention/recovery verdict
is **PENDING** and cannot be supplied by automated input or CI.

The shortest route is for #528 to consume the isolated repair commit into its
existing PR, for #527 to correct its paused-publication test predicate, to read
the exact resulting-head production gates, then perform the three registered
bounded live trials plus human review using the owner-admitted moved fixture. No
parent/child closure or merge is authorized by this record.
