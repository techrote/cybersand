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
full replay, universal failure-site or arbitrary-shape physics proof. All 18 local LFS payloads were subsequently materialized and verified; this
does not establish all-platform execution.
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
records command outputs and fixture identities. The frozen lexical set has 24/32
hit@1, 32/32 hit@5, MRR 0.8542; supplementary C01-C06 has 5/6 hit@1, 6/6 hit@5,
MRR 0.9167. Q31 now retrieves the correct historical/current distinction first.
Original queries were preserved; Q31 expectations changed with the contract.
The previously recorded C04 top-five bounded-capacity detail gap remains; follow
the canonical storage link. Canonical hits alone do not establish complete answers.

## Publication follow-up checks

Documentation run [34286177617](https://github.com/techrote/cybersand/actions/runs/34286177617)
passed every current/M11, checker, retrieval and LFS step for source `dda2fd5`
(synthetic merge `8803cf3e270c2f6d68acc44278481efe6e875c38`). Native run
[34286177604](https://github.com/techrote/cybersand/actions/runs/34286177604) also passed.

`git lfs pull` materialized all 18 required runtime objects; `git lfs fsck` and
`git fsck --full` passed (two unreferenced blobs reported, preserved). The current
`--require-materialized` gate passed in 1.427 s with a 30 s limit. No local
runtime pointers remain. All three native build scripts pass separate Bash
syntax checks. A Windows builder dry run with drift disabled passes current
compiler/source checks; explicit M11 output verification exits 3 for the
different bindings archive even with drift enabled. These read-only probes
used existing clean pinned bindings and made no environment or runtime changes.

## Fresh Linux runtime acceptance and promotion

[Run 34286177653](https://github.com/techrote/cybersand/actions/runs/34286177653)
passed both extension jobs with the drift override removed: exact GCC13.3.0 /
binutils2.42 or LLVM-MinGW23.1, SCons4.10.1 and clean pinned godot-cpp sources.
The Linux job then passed all 16 Godot runners, both profiles, import and scene
smoke (20 invocations). Limits: 240 s import, 180 s each fixture/scene, 1,200 s
each profile, 30 minute aggregate runtime step. Godot error output fails even
with exit zero. The full runtime stage completed within 83 seconds. Native
profile: two workers, 60 ticks; the GDScript scheduler probe is diagnostic
timing, not a performance or cross-mode equality acceptance gate. Linux scripts
named Web tests still execute native Godot; Chromium evidence remains separate.

Tested source merge `8803cf3e270c2f6d68acc44278481efe6e875c38` contains head
`dda2fd5762e7bb472f125b1220a16e308ffa5111`; its native/adapter source inputs
match the published Windows input set and the subsequent promotion commit.
Linux runtime SHA-256
`8f68fd2c7cb2b449173f5ee2c3ce267b6966ac8a9d8381fdacdd05dfc2d9c31a`,
1,182,592 bytes. Artifact `10079917041` ZIP SHA-256
`f08d82b1bb3ac8e48433871706106b221e446919f03c166c94a2494e837ec9f4`
was downloaded, verified, and its ELF and identity record checked before promoting
the exact tested library to Git LFS. The Linux provenance manifest records these
identities; the current gate requires both Windows and Linux manifests. This
replaces the default M11 Linux runtime without changing its historical hash.

ABI acceptance: GLIBC2.34 bundle, CyberSand GLIBC2.32 / GLIBCXX3.4.30 /
CXXABI1.3.9, Rapier GLIBC2.34. Current Windows cross-build SHA-256
`9bcb4329d7f5d5e44f321df45444bf3deda95d7578d0083df4a09f5da8d55ac9`
was format/import checked only; the published Windows DLL remains the separately
Windows-tested `fda49d0...` artifact. No cross-build/runtime substitution was made.

After the Linux promotion documentation, structure and eight checker regressions
still pass. Final frozen retrieval: 23/32 hit@1, 32/32 hit@5,
MRR 0.8385; supplementary results remain 5/6, 6/6, MRR 0.9167. The
earlier 24/32 measurement above remains scoped to its recorded corpus.

## Merge and release-hash packaging follow-up

PR #6 merged as `76640b06de50c9146aba74ee80ae406a5c1b08f2`, preserving the
implementation commits, and issues #1/#2 closed as completed. Final promotion
head `0c91f47` passed current/documentation CI run `34287504398` and native
run `34287504377`. No native, adapter, owner or fixture source changed after
the fully passing fresh-runtime run used to publish the Linux artifact.

Manual release-hash run
[34287717311](https://github.com/techrote/cybersand/actions/runs/34287717311)
passed current identity, historical integrity, LFS and manifest generation, then
failed artifact upload because `github.ref_name` contained `/` in the branch
name. The follow-up uses the numeric workflow run ID for the artifact name,
which works for branches and tags. Hash contents and historical records are
unchanged. The failed run is retained; a new run verifies actual upload.
