---
title: MAT-AUTH-001 353-A shadow compiler and compatibility qualification
status: Current
document-kind: evidence
scope: Owner-requested candidate tooling, immutable-source guards and independent metadata parity; no production cutover, new material semantics, physics qualification or merge
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [../operations/material-catalogue-shadow.md, ../architecture/material-authoring-catalogue-plan.md, 2026-11-03-mat-auth-000-architecture-review.md, ../reference/validation-evidence.md]
---

# MAT-AUTH-001 353-A compatibility qualification — 2026-11-04

**Disposition: bounded #353-A implemented and qualified as an unconsumed
candidate.** The owner requested implementation of the review's corrections
and compatibility mitigations. This checkpoint supplies the narrow first
migration proposed by the [3 November review](2026-11-03-mat-auth-000-architecture-review.md):
a deterministic compiler, independent native oracle, explicit capability maps
and guards against unintended production or identity changes. The
[operational guide](../operations/material-catalogue-shadow.md) owns usage.

Production native/GDScript definitions, movement, chemistry, thermal behaviour,
scheduling, Cell layout, save/transport/receipt formats and existing generated
LCB policy data have no changes. #357 remains its separate draft documentation
PR. This implementation is a stacked draft, not a merge into #357 or an adoption
of the entire proposed architecture. Broad #353 remains open; #353-B consumer
switches and #354–#356 semantics require separate admission and evidence.

## Source custody and scope

| Identity | Exact retained source |
|---|---|
| Accepted main, revalidated live 4 November | `0fd4af5987e77db4da3e37c757cf2c0917ae9e15` |
| Original architecture intake | `a8f08a67fea3c58f6df7473cbae1831334fcc04e` |
| Original #357 proposal | `fc7f74768bb3d24fb7e913615f6774dbff321f91` |
| Revised #357 head and implementation parent | `9b776d109e7843fb9b2d25239f9d088181309aa1` |
| Pinned companion documentation | `6a58311982941b75f46e22109a0829e5acb83c7e` |

The implementation branch is `feat/mat-auth-353a-compatibility-shadow-20261104`.
The final published commit and hosted results are recorded in its PR; the
in-tree evidence is bound to exact source/input hashes rather than a circular
claim about its own eventual commit. Original proposal sections 1–11 and all
historical audit records are unchanged. A separately dated section 12 records
the narrower owner authorization. Existing frozen32, challenge157 and
MAT-AUTH-000 question fixtures are unchanged.

The [native receipt](mat-auth-353a-20261104/native-parity.json) contains every
protected source, compiled command, candidate input and checker hash. The
[Godot receipt](mat-auth-353a-20261104/gdscript-parity.json) binds that complete
native receipt, the native snapshot, generated GDScript, checker and pinned
editor. Neither receipt asserts World execution or physics qualification.

## Implemented corrections and hazard mitigations

| Hazard | Implemented mitigation | Remaining production boundary |
|---|---|---|
| Newly appended powder inherits hard terrain from an ID range | Explicit 256-entry capability map; isolated synthetic132 is explicitly non-hard and supports granular load; no default or range inheritance | Original production range predicate stays byte-identical. Guard rejects production changes; #353-B must separately switch the consumer with compatibility evidence |
| Native metadata accidentally replaces different fallback behaviour | Generated GDScript explicitly identifies native-only shadow facts; source-observed fallback facts are separately locked | Slush1080 native versus1100 fallback remains; no fallback movement or pixel-equivalence claim |
| Formatting-only generated headers invalidate LCB identities, policies or save admission | Authenticate27 owner files against immutable accepted Git history before accepting editable lock hashes; retain exact LF-normalized bytes and existing digests | No header substitution, parser rewrite, identity refresh or stale-policy relaxation is admitted |
| Generic schema hides specialized kernels, state effects or precedence | Preserve56 pair slots and19 specialized provenance slots; compare actual native resolver outcomes; reject active generic layers and implicit defaults | World's hand-coded endpoints, retained state, quantity accounting and scheduler remain authoritative |
| Family overlap silently changes physics | Membership is data only; explicit keys/slots determine canonical order; ambiguous pair ownership reports both origins | No semantic family supplies physical defaults; no effective-parameter precedence or new endpoint law is introduced |
| Synthetic fixture consumes experimental identities | `isolated-synthetic` requires a separate flag and output outside the repository; fixed synthetic name and explicit capabilities | #358's six branch-qualified132–137 claims are recorded without promotion, integration or production reservation |
| Tooling reports overwrite authoring or omit stale inputs | Reject output/input aliases before execution and again before publication, including symlinks/hardlinks; require exact native-receipt inventories before and after Godot readback | Tools are local build utilities, not concurrent or hostile-filesystem publication services |

The first schema has one explicit input and standard-library Python only. It
does not introduce imports, macros, expressions, property inheritance, runtime
loaders, editable physics or a consumer API. It validates versions, strict JSON
types, bounds, enum domains, identities, aliases, references, conflicts and
legacy slot order before writing. Errors identify the source file and JSON
pointer, both origins for conflicts, and line/column for JSON syntax errors.

