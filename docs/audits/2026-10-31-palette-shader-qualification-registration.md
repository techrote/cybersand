---
title: Actual backend palette shader qualification registration
status: Current
document-kind: audit
scope: Source-bound Linux native GL and Windows ANGLE shader apparatus; hosted execution is required separately
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [2026-10-31-palette-shader-integration.md, ../systems/material-appearance-and-rendering.md, ../operations/current-and-historical-validation.md, ../operations/local-build-and-validation.md]
---

# Palette shader qualification registration — 2026-10-31

## Source and claim boundary

This apparatus follows selected production integration
`88ed5ce3fc17673a8a1541c00f6ad3195961d971`, tree
`2084feed9dd448d57a394b029b3dbc7fa9e12a06`. It requires the shared execution
policy and generic runner from watchdog candidate
`c3a7ff3084b5dc76c739c4e297eafff28b8d67d9`, tree
`0bf363a43ebe9fd433fdd7bba3ad83a1ef007d7a`, followed by the Windows custody
corrections and shared `godot_process_cleanup_seconds()` planner correction at
`ab8d92ac76b905e05412ba03b62010c7e7db4964`, tree
`064f8553ec5b7443314fe1c495c80beeb76760bb`. The combined published watchdog base
is `a2543abdcf611d232f538462358bd12bfb0d152f`, tree
`d93c91e1f5a6b2c4fa66a151f23731e29b72323f`. That dependency is a candidate until
its exact source passes the separate acceptance gates. The qualification runner
requires a committed, clean, exact source checkout and records its commit, tree,
canonical Git archive, every scoped source hash, selected materialized LFS
runtimes, engine version and executable digest. Its independent reader runs from
the externally supplied exact commit and re-exports the source archive.
Actual checkout hashes are retained before and after execution. Only LF/CRLF
forms declared by authenticated archived `.gitattributes` may differ from Git
blob bytes; unregistered normalization is rejected. The two tracked Windows
batch/PowerShell launcher files and the attribute file are explicitly included.
The pre-existing four Rapier import descriptors may undergo their known newline
rewrite, which is retained separately; every other actual source hash must remain
unchanged. Full process argv, including import, binds the recorded original
launcher, project path, headless/display mode, driver and fixture without extra
flags.

The original shader branches, #312/#316 history, all earlier rendering attempts,
and the incomplete first Water rendering invocation remain preserved in the
[integration audit](2026-10-31-palette-shader-integration.md). No production
shader or lifecycle source changes are made in this apparatus checkpoint.

## Registered inventory

| Cohort | Process cases | Required observations |
|---|---:|---|
| Linux visual, two shards | 4 + 4 | Compiler/custody guard; full 132-slot bounded oracle; original material, vapour, Water pixel and Water integration fixtures; original 16-frame accepted-source and selected-full atlases together in the second shard |
| Windows visual, two shards | 4 + 3 | The same six fixtures, with every rendered fixture actually using ANGLE; original 16-frame selected-bounded atlas |
| Linux Main/cache | 2 | One cold and one warm process, each with two complete real Main lifetimes |
| Windows Main/cache | 2 | The same cold/warm pair with actual ANGLE selection and rendered Main frames |

There are **19 process cases, six imports and eight real Main lifetimes** in
six cohorts. Sharding adds no duplicate case or new scientific arm.
The preserved atlas and its exact comparator are unchanged. Linux full-source
parity requires all 16 native framebuffer/PNG pairs to remain byte-exact against
accepted source `adaaa37ae35ffcdaa961b80353be3a23b805c0cc`. This does not assert
that bounded outgoing colour equals the full previous-material finish.

The bounded oracle retains its original 132 outgoing IDs, conditions
`0/128/255`, crossfade fractions `0/0.5/1`, camera translation `(3,2)`, original
colour programme and `2/255` tolerance. Version 2 additionally retains the
independent reference and full-current controls and all camera frames: 24
original framebuffer/PNG images and 24 request/readback records. The reader
recomputes the CPU colour programme and all nine outgoing/midpoint/final and
camera comparisons, including the original image storage precision. It checks
all 1,216 fixture assertions completed. The final cross-host reader compares
the same bounded source across native GL and ANGLE, using the unchanged
tolerance. Each backend must first pass its own independent oracle.

