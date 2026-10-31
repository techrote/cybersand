---
title: Windows palette decomposition compiler feasibility
status: Current
document-kind: evidence
scope: Source-pinned Windows compiler measurements and NO-GO for two registered palette decomposition families; no graphical or production acceptance
canonical-for: [play-pace003-palette-decomposition-feasibility]
last-reviewed: 2026-10-31
related-documents: [../operations/testing-validation-and-replay.md, ../operations/github-development-and-release.md, ../reference/validation-evidence.md, ../reference/invariants.md]
---

# Windows palette decomposition compiler feasibility

**Final measured decision: NO-GO for both registered decomposition families.**
The corrected first compiler campaign at `4982e767` completed every registered
case with valid controls and authenticated readback. All seven split programs
compiled, but the coarse family required 60.329724 seconds and the fine-building
family 57.652248 seconds of serial compiler wall time. The shared ordinary
program alone took 42.474788 seconds. These results fail the preregistered
20-second screen and exceed the complete 30-second Main allowance on this host.

The owner requested completion of an isolated feasibility PR for
[#309](https://github.com/techrote/cybersand/issues/309). The preregistration,
including its original pending-results table, is retained below. The dated
result addition identifies the actual source, first attempts and decision;
it does not establish rendered equivalence or a production correction.

The manual branch is `codex/play-pace003-palette-decomposition-20261031`, based
on accepted main `0bf28d5760aed989a79386de03ef4fc6171fef42`, tree
`b9f8b6425812b3cd5230127f1ab81c74f15e6e40`. Coordination belongs in the existing
[#305 ledger](https://github.com/techrote/cybersand/issues/305). The write set
is limited to the new diagnostic generator, compiler harness, their focused
tests, a dedicated GitHub-hosted workflow and this evidence/documentation route.
Generated HLSL, bytecode, original logs and captures are retained artifacts, not
production shader replacements.

## Reconciliation and preserved source boundaries

Fresh reconciliation found production [#310](https://github.com/techrote/cybersand/pull/310)
open at `dc324f7a9e27835a7efade57b6b7f1efd6c3ef82`, with its Linux startup
correction and separately failed Windows PACE result. Diagnostic
[#312](https://github.com/techrote/cybersand/pull/312) remains frozen at
`5de468478c37c8ae9e2d446ba348d4e3ecf54bd6`. Neither PR has an unresolved inline
review thread at this reconciliation. Their branches are not modified by this
experiment. [#308](https://github.com/techrote/cybersand/pull/308) remains at
`2443a78378d649df588efeac9db7c54084473329`, unmerged and subject to its complete
graphical acceptance hold. Scheduswarm remains paused with automatic dispatch
disabled; no automation or successor task is created.

The [prior authoritative handoff](https://github.com/techrote/cybersand/issues/309#issuecomment-6537758061)
and [retained evidence receipt](https://github.com/techrote/cybersand/issues/309#issuecomment-6538165753)
remain historical evidence. The prior standalone compiler run reproduced the
180-second failure without Godot, a graphics device or native World. The
one-bit skip-optimization contrast also failed. Earlier range-group and
single-exit variants were still monolithic programs; their failures do not
answer whether independently compiled programs fit a useful aggregate budget.
The late, distinct unified candidate and its earlier identical-input failures
remain separate evidence, not a successful original baseline.

## Authenticated original compiler input

The input is the phase-1 hoist control captured from source
`3b986726c52babe3013df48300d97f775392aa38` in
[run 41139717684](https://github.com/techrote/cybersand/actions/runs/41139717684),
attempt 1. **It is not the later production #310 shader's compiler output.**
The original artifact is authenticated before generation or execution.

| Input | Frozen identity |
|---|---|
| Original artifact | `13020405751`, `play-pace003-windows-paths-41139717684-1` |
| Original ZIP | 3,299,869 bytes; SHA-256 `426dd61cb2dc13395c586b4e601f83f67f16865f1d101cd2dab28682be6b6fad` |
| Original palette shader | SHA-256 `426c2b8a829d6ca216659b73f7663ba6c7f6dddd300726b81ed1eec85bbd3e1d` |
| Captured HLSL | 175,942 bytes; SHA-256 `192c1a086d5124ce4b22cb172bd90876212779e4d6c67447f9278493ba3ff03c` |
| Authentic System32 compiler | `d3dcompiler_47.dll`, SHA-256 `64054871e088d47b4b7380f90efa40cf2f57bd966724764330a029f4fc3aa6eb` |
| Original trace member | `campaign/hoist-control-cold/d3d-trace/d3d-trace-5340.jsonl` |
| Original HLSL member | `campaign/hoist-control-cold/d3d-trace/d3d-5340-44-source.hlsl` |
| Original compiler manifest | `d3d-compiler/build-receipt.json` |

The original invocation is `D3DCompile`, source name `C:\fakepath`, entry `main`,
target `ps_5_0`, flags1 `0xc000`, flags2 zero, and macro
`ANGLE_ENABLE_LOOP_FLATTEN=1` followed by the required null macro terminator.
The include pointer is null; no secondary input is used. Validation remains
enabled. The original trace has 43 completed calls followed by open palette
call 44. Authentication binds these arguments as well as source bytes, artifact
identity, ZIP safety/CRC and compiler identity.

The reviewed [frozen replay](https://github.com/techrote/cybersand/blob/5de468478c37c8ae9e2d446ba348d4e3ecf54bd6/tools/diagnostics/replay_pace003_hlsl.py)
and [review 5720034205](https://github.com/techrote/cybersand/pull/312#pullrequestreview-5720034205)
provide the existing ABI, input-authentication and conservative deadline
reference. Their original execution is
[run 41149030607](https://github.com/techrote/cybersand/actions/runs/41149030607),
artifact `13022287635`, 3,026,839 bytes, SHA-256
`8cb709913ebc99b425dbc76888e6c5b0750e7e2ecc5044908b624aa4870dbd3d`.
That historical run does not qualify this new generator or executable source.

## Registered program families and semantic hypothesis

The [generator](../../tools/diagnostics/pace003_decomposition_variants.py)
operates only on the authenticated original HLSL. It records each generated
program's bytes and SHA-256, declared domain, removed helpers and
reversible source patch ledger. Catalogue formulas inside their retained domain
remain unchanged. Transitive function-call reachability permits removing dead
helpers; it does not authorize removing reachable work or assuming an unknown
call is dead. Reconstruction and domain checks must reject unexpected source,
unsupported transformations, missing ranges or overlapping ranges.

| Palette case | Role and admitted material IDs |
|---|---|
| `original-control` | The complete unchanged original HLSL; matched reference measurement |
| `compositor` | Preserve temporal blending, ambient-particle, player/rig and final outside-view composition using stage inputs |
| `ordinary` | Ordinary catalogue and unknown-ID fallback: 0-80 and 132-255 |
| `building` | Complete building catalogue: 81-131 |
| `building-81-93` | First fine building partition: 81-93 |
| `building-94-106` | Second fine building partition: 94-106 |
| `building-107-119` | Third fine building partition: 107-119 |
| `building-120-131` | Fourth fine building partition: 120-131 |

The **coarse family** is `ordinary + building + compositor`, three compiled
programs. The **fine family** is `ordinary + building-81-93 + building-94-106 +
building-107-119 + building-120-131 + compositor`, six compiled programs.
Within either family the material programs partition the complete byte-ID
domain 0-255 without overlap or omission. The shared ordinary and compositor
measurements are used in both family sums and are not additional reruns.

Current and previous material IDs must be shaded independently before temporal
mixing. Each material-stage program has an experimental uniform selector in
`b4` for `current`, `previous` or `air0`. The mode changes the stage input while
reusing the same compiled program. The `air0` path accounts for the original
outside-view material-zero colour. The compositor receives current, previous
and air-zero stage colour through experimental bindings `t8`, `t9` and `t10`.
These are diagnostic interfaces, not an accepted renderer interface or an
implemented production render graph.

The three intermediate surfaces use the original framebuffer raster grid.
Compositor `Load` coordinates derive from `input.dx_Position.xy` (the original
`SV_Position`), with matching viewport origin, extent and raster sample grid
required across stages. Logical view-cell coordinates are insufficient: two
framebuffer pixels inside one logical Water cell can select different subcells.
Independent review corrected that interface before any Windows execution, and
the generator tests retain a concrete Water/Empty subcell regression. The
coarse proposal requires six draws including composition; the fine proposal
requires twelve, even though only three or six unique programs are compiled.

Preserving source expressions and operation order is necessary but insufficient
for visual equivalence. Separate passes can change intermediate precision,
alpha/blend behavior, implicit derivatives, texture LOD, filtering and coverage.
A later graphical prototype would need explicit float32 linear intermediates,
controlled stage blending and exact original/candidate native-framebuffer and
PNG comparisons, including mixed material transitions and outside-view pixels.
No such visual comparison or device execution belongs to this compiler-only run.

## Execution and control protocol

### Retained first hosted apparatus failure

The first published head was `42963c4d1158c2c4d0213bf4c1447f9a24f71c21`,
tree `810d0f0a491e414683371395de104f27e8474217`. Its original
[run 41165620441](https://github.com/techrote/cybersand/actions/runs/41165620441)
attempt 1 authenticated the original input and passed all 18 generator tests
under normal and optimized Python. One of 30 harness tests failed on Windows:
the backslash ZIP-name fixture was normalized by `ZipInfo` before the reader
saw it. No compiler case ran. Readback correctly failed for the absent campaign;
this is an apparatus failure, with no shader feasibility conclusion.

Artifact `13029097591` retains all 17 files, 2,948,952 ZIP bytes, SHA-256
`0b7f56ea08c8bce9431313e2216b57b0a5205b5b0b4b3988fb0c9402f5f4a290`.
The complete original job log is separately retained. That head's Documentation
and provenance run `41165620343` passed; its diagnostic failure remains failed.

The correction inspects both `ZipInfo.orig_filename` and normalized `filename`,
including NUL refusal. The fixture now changes both raw ZIP filename headers
after construction with an equal-length replacement; another test explicitly
emulates Windows separator normalization. The new regression fails before the
reader correction and passes afterward. All 31 harness tests pass normally
and with optimized Python. Independent review confirms every harness top-level
element outside `read_original` and the complete generator are unchanged;
the compiler inputs, ABI, deadlines, order and decision budgets stay fixed.

### Registered execution sequence

All programs execute **serially on one GitHub-hosted `windows-2022` runner**.
Each invocation uses a fresh Windows x64 child process and the authenticated
native System32 compiler with the original API arguments and flags. The eight
palette cases each have the unchanged **180-second whole-process bound**.
The two API controls each have a **30-second whole-process bound**. A late
completion observation cannot become an accepted in-bound result.

| Control | Required original evidence and interpretation |
|---|---|
| Tiny valid shader | Successful HRESULT, nonempty retained DXBC/disassembly, clean exit and in-bound completion |
| Invalid-source shader using `#error` | Explicit failed compiler HRESULT, nonempty retained diagnostic bytes, completed begin/return/end records, expected clean failure exit, no DXBC and in-bound completion |
| Authentic original monolith | A measured reference, preserving success, compiler failure or timeout exactly as observed; an unexpectedly fast result is evidence and does not invalidate the apparatus |

A generic failed status is insufficient for the invalid-source control: a
wrapper exception, missing input, process crash, wrong compiler or timeout is
an apparatus failure. The valid and invalid controls do not create a graphics
device or execute the palette. Programs are not compiled concurrently to meet
the aggregate budget. No accepted cached bytecode substitutes for compilation.

The [harness](../../tools/diagnostics/run_pace003_decomposition.py) records
call-only wall time, calling-thread CPU time and process CPU time from original
counters. It persists the compiler-return receipt before
blob copies, disassembly or later artifact work, separating compiler execution
from diagnostic postprocessing. Each row also records whole-process completion
observation, deadline, exit status, compiler messages, bytecode/disassembly
identity and any timeout diagnostics. An unfinished call has censored CPU/wall
observations, not an invented completed-call duration.

Fresh processes do not establish cold OS file pages. The tiny control loads the
same compiler library; external OS cache state is not asserted. Standalone
compilation omits Godot's preceding 43 compiler calls and engine concurrency.
These qualifications apply to every timing and feasibility statement.

## Preregistered decision rule

The engineering screen is **20 seconds for the complete family**, reserved
before observing results. It leaves nominal room below the unchanged 30-second
Main acknowledgement contract, but that margin is a screening choice, not a
measurement or guarantee of engine startup cost.

**GO for a separately qualified renderer prototype** requires valid controls,
complete source/compiler/output custody and at least one complete family whose
necessary programs all compile successfully within their individual bounds.
For that family **both** the serial sum of call-only compile wall times **and**
the serial sum of whole-process completion observation times must be at most
20 seconds. The original monolith is a separate reference and is not added to
either family sum. Tiny controls are apparatus checks, not family members.
Compilation failures, omitted required programs and late observations cannot
be treated as zero-cost members of a family.

**NO-GO for the tested decomposition** applies when the apparatus is valid but
neither complete family meets both budgets, or genuine compiler rejections or
timeouts prevent both families from completing. This is a decision about these
registered programs, compiler and platform; it does not prove that every
possible decomposition or Windows renderer is infeasible.

**INCONCLUSIVE / apparatus failed** applies when controls, provenance, source
generation, output validation or execution custody fail. Missing evidence does
not support either a favourable timing decision or a universal compiler claim.
All first attempts and adverse results are retained. Any subsequent experiment
must be separately identified rather than replacing a failed row in this one.

## Evidence retention and result checkpoint

The resulting evidence must bind the exact tested commit/tree, checkout and
workflow bytes; complete generator, compiler harness and test sources; original archive/API
metadata; input and transformation receipts; host, Python and dependency
identities; compiler bytes and loaded path; all generated HLSL; every original
process log and compile-return record; retained bytecode/messages/disassembly;
timeouts and cleanup evidence; the complete matrix and decision calculation.
Independent readback must recompute file hashes, domain coverage and family
totals from the retained originals. First attempts remain identifiable even if
workflow or apparatus failures prevent a conclusion.

| Result item | State at preregistration |
|---|---|
| Source-bound Windows execution | Not executed |
| Positive and invalid-source controls | Not executed |
| Original monolith reference | Not executed in this experiment |
| Coarse family compiler/process totals | Unmeasured |
| Fine family compiler/process totals | Unmeasured |
| Feasibility decision | Pending execution and independent readback |
| Graphical parity, real Main and production acceptance | Not executed or established by this experiment |

The final source-bound run, original artifact/log digests, independent review
and measured decision belong in the new PR's qualification ledger and a dated
result addition to this record. This placeholder must not be rewritten as if
measurements existed at preregistration.

## Actual Windows results and decision — 2026-10-31

[PR #316](https://github.com/techrote/cybersand/pull/316) contains the isolated
apparatus. Actual executed head:
`4982e767317c3348d5c6c5ea735fb931e0a86eb3`; tree:
`9d19becd3eb672e7e6c87cb05437b4a5762fae4c`. The original
[run 41165819892](https://github.com/techrote/cybersand/actions/runs/41165819892)
attempt 1 used job `124433039153`. Later result documentation does not relabel
these measurements as another executed commit.

The final publication checkpoint adds the result and retires this diagnostic's
automatic `pull_request` trigger after completion. The `workflow_dispatch`
declaration is retained; manual dispatch of this unmerged checkpoint has not
been exercised. All four executable Python
files are byte-identical to the measured head; the workflow difference removes
automatic admission only. Its executed version is retained in the original
artifact. Mandatory production workflows and gates are unchanged. There is no
claim that the final publication commit itself ran another compiler campaign.

The recorded host is Windows Server 2022 Datacenter, build 20348, with an AMD
EPYC 7763 CPU model and two cores/four logical processors exposed to the runner.
Python was 3.12.10 x64; process sampling used pinned psutil 7.1.3. The actual
System32 DLL matches the registered compiler hash. No Godot, graphics device,
native World or renderer workload was created.

### Completed compiler calls

Times below are seconds. Compiler wall and thread CPU cover the actual
`D3DCompile` call. Process observation includes interpreter setup, source
regeneration, DLL authentication, compilation, disassembly and parent polling.
The program inputs and outputs retain their exact hashes in the artifact.

| Program | HLSL bytes | Compiler wall | Compiler thread CPU | Process observation | Result |
|---|---:|---:|---:|---:|---|
| Tiny valid API control | 80 | 0.001700 | 0.000000 | 0.152580 | Successful HRESULT, DXBC and disassembly |
| Invalid-source API control | 175,989 | 0.000324 | 0.000000 | 0.101893 | Explicit failed HRESULT and expected diagnostic; no bytecode |
| Original monolith | 175,942 | Not completed | Not available as call delta | 180.000132 | Timeout; no API-return receipt or output |
| Compositor | 38,990 | 0.903171 | 0.890625 | 1.109565 | Compiled |
| Ordinary: 0-80 and 132-255 | 118,589 | **42.474788** | **42.468750** | **42.813890** | Compiled |
| Complete building: 81-131 | 83,798 | 16.951766 | 16.953125 | 17.237772 | Compiled |
| Building: 81-93 | 56,207 | 4.955004 | 4.937500 | 5.192217 | Compiled |
| Building: 94-106 | 53,258 | 3.729313 | 3.734375 | 3.931112 | Compiled |
| Building: 107-119 | 53,262 | 3.342562 | 3.343750 | 3.578969 | Compiled |
| Building: 120-131 | 50,059 | 2.247411 | 2.250000 | 2.471985 | Compiled |

The original monolith's timeout snapshot recorded process CPU
`179.828125 + 0.140625 = 179.968750` seconds. Its only observed thread had the
same total. These are parent samples including process setup and possible
deadline overshoot, not an invented completed-call duration. Tiny-call CPU
values of zero reflect the granularity of the retained Windows CPU counters.
Small CPU-versus-wall differences in other rows have the same counter/timing
limitations and are not altered to make them equal.

All seven split shaders returned successful HRESULTs and retained valid DXBC
containers and disassembly. All six material programs also retained **X4000
potential-uninitialized warnings**: ordinary names structured-fill and
neighbour-relief helpers; complete building and its first three leaves name
building-finish and neighbour-relief helpers; the last leaf names
neighbour-relief. The compositor produced no retained warning blob. These
warnings remain unadjudicated. The original monolith never returned, so there
is no baseline diagnostic result establishing whether it would emit the same
warnings. No warning-free or visually correct shader claim follows.

### Complete-family adjudication

| Registered family | Required programs | Serial compiler wall | Serial process observation | Decision |
|---|---:|---:|---:|---|
| Coarse | 3 | **60.329724 s** | **61.161226 s** | **NO-GO** |
| Fine building | 6 | **57.652248 s** | **59.097738 s** | **NO-GO** |

Both API controls passed their distinct contracts. All rows and source/output
custody are complete. This is a valid **negative feasibility result**, not an
apparatus failure. The execution step deliberately exited 1 for NO-GO, so the
workflow remains red. The subsequent strict evidence readback passed and
artifact upload passed; neither converts that feasibility result into a pass.

The four building leaves total 14.274289 seconds, compared with 16.951766 for
the complete building program. Their reduction is only **2.677476 seconds**, or
about **4.44% of the complete coarse family**. The unchanged ordinary program
alone exceeds 30 seconds. Further building-only subdivision therefore does not
address this observed critical cost. CPU time closely follows ordinary-call
wall time; the evidence does not identify a particular internal compiler pass.

The original's actual completion time is censored by its timeout. No precise
original-to-split speedup ratio is claimed. The seven successful split calls
establish bounded compiler tractability, but neither family meets the startup
feasibility target. This single source/host cohort is not a statistical timing
guarantee or proof that every equivalent decomposition is impossible.

### Original custody and review

Original artifact `13028433030`, named
`play-pace003-decomposition-41165819892-1`, contains **122 files** in a
**6,887,531-byte ZIP**, SHA-256:

```text
d719b6a0c8207c02d73126e1e8acde38baf071234dcbc34073c66d4ff1921bca
```

Root readback authenticated the original ZIP/CRC, all retained inputs and
outputs, complete executed source against the immutable commit/tree, original
archive/API receipt, reversible patches, exact row order, CPU counters,
deadlines and recomputed family decisions. Separate reviewers independently
read original archive bytes and adjudicated the result; their detailed receipts
and owner-account COMMENT reviews are linked from #316's qualification ledger.
The earlier failed artifact `13029097591` remains retained separately.

All **18 generator and 31 harness tests** passed on Windows under normal and
optimized Python with the authentic source and no skips. Corrected-head
[Documentation and provenance 41165819891](https://github.com/techrote/cybersand/actions/runs/41165819891)
and [scope advisory 41165819896](https://github.com/techrote/cybersand/actions/runs/41165819896)
passed. Draft Native and GDExtension/Godot runs were intentionally skipped;
they are not runtime qualification. The draft Documentation workflow skips its
ready-only materialized-runtime provenance step while still checking docs,
historical integrity and LFS objects. Local repository identity checks used
pointer mode. No production or real graphical acceptance is claimed.

### Bounded continuation decision

**Do not implement either tested decomposition as the proposed startup remedy
on this evidence.** A useful separately registered next diagnostic would focus
on the ordinary program: further semantically complete partitioning or a
compiler-source minimization using its exact retained HLSL and warnings. That
work is not performed or silently admitted by this PR. Preserve the original
compiler, original flags, all material/fallback/snapshot/Empty paths and the
same complete-family accounting if another experiment is authorized.

The proposed renderer designs would add six or twelve draws and three RGBA32F
surfaces. Their raw texel payload alone is 23.730469 MiB at 960x540, or
94.921875 MiB at 1920x1080, excluding alignment, existing targets and in-flight
duplication. These are calculated resource requirements, not measured GPU
costs. Compilation success does not establish acceptable steady-state rendering.
All pixel, derivative/LOD, alpha/HDR, snapshot and ownership requirements above
would still apply to a future prototype that first passes its compiler screen.

## Documentation impact and continuation limits

| Contract or documentation home | Impact of this experiment |
|---|---|
| Architecture and native ownership | Unchanged: no native source, World owner, worker, snapshot or main-thread Rapier change |
| Material/rendering invariants | Production unchanged; experimental stage interfaces and unproved visual equivalence are recorded here |
| Configuration and user controls | Unchanged: no production renderer, window, solver, worker, input or gameplay default changes |
| Runtime/dependency provenance | Authentic compiler is checked; Godot, LFS runtimes and pinned engine bytes are not changed |
| CI/release policy | One bounded GitHub-hosted diagnostic workflow; mandatory gates, command bounds and merge conditions remain unchanged |
| Scientific/training inputs and historical evidence | Unchanged; all earlier failures and source-specific results remain retained |
| Roadmap/handover and retrieval routes | May link this diagnostic evidence; no PLAY completion or production feasibility promotion follows from source preparation |
| Build/test/evidence guidance | Focused generator, ABI, negative-control, deadline and custody checks plus original Windows measurements are required |
| ADRs and production renderer interface | No accepted architecture decision is changed by these experimental bindings |

A favourable compiler screen permits recommending a bounded renderer prototype.
It does not authorize silent production adoption or qualify regenerated current
#310 shader programs. That successor would need exact visual/compositing
evidence, original cold Windows and Linux Main with accepted terrain/actor and
PNGs under the unchanged 30/180-second limits, required graphical/lifecycle
regressions and complete applicable resulting-head ordinary gates. Input-to-
completed-Rapier binding, healthy automatic pause/resume and #270 physical
devices/human feel remain separate requirements. Keep #309/#269/#270/#263 open
and the #310/#308 integration holds intact until their own acceptance is met.