Generation emits four reviewable artifacts with stable ordering, UTF-8/LF,
final newlines, deterministic escaping and no absolute paths or timestamps.
`--check` is nonwriting. Unchanged artifacts retain bytes and mtimes; a failed
validation preserves previous output. Staged directory publication rolls back
ordinary rename failures. It is not a crash-durable or concurrent-writer API.
The C++ inspection structs use their own namespace/layout and are not ABI
substitutes for native material descriptors or Cell.

## Executed native and Godot evidence

The independent C++ oracle compiles the unchanged native headers and
`material_rules.cpp`; expected values are not generated from authored JSON.
A second executable compiles the candidate header and uses an independent
interpreter. Both complete snapshots and the following pure queries pass:

| Checked domain | Exact extent |
|---|---:|
| Descriptor records | 132 allocated slots ×15 fields;131 valid identities; reserved10 retained |
| Byte-ID descriptor/capability responses | 256 each |
| Compact pairs / specialized metadata | 56 /19, exact legacy ordinals |
| Families / explicit memberships | 7 /33 |
| Coverage records / tuning passes | 10 /2 |
| Native pair resolver | 16,777,216 source/target/roll cases |
| MaterialRules pair wrapper | 16,777,216 cases |
| Viscosity | 16,777,216 cases |
| Appearance projection | 17,170,432 cases |
| Density exchange | 327,680 cases across five signed64-bit deltas |
| Validity / lateral rates | 65,536 each |
| Family membership / layer-kind byte inputs | 2,048 /256 |

The retained snapshot SHA-256 is
`58d22545a1f29e49a8c141cb1c5df84101e48ed457fbaaaec09937997c2ce802`.
Source-qualified fallback checks match132 RGBA values,101 hard-surface IDs,
nine granular-support IDs and131 valid identity values. They separately retain
the known Slush density distinction rather than asserting all density parity.