Original material, vapour and Water fixtures keep their existing numerical
oracles and workloads. The apparatus requires their explicit success markers
and original retained images. Water's five frames are independently reduced to
the original lower-half and oriented-right coverage expectations. Missing,
duplicate, skipped or error-bearing completion is a failure even after exit 0.

## Real Main, cache and compiler observations

The Main probe uses the actual Main scene, exclusive native worker, integrated
Play selector, Acrobat rig, one worker, Current policy and main-thread Rapier.
It overrides only focus eligibility for the synthetic fixture. Each lifetime
must acknowledge construction, advance native and Rapier clocks, render actual
frames and retain a nonflat viewport readback, then join its worker and retire
its Rapier session. The second lifetime must reuse the same source-bound shader
resource with the correct backend variant and zero/native or one/ANGLE bounded
define. Worker/session identities must be distinct; instance IDs are opaque,
nonzero signed 64-bit values, preserving valid negative RefCounted IDs. Main construction receives
600 seconds, operations 300 seconds and the whole fixture 3,600 seconds under
the shared policy; each process receives the enclosing 3,940 seconds.

Cold and warm processes share one initially empty, owned cache directory.
XDG, APPDATA, LOCALAPPDATA and Mesa cache variables are explicitly routed
there. The actual Godot user-data path must fall inside that directory. The
runner inventories the real files before/after each process and retains a
separate cold-cache snapshot; cold-after must equal warm-before. At least one
actual Godot shader-cache file must exist. This qualifies those managed caches;
it does not establish that every device driver or resident system cache is cold.

Runtime receipts record the actual engine PID, executable path/hash, engine
build, display server, rendering driver, adapter, source-bound selected shader,
policy and invocation nonce. The Windows observer reads the actual engine PID
and creation identity, then the loaded `d3dcompiler_47.dll` module path and that
file's version, size, file identity and SHA-256. It rechecks the live process
and module after reading. The synchronous OS work runs in a separately owned
helper with the policy's 30-second capture and 10-second termination grace.
An unjoined helper or observer blocks continuation and qualification. Missing,
denied or already-exited module observation is explicitly unavailable. The
file digest is not labelled an in-memory image hash.

All timings describe process execution or Main/draw request to actual readback.
They include other initialization and rendering work and are **not compiler-only
or FXC timings**. There is no new elapsed-time performance threshold. A local
Linux software renderer cannot qualify Windows ANGLE or universal performance.

## Hosted budget derivation

Every preparation cohort gives LFS, the official engine archive and pinned
Python wheels their own 1,200-second allowance. Setup and portable controls
share a separate 300-second allowance, with 10 seconds download cleanup:
`3 × 1200 + 300 + 10 = 3910 seconds`, rounded to 66 minutes.

| Cohort | All execution phases and cleanup | Dependencies | Independent retained readback | Metadata steps and host reserve | Parent |
|---|---:|---:|---:|---:|---:|
| Each Linux visual shard | 213 min | 66 min | 15 min | 4 × 5 min | 320 min |
| Windows visual shard 0 | 213 min | 66 min | 15 min | 5 × 5 min | 320 min |
| Windows visual shard 1 | 179 min | 66 min | 15 min | 5 × 5 min | 290 min |
| Linux Main/cache | 235 min | 66 min | 15 min | 4 × 5 min | 340 min |
| Windows Main/cache | 235 min | 66 min | 15 min | 5 × 5 min | 350 min |

For each process the shared cleanup helper reserves 240 seconds:
`3 × (capture30 + 3 × grace10) + 3 × grace10 + 3 × grace10`. This includes
the generic runner's legacy snapshot helpers, monitor retirement and engine
retirement; these children keep their original actual waits. Every registered
case additionally receives 300 seconds preparation/cache inspection, 41 seconds
observer join and 300 seconds retained readback/cache/exit collection. Thus an
ordinary 1,200-second case contributes `1200 + 300 + 240 + 41 + 300 = 2081`
seconds to its parent; a Main process contributes 4,821 seconds.

