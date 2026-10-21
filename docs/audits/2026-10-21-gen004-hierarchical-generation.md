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
Both JSON files parsed and the whitespace check passed. Full JSON Schema
evaluation was not run: the local Python environment did not provide the
`jsonschema` package. This does not qualify recipe execution, which requires the
native compiler and adapter controls recorded separately.

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

## Acceptance status at documentation preparation

The implementation is in progress. The narrow local example inspection above is
recorded separately from the complete local native/adapter suite above. Runtime
publication and exact-head hosted gate receipts remain to be added here.
Required skips, script errors or stale runtime manifests
will not be counted as passes. The implementation PR must record recoverable
source checkpoints and the final disposition before issue closure.

## Explicit scope limits

The planner builds a finite authored window of canonical regions. It does not
introduce a resident-world streaming manager, player-edit reconciliation or
unbounded neighbor discovery. Region plans and shared ports can be produced
without requesting the adjacent storage chunks. Structural routes are checked
against a declared geometric clearance profile; they do not establish trained
or scripted actor success, gravity-aware navigation or post-simulation stability.

Semantic depth projection remains GEN-005, the full authoring/quality editor
remains GEN-007, and persistent runtime streaming/reconciliation remains GEN-006.
