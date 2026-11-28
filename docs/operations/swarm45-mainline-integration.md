---
title: SWARM-004 and SWARM-005 mainline integration and evaluation
status: Current
document-kind: runbook
scope: Dedicated mainline integration candidate, frozen donor custody, mandatory qualification and separate physical owner acceptance
canonical-for: [swarm45-mainline-integration, swarm45-current-evaluator]
last-reviewed: 2026-11-21
related-documents: [swarm004-workbench-playtest.md, swarm005-workbench-playtest.md, ../systems/gentek-reciprocal-assembly.md, ../architecture/experimental-workbench-authoring-patch.md, github-development-and-release.md]
---

# SWARM-004 and SWARM-005 mainline integration

**22 November successor:** the [unified SWARM-004/005/006 runbook](swarm456-unified-mainline.md) owns the single consolidated mergedown. This page preserves its predecessor checkpoint and evidence; earlier separate sequencing is historical.

**Dedicated integration candidate; Draft/HOLD pending admission.** The owner
authorized reconciliation, qualification and a manual merge after every admission
gate passes on 21 November 2026. This is not an automatic merge authorization.
No source in the concurrent SWARM-006 mission is adopted or modified.

The branch `integration/swarm004-005-mainline-20261121` started from accepted main
`0f0161af337d6d0cee8fa961a9667aff570a75b0` and imports the reviewed donor graph
through #700. Its second freeze reconciles accepted main
`846fe0533b3170e7b01f690518da49fc40cc24d1`: PR #714 changed only Documentation
check ordering and the CI performance runbook, and those accepted files are
preserved exactly. Accepted Water/Wave Flow, all 80 Genteks, Paint, SCRIPT-HOTPATH, Art
history and lazy restoration, Flatten, actors, existing saves and publication
remain the baseline. The new source must earn its own runtime and platform
evidence; green donor results cannot stand in for that qualification.

## Source custody and donor ancestry