Actual Godot `4.7.stable.official.5b4e0cb0f` loaded the entire generated native
metadata in a temporary empty project and returned facts equal to the native
snapshot. The complete editor ZIP is75,664,355 bytes, SHA-256
`0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c`.
The executable is144,186,224 bytes, SHA-256
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`.
The helper verifies both against the repository pin and authenticated ZIP
entry. No production project, native extension, rendered pixels or fallback
simulation was loaded. An earlier truncated71,057,408-byte local ZIP was
refused; it was not accepted by relaxing its pin or rewriting old evidence.

Native/GDScript input and tool hashes are checked again after execution. A
concurrent source-guard edit during an earlier probe correctly caused a
post-check custody failure; the final retained receipt was produced after
the tool sources settled. Negative controls changed authored Slush1080 to1081
and independently changed only the generated header: both failed at the exact
density path. Reversing authored identity-bearing arrays preserved all facts
and passed. [Retained negative-control outcomes](mat-auth-353a-20261104/adverse-controls.json)
keep their original temporary-path diagnostics.

## Tooling cost and rollback

| Static source/output | Bytes |
|---|---:|
| Authored catalogue | 195,969 |
| Compatibility lock | 15,569 |
| Candidate C++ | 53,002 |
| Candidate GDScript | 180,360 |
| Inspection JSON | 215,517 |
| Deterministic manifest | 877 |
| Total above | 661,294 |

On this Linux x86_64/glibc2.39 shared host, GCC13.3/C++20 `-O2` compiled the
original probe in1.360326s and candidate probe in2.001653s; candidate validation
took3.454651s. Probe binaries were78,168 and148,992 bytes. Actual Godot metadata
readback took0.282860s. These are one local tooling run's measured costs, not a
simulation benchmark, cross-platform claim or controlled performance study.

No production target includes these candidate tables, so this checkpoint adds
no linked catalogue storage, tick-time lookup, allocation or per-cell field to
the engine. Future consumer storage, incremental engine rebuild costs and
physics performance are unmeasured and remain separate gates. Source output
size is explicit rather than treated as runtime storage. Reverting the tools,
candidate files, documentation routes and added CI step restores the previous
workflow without save conversion or World rollback.

## Checks and independent review

Executed from the implementation checkout with its pinned companion present:

| Check | Command or evidence | Result |
|---|---|---|
| Compatibility custody | `python3 tools/material_catalogue/compatibility.py --check` | PASS;27 immutable owner inputs; existing catalogue and capability digests unchanged |
| Generated drift | `python3 tools/material_catalogue/compiler.py --check` | PASS; all four candidates byte-identical |
| Focused adversarial suite | `python3 -m unittest discover -s tools/material_catalogue -p 'test_*.py'` | PASS;98 tests in5.977s:48 compiler,22 compatibility,13 native report paths,15 Godot receipts/output paths |
| Independent native oracle | `python3 tools/material_catalogue/check_native_parity.py --output build/material-catalogue/native-parity.json` | PASS; exact retained receipt linked above |
| Actual optional Godot readback | Guide's pinned-editor command with matching snapshot/native receipt | PASS; complete candidate dictionary, native backend only |
| Existing LCB contracts | Capability, wire/hash, native artifact, normalization and run-receipt `--check` commands | PASS; retained policy identities and vectors unchanged |
| Repository/provenance | `python3 tools/ci/check_repository.py --require-materialized` | PASS;18 actual LFS payloads verified, no runtime execution |
| Historical M11 | `python3 tools/ci/check_m11_consistency.py` | PASS;18 records and28 hashes at `05ea45fda7bdd7b0150eb86c4922c202e89e08f4`, no new engine evidence |
| CI scope | Provider policy and scheduling policy checks; ten scheduling tests | PASS;27 existing workflows, no new runner/provider or expensive draft lane |
| Documentation | `python3 tools/ci/check_docs.py` | PASS;119 documents,3,558 local links,671 heading anchors,32 frozen question references |
| Retrieval, focused audit links and whitespace | Final-source checks below; `git diff --check` | PASS with disclosed lexical ranking limits |

The existing Documentation workflow now runs the four shadow checks under the
existing operation watchdog and uploads the native JSON receipt for90 days.
Optional actual Godot readback is not added to CI or made a download dependency.
Draft suppression of expensive Native/GDExtension/Water jobs is unchanged.
Hosted exact-head results are recorded separately in the draft implementation
PR; local checks are not represented as hosted or full ready-for-review CI.

Independent read-only review found and reproduced four tooling defects during
the implementation pass: the import guard omitted native `.inc` files, native
report output could alias a checked external input, and the optional Godot
receipt could omit inventory rows. A subsequent reviewer also reproduced a
late output alias overwriting an external Godot input after verification.
All were corrected with regression tests, including a second explicit-input
check immediately before publication. The final reviewer reran the original
late-alias reproduction and observed refusal with all input bytes/mtimes intact.
The source-ancestor output refusal and ordinary rename-failure rollback were
also independently exercised. The finalized compiler, native oracle, backend
distinction and production exclusion received separate review; the retained
 [review receipt](mat-auth-353a-20261104/independent-review.json) records exact
file identities and limits. The final implementation review is PASS for this
bounded candidate, not production adoption or physics qualification.

Final retrieval used119 documents and1,587 heading chunks. The frozen fixtures
were not rewritten. The new eight-question fixture was fixed before guide
refinement; initial results were5/8 top1 and6/8 top5. Meaningful subsection
headings and explicit compatibility qualifiers improved the final routes:

| Fixture | Reviewed #357 hit@1 / hit@5 / MRR@5 | Final candidate |
|---|---|---|
| Frozen32 | 19 /32 /0.7536 | 19 /32 /0.7536 |
| Challenge157 | 124 /156 /0.8739 | 123 /156 /0.8702 |
| Separate MAT353A8 | New fixture, no predecessor comparison | 7 /8 /0.9375 |

ACT14's canonical route moves1→2 and RENDER-COPY-01 moves3→4. For each,
the same five complete context strings are retained, only reordered. The
existing LCB03 top-five miss remains. This is a disclosed lexical-ranking
regression, not newly lost top-five content. No unrelated documents or question
wording were changed to tune these scores.

Independent expected-fact review finds all8 new questions complete across
their top-five contexts. MAT353A-01 needs ranks2 and5, MAT353A-05 ranks1 and3,
and MAT353A-06 the Current candidate at rank2; its rank1 is the older Planned
admission contract. A canonical top1 hit does not imply a complete top1 answer.
No candidate-to-production, fallback-to-native or metadata-to-physics status
substitution was found. The [retained complete new-question report](mat-auth-353a-20261104/retrieval-353a.json)
and [retrieval receipt](mat-auth-353a-20261104/retrieval-summary.json) bind the
guide, corpus, evaluator, fixtures, contexts and per-question review. These
development-set results do not establish unseen-query generalization.

## Remaining decisions

The original review remains **ACCEPT WITH CORRECTIONS** for the proposed
architecture, with corrections incorporated. This checkpoint implements the
admitted risk-reduction tooling; it does not select new semantics. Keep both
design and implementation PRs draft and unmerged pending owner adoption.

Before #353-B, choose each consumer migration and either preserve its exact
identity-bearing bytes/parser shape or explicitly version its policy/save
transition. Preserve alias/reserved IDs, specialized order and native/fallback
ownership. #354 needs actual liveness reproductions before scheduler changes;
there is no always-awake workaround. #355 must specify quantity creation,
consumption and retained endpoint state before new laws. Serialize shared
World/quantity edits under one integration owner. #356 can expose inspection,
but editable controls require a real native consumer and applied readback.
Spark-family meaning, same-ID preservation, MoltenGlass thermal behaviour,
viscous rest, #358 production IDs and save/ABI changes remain unselected.
