---
title: IN-TOOLS fixtures, qualification and owner playtest
status: Planned
document-kind: guide
scope: Versioned issue 361 test-only preparation, reproducible native primitive probes, proposed host fixture schedule and future owner usability checks; no implemented gameplay or human acceptance claim
canonical-for: [in-tools-fixtures, in-tools-playtest]
last-reviewed: 2026-11-04
related-documents: [../architecture/in-tools-gameplay-admission.md, lcb-scenario-catalogue.md, lcb-manual-comparison-ux.md, ../systems/actor-usables.md, ../audits/2026-11-04-in-tools-admission.md]
---

# IN-TOOLS fixtures, qualification and owner playtest

## What can run now

This package provides **test-only native primitive characterization and proposal
validation**. The six host fixture plans are explicitly Planned. No new launcher,
playable valve, metered usable, momentum source or second comparison host is
installed. The [architecture](../architecture/in-tools-gameplay-admission.md)
owns admission and scope; the [dated audit](../audits/2026-11-04-in-tools-admission.md)
owns actual results and source identities.

From a checkout of this candidate:

```sh
python3 tools/lcb/in_tools_contract.py
python3 -m unittest discover -s tools/lcb -p test_in_tools_contract.py -v
python3 -m unittest discover -s tools/lcb -p test_in_tools_native_runner.py -v
python3 tools/lcb/run_in_tools_native.py --build-dir build/in-tools-361 --output build/in-tools-361/native.json
```

The native driver uses C++20 and pthreads, writes only the selected build/output
paths, and links unchanged production simulation sources into an isolated test
executable. It records compiler and executable SHA-256, exact source inputs,
command, timeout, exit and raw-output hashes. Inspect status and
`inputs_unchanged`; a process timeout, failed assertion, changed input or malformed
output is not a pass. This is not an execution of the shipped Godot extension.

To verify retained #370 inputs as well, fetch its source read-only and run:

```sh
git fetch origin refs/pull/370/head:refs/remotes/origin/review-pr370
python3 tools/lcb/in_tools_contract.py --check-comparison
```

The checker uses the **pinned commit**, not whatever head was just fetched.
Unavailable pinned objects refuse rather than substitute a newer fixture.
`source_inputs` is an inspected-contract lock, not an automatic update target.
A changed input requires source review and a new admission decision. Future
implementation will legitimately change these pins; do not silently regenerate
them to turn a failure green.

The optional `--packet <json>` checks a proposed `{command,receipt,owner}` copy.
Its result always retains `gameplay_qualified=false` and
`native_receipt_authenticated=false`. Synthetic tests intentionally supply
copies; passing them proves validation discrimination, not an actual native
command, desktop ownership or a physics law.

## Versioned fixtures and reuse

The registration is
[`in-tools-admission.v1.json`](../../godot/tests/fixtures/lcb/in_tools/in-tools-admission.v1.json).
It contains current-source hashes, immutable #370 reuse hashes, explicit units,
geometry, event boundaries, finite budgets and supported comparison families.
It is **not executable MicroScenario schema 2**, and no existing schema is
changed to accept it.

Reuse #370 commit `fbe82bcab8f821aac442c2bf59eb57b279717873`:

| Seed | Byte SHA-256 | Original meaning |
|---|---|---|
| `lcb.feel.leak-side.vented.v1` | `fa4cc145f9728fccf1ded17dd80e85151eea891b8e65c49933ddfd36edacff3c` | Vented tank, side opening, contained basin; internal transfer only |
| `lcb.feel.drain-bottom.sealed.v1` | `26e1026a2197645896746127d75fe8f9786821eae59c3689df6061957d8db18a` | Sealed tank, bottom opening, contained basin; internal transfer only |

Both seeds have 13,640 full Water cells, 3,478,200 units at 8 bits. Their original
definitions and campaign remain untouched. The candidate inherits the initial
material raster and replaces the event schedule **in a new definition with a
new ID and digest**; it must not execute original and sidecar opening events
twice. Geometry is half-open `[x,y,width,height]`. Tick k means after k completed
native ticks and before attempting tick k+1.

| New Planned fixture | Schedule / limits | What must be measured |
|---|---|---|
| `in-tools.valve-side.v1` | Vent 0; open 120; close 600; reopen 900; width 1/2/4 | Actual accepted closure/refusal, flow start/tail, remaining inventory, lateral IN motion and voids |
| `in-tools.valve-bottom.v1` | Closed control then open 120/close 600/reopen 900 | Same controls, positional floor protection and occupied closure refusal |
| `in-tools.sink-bottom.v1` | Explicit intake pulses 121/151/181/211; stopped 212–600; resume 601/631; 32-cell removal budget | Actual removed quantity, stop window, remaining liquid, blocked/empty/exhausted reasons |
| `in-tools.sink-side.v1` | Same bounded pulses after vent/open; 16-cell budget | Side intake, empty/body-mask protection and finite budget |
| `in-tools.source-channel.v1` | Four whole-cell source requests 120/180/240/300; 16-cell supply | Actual dose, output blockage, finite stock, left/right/down guide geometry; zero fresh motion |
| `in-tools.usable-liquid-drain.v1` | One current command, cancellation, delayed old-owner command after reset | Existing actor/equipment route, exact source identity, charge/cooldown, real applied quantity and published outcome |

