---
title: MAT-AUTH-001 353-B Main display-name migration and scoped proof transition
status: Current
document-kind: evidence
scope: Bounded labels-only candidate, independent old-source oracle, scoped current proofs and apparatus transition; draft independent-review handoff with no merge or physics change
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [../operations/material-catalogue-shadow.md, ../architecture/material-authoring-catalogue-plan.md, 2026-11-04-mat-auth371-integration.md, ../reference/validation-evidence.md]
---

# MAT-AUTH-001 353-B display-name qualification — 2026-11-04

**Checkpoint: implemented candidate with local qualification, for draft
independent review only.** The owner assigned only Main's
generated display-name authority, scoped current proof receipts and the new
executable dependency in current MicroScenario fingerprints. The
[canonical guide](../operations/material-catalogue-shadow.md#bounded-main-display-name-authority--2026-11-04)
and [architecture section 14](../architecture/material-authoring-catalogue-plan.md#14-bounded-main-display-name-consumer-and-proof-transition--2026-11-04)
own the implementation/admission contract. This record preserves observed
working-source results. The accompanying draft-PR ledger identifies the final
committed head/tree, fresh current receipts and the retained evidence packet;
a receipt cannot attest the identity of a commit that contains itself. This
record authorizes no merge.

## Source intake and isolated ownership

| Identity | Verified source |
|---|---|
| Accepted main, fetched again at intake | `7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1` |
| Accepted tree | `36ce5a01e754a141c321f41cac7f1c6b6059c371` |
| Qualified #371 head | `d9284cc72a52dc46b5c73f182843d5d0c1602df1` |
| Frozen 27-owner legacy authority | `0fd4af5987e77db4da3e37c757cf2c0917ae9e15` |
| Dedicated feature branch | `feat/mat-auth-353b-display-names-20261104` |
| Final candidate head/tree | Recorded in the accompanying draft-PR ledger after committing this checkpoint |

Main had not advanced from the reviewed source at intake. The
[#371 final ledger](https://github.com/techrote/cybersand/pull/371#issuecomment-6620789829)
matches the accepted A-only baseline. Source changes are confined to a new
isolated worktree; no other worker's branch is modified or imported.

| Active work observed at intake | Head and actual diff boundary |
|---|---|
| [#358](https://github.com/techrote/cybersand/pull/358), draft | `7383946a3ed384966e9e5fb72553fc267f9aacb7`; 94 changed files; expanded experimental 132–137 remain unmerged |
| [#347](https://github.com/techrote/cybersand/pull/347), draft | `957ce67df859315ed238b6bbec1eebc9a743aaba`; 1,232 changed files; overlaps protected native owners, untouched here |
| [#370](https://github.com/techrote/cybersand/pull/370), draft | `fbe82bcab8f821aac442c2bf59eb57b279717873`; 154 changed files; Main overlap, with `material_name` unchanged at that head |
| [#162](https://github.com/techrote/cybersand/pull/162), open | `19f7ff43ecc494185226d1fff07dc21ef4a220fb`; 24 changed files; World/quantity ownership remains separate |

Issues #354–#356 remain open and outside this implementation. These observations
are an intake snapshot, not future merge permission. Recheck accepted main and
overlapping diffs before any integration. An accepted expanded catalogue requires
a new scope decision; the B executable-source admission must also be reviewed
when another accepted change touches its inventory.

## Independent legacy oracle and actual old application

The fixture is independently reconstructed from accepted Main's 80 literal
match arms and CellWorld's 51 building labels. It authenticates both original
Git blobs and the accepted tree, without reading the new generator or authored
presentation data. It covers 256 byte IDs plus 21 signed/large edge values,
including both signed 64-bit limits and values around 2^53; IDs are decimal strings
to avoid JSON floating-point loss. It also freezes 130 picker IDs and 8 group IDs.

| Frozen evidence | SHA-256 |
|---|---|
| `main-display-names-v1.json` | `f7c27a60ddd6185c78b2fcc1fab956a0496021024090b467b8071305239d30a1` |
| Original actual legacy probe `legacy-01.json` | `4836b29eef65d6e6c0044dd3e48a26ba8904ec2d0716dc4aaa3229a3625e5103` |
| Probe script used for that original run | `ad11e8789cb9fa474e84d0ac3d3534d5ea51d7913946c4d4fbbd00a949dfb531` |
| Original apparatus script-set identity | `627b902aee7d1c9820e896486c8942f112929a308db08df13e1e06d5e9e29860` |

Before changing Main, the actual Linux headless Godot 4.7 probe completed with
return code 0, **5,857 assertions and 0 failures**. It loaded detached actual Main
and the inherited Web controller, called real UI methods with synthetic UI
context, and recorded actual script/runtime identities. This is neither World
tick execution nor browser/Wasm or rendered-pixel qualification. The original
probe record retains its source and script hash when later probe controls grow.

## Candidate implementation and preserved authorities

Main's only change is a preload and its `material_name` method. A labels-only
resource and versioned presentation manifest are generated from the validated
canonical catalogue plus exactly five UI overrides. ID0, invalid10 and
signed/large unknown formatting retain the old returns; picker, secondary,
Worldgen, transport, shader, save, native and fallback consumers are unchanged.

| Generated artifact measured in this checkpoint | Bytes | Gate |
|---|---:|---:|
| `godot/scripts/generated/material_ui_names.gd` | 2,881 | <=16,384 |
| `materials/catalogue/presentation-manifest.json` | 1,729 | <=32,768 |

The labels resource SHA-256 is
`5b2cd4cacdac6a2af43f93eb9f60b63610d3055aa6748d7c47b9c17c44f29fdb`.
The manifest records its generator/parser and authored-source custody, with
explicit LF normalization for source fingerprints and exact output bytes.
Re-run its nonwriting check after any generator edit; this table is measured
evidence, not a predeclared budget success.

The canonical catalogue, original compiler, four original full-shadow outputs,
native sources and compatibility lock are preserved. The protected catalogue
digest stays
`82b5ab9a6e87ae817072390105052f8a5ac6d0ee22b3301cd973efdfc7fdbad3`;
the capability digest stays
`33c608f875e3d8b5730f1d3b81a54dbeff9579b433e061535610a8bfa276e237`;
the lock SHA-256 stays
`8b4d3351cbe4380e976655d10dc34c4bf9e81d95442719a53770b62d219183dc`.
There is no change to 132 slots, invalid10, 101 hard / 9 granular memberships,
15 descriptor fields, 56 pair / 19 specialized ordinals, endpoint/write order,
Cell/epochs/state, fallback Slush density 1100 or native Slush density 1080.

## Runtime equivalence and adverse controls

The initial candidate Linux Godot run completed with return code 0,
**5,861 assertions and 0 failures**. All 16 compared old/new UI-surface groups
were equal. Its additional checks are recorded separately from the original
5,857-assertion probe; an assertion-count difference is not a changed label.
The source-qualified final receipts are separate from these initial records.

| Actual application control | Observed result |
|---|---|
| Main and inherited Web-controller returns and UI surfaces | Candidate pass; 277 names per controller, picker/selection, HUD, Tower, transport and workbench/export surfaces checked |
| Poison one generated ordinary Sand label in an isolated copy | Return code 1 with 49 intended failures; both actual controllers return `poisoned sand` |
| Restore old Main/identity and remove generated resource in an isolated rollback copy | Return code 0 and 5,861 assertions; original apparatus set restored |
| Old/new source-set comparison | Refused or ineligible under the existing comparison contract |

The poison is routed through actual loaded Main/inherited-controller methods,
so an unused decorative preload cannot satisfy the proof. The candidate
generated-output guard also refuses the poisoned resource. The rollback is a
control, not an assertion that an old route passes a current B source guard.

## Independent review correction and current proof custody

Initial independent review reproduced a second consumer outside `godot/scripts`
that escaped the first source-admission inventory, including an autoload route.
The correction authenticates the full declared native/Godot executable and
scene/configuration source inventory against accepted Git. It permits only the
exact Main change, new resource and identity dependency. Fresh isolated
outside-scripts, addon, embedded-resource, autoload and native indirect-import
controls now refuse those changes; 15 display-contract tests pass, including
refusal to copy a fixture into the task's own source tree, and an
independent rerun closes the original reproduction. This is a B admission
boundary, not a refreshed 27-owner legacy lock.

The focused generator suite passes 21 tests, including complete-input rejection,
nonwriting checks, deterministic output, source/parser drift, aliases and
rollback after a failed second output replacement. The separately reviewed
Godot native-receipt reader passes 22 tests and current source-custody helpers
pass 5 tests. These counts describe observed focused suites; final complete-suite
counts and resulting-source commands belong in the final qualification ledger.

Current compatibility/native/Godot-shadow receipts use schema v2 with separate
native-runtime, full-shadow and UI-label authority scopes. Native/shadow proofs
explicitly do not qualify actual UI behavior and require a separate
`cybersand.material-catalogue.display-consumer` schema-v2 report.
Checked source inventories, parser/oracle hashes, report-input custody and
post-probe rechecks remain mandatory. Historical v1 reports/readers stay in
retained Git and dated audit paths and are refused as current B proof.

The repeatable B driver also completed a four-stage precommit run: legacy
5,857/0, candidate 5,861/0, poison 5,861/49 with the intended nonzero process
code, and rollback 5,861/0. This driver uses `SAND` as its isolated ordinary-label
poison; the earlier `poisoned sand` run above retains its separate identity.
Its reader requires every stage, both actual controllers, complete UI records,
source manifests, process codes, raw/log hashes and current parser/runtime/source
custody. A reproduced late-input verification gap was corrected and independently
closed with changed/deleted raw records, receipt, editor and archive controls.

The first driver attempt was refused because Godot reloads JSON numbers as
floats in the embedded previous-report comparison identity. The correction
expects that exact readback representation only at the cross-report boundary;
original raw schema types and all signed64 case strings remain strict. The
failed attempt and subsequent complete run are retained separately. Synthetic
reader fixtures test adverse handling and do not constitute runtime evidence.

## Affected application regressions and measured toolchain

All eight affected existing Godot scripts passed in the isolated candidate
project, with return code 0, no engine errors, no source-input drift and no
timeouts. The five scripts that report numbered assertions total 10,275; no
assertion count is invented for the other three.

| Existing test under `godot/tests/` | Result | Measured seconds |
|---|---|---:|
| `test_transport_profiles.gd` | UI and transport controls pass | 2.24 |
| `test_building_material_integration.gd` | 1,091 assertions, zero failures | 3.53 |
| `test_web_demo_setup.gd` | Constructor/native/CYSD1 controls pass | 1.17 |
| `test_experiment_tower.gd` | Recipe, landing, plug, rejection, reset and single-step controls pass | 4.88 |
| `test_microscenarios.gd` | 8,858 assertions, zero failures | 156.67 |
| `test_microscenario_materials_lab.gd` | 233 assertions, zero failures | 43.80 |
| `test_microscenario_controllers.gd` | 55 assertions, zero failures | 5.64 |
| `test_microscenario_workbench.gd` | 38 assertions, zero failures | 31.14 |

The retained `qualification-summary.json` SHA-256 is
`4b6382e55bb63ab13888d7349c1683a703abb3f4eadc03e627d342dd665bf4b4`;
the full 751-file copied-input manifest SHA-256 is
`7fc1e300e130f7e976f08f40c518acae656c6f4f37b1aa1458dc208c1ba656d3`.
That manifest includes the injected probe and a preserved, unused LFS transfer
residue; the final source comparison identifies them explicitly. Actual tested
application bytes remain the authority, not the dirty checkout's unchanged
`7ef4856e` HEAD alone. Each invocation retains its exact command, exit code,
watchdog, logs and measured source/runtime identities.

The existing suite used unchanged scale-1 repository limits of 1,200 seconds
for editor import and ordinary cases, and 300 seconds for the focused operation.
An exploratory `test_seconds` lookup returned code 2 because that unit does not
exist; the actual replacement was `ordinary_case_seconds`, recorded before the
runs. No watchdog was widened. The new B driver deliberately uses its tighter
local 240-second import and 180-second display-probe limits.

The environment used Python 3.12.14, GCC C++ 13.3.0 and Git 2.51.1. Godot is
`4.7.stable.official.5b4e0cb0f`, authenticated against the pinned archive:

| Actual checked artifact | Bytes | SHA-256 |
|---|---:|---|
| Godot archive | 75,664,355 | `0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c` |
| Godot executable | 144,186,224 | `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75` |
| Published Linux CyberSand native library | 4,222,424 | `0f60213c7fc3f9a1b1d7ad5143fdb22d453a452cddefd3fe4d7a7cb4d7b6cf45` |

The application tests reused measured, materialized published libraries. No
fresh GDExtension build or Windows execution is claimed. The standalone native
metadata oracle was compiled locally; it is a separate executable and scope.

## Supplementary retrieval qualification

The frozen32 and challenge157 fixtures remain byte-identical to accepted
`7ef4856e`. Only the revision-sensitive first-question facts and version/scope
metadata changed in the existing supplementary fixtures; their queries,
canonical/source routes and all other questions remain unchanged. Evaluations
over 119 documents and 1,599 chunks returned code 0: MAT-AUTH v4 scored
hit@1 **5/10**, hit@5 **10/10**, MRR@5 **0.7167**; MAT353A v3 scored **7/8**,
**8/8**, **0.9375**; the separate six-question MAT353B v1 fixture scored
**5/6**, **6/6**, **0.9167**. The receipts and full contexts are temporarily
under `build/retrieval/mat-auth-353b-followup/` as `architecture.json`,
`shadow.json` and `display.json`, retained with the evidence packet.
Lexical canonical hits do not establish complete answer sufficiency:
MAT-AUTH-01 still retrieves historical sections without the precise accepted
revision fact in its top five; MAT353A-01's current accepted-A/bounded-B
qualification appears at rank 3, and MAT353B-06's current draft/no-merge and
expanded-domain stop boundary appears across ranks 2 and 4. No query was
retuned to improve these results. The inherited USABLE02 challenge miss and
its unrelated owner remain untouched.

## Apparatus identity and final handoff gates

| Current candidate executable identity | SHA-256 |
|---|---|
| Main script | `ddd25833a49c219a1805ff3cee131b6a8efb9f80dcff8e0eafe047f58f155bca` |
| MicroScenario identity script | `375f5196bc55822c9fd0cbad2e3f080f0b42b97b55f2f230d25ee49d114e0534` |
| Apparatus script set, now 23 entries | `c4c2642a0def2a77e1e68f438736948e57b0c64e0c8d2da9ebbb5d821db10243` |

The generated resource is deliberately included in `SOURCES`. The new script-set
hash differs from the frozen old set, and old/new comparison refusal remains
intact. Historical captures and receipts are not rewritten. Runtime binary
hashes must be copied from actual checked files; unchanged native source is
not evidence of equal binary bytes.

The draft-PR ledger records the final committed source head/tree, complete
changed-file list, current scoped receipts, actual B consumer report, required
local command return codes, toolchain identities and evidence-packet hash.
Current reports are produced after the source commit and retained outside the
tracked tree, keeping their strict head/tree/source-context checks meaningful.
The packet preserves raw observations, logs, per-file inventories, independent
review and failed development attempts; no historical report is rewritten.

The final local ledger includes compatibility/compiler/presentation/oracle/B
checks, the complete material-catalogue unit suite, native parity and Godot shadow
readback, all five requested LCB contract checks, documentation, historical M11,
repository/materialized-LFS provenance, CI-provider policy, retrieval and
whitespace. Initial local runs of the requested checks passed; resulting-source
status and counts must be read from the final ledger rather than inferred.

Independent review should authenticate the exact published head and retained
packet, rerun current receipt verification, inspect the single approved consumer
route and guard refusals, and assess the stated platform/fixture limits. Full
ready-state Native/GDExtension/Water/backend matrices, Windows/browser execution,
rendered pixels and human UI acceptance remain unqualified. Expensive hosted
lanes stay suppressed while draft. No merge, #353/#352 closure, #356
implementation or unrelated branch reconciliation is authorized.
