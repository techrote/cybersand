# Independent SWARM45 control pin and committed-source verification

**Verdict: GO to publish the reviewed control-branch source. Do not submit a dispatch request until successful runtime qualification and publication satisfy the unchanged bridge guards. This is not hosted admission, owner acceptance or merge GO.**

Reviewer: `/root/swarm45_publication_review`. This follow-up made no source changes or remote actions.

The control script differs from the previously reviewed checkpoint in exactly two assignments:

- `CONTROL_BASE`: `9b688aed1f06f031f983c27f50d1f17821446e43` → `10fe808ac7f6a4b9c07f7d168763b41957359e57`.
- `ACCEPTED_MAIN`: `0f0161af337d6d0cee8fa961a9667aff570a75b0` → `846fe0533b3170e7b01f690518da49fc40cc24d1`.

Reversing only those two assignments in memory exactly reproduces the prior reviewed script SHA-256. The control workflow, tests and example request are byte-identical to their reviewed versions. The fixed five-workflow dispatch surface and permission/lease/publication safeguards are unchanged. The independent control suite passes **12/12 tests**.

The candidate's reviewed delta files match both committed identities:

| Identity | Verified value |
|---|---|
| Frozen source | `96cc2772b0b7cf8e273526d3efd081596be1ad85` |
| Frozen tree | `550224ac8447ac2c6748dab840da974ed9d13c57` |
| Qualification execution | `10fe808ac7f6a4b9c07f7d168763b41957359e57` |
| Execution tree | `1259e2a16cd0e598fe0f758eff72fd88891ab98a` |
| Native definition | `217bfa716e61198f5b3849f2ae14c30e85bc9f623fc1d05438c59df2296ce7f7` |

The execution commit has the frozen commit as its sole parent and changes only `.github/swarm45-mainline-request.json`. Accepted main `846fe053…`, prior execution `9b688aed…` and frozen donor `580ff82…` are all ancestors of the new freeze. All five dispatched workflow blobs and the publisher workflow are identical between freeze and execution.

I independently checked **1,763 distinct source-ledger paths** by reading actual Git blobs at both commits through the control helper's canonical input verifier. Both ledgers match the clean source inventory exactly. No source-equivalence exception or ignored generated UID was used.

Full evidence, exact control-file hashes and the test-log hash are in `swarm45-publication-review-evidence/delta-002-committed-and-control-pin-checkpoint.json`, SHA-256:

`9837fa7244e025bac84c7fd243769f24534971d61ff1e0e06f17138fe12fd690`

The prerequisite pin-only condition in review 002 is now satisfied. Runtime qualification/publication and final workflow outcomes remain to be established separately on their actual source identities.
