---
title: SOL workbench composition runtime validation identity
status: Current
document-kind: audit
scope: Local source-authenticated experimental Windows and Linux binaries; named headless controls and actual cuts, Linux runtime-floor failure, no release acceptance
canonical-for: []
last-reviewed: 2026-11-06
related-documents: [../2026-11-06-sol-workbench-law.md, ../2026-11-06-sol-workbench-material-transition.md, ../../operations/local-build-and-validation.md]
---

# SOL workbench composition runtime validation identity

This record qualifies newly built experimental development runtimes for Draft
[#466](https://github.com/techrote/cybersand/pull/466). It does not inherit main's
cleanup-owner acceptance, pilot UI, full hosted-release or physical-clearance
qualification. The registered actual-cut result is **NO-GO for packed settling**;
runtime/source identity and scientific success are separate decisions.
**Linux supported runtime-floor check fails:** this SO imports
`hypot@GLIBC_2.35` and `_M_replace_cold@GLIBCXX_3.4.31`, above the retained
2.34/3.4.30 limits. Actual Ubuntu24.04
execution passes; supported older-desktop compatibility remains a blocker.
No source change or floor relaxation is hidden behind those successful runs.

Compiled source `990cd5d3701c46ff3a07b0259b9fc968a7a14e7a`, tree
`a29b2c7e748ac267af575577fae4f5f520752e30`, is retained in ancestry. All93 native
code/header inputs match the current source and build snapshot's LF hashes;
15 additional tools, dependency pins and resources have a separate inventory.
The roster is exactly `native_input_paths()` from the unchanged Windows gate,
including nine SOL files absent in main's old84-input manifests. No frozen
material hash or old validation record is refreshed.

| Actual target | Artifact SHA-256 | Bytes | Compiler |
|---|---|---:|---|
| Windows x86_64 | `6d600ca90129a4db1effb72a113a053eb582a0219b3a2c6117fb0107462b2c27` | 5054976 | Windows-hosted LLVM-MinGW20260826 UCRT clang/LLD23.1; not MSVC |
| Linux x86_64 | `f7857fde74ded7a3165a842f57ff0fa1257ee221c4accd47384f3a278a8730ed` | 4504880 | WSL Ubuntu24.04 GCC13.3/GNU ld2.42; floor check fails |

Pinned godot-cpp is`101ae38034304346a46ea9ea84ae156d3e860496`; static library
hashes, compiler/helper/SDK inventories and dependency equality before/after
are in `build/sol-workbench-law/runtimes-003/receipt.json` and its original logs.
Receipt SHA-256`a84e9ecd583ec25ad3ca8becedf2b578d934abeda95a8e4466f3e4cb3b9525c9`.
Exact commands are `bash tools/build_native_extension_windows.sh` on Windows and
`bash tools/build_native_extension.sh` under WSL with the existing pinned SDK
and strict toolchain variables; the receipt preserves every argument/environment
selection,900s timeout, exit0 and raw log hash. No compiler-drift override is used.

Actual Windows Godot4.7 executable SHA-256
`b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8`, console
launcher`d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c`;
actual Linux executable`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`.
Rapier0.35.2 Windows DLL SHA-256
`b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7`,
Linux SO`566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`.
No dependency version/hash/license changes.

The actual144×720 matrix ran at resource-script source
`026f7d040c3e298a29010dbc67d3569ac6316b70` with the above binaries. Every fresh
project records selected executable/module hashes and full input inventories
before/after; the two hosts'801 recorded files remain unchanged. Source-qualified
matrix receipt SHA-256
`92f58414b2bb67f2c462f44d842fb2b399be6bf6d8948dc7d5b9e8b301e59408`.
Per-command arguments,300s timeouts, exits, raw reports and logs are indexed in
[summary.json](summary.json). This is local headless execution on actual Windows
and WSL Linux, not cross-building a Windows library and calling it Windows proof.

Successful quick smoke at `fccae661` executes native imports,
`test_solid_contact_response`, `test_solid_contact_fences`, `test_sol_contact_order`,
`test_workbench_fleet_session`, `test_workbench_desktop_interest`, startup/binding
refusals and real short cut episodes. Earlier composed smokes execute
`test_workbench_canvas` and `test_workbench_physics_play`, with those earlier
source identities retained; they are not silently relabelled final matrix-source
qualification. Full pilot UI and hosted-release suites remain separate.

Public-refusal tests at the matrix project source pass3,259 checks/16 cases for
each host and worker1/4. They exercise the actual native facade with synthetic
body reservations, not Rapier-motion acceptance. Audit receipt SHA-256
`11f4e080c1cc00c7b88cd6fb6842555a6c2a5182b4d6e9b4ecdd27fc446884ea`.
Additional lifecycle/replacement, actual compound response, CPU render ACK,
host-failure publication, compound coupling and terrain/excavation suites pass
518 checks per host on the same sealed matrix projects (workers1/4 where
applicable). Full801-file inventories remain unchanged. Receipt
`build/sol-workbench-law/host-qualification-001/receipt.json` SHA-256
`8a01588e33237072a77428f63d436ab2c31a2d6fa2294ccd230d173104cf2924`.
The unchanged Linux floor checker exits1; raw log SHA-256
`623746348b9a99748d32dcf6ac964eae7f209b5e29ef4b79e4c4d4dd0e25dfa0`.
Symbol inventory also exposes GLIBCXX3.4.31 beyond3.4.30; CXXABI1.3.9 matches.
The first symbol-summary parser yielded null fields and is retained; corrected
v002 derives these maxima from the same raw symbol log, without rebuilding.
Optimized/strict ASan+UBSan core and material tools/parity pass as separately
listed in the [dossier](../2026-11-06-sol-workbench-law.md); native sanitizer
controls do not claim an instrumented GDExtension host.

Original SOL clearance/depth/async/refusal/CPU failures, #365 and hard-material
exclusions remain unchanged. Full hosted release, MSVC, Web/GPU/human gameplay,
general restoration and default promotion are **UNAVAILABLE**, not passing by
inheritance. Keep Draft; no Ready or integration admission is granted here.
