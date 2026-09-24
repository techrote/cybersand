---
title: REM-002 #11 integration forensics and reconciliation
status: Current
document-kind: evidence
scope: Forensic reconstruction and current-main reconciliation plan for F01 / issue #81; bounded generic body↔cellular semantics only
canonical-for: [rem-002-issue-11-integration-forensics]
last-reviewed: 2026-09-24
related-documents: [../operations/development-claims-remediation-programme.md, 2026-09-20-development-claims-closure-audit.md, 2026-09-13-issue-11-repair.md, 2026-09-12-issue-11-reconciliation.md, ../architecture/rigid-body-and-cellular-coupling.md, ../systems/granular-interaction-policy.md]
---

# REM-002 #11 integration forensics and reconciliation

## Scope

This is the required forensic-first record for issue #81 / REM-002 under parent
#79 / REM-000. It resolves why the bounded 2026-09-13 #11 repair is absent from
current main, classifies every acceptance-critical historical source change, and
defines the narrow current-main implementation that may be restored/adapted.

It does **not** claim production-quality body↔granular gameplay. REM-004 / #83
owns that broader acceptance after this baseline is reconciled.

Authoritative main at REM-002 intake:

`7e17007f15eaa2ac090b9d50eb6bf3140d411dde`

Historical #11 identities:

- repair branch: `codex/issue-11-repair`;
- branch reconciliation checkpoint:
  `76ac3f7b137001c59862fa573fb113dbe349f5fe`;
- primary bearing/masked-source/barrier repair:
  `d22ad88d621a9c0c58736ecac5a8a91bd21c23af`;
- final narrow repair code checkpoint:
  `f8720d331e653ff40c12149dc1b7164724accd9f`;
- evidence/docs commit:
  `d5f0de687283ec366ed4ff33160a274e2a35ddc6`.

Historical evidence remains immutable.

## Divergence mechanism

The #11 repair was **never integrated into authoritative main**.

Evidence:

1. `f8720d3` is exactly two source commits ahead of its branch checkpoint
   `76ac3f7`.
2. Comparing historical `f8720d3` to current main reports divergent histories
   whose merge base is
   `f3fb9de2c6e62907b07b50c7036af389da67d4a5`.
3. The branch `codex/issue-11-repair` still exists.
4. GitHub reports **no pull request at all** whose head is
   `techrote:codex/issue-11-repair`.
5. The historical evidence commit `d5f0de6` is a direct child of `f8720d3`;
   it records branch-local acceptance rather than a merge identity.
6. Current main still contains the pre-repair observable semantics:
   - masked stored Sand under a transient body mask is characterized as producing
     proxy-derived contacts;
   - ejection target selection checks endpoint emptiness without the historical
     path/foreign-mask rule;
   - no granular bearing accumulator exists in the native or interpreted coupling.

There is therefore no evidence-supported "landed then regressed" commit to name.
The correct F01 classification is **historical bounded implementation never
integrated**, not later accidental code loss.

## Current runtime identity

Current retained CyberSand GDExtension runtimes are source-matched to the later
WEX-004 source `66a2935e1001737e63ecb03fd21050f7d433bda7`.
Their manifests bind the current runtime source-input hashes and were repeatedly
accepted by the repository provenance checker on current main.

Linux retained runtime:

- `godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so`;
- SHA-256
  `58eca0792f067a2706c5a9d1a01f52226cd7e7e0b4118fc0229ebcddc1d4064e`;
- actual Godot/Linux regression execution exists.

Windows retained runtime:

- `godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll`;
- SHA-256
  `cccc4a5dea7bc7d5dbf2e61f44cbbbaf79d9f02fa8605171cd3efdf2b11eef5f`;
- current evidence is cross-build only.

These runtimes correctly represent the **current missing #11 semantics**. Because
REM-002 changes tracked native/GDExtension inputs, both retained runtimes and their
provenance must be republished from the accepted REM-002 source. Old bytes must
not be relabelled.

## Historical source-change disposition matrix

