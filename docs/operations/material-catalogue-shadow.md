---
title: Material catalogue shadow compiler and compatibility guards
status: Current
document-kind: guide
scope: Accepted 353-A shadow tooling plus the separately assigned draft 353-B Main display-name consumer; native and fallback physics stay unchanged, with scoped current proofs and immutable historical evidence
canonical-for: [material-catalogue-shadow-compiler, material-catalogue-compatibility-guards, material-catalogue-authoring-workflow, material-display-name-authority]
last-reviewed: 2026-11-04
related-documents: [../architecture/material-authoring-catalogue-plan.md, ../systems/materials-and-rule-kernels.md, ../systems/intermaterial-interactions.md, ../architecture/liquid-solver-family-policy.md, documentation-maintenance.md]
---

# Material catalogue shadow compiler and compatibility guards

**Current on the #353-B candidate branch:** [#371's final ledger](https://github.com/techrote/cybersand/pull/371#issuecomment-6620789829)
records accepted A-only main
`7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1`. The owner separately assigned
the [bounded Main display-name migration](#bounded-main-display-name-authority--2026-11-04):
one labels-only generated consumer, scoped current proofs and an explicit
apparatus source transition. This assignment permits a **draft PR, no merge**.
Native and fallback physics retain their existing authority. The
[B evidence record](../audits/2026-11-04-mat-auth353b-display-names.md) owns actual
source, measured artifacts, runtime results and remaining review gates.

**Historical A-only integration framing:** the following adoption/reconciliation
paragraphs retain the scope that preceded accepted #371 and this separate B
assignment. Full-shadow metadata remains unconsumed in the B candidate.

The [adopted-main integration record](../audits/2026-11-04-mat-auth371-integration.md)
records the escaping correction, independent review and resulting-head gate
requirements. The PR ledger carries final hosted checks and merge identity.

**Current shadow tooling; guarded integration under qualification.** On
4 November the owner separately requested implementation of the architecture
review's corrections and compatibility mitigations. [PR #371](https://github.com/techrote/cybersand/pull/371)
contains that #353-A response: authored metadata, deterministic candidate outputs,
independent native parity and source-identity guards. Documentation PR #357 is
now merged and its corrected architecture is owner-adopted as Planned. The
shadow output remains unconsumed by production; broad #353 and parent #352
stay open, and #353-B consumer migration and #354–#356 remain separately
unadmitted.

The [architecture review](../audits/2026-11-03-mat-auth-000-architecture-review.md)
and [corrected migration contract](../architecture/material-authoring-catalogue-plan.md#11-current-main-review-and-implementation-admission--2026-11-03)
explain why matching values alone is insufficient. The
[current A-only reconciliation boundary](../architecture/material-authoring-catalogue-plan.md#13-bounded-compatibility-tooling-and-adopted-main-reconciliation--2026-11-04)
preserves original implementation `6d3737594beb39e83e555f66f2e81184a4bdbf77`
and its reviewed parent `9b776d109e7843fb9b2d25239f9d088181309aa1`, while
merging adopted main `3da7e7be4a6af4c85e03a7d8a0ed57229e5db33d` normally.
The frozen compatibility baseline remains
`0fd4af5987e77db4da3e37c757cf2c0917ae9e15`; adopted documentation does not
refresh any source lock. The [original qualification record](../audits/2026-11-04-mat-auth-353a-compatibility.md)
retains its tested source and historical status. The #371 ledger records new
resulting-head checks, review and actual merge/post-merge status separately.

## What the compiler owns

[`catalogue.json`](../../materials/catalogue/catalogue.json) is a versioned,
explicit authoring candidate. The [stdlib compiler](../../tools/material_catalogue/compiler.py)
has one input file, no import discovery, inheritance, expressions, family
defaults or runtime loader. Identity-bearing arrays normalize using declared
IDs, keys and legacy slots rather than authoring order. It emits inspection
metadata and C++/GDScript shadows under `materials/catalogue/generated/`.
No native target or Godot production script consumes that directory.
Production material physics and the existing generated liquid-policy artifacts
remain unchanged.

The records cover all 132 descriptor slots and all 15 descriptor fields,
explicit hard/granular capabilities, visual-state projections, the 56 ordered
compact pairs, 19 specialized provenance records, seven families and 33
memberships. Numeric enum encodings have fixed schema domains. Invalid10 and
the Gas/Smoke alias remain explicit. Specialized metadata does not replace
World's hand-coded execution, and the empty interaction-layer table remains
empty. Semantic memberships never supply physical defaults.

The GDScript shadow describes **native** metadata. It is not a replacement for
CyberCellWorld's different fallback simulation. Fallback source facts and their
qualification are recorded separately in the
[compatibility lock](../../materials/catalogue/compatibility-lock.json).
Candidate structs add inspection IDs/legacy slots and use primitive enum
encodings. Their layout is deliberately separate from the native ABI; exact
field/value comparison does not make them drop-in C API or Cell replacements.

## Compatibility protection and independent source authority

[`compatibility.py`](../../tools/material_catalogue/compatibility.py) authenticates
27 named legacy inputs against retained accepted main
`0fd4af5987e77db4da3e37c757cf2c0917ae9e15` before accepting their
lock entries, then compares the working source's LF-normalized bytes. Changing
both a source file and its recorded hash cannot silently establish a new baseline.
Missing historical Git objects, a missing owner, altered identities or an
unexpected production import of shadow output fail closed. The checker never
rewrites the lock, headers, policies, receipts, saves or candidate outputs.

The protected owners include material/interaction headers, native queries,
World movement/reaction/scheduling and quantity codecs, Cell storage,
transport policy, liquid admission/identity sources, fallback functions,
appearance code and retained policy/normalization/receipt vectors. This is an
explicitly frozen compatibility checkpoint, not a promise that these owners
can never change. A future source update needs a separately reviewed baseline
or cutover transition, with the old evidence retained.

The existing catalogue digest remains
`82b5ab9a6e87ae817072390105052f8a5ac6d0ee22b3301cd973efdfc7fdbad3`;
the capability digest remains
`33c608f875e3d8b5730f1d3b81a54dbeff9579b433e061535610a8bfa276e237`.
Formatting-only edits still count as changes under the established LCB
contract, except its existing CRLF-to-LF normalization. Stale-identity refusal
is preserved; it is not weakened to make candidate generation pass.

## Independent native parity for descriptors, reaction ordinals and capabilities

The [native oracle](../../tools/material_catalogue/native_oracle.cpp) is a
standalone metadata/query executable compiled against the unchanged source.
The [parity driver](../../tools/material_catalogue/check_native_parity.py)
compiles the generated C++ shadow and compares it to actual native records
and query results. Expected native facts do not come from the compiler.
This executes metadata and pure queries, not World ticks or physics scenarios.

The compiled comparison passes all 132 descriptors, all 15 fields, 256 byte-ID
capability and fallback responses, 56 pair rules and 19 specialized records
with exact legacy ordinals. It checks all 16,777,216 source-ID/target-ID/roll
combinations against both the native resolver and its MaterialRules wrapper.
The same bounded executable covers density-exchange direction, viscosity,
lateral rate, family membership, complete uint16 validity and visual projection.
These are actual pure-query checks; they do not certify World scheduling or
reaction state effects. Those production owners are protected by unchanged bytes.

## Native GDScript metadata and fallback Slush density

Native Slush density1080 and fallback Slush density1100 remain distinct. Fallback density,
identity, hard/granular and RGBA facts are source-observed, with no claim of
fallback movement or rendered-pixel parity. The unchanged Godot appearance
expressions retain their existing precision and startup behaviour.

The generated GDScript mirror contains native facts only and is not loaded by
CyberCellWorld. A separate optional [Godot metadata readback](../../tools/material_catalogue/check_gdscript_shadow.py)
authenticates the pinned editor archive and executable, requires a matching
native-parity receipt, and loads only the candidate in a temporary empty project.
Actual Godot 4.7 parses and reads all metadata; this is not a game-project,
native-extension, fallback-physics or rendered-pixel test.

Current schema-v2 receipts require the complete declared checker/oracle,
catalogue/mirror, consumer-source and protected-legacy inventories; missing,
duplicated, renamed or stale entries fail. The checker verifies those inventories
again after readback. The original schema-v1 receipts and their readers remain
historical evidence in dated audit paths and retained Git; v1 cannot satisfy
current B proof. The separate labels consumer report is mandatory and is not
produced by this shadow-parser check. Report paths cannot overwrite their
checked inputs. The original truncated-editor refusal and accepted pinned
readback retain their dated qualification.

## Validation, errors and deterministic publication

The compiler rejects unknown fields, duplicate JSON keys, unsupported versions,
non-finite values, booleans in integer fields, out-of-range values, invalid
references, alias/key conflicts, duplicate legacy slots and ambiguous pair
ownership. Errors include the source file and JSON pointer; conflicts identify
both origins, and JSON syntax errors also report line/column.

Unsupported defaults, state contracts or active interaction layers are rejected
instead of interpreted through implicit precedence. Valid inert
`RuleKernel::None` targets remain admissible: a reaction participant need not
own the tick that initiates its reaction. The compiler does not change wake
state, endpoint effects, solver selection or parameter consumption.

Output is UTF-8 with LF and a final newline, deterministic escaping and stable
ordering. No timestamp, local absolute path or directory order enters generated
content. `--check` is nonwriting; missing or stale output fails with a named
artifact. Validation completes before publication, and unchanged files retain
their bytes and modification times. Negative tests require failure to preserve
the previously accepted output set.

Run from a complete source checkout:

```text
python3 tools/material_catalogue/compatibility.py --check
python3 tools/material_catalogue/compiler.py --check
python3 -m unittest discover -s tools/material_catalogue -p 'test_*.py'
python3 tools/material_catalogue/check_native_parity.py
```

The native query check and the focused generated-C++ regression require a C++20
compiler; JSON generation and strict validation use Python's standard library.
CI reuses the existing hosted
Documentation workflow and execution watchdog. These focused commands do not
run World scenarios or require a Godot download; expensive draft lanes stay
suppressed. A later ready-state integration of the B tools/data/Godot changes
requires the applicable full Native and Windows/Linux GDExtension/Godot gates
under the existing path classifiers. A draft skip or metadata readback does not
satisfy those integration requirements. The present assignment stops at draft
independent review; record actual jobs and any skips in its PR ledger.

For optional actual Godot metadata readback, use a complete editor archive and
executable matching `third_party/godot-runtime.lock.json`. Produce a native
snapshot and receipt from the same source, then invoke the checker:

```text
mkdir -p build/material-catalogue
c++ -std=c++20 -O2 -I native/include tools/material_catalogue/native_oracle.cpp native/src/material_rules.cpp -o build/material-catalogue/oracle
build/material-catalogue/oracle --snapshot > build/material-catalogue/native-snapshot.json
python3 tools/material_catalogue/check_native_parity.py --output build/material-catalogue/native-parity.json
python3 tools/material_catalogue/check_gdscript_shadow.py --godot /path/to/pinned-editor --archive /path/to/pinned-editor.zip --native-snapshot build/material-catalogue/native-snapshot.json --native-report build/material-catalogue/native-parity.json --output build/material-catalogue/gdscript-parity.json
```

The helper does not download or modify the editor. Its temporary project loads
only the generated metadata. The native receipt's snapshot hash must match,
and its complete source/mirror inventory must still be current. This optional
engine parser proof is separate from the default documentation CI gate.

## Safe authoring workflow and experimental identities

Inspect the supported record contract, edit a copy of the authoring candidate,
run validation into a temporary candidate output root, and inspect the resulting
diff and diagnostics. Reordering input records cannot change meaning. Generated
metadata remains a proposal until the independent parity and source guards pass
and a consumer cutover is separately admitted.

## Synthetic powder ID132 and paired-material experiment isolation

Current production IDs0–131 remain fixed, with invalid10 unusable. The isolated
future powder at ID132 explicitly declares `hard_surface=false` and
`granular_support=true`; no numeric range can grant hardness in the
candidate map. Its test namespace cannot publish to the committed candidate
directory or export a production/save/receipt identity.

Draft #358's StoneWall132, SaltWall133, CoalWall134, DryBinder135,
ActivatedBinder136 and BinderCrust137 are recorded as **branch-qualified
experimental claims**, not accepted production reservations. A synthetic
fixture does not rename, consume or integrate those identities. Their production
allocation remains a separate integration decision.

The source-level range predicate in production remains unchanged in #353-A.
The candidate's explicit capability map fixes inheritance for the synthetic
registry; production source guards prevent silently appending an ID through
the old range. Switching the production predicate is a #353-B consumer change,
requiring its own parity/identity review and applicable integration gates.

## Production cutover, rollback and remaining decisions

#353-A alone adds tooling and unused candidate data only. Reverting its tools,
candidate directory, documentation routes and CI step restores the previous
development workflow; no save or World conversion is needed. Existing kernels
and policy artifacts remain the production authority throughout.

The Main display-name consumer has the separate bounded assignment below.
Every other #353-B consumer requires its own admission review. Preserve
the exact header bytes and parser-compatible form where they bind identities,
or design an explicitly versioned identity transition before changing them.
Revert a switched consumer and its generated route as one unit. A stale-policy
failure is evidence to resolve, not permission to update the oracle.

#354 still requires reproduced liveness cases; #355 still owns new endpoint
effects and their state/quantity contracts. Serialize overlapping World and
quantity writes under one integration owner. #356 may inspect accepted
metadata, but a slider requires an actual consumer and applied readback.
Source fields whose native path ignores them remain read-only/unused.
No Spark family, same-ID preservation, MoltenGlass thermal law, viscous rest,
new production ID, runtime editing or save/ABI decision is made by these tools.

## Bounded Main display-name authority — 2026-11-04

**Current candidate implementation; independent review and integration remain
separate.** Only [`main.gd::material_name`](../../godot/scripts/main.gd) changes
production ownership. It preloads
[`material_ui_names.gd`](../../godot/scripts/generated/material_ui_names.gd),
bounds-checks the signed material ID and returns its static label. ID0 remains
`"empty"`; reserved ID10, negative IDs and integers above 131 retain
`"material-%d" % material_id`. There is no runtime JSON, per-cell parsing or
silent fallback to the old table. Desktop HUD, inherited Web controller, Tower,
transport and MicroScenario callers still use the same public method.

[`presentation.py`](../../tools/material_catalogue/presentation.py) validates
the complete unchanged canonical catalogue and a separately versioned
[`presentation.json`](../../materials/catalogue/presentation.json). It normalizes
canonical hyphens to spaces and admits exactly these existing UI exceptions:

| ID | Exact display name |
|---:|---|
| 80 | `LED white` |
| 83 | `rough oak log` |
| 113 | `galvanised zinc sheet` |
| 117 | `bare iron plate` |
| 131 | `heat-shield tile` |

The resource contains labels only, with no global class name or native/fallback
physics fields. Semantic families do not become picker groups. Paintable IDs,
group ordering, selection/cycling, secondary material behavior, transport v1's
81-material schema, saves, shaders, Worldgen and native/fallback functions are
unchanged. The 132-slot domain, invalid10, native Slush density 1080 and fallback Slush density 1100
remain intact. ID132 is not admitted by the presentation schema.

### Generation and nonwriting checks

The only outputs are the labels resource and
[`presentation-manifest.json`](../../materials/catalogue/presentation-manifest.json).
They use deterministic UTF-8/LF bytes with a final newline. Input/tool fingerprints
explicitly normalize CRLF to LF; output hashes describe exact generated bytes.
The script budget is 16 KiB and the manifest budget 32 KiB; actual measured sizes
belong to the dated evidence. Unknown fields, duplicate keys, malformed or wrong
schema/types, changed identities and extra overrides fail before publication.
Outputs are staged before atomic file replacements, with rollback after a
publication failure. Unchanged outputs retain bytes and mtimes.

```text
python3 tools/material_catalogue/presentation.py
python3 tools/material_catalogue/presentation.py --check
python3 tools/material_catalogue/legacy_display_names.py --check
python3 tools/material_catalogue/check_display_consumer.py --check
```

The last three commands are nonwriting source checks. In particular,
`check_display_consumer.py --check` does **not** execute Godot or issue a current
runtime B consumer report. Documentation CI adds these source checks to the
existing compatibility/compiler/native metadata gate; expensive draft lanes
remain suppressed.

For the mandatory actual B consumer proof, freeze the source commit, materialize
its published Linux libraries, and select the pinned Godot executable and
archive. Use a new output path for each run:

```text
python3 tools/material_catalogue/check_display_consumer.py --godot /path/to/pinned-editor --archive /path/to/pinned-editor.zip --output build/material-catalogue/display-consumer.json
python3 tools/material_catalogue/check_display_consumer.py --verify build/material-catalogue/display-consumer.json --godot /path/to/pinned-editor --archive /path/to/pinned-editor.zip
```

The driver copies the actual project into isolated scratch space and runs
legacy, candidate, ordinary-label poison and rollback stages. It retains raw
observations, source manifests and import/probe logs beside the report in
`display-consumer.evidence/`. Neither destination may already exist. Verification
requires those actual files, current source custody, authenticated editor/runtime
bytes and all four stages; a metadata receipt or historical v1 report is refused.
The local display-probe bounds are 240 seconds per import and 180 seconds per
probe, tighter than the unchanged repository watchdog allowances. Execution
qualifies detached actual Main and inherited Web UI methods on Linux, with no
World, browser/Wasm or rendered-pixel claim.

Current receipts bind the exact checked Git head/tree and listed worktree
status as well as file hashes. A later documentation/evidence commit is a new
source context: do not relabel an earlier receipt as final-head qualification.
Keep final qualifying outputs outside tracked source and record their source
and hashes in the draft-PR ledger. Repository policy forbids committing logs,
toolchains, caches or archives; retained evidence packets remain separate.

### Separate authority and proof scopes

| Scope | Current authority | Required evidence |
|---|---|---|
| Native runtime and fallback physics | Existing protected legacy sources | Original 27-owner authentication and unchanged policy/quantity contracts |
| Complete native shadow | Unconsumed original full-shadow outputs | Native metadata/query parity and separately authenticated Godot shadow readback |
| Main display names | Generated labels-only resource through the one public method | Independent schema-v2 B consumer report from actual candidate application methods |

Current compatibility/native/Godot-shadow receipts use schema v2 and separate
these scopes. Native metadata execution explicitly claims no actual UI behavior;
shadow readback claims no production-project, fallback-physics or rendered-pixel
qualification. Both carry an unsatisfied-by-this-report requirement for the
separate `cybersand.material-catalogue.display-consumer` schema-v2 report.
Historical v1 receipts/readers, their source hashes and dated evidence stay
authenticatable and cannot be relabelled as current B acceptance.

The [source-admission guard](../../tools/material_catalogue/display_contract.py)
authenticates the accepted native/Godot executable and scene/configuration
routing inventory against `7ef4856e`. It permits only the new labels resource,
the exact Main preload/method replacement and the declared apparatus entry.
Second, renamed or indirect imports, including other script directories,
addons, scene resources, autoload routing and native sources, are refused.
This B admission inventory is separate from the unchanged 27-owner legacy lock.
A future integration that edits Main or another admitted executable source,
including active #370, needs a reviewed B inventory transition and fresh proofs;
it must not refresh the A lock or silently import an active branch.

### Independent oracle, apparatus transition and rollback

[`legacy_display_names.py`](../../tools/material_catalogue/legacy_display_names.py)
authenticates the old Main method and fallback building labels directly from
accepted Git. Its immutable fixture covers all 256 byte IDs and 21 signed/large
edge IDs, including both signed 64-bit limits, plus picker and grouping order.
It does not derive expected returns from the new generator. Actual old and
candidate Main and inherited Web-controller methods must match that oracle;
UI item IDs/counts/order/selection, exported `ui_name` fields and downstream
Tower/transport/workbench behavior have separate runtime checks. A poisoned
ordinary generated label must affect actual Main output or fail the intended
equivalence guard; a decorative unused preload is not evidence.

`microscenario_identity.gd::SOURCES` now includes the executable resource.
Current apparatus source hashes must therefore change. Historical captures
and receipts retain their old source sets, and old/new comparisons remain
refused or explicitly ineligible. Native artifact hashes must be measured from
the actual files; unchanged native source alone proves no binary-hash equality.

Rollback restores the old consumer, removes its generated dependency from the
apparatus source set and restores the matching A-only proof/admission boundary
as one unit. An A-only reader from retained accepted Git qualifies that restored
state; a B guard must reject the old route. No save or World conversion is
introduced. This candidate ends at a draft independent-review handoff:
no merge, #353/#352 closure, #356 implementation or new material allocation.
