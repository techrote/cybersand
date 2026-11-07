---
title: Freed-object runtime validation custody
status: Current
document-kind: audit
scope: New source-authenticated development binaries and actual local host execution; no release or original SOL acceptance
canonical-for: []
last-reviewed: 2026-11-07
related-documents: [../../architecture/workbench-freed-objects.md, ../2026-11-07-workbench-freed-objects.md]
---

# Freed-object runtime validation custody

Compilation source is `d5ebc491f84f5630cd79cce0af7d02d24815bdce`.
Full host-suite execution uses that source. Exact numeric/RID observation uses
`d258a82f2de5beea48f9c748060ec8805900e1d4`; only the test observer and runner
changed. All93 native inputs,15 additional build inputs and154 production
Godot script/resource inputs remain equal. The observer starts a fresh engine,
World and physical session per host/worker run against the unchanged host-suite
projects. It adds no second project copies under the registered2GiB evidence
cap and5GiB free-space reserve. See [summary](summary.json) for receipt hashes,
source trees, inventories, costs and complete numeric readbacks.

| Actual local host | Native artifact SHA-256 | Execution |
|---|---|---|
| Windows x86_64 | `5d0b0e871b393e300695492c9bfaf9c0706195d97ef1e1dff06957f3a53a55c8` | Workers1/4:83 checks each; lifecycle52; retained workbench suites pass |
| WSL Ubuntu24.04 x86_64 | `1b93a937f17799d0385089125e4ad475469f4e3b61eb865cb9c1cbd5b8b92442` | Workers1/4:83 checks each; lifecycle52; retained workbench suites pass |

Godot is4.7.stable.official.5b4e0cb0f. Actual Windows launcher SHA-256 is
`d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c`,
engine `b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8`;
Linux engine `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`.
Selected Rapier binaries remain Windows
`b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7`
and Linux `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`.

Windows builds/execution are Windows-hosted LLVM-MinGW clang/LLD23.1,
not MSVC or a Linux cross-build. Linux uses GCC13.3/ld2.42.
Both bind godot-cpp `101ae38034304346a46ea9ea84ae156d3e860496`;
static libraries are Windows
`2629ba35adc7b1263deeb1155d674252e1e4188c2c89d1d7158e816d18f957df`
and Linux `bc5f860471475c745ebad2b45988607a15c9a35c6996b0f08fea37570e6ef666`.
Dependency inventories match before/after each build. Selected copied library
bytes are hashed before execution; mapped-module enumeration was not repeated.
Do not reuse the historical ordering campaign's mapped-module audit for these
new artifacts.

Native core at `94758f26e9c11720acdfc893061ec6489321dd72` passes optimized
and strict ASan/UBSan:1,184 new checks and19,338 original transaction checks
in each configuration. All actual core inputs remain equal in the final source;
later native changes are confined to the separate Godot facade. Leak detection
is disabled explicitly; no instrumented extension-host sanitizer or MSVC run is
claimed. Linux material controls pass118 tests and native parity. Windows
symlink privilege/path restrictions are retained failures, not passes.

The unchanged Linux runtime-floor gate still fails: bundle GLIBC2.35 exceeds
the retained2.34 floor. The independent symbol ledger records remaining C++ ABI
requirements. Actual Ubuntu24.04 execution does not admit older supported
Linux hosts. No floor, frozen material hash, cap, weight or accepted default was
relaxed. Original SOL physical/CPU/restoration blockers remain separate.
