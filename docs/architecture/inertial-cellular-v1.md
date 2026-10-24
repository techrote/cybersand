---
title: Brine inertial cellular reference
status: Current
document-kind: reference
scope: Native-only opt-in Brine IN checkpoint on the LCB-005 branch; current defaults retained, no Water-IN, Godot or runtime-publication qualification
canonical-for: [inertial-cellular-v1-brine]
last-reviewed: 2026-10-24
related-documents: [lcb-pressure-inertial-handoff.md, liquid-solver-family-policy.md, liquid-state-transition-matrix.md, liquid-prepared-setup-and-receipts.md, ../audits/2026-10-24-lcb005-native-brine-checkpoint.md]
---

# Brine inertial cellular reference

## What executes at this native checkpoint?

**Current on the LCB-005 branch only:** explicitly selecting Brine material24 / `inertial_cellular_v1/reference` executes retained signed motion and subcell accumulators. The default Brine CellularYield law and every other default remain unchanged. Water IN, alternate IN materials, cached/dormant IN variants, Godot presentation and released native artifacts are not qualified by this checkpoint. The [dated evidence](../audits/2026-10-24-lcb005-native-brine-checkpoint.md) names the base, local input seal, executable and actual tests. This is neither full #212 completion nor owner feel acceptance.

The source owners are `native/include/cybersand/inertial_cellular.hpp`, `native/src/world_inertial.inc` and narrow integration in `World`. Shared pair chemistry precedes the Brine yielding-liquid motion gate. The implementation contains no pressure/head term and applies no Rapier force.

## Which fields, parameters and law are authoritative?

The optional slot has signed16 `vx/vy` and signed8 `ax/ay`. Velocity/accumulators use16 quanta per cell. Admitted ranges are vx −32…32, vy0…32 and each accumulator −15…15. New products, paint and reconstruction default to zero. The actual stored slot is six bytes/alignment2 on the measured Windows LLVM ABI; this is not a production Cell ABI change or a portable raw-struct save format.

Fixed reference parameters are version1: q16, gravity4, vmax32, turn1/8, deflect3/4, damping1/16, density-swap drag1/4 and rest threshold1. The existing `inertial-update-v1` order is U1 support; U2 one gravity application; U3 diagonal re-aim or support cancellation and carried-velocity deflection; U4 saturation; U5 signed truncating damping; U6 accumulator travel with every target rechecked; U7 rest/sleep eligibility. First contact ends travel. Wall, body mask and same-family contact are inelastic; only Empty is horizontally enterable. A lighter foreign material is exchangeable only downward under the existing density/exchange gate.

The complete fixed parameter/state/update identity is canonical little-endian data hashed by `inertial_extension_identity()`. Unsupported caller parameter blocks refuse; there is no silently ignored damping request or automatic family fallback.

## Why does IN require radius three?

Travel writes reach at most two cells per axis: after saturation/damping |v|≤30 and |accumulator|≤15, so division by16 produces at most two unit moves. Eligibility is rechecked before each actual step. At most one extra neighborhood probe occurs after or alongside a final travel position. Starting vy32/ay15 reaches y+2 and U7 reads y+3; a contact-side query can similarly reach x±3. Shared powder-exchange Stone bracing inspects one further neighbor of a target within the same radius-three envelope. Brine does not execute the Water carrying stencil.

An IN World therefore explicitly requires `maximum_rule_radius>=3`. The existing scheduler validates radius≤half an even core, prepares neighbor chunks, and separates same-phase expanded domains. Candidate/control comparisons must use identical admitted execution geometry; the protected exact Current preset retains radius2. Native boundary tests exercise signed coordinates, core8/core64, chunk seams, observed read3/write2 reach, no prepared tick allocation and actual four-worker execution. Configured workers and observed task participants are separate `TickStats` values.

Water IN remains unavailable. Its carrying callback can reach farther relative to a later submove than to the original owner. It needs a separate complete stencil proof, real `maximum()` quantity, coherence, direct ingress refusal and the existing normalization preparation before admission. Radius3 Brine proof does not qualify it.

## How does optional state follow its cell and session?

