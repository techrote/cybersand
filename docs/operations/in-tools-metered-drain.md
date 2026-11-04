---
title: IN-TOOLS #361-A — opt-in metered physical Liquid Drain
status: Current
document-kind: guide
scope: Experimental U10 metered-drain-v1 candidate, supported quantity contracts, exclusive-owner execution, refusal and fault recovery, reproducible qualification and remaining acceptance gates
canonical-for: [in-tools-metered-drain]
last-reviewed: 2026-11-04
related-documents: [../systems/actor-usables.md, ../architecture/liquid-solver-family-policy.md, ../architecture/liquid-prepared-setup-and-receipts.md, ../architecture/data-ownership-and-lifetimes.md, ../reference/interfaces-and-message-contracts.md, ../reference/configuration-reference.md, ../audits/2026-11-04-in-tools-361a-metered-drain.md]
---

# IN-TOOLS #361-A — opt-in metered physical Liquid Drain

## Implementation and acceptance boundary

**Current candidate source:** `metered-drain-v1` adds exact quantity accounting
to the existing physical U10 `liquid_drain`. It uses the existing equipment,
physical actor session, worker admission and native World. Ordinary U10 remains
the default. Sampled usables, material IDs, production solver defaults, native
movement laws, the adapter ABI and Rapier coupling are unchanged.

