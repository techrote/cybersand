---
title: Wave Water Ramp 003 runtime and owner package qualification
status: Current
document-kind: audit
scope: Published Linux and Windows runtimes and the locally built Windows owner evaluation
last-reviewed: 2026-11-19
related-documents: [../2026-11-19-wave-water-ramp-003.md]
---

# Wave Water Ramp 003 runtime qualification

The [experiment record](../2026-11-19-wave-water-ramp-003.md) covers the change in floor spread, incline run-up, tank return, timing, worker parity and independent review. The [Draft/HOLD PR](https://github.com/techrote/cybersand/pull/677) records the final branch head and its checks.

## Local Windows evaluation

The owner package and hosted runtimes used source `d0d939bdfa17446057e228ef0f910f6005e75b69`, tree `859f465a5c98ec43fa8858f9057f02730c1d07a8`. The local build used `C:/Users/_/lcb-local-toolchain/rebuild_and_test.sh`, LLVM-MinGW 20260826 / Clang 23.1.0 and Godot 4.7 stable `5b4e0cb0f`. The test host ran Windows 11 Pro x64 with an NVIDIA TITAN RTX using ANGLE D3D11.

| Owner artifact | SHA-256 |
|---|---|
| Windows ZIP, 92,030,100 bytes | `58279c0729c3983625e505ecb2f819620a7b480a2a1faa5717930e2cbc1d85cb` |
| Locally compiled native DLL | `4640207680cf5d23619b35beca1063f38576341b5d437ab3d37a2742bc95833c` |
| Supplied 1024 × 1024 ramp | `7aba8a47c926cc1911bc4ee519179c595b686692d5c78db8f103b8b62d311acb` |

The first `Open Workbench.cmd` run installed the supplied map into an isolated profile. The second preserved an existing map of the same name. All 950 packaged files matched their hashes after extraction and execution. The extracted Workbench passed 766 spill checks. Its graphical ramp and flat-floor runs reproduced every sampled Water total and occupied-cell count from the source captures over nine submitted frames. On the ramp each observation through tick 600 held 9,773,895 units. The original user map still matched its supplied digest after these runs. [Machine-readable local receipt](owner-local.json)

## Published runtimes

[Publication request 21](https://github.com/techrote/cybersand/actions/runs/44486032495) passed all nine jobs, including normal native, ASan/UBSan, TSan and Godot execution on both operating systems. The bot published exactly the two libraries and their two provenance records at `271afa5b1d37a1e0d4dd5ea7b2715a562431497b`. Both downloaded evidence bundles agreed on 95 native and 862 build inputs. Independent SHA-256 checks of all 957 input files matched the published source's Git blobs.

| Hosted artifact | SHA-256 |
|---|---|
| Windows x86_64 DLL | `e78cbf079e451e27fc04a1e06c473ca26cf821f65833a6da076185595233ceba` |
| Linux x86_64 shared library | `f5f55b9faa90d39e388913144c6f76b7bc33d02859065725d2b0ad2dad81cb58` |

Both platforms passed the real Workbench Wave case (1,272 assertions and 35 native ticks), Water Lab spill (766 checks), failure containment (77) and failed-World status (215). All 27 downloaded execution logs were free of `ERROR:` lines. Linux graphical Workbench passed 217 assertions and six captures. Windows passed all five extracted CI package cases and preserved the payload. The separately built local DLL passed the Windows graphical Workbench on the owner's hardware. Browser/WebAssembly performance and the owner's assessment of game feel remain open.

## Additional local checks

Under WSL Ubuntu 24.04, `make -j2 test` passed all 192 aggregate tests and its prerequisites. Both `make -j2 wave-flow-sanitize wave-spill-sanitize` and `setarch "$(uname -m)" -R make -j2 wave-flow-thread-sanitize wave-spill-thread-sanitize` passed all 33 Wave and 32 spill cases. Normal Wave, spill and the 6,000-tick body-boundary campaign passed. The previous 12 base-law and four pinned spill identities were preserved.

After pulling the published runtimes, `python tools/ci/check_repository.py --require-materialized` verified local materialization and agreement with current source. The historical M11 check passed 18 records and 28 hashes. Focused Wave retrieval passed 7/7 questions. The general retrieval evaluation found a top-five canonical answer for 30/32, matching the parent.
