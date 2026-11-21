# SWARM-006 successor handoff — SWARM-004/005 integration candidate

**This is a qualified source candidate, not a new accepted-main baseline.**
Integration [PR #715](https://github.com/techrote/cybersand/pull/715) remains
Draft/HOLD. No merge or Ready transition has occurred. At this checkpoint,
accepted `main` is `846fe0533b3170e7b01f690518da49fc40cc24d1`.

## Exact source and runtime chain

| Role | Commit / tree |
| --- | --- |
| Frozen implementation | `79b8a0a4a1c2ace435d709b35114ee7065c935e6` / `db1393c21a5e58137f06e6b6008f1001775da89f` |
| Qualified original build source | `96b8d3fb9d5a2e9f580d4b33293b1ab725269d4f` / `a3312e00b971cf6859922b2b70eb8ed5da0f66b7` |
| Publication request only | `a7c0a6d42f4a41622faf183c01818ffb73c56899` / `ff989cbd8d8ff0cef39cefec5ea0890346b0f65d` |
| Published integration candidate | `919134a39d31461947c410c233d59d1965c48414` / `78d6df75cb3534238c81b40e7bcdbe0cf693d012` |

Branch: `integration/swarm004-005-mainline-20261121`. The latter three commits
are direct children in the order above. Source-to-execution and execution-to-
publication-request changes are request files only; actual publication changes
exactly eight approved runtime/provenance/binding paths. Build records retain
their original `96b8d3fb…` identity.

The [published manifest](published-source-provenance-r3.json), SHA-256
`805ebd2893a157b87e50e6aadc2008e51822448ea877b6ea991c8efd245228b3`, maps
all **159 changed paths** against accepted main and all five frozen donors.
It records Git blob identities separately from LFS payload SHA-256/size, the
Linux CLI executable mode, and all **1,763 build / 147 native / 106 extension /
43 definition** inputs. Those inputs are identical between the qualified build
source and published candidate. All 81 existing accepted-main native source and
header files are unchanged.

Native definition: `217bfa716e61198f5b3849f2ae14c30e85bc9f623fc1d05438c59df2296ce7f7`.
Transport remains **V1/V2 compatible, V3 for the two opt-in SWARM-005 controls**;
composition evidence remains **schema 5**. The independently inherited donor
schema-6 control serializer is unchanged and is not a SWARM-006 composition
transport or recovery-policy import.

## Frozen donors and deliberate differences

| Donor | Frozen HEAD |
| --- | --- |
| #692 native SWARM-004 | `2c4b8061ef5315de6a31df933e9f84c31865284e` |
| #693 Workbench SWARM-004 | `16a11ef2d25f03d58b229f4bba3f88009ebe1154` |
| #696 native SWARM-005 | `c178feeb39899fd155b7deb9d5bde3f50ee28548` |
| #697 Workbench SWARM-005 | `8ec6d3c62197f3ef4088d79e4aa2910f5eaa36f7` |
| #700 documentation registration | `580ff82f285b7aeda8fb4a2a0d034425f0d0401d` |

The current integration imports reviewed source and preserves the true donor
graph. It does not replace any frozen SWARM-006 baseline with current output.
The substantive differences from frozen SWARM-005 are narrowly scoped:

- Reconcile accepted-main Paint, Art, actor and retained-World transaction seams;
  make the experimental dock discoverable and lazy. Opening it does not generate.
- Charge actual bounded receptor visits and finalization against the original
  allowance, with immutable source-root membership and no partial receptors on
  cancellation/exhaustion. Policies, seeds, fixtures and budgets are not tuned.
- Retire stale transaction authority on pending numeric text, gesture start and
  failed runtime admission; consume territory input during generation.
- Publish source-bound Linux/Windows reciprocal CLIs and adapters with strict
  platform bindings. Use C stdio at five CLI console sites to preserve the existing
  Linux symbol floor; native JSON/generation policy remains unchanged.
- Preserve read-only inspection of the reviewed historical paired definitions.
  Fresh successful current-source Generate is required for transaction authority.
- Stage canonical committed text for source installations and evaluator archives,
  retaining explicit attributes, binary bytes and every import sidecar.
- Register the valid #700 documentation and current integration procedure, plus
  bounded source/platform/custody qualification.

Both SWARM-005 switches remain OFF in ordinary Workbench. Workbench negotiated
sharing also remains OFF; the historical native V1 shared-ownership default
remains true. These are distinct scopes, not a native-default migration.

## Scientific continuity

Original receipts, immutable corpora, registrations and negative results remain
unchanged. SWARM-005 OFF and BOTH each retain **1 Complete / 14 Blocked /
21 Exhausted** over the 36-case primary arms, with no new Apply-valid cases and no
net qualified-joint gain. A local welded termination is not a foreign joint.
Unmeasured closure on exhausted runs remains unknown.

The full 360-case integration replay is an already-revealed regression corpus,
not new unseen qualification. Relative to the frozen reference, corrected work
accounting changes one final fixed-territory result: case 19 moves from Exhausted
to Blocked with four joints, one unresolved obligation and Apply false. The other
differences are recorded in the independent scientific audit; historical evidence
has not been edited to claim improvement. R3 raw results and binaries exactly
match R2 where the native input identities justify reuse.

Do not silently substitute this integration's native definition or results for
the frozen SWARM-006 controls. Any later successor rebase needs explicit source
mapping and its own required qualification. This mission has not mutated #705,
#707, #709, #710, their source branches, scientific fixtures or acceptance evidence.

## Qualification and remaining admission

[R3 scoped qualification](https://github.com/techrote/cybersand/actions/runs/44953582341)
passed on the exact original build source: Linux strict native and relevant
ASan/UBSan, all 360 known controls, actual hosted Windows native execution, and
Godot 4.7 source/Linux, source/Windows and pristine-extracted-Windows layouts.
Each layout passed 14 required child processes and all 17 accepted-main smoke
cases. [Runtime publication](https://github.com/techrote/cybersand/actions/runs/44956855133)
passed and published the exact eight qualified paths.

The five final ordinary workflows are bound to published `919134a3…`: documentation
44957191341, native 44957198003, GDExtension 44957204571, palette 44957211504 and
PLAY 44957219135. Their current/final results and independent evidence reviews
are tracked in PR #715; dispatch is not itself a result.

The [current owner guide](OWNER-EVALUATION.md) identifies the unchanged evaluator
ZIP, SHA-256 `ce50316be11caafe32879395b681ef7f131541732061ded5db36dc3af6236c6d`.
Physical NVIDIA evaluation of the original saved/painted 2048×2048 map remains a
mandatory separate gate. Earlier donor acceptance and hosted graphics do not
accept this new package. Until all gates pass and a manual merge is verified,
`919134a3…` is an unmerged candidate and `846fe053…` remains accepted main.

After a successful merge, #692/#693/#696/#697/#700 can be reviewed for closure as
superseded. Keep their source branches and historical research foundations. No
donor PR has been closed by this integration mission.
