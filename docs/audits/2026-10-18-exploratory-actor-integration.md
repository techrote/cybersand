---
title: Exploratory map actor integration validation
status: Current
document-kind: audit
scope: 2026-10-18 desktop picker integration, source identity, local validation and explicit physical conversion limits
canonical-for: []
last-reviewed: 2026-10-18
related-documents: [../operations/physical-actor-programme.md, ../systems/actor-rigs.md, ../reference/validation-evidence.md]
---

# Exploratory actor integration - 2026-10-18

## Source and recoverability

Parent main is `0d915ff096e7478acee2adfd5d11d6b9883954c2`; the recoverable
implementation source checkpoint is `f7fc8f4` on
`codex/exploratory-actor-selection` in the retained
feature-integration worktree. The original `C:/khybersand` checkout and its
unrelated generated files were not changed. Local runtime input hashes below
identify the tested delta independently of later evidence-only commits. No
native source, binary, dependency pin, CI provider or historical hash was changed.

| Runtime/test file | SHA-256 |
|---|---|
| `godot/scripts/actor_prototype_panel.gd` | `e7bd374875207d13992433197bbf7ee48c6de568f4bf1c05e9dd598376b5159c` |
| `godot/scripts/feature_launcher.gd` | `dcfa22fcd8b0384089f192396086c9a594d178967f94d122dd7ab893e12c3dbc` |
| `godot/scripts/main.gd` | `93d06b6266edc8dbda2df7a074c5c63f8fd2dedb1d3673d687c18659db967855` |
| `godot/scripts/microscenario_catalogue.gd` | `d58a1010b7709828730f49a623c9a29016995352e861122a54ef739a90970b0b` |
| `godot/scripts/simulation_worker.gd` | `765c998716aeda615b5a1ad135a3ea9a2f98ac7c2bbad7bffcd94268e20ea6c1` |
| `godot/tests/test_actor_rig_integration.gd` | `5fbddf016e04a889b6fbc4723498b596cf9474b00a575c97f05b5466d13d82c6` |
| `godot/tests/test_exploratory_actor_selection.gd` | `ee2aa2ab86746bf6d1a673769a56d7fd88e5fc8432fb70e9be6ab1ab4590ab64` |

## Changed behavior and invariants

F5 offers all sampled rigs plus keyboard-driven physical barrel/Ripper in the
sandbox, Blacksite and four showcase districts. Applying restores the selected
map, its start and materials; R retains the actor and exploratory map navigation
carries the choice to the destination spawn. Live edits and motion do not survive
a representation switch. Labels distinguish sampled Ripper from the physical
single-hull Ripper; unsupported physical policy/NPC/power controls are disabled
or hidden. The popup has an opaque background for readability over detailed maps.

Sampled definitions are validated on the worker before scenario installation.
Main-thread live Rapier ownership and the immutable snapshot boundary remain
unchanged. The reset command and published context carry a request serial plus
applied disposition: matching geometry hashes alone cannot acknowledge a new
actor. The worker's ordinary actor-reset receipt remains separate. Controlled
fixtures, Benchmark mode, Tower and Water remain protected. The separate depth,
generation and Thunderbowl hosts have not acquired this exploratory picker.

