---
title: LCB-005 standalone IN adapter qualification
status: Current
document-kind: evidence
scope: Local Windows x86_64 standalone IN readback and explicit factory geometry at native base 028fc7b6 plus a fenced three-file adapter delta; retained failures, unchanged native inputs and pending published/full-host/platform acceptance
canonical-for: [lcb005-standalone-adapter-evidence]
last-reviewed: 2026-10-25
related-documents: [../architecture/inertial-cellular-v1.md, ../architecture/liquid-solver-family-policy.md, ../reference/interfaces-and-message-contracts.md, ../reference/configuration-reference.md, ../reference/validation-evidence.md, 2026-10-24-lcb005-native-brine-checkpoint.md]
---

# LCB-005 standalone IN adapter qualification

## Source and qualification boundary

Native base is `028fc7b6893a57ca816b5221ce1b9067f0c2c01d` on
`codex/lcb005-inertial`, draft PR #250. Native kernel, policy, codec, fixtures
and their previous full140 LLVM/MSVC evidence remain unchanged. This checkpoint
adds standalone Godot adapter bindings, an explicit legacy factory geometry
argument, a corrected obsolete refusal, a direct regression, focused docs and
the source-derived scenario registry reconciliation inherited from the IN matrix.
It imports no #201 cache work or #202 prepared-token/UI/editor implementation.

The compiled changes are exactly `cyber_native_cell_world.hpp/.cpp` and
`cyber_demo_bridge.hpp`. Raw source SHA-256 values and the complete patch are in
`C:/Users/_/.codex/tmp/lcb212-standalone-adapter/strict-local-scope/`.
Compiled patch SHA-256 is
`5c261d3e6d1e397e0152b4c8fc1fa1a94ef6ee19483e361e6a26f546ab679027`.
The before/after build ledger has123 tracked native/adapter/dependency files;
all remained identical throughout the build and later runtime checks.

