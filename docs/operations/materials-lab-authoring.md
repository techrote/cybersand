---
title: Materials Lab v1 inspection, candidate authoring and native tests
status: Current
document-kind: runbook
scope: Implemented desktop review candidate; native read-only inspection, isolated source candidates and existing-material MicroScenarios; no production material migration or runtime candidate activation
canonical-for: [materials-lab-v1-ui, materials-lab-candidate-presets, materials-lab-native-experiments]
last-reviewed: 2026-11-11
related-documents: [../MATERIAL_LAB.md, material-catalogue-shadow.md, microscenario-reference-pack.md, ../architecture/material-authoring-catalogue-plan.md, ../systems/intermaterial-interactions.md, ../audits/2026-11-11-materials-lab-v1.md]
---

# Materials Lab v1

**Current implementation in [Draft PR #562](https://github.com/techrote/cybersand/pull/562);
production activation remains unimplemented.** The desktop **Materials Lab** opens from the feature launcher,
the ordinary Shared Workbench's **Materials Lab…** button, or `--materials-lab`.
It combines native material inspection, structured candidate editing, compiled
candidate tests and an isolated native MicroScenario. The
[dated qualification record](../audits/2026-11-11-materials-lab-v1.md) distinguishes
local Linux execution, graphical evidence and outstanding Windows/human checks.

The Lab uses the accepted [catalogue compiler](material-catalogue-shadow.md).
It does not replace native production definitions, the simulation worker, the
Workbench or World. Production still has 132 slots, including invalid reserved
ID 10. The synthetic powder at 132 exists only inside an external candidate build.

## Launch and prerequisites

Use a complete checkout of the implementation branch and its history. Git LFS
and the ordinary [desktop dependencies](local-build-and-validation.md) remain
required. Godot is pinned to **4.7.stable.official.5b4e0cb0f** and godot-cpp to
`101ae38034304346a46ea9ea84ae156d3e860496`. Rebuild the matching GDExtension:
the retained production binary predates the new read-only inspector method.
An older library causes an explicit rebuild message, not a metadata fallback.

```sh
# Use the existing pinned build environment; see the local-build guide for setup.
tools/build_pinned_godot_cpp.sh linux
tools/build_native_extension.sh
godot --path godot -- --materials-lab
```

Read-only inspection and native experiments require the matching engine library.
Candidate authoring additionally requires Python 3, Git history and a C++20
compiler for **Compile + native test**. The Candidate tab accepts Python and
compiler executable paths without shell arguments. A compiler override is also
available through `CYBERSAND_LAB_CXX`. Source tools must remain next to the
Godot project; this is a desktop source workflow, not an exported/Web authoring
service. No install operation writes production sources.

### Windows launch

Use the existing **GDExtension build and current Godot regression** workflow's
source-built Windows candidate for the exact branch commit, or the pinned
cross-build paths `tools/build_pinned_godot_cpp.sh windows` and
`tools/build_native_extension_windows.sh`. Its downloaded candidate manifest
must identify the same native input files as the checkout. Do not relabel the
retained production DLL as a new candidate. The standalone
`build_windows_msvc.bat` does not build this Godot extension.

For source candidate compilation, start Godot from a configured x64 C++20
compiler environment; for MSVC use an **x64 Native Tools Command Prompt** with
Python available. Select `cl` or its full executable path in the Candidate tab.
An executable path alone cannot supply MSVC's missing SDK include/library
environment. The Python default on Windows is `python`.

```bat
"C:\Tools\Godot\Godot_v4.7-stable_win64.exe" --path .\godot -- --materials-lab
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
  separately. The established isolated cooling/scheduling problem remains open;
  the Lab does not claim to repair it.
- **Lava, Acid and Oil:** an ignored descriptor viscosity is labelled ineffective
  for the specialised kernel, and the candidate control is disabled.

When opened from Shared Workbench, the inspector receives a **copied applied
policy receipt at opening**. Reopen to refresh it. A standalone Lab labels
compiled defaults as unobserved by a live World. **Inspect test-owner policy**
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
| Density; base RGBA; explicit hard/granular capability; visual-state projection | Editable isolated candidate fields; emitted by the canonical compiler and consumed by the native test |
| Descriptor viscosity | Editable only for generic YieldingLiquid, Cement and MoltenGlass templates; ineffective specialised-kernel edits are rejected |
| Physical state, kernel, movement flags, density-motion mode, exchange permission, lateral-flow descriptor, initial state bytes and write radius | Held to the selected template; choose another template for a different admitted mechanism |
| Existing sparse reaction slots owned by the template | Structured partners, products, match mode and inclusive probability threshold are editable; identity, slot and supported endpoint-effect semantics stay fixed |
| New arbitrary production IDs, new kernels, unknown fields, state-setting/keep-existing effects, new pair-rule slots | Unsupported and rejected with a field path and explanation |
| Existing Water default/FreeMass/CellularYield selection in **Native test** | Applied through existing native admission to the isolated test World, with owner readback; does not reconfigure the shared running Workbench |
| Empty 0 and reserved invalid 10 | Inspectable, not candidate templates |

**Draft** means editable, unqualified data. **Validated candidate** means the
strict schema and immutable compatibility check passed. **Compiled/tested**
means that exact candidate compiled and ran in the stated native probe.
**Runtime-active** requires an authoritative production installation and engine
acknowledgement; Lab v1 never assigns this state to a candidate. An edit revokes
previous validation. A background response for an older revision cannot qualify
newer edits.

Validation refuses invalid IDs/types, duplicate JSON keys, duplicate slots,
unknown or conflicting definitions, invalid/inactive reaction sources, malformed
presets, unsupported state/effects and source drift. It uses the frozen
compatibility lock without refreshing it. No failure publishes a partial bundle.

## Save, import, compile and compare

**Save / export preset…** writes a version-1 JSON envelope containing the exact
candidate, source catalogue digest and deterministic candidate SHA-256.
**Import preset…** verifies the envelope, digest, schema, current compatibility
and source identity before replacing the displayed candidate. Tampered or
malformed imports preserve the current candidate. The file is reusable with
the same admitted source; it is not a saved World.

**Compile + native test** generates the complete expanded candidate catalogue,
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
uses the actual native sparse pair resolver over all 256 byte rolls, both
endpoint orientations and all 56 rules. It compares unedited outcomes with the
production resolver and records changed outcomes and positional products. It
reports the generated product descriptors' initial state bytes. **It does not
execute World's endpoint/Water-quantity initialization, install a candidate in
World, simulate candidate movement or establish quantity conservation over time.**

### Reusable powder example

Import [lab-synthetic-powder-v1.json](../../materials/catalogue/fixtures/lab-synthetic-powder-v1.json),
or create the powder, label it **Azure non-hard powder — isolated132**, and set
density **1337**, RGBA **17, 91, 203, 255**, hard surface **false**, granular
support **true**. Compile it. The native readback
must report candidate 132, these exact values, a powder template and no
production activation. Export and reimport: the digest remains
`c2e7859cf568cd9d138c6444a9f26242cc1538be9b283977e6a24dc59ba5c24c`.
This fixture does not reserve ID 132 against any other experimental branch.

## Reaction authoring and deterministic diagnostics

Duplicate Salt or Water to expose its existing sparse reaction slots. The
Reactions tab edits both partners, both products, ordered/unordered/symmetric
matching and threshold. Slot order remains priority order. Endpoint effects
are explicit version 1 **replace_with_defaults** at both endpoints, retaining
legacy product initialization. `keep_existing` and state-setting effects are
rejected rather than approximated. Arbitrary conservation claims are not inferred
from product names; inspect the reported defaults and native experiment quantities.

Historical probability is inclusive: threshold **T means (T + 1) / 256**.
Threshold 0 is a 1/256 chance. The native diagnostic distinguishes no matching
rule, failed supplied roll and selected reaction. It reports endpoint products,
priority and state/quantity implications where the native API provides them.
It cannot establish whether World scheduled a particular contact, masked a
cell, slept, or chose a competing kernel mechanism.

For a concrete candidate comparison, duplicate Salt and set its Water reaction
threshold to 0. Roll 0 succeeds; roll 1 fails in the compiled candidate. The
unchanged production Water/Salt rule still succeeds on roll 1. Alternatively
import [lab-zero-threshold-quench-v1.json](../../materials/catalogue/fixtures/lab-zero-threshold-quench-v1.json):
the Lava/Water quench has one successful roll per orientation rather than 256,
and the probe records 510 changed outcomes over both orientations. This isolates
the edit from contact scheduling and preserves the production rule.

## Native simulation experiments and reproducible cases

Select existing materials and a partner, then choose **Prepare selected +
partner**. Set a bounded tick count, seed, one/four workers and the supported
Water policy. **Step** advances one actual native tick; **Run bounded window**
advances at most one tick per UI frame and stops at the requested endpoint.
The UI allows up to 512 ticks; the helper rejects definitions above 600.

The experiment reuses `MicroScenarioHost`, its contract and the reference pack.
It owns a separate native World. Native material counts, stored cells/state,
Water quantity, content/state hashes, applied policy and aggregate statistics
are the evidence. The image is an illustrative view of that same World. Seed
selects fixture construction, not a new global/native RNG policy. Per-cell sleep
deadlines and scheduler eligibility are not exposed by this owner and are
explicitly labelled unavailable.

For a repeatable example, select **Salt 23 + Water 3**, seed 2, 120 ticks and
four workers. Native readback observes the 384-cell Salt dose reacting with
Water to produce **768 Brine cells**, with Water remaining in the bay.
**Repeat / compare reference** reconstructs a
clean owner with the same definition and checks exact final readback.
**Save test case…** records the definition, source identity, seed, worker count
and applied Water-family selection in a digested envelope; **Import test case…**
restores that configuration transactionally. Native source or digest mismatches
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
- Apply CellularYield in the isolated test, inspect acknowledged policy and
  verify the ordinary Workbench remains its existing owner.

## Qualification and remaining gates

Focused executable regressions are `test_material_lab_catalogue.gd`,
`test_material_lab_experiment.gd`, `test_material_lab_ui.gd` and
`tools/material_catalogue/test_lab.py`. The UI regression mounts the actual
scene and executes Python, C++ and the native World. The graphical capture
script is `godot/tests/capture_material_lab.gd`; its receipt names source inputs,
engine, display and native results. Commands and outcomes are retained in the
[audit](../audits/2026-11-11-materials-lab-v1.md).

The next production step remains a separately qualified #353-B consumer/identity
transition. New endpoint semantics need explicit state/quantity rules and tests
before admission. #354's H1 repair is already owned by Draft #395; saved sleeping
state migration and its performance/source gates remain separate. No mutual
MoltenGlass heating, generic yielding rest, native material identities or saved
World semantics change in this Lab implementation.
