---
title: GEN-003 typed spatial computation and acceptance evidence
status: Current
document-kind: evidence
scope: Dated issue 190 source, analytical and structural controls, adapter execution, runtime publication and exact-head gate disposition
canonical-for: [gen-003-typed-spatial-evidence]
last-reviewed: 2026-10-20
related-documents: [../systems/procedural-typed-spatial-fields.md, ../reference/procedural-spatial-operators.md, ../systems/procedural-world-generation.md, ../architecture/data-ownership-and-lifetimes.md, ../operations/local-build-and-validation.md, ../reference/validation-evidence.md]
---

# GEN-003 typed spatial computation — 2026-10-20

## Authority, integration and recoverable source

[Issue #190](https://github.com/techrote/cybersand/issues/190) owns GEN-003, the
first implementation in the approved GEN-003–007 programme.
[PR #195](https://github.com/techrote/cybersand/pull/195) implements it on
`feat/gen003-typed-spatial-fields`, beginning at main
`4f3685b71366218e82e7c2188e4ecdf27553f4cf`. Intake inspected the repository
guide, handover, roadmap, dependency pins, LFS identities and relevant open
work. Unrelated actor, material, depth and Water programme changes were not
incorporated into this issue.

The first recoverable implementation checkpoint is
`61a5bf2921aac730594de8f49557d293cfbbd9aa`, tree
`afaa2924659ffcef1318a54562a9e726a621b3a6`. It precedes the final analytical,
transport-precision and documentation corrections below. The runtime manifests
identify the later exact build source and all canonical native/build inputs;
neither this checkpoint nor a local test result silently validates later bytes.

Qualified source/docs/publisher checkpoint
`724afcf144d7e22bf511745354b4a9f39520d28f` was followed by the complete-worker-
rectangle regression checkpoint `8356cf78b965105bb115df4100a82f9c147acc58`, tree
`dbfb36b8abb17c69b7f62809921f32af84da9af2`. The latter changes only the integration
test: all 64 chunks and all cells of the reference rectangle are compared across
four workers for each of four typed diagnostic channels. Native implementation,
adapter, examples and authoring inputs remain identical to `724afcf`.

The corrected source checkpoint is
`ba37b41d41b0e42dbfa37238ed69dc6ade517ed5`, tree
`7e898d46da1e1cc014cc4f08a58efb69a41f106d`. It repairs the two Linux ABI imports
and subnormal vector normalization described below, retaining the existing
compatibility-floor gates. The corrected local Linux execution record is bound
to this commit and tree. Earlier full native-suite results and UI captures keep
their original source qualifications.

The [typed contract](../systems/procedural-typed-spatial-fields.md) and
[operator inventory](../reference/procedural-spatial-operators.md) own current
semantics. This audit owns observed results, preserved failures and limits.

## Delivered contracts and acceptance controls

| Requirement | Implementation and independent control |
|---|---|
| Legacy compatibility | Schema 1 / algorithm 2 retains the 22 scalar kinds and original material semantics. All twelve frozen GEN-001 material hashes remain unchanged. Schema 2 / algorithm 3 is explicit; an empty typed graph changes versioned identity without changing material output. |
| Typed values and units | Normalized, signed/general scalar, signed distance, distance-to-feature, double vector, exact categorical tuple and boolean values. Explicit mask conversion; invalid units, arity, ranges, nonfinite inputs and unused declarations reject before publication. Exact categories test signed coordinates beyond double's integer precision and full-width unsigned domains. |
| Geometry and derivatives | Independent quadratic scalar and affine vector fields establish central differences, gradient, divergence/curl, signs, units, extrema and curvature. Circle and box distances establish uniform versus anisotropic transform behavior. Position/vector translation is distinguished; polar origins, log-polar clamps, repeat/mirror seams and bounded warp are explicit. |
| Structured fields | All Peano coordinates through order 5 check coverage, inverse and edge adjacency. A wider 25×25 seed oracle checks Voronoi results; Delaunay tests cover co-circular ties and reciprocal faces. Poisson checks compare wider neighborhoods and pairwise separation. Geometry uses independently known point/segment distances. |
| Discrete assignment | Every one of 256 two-category directional rule sets is compared against an exhaustive 16-assignment oracle, with wrapped and unwrapped grids. Unsatisfiability, exhausted work and scratch limits remain distinct failures. Exact categories do not pass through floating point. |
| Absolute coordinates and multiresolution | Scales 1/4/16/64, negative positions, coarse/repeat/mirror boundaries, derivative halos and admitted coordinate endpoints compare exact typed values. Full rectangles compare different chunk sizes/partitions, random and reversed order, four workers, incremental budget slices, cached and uncached sampling. |
| Reuse and identity | Typed defaults/bindings, nested instances and exported aliases roundtrip canonically. Namespace collisions, missing inputs, cycles, recursive or excessive expansion reject, including unused templates. Parameter changes alter the affected subtree identity; unrelated subtree identity remains stable. |
| Bounded execution and ownership | Preparation charges expansion, solver work/memory and immutable geometry; recursive sampling charges interpolation and stencil fan-out. Caller-owned fixed scratch/cache and allocation counters establish no successful per-sample heap growth. Cancellation, failed evaluation and stale/tampered receipts publish no partial material or diagnostic packet. |
| Adapter and authoring | Double diagnostic arrays, exact string-encoded category triples, copied packets, typed metadata and transactional configure errors are exercised through Godot. The Workbench adds a typed JSON tab, inferred output inspection and explicit normalized-mask selection. Five executable examples cover every required operator family. |

The schema-2 graph has no live World or initial-proposal context access. Existing
GEN-002 fields retain their immutable captured context. Material overrides remain
the final authority. The assignment implementation is the reusable field/solver
boundary for GEN-004, without introducing a second grammar-owned solver.

## Native execution and preserved failures

The full-suite results in this subsection were recorded at the pre-correction
checkpoints `724afcf` and `8356cf`. The ordinary `make -j2 worldgen-test` gate
passed seven suites: generation,
fresh-chunk installation, legacy fields, legacy modifiers, typed fields, typed
generator integration and structured spatial helpers. The independent typed
suite subsequently passed **14,156 assertions**, including the final unit-binding,
ignored-Parameter-payload and signed-zero cache regressions. It passed with the
Makefile's C++20 optimized warnings, including `-Wconversion -Wshadow -Werror`,
and independently under ASan+UBSan.

Reproduction uses GCC 13.3.0 on Linux x86_64:

```sh
timeout 5m make -j2 worldgen-test
timeout 10m env ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1 UBSAN_OPTIONS=halt_on_error=1 make -j2 worldgen-sanitize
```

The pre-correction full seven-suite ASan+UBSan gate passed with exit 0 and no
sanitizer/assertion failures. Its log SHA-256 is
`947ed3445d276dcca5ac8897421ce3365b7a42b2f5c71b6a9eba1e3ddde19db6`.
After strengthening the worker control, all seven optimized suites were run
again and the changed integration binary was rebuilt and passed under ASan+UBSan.
The `8356cf` optimized execution log is
`5d0a4ac915e44065b8ade6bc33941b2d17f3df90a77874dc43c9eeb3bca954f4`;
the `8356cf` integration sanitizer log is
`b922fd85ba8f7d8f5100be5b78180e09e78caee940142dccebd1e440d2070ad6`.
LeakSanitizer's process inspection is unavailable in the restricted local
environment. The repository's generation harness uses `detect_leaks=0`;
these results establish address/undefined-behavior coverage and do not claim
leak detection.

The corrected typed/structured regressions are recorded in the ABI-correction
section below. The earlier seven-suite runs remain evidence for their named
pre-correction inputs; they are not a full-suite execution claim for `ba37b41`.

| Review finding or failed control | Resolution and retained regression |
|---|---|
| Repeated-coordinate cancellation and negative repeat/mirror boundaries | Bounded remainder arithmetic with explicit local interval ownership; analytic negative and very large coordinate checks. |
| Extreme affine distance qualifications and tiny-gradient curvature | Conservative singular-value qualification and normalized-gradient curvature avoid unsupported exact-distance claims and underflow; independent numerical cases check both. |
| Empty/nested unused declarations could hide excessive expansion or ignored data | Shared instance expansion ledger and complete validation of unused declarations; invalid enums, unit overrides, ignored Parameter payloads, recursive templates and excessive instance calls reject. |
| Numeric operator parameter bindings could accept the wrong physical units | Binding units are retained through expansion and checked against the operator's inferred contract, including unused templates and range thresholds. |
| Cached signed zero could differ from the uncached representation | Canonicalize successful floating payload zeros; compare cold, warm and uncached value bits. |
| Godot's default JSON serialization rounded a `1e60` vector and changed canonical identity | Workbench import/export and roundtrip fixtures use `JSON.stringify(..., full_precision=true)`; exact double payload/fingerprint tests distinguish serialization from float32 conversion. |
| A categorical example's 100,000-work solver budget omitted charged scratch initialization | Raise the authored example budget to 1,000,000 while retaining the engine's preparation accounting and explicit low-budget rejection controls. |

No failed assertion, script error, required skip or exhausted operation was
reclassified as a passing run. Earlier fixture assumptions are superseded only
by their corrected, rerun controls.

## Godot examples and inspection

The five schema-2 profiles are
[`typed-industrial-structure.json`](../../examples/worldgen/typed-industrial-structure.json),
[`typed-vector-utilities.json`](../../examples/worldgen/typed-vector-utilities.json),
[`typed-categorical-districts.json`](../../examples/worldgen/typed-categorical-districts.json),
[`typed-reusable-decay.json`](../../examples/worldgen/typed-reusable-decay.json) and
[`typed-multiscale-seeds.json`](../../examples/worldgen/typed-multiscale-seeds.json).
The typed adapter regression loads all five. The
[deterministic renderer](../../tools/render_worldgen_typed.gd) produces five
material/typed-diagnostic image pairs and a JSON record containing graph identity,
metadata and per-chunk receipts. Visualization maps are derived display values;
the native scalar/vector/category payloads retain their declared values.

Local execution uses exact Godot `4.7.stable.official.5b4e0cb0f`, pinned Rapier2D
0.35.2 and a fresh native extension built with the pinned godot-cpp commit
`101ae38034304346a46ea9ea84ae156d3e860496`, SCons 4.10.1, GCC 13.3.0 and GNU ld 2.42.
The official Linux Godot archive SHA-256 is
`0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c`.
Runtime publication below identifies the exact accepted binary separately from
these iterative local builds.

### Earlier `724afcf` local runtime and UI captures

The earlier local Linux rebuild from the `724afcf` native inputs has SHA-256
`32232c4e52bd3dec0e731d791f82239198c5b27bf268ed7c20ec7bba57ce5670`,
2,462,552 bytes. Its hash was verified before and after execution. The established
Workbench regression passed 138 assertions, the legacy field regression passed
271, and the typed adapter/Workbench suite passed 394: all zero failures and
exit 0, without runtime/script/parse errors.

All five native material/diagnostic pairs rendered 2,112 chunks and 245,760 cells.
Three actual 1600×900 Workbench views were regenerated and inspected under
Xvfb/llvmpipe: authoring metadata, scrolled JSON controls, and category inspection
including the exact value `9007199254740995`. Source/runtime/recipe/log/image
hashes and counts are retained in
`build/worldgen-typed/local-validation-724afcf.json`, SHA-256
`c63946f254664bd411f37e8e3f9ce7ed1986ac38febe6814e6c62d7bb86bcafa`.
The only graphics warning was the software driver's unsupported V-Sync toggle.
Native implementation, adapter, scripts, examples, renderer and focused Godot
tests were verified against `724afcf`; the later worker-test checkpoint changes
none of those inputs. These are Linux software-rendering observations, without
Windows or GPU-performance claims. Publication identifies its own artifacts.

## Hosted compatibility-floor failure and correction

[Publication run 39503672713](https://github.com/techrote/cybersand/actions/runs/39503672713)
at `8356cf` built both runtimes. Actual Windows import and all four focused cases
passed: Workbench 138, legacy fields 271, typed adapter 394 and render/generation
23 assertions, all zero failures. Linux failed the existing compatibility-floor
gate before Godot execution: the new `std::hypot` calls imported
`hypot@GLIBC_2.35`, above the required GLIBC 2.34 bundle floor. Independent ELF
inspection also found the new adapter's chained rvalue string concatenation
imported `std::string::_M_replace_cold@GLIBCXX_3.4.31`, above the required
GLIBCXX 3.4.30 floor. Publication correctly skipped; no runtime was published
from this failed run.

The correction retains both gates and the pinned toolchain. Only new spatial
magnitude calls use an internal max-component-scaled `sqrt` helper, avoiding
overflow/underflow and the newer `hypot` symbol. Diagnostic context strings use
copy/append operations with identical text. Production-flag object inspection
confirmed removal of both unwanted imports. Independent magnitude controls
compare ordinary, large, tiny and subnormal vectors against `std::hypot`, within
four representable steps, and retain exact axes and analytic 3–4–5 triangles.

That review also reproduced a distinct numerical defect:
`unit_vector(denorm_min, -denorm_min)` returned `(1, -1)` because its physical
magnitude rounded to one subnormal step. Max-component pre-scaling before unit
normalization fixes the direction without using that rounded physical length as
the divisor. Six new typed assertions cover equal/unequal signed subnormal
components and unit length. Legacy scalar generation and its material oracle
are unchanged. The corrected typed suite passed **14,162 assertions** in both
optimized and ASan+UBSan builds, including tiny-amplitude curvature and the
existing partition/cache/worker/allocation controls. Both typed execution logs
have SHA-256 `090732a500e5f82ff784f235c218df33d602e4236dd93abfbee1c806d484dfd3`.
The structured suite also passed normally and under ASan+UBSan. Source hashes
were checked unchanged through those runs. Final binaries and full acceptance
must use this corrected source; earlier local/Linux and hosted/Windows
observations remain scoped to their recorded inputs.

The combined corrected Linux extension was then rebuilt with the pinned
toolchain and passed the unchanged full runtime-floor check: extension
GLIBC 2.32, bundle GLIBC 2.34 (Rapier), GLIBCXX 3.4.30 and CXXABI 1.3.9.
This checks the linked runtime, independently of the earlier object-level probes.

## Corrected `ba37b41` local Linux execution

The corrected Linux extension was exercised against source
`ba37b41d41b0e42dbfa37238ed69dc6ade517ed5`, tree
`7e898d46da1e1cc014cc4f08a58efb69a41f106d`, using the pinned Godot and Rapier
versions above. Its SHA-256 is
`57529fedcf4e4d2d389bf500c2510962057eb15c862c7c9e9219059f07c82b09`,
size **2,462,560 bytes**. The pre-run source ledger covers 57 native, adapter,
authoring, example, focused-test and build inputs, including the numeric helper
and corrected adapter. Every recorded input matches its published Git blob and
the unchanged working file; the renderer independently records the same runtime
hash and its source/recipe inputs.

Execution used `/tmp/gen003-deps/godot/Godot_v4.7-stable_linux.x86_64` from
the source root. Each focused script ran with `--headless --path godot --script
res://tests/<case>.gd` and `timeout 180`. The renderer used `timeout 300`, the
same headless project options, an absolute `tools/render_worldgen_typed.gd`
script path and `-- --output` pointing to the absolute `build/worldgen-typed`
directory. All four processes ran independently/concurrently with
`XDG_DATA_HOME=/tmp/gen003-xdg-data`,
`XDG_CONFIG_HOME=/tmp/gen003-xdg-config` and
`XDG_CACHE_HOME=/tmp/gen003-xdg-cache`; their captured logs were copied into
`build/worldgen-typed/logs` and hashed in the validation record.

| Corrected local process | Result |
|---|---|
| `test_worldgen_typed.gd` | 394 assertions, zero failures |
| `test_worldgen_fields.gd` | 271 assertions, zero failures |
| `test_worldgen_workbench.gd` | 138 assertions, zero failures |
| `render_worldgen_typed.gd` | Five profiles, 2,112 complete chunks and 245,760 sampled cells; ten material/typed PNGs |

All four processes exited zero with no reported errors or warnings. The renderer
sampled each profile's complete 256×192 region at `[-128,0]`; the retained
manifest contains typed metadata and one material/receipt hash pair for every
chunk. The three 16-cell profiles each produced 192 chunks and the two 8-cell
profiles each produced 768. The local review verified the complete chunk-coordinate
sets, recipe hashes, ten PNG hashes and all four execution-log digests.

| Retained local evidence | SHA-256 |
|---|---|
| `build/worldgen-typed/local-validation.json` | `138ce8f8972758795ac1016b1f45e7687750a0ae8307b7557bfc0459a1f1a705` |
| `build/worldgen-typed/source-inputs-ba37b41.json` | `9d0b0b1875f1c9b67cb0f1ad2a91c417b5479d5d13127ebf20ec7714c2d5c2db` |
| `build/worldgen-typed/render-manifest.json` | `5b53cb7665427419220a4639bdb4a9793366eb3e80cc671078110fce78d324b5` |

The validation record also retains individual log and image hashes. This corrected
pass reran the three focused suites and native renderer. Its `prior_ui_evidence`
explicitly records `rerun: false`: the three 1600×900 Xvfb/llvmpipe Workbench
captures remain bound to `724afcf` and the earlier `32232c4e…` runtime. They were
not relabelled as captures of `ba37b41`. These corrected local results cover Linux
headless execution; hosted Windows execution, runtime publication and full
ready-PR acceptance have separate records.

## Documentation, publication and repository gates

Canonical subsystem, ownership, module boundary, interface, invariant,
configuration, roadmap, handover and build/validation documents were updated
together. The typed contract and operator inventory have explicit corpus/index
routes. Ten new retrieval challenges retain the original 32 frozen questions
and all 79 earlier supplementary objects.

At the documentation checkpoint, all 32 frozen queries retained their exact
baseline ranks: 21 at rank 1, 32 at rank 5, MRR 0.7953. The 89 supplementary
queries scored 70 at rank 1, 89 at rank 5 and MRR 0.8743; eight of the ten new
queries rank first and two rank second. Prior MS05 moved from rank 3 to rank 5
after corpus changes, with all expected facts still retrieved. The other 78
previous supplementary ranks are unchanged. Historical M11 integrity passed
all 18 records and 28 original source hashes; no historical hash was rewritten.

The initial standalone checkout reported six absent companion-workspace
expected-fact paths. Materializing the five referenced files from exact companion
commit `6a58311982941b75f46e22109a0829e5acb83c7e`, in the same parent/source layout
as Documentation CI, resolved those errors without changing source or fixtures.
Documentation then passed at 95 documents, 185 claims, 1,957 links and 149 anchors,
with no errors or warnings. The audit route adds one corpus chunk (1,040 total)
without further rank changes. Before runtime publication, current repository
checks correctly reported stale native source identities; publication remained
blocked until rebuilt, executed artifacts and their complete input ledgers were
available.

The branch-scoped
[runtime publisher](../../.github/workflows/gen003-runtime-publication.yml)
builds the exact source on GitHub-hosted Ubuntu, executes the Linux runtime and
executes the cross-built Windows DLL on an actual GitHub-hosted Windows runner.
It checks import plus four focused legacy/typed worldgen cases without skips,
records complete source/build input maps, validates execution/log digests, and
can append only the two LFS runtimes and their two manifests to the unchanged
feature branch. Build jobs have read-only repository permissions. Publication
does not certify the independent full acceptance gates.

The corrected [publication run 39505192343](https://github.com/techrote/cybersand/actions/runs/39505192343)
for `ba37b41` completed all four jobs successfully. Both its Linux and actual
Windows execution jobs passed import
and all four focused cases: Workbench 138, legacy fields 271, typed adapter 394
and render/generation 23 assertions, all zero failures, with no skips or errors.
The hosted Linux bundle
also passed the unchanged ABI-floor check: extension GLIBC 2.32, bundle GLIBC
2.34, GLIBCXX 3.4.30 and CXXABI 1.3.9.

The publisher appended commit `9966b1cb5db732a720c23d67ead34de2f995fd11`, tree
`2f7cddf813a78120a59d2de6330f1b54290aea45`, directly to parent
`ba37b41d41b0e42dbfa37238ed69dc6ade517ed5`. Its diff contains exactly the two
LFS runtimes and their two provenance manifests. The
[Linux manifest](../../godot/addons/cybersand_native/runtime-provenance.linux.json)
and [Windows manifest](../../godot/addons/cybersand_native/runtime-provenance.json)
each identify the `ba37b41` source/tree, **42 canonical native source inputs**,
**329 build/test inputs**, pinned toolchains, actual target-OS execution and the
successful workflow attempt. Their status is `validated-development-runtime`.

| Published runtime | Bytes | SHA-256 |
|---|---:|---|
| Linux x86_64 shared library | 2,462,568 | `1df04af876b30cafeb75b81a84968bee3c827195eb70c648efd0e14d9d29023c` |
| Windows x86_64 DLL | 2,955,776 | `fb1b53e7983f0af42ab76b22a38b16712892d612dbd26154576a871e2c9c8b1f` |

The retained Linux report is
`gen003-runtime-linux-39505192343/validation.json`, SHA-256
`8c709ceed7250b9637cbeb348372c15b8b3375241b9ac11657a5dec73d26d0ce`.
The Windows report is
`gen003-runtime-windows-39505192343/validation.json`, SHA-256
`b4ca8fbdc4dab9f0a67d890bf4eec8273c826b01ff3377fbffa07985d9c2e695`.
These published artifacts have their own identities, separate from the corrected
local `57529fed…` library and earlier `724afcf` UI runtime.

After fetching the publication commit, local verification matched both downloaded
binaries to their manifests and checked all **371 source/build input hashes per
manifest**. The Linux and Windows source/build maps are identical. The commit's
single parent and exact four-path publication diff were also verified.
`tools/ci/check_repository.py` then passed with all **18 runtime files materialized**,
none unmaterialized and no errors. Documentation checking passed again at 95
documents, 185 claims, 1,957 links and 149 anchors, with no errors or warnings.
These identity/provenance checks precede the independent full CI gates.

This audit checkpoint precedes the final documentation commit and
ready-for-review transition of [PR #195](https://github.com/techrote/cybersand/pull/195).
Runtime publication is complete; the independent exact-head
Documentation/provenance, Native, GDExtension/Godot and scoped Water acceptance
gates remain pending here. Their final commit identities, results and URLs are
recorded in the PR checks/comment after that transition, so this document does
not change the accepted head to insert a self-referencing result. Issue #190
requires those final gates before closure.

## Supported scope and remaining programme boundaries

Determinism covers the documented absolute-world partitions, request order,
worker count, budget slicing and cold/warm caches within the supported numerical
implementation. The native type system does not promise cross-compiler or
cross-architecture bitwise equality of transcendental functions. Platform
execution establishes each tested runtime's behavior independently.

Peano traversal is a finite tile ordering, not a connected physical route across
tiles. Poisson-style seeds use the documented bounded local rejection rule;
they are not an unbounded global optimization. Distance guarantees follow each
operator's explicit exact/qualified contract. Work is bounded logical accounting,
not a hardware performance SLA.

This issue establishes field interfaces and minimal authoring/inspection.
Hierarchical layout remains GEN-004, depth integration GEN-005, full visual
authoring/content qualification GEN-007 and persistent streaming GEN-006.
No new browser/WebAssembly, target-PC performance, owner gameplay or graphics
driver acceptance is inferred from the Linux/Windows headless gates.
