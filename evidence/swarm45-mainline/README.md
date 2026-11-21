# SWARM-004/005 admission control and evidence

This separate branch contains the reviewed bounded CI dispatch control and
additive evidence for [integration PR #715](https://github.com/techrote/cybersand/pull/715).
It is not intended to merge into main. Generated audit payloads and this control
are excluded from the production integration.

## Published candidate and exact evaluator

**Draft/HOLD.** The frozen implementation is `79b8a0a4a1c2ace435d709b35114ee7065c935e6`;
the original qualified build source is `96b8d3fb9d5a2e9f580d4b33293b1ab725269d4f`;
the published integration HEAD is `919134a39d31461947c410c233d59d1965c48414`.
Accepted main remains `846fe0533b3170e7b01f690518da49fc40cc24d1`.

The [published source/provenance manifest](published-source-provenance-r3.json)
maps all 159 changed paths to main and all five donors, with Git/LFS identities,
all 1,763 build / 147 native / 106 extension / 43 definition input hashes, and
the exact eight published runtime paths. It preserves the original qualified
build identity. All 81 pre-existing native source/header files are unchanged.
The earlier [source-only r3 manifest](frozen-source-provenance-r3.json) is retained.

Use the [current physical owner instructions](OWNER-EVALUATION.md) with the
unchanged `CyberSand-SWARM45-Draft-HOLD-Windows-96b8d3fb9d5a.zip`, SHA-256
`ce50316be11caafe32879395b681ef7f131541732061ded5db36dc3af6236c6d`.
The owner ZIP is artifact `14727701534` in the completed qualification run (inside
the GitHub artifact wrapper). Its 1,087 payload files plus package manifest have
been independently verified. The package's original donor guide is preserved;
the current guide above supplies the missing offline runbook route and exact
current-source recipes. No ZIP bytes were changed after qualification.

The [SWARM-006 successor handoff](SWARM006-SUCCESSOR-HANDOFF.md) distinguishes
accepted main from this unmerged candidate, records every deliberate donor delta,
and preserves V1/V2/V3 with composition schema 5. No SWARM-006 branch, PR, fixture
or evidence was mutated by this mission.

## Completed source and publication qualification

[R3 qualification run 44953582341](https://github.com/techrote/cybersand/actions/runs/44953582341),
attempt 1, passed in **34m26s**. [The complete observation](swarm45-r3-ci-observation.json)
records jobs, steps, artifacts, exact source and the measured critical path.
Linux strict native, relevant ASan/UBSan, all 360 known controls, actual Windows
native execution, and three Godot 4.7 graphical layouts passed. Each layout
passed all 14 required child processes and 17 accepted-main smokes: **51 smoke
passes** across Linux source, Windows source and the real extracted evaluator.
The extracted package passed post-import and Flatten custody with all four
canonical Rapier sidecars intact. Startup remains bounded at 60 seconds.

[Runtime publication run 44956855133](https://github.com/techrote/cybersand/actions/runs/44956855133)
passed. It added exactly eight runtime/provenance/binding paths to the dedicated
integration branch under an exact-parent lease. The four published LFS payload
identities and Linux executable bit match the original qualified artifacts.
No Ready, merge or source-policy action was performed by publication.

Independent completed reviews:

- [Committed source / historical-inspection closure](swarm45-r3-committed-source-review.md),
  with [259 independent assertions and genuine historical saves](swarm45-historical-inspection-fix-review.md).
- [Canonical archive repair](swarm45-package-archive-review-003.md), preserving
  exact committed metadata instead of relaxing package hashes.
- [Hosted r3 native/scientific integrity](swarm45-science-evidence/swarm45-hosted-r3-scientific-native-review.md),
  with the full machine audit and reproduction checker alongside it.
- [Windows source, actual package, current guide and publication candidate](swarm45-r3-windows-delivery-and-publication-review.md).
- [Windows build and original runtime inventories](swarm45-r3-windows-build-runtime-review.md).
- [Actual published source/protocol/security](swarm45-published-source-security-review.md),
  including the complete final donor/source manifest.
- [Actual runtime publication and final dispatch](swarm45-r3-actual-publication-and-dispatch-review.md),
  including Git/LFS bytes, uploaded objects and unchanged original build identity.

Each report states its own scope. Later final-CI and actual-publication reviews
are additive; a completed source review is not represented as owner acceptance.

## Final ordinary admission

The reviewed dispatcher [run 44957145764](https://github.com/techrote/cybersand/actions/runs/44957145764)
completed after verifying source qualification, exact publication, fixed workflow
definitions and live PR/head/base leases. It dispatched only these existing
workflows on exact published HEAD `919134a3…`, attempt 1:

| Gate | Run |
| --- | --- |
| Documentation / provenance | [44957191341](https://github.com/techrote/cybersand/actions/runs/44957191341) |
| Native | [44957198003](https://github.com/techrote/cybersand/actions/runs/44957198003) |
| GDExtension / current Godot | [44957204571](https://github.com/techrote/cybersand/actions/runs/44957204571) |
| Palette / actual backends | [44957211504](https://github.com/techrote/cybersand/actions/runs/44957211504) |
| PLAY desktop packet identity | [44957219135](https://github.com/techrote/cybersand/actions/runs/44957219135) |

This checkpoint records dispatch and identity, not a blanket PASS. The final
observation/reviews and PR record the completed results. The dispatcher cannot
alter readiness, merge state, source branches or SWARM-006. Its successful
execution does not satisfy or waive any admission gate.

## Retained failures and negative scientific evidence

R1 run 44947666723 remains failed: the Linux CLI symbol floor, dirty source UID
admission and a cold-start timeout were correctly refused. R2 run 44950154534
remains failed: both source layouts passed, but package smoke admission caught
four Git archive CRLF sidecars rewritten by Godot. The r3 canonical-archive repair
closed that defect without removing metadata or relaxing hashes. Earlier failed
reports and causality records remain available in this directory.

Original research receipts and results remain unchanged. SWARM-005 OFF/OFF and
BOTH retain 1 Complete / 14 Blocked / 21 Exhausted, with no new Apply success or
net foreign-joint gain. Unknown closure stays explicit. The replay is a known
regression corpus, not new unseen qualification. All 360 r3 raw/gzip outputs and
all 14 Linux native binary payloads equal r2 where source identity permits comparison;
original producer identities are still separately recorded.

The earlier complete 720-output paired known-replay archive is retained separately,
SHA-256 `e8820a0b30036aee4fd0be71537400db55bdacc1f1c6d5eab20d37741ab6956f`.
Original donor branches, registrations, immutable corpora and SWARM-006 fixtures
are preserved.

## Remaining physical acceptance

The new package still requires physical NVIDIA/original saved or painted
2048×2048-map visual, architectural, collision and usability evaluation required
by #698. Hosted software-rendered graphics and earlier donor acceptance do not
satisfy it. Draft/HOLD remains until all source-matched gates, independent final
reviews and that owner gate pass. No auto-merge is enabled.
