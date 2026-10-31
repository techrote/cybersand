---
title: Windows palette decomposition compiler feasibility
status: Planned
document-kind: evidence
scope: Preregistered source-pinned compiler-only decomposition experiment for PLAY-PACE-003; no graphical or production acceptance
canonical-for: [play-pace003-palette-decomposition-feasibility]
last-reviewed: 2026-10-31
related-documents: [../operations/testing-validation-and-replay.md, ../operations/github-development-and-release.md, ../reference/validation-evidence.md, ../reference/invariants.md]
---

# Windows palette decomposition compiler feasibility

**Preregistered experiment; execution results are not yet available.** The owner
requested completion of an isolated feasibility PR for
[#309](https://github.com/techrote/cybersand/issues/309), with original compiler
measurements, negative controls and a bounded go/no-go conclusion. This record
defines that experiment before its Windows execution. It does not claim that
decomposition works, that any generated program draws correctly, or that the
unchanged 30-second Main acknowledgement requirement is satisfied.

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
workflow bytes; generator/harness/test/monitor sources; original archive/API
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
