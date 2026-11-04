---
title: Material catalogue shadow compiler and compatibility guards
status: Current
document-kind: guide
scope: Implemented tooling in the unmerged MAT-AUTH-001 353-A candidate; production material authority and physics remain unchanged, with production cutover and new semantics held separately
canonical-for: [material-catalogue-shadow-compiler, material-catalogue-compatibility-guards, material-catalogue-authoring-workflow]
last-reviewed: 2026-11-04
related-documents: [../architecture/material-authoring-catalogue-plan.md, ../systems/materials-and-rule-kernels.md, ../systems/intermaterial-interactions.md, ../architecture/liquid-solver-family-policy.md, documentation-maintenance.md]
---

# Material catalogue shadow compiler and compatibility guards

**Current candidate tooling; no production consumer cutover.** On 4 November
the owner requested implementation of the architecture review's corrections
and compatibility mitigations. The bounded response is #353-A: authored
metadata, deterministic candidate outputs, independent native parity and
source-identity guards. It is separate from documentation PR #357, which remains
draft and unmerged. The original #353 issue stays open for its broader scope.

The [architecture review](../audits/2026-11-03-mat-auth-000-architecture-review.md)
and [corrected migration contract](../architecture/material-authoring-catalogue-plan.md#11-current-main-review-and-implementation-admission--2026-11-03)
explain why matching values alone is insufficient. Accepted main for this
checkpoint is `0fd4af5987e77db4da3e37c757cf2c0917ae9e15`; reviewed design head
`9b776d109e7843fb9b2d25239f9d088181309aa1` remains its separate predecessor.
Executed checks, retained receipts and remaining decisions are in the
[4 November qualification record](../audits/2026-11-04-mat-auth-353a-compatibility.md).

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

The receipt must contain the exact three checker/oracle inputs and five
catalogue/mirror inputs; missing, duplicated, renamed or stale entries fail.
The checker verifies the whole inventory again after readback. Report paths
cannot overwrite their checked inputs. A truncated local editor archive was
refused during qualification; the accepted readback used the complete archive
matching the repository's size and SHA-256 pin.

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

The native query check requires a C++20 compiler; JSON generation and strict
validation use Python's standard library. CI reuses the existing hosted
Documentation workflow and execution watchdog. It does not create a new
physics matrix, require a runtime download or enable the expensive draft lanes.

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

#353-A adds tooling and unused candidate data only. Reverting its tools,
candidate directory, documentation routes and CI step restores the previous
development workflow; no save or World conversion is needed. Existing kernels
and policy artifacts remain the production authority throughout.

#353-B requires a separate review of each proposed consumer switch. Preserve
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
