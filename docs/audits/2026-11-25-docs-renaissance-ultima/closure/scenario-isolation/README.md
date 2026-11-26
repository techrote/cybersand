---
title: ULTIMA scenario profile isolation correction
status: Historical
document-kind: evidence
authority: historical-non-authoritative
retrieval: explicit-history-only
scope: Actual failed aggregate and focused runner repair; no Art product or assertion change
canonical-for: []
last-reviewed: 2026-11-26
related-documents: [../README.md]
---

# Scenario profile isolation

The [failed original campaign](../fe24-linux-failure.json) passed all seven
storage matrices, then failed Art session logging because earlier independent
fixtures intentionally retained audit files in the same disposable user profile.
The session fixture explicitly requires an isolated profile and expects only its
own legacy file before the first event. Both extra files predate its startup.
No assertion or application writer was changed to remove this failure.

The runner now isolates unrelated normal workflows through XDG data/config,
APPDATA and LOCALAPPDATA. Each explicit save/reopen pair retains the same named
scenario profile, preserving the intended fresh-process reload evidence.
[Actual four-case execution](report.json) uses the changed driver recorded by
SHA-256 against the unchanged fe24 application: Art panel12 checks, Art session35,
Paint author1884 and reopen1920, all natural exit zero without engine errors.
The two Art profiles differ; the Paint pair shares its isolated profile.

This focused correction is not a complete resulting-source campaign. The next
published source must execute all29 normal records and all seven storage matrices
on Linux and Windows before evaluator admission.
