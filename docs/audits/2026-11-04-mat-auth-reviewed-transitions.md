---
title: MAT-AUTH reviewed per-file compatibility transitions
status: Current
document-kind: evidence
scope: Owner decision, rules and adverse-control evidence for code-pinned reviewed per-file transitions in the MAT-AUTH legacy compatibility guard; the production table is empty, the lock and baseline are unchanged, and no consumer source changes
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [../operations/material-catalogue-shadow.md, ../architecture/material-authoring-catalogue-plan.md, 2026-11-04-mat-auth-353a-compatibility.md, 2026-11-04-lcb201-p1-wake-summaries.md]
---

# MAT-AUTH reviewed per-file transitions — 4 November 2026

## Decision

`tools/material_catalogue/compatibility.py` froze 27 legacy consumers at
baseline `0fd4af5987e77db4da3e37c757cf2c0917ae9e15` and required "a separately
reviewed baseline or cutover transition" for any change, but defined no form for
one. [PR #382](https://github.com/techrote/cybersand/pull/382) (#201 P1) was the
first behaviour-preserving edit to reach that wall, in `native/src/world_pressure.inc`.
Its [equivalence evidence](https://github.com/techrote/cybersand/pull/382#issuecomment-6641279608)
and the [proposed mechanism](https://github.com/techrote/cybersand/issues/353#issuecomment-6641280156)
were posted for the #353 owner.

**Owner approval.** After the mechanism and its alternatives (a wholesale
baseline advance, or waiting for the catalogue cutover) were explained in the
#201 working session, the owner replied: "Ok great get it done now." This
record implements that decision as its own PR, before #382 adds its entry.

## Mechanism

The [shadow guide](../operations/material-catalogue-shadow.md#reviewed-per-file-transitions)
owns the rules. In summary:

- `REVIEWED_TRANSITIONS` is a code-pinned tuple, empty on this change. The lock
  file, `BASELINE`, both digests and the fallback facts are byte-identical.
- Each entry moves one protected, non-identity path from its currently admitted
  LF hash to the bytes of that path at a reviewed commit. Steps for one path
  chain in order.
- The commit must descend from the baseline (or the previous step) and stay
  reachable from `HEAD`, so a squash merge fails closed.
- A committed `docs/audits/*.md` record must name the path, both hashes and the
  commit.
- Identity inputs are refused: `material.hpp`, `interaction_rules.hpp`, the
  capability matrix, `cell_world.gd`, `interaction_policy.gd` and
  `material_appearance_lut.gd`. Changing them remains a cutover.
- `check()` adds `reviewed_transitions` to its result; downstream receipts that
  embed the result carry it. No consumer requires an exact key set.

Two refinements over the posted proposal: steps for one path chain (a later
reviewed edit, for example #201 P2, adds a step whose `from` is the previous
`to`) instead of "at most one per path", and identity inputs are excluded
outright. Both narrow or preserve what the guard accepts.

## Tests

[`test_compatibility.py`](../../tools/material_catalogue/test_compatibility.py)
keeps the 22 existing controls. Its existing fixture now applies any production
transition's target bytes, so a later entry does not invalidate them. A new
`ReviewedTransitionGuards` class (16 tests) builds real commits in a shared clone
of the repository:

- two chained reviewed steps for `world_pressure.inc`;
- a commit unreachable from `HEAD` (squash-like);
- a commit whose parent precedes the baseline;
- a `HEAD` that commits the record and an unrelated record.

Positive controls: the exact target is admitted, with CRLF normalization and an
ordered two-step chain; the lock bytes and both digests are unchanged. Adverse
controls, each of which must fail:

- the old bytes once a transition exists, and any edit beyond the target;
- an unreviewed edit, and a lock-only hash edit with or without a transition;
- an edit to another locked file alongside a valid transition;
- an unauthenticated target, a wrong `from`, a skipped or repeated chain step,
  and a no-op;
- an unretained commit, and a commit that does not descend from the baseline or
  the previous step;
- an unknown path, a non-string path and all six identity inputs;
- a missing record, a record that does not name the facts, and a record outside
  `docs/audits/`, with `..`, or not Markdown;
- extra, missing or wrongly typed fields: boolean `pr`, zero `issue`, short or
  uppercase commit IDs, uppercase hashes and a non-sequence table.

**Mutation check.** Each of eight guard rules was disabled in turn in memory
(HEAD ancestry, baseline descent, record facts, identity exclusion, target
authentication, transition targets, `from` check, and baseline-only comparison).
The corresponding test failed every time; two unmutated controls passed.

## Validation

Local, Windows 11, Python 3.13.16, Git 2.55.0, from main
`751edc0b495dc85484ad5509a7c95f863651c76b`:

| Command | Result |
|---|---|
| `python -m unittest test_compatibility` (in `tools/material_catalogue`) | 38 tests OK, 69 s |
| scratch mutation harness, 8 mutations + 2 controls | 8 caught, controls pass |
| `python tools/material_catalogue/compatibility.py --check` | PASS, `reviewed_transitions: []` |
| `python -m unittest discover -s tools/material_catalogue -p 'test_*.py'` | 115 run; the same 24 Windows-only failures as unchanged main tools (99 run): symlink/hard-link privilege (`WinError 1314`) and no local C++ compiler. None is in `test_compatibility.py`; hosted Linux runs the full suite |
| `python tools/material_catalogue/compiler.py --check` | PASS |
| `check_docs.py`, `check_repository.py`, `check_m11_consistency.py` | PASS |
| `tools/docs/retrieval_eval.py` | 32 questions, MRR@k 0.7536 (unchanged) |

The hosted Documentation/provenance result at the exact PR head is recorded on
the PR. The mutation harness is a scratch script and is not committed.

## Limits and follow-ups

- This change admits nothing by itself. #382 adds its own entry and record, with
  `source_commit` set to its reviewed P1 commit.
- Draft #384 (#353-B) also edits `check()` and its result. The overlap is
  textual; whichever merges second resolves it.
- #354 (`world.cpp`) and #386 may use the same mechanism only for
  behaviour-preserving, non-identity edits, each with its own review.
- The guard cannot prove behavioural equivalence. Each entry relies on the review
  its record cites.
