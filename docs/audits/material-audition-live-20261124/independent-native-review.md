# MAT-AUDITION-LIVE-001 — independent native source review

**Disposition: source transition reviewed; implementation remains Draft / HOLD.**

Specialist C independently inspected the native change written by specialist A,
compared it with accepted main, checked its call sites and invariants, and reran
the native suite. This record permits consideration of the exact protected source
transition below. It does not authorize merge, Ready promotion, physical owner
acceptance, retained-runtime publication, or a claim that target Windows execution
has occurred. The separate qualification packet must supply those execution
receipts and remaining gates.

## Exact scope and custody

Accepted main is `00cdb02f103265b6dc5224c68283e9a0c8cb449f`.
Reviewed candidate native source is reachable in Draft PR #768 at
`f66e0949dfd5257bc926adc87988ddd0f4634761`. The later host-only checkpoint
`63fd3b6c1af4bd114ce9d711f930b96875316743` has identical `native/include` and
`native/src` inputs. The review does not bless future changes with different bytes.

| Protected source | Accepted SHA256 | Reviewed candidate SHA256 |
| --- | --- | --- |
| `native/include/cybersand/world.hpp` | `6a1e5e89fe988301b56920ae8b23f723fdc1045c396ccc05f67f9be17f8cc45e` | `b94407f0de9ec9bded9f5077bd4d608af11e562c3513f08e4fef36ec7a477359` |
| `native/src/world.cpp` | `ec3034850af97e790dfc3855411bba5be60c820cb623a6df62ca09c70aeb761a` | `c5bd52b8827e5edef262ae2e9df2ec286abb9140d2e7ba6471b40d187e24ef14` |
| `native/src/world_pressure.inc` | `fca639dfbf6274c590fb38283207aa838d6aa659e3ed0e95b397f6a7d8ab5be1` | `70c617cea5556bb6121aba3b09af37ee7774fb6c08719dcf60b7042b72566817` |

The new independent modules are also part of the reviewed mechanism:

| New source | SHA256 |
| --- | --- |
| `native/include/cybersand/material_audition.hpp` | `eae75d534293370f48212052ff0e36c397f29a983616652cf218235d9d4b9ff4` |
| `native/src/world_material_audition.inc` | `d9651d0d651c0b4272be4530303e2cec13478438ae241c170c5a19d2cecfb2fd` |
| `native/tests/test_material_audition.cpp` | `92eaf05f030a49a1be68db9afc62526faad623bb781a25b9c52bb80658a566b7` |

The frozen compatibility lock, canonical descriptors and canonical resolver were
compared directly with accepted main and are unchanged. Their SHA256 values are:

- `materials/catalogue/compatibility-lock.json`: `8b4d3351cbe4380e976655d10dc34c4bf9e81d95442719a53770b62d219183dc`
- `native/include/cybersand/material.hpp`: `3e40f970e3205853a43643b4163041935ccd64d8a018d35a7473c3f95a1d0375`
- `native/src/material_rules.cpp`: `94928fa8f16010efaa3326750a3e951101e6905f3eafe8f99c0935ab33f0de8d`

No frozen-lock refresh is justified or requested by this review.

## Consumer correspondence

The `try_move` change selects the per-World density comparison at the existing
directional exchange call site. With no effective density override it calls the
unchanged canonical function. With an override, the local function reproduces the
canonical checks: no horizontal exchange, no powder/powder swap, Oil's existing
powder penetration veto, valid and eligible target, and the original up/down
motion direction. Only the two integer density comparisons change. The control
does not change rigid-body mass, granular impulse, renderer identity, collisions,
or specialised fluid pressure equations.

The yielding-liquid change replaces the existing descriptor/diagnostic viscosity
lookup with an effective lookup at the same lateral-yield gate. Gravity,
directional exchange, temporal lanes and lateral admission remain the same. The
Mercury diagnostic value remains authoritative and conflicting profile entries
are refused. Inertial-family assignments are also refused because that solver
bypasses the generic yielding function. Water, Oil, Acid and Lava therefore do
not gain misleading generic viscosity sliders.

The compact-pair change obtains the existing cached authored first match at roll
zero, preserving the rule index and endpoint-oriented products. It applies the
selected profile threshold to that match. Every admitted threshold is inclusive:
zero still accepts one possible roll out of 256. It neither skips a failed first
match to choose another rule nor adds a new interaction or material identity.
Existing execution of endpoint effects and quantity-ledger events remains in the
original native call site. Existing wake scheduling still asks whether an
authored match exists, which is correct because no admitted threshold disables
all rolls.

The Wave Water applicability correction is present: an inert endpoint cannot
initiate a compact pair, and Wave Water does not execute the ordinary Water
kernel. Water/raw-clay under Wave therefore refuses the probability edit. Salt
can still initiate the existing Water/Salt rule against Wave Water. This is a
consumer-availability check, not a claim that an arbitrary scene currently has
contact or satisfies all per-cell eligibility conditions.

## Publication, isolation and reversal

