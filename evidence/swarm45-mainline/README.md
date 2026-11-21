# SWARM-004/005 admission control and evidence

This separate branch holds a reviewed, bounded CI dispatch control and immutable review/evidence checkpoints for [integration PR715](https://github.com/techrote/cybersand/pull/715). It is not intended to merge into main. The production integration does not import this control or these audit payloads.

The control permits exactly five existing workflow-dispatch endpoints after verifying a successful source-matched qualification, successful eight-path runtime publication, exact artifact/Git/LFS bytes, fixed workflow definitions and live PR/head/base leases. It cannot alter readiness, merge state, source branches or SWARM-006. The example request contains deliberately invalid placeholders and is not an execution request.

Frozen r2 source:96cc2772b0b7cf8e273526d3efd081596be1ad85. Qualification execution:10fe808ac7f6a4b9c07f7d168763b41957359e57. Accepted main:846fe0533b3170e7b01f690518da49fc40cc24d1. Scoped run44950154534 attempt1 is pending at this checkpoint. No runtime publication or merge acceptance is claimed.

The source manifest maps every changed path to all five frozen donors and records1763 build-input identities. Review scopes distinguish source-only/local diagnostics from hosted qualification and physical owner acceptance. The original failed r1 is retained. The cold-start gate remains60seconds. Original donor branches, registrations, negative results and SWARM-006 fixtures remain unchanged.

The complete720-output local paired known-replay archive is retained separately, SHA256 e8820a0b30036aee4fd0be71537400db55bdacc1f1c6d5eab20d37741ab6956f. These files include its independent audit and classification, without importing the large generated corpus into the runtime branch.

Draft/HOLD remains until every mandatory gate passes. Physical NVIDIA/original2048x2048 saved-map owner evaluation of the new package is still required. Earlier donor owner evaluation is not new-package acceptance.
