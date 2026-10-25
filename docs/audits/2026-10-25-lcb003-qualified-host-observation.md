---
title: LCB-003 qualified runtime and host observation foundation
status: Current
document-kind: evidence
scope: Unmerged copied path/current-file and host observation values, scoped Windows native regression and controlled standalone/editor process-module proof; normal owner integration and full source/runtime/host eligibility remain open
canonical-for: []
last-reviewed: 2026-10-25
related-documents: [../architecture/liquid-prepared-setup-and-receipts.md, ../operations/lcb-manual-comparison-ux.md, ../reference/interfaces-and-message-contracts.md, ../reference/invariants.md, ../operations/local-build-and-validation.md, 2026-10-25-lcb003-tower-constructor.md]
---

# LCB-003 qualified runtime and host observation foundation

## Source and completion boundary

Implementation **`4b05a15ebacf4001cdbc1f3eb9154d8899fac177`**, tree
**`021cee32df12afa908d8f89536582dccadfaaf30`**, on
`codex/lcb003-application-host` follows `cc9dbd98` and draft
[#252](https://github.com/techrote/cybersand/pull/252), stacked on partial native
IN #250. Accepted main remains `ec58d919b3d904fbd338eaccc25de35782c41a24` in this
branch's integration. No kernel, native codec, fixture, dependency or committed
runtime artifact changes. One native adapter method plus a GDScript value
collector and focused regression supply the [qualified foundation](../architecture/liquid-prepared-setup-and-receipts.md#qualified-host-observation-foundation).

The method observes Godot's API-reported library path and the current file at
that path. Its labels explicitly leave mapped-module binding unverified. The
separate host schema copies native bytes/digest/qualifications, records actual
extension config and platform manifest/current script files, and keeps caller
values unverified. Pure-value/depth/text/byte capacities refuse explicitly;
signed integer claims retain exact decimal identities. The collector is not
yet carried through normal owner construction/restart. Native outer-v1 remains
qualifications15/eligibilityfalse; host full matched eligibility is also false.

## Recoverable local runtime and input seal

The non-release Windows x86_64 DLL is **4,678,656 bytes**, SHA256
**`5ab791f5a89d752d3528c3d8e28d10a156ff73d4bac6bc6a2aaca527c9dda24b`**.
The final build completed **43.422/600 seconds**, LLVM-MinGW20260826 /
Clang23.1.0 UCRT, C++20/O3/NDEBUG, pinned godot-cpp
`101ae38034304346a46ea9ea84ae156d3e860496`, `SOURCE_DATE_EPOCH=0`, `LC_ALL=C`,
`TZ=UTC`. Godot is `4.7.stable.official.5b4e0cb0f`; retained Rapier remains
the pinned Windows artifact. All124 native/binding build inputs captured before
compilation remained unchanged after build and at seal. The build ran from
`cc9dbd98` plus the exact header delta committed in `4b05a15e`.

Scratch root **`C:/Users/_/.codex/tmp/lcb202-host-evidence/`** retains build
command/environment/log, before-build inputs, test/probe records and raw logs,
helpers, both scratch editor projects and the staged normal project. The seal
compares594 Godot inputs,19 sibling example inputs and one parameter oracle
with implementation source. This source manifest was captured **after tests,
at seal**; it is not relabelled as a before-test capture. Staged input comparison
allows the separately recorded generated import metadata and actual local DLL.

- `CHECKPOINT.json` SHA256:
  `51cc3dbc56f01ecfafc76c05afbc386f9c44089228378dade82f055e3956db70`.
- `MANIFEST.sha256` SHA256:
  `c567731b002f9d3cf818563b6f32282bb5b1606532bf246b70ff3979c8eafce2`;
  99 retained evidence entries. It excludes generated project trees, whose
  source inputs and deliberate editor-plugin/config deltas have separate scope.

This root is sealed; subsequent work must use another root. Earlier integrated
and Tower seals remain unchanged, including their historical retention correction.

## Scoped regression

Command shape is `Godot_v4.7-stable_win64_console.exe --headless --path
<staged-project> --script res://tests/<case>.gd`; each process has180 seconds.
All four final processes exited0 with no engine error/warning lines.

| Case | Assertions | Seconds |
|---|---:|---:|
| `test_liquid_host_evidence` | 34 | 1.297 |
| `test_liquid_prepared_host` | 72 | 11.406 |
| `test_liquid_tower_host` | 41 | 17.719 |
| `test_liquid_inertial_host` | 305 | 16.125 |

The new test uses actual native construction and its typed canonical bytes. It
checks actual path/current SHA/size, stale publication mismatch, immutable host
value/bytes, deterministic canonicalization, exact signed identities and clean
refusal of missing/corrupt metadata, changed native-v1 qualifications/eligibility,
objects, nonfinite values, non-string keys, excess depth/text/container capacity.
Caller completeness/runtime/eligibility claims cannot replace actual observations.
The three retained host cases cover construction fences, ordinary Tower and
actual IN/physical owner behavior against this newly built adapter runtime.

## Controlled standalone and editor observation

The pinned Godot implementation returns the extension loader's path through
[`_get_library_path`](https://github.com/godotengine/godot/blob/5b4e0cb0f/core/extension/gdextension.cpp#L701).
The loader requests temporary copies for
[editor execution](https://github.com/godotengine/godot/blob/5b4e0cb0f/core/extension/gdextension_library_loader.cpp#L176).
The Windows implementation loads a prefixed temporary file while returning
the original resolved path; see
[`OS_Windows::open_dynamic_library`](https://github.com/godotengine/godot/blob/5b4e0cb0f/platform/windows/os_windows.cpp#L443).
Thus `reloadable=false` does not make the API path an editor mapped-module hash.

Independent PowerShell OS-module enumeration ran at explicit process barriers.
The launcher verified the actual Godot child's parent PID before querying its
modules. It hashed staged/current mapped files before release and the original
file again after completion. This observes current files and module paths; it
does not hash mapped memory or establish a general future-execution guarantee.

| Final probe | Bound | Seconds | Observation |
|---|---:|---:|---|
| `probe-standalone-v5/record.json` | process60s/module-query10s | 1.875 | API path equals OS module path; focused test35 assertions including barrier |
| `probe-editor-plugin-v3/record.json` | process75s/module-query10s | 8.578 | Real editor MainLoop loads `~cybersand_native.windows.x86_64.dll`; API reports original |

Both final probes exited0 without engine errors/warnings, passed eight scoped
process/file assertions and retained unchanged original/current mapped-file SHA
`5ab791f5...`. The editor uses a scratch-only EditorPlugin/config delta rather
than replacing the editor SceneTree. These harness sources are retained. Neither
probe changes the qualified host record's eligibility or claims publication.
The actual retained manifest declares DLL SHA `89a20e5b...`, so its comparison
with this local DLL is correctly false; no fabricated matching manifest is used.

## Retained failures and acceptance gaps

The first ready-file probe read JSON before the writer closed it; an explicit
completion marker repairs the barrier. The console executable launches a Godot
child, so its PID was initially wrong; the repaired probe verifies that relation.
The custom `--editor --script` SceneTree probes confirmed the shadow path but
emitted editor shutdown RID/object warnings, with one aborted scan. They remain
failed clean-execution harnesses, superseded by the real editor-plugin probe.
The first generated plugin contained a stray `+`, failed parsing and was stopped
by terminating only its owned editor process; the corrected plugin passes.
Original logs/records remain present. The earlier43.266-second method build with
less precise labels was superseded before accepted runtime tests; its build
metadata remains under `before-observation-labels/`.

Normal owner integration must stage and bind complete recipe/actor/body/equipment
and execution identity, retain it through restart, and preserve old values on
refusal. Matching Windows/Linux publication, full exact-head suites, actual
compat/threaded Web, remaining constructor rows and complete host eligibility
remain open. Brine IN does not qualify Water-IN or satisfy the distinct GateD
four-controlled-Water-model requirement; Water-IN remains unsupported. This
foundation closes neither #202 nor any full-programme gate.

## Documentation and checkpoint checks

The companion-backed validation mirror uses implementation `4b05a15e` plus the
13 documentation files of this checkpoint and the established five parent
workspace fixtures. `check_docs.py` passes114 canonical documents/225 claims;
historical `check_m11_consistency.py` passes18 records/28 source hashes without
working-tree comparison. CI provider policy passes. `check_repository.py`
correctly refuses the18 stale Windows/Linux source-sensitive runtime inputs
(nine per platform); this checkpoint neither rewrites their provenance nor
supplies new published binaries.

The frozen32 retrieval queries remain unchanged and return32/32 canonical top5,
19 top1, MRR0.7573. The separately reported133 supplementary challenges return
133/133 top5,104 top1, MRR0.8734; new LCB16 ranks1. These are lexical retrieval
results, not independent answer correctness. Its source-backed expected facts
were reviewed against the method/collector/test and controlled probe scope.
Canonical architecture, API/lifetime, capacity, invariant, roadmap, build/test,
user-control, onboarding/index and corpus routes change together; this dated
audit is explicitly excluded from ordinary retrieval. No ADR/default/Cell ABI
decision changes. LFS/whitespace checks are recorded with the final docs seal.