All profile values are validated before narrowing or publication. A separate
candidate snapshot owns the profile string and fixed numeric lookup tables.
Allocation, identity/revision checks, owner failure checks, tick-boundary checks
and the 16 Mi-cell resident scan-cap refusal precede the single pointer swap.
Subsequent wake operations use existing blocks only. Inspection of
`keep_cell_active`, `wake_cell_neighborhood`, `record_physics` and discovery wake
witnesses found no allocation or throwing operation on that path. The explicit
native contract still requires exclusive owner access; it is not a lock-free API
that may race simulation workers.

There is no process-global mutable profile. World moves transfer and retire the
unique token; a destructive clear obtains a fresh token before destructive work.
The moved-from token is zero and cannot admit a transaction. A stale revision
cannot replace later intent. Readback returns a copy, so editing a returned
profile cannot mutate active native authority.

An effective change scans only nonempty resident chunks, marks the affected
material/endpoint blocks and their immediate block-boundary neighbours active,
and preserves stored cells, clocks, quantities, renderer dirty rectangles,
collider revisions and World ownership. Equivalent/default and repeated
equivalent-value transitions perform no cell scan or wake. Restoring a previous
configuration uses the same transaction path; it deliberately does not restore
consumed cells or rewind reaction event history.

The scan currently visits each affected cell to reach the existing wake helpers.
This is a bounded user-triggered cost, not a per-tick catalogue scan. Its actual
latency on larger dense canvases must remain visible in the performance packet;
this review is not a performance waiver.

## Physical identity and persistence

Behaviorally default profiles retain accepted physical hash and save behavior.
Behaviorally modified profiles select physical hash version 7 and include their
effective numeric arrays. Profile names, UI revisions and World tokens do not
become physical state. Existing solver, quantity and cell sections of the hash
remain intact.

The existing CYPS format cannot retain this new authority. A nondefault profile
therefore reports physical format version zero and explicitly refuses physical
save. This is preferable to silently discarding effective behavior on reopen.
Named JSON profiles and ordinary authored starts remain separate; the UI and
owner integration must preserve that distinction. RAMCACHE integration remains
an explicit future seam rather than an invented cross-version continuation.

## Independent execution and outstanding qualification

Specialist C reran the native test binary after verifying the six candidate
native/test inputs above equal the native author's checkout. That executable's
SHA256 was `9fb91c1f1c4dcc6e105f563b2e8b9b85b2df4b279dd3ebd9967fd8e16f0354af`.
The native author built it with the repository standalone target; this rerun is
independent execution of that binary, not an independently attested target-OS
build. It exited zero and reported **33,961,295 assertions passed**.

Observed native witnesses were 96 / 46 / 0 moved Paste bays at viscosity
0 / 128 / 255 after one tick, and 1 / 41 / 96 executed Water/Salt pair events at
thresholds 0 / 63 / 255 after four ticks. The suite corroborates each reaction
event with its actual Brine endpoints and compares one and four requested
workers. It also checks exhaustive default and unrelated-pair resolution,
same-World density reversal, default-equivalent continuing hashes and save bytes,
invalid and stale requests, move/clear token retirement, overflowed revision,
in-tick refusal, failed World refusal and scan-cap atomicity.

Specialist C's separate accepted-source benchmark compiles the same probe against
accepted main and candidate native sources. Its reducer requires exact matched
initial/final cell hashes, physical hashes and versions, counts, moves and visits
for default and explicit-equivalent profiles. Timing is advisory on shared hosts.
The activation timer was corrected during rotating review to exclude probe-side
content-hash verification and profile construction from the native commit cost.

Before a definitive evaluator claim, retain the completed matched-source output,
sanitizer result, pinned Linux and Windows builds, real Godot 4.7 current-scene
and graphical receipts, and extracted portable Windows execution. Their absence
is a delivery gate, not evidence that source-only review established them.

**Source-review finding:** no remaining blocking native correctness defect found
in these exact bytes. Protected transition registration must reference the
reachable candidate source and these exact hashes. Physical owner acceptance and
integration acceptance remain HOLD.

## Expanded independent consumer rerun

The production native hashes above remain unchanged. Test-only source at
`ba021680` (integrated by root at `0a8958ad`) expands actual consumer evidence to
all seven admitted generic viscosities and all 56 existing compact-pair slots in
both endpoint orientations. The new test-source SHA256 is
`08347f2b27babea0e6800f9b944b5ad6f8470d1c833b2c2f2d282b316cc7d808`.

Specialist C independently reran the expanded executable, SHA256
`d833862e35b2e1c768567f3d3c8a9fd38f41f25bfe32627eebddb739a11c0690`.
It exited zero with **34,081,851 assertions passed**. Every admitted viscosity had
an actual three-setting movement witness with one/four-worker agreement. Every
authored pair had more actual executed ledger events at threshold 255 than at
threshold zero in both orientations. A threshold of 255 does not promise that
all authored contacts execute this compact rule: competing specialised paths
still operate. Across 32 sealed bays the observed four-tick high-threshold totals
range from 12 to 32; low-threshold totals range from zero to one. These are
actual execution observations, not resolver predictions or an assertion that
every possible scene is reactive.

This addendum does not extend the original binary's sanitizer receipt to the
expanded test executable. The hosted expanded sanitizer run remains a separate
qualification requirement. The source transition review still applies to the
same five native implementation inputs listed above.
