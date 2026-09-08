## Scope

Describe the concrete behavior change and affected canonical subsystem/ADR.

## Validation and documentation

- [ ] Relevant regression checks and exact tested source/artifact/platform identities are recorded.
- [ ] [Documentation-update checklist](../AGENTS.md#documentation-obligations) completed, including the affected-document matrix, status/platform qualifiers, corpus routes and retrieval questions.
- [ ] `tools/ci/check_docs.py`, retrieval evaluation and `git diff --check` results attached.
- [ ] `tools/ci/check_m11_consistency.py` result attached; historical hash failures remain explicit and historical records unchanged.
- [ ] Current behavior is distinguished from Approved/Planned/Deferred/Rejected requirements and level saves from exact replay.
- [ ] Actual local-delta/checkpoint coverage is recorded; no generated output, secrets or unpinned dependencies are included.

## Remaining gaps

Name failed, skipped, unavailable or manual checks and unresolved decisions.
