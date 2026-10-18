---
title: Combined features and first physical Blacksite comparison validation
status: Current
document-kind: audit
scope: 2026-10-18 integration source, local Windows evidence, preserved failures and separate exact-head hosted merge gates
canonical-for: []
last-reviewed: 2026-10-18
related-documents: [../operations/physical-actor-programme.md, 2026-10-18-owner-actor-observations.md, ../reference/validation-evidence.md]
---

# Combined feature integration checkpoint — 2026-10-18

## Source and recoverability

Implementation checkpoint: `2831932f57d5c15ca902cdff8b8c1982f5ec9fa1` on
`codex/combined-feature-launcher`, in a separate managed source worktree. The
original material branch and quick-play snapshots are preserved. PR #176 owns
launcher/physical-trial integration; #164, #173 and #175 retain their existing
feature ownership. Existing source commits and historical audits are not rebased
or rewritten. The owner explicitly authorized sequential integration and the
first physical barrel/Ripper comparison.

The native Windows DLL remains GEN-002 publication
`29140e5c8449ddf4a2013bfd2b2caeb92114421fb7ddbeda169e90b166f88c35`, native source
`781eccfa016ac0d220a51d2ecf12de1edf1b6d7b`. Rapier Windows DLL remains
`4e26ffa78ec2aaff434c4a70cd2ec85288b10ba5237912c35f204cb1e6ed2180`.
All eighteen required runtime objects are materialized. No native source,
source-sensitive binary input, dependency pin or workflow is changed by #176.

## Executed local checks and preserved failures

Windows, Godot `4.7.stable.official.5b4e0cb0f`, Python 3.12, one body in each
physical arm; fixtures retain ordinary native worker selection and record their
published context. Focused scene tests allow 60 seconds per owner acknowledgement.

- `godot --headless --path godot --script res://tests/test_physical_actor_trial.gd`:
  56 assertions, zero failures on the implementation checkpoint. Covers matching
  geometry, all four owner installs, real Rapier velocity/rotation under impulses,
  invalid input/body rejection, camera continuity, reset and input rearming.
- `test_feature_launcher.gd`: 27 assertions, zero failures. All six feature
  destinations plus Ripper open, acknowledge where applicable, close and return
  via F2. `test_playval001_selectable_player_fixtures.gd`: 75 assertions, zero
  failures, preserving original representation controls.
- The broad `tools/ci/run_godot_regressions.py` Windows sweep executed 70 test
  scripts before stopping at the workbench's old default-scene premise: 69 passed,
  `test_worldgen_workbench` failed one of 138 assertions because it required
  `main.tscn` as the application entry. Updating that intentional entry premise to
  `feature_launcher.tscn` passed all 138. The sweep ran during implementation and
  is supporting coverage, **not an exact-final-head full-suite pass**. The two
  profile runners and default-scene startup were then executed separately.
- Earlier focused Blacksite integration found two title-capitalization failures
  after the comparison title change. The original title was restored for the
  original definition; the broad sweep subsequently passed all 249 assertions.
- Initial worktree imports failed because native DLLs were LFS pointers. Normal
  LFS materialization corrected that prerequisite; no binary was substituted.
- `python -m unittest discover -s tools/ci -p test_feature_web_staging.py`:
  passed, including old/new desktop entry configurations, preserved source bytes,
  Web entry replacement and removal of desktop navigation from staged exports.
- `launch-desktop.cmd -PrintIdentityOnly`: passed in Windows PowerShell after
  replacing the unavailable Get-FileHash dependency with a streaming .NET SHA-256.
  Runtime hashes and the existing provenance rejection remain enforced.
- `capture_feature_trials.gd --output=<local directory>`: actual NVIDIA TITAN RTX,
  driver 581.80, Compatibility/OpenGL 3.3, 1280 by 720 launcher/barrel/Ripper PNGs
  rendered and visually inspected. The capture helper's first attempt reached a
  scene-transition null instance; waiting for scene installation fixed the helper.
  Captures are paused scene/layout evidence, not interactive feel acceptance.
