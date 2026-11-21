# SWARM-004/005 admission control and evidence

This separate branch holds the reviewed bounded CI dispatch control and additive review/evidence checkpoints for [integration PR715](https://github.com/techrote/cybersand/pull/715). It is not intended to merge into main. The production integration does not import this control or these generated audit payloads.

The control permits exactly five existing workflow-dispatch endpoints only after verifying successful source-matched qualification, successful eight-path runtime publication, exact artifact/Git/LFS bytes, fixed workflow definitions and live PR/head/base leases. It cannot alter readiness, merge state, source branches or SWARM-006. No execution request is present at this checkpoint. The example contains deliberately invalid placeholders.

## Current source checkpoint

- Source freeze: `79b8a0a4a1c2ace435d709b35114ee7065c935e6`.
- Request-only execution: `96b8d3fb9d5a2e9f580d4b33293b1ab725269d4f`.
- Accepted main: `846fe0533b3170e7b01f690518da49fc40cc24d1`.
- Native definition: `217bfa716e61198f5b3849f2ae14c30e85bc9f623fc1d05438c59df2296ce7f7`.
- [R3 bounded qualification](https://github.com/techrote/cybersand/actions/runs/44953582341), attempt 1, is running at this checkpoint. No runtime publication or merge acceptance is claimed.

The [r3 manifest](frozen-source-provenance-r3.json) maps every changed source path to all five frozen donors and records 1,763 build, 147 native, 106 extension and 43 definition input identities. All 81 existing accepted-main native source/header files remain unchanged. The r3 delta contains only the reviewed historical-inspection and canonical-archive repairs, focused tests and the integration runbook. The independent [committed-source review](swarm45-r3-committed-source-review.md) confirms those exact bytes and closes the historical-inspection P2. Its [detailed review](swarm45-historical-inspection-fix-review.md) records 259 independently executed assertions and the engineer's 408-assertion evidence with explicit local/headless limits.

[Archive repair review](swarm45-package-archive-review-003.md) preserves every sidecar, authored setting, binary byte and strict custody gate. The [control-anchor review](swarm45-r3-control-anchor-and-runbook-review.md) confirms that immutable `10fe808...` remains the correct reviewed control anchor: descendants must still qualify their exact new source and runtime bytes. The control branch's code baseline is not represented as the new product candidate.

## Retained failures and scientific evidence

R2 run44950154534 completed in 29m05s. Linux and actual Windows source native, graphical and all 17 accepted-main smoke cases passed. The extracted package graphical aggregate passed with the unchanged 60-second startup bound, but its later smoke admission failed when Windows Git archive CRLF metadata was rewritten by Godot. Publication was correctly skipped. The [complete observation](swarm45-r2-ci-observation.json), [causality evidence](swarm45-import-line-ending-diagnosis/comparison.json) and original r1 failure/startup diagnosis remain retained. Later repair does not convert either aggregate into PASS.

The [hosted r2 scientific/native review](swarm45-science-evidence/swarm45-hosted-r2-scientific-native-review.md) independently verified all 360 hosted outputs against the earlier audited integration candidates, all 720 raw/gzip hashes, immutable input ledgers and native execution custody. The primary OFF/OFF and BOTH arms retain 1 Complete / 14 Blocked / 21 Exhausted and no new Apply success or net joint gain. Unknown closure remains explicit. These are already revealed controls, not new unseen qualification.

The complete 720-output local paired known-replay archive is retained separately, SHA256 `e8820a0b30036aee4fd0be71537400db55bdacc1f1c6d5eab20d37741ab6956f`. The initial archive, r1/r2 manifests and reviews remain unchanged. Original donor branches, registrations, immutable corpora, negative results and SWARM-006 fixtures are preserved.

## Remaining admission

Review scopes distinguish source-only/local diagnostics, hosted qualification, runtime publication, final resulting-source gates and physical owner acceptance. Draft/HOLD remains until every mandatory gate passes. Physical NVIDIA/original 2048×2048 saved-map owner evaluation of the reconstructed package is still required. Earlier donor owner evaluation is not new-package acceptance. This branch cannot satisfy or waive that gate.
