"""One-shot, exact-source MAT-002 adapter and documentation integration.
Removed after application; no network or branch operations in this script.
"""
from pathlib import Path
import hashlib
import json
import re


def replace(path, old, new, count=1):
    p = Path(path)
    text = p.read_text()
    if text.count(old) != count:
        raise RuntimeError(f'{path}: expected {count} matches: {old[:90]!r}')
    p.write_text(text.replace(old, new))


def section(path, heading, body):
    p = Path(path)
    text = p.read_text()
    if heading in text:
        raise RuntimeError(f'{path}: section already exists')
    match = re.search(r'^## ', text, re.M)
    if not match:
        raise RuntimeError(f'{path}: no section anchor')
    text = text[:match.start()] + heading + '\n\n' + body.strip() + '\n\n' + text[match.start():]
    text = re.sub(r'^last-reviewed: .*$', 'last-reviewed: 2026-10-18', text, count=1, flags=re.M)
    p.write_text(text)


replace('godot/native_extension/cyber_native_cell_world.cpp',
'''    const auto value = static_cast<cybersand::Material>(material);
    const auto state_a = value == cybersand::Material::Water''',
'''    const auto value = static_cast<cybersand::Material>(material);
    const auto& policy = world_->config().water_experiment_policy;
    // Validate the entire rectangle's material-local payload before its first
    // write. Invalid diagnostic input must not throw through the Godot binding
    // or leave a partially applied rectangle/revision behind.
    if ((value == cybersand::Material::Water && state_b > policy.coherence_ticks()) ||
        ((value == cybersand::Material::Steam || value == cybersand::Material::Ice) &&
         state_b > policy.maximum()) ||
        ((value == cybersand::Material::Lava || value == cybersand::Material::MoltenGlass) &&
         state_b >= policy.maximum())) return false;
    const auto state_a = value == cybersand::Material::Water''')

section('docs/systems/water-design.md',
        '## How do Water, Steam and Ice preserve quantity?', '''
**Current MAT-002 software candidate / #160:** evaporation, condensation, freezing
and melting retain the exact integer aqueous quantity on the selected Water
lattice. Let `M = 2^mass_bits - 1` (normally 255; experimental policies use 3..8 bits).
The implementation lives in [World](../../native/src/world.cpp), with retained
[public-World regressions](../../native/tests/phase_quantity_tests.hpp) and a
[real Godot adapter/save regression](../../godot/tests/test_phase_quantity_regression.gd).
The [dated evidence](../audits/2026-10-18-mat002-phase-quantity.md) separates
source qualification from runtime/owner acceptance.

| Material-local state | Meaning |
|---|---|
| Water `state_a` | Aqueous quantity 1..M; Water `state_b` remains coherent-emission delay |
| Steam `state_a` | Existing lifetime; changing it must preserve the quantity byte |
| Steam / Ice `state_b = 0` | Legacy or painted full parcel: exactly M, **not zero inventory** |
| Steam / Ice `state_b = 1..M` | Explicit aqueous quantity; new full parcels canonically use zero |
| Lava / MoltenGlass `state_b = 0..M-1` | Accumulated Water-quench progress, in the same integer coolant units |

Water-to-Steam pair rules and charged-Metal evaporation retain the original Water
quantity. Steam expiry or Steam/Ice contact returns that amount, not a fresh full
cell. Ice melting and Water freezing retain quantity as well. Motion, conservative
swaps and serialized body relocation carry the existing compact state. Unchanged
Water, Ice and Lava pair participants preserve their state rather than being
reinitialized. Merely waiting or observing does not invent additional quantity.

### Why does a tiny Water parcel no longer instantly turn Lava into Stone?

For Water contacting Lava or MoltenGlass, each selected contact adds the parcel's
actual quantity to that hot cell's quench progress. The hot cell remains liquid
until cumulative coolant reaches M, then becomes the existing Stone or Glass
product. A full Water cell therefore keeps the original full-contact result;
several small contacts accumulate instead of each generating a whole solid cell.
MoltenGlass's separate cooling timer and Lava/Glass interactions preserve progress.

The contacting Water parcel becomes Steam in full, retaining its quantity even
when the threshold is crossed. Solid products remain whole cells, so completion
can overshoot the threshold by less than the final parcel. This is a deliberately
bounded **game-scale coolant-contact budget**, not a temperature equation, joules,
latent heat, a physical steam-expansion law or universal energy conservation.
Natural MoltenGlass cooling remains a separate existing path. Stone's existing
brace/support behavior is unchanged; broad crust/bridge realism is not accepted
by quantity conservation alone.

### Which reactions remain outside the closed phase ledger?

A closed Water/Steam/Ice thermal fixture sums Water `a` plus decoded Steam/Ice `b`.
Existing liquid-only `liquid_mass` and Water observation counters still omit
vapor/ice and must not be used alone as that combined ledger. Brine and Sludge
are still whole-cell chemical materials, not a quantitative mixture model. Sludge
purification preserves the original Water parcel and adds one explicitly modeled
full Water cell from Sludge; it must not refill both cells. Brine-to-Steam recipes,
painting, Cloner/Rocket emissions and direct replacement are explicit sources or
sinks. Salt/Sodium chemistry, Acid corrosion, growth and explosions have their own
accounting boundaries. No global species/mass conservation claim follows.

Invalid explicit phase quantities and unfinished quench progress are rejected by
World input validation; the Godot diagnostic rectangle preflights these fields
before any write. CYSD1 retains the same bytes/layout, with the
[save compatibility limits](../reference/level-saves-and-replay.md#mat-002-phase-payload-compatibility).
Native Water transport, mass/coherence defaults, scheduler ownership, pressure/head
successor gates and fallback semantics are unchanged by this phase pass.
''')
replace('docs/systems/water-design.md',
        'canonical-for: [native-water-semantics, native-fallback-water-differences]',
        'canonical-for: [native-water-semantics, native-fallback-water-differences, aqueous-phase-quantity, water-quench-budget]')
