---
title: P2 runtime identity and fixed-action ordering qualification
status: Current
document-kind: audit
scope: Fresh P2 Windows/Linux runtimes and source-qualified ordering experiment; Linux floor failure and physical NO-GO retained
canonical-for: []
last-reviewed: 2026-11-06
related-documents: [../2026-11-06-sol-workbench-ordering.md, ../sol-workbench-law-20261106/runtime-validation.md, ../../operations/local-build-and-validation.md]
---

# P2 runtime identity and fixed-action ordering qualification

Fresh native binaries compile P2 source/build
`9a78d136246d34b9760d64f2c0dffa53c5561eb1`, tree
`861eabc927091c3d528e110673f5f3d4dc2e48fe`. The public wrapper preserves the
preflight diagnostic distinction between unavailable, failed and fenced World.
No contact arithmetic, material consumer, mass, inertia, gravity, damping, cap
or default changes. The full 93-file production native roster and 15 additional
build inputs are authenticated before/after; both platforms have exactly the
same source roster. Dependency versions, licenses and hashes remain pinned.

| Actual build host/target | Native artifact SHA-256 | Toolchain |
|---|---|---|
| Windows x86_64 | `d8dc09c1ce4860b7f74c4841c364bca4504761c453de93caf1ff9dd0c1fcb8bd` | Windows LLVM-MinGW20260826, UCRT clang/LLD23.1; not MSVC |
| WSL Ubuntu24.04 Linux x86_64 | `aa78df39268096ce8c2908ff274f544e3a295e081be67e55d4f47be49edb5bf6` | GCC13.3, GNU ld2.42 |

The build receipt is `build/sol-workbench-order/runtimes-001/receipt.json`,
SHA-256 `d8b5f4d9a8686be461c77c9921b74dfb48768d6c37b92c0ef4a90c764fb57a69`.
Commands are the unchanged Windows/Linux extension build scripts with the
registered pinned SDK/compiler variables, 900s timeout and exit0. All arguments,
tool/helper/SDK/static-library inventories, logs and before/after equality are
retained. Pinned godot-cpp is `101ae38034304346a46ea9ea84ae156d3e860496`;
Windows library SHA-256 `2629ba35adc7b1263deeb1155d674252e1e4188c2c89d1d7158e816d18f957df`,
Linux `bc5f860471475c745ebad2b45988607a15c9a35c6996b0f08fea37570e6ef666`.

Actual Windows Godot4.7 engine SHA-256
`b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8`,
console launcher `d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c`;
Linux engine `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`.
Rapier0.35.2 Windows DLL `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7`,
Linux SO `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`.
One live mapped-module sample per host confirms these actual loaded paths/hashes;
this is not module sampling of all episodes. Sampling receipt SHA-256
`29457a5b63691a49d3ee9461aef70b3a753937498248f3f2a626d12afdfc454a`.

P2 source actual-host qualification `facade-002` passes **3,260 checks/16 cases**
on Windows and Linux, each with workers1/4. The exact `world_failed` capacity
assertion runs on all four hosts/configurations. Minimal import-only
`facade-001` projects crashed at editor shutdown before facade execution;
those failures remain intact. Complete source-matched host imports pass.

Ordering test resources execute at source
`13a9ec68be342b54a7476b7f9e0ff1315a8bd917`, tree
`dacbcc9345758352229f4ce12c22d3dc0eab1a8c`, using those compiled binaries.
Smoke002 authenticates all prerequisite files/logs/reports and 1,360 primitive
checks before primary admission. Receipt SHA-256
`468e0aeb8a982b5ef972c8b196336363edb9cfe8106009469762e0700bb0fb3a`.
The pure actual-Rapier adapter oracle passes201 checks/60 bodies per host,
20 copied-production equalities each; 16 short actual-cut episodes pass startup.
Contact-order, fleet-session and desktop-interest controls pass on both hosts.
The no-step oracle's zero gravity does not apply to physical actual-cut episodes.

Matrix001 contains **96 fresh actual-cut episodes / 69,120 physical steps**,
Windows/Linux, workers1 with five repeats plus separate worker4 spots. Every
host input inventory and source identity remains unchanged. The registered
decision is **NO-GO**: reversing correction/clip versus combined impulse/torque
fails rest and worsens median Sand area/depth in every primary comparison.
The separate independent reducer verifies all345,600 primitive transitions,
geometry/rest/sink and work identities without disagreement. Exact receipt,
report/archive, command/log and reduction hashes are in [summary.json](summary.json)
and the artifact index. No scientific success is inferred from valid runtime
identity or from the preserved historical source-qualified native tests.

**Supported Linux runtime-floor admission still fails.** The unchanged checker
exits1; `hypot@GLIBC_2.35` and `_M_replace_cold@GLIBCXX_3.4.31` exceed retained
2.34/3.4.30. CXXABI1.3.9 matches. Actual Ubuntu24.04 execution passes; older
supported desktop compatibility remains blocked. The separate symbol inventory
and retained retries do not weaken this floor.

Fresh material guard/generated checks pass. The historical optimized/strict
ASan+UBSan core controls have123 matching canonical Git/LF inputs,112 exact old
checkout-byte matches and11 CRLF-only differences. They retain their original
compiled source, executable hashes, commands and results; they were not rerun
here and do not qualify a sanitizer-instrumented extension. The fresh P2 build
and four facade runs cover the changed wrapper separately. Frozen material
guards and accepted per-file transitions remain unchanged.

This is scoped experimental development qualification for Draft #466. No MSVC,
full hosted release, GPU/Web, human gameplay, universal60Hz, original inclusive
SOL CPU gate, restoration or accepted-default promotion is admitted. Preserve
all original SOL failures/#365/hard exclusions. Prior runtime records and their
hashes remain unchanged. No Ready or merge.
