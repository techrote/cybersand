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

The ordinary `make -j2 worldgen-test` gate passed seven suites: generation,
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

The full sanitizer gate has its own result below; the focused typed result does
not imply that every other suite completed. LeakSanitizer's process inspection
is unavailable in the restricted local environment. The repository's generation
harness uses `detect_leaks=0`; these results establish address/undefined-behavior
coverage and do not claim leak detection.

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

The established Workbench regression passed 138 assertions and the legacy field
regression passed 271, both with zero failures. The typed adapter/Workbench suite
passed 394 assertions after the precision and example-budget corrections.
All five native material/diagnostic pairs rendered, and actual Workbench layout
was inspected under Xvfb/llvmpipe. Final publication and ready-for-review CI
rerun the frozen source; these observations are not Windows or GPU performance
claims.

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

The initial standalone checkout reports six absent companion-workspace
expected-fact paths. Documentation CI materializes that established companion
checkpoint. Before runtime publication, current repository checks correctly
report stale native source identities; that failure is an acceptance blocker,
not a bookkeeping exception.

The branch-scoped
[runtime publisher](../../.github/workflows/gen003-runtime-publication.yml)
builds the exact source on GitHub-hosted Ubuntu, executes the Linux runtime and
executes the cross-built Windows DLL on an actual GitHub-hosted Windows runner.
It checks import plus four focused legacy/typed worldgen cases without skips,
records complete source/build input maps, validates execution/log digests, and
can append only the two LFS runtimes and their two manifests to the unchanged
feature branch. Build jobs have read-only repository permissions. Publication
does not certify the independent full acceptance gates.

Publication identity, full sanitizer disposition and final required gate links
are recorded as follow-up evidence in this audit and
[PR #195](https://github.com/techrote/cybersand/pull/195). At this source checkpoint
the PR is intentionally draft: Linux/Windows runtime publication and exact-head
Documentation/provenance, Native, GDExtension/Godot and scoped Water gates are
still pending. Issue #190 remains open until those gates pass.

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
