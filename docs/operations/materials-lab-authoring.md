---
title: Materials Lab v1 inspection, candidate authoring and native tests
status: Current
document-kind: runbook
scope: Implemented desktop review candidate; native inspection, source candidates, isolated compiled World comparisons and existing-material MicroScenarios; no production material migration or runtime candidate activation
canonical-for: [materials-lab-v1-ui, materials-lab-candidate-presets, materials-lab-native-experiments]
last-reviewed: 2026-11-12
related-documents: [../MATERIAL_LAB.md, material-catalogue-shadow.md, microscenario-reference-pack.md, ../architecture/material-authoring-catalogue-plan.md, ../systems/intermaterial-interactions.md, ../audits/2026-11-11-materials-lab-v1.md]
---

# Materials Lab v1

**Current implementation in [Draft PR #562](https://github.com/techrote/cybersand/pull/562);
production activation remains unimplemented.** The desktop **Materials Lab** opens from the feature launcher,
the ordinary Shared Workbench's **Materials Lab…** button, or `--materials-lab`.
It combines native material inspection, structured candidate editing, compiled
candidate tests, a compiled candidate/reference World comparison and an isolated native MicroScenario. The
[dated qualification record](../audits/2026-11-11-materials-lab-v1.md) distinguishes
the preceding implementation's evidence. The
[completion record](../audits/2026-11-11-materials-lab-completion.md) owns the subsequent
native contact diagnostics, runtime publication and Windows package qualification.

On supported desktop displays, the Workbench opens the Lab in its own native
window, preserving physical-pixel text and local input while the game retains
its canvas scaling. Headless/Web displays retain the embedded fallback. Closing
the Lab returns to the same Workbench session; its owner policy is refreshed
when reopened.
Native placement fits the client, title bar and borders within the usable
desktop work area on the owning screen. A desktop too small for the existing
1000x650 client plus its borders receives an explicit capacity refusal.

The Lab uses the accepted [catalogue compiler](material-catalogue-shadow.md).
It does not replace native production definitions, the simulation worker, the
Workbench or World. Production still has 132 slots, including invalid reserved
ID 10. The synthetic powder at 132 exists only inside an external candidate build.

The five tabs are **Inspect**, **Edit copy**, **Reactions**, **Try originals**
(unchanged built-in materials) and **Compare edits** (your copy against the
original). In Inspect, drag the edge between column titles to set widths;
double-click a divider to restore its width. The table scrolls sideways if it
gets wider than the window. **Defined value** is the saved definition; **Value
used** includes engine overrides. Hover any cell to read the whole explanation
and its technical name. **Show technical details and reaction data** reveals
the full reference information.

## Launch and prerequisites

Use a complete checkout of the implementation branch and its history. Git LFS
and the ordinary [desktop dependencies](local-build-and-validation.md) remain
required. Godot is pinned to **4.7.stable.official.5b4e0cb0f** and godot-cpp to
`101ae38034304346a46ea9ea84ae156d3e860496`. Rebuild the matching GDExtension:
an older retained production binary predates the new read-only inspector methods.
An older library causes an explicit rebuild message, not a metadata fallback.
Use a freshly qualified branch runtime only when its provenance matches the
checkout's native inputs; the completion publisher provides that explicit path.

```sh
# Use the existing pinned build environment; see the local-build guide for setup.
tools/build_pinned_godot_cpp.sh linux
tools/build_native_extension.sh
godot --path godot -- --materials-lab
```

Read-only inspection and native experiments require the matching engine library.
Candidate authoring additionally requires Python 3, Git history and a C++20
compiler for **Build + check definition**. The Edit copy tab accepts Python and
compiler executable paths without shell arguments. A compiler override is also
available through `CYBERSAND_LAB_CXX`. Source tools must remain next to the
Godot project; this is a desktop source workflow, not an exported/Web authoring
service. No install operation writes production sources.

The standalone Lab uses window pixels for readable controls instead of shrinking
the game's 1920×1080 canvas. Tabs scroll when their contents exceed the available
space, including the 1000×650 Workbench window minimum. Inspection columns keep
their useful widths and can scroll horizontally. Closing the standalone Lab
restores the launcher's original scaling. These presentation changes do not alter
the simulation viewport or the shared Workbench's controls.

### Windows launch

The branch-scoped **Materials Lab source-matched native runtime publication**
workflow builds a Windows evaluation ZIP after actual Windows execution. Its
**Open-Materials-Lab.cmd** launcher uses the included Godot, Python, Git history
and C++ compiler. Extract the entire ZIP to a writable directory and keep its
`source` and `dependencies` directories together. First launch imports the
project, then opens the Lab with the qualified ANGLE renderer. It does not need
a separately configured compiler environment. The bundle's manifest binds all
files and the native DLL; `qualification` retains the original automated
receipts and graphical captures. A package is delivered only after its copied
environment also executes the native authoring tests. See the completion record
for the actual run/artifact identity; workflow presence alone is not a passed run.

For an ordinary source checkout instead of the evaluation package:

Use the existing **GDExtension build and current Godot regression** workflow's
source-built Windows candidate for the exact branch commit, or the pinned
cross-build paths `tools/build_pinned_godot_cpp.sh windows` and
`tools/build_native_extension_windows.sh`. Its downloaded candidate manifest
must identify the same native input files as the checkout. Do not relabel the
retained production DLL as a new candidate. The standalone
`build_windows_msvc.bat` does not build this Godot extension.

For source candidate compilation, start Godot from a configured x64 C++20
compiler environment; for MSVC use an **x64 Native Tools Command Prompt** with
Python available. Select `cl` or its full executable path in the Edit copy tab.
An executable path alone cannot supply MSVC's missing SDK include/library
environment. The Python default on Windows is `python`.

From **PowerShell inside the cloned repository**, resolve the checkout before
launching. PowerShell requires `&` before a quoted executable path:

```powershell
$labCheckout = git rev-parse --show-toplevel
& "C:\Tools\Godot\Godot_v4.7-stable_win64.exe" --path "$labCheckout\godot" -- --materials-lab
```

The exact Windows execution status belongs to the dated qualification record.
Linux screenshots and a successful cross-build are not Windows graphical or
human acceptance.

## Browse and inspect actual behaviour

Search by exact stable ID, name, physical state, kernel, semantic family or
reaction partner. Filters include physical states and explicit hard/granular
capabilities. These categories organize the browser; neither appearance labels
nor semantic family membership confer inherited physics.

Every important property row separates **declared value → effective value →
actual consumer → applicability → editability**. The native cold-path bridge
reads original descriptor values, capability predicates, density-exchange
eligibility, visual-state projection and compiled solver defaults. The model
also consumes the existing native interaction profile. Missing native support
fails explicitly. It never substitutes shadow catalogue values for native facts.

Examples to check:

- **Water:** the specialised Water family determines motion. Descriptor viscosity
  is not a Lab edit. CellularYield Water's versioned policy viscosity is a
  separate consumer; it is not the descriptor viscosity byte.
- **Sand:** powder movement, density and explicit hard/granular capabilities are
  separate facts. A powder name never implies hard terrain.
- **Slush:** native density is 1080; the separately identified GDScript fallback
  has density 1100. Neither value is silently substituted for the other.
- **MoltenGlass:** yielding movement and specialised thermal behaviour are shown
  separately, including the actual consumers and the admitted descriptor fields.
- **Lava, Acid and Oil:** an ignored descriptor viscosity is labelled ineffective
  for the specialised kernel, and the candidate control is disabled.

When opened from Shared Workbench, the inspector receives a **copied applied
policy receipt at opening**. Reopen to refresh it. A standalone Lab labels
compiled defaults as unobserved by a live World. **Show applied Water settings**
switches the inspector to the isolated experiment's acknowledged native policy.
The UI never reads a simulation-worker-owned World from the main thread.

Sources: [native inspection](../../godot/native_extension/material_lab_inspection.inc),
[catalogue model](../../godot/scripts/material_lab_catalogue.gd),
[panel](../../godot/scripts/material_lab_panel.gd) and the minimal
[Workbench mount](../../godot/scripts/shared_workbench.gd).

## Supported candidate edits and state transitions

Select a valid, nonempty material and **Duplicate selected**, or choose **New
powder 132**. The original template selects the existing kernel and state
contract. The candidate label is not a production rename. Existing IDs, enum
encodings and rule slots remain fixed.

| Property | Lab v1 boundary |
|---|---|
| Density; base RGBA | Editable candidate fields; consumed by the descriptor probe and isolated compiled World |
| Explicit hard/granular capability; visual-state projection | Editable and exercised by the descriptor probe; edits are rejected by the World backend because it retains the native capability/projection consumers |
| Descriptor viscosity | Editable only for generic YieldingLiquid, Cement and MoltenGlass templates; ineffective specialised-kernel edits are rejected |
| Physical state, kernel, movement flags, density-motion mode, exchange permission, lateral-flow descriptor, initial state bytes and write radius | Held to the selected template; choose another template for a different admitted mechanism |
| Existing sparse reaction slots owned by the template | Structured partners, products, match mode and inclusive probability threshold are editable; identity, slot and supported endpoint-effect semantics stay fixed |
| Explicit endpoint effects v2 | Non-Water `keep_existing`, or declared Metal/Combustible `state_b` updates, execute only in isolated compiled Worlds; see the reaction contract below |
| New arbitrary production IDs, new kernels, unknown fields, Water retention/quantity effects, arbitrary state writes, new pair-rule slots | Unsupported and rejected with a field path and explanation |
| Water movement model in **Try originals** | Built-in default, FreeMass, CellularYield and PressureFlow use the existing native admission and readback in the isolated test World |
| Empty 0 and reserved invalid 10 | Inspectable, not candidate templates |

**Draft** means editable, unqualified data. **Validated candidate** means the
strict schema and immutable compatibility check passed. **Compiled/tested**
means that exact candidate compiled and ran in the stated native probe.
**Runtime-active** requires an authoritative production installation and engine
acknowledgement; Lab v1 never assigns this state to a candidate. An edit revokes
previous validation. A background response for an older revision cannot qualify
newer edits. Candidate World results also bind the exact test recipe; changing
seed, placement, partner, tick count or workers retires the displayed comparison.
Actions commit pending numeric text before capturing a request, so typing a
value and immediately pressing Validate, Compile or Save uses the visible edit.

Validation refuses invalid IDs/types, duplicate JSON keys, duplicate slots,
unknown or conflicting definitions, invalid/inactive reaction sources, malformed
presets, unsupported state/effects and source drift. It uses the frozen
compatibility lock without refreshing it. No failure publishes a partial bundle.

## Save, import, compile and compare

**Save material preset…** writes a version-1 JSON envelope containing the exact
candidate, source catalogue digest and deterministic candidate SHA-256.
**Import preset…** verifies the envelope, digest, schema, current compatibility
and source identity before replacing the displayed candidate. Tampered or
malformed imports preserve the current candidate. The file is reusable with
the same admitted source; it is not a saved World.

**Build + check definition** generates the complete expanded candidate catalogue,
C++ definitions and Godot metadata in a temporary external build, compiles the
native probe, executes it and displays a receipt. **Export compiled bundle…**
performs the same operation and saves to a fresh child directory outside the
repository. The bundle contains the preset, generated files and source-bound
receipt for review. Import the bundle's `preset.json` to reopen its candidate;
the temporary executable is deliberately not exported. It records the
compiler/version and hashes of native source
inputs, generated files and the probe executable; native source identity is
checked before and after compilation.

The probe consumes the generated descriptor/capability/appearance values and
uses the actual native sparse pair resolver over all 256 byte rolls and every
unique directed pair in the union of production and candidate rules. Removed
pairs remain in the comparison; self-pairs and opposite ordered rules are not
double-counted. It records changed outcomes, deterministic example rolls and positional products. It
reports the generated product descriptors' initial state bytes. **It does not
execute World's endpoint/Water-quantity initialization, install a candidate in
World, simulate candidate movement or establish quantity conservation over time.**
The separate **Compare edits** backend below supplies that bounded World execution.

Authoring runs in a polled child process with **Cancel authoring**, bounded
output and a five-minute desktop wall limit. **Cancel comparison** uses the same
cancellation marker. The compiler/probe process tree is terminated on timeout or
cancellation; cancelled/failed jobs cannot qualify a candidate. Closing gives
cleanup at most two seconds before terminating an unresponsive process. These
process controls use a private Windows Job Object established before the child
executes, or a POSIX process group. Descendants are retired even if their driver
already exited or redirected its streams. Four actual descendant-lifetime
fixtures run on both platforms; their platform-qualified results belong to the
completion record. CLI request/response paths cannot overwrite a
preset or a compiled bundle through response-path aliasing.

### Reusable powder example

Import [lab-synthetic-powder-v1.json](../../materials/catalogue/fixtures/lab-synthetic-powder-v1.json),
or create the powder, label it **Azure non-hard powder — isolated132**, and set
density **1337**, RGBA **17, 91, 203, 255**, hard surface **false**, granular
support **true**. Compile it. The native readback
must report candidate 132, these exact values, a powder template and no
production activation. Export and reimport: the digest remains
`c2e7859cf568cd9d138c6444a9f26242cc1538be9b283977e6a24dc59ba5c24c`.
This fixture does not reserve ID 132 against any other experimental branch.

## Compare an edited candidate in a real native World

The **Compare edits** tab compiles the actual native `World` twice in temporary
directories: once from untouched source, once with staged descriptor and
sparse-rule tables adapted to compiler-generated definitions. Extended endpoint
effects additionally use a bounded external pair-application adapter. The same
bounded bay, seed, placement and tick count run in both. Repository source,
production binaries and the shared running World are not rewritten.

Duplicate **Sand 2**, set density **500** and a distinct base RGBA, then select
**Compare edits**, **Upper dose**, partner **Water 3**, seed **2**, **120** ticks
and **4** workers. Press **Build + run comparison**. The candidate penetrates
less deeply than the untouched reference while preserving Water quantity.
Both images derive from actual stored material/state and compiled RGBA. The
initial/final selector and stored-coordinate inspector expose material, state A,
state B and temperature; the counts and ledger provide evidence beyond images.
No palette-shader parity is claimed by this readback preview.
The reusable [low-density Sand preset](../../materials/catalogue/fixtures/lab-low-density-sand-world-v1.json)
contains the exact density/RGBA candidate exercised by native acceptance.

Supported World edits are existing-ID density, base RGBA, consumed descriptor
viscosity and admitted sparse-pair/effects edits. Synthetic132, capability changes
and visual-state projection changes are refused with actionable paths; their
descriptor compilation remains available. Kernels, identity and state contracts
stay held to the chosen template. The test uses native default solver settings;
it does not inherit the Workbench's applied solver configuration.

Each build checks fresh deterministic repetition, one/four-worker equality,
same-build persistence continuation and the full native quantity ledger. Receipts
retain actual worker participation, full native source/staged/generated hashes,
compiler identity, exact scenario, stored grids, initial/final state and products.
Persistence compares canonical physical state, cells, registers, temperature and
quantities; the historical state hash is retained separately because restoration
normalizes inactive quiet counters. Fresh repeats and worker comparisons retain
the exact historical-hash check as well. A one-tick regression covers this distinction.

The native probe reuses the Lab's bay geometry and `demo::construct`; it is not
an exact replay of the mounted `MicroScenarioHost`. Its receipt records raw
native default transport, capacities and interest rectangle. Candidate and
reference share these settings; their hashes are not asserted equal to the
separate mounted host. Per-cell scheduling eligibility and sleep deadlines remain
unavailable; aggregate activity and completed native ticks are reported.

**Export comparison files…** rebuilds/tests into a fresh external child directory
and saves the versioned preset, full source-staged reference/candidate fixtures,
generated definitions and `world-receipt.json`. Executables and saved Worlds are
excluded. Import `preset.json` to edit it again. The receipt's `scenario` can be
passed unchanged to `compile_world_test` through the existing JSON request CLI
for reproduction. These test results qualify the stated fixture only; they do
not establish cross-build saved-world compatibility or production activation.

**Save World recipe…** stores the candidate, placement/partner, seed, ticks,
workers and executable-source hashes in a versioned, digested JSON case.
**Import World recipe…** restores the candidate and all visible controls together.
Import validates the case but never restores a previous successful test claim:
press **Build + run comparison** for a fresh result. Changed inputs, invalid
IDs, malformed/duplicate fields and digest mismatches are refused. A
documentation-only Git commit does not invalidate a recipe when all captured
executable inputs are unchanged. A source mismatch requires explicit candidate
reconciliation; it is not silently treated as the same experiment.

Sources: [World compiler backend](../../tools/material_catalogue/world_candidate.py),
[native probe](../../tools/material_catalogue/lab_world_probe.cpp),
[comparison view](../../godot/scripts/material_lab_world_panel.gd).

## Reaction authoring and deterministic diagnostics

Duplicate Salt or Water to expose its existing sparse reaction slots. The
Reactions tab edits both partners, both products, ordered/unordered/symmetric
matching and threshold. Slot order remains priority order. Endpoint effects
are explicit version 1 **replace_with_defaults** at both endpoints, retaining
legacy product initialization. The endpoint selectors also admit a bounded
**effects version 2** in the isolated compiled World:

| Effect | Executed semantics and admission |
|---|---|
| `replace_with_defaults` | Existing product initialization, including same-identity products |
| `keep_existing` | Preserve a non-Water participant's material, state A, state B and temperature; its product must equal its input identity |
| `set_state` with `state_b` | Preserve material, state A and temperature; set B to an integer 0–255 only for the native Metal charge or Combustible burn countdown |

Use Ordered or Unordered role-preserving matching for extended effects. Positional
Symmetric effects, Water retention/state writes, undeclared registers and two
keep-only endpoints are rejected. The editor aligns a retained endpoint's product
with its participant. **Run edited reaction** selects the rule's pair and
executes the native comparison; the descriptor/resolver-only test explicitly
refuses extended effects. The production table and World implementation remain
unchanged. State/epoch/wake details and executed acceptance belong to the dated
audit and the [isolated adapter](../../tools/material_catalogue/reaction_effects.py).

Arbitrary conservation claims are not inferred
from product names; inspect the reported defaults and native experiment quantities.

Historical probability is inclusive: threshold **T means (T + 1) / 256**.
Threshold 0 is a 1/256 chance. The native diagnostic distinguishes no matching
rule, failed supplied roll and selected reaction. It reports endpoint products,
priority and state/quantity implications where the native API provides them.
This resolver-only diagnostic cannot establish whether World scheduled a
particular contact. The separate native contact inspector below adds observed
cell masks and core-window facts; actual dispatch, per-cell sleep and competing
kernel mechanisms remain unobserved.
Changing a resolver endpoint or supplied roll retires its previous diagnostic.
A reply for an older diagnostic selection cannot replace the current report;
its original native compilation receipt remains inspectable.

For a concrete candidate comparison, duplicate Salt and set its Water reaction
threshold to 0. Roll 0 succeeds; roll 1 fails in the compiled candidate. The
unchanged production Water/Salt rule still succeeds on roll 1. Alternatively
import [lab-zero-threshold-quench-v1.json](../../materials/catalogue/fixtures/lab-zero-threshold-quench-v1.json):
the Lava/Water quench has one successful roll per orientation rather than 256,
and the probe records 510 changed outcomes over both orientations. This isolates
the edit from contact scheduling and preserves the production rule.

For an actual authored contact, duplicate **Salt 23** and change both products
of its Water pair to **Stone**. Run the Compare edits against Water. Native
readback records Stone products, pair events and Water ledger changes instead
of the reference's Brine products. The rule still uses the existing default
initialization effect and priority. Changed candidate rules receive generated
product/accounting descriptions, so legacy prose cannot describe different products.
The [Salt-to-Stone World preset](../../materials/catalogue/fixtures/lab-salt-stone-world-v1.json)
contains this exact candidate for import and repetition.

For retained state, import the
[retained-Salt preset](../../materials/catalogue/fixtures/lab-salt-retain-world-v2.json),
or duplicate Salt, keep Water's replacement with Brine and select **Keep existing**
for the Salt endpoint. Salt acts as a retained participant instead of being
replaced with a fresh product. For state-setting, import the
[Metal charge preset](../../materials/catalogue/fixtures/lab-metal-charge-world-v2.json),
or duplicate Metal and select **Set state B** on its Metal endpoint, for example
73, while retaining an admitted replacement on the other endpoint. Native
endpoint fixtures seed non-default state and temperature, inspect the actual
registers, quantity ledger and persistence, and exercise the countdown consumer.

## Native simulation experiments and reproducible cases

In **Try originals**, select a built-in material and a partner. Set the step
count, seed, simulation threads and **Water movement model**, then click
**Prepare experiment**. Select **PressureFlow** to test the native PressureFlow
reference solver. **Show applied Water settings** opens Inspect with the
settings acknowledged by the prepared World. The saved case includes the Water
model and restores it when opened with matching source and runtime.
[PressureFlow reference solver](../architecture/pressure-flow-v1.md)

**Step** advances one native tick. **Run set number of steps** advances at most
one tick per UI frame and stops at the requested endpoint. The UI and helper
admit 1 through 600 ticks. **Compare edits** uses the built-in solver settings in
both of its compiled Worlds.

The experiment reuses `MicroScenarioHost`, its contract and the reference pack.
It owns a separate native World. Native material counts, stored cells/state,
Water quantity, content/state hashes, applied policy and aggregate statistics
are the evidence. The image is an illustrative view of that same World. Seed
selects fixture construction, not a new global/native RNG policy.

### Inspect an actual native contact

Left-click the native preview to select a source cell and right-click to select
a target. **Swap the two cells** tests the opposite source orientation. Set a byte
roll and press **Inspect contact**; this pauses the exclusive test owner and
copies both native cells from the same completed tick. Inspection never executes
a reaction. Stored material, visible material, state A/B, raw stored temperature,
body-mask identity, compiled kernel and pair capability remain separate facts.

The report combines the real sparse resolver with observed neighbour distance,
mask and selected source-core window facts. It also shows the preceding completed
tick's applied window; that value is unobserved before the first tick. A target
outside the selected core range is not automatically excluded, because contacts
can reach the source core's write halo. A selected supplied roll cannot prove
next-tick execution: per-cell sleeping, future wake deadlines, cell epochs,
actual task dispatch, random bytes and competing neighbours remain explicitly
unobserved. Editing coordinates/roll or advancing the owner retires the report.

For a deterministic probability example, inspect adjacent native **Steam/Ice**
cells with rolls **32** and **33**. The compiled threshold32 rule selects the
reaction on32 and rejects33. The separate eligibility section explains any
observed blocker without presenting the supplied roll as World's random stream.

For a repeatable example, select **Salt 23 + Water 3**, seed 2, 120 ticks and
four workers. Native readback observes the 384-cell Salt dose reacting with
Water to produce **768 Brine cells**, with Water remaining in the bay.
**Repeat and check result** reconstructs a
clean owner with the same definition and checks exact final readback. Replay
advances one tick per UI frame; **Pause** cancels it while preserving the source run.
**Save experiment…** records the definition, source identity, seed, worker count
and applied Water-family selection in a digested envelope; **Open experiment…**
restores that configuration and its visible seed/duration/worker/policy controls
transactionally. Prepared-run identity is shown separately from controls for a
new pair. Native source or digest mismatches
are refused. This is reproducible fixture reconstruction, not arbitrary World
continuation or a save-format migration.

Source: [experiment helper](../../godot/scripts/material_lab_experiment.gd).
The previous [1024² manual laboratory](../MATERIAL_LAB.md) and the existing
[MicroScenario reference pack](microscenario-reference-pack.md) retain their
separate controls and evidence.

## Manual evaluation checklist

- Open from the launcher and Shared Workbench; inspect Water, Sand, Slush,
  MoltenGlass and reserved 10. Confirm native/fallback/shadow distinctions and
  the origin of the copied solver policy.
- Search for `23`, `powder`, `MoltenGlass` and a reaction partner; check physical
  and capability filters without implying semantic inheritance.
- Create powder 132, change density/colour, validate and compile. Confirm no
  Runtime-active label and no production 132 in the browser.
- Export/reimport the preset, then export a compiled bundle and import its
  `preset.json`. Tamper with a field/digest;
  require an actionable refusal and preservation of the current candidate.
- Duplicate Salt, set threshold 0 and compare rolls 0/1 in the candidate and
  production resolver. Confirm explicit product-default effects.
- Run Salt/Water for 120 ticks, read stored material/state, compare a clean
  reference, save/reopen the test and check one/four-worker agreement.
- In **Try originals**, prepare a Water experiment with CellularYield and then
  PressureFlow. Inspect the applied settings, step the PressureFlow World,
  save it and reopen it to verify the selected model and native policy hash.
- Duplicate Sand, set density500, compare both native Worlds against Water,
  inspect initial/final cells and export/reopen the World bundle. Edit settings
  while a compile runs and verify its older result cannot qualify the new recipe.
- Cancel a compile and a reference replay; confirm the Lab stays usable and
  reports cancellation without a successful receipt.
- Save/import a World recipe after changing placement, seed and workers; require
  exact restored controls, a validated state and a fresh compile before qualification.
- Exercise Salt retention and a Metal state-B edit through **Run edited reaction**;
  check native registers/temperature and quantity evidence, not only the preview.
- Select neighbouring native preview cells with left/right clicks, inspect a
  supplied roll, swap source/target and advance one step; the old contact report
  must retire and unobserved scheduling facts must remain labelled.

## Qualification and remaining gates

Focused executable regressions are `test_material_lab_catalogue.gd`,
`test_material_lab_experiment.gd`, `test_material_lab_ui.gd`,
`test_material_lab_service.gd`, `test_material_lab_world.gd`,
`test_material_lab_diagnostics.gd`,
`tools/material_catalogue/test_lab.py`, `test_world_candidate.py`,
`test_world_case.py`, `test_reaction_effects.py` and `test_process_owner.py`. The UI regression mounts the actual
scene and executes Python, C++ and the native World. The graphical capture
script is `godot/tests/capture_material_lab.gd`; the full mounted UI test also
accepts `-- --capture-output=<absolute-directory>` to retain its executed
effects-v2 World view, native receipt and source/library/display manifest.
Commands and outcomes are retained in the
[audit](../audits/2026-11-11-materials-lab-v1.md).

The bounded #353-B hard/granular capability consumer is isolated in
[Draft #563](https://github.com/techrote/cybersand/pull/563), stacked on the Lab
Draft. Its generated maps, independent source-matched equivalence campaign and
authenticated compatibility transition do not install authored candidates or
alter the Lab branch's production consumers. Wider endpoint and quantity semantics require additional native
contracts. The owner explicitly excluded MoltenGlass H1 from this continuation;
it is not a Materials Lab delivery dependency. Historical liveness evidence is
preserved. No production thermal law, native identity or saved-World semantics
change in this Lab implementation.
