# CI-OPT-003 routine CI accelerator — engineering evidence

This evidence branch records source-bound engineering work for
[programme #706](https://github.com/techrote/cybersand/issues/706). It is not an
implementation branch or a request to merge evidence into production. Original
hosted logs remain in the linked GitHub Actions artifacts; their digests and
strict readbacks are retained here. Synthetic failure controls are explicitly
separate from executed scientific qualification.

## Checkpoint at 23:30 UTC, 21 November 2026

No improvement has been merged yet. Accepted main remains
`846fe0533b3170e7b01f690518da49fc40cc24d1`.

| Candidate | Exact source | Disposition |
| --- | --- | --- |
| [#721 — compiler-tail ordering](https://github.com/techrote/cybersand/pull/721) | `506dfc8c343c5d24fe26e89a9542cf985c52853e` | Full applicable hosted CI passed; performance HOLD pending the controlled sanitizer pair |
| [#722 — soliding compilation reuse](https://github.com/techrote/cybersand/pull/722) | `cd32ed95b1c3da1d5e8bbecc8020f68e13fe1d55` | Independent source GO; full CI and sanitizer pair running |
| [#723 — showcase concurrency](https://github.com/techrote/cybersand/pull/723) | `28ec075afab840cf6fbb35190a7b1915808904f3` | Draft/HOLD: independently reproduced P2 loss of a hung peer's buffered diagnostics; repair in progress |

The #721 cohort completed in 29m59s and used 292.2833 unweighted runner-minutes.
Different hosts and an extra historical source-guard job prevent treating its
difference from the older 30m37s cohort as a causal speedup.

The independently admitted same-worker normal-worldgen pair measured
235.386537s to 228.906391s: 6.480146s saved. The independently admitted complete
normal-soliding family pair measured 190.811701s to 108.006146s: 82.805556s saved.
These are individual paired observations, not percentiles or population claims.
Soliding retains all eight executables plus its normal benchmark/apparatus/cost
commands. Worldgen remains the current routine-CI critical path.

## Qualification sources

- [#721 Native](https://github.com/techrote/cybersand/actions/runs/44959001079)
  and [Linux/Windows integration](https://github.com/techrote/cybersand/actions/runs/44959001009).
- [#721 controlled worldgen proof](https://github.com/techrote/cybersand/actions/runs/44959131042),
  proof commit `371b9aef07e75cf99e20417884402a22a9ad58da`.
- [#722 Native](https://github.com/techrote/cybersand/actions/runs/44960371733)
  and [Linux/Windows integration](https://github.com/techrote/cybersand/actions/runs/44960371856).
- [#722 complete soliding proof](https://github.com/techrote/cybersand/actions/runs/44961498877),
  proof commit `fd4921ace2c4f97f06c70b887778b2366d7a9f0f`.

The first proof's original comparator had a confirmed summary/raw-inventory
binding defect. Its result is not an admission authority. The separately
reviewed `reviews/strict_worldgen_pair.py` rechecks all original raw commands,
tests, source/worker identity, policy and log hashes. Its eighteen adverse
controls passed; existing immutable artifacts are rechecked without repeating
the workload. The soliding proof uses the original production family runner and
an independently reviewed strict reader retained in its proof commit.

## Preserved obligations

The complete platform plan retains 338 Linux and 315 Windows cases in 24/23
shards, with original rendered/readback requirements. Native retains six
families, twenty outer command obligations and 192 registry cases. Machine
inventories record the original flags, tests, watchdogs, source identities and
explicit candidate deltas. No gameplay algorithms, scientific fixtures,
published runtime binaries or provenance manifests have changed.

PR #714's early provenance admission remains accepted. PRs #708 and #718 remain
untouched Draft/HOLD. No auto-merge or unrelated branch mutation is authorized by
this evidence record. The current owner mission permits manual merge of new
CI-only improvements only after their complete admission gates pass.