replace('docs/systems/water-design.md',
        'scope: Native conserved Water, coherent emission and adhesion, rest/hash fixtures, fallback differences, and future reaction accounting',
        'scope: Native Water transport and phase quantities, bounded quench progress, coherent emission, rest/hash fixtures, fallback differences and remaining reaction accounting')

section('docs/systems/materials-and-rule-kernels.md',
        '## MAT-002 phase quantity and quench state', '''
**Current software candidate / #160:** Steam and Ice use `state_b` for retained
aqueous quantity, with zero retaining the legacy/full-parcel meaning. Lava and
MoltenGlass use `state_b` for cumulative Water-quench progress. Steam lifetime and
MoltenGlass cooling updates preserve these fields. Water's mass and coherence
states, all material IDs and descriptor defaults remain unchanged.

The [Water phase contract](water-design.md#how-do-water-steam-and-ice-preserve-quantity)
owns the exact lattice/sentinel, threshold, chemical-source and physical-model
limits. The [versioned interaction substrate](intermaterial-interactions.md#mat-002-versioned-quantity-execution)
owns affected rule identities. Ordinary full-contact products/probabilities and
coordinate cadence remain controls, not proof that partial contacts are unchanged.
The [dated audit](../audits/2026-10-18-mat002-phase-quantity.md) scopes executed tests.
''')
replace('docs/systems/materials-and-rule-kernels.md',
'''World owns the four-byte Cell: material, `state_a`, `state_b`, update epoch.
The two generic bytes hold material-specific mass, lifetime, burn/growth,''',
'''World owns material identity, `state_a`, `state_b` and update epoch through the
existing [superset carrier](../architecture/chunk-tile-and-buffer-model.md#what-is-stored-per-cell-and-per-chunk).
Its two logical state fields hold material-specific mass, lifetime, burn/growth,''')

