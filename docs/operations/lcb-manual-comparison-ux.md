---
title: LCB manual liquid comparison UX flow
status: Current
document-kind: guide
scope: Accepted bounded liquid-comparison controls and constructor boundaries; retained October design and source-specific qualification are historical references, not current instructions
canonical-for: [lcb-manual-comparison-ux]
last-reviewed: 2026-11-25
related-documents: [../architecture/liquid-solver-family-policy.md, ../architecture/liquid-prepared-setup-and-receipts.md, lcb-water-comparison-and-fixtures.md, lcb-scenario-catalogue.md, workbench-water-lab.md, microscenarios.md]
---

# LCB manual liquid comparison

Use **Liquid comparison — solver policies and protected Dam Break** in the
Feature Launcher to compare the accepted native families on bounded fixtures.
It opens the ordinary Main host with **Liquids…** in the MicroScenario panel.
For painting and playing with Water in an authored scene, start with the
[Workbench Water Lab](workbench-water-lab.md), which has its own gameplay profile
and accepted installation controls.

The comparison apparatus has **eight policy presets and two protected setups**.
It is not the complete 27-scenario registry browser or the whole
[#202 manual-comparison programme](https://github.com/techrote/cybersand/issues/202).
App [#256](https://github.com/techrote/cybersand/pull/256) and Trial
[#257](https://github.com/techrote/cybersand/pull/257) are accepted; their availability
does not close #202 or [#203 scientific/package qualification](https://github.com/techrote/cybersand/issues/203).

## Run a first controlled comparison

1. Launch the [pinned native desktop build](getting-started.md) and choose the
   Liquid comparison entry. The protected Dam Break starts paused.
2. Select **Protected Dam Break** or **Water / Oil / Brine lock exchange**.
   Leave **Controlled • fixed actor-free** selected for a controlled fixture.
3. Choose a policy preset. A choice changes the pending request, not the running
   World. Read any native refusal before continuing.
4. For an inertial family, explicitly select **Matched IN geometry (radius 3)**.
   Select that same geometry for its comparison arm. IN with radius 2 refuses;
   selection never silently increases the radius.
5. For a fractional initial Water setup under a whole-cell family, explicitly
   enable **Normalize Water to whole cells on rebuild**. The resulting receipt
   reports gross added, gross removed and net Water quantities. This is a
   declared setup conversion, not physical conservation or a live conversion.
6. Click **Load selected comparison**. Wait for applied native policy and owner
   acknowledgement. Pending selection or a queued request is not a completed
   installation. Use the normal pause, step and reset controls after acceptance.
7. Record source/runtime identity, applied policy, setup, geometry, normalization
   and actual observations. Compare runs with the same initial geometry,
   precision, schedule and worker configuration. The
   [controlled fixture contract](lcb-water-comparison-and-fixtures.md) owns the
   exact definitions and measurement rules.

**Original Current control** reconstructs the protected fixture through its
original default constructor, ignoring pending family and normalization choices
and restoring radius 2. Here “Current” is the registered FreeMass comparison
control; it is not a claim that every current gameplay host defaults to that
profile. Workbench Wave is a separately selected overlay on the FreeMass carrier,
not a fifth member of the four-family enum.

## Policies and controls

| Preset | Pending assignment |
|---|---|
| Current defaults | Native default assignments |
| Water: whole-cell | Water `cellular_yield_v1/reference` |
| Water: pressure reference | Water `pressure_flow_v1/reference` |
| Water: pressure cached | Water `pressure_flow_v1/cached` |
| Water: pressure dormant | Water `pressure_flow_v1/cached_dormant` |
| Water: inertial | Water `inertial_cellular_v1/reference` |
| Mixed: pressure Water + inertial Brine | Water PF reference and Brine IN |
| Mixed: Current Water + inertial Brine | Native-default Water and Brine IN |

The panel also lists all eleven liquid materials, including species absent from
the setup. Native capability queries determine valid family/variant choices and
refusal reasons. One World assigns one family to each material; it cannot apply
several families simultaneously to Water. Pressure variants share one family.
Independent Water precision, coherence and transport settings keep their own
contracts rather than being silently reset by a family preset.

**IN damping numerator / 16** accepts 0–16, initially 1. It edits the pending
native parameter block and takes effect on rebuild. Applied readback reports the
actual value and geometry. The source-controlled panel, rather than a retained
screenshot or old mockup, defines the current labels and availability.

Source: [`CyberLiquidComparisonPanel`](../../godot/scripts/liquid_comparison_panel.gd),
[`Main`](../../godot/scripts/main.gd) and the
[family policy](../architecture/liquid-solver-family-policy.md).

## Rebuild an existing supported scene

Use **Exploratory • staged owner**, choose the policy, geometry and normalization,
then **Apply & rebuild active**. This preserves the active admitted constructor's
semantics; it does not reinterpret any arbitrary scene as the protected Dam Break.
The existing host validates and stages the candidate before its ownership handoff.
A refusal preserves the previous World, owner graph and accepted receipt.

Actor, body, terrain and future-source restrictions depend on the constructor.
The [prepared-owner contract](../architecture/liquid-prepared-setup-and-receipts.md)
is the canonical technical coverage map. In particular:

- Controlled mode refuses player/body routes. Exploratory mode admits the
  implemented sampled, articulated and bounded trial-body routes where their
  original setup, masks, terrain and ownership can be prepared.
- The native-default PF geometry can refuse initial gas capacity. Choose a
  supported finite fixture; do not interpret a refusal as a successful fallback.
- Initial whole-cell normalization does not legalize later fractional sources.
  CY/IN recipes with unsupported future fractional Water actions refuse.
- Existing projectile velocity does not initialize IN material momentum. The
  separate [IN-TOOLS programme](in-tools-fixtures-and-playtest.md) owns proposed
  stricter source/drain tools; its six planned fixtures are not implemented by
  this selector.
- Trial-body Apply may retain its admitted captured pose/motion, while reset/F5
  reconstructs authored fresh state. This is not a general saved physical
  continuation guarantee.
- Blind/read-only apparatus disable these rebuild controls. The legacy Tower
  export is [engineering metadata](water-feel-lab-experiment.md), not a newly
  qualified formal blinded study.

Where the synchronous ordinary level-import host exposes **Use selection for next
level import**, it arms a copied Exploratory selection without changing the
current World. **Use Current defaults for next import** clears that choice.
The supported body-free CYSD import stages copied payload and a sampled owner;
unsupported physical/Tower/showcase or inherited-policy combinations refuse.
Do not apply this conversion path to CYPS physical continuation.

## Read the result and recover from refusal

The UI keeps requested policy, applied policy, pending serial, native refusal and
owner acknowledgement separate. Inspect the applied receipt after every rebuild.
A label alone, old snapshot or matching requested value does not prove the new
owner was installed. Reset retains the accepted selection only through the
corresponding supported host route.

If application refuses, read the stated policy, geometry, capacity or constructor
reason, correct the pending choice and retry. The existing accepted session stays
available. If the native World has faulted and is quarantined, a generic retry is
not recovery: follow the host's explicit fresh/default scene or validated
replacement route. Preserve the error and source/runtime identity when reporting it.

The panel's partial observation fields do not establish complete mapped-module,
script, actor and host provenance. `worker_threads_observed` counts distinct task
claimants in a phase; configured workers, simultaneous overlap, frame rate and
physical progression are different observations. Rendering and manual feel need
their own evidence; timing comparisons require isolated registered runs.

## Constructor coverage at this checkpoint

Accepted constructors and source-specific limitations live in the
[prepared setup and receipts reference](../architecture/liquid-prepared-setup-and-receipts.md).
Later [Shared Workbench authoring](../architecture/shared-workbench-authoring-data.md),
generated installation and large-landscape admission have their own contracts.
A missing row in an old October comparison table cannot make those accepted
features unavailable, nor does a new constructor qualify the entire #202/#203
scientific campaign.

The complete prior comparison table, publication chronology, source identities,
failed attempts, planned mockup and proposed future UI remain at the
[immutable predecessor](https://github.com/techrote/cybersand/blob/20170bd6259498c3d2774ab274567febb043fc1d/docs/operations/lcb-manual-comparison-ux.md#constructor-coverage-at-this-checkpoint).
Those records are historical evidence, not instructions to restart an old branch
or repeat a publication. They retain all original qualification limits.

## Remaining programme and platform boundary

The [scenario catalogue](lcb-scenario-catalogue.md) still distinguishes accepted
native capabilities from its 117 retained campaign-arm classifications. The
complete registry picker, broader host/provenance collection, registered full
campaigns and owner feel decisions remain with #202/#203. No preferred solver or
production default is selected by this guide.

The synchronous controller exists, and dated browser runs qualify only their
recorded functional arms. Further browser/shader work was deferred for this LCB
epic; the owner's [Web experiment policy](web-threading.md)
also does not require maintained Web CI or long-term Web releases. A future Web
experiment must record its own exact source, actual controls/rendering and limits.
Headless native tests, hosted software rendering and physical Windows/NVIDIA owner
acceptance remain separate evidence classes.