`Chunk::inertial` owns a dense vector when any admitted material in the World selects IN. It is optional by World policy and allocated for every resident chunk, including Empty/foreign-material chunks. Moves, density swaps and body displacement transport the owning slot with the complete tuple and stored temperature. Vacancies and foreign families contain zero IN state.

Current `write_cell` and public paint paths reset IN on external writes, new products or material change. They include a family-only difference in mutation, activity, dirtiness and discovery publication even when the visible tuple is identical. Ordinary same-material lifecycle state updates retain motion. A Brine/BareIron reaction produces a fresh Brine slot despite preserving Brine material identity. Generated chunks use the current shared writer; clear/rebuild retires optional storage and the ledger. Refused prepared candidates never replace the existing session.

Signed per-component impulse, gravity, speed loss, support loss, truncation remainders and retirement remain separate diagnostics. External L1 changes are summed per edited cell before aggregation; `abs(sum external_x)` is not used as a speed-source estimate. IN ledgers are serialized and validated but are separately compared from the complete physical hash.

## Which hash, capture and receipt versions apply?

Non-IN Worlds keep physical hash2 and CYPS2 field emission. IN Worlds use instance `physical_state_hash_version()==3` and `physical_state_format_version()==3`, with explicit fixed identity, slot fields and ledger. CYPS3 uses validated field encodings, not C++ padding. Restore accepts current CYPS2 for non-IN, requires CYPS3 for IN, validates all current quantity/gas/scheduler obligations and rejects inconsistent required sidecars, unknown identity, invalid ranges and motion on another family. The old saved candidate's incompatible format2 is not reinterpreted as current CYPS2.

`capture_native_facts` remains the exclusive native boundary. It adds family4/state-contract1/extension-identity1 with the complete fixed identity digest through the existing outer receipt-v1 extension field. Its physical hash version comes from the actual instance. Host source/runtime claims remain explicitly unverified. Exact continuation retains clocks, actual epochs, activity/deadlines, interest and pending work; content plus completed tick does not reconstruct those obligations. Host-owned masks/actors and settled discovery retain their existing persistence refusals/ownership limits. This does not implement GEN-006 streaming.

Static-rest observations require zero vx/vy/ax/ay and stable physical content. The complete continuation hash still changes with advancing clocks. The root-owned separately named quiescent projection is integrated separately; no historical `content_hash` or `state_hash` definition is changed here.

## What does the storage readback measure?

`inertial_storage_usage()` reports actual slot size/alignment, resident optional arrays, capacity and nonzero slots; array bytes; vector/pointer owner components; per-job IN ledger capacity; fixed World IN members; and their declared component sum. Allocator bookkeeping, inter-member padding, shared World/scheduler/PF/temperature/snapshot resources and process RSS are explicit exclusions. `resident_cell_bytes()` keeps its legacy meaning and is not a complete IN memory metric.

At128² one dense six-byte array is98,304 bytes; at1024² it is6MiB; at2048² it is24MiB. Base C64 plus IN arrays are14MiB/56MiB respectively, before other owners. Enabled-but-unread and sparsely populated Worlds still pay the full resident dense-array cost. Count old/candidate Worlds, captures and temporary serialization buffers simultaneously. The [fresh #204 handoff](https://github.com/techrote/cybersand/blob/7084438425a2025210d4451572dd17d2e1d59961/docs/research/mat003-remaining-acceptance.md) provides neutral-array controls, not actual IN memory or performance acceptance.

## How is this checkpoint exercised?

`make build/tests` followed by `./build/tests "LCB-005"` selects the native IN groups. `build_windows_msvc.bat` includes the same source; platform execution must still be recorded separately. The saved eleven numeric examples retain their exact expectations, including sleep after the final dirty-state publication. Added checks cover complete radius, observed worker participation, same-visible paint/products, mask refusal, generated defaults, actual storage, native receipt identity, valid-digest incompatible states and continuation through epoch wrap. Three-family controls execute FreeMass Water/CY Oil/IN Brine and a PF Water substitution with exact counts/Water quantity and ledger comparison. Native success does not qualify the separately owned application adapter or released binaries.
