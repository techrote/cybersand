# Independent r3 control-anchor and runbook review

**Verdict: retain `10fe808ac7f6a4b9c07f7d168763b41957359e57` as the immutable reviewed control anchor. Repinning the bridge or merging r3 into its control branch is unnecessary for the described r3 delta. The narrow integration-runbook update is GO.**

This is a source/design decision, not approval to dispatch before runtime publication or a hosted/merge GO. The previous four-file archive repair review remains valid. Historical-inspection implementation correctness remains subject to its separate native/protocol review.

## Verified control identity and semantics

I confirmed the live control branch is at `bb045b5c0463f34e4e468fe27f0692cd29ea1607` and checked the actual Git commit: its sole parent is `10fe808ac7f6a4b9c07f7d168763b41957359e57`. The three committed control implementation/workflow/test files exactly match their previously reviewed SHA-256 values. Their pins remain `CONTROL_BASE=10fe808…` and `ACCEPTED_MAIN=846fe053…`.

`source_chain()` deliberately requires `CONTROL_BASE` and accepted main to be ancestors of the actual qualification source. It does not require qualification-source equality with the anchor. The anchor serves two purposes: retained reviewed ancestry and immutable byte comparison for the five final-admission workflows plus the publisher workflow.

The actual qualification source is supplied separately in the strict request and must match the completed successful qualifier run and attempt. Its path to publication must contain only explicit publication-request commits followed by exactly eight runtime/provenance paths. The immutable qualified artifact, original build/source records, published Git/LFS payloads and complete source ledgers are checked against that new source. Live PR715, integration, accepted-main and control-branch leases are rechecked before dispatch. Thus retaining the earlier anchor does not reuse the r2 executable, receipts or acceptance for r3.

I verified the current r3 working tree leaves all five fixed workflow files and the publisher workflow byte-identical to `10fe808…`. The reviewed archive repair and historical-inspection changes do not require a different anchor. If those workflow definitions or accepted main change later, the existing guards will fail closed and a new review would be required.

## Runbook delta

The reviewed file is `docs/operations/swarm45-mainline-integration.md`, SHA-256:

`d84f6d187a80612ba9ede07be9bff47b4dc4d7783b8dcf9b5f5ed24c6df58cc5`.

Its 19-line addition accurately records the recognized matching historical definition pairs, the SWARM004-only missing-option=false compatibility, immutable historical `can_apply` evidence versus separate read-only transaction authority, successful fresh current-source generation as the route back to live authority, and the canonical archive producer's child-only Git defaults with preserved attributes and mandatory integrity checks. The named definitions match the current protocol constants. The prose does not claim historical evidence can authorize Apply or that existing receipts are rewritten.

The document also keeps package hashes and source-clean checks mandatory; it does not describe import metadata omission or a post-hash rewrite as the repair. Actual hosted outcomes and final historical-inspection behavior remain independently gated.

## Evidence and limits

The machine-readable receipt records the live control identity, exact committed control hashes, all six anchor workflow hashes, document hash and conditions:

`swarm45-publication-review-evidence/r3-control-anchor-and-runbook-review.json`

SHA-256: `30730b3f0633cc978fd932424b9f1531b788a21c89f4f216fba534465021ea1b`.

No source, branch, PR or workflow was changed by this review. No expensive tests were repeated for unchanged bridge bytes; the prior independent 12/12 control-test result remains attached to those exact bytes. The forthcoming committed r3 source, actual qualification/publication evidence, final workflow results and physical-owner acceptance require their own verification.
