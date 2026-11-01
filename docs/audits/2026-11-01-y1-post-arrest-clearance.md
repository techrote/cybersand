---
title: Y1 post-arrest accounting and finite clearance observation
status: Current
document-kind: audit
scope: Copied bridge accounting followed by separately registered 1800-sample B0/Y1 observation; no response changes or production selection
last-reviewed: 2026-11-01
related-documents: [../operations/granular-bearing-post-arrest-handoff-proposal.md, 2026-11-01-granular-bearing-candidate-discrimination.md]
---

# Y1 post-arrest accounting and finite clearance observation

## Frozen intake

The isolated branch `codex/y1-post-arrest-clearance-20261101` starts at exact
reviewed PR #341 head `064a3306dc3a87c3a88172003e42c8e426cb73e1`, tree
`0e695747de2a73f319584b25ee1aa0c4031d4672`. Its executed candidate source remains
`39d91671c1d0bb7978a29460f14419cd1b37a252`. Observed remote main
`25ce0731d89b9540c2d95cfa8bae321c37e6e118` is metadata only. No main or concurrent
source is consumed. The root `C:/khybersand` material branch and its dirty work
are preserved. Work occurs in
`C:/Users/_/.codex/worktrees/y1-post-arrest-clearance/khybersand`.

The historical handover's `C:/kybersand/source` path is superseded for this task
by the inspected source root/worktree; it is not a checkout instruction.
Godot4.7, Rapier0.35.2 with retained x86_64 backport, godot-cpp101ae380 and
LLVM-MinGW20260826 pins remain unchanged. LFS payloads are materialized.
The published native payload is not the diagnostic runtime.

## Stage A: copied-value oracle

The [machine receipt](y1-post-arrest-2026-11-01/stage-a.json) retains42 samples:
300..321 and580..599, including21 consecutive pairs. Source trajectory and
acquisition receipt SHA-256 bind them to PR #341. The
[oracle](../../tools/experiments/post_arrest_accounting.py) imports no simulation
API, reads copied values only and changes no live response.

All application, correction, age scaling, impulse and next-pre-Rapier boundaries
close **exactly** with literal float32 storage/addition: maximum residual0.
Ignoring float32 position rounding gives maximum7.323920726776123e-6px,
below the existing2e-5 API accounting tolerance. No tolerance is enlarged.
The frame599 successor is unavailable in the retained record and explicitly
null; frame598-to599 closes. Rapier transitions are observed, without inferring
unavailable forces or implementing a second integrator.

Incoming vy alternates0.006344288121908903 and1.52896249294281px/s.
The first phase has no correction and the impulse cancels incoming vy to0.
The second applies requested upward correction-0.015831299126148224px;
the opposing incoming component is zeroed before impulse-1.52896249294281
produces outgoing vy-1.52896249294281. Age0 gives scale1 throughout.
Both retained windows reproduce this pair without hard-coded expected velocities.
This explains the bridge handoff; it neither proves a defect nor eventual clearance.

Command: `python tools/experiments/post_arrest_accounting.py --output
docs/audits/y1-post-arrest-2026-11-01/stage-a.json` on Windows/Python3.13,
followed by `python -m unittest discover -s tools/experiments -p
test_post_arrest_accounting.py`. Six regressions include altered impulse,
missing zeroing, wrong sample boundary, explicit missing observation and input
immutability. Stage B is not executed at this checkpoint.

## Documentation change map

This is copied diagnostic accounting only. Native ownership/lifetimes,
interfaces, capacities, response laws, ADR007/009, user controls and dependency
pins are unchanged. The canonical post-arrest proposal routes to this receipt;
the final observation checkpoint will synchronize the roadmap, retrieval and
validation routes. Historical PR #341 evidence remains intact.

Stage-A checks: six Python regressions pass; M11 integrity and retrieval execution
pass. Documentation retains the six frozen companion-reference findings;
repository qualification additionally retains12 published-runtime source-rebuild
findings, matching the parent. No published runtime hash is rewritten.