| Donor | Frozen commit |
| --- | --- |
| Native SWARM-004, [#692](https://github.com/techrote/cybersand/pull/692) | `2c4b8061ef5315de6a31df933e9f84c31865284e` |
| Workbench SWARM-004, [#693](https://github.com/techrote/cybersand/pull/693) | `16a11ef2d25f03d58b229f4bba3f88009ebe1154` |
| Native SWARM-005, [#696](https://github.com/techrote/cybersand/pull/696) | `c178feeb39899fd155b7deb9d5bde3f50ee28548` |
| Workbench SWARM-005, [#697](https://github.com/techrote/cybersand/pull/697) | `8ec6d3c62197f3ef4088d79e4aa2910f5eaa36f7` |
| Documentation registration, [#700](https://github.com/techrote/cybersand/pull/700) | `580ff82f285b7aeda8fb4a2a0d034425f0d0401d` |

#693 and #696 separately descend from #692; #697 contains both, and #700 is its
direct descendant. The accepted-main / Workbench-donor merge base is
`de58bf1997ca75825cf3b29e046dc1c1022c45bf`. The integration preserves this ancestry
with a real merge, retains current-main authoring seams and imports only the
additive reciprocal transaction. Original donor PRs and branches remain intact.

The [custody tool](../../tools/swarm45/runtime_custody.py) records the exact build
commit and tree, complete source/build input SHA-256 inventories, native
definition, platform, executable bytes and original hosted producer run/attempt.
The request-only execution commit and its frozen source ancestor remain separate
identities. Runtime publication uses the actual qualified bytes and a branch-tip
lease; a source label or edited manifest never qualifies an older binary.

The publication transaction covers eight paths: the Linux and Windows native
adapters, their two provenance records, the Linux and Windows reciprocal command
line executables, and their two platform-specific source bindings. The ordinary
Workbench resolves its platform binding without developer environment overrides.
A present invalid platform binding fails closed; the legacy evaluator binding is
used only when the platform-specific file is absent. Both executables use Git LFS,
and the Linux executable retains its execute permission. The cheap ordinary
[repository gate](../../tools/ci/check_swarm_runtime.py) verifies the exact native
input inventory, protocol definition, executable hash and target format without
running a research campaign. Hosted qualification also checks the existing Linux
runtime compatibility floor.

### Additive historical identity correction

The exact Makefile definition algorithm produces:

| Source | Native definition SHA-256 |
| --- | --- |
| #692 | `07901d11889c217ebe61e9ab3562046914a1e9e31865281fe8667b4124adbc71` |
| #693 | `57ff699bf5c9833a2a5e2198ff2ef0b07cfd051069013776e6427f1e9d6694ec` |
| #696 | `4ef94e7b1b13506f50318791a2c9d3f632e3eccca3889c7d12b01e0e61759365` |
| #697 / #700 | `12a4816dab749a9c872a4d531836db8ec6a170aab31576d70086efa80eeb3b6b` |

The archived SWARM-005 compiler receipts and #698 assertions associate #696 with
`12a4816d…`, which is the Workbench native source set's definition. The native
engine core is identical; its hashed `reciprocal_main.cpp` differs. The old CSV
archive has no binary hash, full source inventory or complete native JSON planes.
Keep those original receipts unchanged and describe their custody limitation.
They do not establish an exact native-only build identity. Test translation
units are also included in the definition hash, so new native tests require a
new compiled definition and explicit Workbench protocol admission.

## Experimental authoring and defaults

Open ordinary **Shared Workbench**, then **Reciprocal assembly…**. Its single
lazy dock is labelled **Experimental · FRAMEWEAVER × MOSAIC**. Opening the dock
does not capture, generate, change the installed World or enable either SWARM-005
option. Explicit **Generate** uses a copied native material plane; native preview
and inspection remain separate from **Apply construction**.

**Source-feasible terminal parts** and **Source-bound MOSAIC receptors** both
start OFF. Independent FRAMEWEAVER/MOSAIC controls, expression, seed, ownership,
protected passages and bounded proposal rounds retain their reviewed meanings.
The separate negotiated-sharing control retains its donor default and meaning.
A local welded termination is a source-time part choice, not a foreign reciprocal
joint. `STILL_REQUIRED` obligations and genuinely blocked negotiations refuse
Apply. Native Stone13 retains its ordinary powder behavior.

Both options OFF preserve the V1/V2 transport. Enabling either uses existing V3
with the exact option bits; composition evidence remains schema 5. The integrated
definition and executed CLI are bound to immutable receipts. Pending numeric
text, control edits, source changes and the start of a territory gesture retire
old Apply authority. Territory input stays with the dock during generation so
it cannot fall through to live Paint. Failed runtime admission cannot preserve
an earlier proposal's Apply authority.

Apply and inverse Undo use the existing private prepared retained-World
transaction, exact material/protected/body masks, source and physical fences,
single-use commit tokens and acknowledged history. Current Water settings remain
authoritative. Ordinary Save/Load formats and historical recipe semantics are
unchanged. Saved composition evidence is inspection-only, not reusable Apply
authority. See the [transaction contract](../architecture/experimental-workbench-authoring-patch.md).

Saved inspection recognizes matching FRAMEWEAVER/MOSAIC definition pairs from
the frozen #693 and #697 Workbench sources, integration r1 (`fe62e154…`) and the
current integration (`217bfa71…`). Unknown or mixed definitions remain refused.
Only #693 may omit the two later SWARM-005 option fields; they mean false and
cannot retroactively enable either capability. All original receipt, evidence,
material and source checks still apply. Inspection preserves the native result's
original `can_apply` value as historical evidence while separately disabling
Apply, submission, attestation and construction Undo. Cancellation or control
changes cannot remove that restriction; a successful fresh current-source
generation is required. Live decoding admits only the current definition.

## Deliberate integration changes

- Preserve accepted-main Workbench actor, Paint and Art integration while adding
  the donor's retained authoring-patch transaction and lazy dock.
- Retire proposals on pending numeric text and initial gesture mutation, commit
  focused numeric fields before actions, consume in-progress territory input,
  and retire stale proposals before attempted runtime readmission.
- Replace the receptor scanner's fixed estimate with charged bounded visits.
  Immutable source-root membership is computed once per slot. Rejected searches,
  footprint visits and exact receipt finalization consume the same existing
  allowance. Exhaustion/cancellation publishes no partial receptors. No allowance,
  geometric policy, connector obligation or physical material is enlarged.
- Keep protocol/controller/adapter fixtures in ordinary Godot discovery. The
  external-CLI controls and graphical lifecycle harness are explicit mandatory
  scoped fixtures, not silently skipped ordinary tests.
- Complete #700's corpus registration with required guide metadata, preserve its
  historical scope and add this current integration route.
- Ship source-bound reciprocal executables with both retained runtimes, with
  platform-specific lookup and fail-closed stale-binary handling. This closes the
  donor's evaluator-only executable installation gap in ordinary Workbench use.
- Use C stdio for the CLI's five progress/error output sites to preserve the
  existing Linux runtime compatibility floor. Native JSON serialization and
  generation semantics remain unchanged; the changed source receives a new
  native definition and explicit protocol pin.
- Preserve bounded read-only inspection of reviewed historical Workbench
  definitions across native-source updates, without restoring their transaction
  authority or rewriting saved maps, receipts or evidence.
- Archive canonical committed text when staging source installations and Windows
  evaluators. Child-only Git line-ending defaults preserve explicit per-file
  attributes, binary bytes and every import sidecar. This prevents Windows Git
  settings from changing sealed metadata that Godot subsequently rewrites; exact
  package hashes and source-clean checks remain mandatory.

These choices are reversible as separate integration deltas, but reverting the
authority or accounting repairs would restore demonstrated defects. No SWARM-006
recovery policy, V4 transport, schema-6 composition or inspector UI is imported.

## Scientific limits and known-matrix replay

The original registered holdouts are **already complete**. SWARM-004's selected
fixed-territory, two-round holdouts produced nine causal joint constructions and
**zero causal fully closed Apply successes**. Its original unresolved deficits
and closure-unknown outcomes remain in their denominators.

The [SWARM-005 registered results](https://github.com/techrote/cybersand/issues/698#issuecomment-7055626297)
contain 36 cases per policy, ten policies and 360 executions. OFF/OFF and BOTH
each report **1 Complete, 14 Blocked and 21 Exhausted**, with eleven qualified
joints in each aggregate. There are zero newly Apply-valid cases and zero net
new qualified joints. Nine fewer source obligations in six still-blocked cases
do not establish foreign joins. Hard-only and fixed-territory controls change
other policy dimensions. Absent closure metrics on exhausted rows mean unknown,
even where the old CSV serialized zero.

The [known-matrix replay](../../tools/swarm45/replay_known_controls.py) preserves
the same fixtures, expressions, seeds and option combinations, but retains full
native JSON/material arrays, explicit unavailable metrics, source and executed
binary hashes. It is integration regression/reproduction, **not new unseen
qualification**. The [external driver](../../tools/swarm45/replay_known_control.cpp)
does not add runtime policy or increase budgets. Any accounting-induced changes
are new-source outcomes, never edits to original scientific receipts. No new
generalization or success-rate claim follows from this integration.

## Qualification and owner evaluation

Development uses strict native suites, relevant ASan/UBSan, malformed-request and
receipt mutations, real typed-input controls and source-built native adapter
checks. A frozen candidate requires Linux and hosted Windows Godot **4.7**
graphical Generate → Preview → Apply → Undo → Save → quit → fresh-process Reopen,
representative complete and blocked cases, lifecycle cancellation/timeout/source
staleness, full native-plane verification and accepted-main Paint/Water/Art/
Flatten/actor smoke. A separately extracted Windows evaluator repeats the real
sequence. Hosted software-rendered graphics are identified as such.

The original #697 run `44854238228` passed its individual V3 Irregular create/
reopen and Viaduct blocked cases but failed Workbench startup in its final
lifecycle scenario. Its aggregate failed and pristine evaluator qualification did
not run. Keep that failed evidence. The integration retains the 60-second startup
bound and adds bounded state/screenshot diagnostics instead of declaring a pass
from those partial results.

Final admission also requires source-matched Linux/Windows retained libraries
and provenance, applicable standard resulting-source gates, genuinely independent
source/protocol/scientific/platform review, no unresolved P1/P2 integration defect,
live mergeable HEAD/base verification and physical owner acceptance. Only after
all gates pass may the dedicated PR become Ready and merge manually. No auto-merge.

### Physical owner gate

[Registration #698](https://github.com/techrote/cybersand/issues/698) explicitly
requires the owner's physical NVIDIA and original-map evaluation separately
from hosted Windows qualification. Earlier evaluation of donor packages does
not accept this newly reconstructed source/package. Until that gate is completed
or explicitly changed by the owner, retain **Draft/HOLD**.

Use the exact newly qualified evaluator identified by the integration PR, verify
its manifest and hashes, extract into a fresh folder and launch its ordinary
Workbench. Confirm the Experimental dock is discoverable and both new controls
are OFF. Follow the [paired 005 cases](swarm005-workbench-playtest.md#reproduction-from-the-owners-blocked-examples),
then repeat on the owner's original saved/painted 2048×2048 map, with the actual
protected cells and chosen crop. Record genuine Blocked outcomes. For an
Apply-authorized case, Apply, Undo, regenerate, Apply, Save, fully quit, start a
new process and Reopen. Verify the recorded material/evidence identity and report
visual, architectural, collision and usability observations with GPU/driver,
package/source hashes and saved-world identity. Do not infer load-bearing
stability from native material-path validity alone.

## SWARM-006 successor and housekeeping

The integration PR handoff must publish the definitive merge SHA, or explicitly
label an unmerged qualified candidate if HOLD remains, together with its full
file inventory, definition hashes, transport versions, runtime provenance and
the deliberate differences listed above. SWARM-006's frozen controls and
scientific comparisons keep their original source identities; a new baseline
requires an explicit successor comparison. PRs #705, #707, #709 and #710 and their
branches/fixtures/evidence are outside this mission.

After a successful integration, #692, #693, #696, #697 and #700 are candidates
for later closure as superseded. Keep their source branches and evidence.
Foundations #625, #662 and #686 retain historical/scientific value and should not
be mass-closed merely because their source is an ancestor of this candidate.
