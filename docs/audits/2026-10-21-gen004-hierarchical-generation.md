---
title: GEN-004 hierarchical generation implementation and acceptance evidence
status: Current
document-kind: evidence
scope: Dated issue 191 source identities, semantic/raster controls, documentation checks and separately qualified runtime acceptance
canonical-for: [gen-004-hierarchical-generation-evidence]
last-reviewed: 2026-10-21
related-documents: [../systems/procedural-hierarchical-generation.md, ../systems/procedural-world-generation.md, ../systems/procedural-typed-spatial-fields.md, ../reference/validation-evidence.md, ../operations/local-build-and-validation.md]
---

# GEN-004 hierarchical generation — 2026-10-21

## Intake and evidence boundary

[Issue #191](https://github.com/techrote/cybersand/issues/191) owns GEN-004,
the second stage in the approved GEN-003–007 programme. Implementation starts
from main `ba19d3a2b2608ef0ffbe252b684561e45aeaa457`, tree
`e0bb20d9f10bae6729bd002fd0501c92bd02502a`, which merged the prerequisite
GEN-003 in [PR #195](https://github.com/techrote/cybersand/pull/195).

Intake inspected the repository guide, handover, roadmap, canonical generation
contracts, native interfaces, dependency pins and all eighteen materialized LFS
runtime entries. The active Git root is the source repository. Unrelated open
actor, scene, material and Water work retains its own scope.

The [hierarchical generation contract](../systems/procedural-hierarchical-generation.md)
first recorded canonical ownership and the semantic-to-raster boundary before
implementation. It owns current API semantics when source inspection is complete;
this dated audit owns executed controls and their limitations. No local check
substitutes for source-matched Linux/Windows runtime publication or exact-head
hosted acceptance.

## Documentation and retrieval baseline

Before adding the hierarchy contract to the current-answer corpus, the retained
frozen 32 questions returned **21 hit@1, 32 hit@5, MRR@5 0.7953**. The existing
89 supplementary questions returned **70 hit@1, 89 hit@5, MRR@5 0.8743**.
Both runs used the repository's unchanged heading-chunk/BM25 evaluator and a
95-document, 1,040-chunk corpus on Linux/Python. Commands:

```sh
python3 tools/docs/retrieval_eval.py --output /tmp/gen004-retrieval-baseline.json
python3 tools/docs/retrieval_eval.py --queries docs/reference/retrieval-challenges.json --output /tmp/gen004-challenges-baseline.json
```

These measurements establish routing baselines, not answer correctness or a
claim about embedding-based retrieval. Existing question IDs and query wording
remain unchanged; new hierarchy questions are reported separately.

## Documentation synchronization and local checks

The first remotely recoverable implementation checkpoint in draft
[PR #196](https://github.com/techrote/cybersand/pull/196) is
`66fddb78ff0f1ac6e457f53a78cf0c39aea14d7b`, tree
`fb4986cadf5b47eb9e0775fb29c57945f152c636`. It was published through the Git API
and has the same tree as the local checkpoint
`3d27ddc3508f569f7b7368b71660ad23c5ec2be6`; the two commit IDs are not
interchangeable ancestry claims. The documentation checks below ran on
Linux x86_64 with Python 3.12.14 after the local checkpoint, with the final
documentation changes still in the working tree. Their results qualify the
inspected document corpus; they do not attest the later native or runtime bytes.

| Affected responsibility | Canonical synchronization |
|---|---|
| Semantic ownership, deterministic identities, constraints, routes and bounded raster integration | New [hierarchy contract](../systems/procedural-hierarchical-generation.md); [ADR-013](../decisions/ADR-013-canonical-semantic-generation.md); existing generation, scalar-field and typed-field contracts |
| Lifetime and dependency boundaries | Ownership/lifetimes, module boundaries and chunk/tile/buffer model distinguish semantic regions from storage chunks, immutable geometry from live World state, and route qualification from admission authority |
| Public API, capacities and failure invariants | Interface, configuration and invariant references describe copied inspection, finite planning budgets, hard-override conflicts and all-or-nothing publication |
| Authoring and runtime validation | Versioned grammar schema, multi-district JSON example, build guide and test-selection guide identify the real adapter and focused suites |
| Programme and discoverability | Roadmap, handover, documentation index, retrieval index/corpus, validation ledger and eight new supplementary questions route to the new canonical home |
| Unaffected simulation behavior | No new MaterialRules, actor controller, scheduler, depth renderer, World streaming owner or persistent-edit reconciliation is asserted; those contracts retain their separate programme scope |

The canonical contract was reviewed against `GrammarPlan`, the final material
stack, copied adapter records and the JSON example. It explicitly discloses
finite regional ownership, bounded greedy candidate selection, support against
semantic surfaces, the `floating-square-v1` clearance profile, clipped outer
boundary apertures and separate `static-solid-contact-v1` qualification.
The schema is an authoring aid; native validation owns
cross-field, type, cycle, geometry and work-limit checks.

Commands executed for the documentation checkpoint:

```sh
python3 tools/ci/check_docs.py
python3 tools/docs/retrieval_eval.py --output /tmp/gen004-retrieval-final.json
python3 tools/docs/retrieval_eval.py --queries docs/reference/retrieval-challenges.json --output /tmp/gen004-challenges-final.json
python3 -m json.tool examples/worldgen/hierarchy-multi-district.json
python3 -m json.tool examples/worldgen/schemas/grammar-v1.schema.json
git diff --check
```

Structural documentation validation passed with 97 documents, eight navigation
files, 189 canonical claims and 152 heading anchors, with no errors or warnings.
Both JSON files parsed and the whitespace check passed. At this documentation
checkpoint, full JSON Schema evaluation was not run because the local Python
environment did not provide `jsonschema`. The later frozen-source check below
adds that receipt. Schema validation does not qualify recipe execution, which
requires the native compiler and adapter controls recorded separately.

The resulting retrieval corpus contains 97 documents and 1,063 heading chunks.
The evaluator SHA-256 is
`a68ebed677cdd2916b18dfc065fe59245c4690707f2d6083e07d108a7b523e59`;
the unchanged frozen fixture SHA-256 is
`f2727cbe26633359798736537e06c7754db8c5588af90627f79c6bd798bbb6ec`.

| Question set | Before hit@1 / hit@5 / MRR@5 | After hit@1 / hit@5 / MRR@5 |
|---|---|---|
| Frozen 32 | 21 / 32 / 0.7953 | 21 / 32 / 0.7953 |
| Existing 89 supplementary | 70 / 89 / 0.8743 | 69 / 89 / 0.8693 |
| New GEN19–GEN26 | No earlier measurement | 6 / 8 / 0.8750 |
| Combined 97 supplementary | Different fixture; not comparable | 75 / 97 / 0.8698 |

All frozen ranks were retained. Among the prior supplementary questions,
ACT10 moved from rank 1 to rank 2; its new first result is the existing physical
actor contract. MS05 moved from rank 5 to rank 4; the other 87 prior ranks are
unchanged. No query was changed to hide the ACT10 decline. Six new hierarchy
questions rank first; GEN23 and GEN25 rank second behind their related typed-field
and public-interface contracts. Those companion answers and the canonical
hierarchy answer were reviewed for immutable geometry, copied ownership and the
declared runtime qualifications. Hit rates remain routing evidence, not proof of
answer correctness or a new embedding retrieval claim.

## Authored example corrections and bounded local raster inspection

The initial sixteen-site curve tour exceeded the retained 1,000,000,000-operation
final-raster budget after native mask eligibility was accounted conservatively.
The example now declares order-1 Hilbert sites, a real four-site service tour,
one foundry entry, two gallery entries and one machinery entry per region. An
unnecessary pump-light feature was removed; the dais retains two independently
placed light details. No default or hard budget was raised.

The first solid dais incorrectly requested `open_volume` for its embedded light
details; the compiler correctly rejected that occupied parent interior. The
details now declare separation without claiming empty parent volume. Raster
inspection then found that passage restoration and the preexisting candidate
macro network could remove initially valid apparatus or support. The example's
preferred foundry candidate is now the upper rectangle at local `[12,20,104,72]`.
Its 64×66 gallery contains an 8×2 dais at local `[2,62,8,2]` with floor and wall
constraints; the machinery room contains an 8×4 pump at `[16,58,8,4]` and an 8×4
ceiling console at `[14,2,8,4]`. All coordinates in this sentence are relative to
the respective parent. The two dais lights are 2×1 embedded details. These are
deliberate authored placements, not a promise that arbitrary future edits avoid
all raster cuts.

A local Linux/Godot 4.7 probe configured the complete authored recipe, read the
native final route/support report, generated a 64-cell chunk and inspected every
cell of the twelve support-constrained fixture rectangles plus their declared
contact sides. At 2026-10-21 06:50 UTC, recipe SHA-256
`e5aae69f28ba96add7bc3dbfdfad6f954954b389df7241ad16382122f76705d1`
and Linux runtime SHA-256
`64bc39500a4a93f4beb6fe76caa5e115ac857da032da8f0634ed82a137e38543`
produced 52 features and 52 routes. The report passed all 40 required routes and
16 support constraints over 65,536 final cells, charging **991,738,352 logical
operations**. The plan declared 10,816 operations per sample; the 4,096-cell
chunk charged 61,587,456 operations. This example is close to its unchanged
logical budget; additional rules or geometry must be requalified.

The additional cell inspection found all **320 fixture footprint cells** and
**104 authored-side contact cells** solid after the complete material stack.
The generic wall report also inspects the opposite side, so its missing-contact
count may be nonzero while the declared wall contact passes. This control is
stronger than the generic profile's one-contact threshold for these particular
fixtures, but establishes no gravity or simulation stability. Local probe source
SHA-256 was `ae1b14e49fcd33ae86e5fc863ba0e07376723eb9aa2885b96f0f22b2b0dd7c35`;
its copied inspection result SHA-256 was
`ae4dffe8848955b36bb4c6dbd2b032a0c591c1743ff877ccbfab330c77c77389`.
These prepublication runtime observations are not relabelled as acceptance of
later rebuilt binaries or commits.

## Local integration verification before publication

The complete frozen source was published as
[`e25fbbc921f35435f369928c5b53bde2c2c223a5`](https://github.com/techrote/cybersand/commit/e25fbbc921f35435f369928c5b53bde2c2c223a5),
tree `77194f834e8bb1f79286a7a5b4b17e89a764180f`, retaining the implementation,
schema/example, regression tests and scoped runtime publisher.

The final native source working tree based on remote checkpoint `66fddb78` passed
`make -j2 BUILD_DIR=build/gen004-acceptance worldgen-test` on Linux x86_64 with
GCC 13.3.0. All eight executables passed: legacy generation, atomic World
installation, scalar fields, modifiers, typed fields, typed integration, spatial
primitives and semantic grammar. The typed field suite reported 14,162
assertions; the semantic grammar suite reported **77,294 assertions** in both
the independent debug build and the optimized build. Its retained controls
cover negative coordinates, independent regions, all three candidate strategies,
chunk sizes 8/16/32/64, request order, four workers, budget slices, constraints,
fallback/exhaustion, geometry and recipe roundtrips, material composition, final
route clearance, support removal and complete declared external binding checks.

The frozen native implementation hashes were:

| Source | SHA-256 |
|---|---|
| `native/src/world_generation.cpp` | `fed1656d5c5d481c702d22ee8ef3199b20586abff3f8a41b26d6005948b996e7` |
| `native/src/generation_grammar.cpp` | `90d279369059a1d6bdc7125148cfa514ffc2ac035b9104b4ccd22dbb7560bf61` |
| `native/tests/test_generation_grammar.cpp` | `4b57fe76f91a2cfc145c6ee8a829784042beb37d03b6b16028a558ca3a9bf9c0` |

After rebuilding through `tools/build_native_extension.sh`, Linux runtime
SHA-256 `773bdc21489a2e36165afb8c720e9d0b3bfcd9022e3465e0f7fa9b06d64b25a7`
passed the pinned Godot 4.7 import and all five focused adapter/UI cases with
no skips, script errors or diagnostic errors: Workbench **138**, fields **271**,
typed generation **394**, semantic grammar **438**, and render integration
**23** assertions, all with zero failures. These cases were run through the
repository regression runner with its normal 180-second case bounds; import
used its 240-second bound. This local artifact is not substituted for the
workflow-published Linux/Windows pair.

Review retained regression controls for suppressed child masks losing parent
material, duplicate exported geometry on recipe recompilation, unstable theme
normalization, invalid external bindings in unused/omitted rules and an unbounded
native district-theme map. The old unknown-schema test was updated to reject
schema 4 because schema 3 is now deliberately supported. Historical M11 integrity
passed for all 18 records and 28 source hashes; the eight validation-failure
contract tests and six CI-provider policy controls passed.

The focused semantic grammar AddressSanitizer/UndefinedBehaviorSanitizer target
also passed **77,294 assertions**, exit 0, with no runtime sanitizer diagnostics:
`make BUILD_DIR=build/gen004-acceptance build/gen004-acceptance/test_generation_grammar_sanitized -j2`,
then execution with `ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1` and
`UBSAN_OPTIONS=halt_on_error=1`. Its binary SHA-256 was
`a053007c861de9b6d8c7af0b3f8e8d2f245e23fce8eafa99e17d0117c1d176ac`;
the implementation and test source hashes were unchanged before and after.

The frozen grammar schema also passed `Draft202012Validator.check_schema`, and
the complete example's `grammar` member passed that schema's `validate` method,
using `jsonschema==4.23.0` installed in an isolated temporary environment. This
added no repository dependency or source change.

## Linux runtime compatibility correction

The first scoped runtime publication for source `e25fbbc921f35435f369928c5b53bde2c2c223a5`,
[run 39558540625](https://github.com/techrote/cybersand/actions/runs/39558540625),
failed the Linux compatibility gate before its focused tests could execute:
the rebuilt extension required `GLIBCXX_3.4.31` instead of the retained
`GLIBCXX_3.4.30` floor. The Windows cross-build and actual Windows execution
passed, but the publication job correctly skipped; no runtime publication
commit was created. The earlier local Linux test pass above was on a host
providing the newer symbol and therefore did not establish distribution
compatibility.

Object-level inspection attributed the new import to GCC 13's
`std::string::_M_replace_cold` helper, introduced by literal assignments and
rvalue concatenation in semantic IDs, constraint receipts and final route/support
diagnostics. Those expressions now construct then move strings or append into
owned strings. Compiler, dependency pins and the compatibility gate are
unchanged. The optimized planner, raster integration and Godot adapter objects
contain no `_M_replace_cold` import.

Nine before/after planner fixtures (Hilbert, Morton and Peano, each with seeds
`0`, `191` and `UINT64_MAX`) produced byte-identical fingerprints, work/storage
receipts, feature IDs/revisions and constraint receipts. Both comparison files
had SHA-256 `dbd31f7fa32091dbe58474e1e1d365e957378f10891721c027e775c1a9595f3b`.
The corrected implementation hashes are:

| Source | SHA-256 |
|---|---|
| `native/src/world_generation.cpp` | `f4af7b2deaf68348acc22699a5aca636a93d3dfbb0f91d26e7c675ed679f6561` |
| `native/src/generation_grammar.cpp` | `4f872a4140a9bb2be617947f4fd491d546a584f396f97bd6efaa801121163eba` |

The corrected source passed the independent debug grammar suite's **77,294
assertions**. Rebuilding the complete extension through the pinned Linux build
script produced SHA-256
`8e23761806f944896f094ad927c245673689e5b3bdaccfeea335acd763fddd5d`.
`bash tools/check_linux_runtime_floor.sh` passed with bundle `GLIBC_2.34`,
CyberSand `GLIBC_2.32`, `GLIBCXX_3.4.30` and `CXXABI_1.3.9`, and Rapier2D
`GLIBC_2.34`. This corrected runtime then passed the pinned Godot import and
the same five focused cases: Workbench **138**, fields **271**, typed generation
**394**, semantic grammar **438** and render integration **23** assertions,
with no skips or errors. These are local receipts; both target-OS builds and
execution are repeated by the scoped publisher for the corrected source commit.

The compatibility checkpoint was published as
[`5f772f8221a5bae4f4f60f5c0eacedabdc050976`](https://github.com/techrote/cybersand/commit/5f772f8221a5bae4f4f60f5c0eacedabdc050976),
tree `a130c07c85b035931c232142e414f94ccdca3d6e`.
Its scoped [run 39560390001](https://github.com/techrote/cybersand/actions/runs/39560390001)
passed the Linux floor and focused execution, Windows cross-build and actual
Windows focused execution, then published both runtimes in
`77d24cf2aa40d7e6d92529c9eb308a20a33cdf78`. This proves the compatibility
correction at that source; the subsequent socket corrections below require
their own source-matched publication and are not covered by that pair.

## Adjoining socket corrections

The final acceptance review found that manually adjoining `liquid` sockets with
`attach_to_route=false` emitted a correctly typed route but selected the generic
service material. Automatic trunk attachments already inherited the correct
route material. The adjoining-pair dispatch now selects Empty for passages,
the declared `liquid_material` for liquids and `service_material` for services.
Pairing, geometry, IDs, ownership and required traversal flags are unchanged.
The corrected planner SHA-256 is
`92e4a42f7326e14b962e299ae5e4043dc62722bfc1b4ced104d6972e39ae4356`.
Its rebuilt Linux runtime, SHA-256
`fd14e6c013b5efcf2eb5be8a4d914d5035ddf93cbdce5275b3dd8c6fe035ac4c`,
passed the unchanged runtime-floor check, pinned Godot import and all five
focused cases (138/271/394/438/23 assertions, zero failures, skips or diagnostic
errors). The earlier compatibility-only runtime is not the final candidate.

The same review found an omission case where a manual route's ID belonged to
the surviving feature while its peer socket belonged to a subsequently omitted
feature. Removing only routes under the omitted feature's ID left a dangling
endpoint and residual raster geometry. Pruning now removes routes owned by the
omitted subtree or connected to either of its removed endpoints; existing
reciprocal-match cleanup remains active. The per-route pruning work charge
increases from 16 to 48 to cover all three bounded identity checks.

The expanded independent debug suite passed **77,480 assertions**. Its manual
socket controls cover passage/service/liquid materials with defaults and custom
Metal/Acid values, reciprocal endpoint IDs, exact corridor and adjacent unaffected
cells, material provenance and declaration reordering. The omission control
compares surviving cells against an independently compiled survivor-only recipe,
checks every route endpoint remains published and rejects leftover join material
or provenance. Both negative controls failed against the exact prior `5f772f82`
planner at their intended material-selection and removed-endpoint assertions.

Final socket source SHA-256 is
`1d2f024eb3165233b5d012c4fd62ed5cdaad0adb972df1c486007e77b57afce0`;
test SHA-256 is `af61209ba9ed75fc60bdfa659ae273fa8e8dc6d68b3f8facf34ce02324fd9c78`.
Its rebuilt Linux runtime, SHA-256
`0b0843a07ab824a801d708c9d98ba0776973c48b269b28da96ad42d2f14e7048`,
passed the unchanged compatibility floor, pinned Godot import and all five
focused cases (138/271/394/438/23 assertions), with no skips or errors.

## Cold native build budget

The prior full local suite used an incremental build with parallel compilation;
it did not qualify the hosted cold serial command. With final socket sources and
tests frozen, a separate empty output directory ran the existing
`timeout 5m make worldgen-test` command with inherited parallel flags removed.
On local GCC 13.3 it exited **124 at 300.053 seconds** while compiling the last
`test_generation_modifiers` executable. Seven binaries had been built, but none
of the target's test commands had started. This is a build-budget failure, not a
failed assertion or a passed suite. Input hashes were unchanged; child CPU time
was 281.926 seconds user and 16.173 seconds system, with peak child RSS
601,444 KiB.

The generation test recipes now reuse compiled objects within four distinct
flag sets: optimized plain, optimized threaded, sanitized plain and sanitized
threaded. Each executable retains its previous source subset, compile/link
flags and test commands. Source, shared-header and Makefile dependencies prevent
stale objects after relevant edits. Installation and demo compilation, runtime
build scripts, dependency pins, all eight normal/sanitized executables and the
five-/ten-minute CI timeouts remain unchanged. Cold normal and sanitizer runs
separately qualify the revised build before implementation acceptance.
An independent old/new dry-run comparison expanded every object back to its
source and verified all 17 executable targets (eight normal, eight sanitized
and the unchanged demo) retain ordered per-source flags, link flags, source
order and execution commands. The twenty generation objects are separated by
all four flag contracts and depend on their source, Makefile, all 26 shared
headers and their variant directory. `clean` removes only the new dedicated
cache in addition to its existing cleanup. Makefile SHA-256 is
`efe0ce424c8f5782d8001627f00a6ed582fe5fd307bd8e0c7cf6ab8a7be8ebdb`.

The revised cold serial normal run passed all eight executables in **211.158
seconds**, exit 0, under the unchanged 300-second bound. Semantic grammar
reported **77,480 assertions** and typed fields **14,162 assertions**. The run
used a new empty output directory, unchanged input hashes and the same GCC 13.3
flags; peak child RSS was 601,372 KiB. Its normal compiler warnings in the
preexisting C API are not sanitizer diagnostics or failed assertions.

The revised cold serial sanitizer run passed all eight executables in
**546.001 seconds**, exit 0, under the unchanged 600-second bound. Semantic
grammar again reported **77,480 assertions** and typed fields **14,162**.
It used another new empty output directory, unchanged input hashes,
`ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1` and
`UBSAN_OPTIONS=halt_on_error=1`; peak child RSS was 928,972 KiB. No sanitizer
runtime diagnostics appeared. Leak detection was explicitly disabled. Both
cold measurements used default serial make with inherited `MAKEFLAGS` and
`MFLAGS` removed and ran concurrently on the same local host. These observed
times qualify that host; hosted CI retains its own independent timing gate.

The complete socket fixes, expanded tests and build-object reuse were published
as [`23ca883f81bd7eac9498b8271359ffc8099bf809`](https://github.com/techrote/cybersand/commit/23ca883f81bd7eac9498b8271359ffc8099bf809),
tree `b8535961d52d9dee0cbb014db1ba59ee3dba2d95`, based on the earlier runtime
publication `77d24cf2aa40d7e6d92529c9eb308a20a33cdf78`. Its frozen source and
test hashes are the final socket identities above; the runtime build scripts
and toolchain pins did not change.

## Final source-matched runtime publication

[Publication run 39562462805](https://github.com/techrote/cybersand/actions/runs/39562462805)
completed all four jobs successfully against source
`23ca883f81bd7eac9498b8271359ffc8099bf809`, source tree
`b8535961d52d9dee0cbb014db1ba59ee3dba2d95`:

| Job | Executed scope |
|---|---|
| [Linux build and execution](https://github.com/techrote/cybersand/actions/runs/39562462805/job/119096712830) | Pinned GCC 13.3/binutils 2.42 build, unchanged compatibility floor, Godot import and all five focused cases |
| [Windows cross-build](https://github.com/techrote/cybersand/actions/runs/39562462805/job/119096712526) | Pinned LLVM-MinGW 20260826 UCRT/Clang 23.1 build |
| [Actual Windows execution](https://github.com/techrote/cybersand/actions/runs/39562462805/job/119097995767) | Windows x86_64 Godot import and all five focused cases |
| [Pair publication](https://github.com/techrote/cybersand/actions/runs/39562462805/job/119099442794) | Validated bundle hashes, source lease, LFS pointers and two manifests; published only the two runtime binaries and their manifests |

Both execution jobs used pinned Godot 4.7 and passed the workbench, scalar fields,
typed fields, hierarchical grammar and world-generation rendering cases with
**138 / 271 / 394 / 438 / 23 assertions**, respectively, zero failures and no
required skips or diagnostic errors. Linux retained the existing bundle floor:
GLIBC 2.34 overall, CyberSand GLIBC 2.32 / GLIBCXX 3.4.30 / CXXABI 1.3.9 and
Rapier2D GLIBC 2.34. This publisher establishes its recorded target-OS headless
scope; full graphical and repository acceptance remains separately gated.

The publication commit is
[`33e782dcf2a3d4062d410964f1f80157f1ee5e99`](https://github.com/techrote/cybersand/commit/33e782dcf2a3d4062d410964f1f80157f1ee5e99),
tree `fdcc98a3e2d96bffa797e8a435c35302f695086a`, with the built source as its
single parent. Its materialized runtime identities are:

| Platform | Bytes | SHA-256 |
|---|---:|---|
| Linux x86_64 | 2,912,480 | `9cc482b9d6be23e23adc8ce784929d34e0fd2c36b2c5b51696df53ec1a3e546f` |
| Windows x86_64 | 3,429,376 | `df9f098bcd431c8c37620bb9643cfe686dbfd07b8966d42fc0360e22180318a7` |

After fetching the publication, `check_repository.py --require-materialized`
passed with all eighteen runtime files materialized and no source/build-input
or artifact-identity errors. `git lfs fsck`, the Linux floor check and historical
M11 integrity (18 records, 28 retained source hashes) passed. Documentation
validation reported 97 documents, 189 canonical claims, 2,002 local links and
152 anchors, with zero errors or warnings. The final retrieval evaluation kept
the frozen 32-question result at 21 hit@1 / 32 hit@5 / MRR@5 0.7953; the expanded
97-question supplementary set returned 75 hit@1 / 97 hit@5 / MRR@5 0.8698.

## Exact-head acceptance record

The source implementation, focused local controls and both published runtimes
are qualified above. The final evidence-only commit preserves every recorded
source and build input. Its exact accepted head, full hosted workflow/job links
and merge disposition are recorded on [PR #196](https://github.com/techrote/cybersand/pull/196)
so that adding the final receipts does not create a new untested source head.
Merge requires actual successful execution of Documentation/provenance, Native,
GDExtension Linux and Windows, and the applicable Issue #49 Water apparatus
workflow on that exact head. A skipped draft, required skipped case, script
error or stale runtime manifest does not satisfy acceptance. Historical local
and publication receipts above retain their original source/platform scope.

## Explicit scope limits

The planner builds a finite authored window of canonical regions. It does not
introduce a resident-world streaming manager, player-edit reconciliation or
unbounded neighbor discovery. Region plans and shared ports can be produced
without requesting the adjacent storage chunks. Structural routes are checked
against a declared geometric clearance profile; they do not establish trained
or scripted actor success, gravity-aware navigation or post-simulation stability.

Semantic depth projection remains GEN-005, the full authoring/quality editor
remains GEN-007, and persistent runtime streaming/reconciliation remains GEN-006.