The [dated qualification record](../audits/2026-11-04-in-tools-361a-metered-drain.md)
separates native primitive controls, actual Godot/worker execution, synthetic
desktop input and untested platform/human acceptance. This candidate does not
claim full #361-A acceptance until its remaining gates pass. Parent
[#361](https://github.com/techrote/cybersand/issues/361) stays open.

Planning authority is [#379 at `24d0e612`](https://github.com/techrote/cybersand/blob/24d0e612ae986edbdc48e5b94f52315d9c3d8421/docs/architecture/in-tools-gameplay-admission.md),
including its `in-tools.usable-liquid-drain.v1` registration. This implementation
does not require merging that preparation branch. The executable
[physical fixture v1](../../godot/tests/fixtures/in-tools-metered-drain.v1.json)
registers its own geometry and measured quantities; it does not relabel the
planned #379 tank or #370 comparison recorder as executed.

## Selecting and operating the profile

Use an existing supported physical actor with held equipment. Open **F5**, choose
**Liquid Drain**, then explicitly choose **Metered Water v1 — experimental** or
**Metered Brine v1 — experimental** and **Equip only**. The profile selector is
available only for physical U10. **Ordinary U10** selects the retained behavior.
Changing equipment requires the existing chassis to be held and the previous
pending use to be retired.

Aim with the pointer independently of movement. Hold left mouse or **M** to
request repeated pulses; release stops future uncommitted pulses. Right mouse
requests one precision pulse at 35% of selected equipment power. Opening a
blocking panel, losing focus, pausing or retiring control cancels the pending
intake. Release the buttons before rearming after cancellation or a new owner.

Stopping the worker retires pending equipment and its retained control
generation. A direct stop/start cannot revive that lease; a normal fresh control
boundary or reconstruction must precede another activation. Main ordinarily
stops the worker on scene exit; qualification joins for read-only census and
then explicitly establishes fresh control before resuming.
Healthy restart preserves the selected physical-owner mode. It does not enable
the sampled character or run sampled spawn recovery inside that physical World.

The actor status shows the cumulative registered sink and remaining allowance in
**Water units** or **Brine cells**. Its tooltip identifies the last applied,
refused or fault outcome, selected material, native generation and policy. A
refusal produces no accepted drain effect or recoil. The displayed allowance is
a finite permission to remove material, not an inventory of recovered liquid.

Current FreeMass Water and CY Brine work in ordinary native physical gameplay.
For IN, use the existing **PLAY** session panel: choose a physical rig, select
**Water: inertial**, set radius **3**, **Build selected session**, then play/resume
and equip metered U10 through F5. The existing **Mixed Current Water + inertial
Brine** preset similarly supplies a supported no-PF Brine owner. Authored
exploratory maps also support prepared physical actors. The native-default-demo
Liquids route excludes articulated equipment owners and is not this route.
A legacy/imported IN World without its initial native construction receipt
refuses this profile.
The metered selector does not itself change solver policy or normalize liquid.

## Quantity, resource and footprint contracts

| Property | Metered v1 behavior |
|---|---|
| Identity | Existing U10, catalogue index 9, ID `liquid_drain` |
| Range / radius | Authored range 29 and radius 4; existing power scaling shortens reach to `29 × lerp(0.35, 1, effective_power)` |
| Pulse bound | At most `ceil(16 × effective_power)` target cells, clamped to 1–16 for positive power |
| Precision | Effective power is selected power × 0.35 for the single alternate pulse |
| Accepted charge / cooldown | Fixed 0.85 charge and 0.10 seconds, independent of power and actual dose |
| Equipment capacity / recharge | Existing 100 charge and 6 charge per simulation second |
| Shared runtime bound | Existing 2,048 read units and 128 writes per step; complete metered pre/postflight capacity is reserved before editing |
| Experimental allowance | Per native World generation and actor slot: 32 × Q Water units and, separately, 32 Brine cells |
| Per-command quantity request | Positive integer, at most 16 × Q Water units or 16 Brine cells; removal also fits the remaining allowance |
| Refill | Only a verified replacement of the native World/generation; equipment selection, material switching, pickup and actor-session reset do not refill live stock |
| Owner lifetime bound | A completed native tick above 2^31 refuses with `fresh_owner_required`; explicit reconstruction is required |

Here `Q = (1 << mass_bits) - 1`, read from the actual native Water policy. Thus
Q is 7 at three bits and 255 at eight bits. The profile accepts native precision
3–8; the executable endpoint controls qualify three and eight bits.

| Selected material / applied family | Quantity authority and eligibility |
|---|---|
| Water / FreeMass | Sum actual stored `state_a`; partial cells are valid. Removing a cell with two units debits two units, not Q or 255. |
| Water / IN or CY reference | Every selected live Water cell must contain exactly Q. Fractional live input refuses; possible construction normalization is not permission to erase it. |
| Brine / IN or CY reference | Count actual stored Brine cells. Never interpret Brine `state_a` as Water quantity. |
| Any World containing PressureFlow | Refused by this version, including a Brine request in a PF Water World. Its extra state transitions are outside the restricted erase qualification. |
| Other materials, variants or invalid/radius-mismatched policies | Refused with no effect debit. IN requires applied radius three. |

The footprint starts at the first selected-material contact along a supercover
ray from the physical muzzle. Candidate cells lie in the authored radius-four
disc and are chosen in deterministic row order. Each selected target also has
its own supercover visibility check; diagonal corner blockers count. Hard terrain,
other intervening material and any body mask block the relevant sight path.
This prevents the edge of a wide intake from reaching through a wall even when
the central aim ray is clear. Native copied observation of nonempty stored liquid
proves that the target is resident; no erase allocates a new chunk.

## Ownership, observations and failure semantics

[`physical_usable_runtime.gd`](../../godot/scripts/physical_usable_runtime.gd)
calls the owner-local
[`metered_liquid_drain.gd`](../../godot/scripts/metered_liquid_drain.gd) helper
only inside the existing worker consumption interval. The cancellation mutex
linearizes admission and the entire finite operation. Main supplies copied
equipment/body values; the worker prepares native masks from its captured
physical frame before consumption. No main-thread World writer, global state or
additional queue is introduced.

The version-2 request extends the ordinary request with `profile`, `material`,
`native_generation`, `policy_hash`, `world_instance_id` and `quantity_budget`.
The physical frame echoes these values plus the current `metered_request_id`.
Release retires that token immediately; latest held-state admission prevents a
quick press/release from reappearing through the ordinary edge replay. Existing
run/epoch, control generation, equipment epoch/instance, body, strictly increasing
sequence and lease checks still apply. Native ObjectIDs are signed opaque values;
nonzero identity, rather than positivity, is required.

All destructive preflight finishes before the first writer: equipment identity,
owner policy and health, finite positive bounds, charge/cooldown, full selected
target quantities, body masks, visibility, adapter bounds and reserved read/write
capacity. The helper uses `CyberDemoBridge.inspect_cell` for **stored** material,
quantity and mask state, then the existing radius-zero Empty edit. A void writer
or unchanged health flag is never counted as success. Every attempted edit has
copied native post-readback; positive totals come only from verified transitions.

Results are labelled **`host-local-native-observation-v1`**. They bind the
command and captured frame to native World object/generation, applied policy,
completed native tick and hard-surface revision. Initial native construction
receipts remain separately labelled; IN admission checks their canonical byte
hash. They are not per-command native receipts. The adapter exposes no
separate native pose revision: the result says so and records the captured
physical-frame/mask provenance instead. Whole-World censuses in the fixtures
independently check the local transition ledger; production does not run a
full-World scan for every pulse.

A **normal refusal** performs no destructive edit, consumes no effect allowance,
charges no activation cost and starts no new cooldown. Ordinary simulation time
may still recharge charge and age an existing cooldown. A command consumed as
refused cannot later retry because its intake becomes clear. Admission-only
refusals are labelled `not_dispatched`; they do not fabricate an inspected
target set or fresh native per-command receipt.

An **unexpected execution fault** is distinct. The helper latches terminal
*before* the first writer. It retains attempted transitions, verified partial
quantity and whether quantity verification is complete. The worker then pauses,
retires pending effects/brush commands and publishes failure evidence alongside
the last valid render/cell publication. It cannot continue a native tick, retry
the command or publish partial cells as a healthy frame. Restart preserves that
quarantine while allowing an explicit existing clear/prepared reconstruction.
No liquid repaint or velocity rollback is attempted. Process death or an
uncatchable native exception cannot be converted into a surviving host receipt.

## Reproducing the focused checks

Use the pinned, source-matched native and Rapier runtimes and the repository's
Godot version. The three `test_physical_metered_*.gd` files are discovered by the
existing Godot regression route. A direct focused run uses:

```sh
godot --headless --path godot --editor --import
godot --headless --path godot --script res://tests/test_physical_metered_drain.gd
godot --headless --path godot --script res://tests/test_physical_metered_equipment.gd
godot --headless --path godot --script res://tests/test_physical_metered_desktop.gd
python3 tools/lcb/run_metered_drain_native.py --output-dir build/metered-drain-native-run
python3 -m unittest discover -s tools/lcb -p test_metered_drain_native.py -v
```

The native runner requires a **new** output directory, compiles the source, seals
source/compiler/executable identity and validates a complete typed result census.
It is a standalone scoped control command, not an additional registered hosted
Native job. Native-only controls cannot establish actor input or Rapier safety.
Headless Main plus injected input events cannot establish graphical pacing,
physical mouse/keyboard operation, Windows execution or owner handling feel.

Controlled quantity arms disable reactions and unrelated sources/edits and check
`initial + admitted sources - explicit sinks = remaining stored quantity` after
accepted operations and drain shutoff. Water units and Brine populations remain
separate. Wall positions, forbidden-side cells and actual native masks accompany
quantity totals. Command-owner timing and native tick timing are separate;
configured worker count is accompanied by observed native phase claimants.

The result's `reads_used` conservatively counts native calls inside the metered
effect preflight/write/readback section. The shared runtime additionally counts
its existing source-clearance and observation reads. Lifecycle metadata refresh
and existing scalar setup/health calls are outside that historical material-work
counter. Owner-command timings in the fixture include runtime work; the helper's
`command_overhead_usec` is narrower and excludes queue/input, source clearance,
native ticking and graphical presentation. Neither is a frame-time guarantee.

## Remaining boundary for #361-B

Reversible valves are not implemented or authorized by this profile. A successor
must separately qualify opening **and** closing, exact aperture geometry,
unoccupied/unmasked closure, partial-edit faults, current physical ownership and
zero new momentum. Resident liquid removal does not prove safe solid insertion,
multi-cell closure atomicity or rollback. If the existing API cannot preflight
those mutations without uncertainty, propose a separate minimal native contract
instead of broadening this application helper. Directed nozzles, arbitrary
velocity, pressure algorithms and production-policy changes remain outside scope.
