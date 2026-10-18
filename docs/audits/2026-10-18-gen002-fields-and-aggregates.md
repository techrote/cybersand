---
title: GEN-002 fields, masked modifiers and aggregate evidence
status: Current
document-kind: evidence
scope: Dated issue 171 native field/modifier, legacy compatibility and isolated Godot preview validation; publication and platform gates remain separately identified
canonical-for: [gen-002-fields-and-aggregates-evidence]
last-reviewed: 2026-10-18
related-documents: [../systems/procedural-generation-fields-and-modifiers.md, ../systems/procedural-world-generation.md, ../architecture/data-ownership-and-lifetimes.md, ../reference/configuration-reference.md, ../operations/local-build-and-validation.md, ../reference/status-and-roadmap.md]
---

# GEN-002 fields and aggregates — 2026-10-18

## Authority, integration and source scope

The owner extended procedural generation with space-filling curves, structured
noise, masks/sidechains, masked modifiers, simple aggregate-material definitions
and context-aware guidance, sculpting and manipulation.
[Issue #171](https://github.com/techrote/cybersand/issues/171) owns this work on
`codex/worldgen-fields-and-aggregates`.

The implementation begins from GEN-001 source
`54d455ca3157ecc3dbf9be2be2a5778567ec3311` and incorporates ACT-002 main
`087ca3e972296b189c8b83060463125c06d600e2` in merge
`f98d5ec4ff8e291ed7c79476b61920477c0d3581`, tree
`1b2ec8f29c73f8e958eb7e3cb8600eca6281a38a`. The sole merge conflict was the
supplementary retrieval-question collection. Resolution preserved the incoming
ACT03 scope update and ACT04–ACT09, GEN01–GEN04 and every other prior object;
the frozen 32-question collection remained byte-identical.

This record initially captures that merge plus the owned GEN-002 working delta.
A source checkpoint and fresh runtime publication must name their own commits
and full input maps before this becomes evidence for a published runtime. An old
GEN-001 artifact or an earlier successful UI copy is not validation of later
adapter/UI edits. The [field/modifier contract](../systems/procedural-generation-fields-and-modifiers.md)
owns Current semantics; this audit records actual tests and their limits.

## Implemented boundaries

The standalone scalar graph has 22 field kinds, fixed 64-value scratch,
topological dependency evaluation, validated canonical identities and bounded
logical work. Structured noise includes value, gradient, octave/ridged and
cellular distance/gap fields. Finite Hilbert/Morton addressing uses wide signed
tile arithmetic and explicit order/cell-size bounds. Analytic masks and arithmetic
compose through named inputs; optional noise warp consumes already evaluated
displacement values without recursively resampling the graph.

The generator captures initial proposed material, surface and route context
before the new controls. Each modifier influence is captured once. Theme guidance
precedes parameter guidance and hard geometry reapplication; masked native
modules precede material/aggregate modifiers, route/path carving and final hard
material overrides. Global exclusions remain eligibility constraints.

Aggregate definitions retain positive authored component weights and prepare
separate normalized selectors. They emit ordinary existing material IDs, using
signed world-aligned hashed grains or a directly sampled named variation field.
They add no mixture physics or save-state material representation.

Optional field/modifier/module diagnostic floats are collected during paced chunk
generation and bound into result receipts. Failed/cancelled jobs discard both
material and diagnostic arrays. The Godot workbench edits fields, components,
modifier masks/predicates/mappings and shape transforms; it previews copied
materials/diagnostics in its existing bounded queue/cache. It never installs
sculpting commands into the live sandbox World.

## Independent review findings and retained controls

| Finding | Repair or explicit contract, with regression coverage |
|---|---|
| Naively admitting curve extents into 32-bit intermediate arithmetic would truncate a maximum `2^32`-cell tile | Wide signed tiling with order-20/cell-size-4096 boundary cases, signed origin cases and independently interleaved Morton ranks |
| Repeated aggregate normalization could drift canonical fingerprint bits; an extremely small positive component could normalize to zero | Preserve authored weights, keep prepared normalized values separate, reject underflow and require recompiling the canonical recipe to retain identity/output |
| A slope calculation that held the center's parameters fixed omitted authored surface brushes at neighboring samples | Recompute original theme/brush/hard parameters at x−1/x+1, use one-sided domain endpoints, charge both snapshots and test an analytic zero-relief height brush |
| Context-aware carving could be misread as feedback from an earlier modifier or live World state | Capture initial context once; occupied-to-empty and empty-to-occupied two-modifier negative controls distinguish the implemented observation point |
| A copied diagnostic could be placed under another channel or returned after an inspection switch | Bind diagnostic channel/float bits into the native receipt and check the UI's captured view token, coordinate, channel, shape and finite normalized values before cache writes |
| Godot `Vector2` conversion in modifier transforms lost admitted coordinates above `2^24`, including identity transforms | Use scalar double coordinate arithmetic; preserve exact identity scaling before centroid arithmetic; add large-bound translation and fractional-point identity controls |
| Adversarial review required an explicit string-conversion boundary check | Retain a defensive embedded-NUL guard. Godot 4.7 converts attempted NUL input to U+FFFD before the adapter and warns; no prefix-alias acceptance was observed. Test representable U+FFFD references and preservation of the valid pending job |

An initial all-noise field test fixture exceeded the explicit 4096-operation
limit because it included both default four-octave fractals and two cellular
fields. The fixture was changed to one octave for that combined graph, with
default fractals tested separately and an intentional three-cellular over-budget
graph required to reject. A draft aggregate success fixture also contained zero
components, contrary to the strictly-positive schema; it was replaced with valid
positive components and separate individual-zero/all-zero rejection tests. These
are corrected test assumptions, not evidence of relaxed engine limits.

## Native regression scope and execution

The [field suite](../../native/tests/test_generation_fields.cpp) independently
checks finite curve bijection/inverse, the order-1 Hilbert orientation, all
consecutive Hilbert steps for orders 1 through 6, Morton discontinuity, signed
tile origins and maximum extents. Analytic mask/arithmetic values include exact
endpoints and a subnormal normalization interval. Noise checks cover finite range,
canonical declaration order, seeded reproducibility, single-octave equivalence,
receiving-primitive warp semantics, concurrent const sampling and successful-path
ordinary C++ allocation counts. Invalid unused nodes, cycles, parameters, limits
and contexts are explicit negative controls; failed evaluation preserves the
entire caller-owned destination.

The [modifier suite](../../native/tests/test_generation_modifiers.cpp) checks
application/exclusion/strength/shape products, fixed initial context, parameter
mapping and hard authority, theme exclusions, material realization and signed
grains, masked custom callbacks and final route/path/material precedence. It
compares absolute cells and diagnostic floats across 16/32/64-cell partitions,
reordered definitions, independent concurrent jobs and varied incremental
budgets. It rejects stale/altered receipts and clears both outputs after callback,
budget or cancellation failure. The existing generator and installer suites
remain separate registration targets under `make worldgen-test`.

The new optimized suites compile with C++20, `-O2 -g` and warnings
`-Wall -Wextra -Wpedantic -Wconversion -Wshadow -Werror`. Local ASan/UBSan uses
`-O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined`, with:

```sh
ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1 UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1 make worldgen-sanitize
```

The final `make worldgen-test` passed all four suites: generator, fresh-chunk
installer, fields and modifiers. The final `make worldgen-sanitize`, with the
environment above, passed the same four suites with exit 0 and no sanitizer or
failure diagnostics. The final modifier binary was forcibly rebuilt after the
strict-positive fixture and canonical/slope assertions. An input ledger checked
that native inputs did not change during the final sanitizer gate.

The optimized log SHA-256 is
`80857fcff868186b6e8513d3c92bfad9400c2e1f1053f8ddd088a11608ad9609`;
the sanitizer log SHA-256 is
`292907ec3f71629af3d47610fb2513f9ab818eb767b24fd8dc86b4c466860cc7`.
An initial attempt with LeakSanitizer enabled failed
because it could not inspect `/proc/2/task` under the environment's ptrace/process
restrictions. Successful runs with `detect_leaks=0` establish ASan/UBSan results,
not leak-freedom. A supported hosted runner must report its own LeakSanitizer
result; no failure is converted to a pass by changing that label.

The following focused LF source identities were inspected after those native
fixes. They identify the changed contracts/core/tests, while a published runtime
must retain the complete build/source maps in its provenance manifest.

| Input | SHA-256 |
|---|---|
| `native/include/cybersand/generation_fields.hpp` | `e405c49a96e912ce07535c57fc42467849384eddb43d405718bbefa98356da79` |
| `native/src/generation_fields.cpp` | `0f4139421792d9e17c069b542620356a2978a09f7254bc4f11c1b725729a4df3` |
| `native/include/cybersand/world_generation.hpp` | `1a8fbb40ead0ed8f50e2a407eca62ee2312aba64d396d1f44fa5ae6ca48148df` |
| `native/src/world_generation.cpp` | `b3ebf1fa657496e438f436012b8e9b865b5a1bd82fcf550d0ceeead9fbd139ae` |
| `native/tests/test_generation_fields.cpp` | `540f1a5514420252f2425d246164bd56324b7fbd8aacf368955133738d7458d6` |
| `native/tests/test_generation_modifiers.cpp` | `396cb2c52b72efc34578c52e368af4284fe51230e008888f1f9d33f0460c3431` |

## Retained GEN-001 material oracle

The compatibility test does not derive its expected hashes from the new
implementation. It materialized the historical generator header/source and
`decorated_recipe` test from commit
`54d455ca3157ecc3dbf9be2be2a5778567ec3311` using `git show`, compiled that source
in a separate temporary include path and generated four signed chunks for every
candidate. The referenced `world.hpp` and `material.hpp` bytes were checked equal
between historical and current source. No new fields, modifiers, aggregates or
module masks enter this fixture.

| Historical input | SHA-256 |
|---|---|
| `native/include/cybersand/world_generation.hpp` | `363019e142620a4a7265e758bfb7c244bae71cfd27a12711ccef8523b07b59f4` |
| `native/src/world_generation.cpp` | `7053c12dffc6f102996aaf6e75bd5046b93fcaf8c17d45dfe76cd5663bc9d0f5` |
| `native/tests/test_world_generation.cpp` | `90ef4f4a61f4c1b2be7da5ebe8bcdd6b1befa7aca6fce8a8133d61a0e108d6a2` |

The probe uses the old fixture's seed `0x416cd08397ad0f23`, 128-cell chunks,
natural/built weights 2/1, garden ribbon, crossing guide, hard stained-glass
rectangle and prepared vault. The historical compilation used `g++ -std=c++20
-Wall -Wextra -Wpedantic -Werror -O2` and completed successfully.

| Candidate | Chunk `[-1,-1]` | Chunk `[0,-1]` | Chunk `[-1,0]` | Chunk `[0,0]` |
|---|---|---|---|---|
| Strata | `3aa8e7812c4c46aa` | `674c7e8c09bb9d1f` | `031bffb3dd2e81d2` | `cba20a0a240408da` |
| Flow Network | `3aa8e7812c4c46aa` | `674c7e8c09bb9d1f` | `6a09cee13286e2e4` | `cba20a0a240408da` |
| District Grammar | `6159bcb98c8db89e` | `1ba53b231d1a3912` | `ea038ba7c39d3ce2` | `0da1c9523b6a06ed` |

All twelve constants are now retained in the new modifier suite. They establish
material-output compatibility for these fixtures. Generator algorithm identity
is intentionally 2, so recipe fingerprints and receipts are not expected to
match the old version. The [GEN-001 audit](2026-10-18-gen001-procedural-generation.md)
and its source/artifact claims remain unchanged.

## Godot execution and actual profile rendering

Initial local execution used the pinned Godot
`4.7.stable.official.5b4e0cb0f`, Rapier2D `0.35.2` and a fresh Linux x86_64
native build made with GCC 13.3. Its SHA-256 was
`08dec50cde64415faffa4b4156f4e6703c43cd1d783b09d70e35a895462cba0b`.
In an isolated copied project, `test_worldgen_workbench.gd` passed 138 assertions
and `test_worldgen_fields.gd` passed 254 assertions, each with zero failures.
Subsequent adapter checks and GUI help/transform changes received the fresh final
run recorded below; the initial counts do not attest those later source bytes.

Both final native builds completed after the defensive adapter check. These are
local build identities, prior to hosted publication:

| Artifact | Bytes | SHA-256 | Executed scope |
|---|---:|---|---|
| Linux x86_64 native extension | 2,124,584 | `0dfa474a9321e752fa21f241437fee777b1229bc6af1153c21a1b9e6e868b992` | Both final Godot suites and six software-OpenGL captures passed |
| Windows x86_64 native extension | 2,589,184 | `9336016005432946f9269c5455c2b9873f565a545243bec017c8887ef394c174` | Pinned cross-build; Windows execution unavailable |

The attempted raw-NUL Godot regression produced an input-normalization warning,
so that fixture was corrected to exercise the actual representable U+FFFD value.
The adapter did not accept a prefix alias in that attempt; the final negative
controls rejected representable invalid references and retained pending work.

The final source-matched Linux runs passed **138 assertions / zero failures** in
`test_worldgen_workbench.gd` and **263 assertions / zero failures** in
`test_worldgen_fields.gd`. Both exited 0 without `SCRIPT ERROR`, `ERROR` or Unicode
warnings. They include the corrected representable-string fixture, scalar-double
large-coordinate transforms and complete labels for all 80 valid existing
materials, omitting reserved ID 10. These final source identities distinguish the
tested UI/adapter from the initial 138/254-assertion copy:

| Input | SHA-256 |
|---|---|
| `godot/native_extension/cyber_world_generator.cpp` | `3f39cc42553d87a1e464e7ab5136966b67285e44757d8789c6489db5d6ded0e9` |
| `godot/native_extension/cyber_world_generator.hpp` | `648dc08fe074b3476778e070208386cc230c82414b2e7f47afd20ba2237bc6ef` |
| `godot/scripts/worldgen_workbench.gd` | `4cdcf73eaacc386cf7cb62ae361cb4343b6a738ed031c138a89429ca8ac14336` |
| `godot/scripts/worldgen_preview.gd` | `49179c6f7d093cd6c8f033eee904bd1384b62e89dc2f46d26edd57cf4b46adff` |
| `godot/tests/test_worldgen_workbench.gd` | `a91b5f07c00531b957723131509d0d13314e163ca146fae084bcf732ef121517` |
| `godot/tests/test_worldgen_fields.gd` | `9ccb11916df79bfb726dd6f0153b7e0662d30b92eb1455687103304a39b348a6` |

The Linux runtime floor check also passed: CyberSand imports at most
GLIBC 2.32, GLIBCXX 3.4.30 and CXXABI 1.3.9; the retained Rapier library raises the
bundle's GLIBC floor to 2.34. This is an ABI inspection, not Windows execution.

The checked-in [renderer](../../tools/render_worldgen_fields.gd) loaded all three
real JSON examples through `CyberWorldGenerator`, requested copied materials and
one diagnostic per chunk, and rendered a 512×384 region at origin `[-256,0]`.
All 72 requests completed with Ready results. Each individual chunk stayed below
the default 64,000,000-operation limit; totals below cover the entire region.

| Profile | Chunks | Diagnostic | Operations per chunk | Region total |
|---|---:|---|---:|---:|
| `hilbert-seams` | 12 | `modifier:cyan_hilbert_traces` | 45,613,056 | 547,356,672 |
| `weathered-aggregate` | 48 | `modifier:weathered_surface` | 17,498,112 | 839,909,376 |
| `sidechained-arcology` | 12 | `module:weathered_arcology` | 35,061,760 | 420,741,120 |

The renderer writes six exact material/mask PNGs and `render-manifest.json`, with
per-chunk material/receipt hashes and recipe identities. The assembled
[documentation figure](../figures/worldgen-fields-and-aggregates.png) has SHA-256
`7d29c07d2b4c53dd99fc83bac2fac088e10800b62c1edb937e0775eae9b3edd8`.
These pixels are generation output before simulation; no aggregate settling,
Water equilibrium, actor traversal, target-GPU frame time or Windows/Web execution
claim follows from their successful rendering.

Six pre-publication software-OpenGL/Xvfb captures exercised field editing, aggregate
materials, modifier diagnostics, context-aware sculpting, module masks and a
compact field panel. The capture process exited 0, all six layout checks passed
and the native runtime hash remained unchanged. The project uses a logical
1920×1080 canvas stretched to physical windows of 1800×1012 and 1280×720.
The initial harness compared physical screenshot coordinates with logical UI
bounds and falsely flagged overflow; correcting the measurement basis resolved
that flag. A blank programmatically selected sculpt-tool overlay was resolved
by requesting redraw in the capture harness; the normal user-selection signal
already does so. Neither required a product rendering change.

The [pre-publication aggregate workbench capture](https://github.com/techrote/cybersand/blob/781eccfa016ac0d220a51d2ecf12de1edf1b6d7b/docs/figures/worldgen-aggregate-workbench.png)
was the exact 1800×1012 PNG, 170,874 bytes, SHA-256
`b870a7892ee3b7455c8bd63559d9d441810a9a6630fab00027840e3b71b236e1`.
Godot executable SHA-256 was
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`;
the isolated Xvfb executable SHA-256 was
`b73b49fddab9b345bd755b1d083d1c68c4cc4e711170a5090563199884807c3f`.
Software-rendered layout review is scoped visual evidence, not target-device
rendering throughput or gameplay acceptance.

## Documentation and publication gates

Canonical changes cover the focused field/modifier contract, existing generation
precedence, configuration, interfaces, module boundaries, sample/output ownership,
chunk/tile distinctions, World-admission scope, product intent, roadmap and build
handover. The retrieval manifest adds the focused Current contract and explicitly
routes this dated audit outside default answers. GEN05–GEN08 are supplementary
questions; all 49 previous supplementary objects and the frozen 32 questions
remain unchanged.

The first complete canonical-document pass produced these results:

| Check | Result and scope |
|---|---|
| `python3 tools/ci/check_docs.py` | PASS: 82 canonical documents, 145 claims, 1,449 local links and 81 anchors; no errors/warnings |
| `python3 tools/ci/check_m11_consistency.py` | PASS: 18 immutable historical records and 28 historical source hashes; no current runtime acceptance implied |
| Frozen `retrieval_eval.py`, k=5 | 24/32 at rank 1; 32/32 at rank 5; MRR 0.8646 |
| Supplementary `retrieval_eval.py`, k=5 | 41/53 at rank 1; 53/53 at rank 5; MRR 0.8670 |
| `python3 tools/ci/check_ci_provider_policy.py` | PASS: active routine workflows retain GitHub-hosted policy |
| `git diff --check` | PASS |
| `python3 tools/ci/check_repository.py` | Expected pre-publication FAIL: exactly eight stale source-map entries across the two retained native runtime manifests; all 18 required runtime files materialized |

The two lexical evaluations used 82 documents / 840 heading chunks. Manual review
of the new questions retained finite-curve, initial-context, aggregate-physics and
World-lifetime qualifiers. GEN06's top-five contexts include context and hard
authority; detailed cycle/warp validation requires following the same contract's
field-graph section. A canonical hit is therefore not a claim that every expected
fact is already present in the first retrieved paragraph or a general retrieval
quality improvement.

After the final UI evidence and screenshot caption, the required documentation,
M11, frozen/supplementary retrieval and diff checks were rerun successfully.
Documentation now counts **1,451 local links**; the other counts and both retrieval
metrics above are unchanged. At that pre-publication point, the retained runtime
manifests still required actual publication of source-matched artifacts. Runtime provenance must
come from those rebuilt artifacts and complete source maps; editing old manifests
to disguise stale source is not an admissible substitute. Publication must rerun
the current repository/CI gates against its exact source checkpoint.

Local compilation, Linux execution, Windows cross-compilation, hosted exact-head
CI, browser execution and owner visual/gameplay acceptance remain separate
evidence categories. No merge, release, production streaming or blanket platform
acceptance is asserted by this working checkpoint.

## Completed source and runtime publication — 2026-10-18

The source/API checkpoint is
[`781eccfa016ac0d220a51d2ecf12de1edf1b6d7b`](https://github.com/techrote/cybersand/commit/781eccfa016ac0d220a51d2ecf12de1edf1b6d7b),
tree `9fde678e97e453ba94eba6b8407909e672063e7e`, in
[PR #173](https://github.com/techrote/cybersand/pull/173). Its two parents preserve
GEN-001 `54d455ca3157ecc3dbf9be2be2a5778567ec3311` and the current main observed
at freeze, `087ca3e972296b189c8b83060463125c06d600e2`. The earlier local
`f98d5ec…` checkpoint remains the test-ledger base described above; publication
does not rewrite that historical execution identity.

The guarded publisher was installed at
`57e497ebf62ee882620248bf28beba33158f14be`, workflow SHA-256
`dda3a4f9b6834f82aca012ac1f01acca6168560bffae8094b649314dbdfd1c6e`.
[Run 39120381132](https://github.com/techrote/cybersand/actions/runs/39120381132)
**passed on attempt 1**, completing at 10:58:06 UTC. The build checkout was the
workflow-install commit; all 37 native source inputs and 35 build/validation
inputs were checked against the frozen `781eccfa…` Git blobs. Downloaded reports,
artifact bytes and the 15 Linux/two Windows recorded log hashes were verified.

Publication commit
[`47ee9496d0d0a68e5d7e066cf0b18e34bbc78391`](https://github.com/techrote/cybersand/commit/47ee9496d0d0a68e5d7e066cf0b18e34bbc78391),
tree `726bb1180b1121517152c13c65ecbd027af52d58`, changed only the two runtime
artifacts, their two provenance manifests and deletion of the one-shot publisher.
The local checkout was fast-forwarded and both published LFS artifacts materialized.

| Published artifact | Bytes | SHA-256 | Acceptance scope |
|---|---:|---|---|
| Linux x86_64 | 2,124,592 | `71bb831ac1ea841b2f381b710bca6a49ff4b21ff3b8ec37a2bef95d979b98128` | Fresh hosted build, ABI check and Linux execution below |
| Windows x86_64 | 2,589,184 | `29140e5c8449ddf4a2013bfd2b2caeb92114421fb7ddbeda169e90b166f88c35` | Fresh pinned cross-build and PE32+/AMD64 inspection; Windows execution not performed |

The [Linux provenance](../../godot/addons/cybersand_native/runtime-provenance.linux.json)
and [Windows provenance](../../godot/addons/cybersand_native/runtime-provenance.json)
retain the exact source/tree, build commit, toolchain, input maps and run identity.
Their artifact hashes are distinct from the earlier local builds and are recorded
separately. The hosted Linux build used Ubuntu 24.04/GCC 13.3; both targets used
the pinned godot-cpp commit `101ae38034304346a46ea9ea84ae156d3e860496`.

Hosted Linux passed all **70 core native tests**, all **four optimized generation
suites**, and all **four generation ASan/UBSan suites** with
`ASAN_OPTIONS=detect_leaks=1:strict_string_checks=1` and
`UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1`. LeakSanitizer therefore passed
in this supported hosted environment; the earlier local process-inspection
limitation remains a separate retained result.

All eight Godot cases passed with return code 0 and no diagnostic errors: clean
import, native render bridge, native edge/contact, MicroScenario native observation
(100 assertions), workbench (138 assertions), field authoring (263 assertions),
180 headless workbench scene frames and all three executable example profiles
(12/48/12 chunks). Each of the six hosted material/mask PNGs was **byte-identical**
to its earlier input for the documentation figure. This confirms those figure
inputs against the actual published Linux generator; the local software-OpenGL
layout captures keep their separately recorded runtime identity.

Post-publication `check_repository.py --require-materialized` **passed with zero
errors** and all 18 required runtime files materialized, resolving all eight
pre-publication stale-input errors. Documentation passed at 82 documents,
145 claims, 1,451 links and 81 anchors with no errors/warnings. M11 again passed
18 records/28 historical source hashes. Frozen retrieval remained 32/32 at rank 5
(24 at rank 1, MRR 0.8646); supplementary retrieval remained 53/53 at rank 5
(41 at rank 1, MRR 0.8670), each across 840 chunks. Provider policy and
`git diff --check` passed. These checks used the materialized publication checkout
plus this audit-only follow-up; no native or UI source was changed.

Normal ready-for-review Documentation, Native, GDExtension and scoped Water CI
are separate from this publisher. Their actual final PR head, checkout and run
results belong to the later PR validation record; no draft skip or publisher
success substitutes for those gates. Windows execution, browser/WebAssembly,
target-device performance and product/gameplay acceptance remain outside this
publication's scope.

## Post-publication accepted-profile UI defaults — 2026-10-18

Final review found that reopening an accepted profile with omitted optional
values displayed new-draft presets instead of native defaults. An aggregate's
implicit `grain_size` is 4, while the editor's intentional new-draft preset is
12; an accepted modifier's implicit priority is 0, while a new draft starts at
10. An aggregate component may also omit its weight, which the native adapter
interprets as 1. The UI now uses those native defaults for accepted entries and
retains its separate new-draft presets. This prevents an unchanged Apply action
from altering an accepted aggregate's grains or a modifier's ordering.

The correction changes only
[`worldgen_workbench.gd`](../../godot/scripts/worldgen_workbench.gd) and its
[field-authoring regression](../../godot/tests/test_worldgen_fields.gd). Eight
additional assertions verify displayed defaults, unchanged reapplication, equal
canonical fingerprints in independently configured generators, equal generated
material bytes/hashes, and preservation of the new-draft presets.

Execution used the **published Linux runtime**
`71bb831ac1ea841b2f381b710bca6a49ff4b21ff3b8ec37a2bef95d979b98128`,
Godot `4.7.stable.official.5b4e0cb0f` and Rapier2D `0.35.2`.
`test_worldgen_workbench.gd` passed **138 assertions / zero failures**;
`test_worldgen_fields.gd` passed **271 assertions / zero failures**.
No C++ source or runtime binary changed, and no native rebuild was required.

| Corrected source | SHA-256 |
|---|---|
| `godot/scripts/worldgen_workbench.gd` | `d2ffc9d95062dd643b7331134a8b80fa45894cec1a0b30d008da8c14d202e967` |
| `godot/tests/test_worldgen_fields.gd` | `f325c3984c3bd0d0e1f6c14e690f359d1e3f4fb038f7c8d4e2660e792e192e49` |

The publisher's original 138/263 results and its 37 native/35 build-input maps
remain the actual publication snapshot. They are not rewritten to claim that
the publisher tested these later GDScript changes. The 138/271 runs above are
separate post-publication evidence; normal exact-head PR CI remains an
independent gate.

All six software-OpenGL/Xvfb views were then recaptured with the corrected UI on
the published `71bb831a…` Linux runtime: **six captures / zero failures**, process
exit 0 and no `ERROR`/`SCRIPT ERROR`. The reviewed aggregate panel visibly shows
the accepted native grain size 4; contextual-sculpt and compact-field layouts were
also inspected. Godot/Xvfb executable hashes and the logical/physical viewport
basis remain those recorded above.

The current [aggregate workbench figure](../figures/worldgen-aggregate-workbench.png)
is this updated 1800×1012 capture, **170,611 bytes**, SHA-256
`2e263ca78aa88c459fc55b71d3da392a46ff53aee3eb755ecea7d7e5eafe3f42`.
The earlier `b870a789…` capture is retained under its pre-publication commit link
above and is not relabeled as the corrected view. The native material/mask
comparison figure and the publisher's six-image byte-equality result are unchanged.

After this correction and recapture, the required repository check with
`--require-materialized` passed with zero errors and all 18 runtime files present.
Documentation, M11 integrity, both retrieval evaluations, provider policy and
diff checks passed again with the same counts and metrics recorded above. The
final working delta was exactly this audit, the current aggregate figure, the
workbench script and the field-authoring test; runtime manifests and native
source remained unchanged.
