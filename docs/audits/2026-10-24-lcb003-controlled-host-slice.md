---
title: LCB-003 controlled application-host preparation checkpoint
status: Current
document-kind: audit
scope: Dated unmerged first application-host slice, native preparation/token and copied-receipt boundary, deterministic worker fences, Windows headless normal-controller execution and explicit remaining #202 gates
canonical-for: []
last-reviewed: 2026-10-24
related-documents: [../architecture/liquid-prepared-setup-and-receipts.md, ../reference/interfaces-and-message-contracts.md, ../operations/local-build-and-validation.md, ../reference/status-and-roadmap.md, 2026-10-24-lcb001-residual-shared-contract.md]
---

# LCB-003 controlled application-host preparation checkpoint

## Source and recoverable scope

This is **unmerged source preparation**, not full #202 or release acceptance.
Branch `codex/lcb003-application-host` starts at the frozen #246 head
`9e91a9f75d47b9a9aa4a8ba2d3ce78ba2fbfd882`. The implementation checkpoints are:

| Commit | Scope |
|---|---|
| `6a34c09fedc832fffce32b6b93131cca054e87ea` | Adapter-owned native candidate/token/receipt, explicit normalization, actual desktop and synchronous application routes, deterministic owner fences and regressions |
| `af76354072a485b69398fc2e99924b088a606c55` | Restore prior application mode when a proposed replacement refuses |
| `7d8000b6c80003a24df1321b29c519ccc5bfcf37` | Distinguish an installed apparatus/observer fault from transactional refusal; retain final captured execution settings |
| `130069f158a18f2cf188934c19c83f13aee2f98f` | Scope installed-fault acknowledgement to controlled preparation and preserve the ordinary-host return contract |