The source contract is the [IN reference](../architecture/inertial-cellular-v1.md#standalone-godot-readback-and-explicit-geometry).
This is local Windows headless qualification, not a published release,
Linux/browser run, full application integration, owner feel or full #212 closure.
The outer native-v1 typed receipt remains separately qualified; the older
dictionary run identity does not supply verified host provenance.

## Actual adapter behavior

- Hash/save version getters use the actual World instance:2 for non-IN,3 for IN.
  Applied policy readback copies actual damping0..16/16, effective extension
  identity and execution radius. Validation labels policy-derived predictions.
- `inspect_inertial_cell` copies vx/vy/ax/ay and availability/material/family
  values. Returned dictionaries cannot mutate native authority or saved bytes.
- The older dictionary run receipt binds actual version and IN parameter
  identity. The independent test reconstructs its complete length-prefixed
  SHA-256 stream; non-IN fields retain their old stream.
- The legacy factory defaults to radius2 and accepts explicit2/3. IN at2
  refuses before replacing the live World; explicit3 constructs. Default demo,
  tuned, Water Feel, ordinary world and CYSD1 reconstruction reset2. CYPS2/3
  continuation restores its saved policy/geometry, including3→2 replacement.
- The obsolete Brine-IN-unavailable negative is replaced by unsupported
  Brine-IN-cached. Liquid-policy refusal coverage stays11; worker coverage3.
  Pressure cached/dormant and Water IN negatives remain valid on this branch.

No native pool worker calls Godot, no mutable World storage is exposed, and
no family/geometry is substituted silently.

## Build, inputs and actual runtime

The separate build used LLVM-MinGW20260826/UCRT Clang23.1.0, C++20 `-O3`,
`-DNDEBUG`, the existing static/undefined-symbol flags and pinned godot-cpp
`101ae38034304346a46ea9ea84ae156d3e860496`. Its checkout was clean. The reused
template-debug static library is66,388,182 bytes, SHA-256
`c99db7aa1b834c6fcb0c8feb23779884691cbd50b799210d8325b48c707155df`.
This is a fresh extension build against the retained pinned library, not a cold
rebuild of every SDK component.

Build completed in41.169/600 seconds with empty stdout/stderr. Result:

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| Local `cybersand_native.windows.x86_64.dll` | 4,433,408 | `40274b11cece64e54bf4163c20e5a99b1b37eab363e2a34fb619f2502b8dec5a` |

Godot is `4.7.stable.official.5b4e0cb0f`. A separate project stages the tracked
Godot files, sibling examples, the canonical parameter vectors and the new
independent adapter fixture. All18 LFS payloads were verified against their
recorded SHA-256 and size before import; only the local extension DLL was
explicitly overridden. Windows Rapier remains the accepted patched payload
`b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7`.
Import passed in5.795/180 seconds with no errors, warnings or skips. Four
Rapier SVG/logo `.import` files changed only in staging; their hashes are
retained and no generated import metadata is committed.

Build receipt SHA-256:
`4f2cd6c084e5dcece699bcb08dcc09bb144d9a63288d4988b4380e7f6715972b`.
The runtime reduction is
`strict-local-scope/runtime-proof.json`, SHA-256
`d2c073ff5ae241e74822b4639ae9371590e9d77ffb52b08c81950bad6b4f7484`.
That receipt retains exact commands, compiler/dependency identities, source and
runtime hashes, staged deltas, per-case logs/results and limitations.

## Executed controls and preserved failures

`test_lcb_inertial_adapter.gd` passes **540 assertions, zero failures**, all six
sections true, in3.257/360 seconds. Sections are `oracle_parameters`,
`instance_readback`, `radius_transaction`, `mixed_workers`,
`cyps_continuation` and `default_preservation`. The source fixture
`inertial-adapter-parameters.json` has SHA-256
`25b99a84f4c122e6a281f24d26f0211c962eaf824d1c90d2244b065228fcf6bd`.
It uses the independent Python policy/parameter byte specification for all17
actual values and the twelve retained accepted/refused native examples; no
native executable supplies its expected policy hashes or extension digests.

Four separated mixed rooms run actual FreeMass Water/CY Oil/IN Brine, then a PF
Water substitution, under configured1/4 workers with parallel phases observed.
Every completed tick compares the complete native physical hash. A closed
three-cell tube independently forces actual Brine exchanges through Oil and
Water. Water visible+overfill remains48,960 units; whole-cell Oil and Brine
each remain192 cells. Configured workers and a parallel phase do not prove four
distinct participating claimants.

All **twelve retained shared-contract cases** pass, including policy385,
worker29, pressure1,934/twelve sections and all16 WEX body-mask cases. The
unchanged shared publisher reducer independently accepts exact case coverage,
summary/section types, log digests and absence of errors/skips. All staged
script/fixture/runtime fences remain stable. The slowest retained cases are
MicroScenarios81.091s and WEX96.630s; local finite bounds and commands remain in
the receipts. These are scoped local tests, not the full hosted matrix.

The final generated-registry check found the inherited registry still carried
the earlier capability digest and six non-executable Brine/reference rows.
Source-derived regeneration changes only that digest and those availability
fields; no measured arm/status is rewritten. All capability/scenario generators,
registry build, retained reledgers v1–v6,81 registry tests and24 independent IN
contract tests pass. The affected Godot fixture-manifest case then passes26/0
in3.100s and the catalogue passes27 scenarios,774/0 in42.809s against the same
DLL with the final registry staged. Their command/log/input-fence receipts are
retained separately under `registry-validation-v1/` and the two `registry-final`
stage directories; the original twelve-case proof is preserved unchanged.

Two failed test controls are retained:

1. A `PackedInt32Array` constructor was incorrectly used as a GDScript constant.
   The first explicit test load failed parsing. Only the test declaration was
   corrected; the compiled DLL inputs did not change.
2. The first mixed assertion incorrectly required conserved occupied Water cell
   count. Actual fractional Water occupied235 cells (FreeMass) or219 (PF), while
   its exact quantity was already48,960 and Oil/Brine remained192 each. The
   corrected assertion preserves quantity and whole-cell populations as separate
   units. Per-tick native worker parity and the density-exchange controls remain.

## Documentation checklist and remaining gates

The family page owns the physics, instance interfaces and explicit geometry.
The API/configuration/invariant routes record copied ownership and radius2/3
behavior. Roadmap, handover, validation ledger, README and retrieval routes
distinguish branch/local proof from release/full-host acceptance. The new
independent `LCB-IN-ADAPTER-01` question is separate from frozen32 and all126
previous supplementary queries. Prior historical hashes and failures remain
unchanged. Existing physical-law/Cell/ownership ADRs are unaffected; no new
native law, user editor or production default is introduced.

The separate companion-backed `source212-projections` validation mirror is at
the same native base with an exact20-path adapter/test/docs/registry overlay. Its logs
and command receipts are under `lcb212-standalone-adapter/docs-validation-v1/`.

| Check | Result |
|---|---|
| Documentation | PASS:114 documents,225 claims, no errors/warnings |
| Historical M11 | PASS:18 records,28 source hashes; no historical rewrite |
| Provider, LFS and whitespace | PASS; all18 runtime payloads materialized |
| IN damping, Water normalization and typed receipt independent oracles | PASS; existing native artifacts unchanged |
| Capability/scenario/registry derivation, retained reledgers v1–v6 and focused registry/IN contracts | PASS; regenerated capability digest and six Brine/reference availability rows only, with no measured status changes |
| Frozen32 retrieval |20 first,32 top-five, MRR0.7729; unchanged questions |
| Supplementary127 retrieval |97 first,127 top-five, MRR0.8642; all126 prior query strings retained |
| New standalone IN question | Canonical rank2; top-five includes actual parameters/version/geometry, transaction, ownership and local/platform qualifiers; lexical routing is not answer correctness |
| Materialized repository/provenance | Expected failure:18 stale extension source-input entries, nine per OS; no missing LFS or Rapier/pin/documentation errors |

Runtime provenance reports the unpublished source delta and is not bypassed.
Source-matched actual Windows/Linux publication, independent review and the
ready-PR exact-head Documentation/provenance, Native, Godot and applicable Water
gates remain required. PR #250 stays draft. The prepared application host,
verified host envelope, remaining constructors/UI and actual Web remain #202;
joined packaging remains #203.

## Unarmed combined publication preparation

The subsequent publisher preparation adds a branch-scoped LCB-005 workflow,
an isolated configuration of the accepted LCB-001 engine and profile guards.
The shared engine's sole reusable seam is a configurable bundle prefix whose
historical default is unchanged; the same two-line seam is present in #201.
No native/adapter/test/runtime byte changes accompany that preparation.

The new request path remains absent. Normal source edits cannot start a build;
preparation changes exercise only lightweight guards. Arming requires a
separate committed request with the IN/reference plus pressure execution3
union scope, source/workflow/branch identity and exact remote lease. The
eventual frozen #201 source must first be integrated and requalified. Missing
either positive helper refuses the campaign; all fourteen scoped cases plus
import, both six-boolean section maps, exact log digests and no errors/skips
are mandatory on actual Windows and Linux. Existing case and job deadlines
remain unchanged; the two additional cases each have a finite360s bound.

Publication may append only the two canonical native runtime paths and their
two provenance manifests. Complete source/build ledgers, accepted Rapier and
toolchain pins, both target bundles, one exact source parent and an atomic
branch lease remain mandatory. This preparation records no Windows/Linux
publication result and grants no full-application or ready-PR acceptance.