Closed/open/reopen state is a command outcome, not a postulated success. If
liquid still occupies the aperture at 600, closure **must refuse** and preserve
it; the 900 open may then be an already-open refusal. Use the separate
empty-port control to prove an actual successful close/reopen. This avoids
quietly inventing liquid displacement to make a pleasant test result.

The ordinary usable must execute through the supported **Exploratory physical
actor route**. The fixed controlled #370 host disables physical usable effects;
giving its actor-free fixture a new label does not qualify player interaction.
The captured original #370 payload can be nested unchanged in the proposed
outer tool capture, but its scheduled-edit-only ledger cannot account these
new effects on its own.

## Fixture matrix and independent controls

| Requirement | Current preparation | Future actual-host gate |
|---|---|---|
| Whole Water / Brine | Native primitive probes; Water bits 3/8; distinct Brine counts | Selected material × actual family readback; complete Brine census |
| Fractional/invalid ingress | Native refusal/normalization controls and strict copied-packet negatives | Old session/receipt/body graph preserved; no implicit rounding or fallback |
| Valve cycles | Native test-only guarded primitive composition; Planned host schedule | Empty close accepted, occupied/body-masked close refused, reopen matches actual state |
| Drain active/stopped/empty | Native ledger primitives and proposed budget checks | Per-command sink, actual full-World totals, no new sink after release/cancel |
| Width/direction | Explicit registration | Same final geometry per comparator; trajectory and actual admitted dose |
| Workers 1/4 | Native tick parity and observed phase participation | Actual desktop native claimant observations; complete-body owner route |
| Core/chunk/signed seams | Native translated boundary probes | In-bounds 1024² host seams; no invented negative-domain application support |
| Hard walls/body masks | Native mask/Wall controls; source-traced owner order | Positional barrier checks, actual body pose/mask/collider publication and placement refusal |
| Reset/reconstruction | Native state continuation/fresh World controls | Repeated full owner stop/restart, new generation, delayed request and receipt refusal |
| No creation/deletion | Independent native ledger and supplied-copy consistency | Actual native full inventories + command ledger + registered source/sink budgets |
| Current FreeMass | Protected source pins and native comparator | Existing ordinary U10 behavior unchanged; separate radius 2 protected control |
| Shared material union | Not imported | Explicit #353-B/#358/#370 integration and actual bound-carrier readback before any claim |

Never substitute synthetic fences for a real extracted-request/cancel race.
Future tests must include a request already pulled into a local worker batch,
then a focus/reset/selection cancellation before the final mutex-protected effect
check. Also test duplicate consumed request, reused receipt, wrong equipment
instance/body, expired lease, native session mismatch and failed-owner publication.

The native multi-tank test is a different fixture from the six planned host
registrations. Its wide operation visits 32 targets across eight tanks; it does
not qualify the proposed 16-cell production command limit. V2 names the first
interior-reservoir census decrease `first_reservoir_depletion_tick`; the original
v1 called it `first_flow_tick`. Neither measures downstream crossing flux or tail.
V2 separately compares IN diagnostic-ledger traces and native restored
continuation, because the physical hash excludes those diagnostics. Independent
stored-cell inventories check all 393,216 cells in the 24 resident chunks at
completed ticks 0/8/24/32/64/224 and both continued Worlds at 232. Exact barrier,
escape and material-count controls complement per-tick ledger closure. The
[independent review](../audits/2026-11-04-in-tools-379-independent-review.md)
keeps original evidence and the corrected-source results separate.

Primary scientific fixtures contain only the selected liquid, Empty and Wall.
Every source/sink is declared; no chemistry or unobserved outflow is permitted.
Register one actual-body protection fixture separately without claiming splash
or contact-response research. A failure stops that candidate, retains artifacts
and narrows the next task; no increasing horizon or relaxing conservation after
seeing a result.

## Metrics, fairness and evidence requirements