- `check_docs.py`, `check_repository.py --require-materialized` and
  `check_m11_consistency.py` passed. Initial local documentation checks reported
  six missing companion-workspace references; the five required files were then
  materialized outside the source root from exactly CI's pinned companion commit
  `6a58311982941b75f46e22109a0829e5acb83c7e`. No placeholder evidence was invented.
- Frozen retrieval: 32/32 canonical top-five, MRR 0.849. Supplemental retrieval:
  63/63 top-five, MRR 0.8788, including new ACT10. These are lexical development
  results, not semantic or gameplay acceptance. Manual ACT10 review confirms
  desktop-only scope, separate generation ownership and Planned articulation.

Commands used the pinned Godot console executable; the broad runner supplies
180-second test timeouts and 1200-second profile timeouts. Local logs and PNGs are
machine-local outputs, excluded from source. Normalized source hashes below bind
focused checks to the checkpoint; the dated old failures remain in local logs.

| Source | SHA-256 of LF-normalized bytes |
|---|---|
| `godot/scripts/main.gd` | `69cd5f2f98de18d627d909d42dfdff4f1aa6457cedd3eea1261748934c56791b` |
| `godot/scripts/physical_actor_trial.gd` | `8f2255cc3eedef597c945d5d7a9b9a50a5937ccd3a21ff3383a4414404ef8ffe` |
| `godot/scripts/feature_launcher.gd` | `1cc3ce7fa5f83c5e98dbb17207bb81e75a21562669ec8064f1e4d002fbcd8237` |
| `godot/scripts/feature_navigation.gd` | `b5c5a1c3396a659f8f9c07de3c7e8fdf8ba85a67080eea45a943d2bbcf0c7ac7` |
| `godot/scripts/rapier_physics_bridge.gd` | `203b703c7f1c9a7ce8cd5e32619c43b0e8aa1a89daffb0bae799b2296c8f2b46` |
| `godot/tests/test_physical_actor_trial.gd` | `11baffcde96549f15c6ed87ddad4ca17fbaa39c0232eb41dd4699943df858017` |
| `godot/tests/test_feature_launcher.gd` | `abf514bd385d084aa2ab61272e0e1780bfdad8490488167e1a14c7abd76d7297` |
| `tools/build_web.py` | `8e03dbdfbfb994618d237225d72dac8b1bd258a7b6748906987a67987f64fce0` |

## Documentation-update checklist and merge gate

The physical actor programme owns controls, bounds, ownership and Planned
follow-ups. Configuration, interfaces, ownership, roadmap, owner intent, handover,
build guide and retrieval routes are updated with it. Existing architecture ADRs
and body ABI remain unchanged: this is one ordinary rectangle using current
coupling, not generalized shape/torque feedback or articulated dynamics. Original
scenario definitions and audits are preserved. Web export staging is adjusted to
retain its own entry; actual browser execution is not claimed.

Exact-head hosted Documentation/provenance, Native, GDExtension/Godot and scoped
Water gates are recorded in the respective PR descriptions before merge. Draft
skips and old heads are not acceptance evidence. This local record alone does
not authorize a failed or stale gate to merge. Final integration disposition is
recorded separately from these local execution results.

## Depth addition after chat-history access recovered

The depth conversation identified separate PR #169, previously omitted while history access was rate-limited. Its corrected reconstructed implementation is included in the combined branch, with separate [fresh depth validation](2026-10-18-depth-integration-validation.md). The launcher now opens seven features plus four comparison arms; the updated navigation runner passes 31 assertions. Focused physical checks still pass 56 assertions after integration. The seven-feature run supersedes the earlier 27-assertion launcher count for the enlarged menu, without rewriting that earlier evidence. Final exact-head hosted checks remain the integration gate.

Direct-entry follow-up: all three explicit `test_feature_launch_arguments.gd` invocations (`--blacksite-nine`, `--showcase`, `--depth-lab`) passed on Windows. Startup arguments are consumed once so F2 can return to the launcher and a subsequent sandbox selection stays ordinary. The seven-feature navigation runner still passes 31 assertions. Supplemental DEP01 adds explicit layering/paused-bake ownership coverage; the supplementary set now contains 64 questions. Final source-head gates are recorded in PR #176.