Each cohort also includes import `1200 + 240`, one cached telemetry source read
(300 seconds), shared source preflight (300), import receipt handling (300),
shared source postflight (300), internal final readback (900), artifact sealing
(300) and aggregate headroom (600). All Git/archive/version calls inside a
source phase consume its one remaining clock rather than receiving fresh
300-second limits. Nested contexts cannot enlarge the parent. These internal
phases are separate from the workflow's independent 15-minute retained reread.
Linux metadata covers checkout, Python setup,
upload and a separate hosted reserve; Windows adds its pre-checkout exact-text
configuration. Parents round the sum of already rounded stage limits upwards
to ten minutes. The final reducer separately permits six 900-second cohort
readers, 300 seconds cross-backend comparison and 600 seconds aggregate headroom
(105 minutes), 26 minutes reader dependencies and five 5-minute metadata/reserve
allowances, enclosed by 160 minutes. Every job stays below 360 minutes. If policy
scaling exceeds that capacity the planner fails explicitly; inventory must be
split with preserved allowances before such a scaled campaign can run.

## Checkpoint validation and remaining evidence

The 28 portable reader controls pass normally and with Python optimization;
they exercise positive and corrupted retained pixels, missing inventory, wrong
backend/source/policy identity, cache path custody, incomplete Main progress and
retirement, signed instance IDs, altered wait allowances, full process/import
argv, shared phase clocks and complete sequential parent budgets. The separate compiler observer's 13
controls pass normally and with optimization, including actual short, failed
and hung owned helper processes. The independent checkout-custody helper adds
12 controls, passing normally and with optimization, for authenticated root and
nested attributes, actual launcher CRLF forms, mixed endings, content changes,
unknown transformations and unsafe paths. These controls do not substitute for rendered
execution. Godot 4.7 actually completed the 27-assertion compiler/custody guard
and parsed the new Main probe. Workflow YAML, embedded Python, Bash syntax and
the hosted-provider checker pass.

The first integrated local attempt used commit
`644e53e5bb893ccbd4c242e12e3d82e9d918c26c`, tree
`2b55eb567c0300af7724f2466e02e0671cfe935c`, before this review follow-up. Its
canonical source archive SHA-256 is
`3c96a3a62e81e5c2ba5bddf294ad4d4e407809b444fd6fce9685a26f9c226227`.
On Linux llvmpipe (LLVM 20.1.2, 256 bits), all eight original visual process
cases and the independent sealed readback passed. The bounded oracle retained
24 images, covered all 132 slots, and reduced to maximum RGBA error
`0.0003662109375` and camera error zero. The full-path atlas pair passed all
16 byte-exact frame comparisons. The complete 425-file visual manifest is
retained at `shader-qualification-evidence/linux-visual-attempt1/manifest.json`,
SHA-256 `af3c502f0cb7c47a5408258e280d4286e701c46b40c4b466f6464d5d34389dc4`.

The first cold/warm Main attempt on that same source remains **failed**:
both engine processes completed 27 assertions with zero fixture failures, two
joined workers and two retired sessions each, but the reader incorrectly
required positive instance IDs. The actual worker/shader IDs were valid negative
signed integers. The follow-up accepts opaque nonzero signed 64-bit IDs, retains
their exact equality/distinctness requirements, and adds adverse controls.
Its original 180-file failed manifest remains unchanged at
`shader-qualification-evidence/linux-main-attempt1/manifest.json`, SHA-256
`fe1fd67f7d04f7371ffeac0a6348ef2d0f9404123122bac7257b5fe2eae3e5f4`.
Neither original attempt is relabelled as execution of the later source.

Full source-matched Linux and Windows runtime campaigns, complete retained
readback and the final six-cohort comparison remain required. The workflow
preserves failed/incomplete originals and includes only its owned evidence
directory when uploading hidden cache files. No local Windows execution,
hosted success, physical-device behavior or merge acceptance is claimed by this
registration.