The native World, prepared builder, normalization law and receipt codecs are
unchanged. New implementation source is
`godot/native_extension/cyber_prepared_liquid_world.hpp`, adapter bindings/state,
the existing MicroScenario host/worker and the two normal application
controllers. The [canonical host contract](../architecture/liquid-prepared-setup-and-receipts.md#controlled-application-host-preparation-slice)
owns interfaces, lifetime, invariants and qualification. No retained library,
dependency pin, Cell ABI, ordinary default, physics law or generated registry
changes in these commits.

## Construction and lifecycle result

Fixed, actor-free schema-2 MicroScenarios accept explicit current, whole-cell
Water or pressure policies through the actual existing owners. Native preparation
resolves all rectangle/nonzero-fill overwrites first, then executes the shared
builder and optional `water-normalize-v1`. Normalization is never inferred from
the selected family. Reset retains the accepted policy and explicit option.

One adapter-owned slot retains the candidate World, preallocated render exchange,
final setup and copied native receipt. Only an opaque one-use token is returned.
Preparation and native refusal leave the live World, masks, stored quantity,
generation, applied receipt and host event cursor intact. A newer preparation,
discard, live edit, selected execution change or token replay prevents commit.
The worker's actual swap is under its queue mutex, fenced by the current
owner-issued request revision, reset and stop. Same-definition supersession is
still supersession. No native World pointer reaches GDScript.

Native facts are captured after final fixed interest, cadence selection and
adhesion have been prepared. The controlled host does not reapply these settings
after capture. A nondefault region/cadence/adhesion regression compares the actual
complete native hash with the captured receipt. Readbacks copy the original
native canonical bytes, hash, qualifications and normalization counters/digests;
consumer mutation cannot reach later owner publications. Native-v1 full-match
eligibility remains false, with all setup/source/runtime/host qualifiers retained.

**Installed fault versus refusal:** once controlled native commit succeeds, host
`install` returns true. A subsequent initial-observer/apparatus failure belongs to the
newly installed session and is published through `summary.failed`, error/status
and an applied acknowledgement. It never returns a construction refusal claiming
the old World was retained. Current valid bounded native cell observations
succeed; a test observer subclass injects the existing fault branch after a real
commit, including actual worker acknowledgement. The existing ordinary-host
failure return contract is separately preserved and tested; this correction is
scoped to the new controlled route. This is deliberate fault
injection, not an observed platform failure.

Construction-only measured x64 layout: staging tuple **6 bytes** per slot,
**6 MiB** for the fixed 1024² map; final native tuple **24 bytes**, at most
**24 MiB logical payload** before vector capacity. `NativeFactValues` is
46,256 bytes and `WorldConfig` 39,856 bytes in the LLVM-MinGW build. Retained and
candidate Worlds, map/input vectors, captured facts, render exchanges and copied
receipts overlap during preparation. Total peak process memory and construction
latency are not qualified here. There is no new tick-time staging allocation.

## Local Windows runtime evidence

Evidence is retained outside Git at
`C:/Users/_/.codex/tmp/lcb202-host-slice/`. The final native build uses the recorded
compiler argv in `build-final.json`, C++20/O3, 600-second build bound, pinned
godot-cpp `101ae38034304346a46ea9ea84ae156d3e860496`, LLVM-MinGW 20260826 /
Clang 23.1.0 UCRT and `SOURCE_DATE_EPOCH=0`. Native source/bindings and dependency
inputs were sealed before and after build. The native build completed in
**44.766 seconds**, exit 0. The final development DLL SHA256 is
`b886b981f9293d9aeaf326134e5468f680c4573e0656ee963822cf0d0c73d59a`.
It is staged only in the scratch projects, never committed as a release runtime.

Godot is exactly `4.7.stable.official.5b4e0cb0f` on Windows x86_64. The desktop
Rapier DLL retains main's qualified cooperative-BVH artifact
`b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7`.
The final immutable `checkpoint-project` contains the tracked Godot inputs at
`130069f1`; source manifests and per-process command, timeout, elapsed time,
exit/error checks and stdout hashes are retained. The native artifact was built
at `af763540`; subsequent commits change only GDScript/test classification, so their native
build inputs remain identical.

Final proof capsule `CHECKPOINT.json` SHA256:
`68d2621d11bf85815c90767d10461d1757865aa082ed978f6b7937d3e90cd77f`.
It verifies all **119 native/binding/dependency inputs** against the sealed
build inputs and all **564 tracked Godot inputs** against the final committed
source. The scratch project has the declared development-DLL override and four
Rapier SVG/logo `.import` metadata files regenerated by Godot import; their
before/after digests are explicit. No authoritative source input changes across
the final execution. `MANIFEST.sha256` is
`8ee88cb566889627f9290a0202fada58f40726b1a4566084fc4062e9ce0412c2`.
The DLL is 4,544,000 bytes.

The focused `test_liquid_prepared_host.gd` passes **72 assertions, 0 failures**.
Its 240-second process bound covers native gross/net normalization at 8 and
3 mass bits, final overwrite/zero-fill semantics, canonical-byte hashes and
copy isolation, native attempt identity, token replay/supersession/discard,
retained live edit/execution selection/body-mask state, host cursor preservation,
actual same-definition/reset/stop barriers, post-commit observer-fault
classification and both actual normal application controller routes.

Retained companion regression scope:

| Case | Outcome | Process bound |
|---|---|---|
| Native policy handshake | 385 assertions, 0 failures | 360 s |
| Threaded policy owner | 29 assertions, 0 failures | 360 s |
| MicroScenario harness | 8,855 assertions, 0 failures | 360 s |
| Native observation | 100 assertions, 0 failures | 240 s |
| Workbench lifecycle | 15 assertions, 0 failures | 360 s |
| Water Feel controller | Transactional rejection/body isolation/desktop+synchronous blind lifecycle and all 10 deterministic exit acknowledgements pass | 360 s |
| Godot editor import | Exit 0, no engine errors/warnings | 180 s |

The app tests exercise the ordinary `main.tscn` asynchronous owner and
`web_main.tscn` synchronous controller under **Windows native Godot**. They do
not establish Wasm/browser runtime, interaction/rendering feel or all-platform
acceptance. The native suites themselves remain owned by residual #200's
separate exact-head gates; this slice changes no native kernel.

The final 72-assertion case takes **10.109 seconds**; its stdout SHA256 is
`035540ba825976f1f0ee5bda0e53219a0f991f39ee0412598ea7589929249877`.
The companion harness takes 89.688 seconds and the remaining cases retain
per-process timing in `checkpoint-focused-regression.json`. All eight final
processes exit zero with no engine errors/warnings. This is a finite source
checkpoint proof, not a target-hardware performance qualification.

## Documentation and provenance checks

The isolated check mirror uses the five expected companion-workspace files from
the existing validation fixture; it does not alter the unrelated working
checkout. Documentation passes (112 selected documents, 220 canonical claims),
historical M11 integrity passes (18 records, 28 historical source hashes), and
LFS integrity, provider policy and whitespace checks pass. Frozen retrieval
remains 32/32 top five, 20 top one, MRR 0.7729. The separately expanded challenge
set is 127/127 top five; the new LCB10 host/fence question ranks first. The
original 32 and prior 126 queries were not tuned.

Current repository provenance **correctly fails** with six rebuild errors:
the three changed existing adapter inputs for each retained Windows/Linux
runtime. The new helper header is also covered by the publisher's dynamic
native-extension input enumeration. The scratch development DLL does not fix
retained release manifests. Source-matched publication and its exact-head
execution gates remain required; no stale provenance check is waived.

## Preserved failures and evidence boundaries

The first test-harness attempt called an unavailable `PackedByteArray.sha256_text`
method: four test assertions failed. It is preserved as
`test-liquid-prepared-host-v1.log`; the regression now uses Godot's independent
`HashingContext` SHA256 over the original copied bytes. Later 42/54/64-case
iterations and the 71-assertion review correction remain retained separately
from the final 72-assertion source.

An intermediate compiler succeeded while staging onto an executing scratch
project was refused by Windows' DLL file lock. No library in use was replaced;
staging completed after that test process exited. The final acceptance snapshot
uses a new immutable project directory with its own before/after input fence.
Intermediate working-project executions are preparatory evidence, not that final
sealed-source proof. No failing test, runtime publication or old artifact is
silently reclassified as passing final acceptance.

## Remaining #202 work and integration gates

This checkpoint supports only fixed actor-free schema-2 MicroScenarios through
the explicit controller API. The comparison entry point, family pickers/presets,
all normal-application constructors, Water Feel integration, actors/equipment
staging, exploratory edits/import, protected comparison exhibition and real Web
execution remain to implement or qualify. Unsupported first-slice routes refuse
before replacement; the legacy routes retain their existing behavior.

Native registered-definition collection remains host-unverified. Source/runtime
claim verification and any stronger host proof require their own honest envelope;
the frozen native-v1 eligibility flags cannot be upgraded by GDScript. Current
native/canonical hash2 bytes remain unchanged. Integration with #212 must use its
instance physical-hash-version getter once that API lands.

Before any PR merge: advance to fresh accepted main after #246, integrate the
parallel family changes deliberately, publish source-matched Windows/Linux
runtimes for the adapter source change, run exact-head Documentation/provenance,
Native/GDExtension/scoped apparatus gates and independent review. Actual compat
and threaded browser evidence must use the eventual integrated native source.
The programme remains finish residual #200 → fan out #201/#202/#212 → #203.