The owner approved a full-roster physical Rapier migration, with exceptions only
for specifically impossible behavior/configurations. That direction and conversion
sequence are preserved in the [programme](../operations/physical-actor-programme.md).
This change does not implement the remaining 29-rig conversions, articulation,
usable grips or generic granular acceptance (#83).

## Runtime identity and commands

Windows x86-64, Godot `4.7.stable.official.5b4e0cb0f`, Rapier2D `v0.35.2`.
Godot executable: `C:/Godot47/Godot_v4.7-stable_win64_console.exe`.
Native Windows DLL SHA-256 is
`29140e5c8449ddf4a2013bfd2b2caeb92114421fb7ddbeda169e90b166f88c35`;
published native source is `781eccfa016ac0d220a51d2ecf12de1edf1b6d7b`.
Rapier Windows DLL SHA-256 is
`4e26ffa78ec2aaff434c4a70cd2ec85288b10ba5237912c35f204cb1e6ed2180`.
All 18 required LFS runtime objects were materialized. Authored map seeds are 0,
transport and Water settings are those of their unchanged recipes. The desktop
uses its existing worker policy; no fixed-worker performance or equivalence
acceptance is inferred from these integration tests.

Commands from the source root, using the pinned executable in place of `<godot>`:

```text
<godot> --headless --path godot --script res://tests/test_exploratory_actor_selection.gd
python tools/ci/run_godot_regressions.py --godot <godot> --output <temporary-output>
python tools/ci/check_docs.py
python tools/ci/check_m11_consistency.py
python tools/ci/check_repository.py --require-materialized
python tools/docs/retrieval_eval.py --output <temporary-output.json>
python tools/docs/retrieval_eval.py --queries docs/reference/retrieval-challenges.json --output <temporary-output.json>
git diff --check
```

Focused and ordinary suite cases use a 180-second timeout (the runner owns
individual exceptions). Local suite logs are under
`C:/Users/_/AppData/Local/Temp/cybersand-exploratory-actors-suite-v3/`;
final expanded focused output is `actor-integration-final-focused-v4.log` in the
same temporary root. The full sweep passed import plus all 80 assigned cases (81 result records),
including Water, Web-controller host and generation tests. Final focused integration
passes 479 assertions; the existing 56-assertion
physical-trial run also passes. The whole sweep includes the earlier
460-assertion revision and the popup before its final first-open fitting change;
the expanded final focused run adds navigation, owner-refusal and keyboard-only
UI checks. Final-source actor-rig integration (683 assertions) and feature launcher
(31 assertions) also passed after the popup fitting change. The final focused run uses the source
hashes above, including the opaque fitted popup, hidden sampled-only power row and legacy F6
reference-body restoration. Post-correction PCHAR representation checks and the
157-assertion original actor integration also pass. The full sweep predates only
the final UI fit and F6 restoration, covered by these focused final-source runs.

## Visual inspection

Actual NVIDIA TITAN RTX / OpenGL 3.3 / driver 581.80 captures show physical Ripper
and its picker in Blacksite and Neon. Temporary capture helper
`C:/Users/_/AppData/Local/Temp/capture_actor_picker.gd` runs with the same `--path godot`
and a rendering display, with a 60-second install deadline. Images are in
`C:/Users/_/AppData/Local/Temp/cybersand-exploratory-actors-visual/`.
The first capture exposed an insufficient popup background and a missing
post-layout wait; an opaque style and a first-open layout-frame refit corrected it.
This is visual inspection, not owner feel acceptance or an FPS measurement.

## Retained failures and limits

The first integration run caught a real same-hash reset acknowledgement race,
with old sampled rig identity surviving the UI transition. Per-request owner
acknowledgement corrected it. Early iterations also encountered invalid script
encoding/line endings, a fixed-size picker expectation and a changed override
signature; UTF-8/LF, preserved Set A indices with appended physical choices, and
the unchanged public two-argument scenario method corrected those failures.
Boundary review also found that legacy F6 could leave a Ripper-sized hull behind
when restoring the sampled sandbox player. F6 now rebuilds the three reference
bodies, and the focused test checks their 8 by 14 collider extent.
The initial GPU helper read `current_scene` before deferred replacement completed;
it now waits for the scene. Failed logs were retained in the temporary root.

Frozen retrieval retains 32/32 canonical top-five hits (MRR 0.849). Supplementary
retrieval is 64/65 (MRR 0.8692); the new ACT11 question ranks its canonical
programme first. C09's existing powder/contact historical-remediation question
falls outside the first five after corpus expansion. Its expected facts were
not rewritten or taken as new coupling acceptance. Answer correctness and
platform/Current-versus-Planned qualifiers still require source review.

No browser, Linux desktop or articulated-actor execution is claimed by local
Windows checks. Final exact-head hosted implementation gates and merge identity
belong in the PR record, separately from these local results.
