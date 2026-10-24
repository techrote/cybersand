---
title: LCB manual liquid comparison UX flow
status: Planned
document-kind: design
scope: LCB-003 (#202) preparation — proposed manual feel-testing flow inside the normal CyberSand application: entry points, comparison panel, per-material family picker driven by the capability matrix, validate-reconstruct-commit apply, controlled versus exploratory sessions, presets, overlays and refusal states; no UI is implemented
canonical-for: [lcb-manual-comparison-ux]
last-reviewed: 2026-10-23
related-documents: [../architecture/liquid-solver-family-policy.md, lcb-water-comparison-and-fixtures.md, experiment-tower.md, microscenarios.md, ../systems/player-control-playground.md]
---

# LCB manual liquid comparison UX flow

## Status and scope

**Planned design for LCB-003 ([#202](https://github.com/techrote/cybersand/issues/202)).
No widget, route or setting described here exists yet.**

- **Ground rule:** every control is backed by the native policy and receipt
  from the [solver-family policy](../architecture/liquid-solver-family-policy.md).
  A choice the build cannot execute is shown as unavailable, with its
  refusal reason. It is never hidden, mocked or silently remapped.
- **What it extends:** the *existing* full application, not a separate
  sandbox. That means the feature launcher
  ([feature_launcher.gd](../../godot/scripts/feature_launcher.gd)), the
  Materials sandbox / Experiment Tower (F9), the MicroScenario host/panel and
  Water Feel panel, the player playground, actors and depth scenes.
- **Out of scope:** the four-family runtime itself (#200/#212), packaging
  (#203), and timing (#203 runs it sequentially and isolated).

## Entry points

| Entry | Route | Default state |
|---|---|---|
| Launcher button **"Liquid comparison — four solver families"** | new `liquid_comparison` destination → `main.tscn` with the comparison panel open on the protected Dam Break | paused, Controlled |
| Experiment Tower / Materials sandbox | new **Liquids** tab beside the Water Feel and MicroScenario tabs (F9 panel) | current scene's setup |
| Any MicroScenario / Water Feel scenario | "Compare liquids…" action, which seeds the panel from the active definition | Controlled if the definition is `fixed`, else Exploratory |
| CLI / profile | `--liquid-policy=<file.json>` and `--liquid-arm=<alias>` (aliases `current`, `pressure`, `pressure_cached`, `pressure_dormant`) | refused with a printed reason if unavailable |

Existing destinations, F2 return-to-launcher, R/reset, pause/step, F5 actor
selection and the Web 11-demo menu are unchanged. The panel appears only where
a native World exists. GDScript fallback scenes show it read-only, with
"native solver families unavailable in fallback".

## Comparison panel

```text
┌ Liquid comparison ────────────────────────────── [Controlled ▾] ┐
│ Setup  lcb.dam.water.freemass.reference.v1  ★ protected  [Change]│
│ Arm    current (Water freemass_v1/reference)          [Aliases ▾]│
│ ── Per-material family ─────────────────────────────────────────│
│ Water        [freemass_v1 ▾] [reference ▾]   ● applied           │
│ Oil          [cellular_yield_v1 ▾]  (Oil kernel kept)            │
│ Brine        [cellular_yield_v1 ▾]                               │
│   …only liquids present in the setup, then "Show all liquids"   │
│ ── Independent tuning (unchanged by family) ────────────────────│
│ Water mass 8 bits · coherence 12 · transport Baseline · adhesion │
│ ── Receipt ─────────────────────────────────────────────────────│
│ policy 3f…a1  setup 494a…19bf  workers 4  tick 0  Windows        │
│ [Apply & rebuild]  [Reset]  [Step]  [▶]   [Save setup] [★]       │
└──────────────────────────────────────────────────────────────────┘
```

- **Family dropdowns come from the capability matrix**
  ([JSON](../reference/liquid-solver-capability-matrix.json)) plus the
  build's availability. Entries show one of three badges:
  - **current default**: executes;
  - **experimental**: available in this build, otherwise disabled with
    "not in this build (#200)" / "(#212)";
  - **rejected**: disabled with the matrix note.

  Variants appear only for families that offer them.
- **Arm aliases** fill the Water row only. Choosing `pressure_cached` shows
  "variant of pressure_flow_v1, same physics" so variants are never presented
  as families.
- **The receipt line is the authority.** It shows the applied `policy_hash`,
  the setup hash, workers and platform, read back from native through
  `get_liquid_solver_policy()`. A per-row ● marks *applied*; ○ marks
  *requested, not yet applied*.
- **Independent tuning** keeps its existing panels, such as Water Feel
  precision/coherence and transport profiles, linked rather than duplicated.
  Changing a family never resets tuning, and the reverse holds too.

## Apply flow (validate → reconstruct → commit)

```text
edit rows ──► [Apply & rebuild]
                 │
                 ├─ validate (native, no side effects)
                 │     ├─ refused ──► inline error per row + banner; live World untouched; receipt unchanged
                 │     └─ ok
                 ├─ reconstruct retained setup with the new policy (worker / Web owner)
                 │     ├─ capacity/construction refused ──► same as refused
                 │     └─ built
                 └─ commit at owner boundary ──► new receipt; tick 0; paused; camera/bookmark kept
```

- **No live hot switch.** While the session runs, the dropdowns edit a
  *pending* policy. The banner reads "Pending: applies on rebuild (current run
  keeps its policy)".
- **What the retained setup holds:** recipe/definition, seed, initial edits
  or imported level, scheduled events, actor/loadout,
  Water/transport/interaction policy, interest and plane clocks. Exploratory
  edits made during a session can be **captured as a new setup**, which gets a
  new hash. They are never folded silently into the protected one.
- **Refusal text** names the code and the owning issue. Example:
  "Brine → inertial_cellular_v1: family_unavailable (LCB-005 #212 not in this
  build). Session unchanged."
- **Depth/multi-plane scenes.** The receipt lists each plane:
  active/configured, policy hash, or "frozen — configured inactive". Visibility
  and camera never change policy.

## Controlled versus exploratory

| | Controlled | Exploratory |
|---|---|---|
| Source | frozen definition (`execution.policy = fixed`) | any setup, including Controlled after interaction |
| Inputs | scheduled events only | painting, erasing, tools, player, bodies, actor swaps, live tuning panels |
| Badge | green **CONTROLLED** with tick counter | amber **EXPLORATORY** with the first-interaction tick |
| Transition | first manual input flips to Exploratory, and the panel says so; **Reset** returns to Controlled | — |
| Records | eligible for matched comparison exports | exported only as exploratory notes or feel-review entries |
| Timing | not shown as performance evidence; #203 uses isolated runs | never |

## Preset library

Grouped and searchable, with a ★ favourite. Protected presets are read-only:
"Duplicate to edit" creates a new ID and version.

- **Protected references:** `lcb.dam.water.freemass.reference.v1`, then
  `lcb.mixed.water-oil-brine.v1` with arms M0, M1 and M2 (M1/M2 shown disabled
  until #212/#200 land).
- **Comparison stations (#202):**
  - deep release and surge, including the depth ladder;
  - vented communicating head, using the existing #49-style fixtures;
  - **sealed** bell/dome and air pockets (labelled "sealed — equal levels are
    not expected");
  - remote wake, same-Water impulse, Rapier body entry and Water/Sand.
- **Existing catalogues, unchanged:** all 35 Water Feel scenarios,
  MicroScenario reference pack, Experiment Tower floors, demo registry,
  Deepworks, semantic depth and the player playground (including `liquidswarm`).
- **User setups:** saved in an experimental, namespaced user-data folder
  (`user://lcb/`). A setup is JSON holding the MicroScenario definition, the
  policy and a receipt. Import validates before replacing anything.

## Inspection and presentation

- **Overlays** are optional and presentation-only, and are recorded in the
  receipt's presentation block:
  - per-cell family (colour key per family);
  - Water mass (existing coverage/oriented modes);
  - candidate overfill, pressure, velocity and air, shown only when the family
    exports them;
  - dormancy/cache state (#201).
  - Smoothing, including the PR #188 seam presentation, is labelled "visual
    only".
- **Camera.** Bookmarks are stored per setup. Follow-front is a camera helper
  only.
- **Side-by-side** shows the same setup under two applied policies as **two
  sequential recordings** or two Worlds explicitly labelled "visual aid —
  contended, not timing". It never stands in for the single-World mixed
  requirement.
- **Cell inspection.** The existing schema-2 `inspect_cell` probe gains a
  "family / family state" section once a family exports state.

## Feel review (owner, optional)

After any session the user can record a dated review against the #203
template. The fields are:

- scenario, receipt hash and Controlled/Exploratory;
- ratings for flow speed, deep surge, splash/waves, inertia, viscous rest,
  mixing/chemistry, body interaction, render clarity and frame pacing;
- free text.

Reviews are stored separately from technical results and never change
defaults.

## Platform behaviour

| Platform | Behaviour |
|---|---|
| Desktop (Windows/Linux) | full panel; families as qualified per build |
| Web compat/threaded | same panel inside the existing Web demo menu; families offered only where Web qualification exists, otherwise `platform_unsupported` |
| GDScript fallback | read-only panel; all non-default rows refused |

## Acceptance hooks for #202

- The UI state equals the native receipt after every apply, refusal, reset,
  scene navigation, actor/material swap, load and #199 exit.
- Refused applies leave the World, hash and tick unchanged; this is covered
  by regressions.
- Protected presets reset to an identical tick-0 state. `test_lcb_fixture_manifests.gd`
  already pins their definitions and initial proofs.
- The Exploratory flag is set by every input path listed above.
