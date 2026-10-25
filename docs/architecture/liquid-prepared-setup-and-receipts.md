---
title: Native liquid prepared setup, receipts and quantity accounting
status: Current
document-kind: design
scope: Unmerged LCB-001 native construction contract on codex/lcb001-shared-contract — immutable final tuples, explicit Water normalization, prepared World ownership, typed native outcomes, native run and attempt receipts, exact quantity aggregates, physical hash/CYPS2 and qualified local evidence; application-host proof and downstream family work remain open
canonical-for: [liquid-prepared-setup, liquid-native-run-receipt, liquid-quantity-accounting]
last-reviewed: 2026-10-25
related-documents: [liquid-solver-family-policy.md, pressure-flow-v1.md, liquid-state-transition-matrix.md, lcb-pressure-inertial-handoff.md, ../operations/lcb-water-comparison-and-fixtures.md, ../operations/lcb-manual-comparison-ux.md, ../operations/current-and-historical-validation.md, ../reference/status-and-roadmap.md]
---

# Native liquid prepared setup, receipts and quantity accounting

## Source and completion boundary

**Current in unmerged native source** on branch `codex/lcb001-shared-contract`,
based on `349d59359a45ebbe4f92af879945b43b591d412a`, with the preparatory local
delta dated 2026-10-24. The native prepared setup, normalization receipt, typed
run receipt, construction-attempt receipt and quantity ledger use their explicit
schema/version 1 contracts below. The complete physical-state hash version and
CYPS persistence format are **2**. This describes the source and local native
checks; it does not declare [#200](https://github.com/techrote/cybersand/issues/200)
complete or establish a published, source-matched Godot runtime for this delta.

Native C++ owns cells, setup preparation and accounting. Values expose copied
immutable data or const spans into owned values; they expose no mutable World
storage. Preparation acts on an unexposed new candidate. It accepts no live
World to normalize or replace. The owner still performs the eventual session
installation and publication transaction.

**Residual #200 boundary:** that native checkpoint supplies no Godot typed-v1
normalization opt-in route. The subsequent [bounded #202 host slice](#controlled-application-host-preparation-slice)
adds one on `codex/lcb003-application-host`. The
existing `CyberNativeCellWorld.get_liquid_run_receipt(Dictionary)` in
[`cyber_native_cell_world.cpp`](../../godot/native_extension/cyber_native_cell_world.cpp)
remains an experimental dictionary/string assembly from the pressure reference.
It is a different encoding and does not supply this typed native contract or
application-host proof.

## Controlled application-host preparation slice

**Current experimental source on `codex/lcb003-application-host`, based on
`9e91a9f75d47b9a9aa4a8ba2d3ce78ba2fbfd882`:** the normal desktop
MicroScenario owner and synchronous application controller accept a fixed,
actor-free schema-2 definition with an explicit policy and optional
`water-normalize-v1`. `microscenario_apply_controlled_liquid` keeps the existing
definition, event, observation, pause, acknowledgement and Reset routes. Reset
retains the accepted policy and normalization opt-in. Ordinary constructors
continue to use their existing defaults. This is the first #202 slice, not
completion of the comparison host, UI, all constructors or Web qualification.

`CyberDemoBridge.prepare_liquid_world` resolves the ordered rectangle and
nonzero Water-fill overlays into final unique native tuples before calling the
unchanged `PreparedWorldBuilder`. Zero-mass fills retain their no-op meaning.
The construction-only dense tuple map has 1,048,576 entries; no staging storage
or allocation enters tick execution. This initial schema carries ambient
temperatures; native tuple/thermal authority and native normalization remain
owned by the contract above.

One adapter-owned pending slot owns the candidate World, render exchange,
final setup, copied native receipt and a monotonically issued opaque token.
The final fixed interest region, adhesion and host cadence selection are set
before native capture. Preparation cannot expose its World or applied receipt.
A newer preparation retires the previous token even when the newer request
refuses. Commit is one-use and first checks the retained generation, revision,
complete physical hash and selected adapter execution flags. Changed live state,
discard and token replay refuse before any swap. Legacy constructors retire the
typed identity rather than retain a receipt from another World.

The desktop worker prepares outside its queue mutex. It fences the actual
native commit under that mutex against the current owner-issued request
revision, reset and stop. A same-definition newer request still has a different
request identity. Refusal preserves the old World, generation, applied receipt
and MicroScenario event/observation cursor; the latest native-issued refusal
has a distinct copied construction-attempt encoding. The attempt captures the
healthy retained native facts before preparation and again after refusal.
An initial legacy World with generation zero cannot mint that native receipt.
Host schema/unsupported-route errors and retired tokens do not invent native
policy refusals.

`get_applied_liquid_construction_receipt` and
`get_liquid_construction_attempt` copy the native canonical bytes and SHA256
into owned Godot values. The applied value remains the original tick-zero
receipt through ordinary ticks. Consumer mutation cannot affect the adapter or
later worker publications. The native-v1 qualification flags remain intact and
full matched-evidence eligibility remains false: a host definition digest is
still a claim, source/runtime verification is not supplied, and no GDScript
re-encoding upgrades the frozen native contract. The older dictionary getter
remains a separate encoding.

The [dated host evidence](../audits/2026-10-24-lcb003-controlled-host-slice.md)
records deterministic preparation/commit barriers, masked-Water refusal,
normalization totals, actual normal-app routes and retained legacy regressions.
The synchronous `web_main.tscn` check executes in Windows Godot; it is not a
browser/Wasm result. Subsequent bounded UI and sampled/exploratory source are
Current on this same branch as described below. Physical-body staging, remaining
constructor routing, full exhibition, complete definition/actor/loadout and
provenance verification, browser runs and hosted source-matched runtime
publication remain #202 work.

### Staged sampled actors and exploratory owners

**Current experimental source `da800552` on the same pre-quantity-fix `9e91a9f7`
base:** `microscenario_apply_exploratory_liquid` is an explicit additional route
for body-free schema-2 definitions. It retains ordinary manual tools and owner
execution/interest, and stages sampled characters or the existing allowlisted
sampled actor/equipment sessions. The original Controlled API remains fixed and
actor-free. The normal panel selects Controlled or Exploratory explicitly;
Original Current control still uses the unchanged original default constructor.
The [constructor matrix](../operations/lcb-manual-comparison-ux.md#constructor-coverage-at-this-checkpoint)
owns per-route availability and platform limits.

The worker privately configures replacement `CyberActorPrototypeSession`,
`CyberUsableSession` and character before native commit. Spawn recovery uses a
read-only token-bound candidate collision view with the exact live collision
query law, never the retained old terrain. Retired tokens fail closed; this
view offers no tick/edit operation or pending native World reference. Existing
bounded blocked-spawn semantics remain unchanged. Actor epochs advance beyond
the retained session's epoch, including inactive periods. Producers acquire a
retained session reference under the owner mutex; the World/session swap shares
the final request/reset/stop/settings fence. A refused staged actor/equipment
configuration mutates no old owner, epoch, equipment, mask or native receipt.
A host-only refusal fabricates no native construction outcome.

Initial native facts bind the actual region, window/cadence/adhesion, explicit
`Exploratory` intent and `HostPaced` execution. The initial owner view is derived
from the accepted definition camera, existing 480×270 MicroScenario view and
selected buffers/window. The worker holds that initial frame until main installs
the acknowledged camera/configuration; older presentation frames cannot rewrite
its tick-zero facts. Only the matching scenario acknowledgement releases it.
Ordinary accepted constructors retire the hold. An execution/buffer or player
profile change during preparation retires the candidate. A profile extracted in
the same owner turn joins the candidate character before swap; an unconsumed
newer profile refuses preparation. Settings remain independent of solver choice.

Reset and F5 sampled-rig reconstruction retain the accepted exploratory policy,
normalization and intent. The subsequent desktop articulated route below stages
actual physical ownership; other body constructors remain explicitly unsupported.
The synchronous controller stages its existing sampled character through the
same native view and commits on its main thread; sampled rig/equipment ownership
there remains separate work. Main-thread Rapier objects never enter native pool
workers or this GDScript worker. Native-v1 actor/loadout, setup, execution and
source/runtime gaps remain; native receipt eligibility stays false. No extension
of the frozen native codec or final full-host acceptance is claimed.

The [sampled/exploratory evidence](../audits/2026-10-25-lcb003-sampled-exploratory-host.md)
records actual owner/app routes, deterministic declared failure/supersession,
prior masked Water preservation and Current actor regressions. These local tests
still require fresh accepted #246 native integration and the final platform
matrix; they do not qualify that newer native source.

### Staged articulated physical owners

**Current on the unmerged #202 branch, locally qualified Windows native source:**
the explicit Exploratory route additionally supports the existing allowlisted
schema-2 play maps with an articulated Rapier actor and its existing loadout.
Controlled fixed fixtures remain actor-free. Barrel/reference bodies, Water Feel,
Tower, imports, generation and actual browser execution remain separate routes in
the [constructor matrix](../operations/lcb-manual-comparison-ux.md#constructor-coverage-at-this-checkpoint).

Main prepares the complete existing PhysicalActorSession, rig, equipment and
terrain bridge inside a private permanent `SubViewport`/`World2D`. Its space has
automatic integration disabled and its dynamic bodies remain frozen. Actual
PhysicsServer poses/velocities are read back, copied and verified across at least
two distinct real physics frames. Candidate terrain uses the existing bounded
collider budget. Accepted adoption keeps exactly this graph and space; no physics
rebind or fallible reconstruction follows native commit. Old scene/space and
equipment remain installed through refusal. No scene object or RID enters the
simulation worker or native pool workers.

The native preparation option `initial_bodies` admits at most 64 existing
11-float body records. The strict construction parser refuses malformed stride,
nonfinite values, invalid IDs/sizes/mass/serials and duplicate IDs. Its accepted
mask raster shares the ordinary adapter law. Actual initial masks are installed
before native facts and canonical receipt capture, without sweep resolution or
erasing stored Water. `prepared_liquid_world_values` returns copied pending terrain,
body input, its SHA256 and candidate physical hash, never a World reference or an
applied receipt. The canonical native physical hash binds the actual initial mask;
the body-input digest/count are explicitly additional host readback metadata,
not a new field or stronger claim in the frozen native-v1 encoding.

The worker keeps one nonblocking continuation. Main's copied readiness binds its
token, request serial, epoch, Godot instance ID and body-input digest. Continuation
resumption requires exact equality with the original definition, policy, complete
setup/options and request revision; the token is retained internally, never read
from a caller's setup dictionary. Final request/settings/reset/stop fences still
run under the owner mutex. Wrong readiness, changed definitions or superseding
requests cannot install a stale candidate. Stop discards it without waiting for a
main callback. An initial body-frame hold rejects stale predecessor publications
until main adopts the accepted graph and acknowledges the matching serial.

While preparation waits, the worker leaves already-admitted cell/disc paint and
physical work in their mailboxes. New paint explicitly refuses during this
interval. Independently admitted settings or reset/prototype changes retire the
candidate and keep their ordinary disposition; unconsumed profile values remain
queued until the retained owner can apply them. Main suspends old-owner mutation
and input publication while its separate physical replacement is pending.

Native-v1 full-match eligibility stays false with source/runtime/host claim and
setup-coverage qualifications. **Planned:** after constructor coverage is stable,
a separately versioned host-evidence/readback envelope must identify the actually
executed runtime and source-matched provenance, complete actor/body/equipment and
execution setup, and bind its immutable native run bytes. A receipt panel or
caller-supplied digest cannot supply that proof. This slice introduces no new
host-evidence schema or native codec version.

## Source map

| Responsibility | Current source |
|---|---|
| Typed finite setup descriptor, coverage gaps and prepared identity | [`prepared_setup_identity.hpp`](../../native/include/cybersand/prepared_setup_identity.hpp), namespace `cybersand::setup` |
| Final tuples, validation, explicit normalization and private receipt construction | [`water_normalization.hpp`](../../native/include/cybersand/water_normalization.hpp), namespace `cybersand::normalization` |
| New candidate construction, actual payload check and private ledger initialization | [`prepared_world.hpp`](../../native/include/cybersand/prepared_world.hpp), `PreparedWorldBuilder` and `PreparedWorld` |
| Native-issued immutable refusal/failure outcome | [`liquid_construction_refusal.hpp`](../../native/include/cybersand/liquid_construction_refusal.hpp), `ConstructionRefusal` |
| Typed applied-run and construction-attempt encodings | [`liquid_run_receipt.hpp`](../../native/include/cybersand/liquid_run_receipt.hpp) |
| Exclusive-owner capture of actual native values | [`liquid_run_receipt_native_capture.hpp`](../../native/include/cybersand/liquid_run_receipt_native_capture.hpp) |
| Quantity values and fixed worker scratch | [`quantity_ledger.hpp`](../../native/include/cybersand/quantity_ledger.hpp) |
| Producers, reductions, overflow, validation and persistence helpers | [`world_quantity.inc`](../../native/src/world_quantity.inc), hooks in [`world.cpp`](../../native/src/world.cpp) and [`world_pressure.inc`](../../native/src/world_pressure.inc) |
| Completed-boundary readbacks | [`world.hpp`](../../native/include/cybersand/world.hpp): `stored_temperature`, selected/applied simulation cores, `quantity_ledger` |

## Final setup tuples and identity

`FinalSetupInput` declares mass bits, an ambient thermal value, a typed setup
descriptor and final cell tuples `(x, y, material, state_a, state_b, temperature)`.
Coordinates and the native integer thermal lane retain their exact values.
The caller must already resolve every overwrite: duplicate coordinates are
refused, and no list of historical rectangle/fill records is normalized.
Preparation sorts the unique final tuples by ascending y, then x.

Ambient Empty with zero state lanes has canonical sparse absence. Nonambient
Empty remains explicit authority. Down-rounding Water preserves its temperature
and clears its material/state lanes. Installation into a fresh World therefore
does not reveal an earlier rectangle underneath a removed Water cell.

`NativeCellFixture` means the supplied tuples are the authored input. A
MicroScenario/registered-definition digest binds declared definition bytes but
does not prove those tuples were compiled from them. The descriptor retains
typed gaps for schedule, actors/loadout, planes/clocks, retained edits/import,
presentation/inputs and unverified host collection. Native-payload-only coverage
must retain the non-cell gaps. Registered-definition coverage cannot remove
`HostCollectionUnverified` in this implementation.

The v1 domains are distinct:

| Identity | Domain and coverage |
|---|---|
| Native cell payload | `cybersand-lcb-final-cell-payload-v1`: schema, mass bits, ambient temperature, finite domain and canonical material/state/thermal tuples |
| Prepared setup | `cybersand-prepared-setup-v1`: typed descriptor, seed, explicit coverage/gaps and native payload digest |
| Normalization receipt | `cybersand-water-normalization-receipt-v1`: rule/version, precision, unchanged before/after seed, both payload/setup identities and all normalization totals |

Before and after setup identities use the same descriptor and seed. The setup
identity never includes the normalization receipt hash, avoiding a hash cycle.
A matching caller-supplied definition digest supplies no compiler, source,
runtime or host-execution verification.

## Explicit normalization and candidate admission

The [Water quantity normalization law](../operations/lcb-water-comparison-and-fixtures.md#water-quantity-normalization)
owns rounding, signed setup delta and matched post-normalization comparison.
This implementation executes that registered law on the final tuples. It
validates mass bits 3–8 and uses checked integer quantities and totals.

| Native target requirement and request | Outcome |
|---|---|
| Fractional-capable target, no opt-in | Preserve fractional Water; no normalization receipt |
| Whole-cell target, fractional Water, no opt-in | Native `normalization_required` refusal |
| Either target, explicit `water-normalize-v1` | Same normalized payload and normalization receipt for both comparator arms |
| Explicit rule with already-full/empty setup | Retain an explicit receipt even when the net delta is zero |

`PreparedWorldBuilder` derives the quantity requirement from the admitted native
policy. It validates the original Water coherence lane against the selected
policy before rounding can remove a cell. Precision and ambient must match the
requested World, and only the implemented SerialInPlace/PhasedInPlace backends
are accepted. Policy admission precedes candidate allocation.

The preparation bound is at most 1024 cells per side and 1,048,576 explicit
records; a caller may lower the record budget. Inclusive endpoints and the
native reservation halo have checked coordinate bounds. World chunk capacity
can still refuse an otherwise valid setup. Allocation/length and expected
reservation-capacity failures return native capacity outcomes. Unexpected
installation, digest or quantity invariant failures return a separate native
preparation-failure outcome. No failed candidate is installed into the retained
live session.

The builder reserves cell/thermal storage, installs the final tuples, captures
the actual prepared payload, and compares its digest with the immutable value.
It checks actual Water quantity before attaching a construction ledger once at
tick 0. The ledger retains the exact before/after payload/setup identities and
normalization receipt digest. An alternative before mass such as 128 versus
129 cannot borrow the same after-255 World to assert a different installed
normalization history.

Water `cellular_yield_v1/reference` is admitted in this native branch, with its
own optional Water material block v2 (`viscosity_index` 0–255, default 0).
Its ingress requires `maximum()` per Water cell. A fractional public bool
`set_cell_state` returns false before mutation/allocation; native setup/import
preflight returns `normalization_required` where applicable. No FreeMass
transfer fallback or foreign Paste/Slush parameter supplies its motion law.
The [family policy](liquid-solver-family-policy.md) owns the wider family and
material-hook contract.

## Native-issued outcomes and typed receipts

`ConstructionRefusal` has private construction and separate outcomes:
`PolicyOrSetupRefused` carries the actual native `LiquidPolicyRefusal`;
`NativePreparationFailed` carries an internal failure detail without inventing
a policy refusal reason. Const accessors expose owned bounded request data.
The native policy validator never issues a refusal for an accepted request.

| Request scope | Meaning |
|---|---|
| `ExactRawPolicyRequest` | Native decode/admission refusal binds the exact requested words, including request-only family code zero |
| `NormalizedPolicyEnvelope` | Builder setup/capacity/failure outcome binds the decoded policy envelope it received; it does not reconstruct an earlier raw host request |

The request digest uses `cybersand-construction-request-v1`, schema, scope,
word count and little-endian signed words. Inputs are bounded to 4096 words and
details to 512 bytes. Oversized raw validator input throws before parsing; it
never produces a token falsely claiming a truncated exact request.

`AppliedRunReceipt` uses `cybersand-run-receipt-v1`. It requires a healthy
completed tick-zero native capture, the matching applied policy, the same setup
descriptor and a nonzero declared committed generation. It binds policy and
catalogue/capability identities, Water semantics, transport and interaction
configuration, workers/backend/capacities, selected and applied simulation
coverage, complete physical hash/version, family-state extensions, native
quantity snapshot, prepared setup identity, optional installed normalization,
host execution fields and explicitly typed provenance claims.

`ConstructionAttemptReceipt` uses `cybersand-construction-attempt-v1`. It
requires a native-issued outcome, unchanged captured native state/setup and an
unchanged nonzero generation. The outcome kind, request scope, exact request
digest/words and actual refusal/failure are distinct from an applied-run value.

`stored_temperature()` reads actual thermal authority beneath a body mask;
`temperature()` keeps its existing effective-value behavior. Independent
selected/applied core getters retain the distinction between a selected region
and the region latched at tick entry. Native capture reads these values from
the exclusive owner; workers call no Godot API.

**Qualification remains mandatory.** Source/runtime values are caller claims.
Shaped commit strings, hashes, a Controlled intent, a setup definition digest
or declared generation do not establish provenance or execution fences. Applied
receipts retain setup/source/runtime/host-execution qualifiers and return false
for full matched-evidence eligibility. No ordered input replay or authenticated
arbitrary rehashed lifetime history is established by these digests.

## Quantity aggregates, producers and continuation

`QuantityLedgerSnapshot` schema 1 is native World-wide accounting, including
stored cells under body masks and outside the current simulation region.

| Data | Unit and interpretation |
|---|---|
| Visible Water and pressure overfill | Exact selected-precision Water integer units |
| Six source/sink kinds | Setup normalization, external edit, generated chunk, deferred event, pair reaction and kernel conversion; produced/consumed Water are separate unsigned totals |
| 56 pair-rule entries and event counts | Rule-specific gross Water inputs/products, with actual consumed partial/overfill quantity and initialized full Water outputs |
| 19 kernel-rule entries | Rule-specific Water source/sink quantities, checked against the kernel's actual source/sink roles and full-cell production quantum |
| Current/prepared populations | Two exact arrays of 256 material cell-count slots; these are per-species counts, not inferred common liquid mass |
| Construction seed | Original/prepared identities, original baseline, normalization source/sink and receipt digest; attached once by the private native initializer |

The closed equation is `baseline + sum(produced) = visible + overfill + sum(consumed)`.
At construction the baseline is pre-normalization quantity and normalization is
booked once as a declared setup-only source/sink. Runtime transport contributes
no physical source/sink. Pair products book gross inputs and products even when
a Water role remains Water; a partial Water+Salt conversion cannot be described
as a conserved whole-cell transfer.

All live producer seams are hooked: external writes, generated installation,
applied deferred events, pair products, specialized kernel conversions, FreeMass
transfers and pressure take/give/overfill relief. Whole-tuple moves retain global
quantity and species populations. Source-role validation refuses generated
Water sinks, deferred-event Water sources, incapable kernel explanations and
invalid production quanta. Prepared Water count/quantity bounds also constrain
the declared initial state. Current species snapshots and rule aggregates do
not authenticate every possible external history or provide an ordered replay.

Worker deltas are fixed per scheduling slot and merged after the phase barrier.
There is no new tick-time allocation, per-cell lock or per-material thread.
Serial writes instead check only the affected Water quantities, at most two
material populations, the selected cause/rule and the six-category lifetime
totals before assigning any ledger field. They do not construct job scratch or
copy/scan the entire ledger for each painted cell. Both paths preserve checked
arithmetic and transactional external refusal; phase reduction retains its
complete worker-delta merge. The dated audit retains the full Windows setup
timeout that motivated this repair and a source-fenced construction comparison.
In the measured Windows x64 layout a delta is 3816 bytes: the default 4096 slots
add **15,630,336 bytes**. `QuantityLedgerSnapshot` is **6088 bytes** and
`QuantityConstructionSeed` is **208 bytes**; the optional seed is already part
of the snapshot layout. These are accounting storage costs, not total World
memory or a performance qualification.

Checked counters reject external/generated overflow before authority or a new
chunk changes. Worker/reduction overflow quarantines the partially advanced
World and prevents a completed accounting read. CYPS2 retains exact accounting
and construction bindings, validates source roles and aggregates, and scans
restored stored authority before returning a new World. Unknown quantity schema
and historical CYPS1 are explicitly refused. Complete physical hash v2 includes
the ledger and continuation state. Historical content/state definitions are
preserved; cross-tick rest is not equality of a tick-inclusive continuation hash.

The residual pressure continuation also retains ordinary pending-event ingress
bounds on restore and a non-wrapping gas-ID allocator for creation and split.
Exhausted gas identities use an explicit sentinel and the existing failed-tick
quarantine. Direct quantity rectangles validate their inclusive endpoints and
preserve zero-area reads; none of these readback checks mutate the World or its
ledger. The [pressure contract](pressure-flow-v1.md#persistence-cyps-v2) owns
these concrete limits and the residual audit preserves their failing controls.

## Tests and qualified evidence

Source regressions are
[`test_water_cellular_yield.cpp`](../../native/tests/test_water_cellular_yield.cpp),
[`test_water_normalization.cpp`](../../native/tests/test_water_normalization.cpp),
[`test_liquid_construction_refusal.cpp`](../../native/tests/test_liquid_construction_refusal.cpp),
[`test_liquid_run_receipt.cpp`](../../native/tests/test_liquid_run_receipt.cpp) and
[`test_quantity_ledger.cpp`](../../native/tests/test_quantity_ledger.cpp).
They cover all Water masses at bits 3–8, coherence 0/12, workers 1/4, material
hooks, masked authority, explicit comparator normalization, typed outcomes,
forged same-after/different-before binding, capacity refusal, actual prepared
readback, conservative transport, rule products, overflow and rehashed malformed
CYPS2 inputs. W-CY rare-yield tests compare ordinary sleep with always-awake
behavior across viscosity 255, cadence 1/17 and horizontal sampling 1/2; blocked
masked/enclosed sources may sleep while eligible body probes remain intact.

Independent Python byte specifications retain complete expected bytes and
frozen native-test identities:

| Oracle | Frozen vectors |
|---|---|
| [`water_normalization_contract.py`](../../tools/lcb/water_normalization_contract.py): 8 struct/hashlib/exact-rational vectors | [`water-normalization-vectors.json`](../reference/water-normalization-vectors.json) |
| [`liquid_run_receipt_contract.py`](../../tools/lcb/liquid_run_receipt_contract.py): 7 complete run/attempt encodings | [`liquid-run-receipt-vectors.json`](../reference/liquid-run-receipt-vectors.json) |

The receipt fixtures are `controlled_native_scope`, `exploratory`,
`caller_claims`, `selected_region`, `pressure_state_extension`,
`normalized_bound` and `refused_attempt`. The four physical hashes are explicitly
measured fixture facts, not independent verification of native physics.

The [dated evidence ledger](../audits/2026-10-24-lcb001-residual-shared-contract.md)
records the final native and scoped Windows Godot executions, source manifests,
tool/artifact hashes, failures and acceptance gaps. Local evidence is outside
the repository and is qualified as a local proof:

- `C:/Users/_/.codex/tmp/lcb200-quantity-prep/final-integrated/` and `msvc/`:
  final LLVM-MinGW/UCRT C++20 `-O1` and MSVC 19.38 `/W4 /Od /Zi` builds both
  pass **121/121**, including the frozen vectors and restore correction, with
  ordinary 1 MiB reserve/4 KiB commit. Both have the same native-input manifest
  `9b6344ee27e198bd2aadb2c7e8a76cd8c3c56e1cfef5028571cceab374f81b4d`.
  The dated ledger records each executable hash and command/result boundary.
- `C:/Users/_/.codex/tmp/lcb200-quantity-prep/final-receipt/`: the final frozen
  receipt harness passes 63 ordinary assertions and 70 with vector output;
  all seven complete byte strings match the independent oracle. Binary SHA256
  is `4b8e8403eb5969839e1cec424d9e3d44983aced5f06a2cc41d270c1bf049d0a0`.
  `command.json`, `inputs.json`, `inputs-after.json`, `tests.log`,
  `vector-tests.log` and `vectors/` retain the check.
- `C:/Users/_/.codex/tmp/lcb200-normalization-prep/build/`: integrated value
  normalization passes six groups under MSVC 19.38 `/W4 /WX` in debug `/RTC1`
  and optimized builds. The original default-stack failure, the separately
  qualified 8 MiB test run, the fixture-only heap repair and subsequent ordinary
  1 MiB full native passes remain retained; production World layout was not
  changed to address that test portability failure.
- `C:/Users/_/.codex/tmp/lcb200-godot-proof/`: a fresh non-release Windows DLL
  passes policy (385 assertions), pressure (1,934), worker receipt (29), native
  observation (100) and all 16 WEX body-mask cases. All 767 captured inputs
  remained unchanged. This scoped scratch proof does not expose typed native
  normalization/receipts through Godot or supply Linux/release publication.

Run `python tools/lcb/water_normalization_contract.py --check` and
`python tools/lcb/liquid_run_receipt_contract.py --check`. The latter also
accepts `--native-dir` to compare all complete native fixture bytes. These local
proofs do not replace exact-head Documentation, native/platform, Godot runtime
publication or release gates.

## Downstream ownership

**Planned #201:** a rest certificate must preserve stationary body-contact
probes, material stages 1/2 and other materials' execution, as well as cadence
and stochastic future work. It cannot remove tick/scheduler state from the
complete physical hash or infer rest solely from unchanged positions. No cached
or dormant implementation is supplied by this checkpoint.

**Planned #202:** normal application constructors, UX, Web integration, the
registered-definition compiler, actual input/session fences and source/runtime
provenance verification remain application-host work. A definition digest is
not a substitute for compiler proof. **#212** inertial qualification and **#203**
packaged comparison coverage remain pending. Existing family and campaign gates
continue to own acceptance; this native checkpoint supplies no completion claim
for those streams.
