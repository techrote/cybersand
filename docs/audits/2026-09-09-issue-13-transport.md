# Issue #13: Experiment Tower and optional transport

Date: 2026-09-09. Work is on `codex/issue-13-experiment-tower` in
`C:/kybersand/source`. Intake exactly matched
`372bfb3ac3cbbb8005b594cd0995ed5e71d6c530` on
`codex/issue-10-player-and-exchange`. The sole tracked delta was the intentional
Windows DLL, SHA-256 `d363cadf71674eab72df54c154bac3aeccbfaa63884c8c3a6b92fe585e1039eb`.
Its bytes are preserved in `C:/kybersand/validation/local/2026-09-09-issue-13/intake/`.
No tilde DLL existed at intake; none was removed. The companion repository was
clean. Functional deliverables in `C:/cybersand` remain untouched.

## Reference and tower checkpoint

The [runbook](../operations/experiment-tower.md) owns recipe and command semantics.
Raw prefix: `C:/kybersand/validation/local/2026-09-09-issue-13/`.
`baseline/manifest.json` records actual source inputs and the freshly compiled
Windows reference CLI. `baseline/references.json` retains 60 fresh 1800-tick
controls with exact matching one/four-worker samples at each seed. Every run
has zero diagnostic overflow. These were captured before solver changes.
Baseline values are preservation references, not a new transport tuning decision.

The native DLL was freshly rebuilt (`baseline-native-build.log`, 10.13 seconds,
wrapper `20260909-232211`). `tower-test.log` passes deterministic construction,
safe landings, all reservoir plugs, invalid candidate preservation, exact recipe
reset, actual desktop owner startup and exactly one paused single step. Both
controller scene resources load. This headless test is not a visual walkthrough.

Checkpoint documentation mapping: this new runbook owns tower controls and fixture
inputs; ownership and interfaces link it for the queued replacement boundary;
configuration links construction/command budgets; tests, handover, roadmap,
source identity and evidence route the new work. Material and Water solver,
granular policy, ADR-008/011, cell state, saves and reactions are unchanged at
this first checkpoint. Profile infrastructure and new transport follow separately.

Real Web execution, visual review, experimental transport/profile validation,
performance comparisons and final regression/documentation checks are pending.
Published runtime provenance remains a separate known mismatch; it is not repaired
or relabelled by this issue. Historical #9/#10 and M11 records remain intact.

Reference checkpoint gates: native suite **52/52**; documentation, retained M11,
eight checker-contract tests, both retrieval evaluations and `git diff --check`
pass. [Gate commands and outcomes](issue-13-2026-09-09/tower-validation.json)
retain the separate repository failure: **14 published-runtime mismatches**, the
same six inputs per platform plus dirty Windows bytes/LFS identity inherited
from #10. Frozen [baseline samples](issue-13-2026-09-09/baseline-references.json)
and [source/artifact manifest](issue-13-2026-09-09/baseline-manifest.json) are
retained in source. The full Godot suite was started and remains in progress at
this focused checkpoint; its later outcome will be recorded independently.
