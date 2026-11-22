# Independent focused-driver review

Reviewer: renderer/platform specialist, who did not implement the reviewed
measurement driver or causal observer. This is a source and validator review,
not a new gameplay or graphical qualification.

## Finding and repair

The focused driver at integration commit
`0fc3adc48b7e25c39a2211989169c1e43d46639f` omitted the predecessor's explicit
request-to-receipt checks for fixture, renderer, Water variant and input mode.
It also omitted complete-arm and cross-arm hardware/workload matching.

An untouched, genuinely executed original `wave_512_follow` receipt passed the
complete frozen v3 reduction, including 144 actual Rapier completions. Its
receipt also satisfied the exact AST expression used by the new driver when
the requested case was changed to `wave_2048_follow`. Both workloads had the
same camera, worker count, Water family and Water profile; the missing fixture
comparison was material. This was a qualification-integrity blocker, not a
defect in native simulation or evidence that a wrong workload had actually
been published as a successful 2048 result.

Science commit `c4a6c59a1e427bf4b4b2ee569a0e1fced4ea5327` restored the exact
requested fixture and apparatus checks, complete ordered-arm count and the
full predecessor `statistics.match` equality. Independent delta review reused
the same original receipt: its correct 512 request passed, the 2048 request
failed, and 25 further apparatus, hardware, missing-arm and reordered-arm
substitutions failed. The 14 causal/driver unit tests also passed.

| Reviewed version | `run_focus.py` SHA-256 | Disposition |
| --- | --- | --- |
| `0fc3adc48b7e25c39a2211989169c1e43d46639f` | `de716f3cb40a06bf175e09cd9635ce5db8981c7a2642eac4a47a89561d0179af` | FAIL: requested workload not fully bound |
| `c4a6c59a1e427bf4b4b2ee569a0e1fced4ea5327` | `a920faee85e29d6e914e4170c7c8c9d91a0ac5d5179c12fa4c212732646eb0df` | PASS for the confirmed defect and its repair |

The old negative and repaired positive records are retained separately. No
original receipt, trace, manifest, timestamp or frozen validation policy was
modified. The scripts are retained exactly as run, including their scratch
recovery paths; those paths identify the original extraction rather than
shipping a new copy of the large archive.

## Original evidence custody

Original archive:
`pubpres-playability-linux-wave_512_follow-same-frame-44963596029-1`.
Member: `same-frame-abba/wave_512_follow/0-C/receipt.json`.

- Receipt SHA-256:
  `71c2f9979aa6c6afbf287f25befae4f7da66fc1c1344611d209be86be791f56d`.
- Original `receipt-events.jsonl` SHA-256:
  `c2005e013fb5264dfa817fc27850e9a131aac05fe5e27c1b12ed16b5c940ca7b`.
- Original raw receipt and trace remain in the original recovered archive.
- Exact local extraction paths and checked source identities are recorded in
  the two JSON files beside this report.

To repeat in the recorded recovery environment, run the corresponding Python
script. For another environment, materialize the same archive member, its
event trace, `arm.json`, `analysis.json` and the archive's `campaign.json`, and
adjust only the `ROOT` and `EVIDENCE`/`BASE` input-path constants. The negative
script must use the reviewed old driver checkout; the positive script must
use the repaired driver checkout. Output is a new review record, not a
replacement of the original archive.

## Other reviewed boundaries

- The causal GDScript diff is additive to the frozen v3 observer. It retains
  the existing primary event contract and writes prospective Main/worker
  events into a separate bounded, hashed sidecar.
- The causal reducer obtains completed-step credit from separately validated
  `rapier_step` events. Transaction entry is not completion credit. Tests
  reject reused entry credit and mismatched owner, sample, terrain and
  callback identities.
- `execute()` retains the predecessor's owned-process timeout, child cleanup,
  display-owner checks and strict script/load/GL initialization failures.
- Missing causal producer observations remain explicit unavailable joins;
  they are not treated as zero latency. The sidecar cannot independently
  qualify a capture without the original v3 reducer.
- The repaired committed-driver closure refuses changed or untracked
  measurement inputs and remains distinct from the tested application's
  source/native identities.

No additional blocker was confirmed in these reviewed boundaries. This does
not approve unexecuted graphical arms, final performance claims, Windows
packaging, or future changes to the reviewed source. Final source and runtime
qualification remain separate gates.
