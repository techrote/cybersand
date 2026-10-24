---
title: MAT-003 reconciliation after the LCB-001 regression follow-ups
status: Current
document-kind: audit
scope: Import landed PR240 into the unmerged MAT stack, preserve the completed prior gates and immutable experiments, and require fresh exact-head integration checks
canonical-for: []
last-reviewed: 2026-10-24
related-documents: [2026-10-24-mat003-lcb001-integration-checkpoint.md, 2026-10-24-issue-200-policy-foundation.md, ../reference/status-and-roadmap.md, ../operations/mat-003prepass-registration.md]
---

# MAT-003 and the landed #240 regressions — 2026-10-24

## New main and the completed previous checks

After the second reconciliation's required checks completed, main advanced from
`1e032e492cafb232e604baf6e2b823b13d779aa8` to
`a395e33dc0632f5c3f41e8b8b1c18c89f0aaa131`, the merge of
[PR #240](https://github.com/techrote/cybersand/pull/240). The bounded #200
foundation previously landed through [PR #239](https://github.com/techrote/cybersand/pull/239).
#240 adds committed threaded-worker request/receipt regressions and C API
allocation-failure injection; it changes tests and the corresponding evidence
and roadmap. It does not change a production runtime input or published runtime.
The upstream [foundation evidence](2026-10-24-issue-200-policy-foundation.md)
is imported exactly from the new main, including its additive follow-up record
and the retirement of those two formerly explicit test gaps.

By 09:11 UTC, all **15 required current-source workflows and seven scoped MAT
workflows passed** at the second reconciliation's exact heads. GitHub metadata,
decoded execution logs, source identities, merge parents/trees and sealed
artifacts were inspected. These completed results are preserved; they establish
results for their recorded sources and are not predictions for new heads.

| PR | Previous exact head, preserved | Documentation/provenance | Native | Godot |
|---|---|---|---|---|
| #208 | `ff7afb1eaf0db185a5580e1318a416d943839fa1` | [40075047449](https://github.com/techrote/cybersand/actions/runs/40075047449) | [40075047462](https://github.com/techrote/cybersand/actions/runs/40075047462) | [40075047451](https://github.com/techrote/cybersand/actions/runs/40075047451) |
| #211 | `ec9d59c86a0cf988cc416e76cf8a5fb93cb50c1c` | [40075047178](https://github.com/techrote/cybersand/actions/runs/40075047178) | [40075046933](https://github.com/techrote/cybersand/actions/runs/40075046933), attempt 2 | [40075046913](https://github.com/techrote/cybersand/actions/runs/40075046913), attempt 2 |
| #221 | `c7f988e7943d9a26fee9c0c097402cbb5cf50759` | [40075047360](https://github.com/techrote/cybersand/actions/runs/40075047360) | [40075047117](https://github.com/techrote/cybersand/actions/runs/40075047117), attempt 2 | [40075047075](https://github.com/techrote/cybersand/actions/runs/40075047075), attempt 3 |
| #235 | `227d57f2c878e4c8de60a3661857c25b0a9cf0c2` | [40075047978](https://github.com/techrote/cybersand/actions/runs/40075047978) | [40075047990](https://github.com/techrote/cybersand/actions/runs/40075047990) | [40075047984](https://github.com/techrote/cybersand/actions/runs/40075047984) |
| #238 | `33eb9f64e5a04772ca92ebe376a5db725f0886f7` | [40075047911](https://github.com/techrote/cybersand/actions/runs/40075047911) | [40075047919](https://github.com/techrote/cybersand/actions/runs/40075047919), attempt 2 | [40075047875](https://github.com/techrote/cybersand/actions/runs/40075047875), attempt 2 |

The previous #208 base was main `1e032e4`; each later PR used the preceding head
in this table as its base. All fifteen table entries have an official successful
workflow conclusion. The seven successful scoped runs are:

| Scoped check | Previous run |
|---|---|
| #208 S1 World | [40075047468](https://github.com/techrote/cybersand/actions/runs/40075047468) |
| #211 S2F source/twins | [40075047156](https://github.com/techrote/cybersand/actions/runs/40075047156) |
| #221 continuation contracts | [40075047082](https://github.com/techrote/cybersand/actions/runs/40075047082) |
| #221 S2P | [40075047337](https://github.com/techrote/cybersand/actions/runs/40075047337), attempt 2 |
| #221 C128 | [40075047077](https://github.com/techrote/cybersand/actions/runs/40075047077) |
| #235 verifier contracts | [40075047985](https://github.com/techrote/cybersand/actions/runs/40075047985) |
| #238 verifier contracts | [40075047951](https://github.com/techrote/cybersand/actions/runs/40075047951) |

Original failures and cancellations remain separate evidence. In particular,
#221's first Windows course case stalled at 180.002 seconds; one unchanged actual
Windows retry passed the case in 3.646 seconds with 1,475 assertions and zero
failures. Its cause remains unknown. #238's first Native job reached the
45-minute whole-job cap after all three 93-test suites passed; that cancellation
is not counted as PASS. Its one unchanged actual retry passed every step in
43m41s, 08:27:10–09:10:51 UTC. Disabled optional-lane cancellation recovery and
jobless duplicate cancellations are distinguished from actual source execution.
No source, runtime, command or watchdog change produced those retry results.

## Third reconciliation and preservation

The third reconciliation imports new main into #208 and propagates merge ancestry
through #211, #221, #235 and #238. It preserves the previous heads above as
ancestors, along with the original MAT stack and earlier reconciliation records.
Claude's separate source branches and unrelated primary-checkout work are not
edited by this task.

The new baseline has **673 protected main blobs** across Native, Godot,
dependencies, CI/checker/LCB/documentation tools and the core build/current-gate
files. Those upstream bytes are imported unchanged. All **56 recorded native
runtime-input identities** are unchanged between `1e032e4` and `a395e33`.
The source-matched publications therefore remain Windows native SHA-256
`b13805bf1a0bb3452493c6990b212575787f638c30be22613a5cc03b78933d30`
and Linux native SHA-256
`2495cedc12de07be3738a76b41ea352e5dff8309d167ea89f7fc430ae89765cf`.
Godot remains `4.7.stable.official.5b4e0cb0f`; the toolchain, dependency pins and
runtime provenance records are unchanged.

MAT historical audit/experiment bytes, registrations, controls, sealed archives,
v4 registration and its nine revised readers remain unchanged. The updated #200
foundation audit is the explicit upstream evidence import, not a rewrite of MAT
history. Retrieval question objects and the frozen question file are unchanged
by this third reconciliation.

The [previous integration checkpoint](2026-10-24-mat003-lcb001-integration-checkpoint.md)
continues to own the registered historical-checkout boundaries: S1 at
`dc2b610ef563bd395104d154302f0a97417957d8`, S2F at
`c160b4509857370f8065f7d64a9cb1c9d2847260`, and continuation/S2P/C128 at
`7dd1373d999d91e52e6f29e9c9832f106a77da14`. Their fresh regressions preserve
the recorded apparatus and historical World. They do not qualify MAT candidates
against the policy-enabled current World. No registration hash or historical
producer is changed to make a new checkout pass.

## Fresh checks remain pending

Every new head requires fresh Documentation/materialized provenance, Native,
GDExtension/Godot and applicable scoped checks. New #240 tests imply an expected
Native count of **94 per mode**, and an expected Godot inventory of **139 total /
127 Windows-applicable cases**. These are source-derived expectations, not actual
execution results or a claim of PASS. The prior run counts remain 93 per Native
mode and 138 total / 126 Windows-applicable Godot cases.

Final exact head/base pairs, synthetic merge parents/tree equality, run IDs,
decoded logs, versions, command limits and any failures belong in the PR reports
after these new checks finish. The record separates GitHub-reported execution
from independent log/artifact/hash inspection. Native benchmark smoke remains
characterization; the epoch model remains a contract model. Neither establishes
scientific or performance acceptance. No paired MAT timing campaign is admitted.

No PR is merged or issue closed by this reconciliation. #204 and independent
scientific acceptance remain open; the archived author-evidence packet gains no
new acceptance status. #213's closed final Gates A–E PASS and its landed evidence
remain valid. The defaults-only #200 foundation gains regression coverage, not
new solver authority: all 90 candidate arms remain blocked, #212 remains held,
and pressure/inertial ports, changed defaults, schema/ABI freeze and Rapier
integration remain outside scope.