section('docs/systems/intermaterial-interactions.md',
        '## MAT-002 versioned quantity execution', '''
**Current software candidate / #160:** schema remains version 1; the
`int.current-behaviour` profile is version **2**. The original
`int.pass.current-oracle` remains the retained parent of
`int.pass.mat002-phase-quantity`, whose disposition is `bounded-software-candidate`.
The changed pair rules are `lava-water.quench`, `fire-water.extinguish`,
`water-sodium.react`, `water-toxic-sludge.purify`, `steam-ice.condense`,
`water-molten-glass.quench` and `lava-glass.melt`; their `int.pair.*.v2` entries
carry explicit version, v1 supersession, pass identity and accounting.
Steam condensation, Metal charge, MoltenGlass cooling, Lava contact and Ice phase
specialized `int.kernel.*.v2` entries likewise identify their changed state semantics.

The frozen 14-rule product/probability oracle remains a **full-contact recipe**
control. It is not an assertion that partial-quantity runtime execution is unchanged:
World now plans both product states before writing either participant, preserves
unchanged aqueous/hot state, and conditionally retains a hot material until its
coolant threshold. The
[Water contract](water-design.md#how-do-water-steam-and-ice-preserve-quantity)
defines that bounded model and explicit chemical sources/sinks. Read
[MAT-002 evidence](../audits/2026-10-18-mat002-phase-quantity.md) before reusing old
interaction captures; earlier profiles/artifacts retain their original identities.
No general heat field, dense chemistry table or new kinetic solver is introduced.
''')
replace('docs/systems/intermaterial-interactions.md',
        '- profile ID int.current-behaviour, version 1;',
        '- profile ID int.current-behaviour, version 2 (MAT-002 quantity execution);')

section('docs/reference/level-saves-and-replay.md',
        '## MAT-002 phase payload compatibility', '''
**Current software candidate / #160:** CYSD1 still stores the same material/a/b/
temperature payload. Steam/Ice aqueous quantity and Lava/MoltenGlass quench progress
therefore survive exact payload export/import without adding fields or changing
Cell allocation. The [phase state contract](../systems/water-design.md#how-do-water-steam-and-ice-preserve-quantity)
defines the new material-local interpretation.

Existing ordinary Steam/Ice payloads with `state_b=0` retain the legacy full-cell
meaning. Previously arbitrary nonzero bytes are now meaningful quantities/progress;
invalid values are refused during replacement construction, leaving the active
World intact. The new Godot regression checks exact round-trip, retained quantity,
legacy initialization and invalid-import non-mutation through the real adapter.

Layout compatibility is **not backward semantic compatibility**: an older runtime
can discard or misinterpret these newly used bytes. Use matching source/runtime
and the same Water policy; CYSD1 is not a complete policy/replay container and does
not authorize resuming low-precision experimental state under a different lattice.
No exact next-tick continuation or old-runtime compatibility is claimed.
''')
replace('docs/reference/level-saves-and-replay.md',
'''The authoritative hot cell remains four bytes. Save bytes intentionally exclude
its update epoch and add temperature from the optional field; the five-byte
save layout is not the in-memory `Cell` ABI.''',
'''The [current in-memory carrier](../architecture/chunk-tile-and-buffer-model.md#what-is-stored-per-cell-and-per-chunk)
is separately specified. Save bytes intentionally exclude its update epoch and
add temperature from the optional field; the five-byte save layout is not the
in-memory `Cell` ABI.''')

section('docs/architecture/chunk-tile-and-buffer-model.md',
        '## MAT-002 material-local state reuse', '''
The [Water phase contract](../systems/water-design.md#how-do-water-steam-and-ice-preserve-quantity)
assigns existing Steam/Ice `state_b` to aqueous quantity and Lava/MoltenGlass
`state_b` to bounded quench progress. No carrier size/alignment, chunk geometry,
per-cell allocation, render payload width or scheduler ownership changes. The
quantity helper reads the same bounded contact neighborhood; both product states
are captured before in-place pair writes. Default Water remains mass8/coherence12.
''')

