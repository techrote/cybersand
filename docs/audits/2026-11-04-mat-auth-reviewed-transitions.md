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
  reachable from `HEAD`. A squash or rebase merge of a PR that adds an entry
  therefore fails closed, on main and on every PR's merge ref, until a reviewed
  follow-up repoints the entry.
- A Markdown record under `docs/audits/`, committed at `HEAD`, must name the
  path, both hashes and the commit.
- Twelve identity inputs are refused: the six files the lock derives its digests
  and fallback facts from (`material.hpp`, `interaction_rules.hpp`, the
  capability matrix, `cell_world.gd`, `interaction_policy.gd`,
  `material_appearance_lut.gd`), the policy identity generators and contract
  (`liquid_policy_catalogue.hpp`, `policy_contract.py`,
  `native_policy_artifacts.py`) and the three retained oracle vectors. Changing
  any of them remains a cutover or identity transition.
- Git runs without location variables (`GIT_DIR`, `GIT_INDEX_FILE` and similar),
  so a hook or `git rebase -x` cannot redirect authentication.
- `check()` adds `reviewed_transitions` to its result. Consumers that compare
  whole results (`check_gdscript_shadow.py`, the liveness reducer) do so within
  one run, so the added key is harmless there.

Compared with the posted proposal, chaining widens "at most one transition per
path" to an ordered chain in which every step needs its own reviewed entry and
record. Refusing identity inputs narrows it, and the list was widened from six to
twelve files after the independent review.

## Independent review

A separate read-only reviewer examined the guard and #382's first entry. It
found no bypass that does not edit `compatibility.py` itself, and independently
confirmed #382's hashes, ancestry and two-function scope. Findings and their
disposition:

| Finding | Disposition |
|---|---|
| Squash or rebase merges are allowed on main and would break the guard for every PR | Error message and guide now name both and give the recovery. Merge method for entry-adding PRs is an owner/merger obligation; the repository setting is unchanged |
| Draft #384 freezes every `native/` and `godot/` executable source at main `751edc0b` and changes the result schema | Behavioural, not only textual; see Limits |
| Inherited `GIT_DIR` could make the test fixture move the developer's real HEAD | Fixed: guard and fixture remove Git location variables; regression added |
| Record-fact checks were weakly tested | Fixed: one record per omitted fact, and a CRLF blob fixture |
| Policy identity generators and oracle vectors could move with one entry | Fixed: added to the identity inputs; a regression derives the lock's identity reads |
| `merge-base` errors were reported as "does not descend" | Fixed: unresolvable history now fails with Git's error |

The reviewer's "record only at the source commit" mutant is equivalent: a record
inside a commit cannot name that commit's own ID, so it can never pass the fact
check.

## Tests

[`test_compatibility.py`](../../tools/material_catalogue/test_compatibility.py)
keeps the 22 existing controls. Its existing fixture applies any production
transition's target bytes, so a later entry does not invalidate them. A new
`ReviewedTransitionGuards` class (19 tests) builds real commits in a shared clone
of the repository:

- two chained reviewed steps for `world_pressure.inc`, and a step whose blob has
  CRLF line endings;
- a commit unreachable from `HEAD` (squash-like);
- a commit whose parent precedes the baseline;
- a merge `HEAD` committing a complete record, four records that each omit one
  fact, and an unrelated record.

Positive controls: the exact target is admitted, with CRLF working bytes, a CRLF
blob at the source commit and an ordered two-step chain; the lock bytes are
unchanged; and decoy `GIT_DIR`, `GIT_INDEX_FILE` and `GIT_OBJECT_DIRECTORY`
values cannot redirect authentication. Adverse controls, each of which must fail:

- the old bytes once a transition exists, and any edit beyond the target;
- an unreviewed edit, and a lock-only hash edit with or without a transition;
- an edit to another locked file alongside a valid transition;
- an unauthenticated target, a wrong `from`, a skipped or repeated chain step,
  and a no-op;
- an unretained commit, and a commit that does not descend from the baseline or
  the previous step;
- an unknown path, a non-string path and all twelve identity inputs;
- a missing record, an unrelated record, each single omitted fact, and a record
  outside `docs/audits/`, with `..`, or not Markdown;
- extra, missing or wrongly typed fields: boolean `pr`, zero `issue`, short or
  uppercase commit IDs, uppercase hashes and a non-sequence table.

A further test derives the files `build_lock` reads beyond hashing them and
requires each to be an identity input.

**Mutation check.** Thirteen in-memory mutants each disabled or weakened one rule:

- HEAD ancestry, baseline descent and the `from` check;
- the record-fact check, removed or reduced to the path only or the commit only;
- the identity exclusion, removed or with one generator dropped;
- target authentication, removed or hashing the raw blob without LF
  normalization;
- transition targets, and a baseline-only comparison;
- Git environment scrubbing.

The targeted test failed for every mutant; the unmutated control passed.

## Validation

Local, Windows 11, Python 3.13.16, Git 2.55.0, from main
`751edc0b495dc85484ad5509a7c95f863651c76b`:

| Command | Result |
|---|---|
| `python -m unittest test_compatibility` (in `tools/material_catalogue`) | 41 tests OK, 84 s |
| scratch mutation harness, 13 mutants + control | 13 caught, control passes |
| `python tools/material_catalogue/compatibility.py --check` | PASS, `reviewed_transitions: []` |
| `python -m unittest discover -s tools/material_catalogue -p 'test_*.py'` | 118 run; the same 24 Windows-only failures as unchanged main tools (99 run): symlink/hard-link privilege (`WinError 1314`) and no local C++ compiler. None is a `test_compatibility.py` test; hosted Linux runs the full suite |
| `python tools/material_catalogue/compiler.py --check` | PASS |
| `check_docs.py`, `check_repository.py`, `check_m11_consistency.py` | PASS |
| `tools/docs/retrieval_eval.py` | 32 questions, MRR@k 0.7536 (unchanged) |

Hosted run 41919483095 at the first head (`b6d50a36`) reported the full
material-catalogue suite passing on Linux. The exact-head hosted result for the
final head is recorded on the PR. The mutation harness is a scratch script and is
not committed.

## Limits and follow-ups

- This change admits nothing by itself. #382 adds its own entry and record, with
  `source_commit` set to its reviewed P1 commit, and must merge with a merge
  commit.
- **Draft #384 (#353-B) interacts behaviourally.** At its head `3d537d1a`, its
  `display_contract` requires every `native/` and `godot/` executable source to
  equal main `751edc0b` and the file inventory to match. If #384 lands first,
  #382 fails on its unprotected pressure files whatever `REVIEWED_TRANSITIONS`
  says. Its version-2 result also drops the top-level `production_cutover` that
  `tools/material_liveness/reduce.py` requires. Before #384 merges it should
  re-pin after #382 or exempt protected paths and admitted targets, and carry
  `reviewed_transitions` into its result.
- #354 (`world.cpp`) and #386 may use the same mechanism only for
  behaviour-preserving, non-identity edits, each with its own review.
- The guard cannot prove behavioural equivalence. Each entry relies on the review
  its record cites.