| Historical change | 2026-09-13 result | Current-main intake | REM-002 disposition |
|---|---|---|---|
| Stored source authority under transient body mask | `World::update_cell` refused cellular kernel execution under a body mask; rule dispatch also carried stored source identity rather than re-reading the Wall proxy | Missing; current characterization still expects 3 proxy-derived contacts/raw y=4800 | **Adapt/restore**. Preserve current INT-000/kernel logic; change only source-authority dispatch and masked-source refusal. |
| Support query ignoring transient body proxy | `granular_support_at(..., include_transient_obstacles=false)` and fallback equivalent read stored material | Missing | **Adapt/restore** for body bearing only; sampled-player default remains unchanged. |
| Paused active grains outside selected simulation region cannot bear load | Historical final fix rejected active-but-excluded grains while sleeping grains remained eligible | Missing | **Adapt/restore** against current phased scheduler/selected-region state. |
| Hard-surface-aware ejection path | Candidate endpoint plus bounded half-cell path rejected intervening hard terrain | Missing; current thin-floor fixture still characterizes crossing | **Restore**. |
| Foreign-body-aware ejection path while own mask remains traversable | Final `f8720d3` passes source body ID and rejects any other transient body ID on path | Missing | **Restore**. |
| Native granular bearing | Bounded exposed-downward samples; #10 support predicate; yielding impulse; capped low-speed correction; no support cache | Missing | **Adapt/restore** with the existing 9-float result ABI and current native storage types. |
| Interpreted/fallback granular bearing | Mirrors native narrow semantics | Missing | **Adapt/restore** so fallback/current Godot interaction semantics do not disagree. |
| Diagnostics: bearing/support samples | Appended diagnostic fields only; production result ABI unchanged | Missing | **Restore** as bounded diagnostics; update current characterization indexing safely. |
| Native masked-source regression | Expected retained Sand, body mask available, zero proxy contacts/impulse | Reverted to old characterization | **Replace current characterization with observable regression**. |
| Thin-floor and foreign-body ejection regressions | Retain complete Water payload and report unresolved overlap | Thin-floor test currently expects crossing; no foreign-body control | **Replace/add observable regressions**. |
| Excluded-active-grain support regression | Rejects paused active grains outside region | Missing | **Restore**. |
| P4/P5 physics-characterisation tooling | Added issue-11 ordinary/support-loss scenarios and bearing diagnostics | Historical runner has evolved; old exact file edits are not current authority | **Do not cherry-pick wholesale**. Add a focused current regression/characterisation path sufficient to prevent semantic disappearance; REM-004 owns broad envelope expansion. |
| Historical docs claiming #11 current | Accurate only on the unmerged branch | Not current-main truth | **Do not restore as current historical claim**. Preserve old audit; publish this forensic record and update Current coupling/remediation docs after implementation. |

## Narrow implementation contract

The current-main repair retains the historical bounded architecture rather than
replaying old code mechanically.

### Ownership

- native cells remain sole material owner;
- transient body occupancy remains a derived collision/observation field;
- main-thread Rapier remains sole rigid-body motion/contact owner;
- no powder Rapier collider, body-specific material owner or soliding aggregate is
  added;
- bearing is a cellular coupling result, not a second rigid-body solver.

### Masked source

A stored material cell beneath transient body occupancy is reconciled by the body
overlap path and does not execute a normal cellular material kernel using the body
Wall proxy as source/contact authority.

### Ejection

A bounded ejection destination is legal only when:

- the endpoint is in bounds and stored-empty;
- the half-cell path does not cross stored hard terrain;
- the path does not cross another transient body's mask;
- the source body's own mask remains traversable.

If no path exists, retain the complete source payload and report unresolved
overlap.

### Granular bearing

For exposed downward body raster cells:

- query the existing #10 support-capable/packing predicate against **stored**
  material rather than the body proxy;
- active work paused outside the current selected simulation region is not settled
  support;
- recompute support from current cells each accepted sample; no support cache;
- retain the historical bounded yielding load response/caps as the narrow control,
  not a production calibration;
- low-speed positional correction may only undo bounded just-observed downward
  travel;
- result ABI stays 9 floats; bearing is folded into the cellular impulse/correction;
- liquid and hard-terrain controls remain distinct.

## Explicit non-restorations

REM-002 will not restore historical branch changes that are only broad harness
convenience or old current-status prose. It will not:

- claim the historical P4/P5 envelope is owner-accepted final gameplay;
- generalize bearing to arbitrary shapes, crowds, high-energy impacts or long
  publication delays;
- implement torque/fracture/coherent soliding;
- alter Water pressure/head semantics;
- alter INT-000 interaction policy/catalogue;
- absorb REM-004.

## Validation required before merge

Focused observable gates must prove at minimum:

1. masked source produces no proxy-derived cellular contacts and retains payload;
2. thin hard floor blocks ejection with exact payload retention;
3. a foreign body mask blocks ejection while the source body's own mask does not;
4. packed support-capable material creates bounded bearing for an ordinary body;
5. excavation/support loss removes bearing on the next accepted sample;
6. liquid and hard-floor controls remain distinct;
7. current/one-sample-old results remain bounded and stale policy is unchanged;
8. no material duplication/loss or hidden body/material dual ownership;
9. ordinary native tests, sanitizer/TSan, GDExtension/Godot and docs/provenance pass;
10. retained native runtimes are regenerated from the accepted source, with Linux
    runtime execution and Windows evidence described only at the level actually run.

## Executed current-source evidence

The implementation source was frozen at:

