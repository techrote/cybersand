# 2026-09-08 publication and validation reconciliation

This dated record supplements the preserved issue #1/#2 and M11 audits. The owner
authorized pushing/finalising completed work and resolving legacy validation.
No original audit, historical hash, tag or failure output was rewritten.

## Intake, publication and scope

- Workspace `C:/kybersand`, source `C:/kybersand/source`, separate Git roots.
  Workspace intake `6a58311982941b75f46e22109a0829e5acb83c7e` was clean.
- Source issue commits `0778845` / `061ad23` (#1), `b462e6b` (#2).
  Completed independent physics planning documentation was preserved separately
  in `a8a93da`; it implements no new physics behavior.
- `22a19357e014112b5467d539f01e7928e54a15b0` publishes the validated Windows
  DLL through LFS and its source-input provenance. DLL SHA-256
  `fda49d0acb0a4786f9aeeb6cb4289fc2fd10ac8103512cc1663f98598a49049b`,
  1,731,072 bytes. Prior issue audits identify its native/Web tools and tests.
- Pushed `codex/issues-1-2`, opened [PR #6](https://github.com/techrote/cybersand/pull/6)
  against `main` at `ad128ce33181f2db0f3714fb51fc749df1bd18ad`.
  Its tree matched the acquired documentation checkpoint `bfac0bc`.
- This follow-up changes validation tooling/workflows and documentation. Tick,
  storage, activity, native interfaces, TIME-002 and their ADR decisions remain
  as implemented in the separate issue commits. No environment or issue #3 Web
  toolchain changes were folded into the simulation fixes.

## Historical mismatch disposition

All 28 original BUILD_ID hashes match Git blobs at the actual M11 source commit
`05ea45fda7bdd7b0150eb86c4922c202e89e08f4`. A retention manifest freezes 18 existing
records including the original checker. The prior local checker reported 12
current-file mismatches. PR run
[34284717426](https://github.com/techrote/cybersand/actions/runs/34284717426)
reported 11 with Linux LFS materialized: World header/source/tests, adapter
header/source, Windows DLL, simulation worker/snapshot, main, Rapier bridge and
project configuration. The additional local mismatch was the unresolved Linux
library pointer. These were current-versus-M11 differences, not historical
corruption. Strict comparison remains available and nonzero; current validation
now has its own failure-enforcing gate.

## Executed evidence before reconciliation

For pushed source `22a1935`, GitHub tested synthetic merge
`b3bb2551d5b9cb881700ec5bba9649a7108129c9` on Ubuntu 24.04 x86_64:

- [Native run 34284717418](https://github.com/techrote/cybersand/actions/runs/34284717418):
  C11 header; 46/46 native tests; 46/46 ASan+UBSan with `detect_leaks=0`;
  46/46 TSan with `halt_on_error=1`; shared library and benchmark passed.
  GCC/G++ 13, binutils from the recorded job. Each compile/run timeout 15 minutes
  except C header 5 minutes and benchmark 10 minutes. Benchmark: phased, one
  worker, preallocated 512x512, 120 ticks, zero tick-time chunk/temperature
  allocations. This is not LeakSanitizer acceptance or a performance threshold.
- [Extension run 34284717476](https://github.com/techrote/cybersand/actions/runs/34284717476):
  exact godot-cpp `101ae38034304346a46ea9ea84ae156d3e860496`, SCons 4.10.1;
  Linux GCC13 and pinned Linux-host LLVM-MinGW 20260826/Clang23.1 Windows
  cross-builds passed. Binding/extension timeouts 35/20 minutes. This run used
  the pre-reconciliation drift override; it did not execute those fresh binaries.
- [Old Godot run 34284717445](https://github.com/techrote/cybersand/actions/runs/34284717445)
  passed its retained-Linux-library fixture list. This is explicitly not current
  adapter acceptance; the consolidated workflow now tests the fresh library.

## Local reconciliation checks and documentation checklist

Python 3.12.14 on Windows x86_64; commands run from source through the workspace
logging wrapper, raw records in `validation/local/20260908-issues-1-2`.
Initial `legacy-integrity-initial` (30 s limit, 1.278 s) passed 18 retained
records/28 source hashes; `current-integrity-initial` (30 s, 1.2 s) passed with
4 materialized and 14 explicitly unresolved runtime objects. Eight deliberate
failure-contract regressions passed (`validation-contracts`, 30 s, 1.851 s).
Subsequent final results and remote source/artifact identities are recorded below.

Checklist mapping: source identity, build/release/maintenance guides, contributor
instructions, validation ledger, roadmap, handover and README/routes updated.
Q31 keeps its original question and updates expected facts for the new policy;
the supplemental C01-C06 questions remain independent. Canonical corpus gains the
current/historical validation guide. Simulation ownership/storage/interfaces,
invariants including TIME-002, capacities and ADRs are unaffected by this tooling
follow-up and remain covered by the issue-specific audit mappings. Historical
records stay outside the default answer corpus.

## Remaining scope limits

No macOS, Firefox or Safari runtime execution; no LeakSanitizer acceptance,
full replay, universal failure-site or arbitrary-shape physics proof. Local Linux
LFS payloads remain unresolved even when CI materializes or rebuilds them.
Web CI toolchain/arguments/export provenance remains the separate issue #3.
Project public licensing remains undecided; this is private repository publication.

## Final local gate results before pushing reconciliation

On source `22a1935` plus the reconciliation commit's reviewed tooling/docs delta:
current gate passed (1.503 s), historical integrity passed (1.559 s), eight checker
regressions passed (2.041 s), each with 30 s timeout. `check_docs.py` passed 50
canonical documents, 86 topic owners and 32 frozen questions. Strict comparison
retained 12 differences with no historical-integrity errors. `git diff --check`
passed; native solver/adapter sources and the tested Windows DLL did not change.

[Machine-readable evidence](validation-reconciliation-2026-09-08-evidence.json)
records command outputs and fixture identities. The frozen lexical set has 23/32
hit@1, 32/32 hit@5, MRR 0.8307; supplementary C01-C06 has 5/6 hit@1, 6/6 hit@5,
MRR 0.9167. Q31 now retrieves the correct historical/current distinction first.
Original queries were preserved; Q31 expectations changed with the contract.
The previously recorded C04 top-five bounded-capacity detail gap remains; follow
the canonical storage link. Canonical hits alone do not establish complete answers.