section('docs/reference/status-and-roadmap.md',
        '## MAT-002 material phase checkpoint — 2026-10-18', '''
**Implemented software candidate:** #160 follows merged MAT-001 / #158 with exact
Water/Steam/Ice phase inventory, retained same-material state and a bounded
cumulative Water-quench budget for Lava/MoltenGlass. The original full-contact
recipes remain controls; tiny parcels no longer gain a full aqueous inventory or
instantly complete a whole hot-cell quench. See the
[canonical phase contract](../systems/water-design.md#how-do-water-steam-and-ice-preserve-quantity)
and [dated qualification](../audits/2026-10-18-mat002-phase-quantity.md).

The core nine-group regression and complete native suite passed before the
Godot/input/save follow-up. Source-matched runtimes and final normal CI remain
integration gates. Windows graphical game-feel acceptance, general heat/energy
semantics, broad chemistry and Water #95/#45 head/pressure work are separate.
''')
section('docs/operations/cybersand-codex-development-handover.md',
        '## MAT-002 phase quantity follow-up — 2026-10-18', '''
Issue #160 / branch `mat/phase-quantity-quench` owns the owner-authorized phase
quantity and cumulative-quench implementation after MAT-001. Read the
[phase contract](../systems/water-design.md#how-do-water-steam-and-ice-preserve-quantity)
and [qualification record](../audits/2026-10-18-mat002-phase-quantity.md), not just
the prior full-cell product oracle. Steam/Ice quantity and hot-cell progress reuse
state bytes; same-source native runtimes are mandatory before integration. The
new real-Godot `test_phase_quantity_regression.gd` is automatically discovered by
the existing regression runner. #30 and the independent #95/#45 gates remain open.
''')
section('docs/README.md', '## MAT-002 phase quantity route', '''
For partial Water evaporation/condensation, Ice quantity or Lava/MoltenGlass
quenching, use the [Water phase contract](systems/water-design.md#how-do-water-steam-and-ice-preserve-quantity),
[save compatibility](reference/level-saves-and-replay.md#mat-002-phase-payload-compatibility)
and [dated evidence](audits/2026-10-18-mat002-phase-quantity.md).
''')
section('docs/reference/retrieval-index.md', '## Water phase quantity and quench progress', '''
Why does partial Water retain its quantity through Steam and Ice, and why does a
tiny parcel not instantly solidify Lava? Read the
[Water phase contract](../systems/water-design.md#how-do-water-steam-and-ice-preserve-quantity).
For payload persistence and old-runtime limits use
[phase save compatibility](level-saves-and-replay.md#mat-002-phase-payload-compatibility).
The [MAT-002 audit](../audits/2026-10-18-mat002-phase-quantity.md) carries dated evidence.
''')

corpus_path = Path('docs/reference/retrieval-corpus.json')
corpus = json.loads(corpus_path.read_text())
corpus['reviewed'] = '2026-10-18'
corpus['excluded'].append({
    'path': 'audits/2026-10-18-mat002-phase-quantity.md',
    'reason': 'Dated phase-quantity and quench candidate evidence; use with exact source/runtime/platform identity'
})
corpus_path.write_text(json.dumps(corpus, indent=2, ensure_ascii=False) + '\n')
questions_path = Path('docs/reference/retrieval-challenges.json')
questions = json.loads(questions_path.read_text())
questions['purpose'] += ' MAT03/MAT04 cover MAT-002 aqueous phase quantity and cumulative quench progress.'
questions['questions'] += [
    {'id': 'MAT03', 'query': 'How does partial Water preserve quantity when evaporating into Steam, condensing or freezing into Ice?',
     'canonical': ['systems/water-design.md'],
     'facts': ['Steam/Ice state_b retains Water-lattice quantity; zero is the legacy full-cell sentinel.',
               'Steam lifetime and thermal conversions preserve exact quantity; liquid-only observations omit Steam and Ice.',
               'This closed phase ledger does not claim global chemical/species or energy conservation.'],
     'sources': ['../native/src/world.cpp', '../native/tests/phase_quantity_tests.hpp']},
    {'id': 'MAT04', 'query': 'Why does a tiny Water parcel no longer instantly turn Lava into Stone, and how is quench progress counted?',
     'canonical': ['systems/water-design.md'],
     'facts': ['Lava/MoltenGlass state_b accumulates actual coolant quantity until one full Water-cell equivalent.',
               'The contacting Water remains quantity-bearing Steam; whole-solid completion may overshoot by less than a parcel.',
               'The threshold is a bounded game-scale contact budget, not a latent-heat/temperature solver.'],
     'sources': ['../native/src/world.cpp', '../native/include/cybersand/interaction_rules.hpp']},
]
questions_path.write_text(json.dumps(questions, indent=2, ensure_ascii=False) + '\n')

native_inputs = ['native/src/world.cpp', 'native/include/cybersand/world.hpp',
                 'native/include/cybersand/interaction_rules.hpp', 'native/tests/test_world.cpp',
                 'native/tests/phase_quantity_tests.hpp']
rows = '\n'.join(f'| `{p}` | `{hashlib.sha256(Path(p).read_bytes()).hexdigest()}` |' for p in native_inputs)
Path('docs/audits/2026-10-18-mat002-phase-quantity.md').write_text('''---
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
''' + rows + '''

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
''')
print('Applied adapter admission, canonical phase state contracts and dated qualification routes.')