| Metric | Exact observation / interpretation |
|---|---|
| Flow continuity | A future source-qualified crossing observer is required for true flux. Alternatively preregister a control-volume quantity-change proxy with no internal source/sink and label it as a proxy; report active-flow fraction and longest zero-change gap. A cropped count is not a crossing counter. |
| Startup | First accepted opening/source boundary to first observed downstream transfer; record censored “no onset by horizon” explicitly. |
| Shutdown | Last accepted source/sink or close boundary to last downstream transfer within fixed horizon. Downstream residual motion is allowed; closing an occupied port is not a successful shutoff. |
| Momentum persistence | Per-tick complete IN vx/vy/ax/ay digest, nonzero-cell count, extrema and signed component totals; retained motion must not be inferred from image displacement alone. |
| Voids | Stored Empty cells below liquid in a column, enclosed four-connected Empty regions and Water-bounded subset separately. IN has no gas-pressure state. |
| Quantity | Full-World stored Water units and independent Brine population; source and sink deltas per accepted event; foreign-material and wall position checks. |
| Worker cost | Native tick and command timings separately, configured pool, job count, actual claimants, warm/cold distinction. Claimants are not utilization or simultaneous execution. |
| Host cost | Owner-step duration, queue/receipt delay, main frame and publication age. Do not call native test elapsed time or headless speed graphical FPS. |
| State/memory | Native `inertial_storage_usage` component census, resident chunks/cells and peak old+candidate overlap. Record RSS separately with its broader scope. |
| Lifecycle | Queue admission → owner application → inclusion in a valid completed publication. A quarantined owner is not a completed successful gameplay action. |
| Usefulness | Source-bound owner ratings of targeting, readable refusal, predictable close, useful drain, finite supply and restart. All are UNTESTED in this package. |

### Matched FreeMass and inertial comparison

Water's matched lane is FM versus IN at radius 3, identical seed, precision,
initial full-cell quantity, geometry and horizon. Original Current FM at radius 2
is a separate compatibility control, not the same-geometry timing comparator.
Brine's eligible baseline is CY; there is no FreeMass-Brine comparison.
Matched source attempts may admit different actual doses. Publish both the
requested/admitted throughput and dose-normalized observations; do not silently
post-select a favorable subset or top up the slow arm invisibly.

#370's 96-row native campaign is retained evidence at its own source. Its
Windows/WSL legs overlapped on one machine, so their timing is not clean cost
evidence. Its later graphical host cohort is Windows-only, actor-free and
separately source-bound. The #361 package does not rerun, authenticate or broaden
those historical platform/host claims.

For each future qualified union record: full commit/tree and local delta;
fixture byte and canonical-definition hashes; compiled native source map;
actual runtime/module and Godot identities with unavailable bindings marked;
requested/applied material/family/variant/precision/radius; construction/native
receipt identity; owner generations; compiler/platform; command and bounded
timeout; raw-log/capture hashes; exact failed and completed observations.
Compare physical continuation and native diagnostic ledgers separately where
their hash contract excludes diagnostics. No observation capture is a full save.

Start actual desktop qualification with the metered-drain subset and one
registered port, workers 1/4 on Windows/Linux. Expand to the six planned fixtures
only after the authority and accounting subset passes. Run timings sequentially
without competing campaigns, rotate family order and use at least three fixed
repeats for a reported cost comparison. Performance thresholds must be registered
by that implementation task; this preparation selects no FPS or latency winner.

## Short owner playtest — all rows UNTESTED

After automated source-matched host qualification, use the existing comparison
panel and a fixed view/simulation speed. Capture each accepted request and its
actual result; do not ask the owner to infer policy or quantity from colors.

1. Open a side valve, close it while occupied, then after it has emptied. Check
   that the first refusal is understandable and the second close is visibly real.
2. Reopen it. Observe flow continuity, trailing motion and any cavities. Record
   preference separately from conservation/physics conclusions.
3. Start/stop the bottom drain. Confirm the removed-unit counter stops, remaining
   quantity is readable and an empty/exhausted intake does not spend a pulse.
4. Compare geometric outlet orientations with the same actual delivered dose.
   State explicitly that this version does not launch velocity-directed jets.
5. Equip the existing Liquid Drain. Aim, hold/release, switch focus, pause/resume,
   change selection and reset. Require fresh input before it acts again.
6. Repeat the chosen Water view with Current FM. Rate useful control, visual
   readability, perceived delay and overall preference 1–5; attach both captures.

| Owner observation | Result |
|---|---|
| Valve makes its actual state/refusal clear | UNTESTED |
| Sink counter and remaining amount are useful | UNTESTED |
| Geometric source direction matches its stated capability | UNTESTED |
| Equipment/focus/pause/reset feels predictable | UNTESTED |
| Preferred FM/IN feel and useful context | UNTESTED |

Upward splash, realistic gas bubbles and Rapier-impact comparisons remain #362.
Do not merge this preparation automatically or close #361 on these registrations.