`df54e927022c464e0da4f41602b2a6e10e1e6075`

with Git tree:

`2275c63002ad375d9d005e07bdb8a5304b48f9d6`.

The pull-request synthetic merge used for Linux GDExtension execution was
`fe8efdb704641bc26930aa0f090430b5fa9715c7`; its tree is byte-identical to
the frozen source tree above.

### Exact-source validation

- Native C++ validation **36046243938** — **success**. The suite includes the
  normative masked-source/stored-support assertions, ordinary behavioral and
  integration coverage, soliding/Stage-3B guards, ASan+UBSan, the dedicated
  sanitized soliding path, TSan, shared-library build and benchmark.
- GDExtension/Godot **36046243935** — **success**. Linux and Windows x86_64 builds
  passed; all four isolated Linux Godot regression shards passed on one exact
  Linux runtime artifact.
- Issue-49 Water apparatus-v2 **36046243988** — **success**, including adversarial
  apparatus checks, sanitized harness and the preregistered Current-Water
  baseline. REM-002 therefore did not silently alter the separate Water-head
  apparatus contract.
- The first Documentation/provenance run **36046243934** failed **only** because
  the tracked Linux/Windows runtimes still described the pre-REM-002 source. That
  was the intended publication stop condition, not waived evidence.

### Focused REM-002 owner-path result

`test_rem002_body_granular.gd` executed in Linux regression shard 1, job
**107792501555**, on the exact staged Linux runtime.

It passed native and fallback support/support-loss controls, Water/hard-terrain
non-bearing controls, age-1 acceptance, age-9 stale rejection and the real
Rapier P4/P5 cases.

Emitted current-source measurements:

| Case | Peak depth | Final depth | Notes |
|---|---:|---:|---|
| P4 one-height, Sand | 3.7484 cells | 0.0000 | 410 support samples; no hard-floor contact |
| P4 four-height, Sand | 6.6518 cells | 1.4718 | within the retained <=8-cell narrow envelope; no hard-floor contact |
| P5 excavation, Sand | 229.3073 cells | 229.0247 | support is removed and the body resumes large downward travel before the deep floor |

The P4 values reproduce the useful historical bounded behavior on current source
to normal floating-point/solver variation. P5 is intentionally a release test,
not a requirement to stay near the former supported surface.

The existing WEX-001 regression was explicitly reconciled in
`df54e927...`: its 2026-09-20 audit remains the historical record that the
then-current source crossed the hard floor, while Current regression semantics now
require zero forbidden-floor Water mass after REM-002's barrier-aware ejection
repair. This is a successor semantic fix, not a rewrite of #91 history.

### Source-matched runtime publication

One-shot GitHub-hosted publication run **36057247186** restored the exact Linux
runtime exercised by run **36046243935**, rebuilt Windows from the same frozen
source, regenerated manifests from the actual bytes, passed materialized
repository/provenance and LFS checks, removed its temporary workflow, and pushed
publication commit:

`009ab2f27040d995ae13d839daa426a0bf17a457`.

Retained Linux runtime:

- SHA-256
  `bfc735dd7380edb00ddebc9100b09455d92b2ae17c4e7fb3d027b415f835e6ca`;
- size **1,617,224 bytes**;
- actual Linux Godot execution: **yes**, all four regression shards in
  **36046243935**.

Retained Windows runtime:

- SHA-256
  `22adb31926895b4b2df7a8e92d8b1101533aaccc91ed9ca2710e92e4946d2a80`;
- size **2,091,008 bytes**;
- actual Windows execution: **no**; pinned LLVM-MinGW cross-build evidence only.

Browser/WebAssembly execution was not newly performed by REM-002. Historical #11
browser results remain historical branch-era evidence and are not promoted to
current-main runtime acceptance.

### Acceptance boundary

This evidence establishes the **bounded generic coupling baseline** required by
REM-002:

- masked stored material remains authoritative;
- barrier/foreign-mask crossing is rejected without material loss;
- current packed granular material can supply bounded bearing;
- excavation removes that bearing;
- liquid and hard terrain remain distinct;
- sample-age refusal remains bounded;
- source-matched Linux/Windows retained runtimes now correspond to the repaired
  native inputs.

It does **not** establish broad arbitrary-body/body↔granular gameplay acceptance,
high-energy/thin-bed/crowded/general-shape support, general torque/fracture, or a
dynamic material↔Rapier ownership substrate. Those remain outside REM-002 and,
where applicable, belong to REM-004 / #83 or #12.

## Downstream

Successful REM-002 completion supplies REM-004 / #83 with a clean current-main
**bounded baseline**, not broad body↔granular acceptance.

It may also improve generic body↔cellular correctness relevant to future #12/WEX
work, but it does not implement the dynamic material↔Rapier ownership substrate
that blocked WEX-002.
