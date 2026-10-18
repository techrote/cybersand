---
title: MAT-002 aqueous phase quantities and bounded quenching
status: Current
document-kind: evidence
scope: Source-qualified partial Water phase inventory and cumulative quench repair, with explicit runtime and physical-model limits
canonical-for: [mat-002-phase-quantity-evidence]
last-reviewed: 2026-10-18
related-documents: [../systems/water-design.md, ../systems/intermaterial-interactions.md, ../reference/level-saves-and-replay.md]
---

# MAT-002 aqueous phase quantities and bounded quenching — 2026-10-18

## Authority and frozen baseline

The owner authorized the proposed material-behavior implementation after MAT-001:
quantity must not inflate when partial Water changes phase, and tiny coolant
contacts must not complete full-cell hot-material quenching. Issue #160 owns
`mat/phase-quantity-quench`, starting at main
`ec05d7227885bda59bf72a5889b004296b9a07e5`. The restart-resolved comparison-build
incident is not a source regression premise. No unrelated native implementation
PR was open at intake; player PR #148 remains untouched.

## Reproduction before repair

GitHub-hosted run `39103329047`, job `117603900622`, compiled the public-World
quantity tests against production source proven byte-identical to the baseline.
The run used Ubuntu 24.04, GCC 13.3, C++20/O1 and bounded five-minute compile/run
commands. Its expected-failure artifact `mat002-baseline-39103329047` retains all
nine failing groups; success of that workflow means **the failures reproduced**,
not that old behavior passed.

The first evaporation counterexample was mass3, one-unit Water contacting Lava:
Steam represented the full seven-unit parcel instead of one. Independent groups
also reproduced repeated-cycle inflation, freezing inventory change, coolant
accounting loss, payload loss during lifetime/movement, charged-Metal inflation,
and quantity differences at masks and signed/core/chunk seams. Invalid new-contract
payloads were admitted by the baseline. These failures remain retained controls.

## Source-qualified implementation

Run `39103710577`, job `117605029921`, applied the guarded exact-source repair,
passed all nine focused quantity/quench groups and the entire core suite, then
published source commit `dd4f6ca01d4bf29d009d62f3142531bef99ed474`.
The suite contains 71 top-level tests: the 70 existing tests plus the nine-group
MAT-002 aggregate. Evidence artifact `mat002-candidate-39103710577` retains the
focused/core logs and file hashes. No original full-contact product/probability
oracle was deleted or regenerated to match changed traces.

| Native source/test input | SHA-256 |
|---|---|
| `native/src/world.cpp` | `12334b9984be195e3fd17dfd188e634fa9f55f4a86ba8b89230edd786f684fe8` |
| `native/include/cybersand/world.hpp` | `7a06d72e8359aabe02d84a49384c1561fa63ef5be0d1329ce355eceef070c302` |
| `native/include/cybersand/interaction_rules.hpp` | `f20a5871ba1155ce1ab60347be309f7a8a29caf1f448971e1a8b31f97522c887` |
| `native/tests/test_world.cpp` | `01f8bb21fd8f48df07bc796e923470bbeca4d4db83ca4f4d6b0997c0af4508ef` |
| `native/tests/phase_quantity_tests.hpp` | `bafdd0caf5a54d2088f77a18ab4b3b2155d4a1b2344684d28b3044cc4022151e` |

The [phase contract](../systems/water-design.md#how-do-water-steam-and-ice-preserve-quantity)
owns quantity encoding, preserved states, the full-cell coolant threshold and
chemical source/sink limits. Water/Steam/Ice conversions conserve the fixture's
combined integer inventory. Steam/Glass cooling writes preserve their added state;
unchanged Water/Ice/Lava participants are no longer reinitialized. Both pair
product plans are captured before either write. Movement, native Water flow,
cadence, probabilities, masks, worker ownership and existing Stone support remain
separate controls.

The follow-up preflights material-local diagnostic rectangle bytes before any
Godot-side write. A new automatically discovered real-Godot regression covers
partial/full evaporation and condensation in both orientations, quench progress,
legacy Steam, exact CYSD1 payload round-trip and invalid import/diagnostic
non-mutation. Those adapter/save checks require a newly rebuilt runtime; their
presence is not recorded as execution until the runtime checkpoint below.

## Validation scope and remaining gates

The core tests cover Water mass3..8, partial/full quantity, both pair orientations,
repeated phase cycles, cumulative and overshooting quench doses with explicit
source/sink ledger, payload movement/relocation, Steam/Ice contact, charged Metal,
mask exclusion/unmasking, interest pause/re-entry, signed/core/chunk seams, real
one/four-worker execution with discovery observation, invalid inputs, and zero
post-setup World chunk/temperature allocations in prepared fixtures.

At this checkpoint the full native suite and focused groups are source-qualified;
new Godot/save execution, sanitizer extension, source-matched retained native
binaries and all applicable final PR checks remain pending. Required original
checks are Documentation/provenance, Native, GDExtension/Godot and issue49 Water
apparatus v2. Neither a stale runtime manifest nor a draft/ready-scope skipped job
is acceptance. Runtime publication and final CI are recorded as separate dated
checkpoints when executed.

## Deliberate limits and compatibility

The quench threshold is one full Water-cell equivalent, not a physical heat
capacity or energy calibration. Solid products remain whole cells; final contact
may exceed the threshold by less than one parcel, whose aqueous quantity remains
in Steam. Natural MoltenGlass cooling is independent. Old Steam condensation and
Ice freezing are still game rules rather than a thermodynamic field model.

Brine/Salt/Sodium/Sludge, growth, corrosion, painting and Cloner/Rocket emissions
remain explicit chemical/source/sink boundaries. No global chemical mass,
stoichiometry, energy, steam expansion, crust mechanics or broad gameplay realism
has been qualified. Shader output is not the inventory oracle.

The same Cell carrier and CYSD1 layout are retained. Legacy b=0 phase initialization
means full inventory; arbitrary invalid new state is refused. Older executables
can misinterpret or erase the new bytes, so layout compatibility does not promise
old-runtime semantic compatibility or replay continuation. Native Web compilation,
actual browser execution, Windows graphical feel and GPU performance must not be
inferred from Linux headless checks or a Windows cross-build.

## Documentation and ownership

Canonical Water/material/interaction/storage/save contracts, handover, roadmap,
entry routes and supplementary MAT03/MAT04 retrieval questions are updated together.
The frozen retrieval development questions and historical M11/Water/MAT-001 evidence
remain unchanged. No API, material-ID, dependency-pin, capacity or default-transport
migration occurs. #30 remains the interaction programme owner; #95/#45 head/pressure
and broad player/body acceptance remain separate.
