---
title: GEN-007 runtime completion — 15 November 2026
status: Current
document-kind: audit
scope: Dated source custody, runtime publication and Windows/Linux execution evidence for PR 582; no merge or human acceptance authority
last-reviewed: 2026-11-15
related-documents: [../systems/architectural-generator.md, ../operations/architectural-generator-playtest.md]
---

# GEN-007 runtime completion — 15 November 2026

This dated record covers the retained-runtime repair for
[PR #582](https://github.com/techrote/cybersand/pull/582). The owner's instruction
is **fix and complete; do not merge**. The earlier source-only merge proposal is
superseded. This report grants no authority to merge, alter the accepted
Arched Viaduct v2 geometry, or substitute automation for human Windows acceptance.

## Source and publication custody

| Identity | Verified value |
| --- | --- |
| Branch | `feat/gen007-architectural-generator-ab` |
| Repaired build source | `6d6e2cd68490591fbdac3e17dab0caed49c84758` |
| Build source tree | `0b18ce0e848a1bed4847dc3f2f9253411ffdc1bd` |
| First parent | `fcbce00aa0c2b8bf602dfc125e3ef9b488379cd0` |
| Incorporated main parent | `dea4e53dd71d6e0af71775593fdc9197a7633e3e` |
| Source qualification | [Actions run 43686111563](https://github.com/techrote/cybersand/actions/runs/43686111563), attempt `1`, result `SUCCESS — all five jobs` |
| Four-file publication commit | `99d7bd2b67ff49c33a6ca67c47b71507731fac35` |
| Publication tree | `afa965184a7fbb0cc9abf8b08bde4113690d16d6` |
| Publication parent | `6d6e2cd68490591fbdac3e17dab0caed49c84758` |

The main reconciliation was mechanical. The publication commit has the
qualified source as its sole parent and changes exactly these four paths:

- `godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so`
- `godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll`
- `godot/addons/cybersand_native/runtime-provenance.linux.json`
- `godot/addons/cybersand_native/runtime-provenance.json`

Independent inspection of the actual commit and materialized Git LFS objects:
**`PASS`**. Both manifests identify the
build source/tree above and carry the same **93 native inputs and 814 build
inputs**, independently recomputed from that Git source. Their binary hashes and
sizes match the actual downloaded Git LFS objects, committed pointers and
validated artifact bytes. All 93 native input hashes also match the raw Windows
checkout after the LF correction. `check_repository.py` passes its strict
current artifact/source identity checks with zero errors. A later documentation
commit does not become the native build source.

## Repaired defects

**Missing execution source ledger.** At source `fcbce00a`, both OS campaigns
completed native and graphical checks, and Windows completed its package checks. Then
[run 43680029270](https://github.com/techrote/cybersand/actions/runs/43680029270)
failed during publication acceptance with `KeyError: 'source_inputs'`. The
acceptance report omitted the field subsequently required by source validation.
The repair copies the already verified build manifest's ledger into that report
and independently checks the report's tree and full ledger against the manifest.
Missing or substituted evidence still fails closed.

**Windows native-source newline custody.** The architecture identity records
the bytes actually present during execution, while publication records canonical
Git source bytes. Unpinned C/C++ include suffixes could be converted to CRLF by a
Windows checkout and break that comparison. `.gitattributes` now explicitly pins
all admitted native-source suffixes to LF, including `.inc`, `.inl` and `.tpp`.
A regression performs a real Git checkout with `core.autocrlf=true` and requires
the resulting bytes and hashes to equal their canonical source for every
admitted suffix. The verifier was not changed to excuse divergent inputs.

## Local repair verification

The repair passed **12 GEN-007 publisher tests** and **30 shared publication
engine tests**. The GEN-007 suite exercises acceptance, independent bundle
verification and staging on both platform receipt shapes; rehashed substitutions
of the ledger/tree; stale runtime evidence; and refusal to replace a Windows
owner-package receipt with a different campaign. The LF checkout regression is
included in the 12-test count. These are publication/custody tests; actual native
execution is recorded separately below.

Commands: `python3 tools/ci/test_gen007_architectural_runtime_publication.py`;
`python3 tools/ci/test_lcb001_shared_contract_runtime_publication.py`;
`python3 tools/ci/check_ci_provider_policy.py`; `python3 tools/ci/check_docs.py`;
and `git diff --check`. Provider, documentation structure and whitespace checks
passed. The documentation check used the actual pinned companion files from
`6a58311982941b75f46e22109a0829e5acb83c7e`, with their Git blob hashes verified.

The architecture retrieval set has one new publication question and one
corrected thirteen-preset/five-card expectation: **4/4 canonical hit@5**, **3/4
hit@1**, MRR **0.875**, with expected-fact review. The unchanged frozen set is
30/32 hit@5 and the existing challenge set 162/164. These lexical metrics do not
establish runtime behavior.

## Accepted geometry preserved

Both files below are byte-identical to the owner-accepted v2 source
`2ef35d46d7506b58f05a963c6ab3d650c1876da5`; this was checked independently at the
repaired build source.

| File | SHA-256 |
| --- | --- |
| `native/src/generation_architecture_modules.inc` | `3bab22d7ab5430d083991c6dcfdafc2ae74fff64f57b042ccd04c4f4ba6fb732` |
| `examples/worldgen/architectural/arched-viaduct.style.json` | `9aee72a6511ce73b99f03f110ebce1e54dba57d2b90d475976cf144977809782` |

The repair preserves original v1 compatibility and the accepted v2 geometry;
it does not introduce new algorithm families, material pickers or aperture UI.

## Actual Windows and Linux qualification

Build and execution dependencies are pinned by the workflow: Godot
`4.7.stable.official.5b4e0cb0f`, godot-cpp
`101ae38034304346a46ea9ea84ae156d3e860496`, Linux GCC 13.3.0, SCons 4.10.1, the pinned
LLVM-MinGW 20260826 / Clang 23.1.0 Windows toolchain, and the recorded platform Rapier hashes.
Linux runs on Ubuntu 24.04 with the explicit software-rendered Xvfb display;
Windows execution runs on Windows Server 2022. These are not physical Windows
11/GPU observations.

| Required execution | Linux | Windows |
| --- | --- | --- |
| Native generation + sanitizer suites | `PASS — normal and ASan/UBSan` | Cross-build `PASS`; target-OS native material checks below |
| Architectural project contract | `1,952 / 1,952 PASS` | `1,952 / 1,952 PASS` |
| Native architectural materials | `812 / 812 PASS` | `812 / 812 PASS` |
| Graphical five-column UI | `56 / 56 PASS` | `56 / 56 PASS` |
| Ordinary author / fresh-process reopen | `73 / 22 PASS` | `73 / 22 PASS` |
| Five/sparse styles author / fresh reopen | `79 / 31 PASS` | `79 / 31 PASS` |
| Native Workbench edit ordering | `144 / 144 PASS` | `144 / 144 PASS` |
| Legacy same-platform receipts and portable materials | `PASS` | `PASS` |
| GEN-008 512² author/reopen and failure recovery | `195 / 43; native-owner failure/reopen 53 / 44 — PASS` | `195 / 43; native-owner failure/reopen 53 / 44 — PASS` |
| Independently extracted owner ZIP architecture + pristine Flatten replay | Not applicable | `PASS — normal/multistyle owner replay and the same Flatten checks` |

| Retained artifact | SHA-256 | Bytes | Original evidence artifact |
| --- | --- | ---: | --- |
| Linux SO | `0cbef228d1ce28772ac3f4d6f3dcc2cc7778775abe631bd39e71239eda404d7b` | `4,663,560` | [14150258612](https://github.com/techrote/cybersand/actions/runs/43686111563/artifacts/14150258612) |
| Windows DLL | `373b74cbaf19089422c30f89da7aaab170052a541d8383766286f6a522c793b0` | `5,211,136` | [14150733799](https://github.com/techrote/cybersand/actions/runs/43686111563/artifacts/14150733799) |
| Windows owner application ZIP | `370775ffa6a6d6fed9cc5af9ac8a1386489ad2ddb6611367e1d36b1d0e1fb0a8` | `93,489,140` | [14150923470](https://github.com/techrote/cybersand/actions/runs/43686111563/artifacts/14150923470) |

Independent downloaded-package inspection: **`937`**
payload hashes checked, with **`zero missing, extra or mismatched files`**.
All **93 native source hashes** were also independently verified. The manifest's
source commit/tree and bundled native DLL equal the qualified source and Windows
binary above. The inner application archive is
`CyberSand-Architectural-Generator-Windows-6d6e2cd68490.zip`; its SHA-256 matches
the published sidecar.

The validated bundle reports are bound by SHA-256 in the retained manifests:
Linux `61171c2a054a4996c6486d674676f6848458fb2a2a201d84cf465c73d664480e`;
Windows `6b939857a08a73947466d2382e41ffd14296d6d2f161581f9d565a92113338bd`.
Both name run 43686111563, build and execution attempt 1.

## Durable coverage and remaining owner boundary

Native CI and the broad Linux/Windows Godot workflows retain the architectural
native-material, compiler-contract and UI regressions. The architectural
workflow also runs its bounded publication guards on pull requests and main
pushes. Full native/graphical/package qualification remains restricted to the
feature-branch push campaign or explicit workflow dispatch; publication remains
limited to the guarded feature branch.

The final documentation follow-up does not change compiled or declared
publication build inputs. Fresh checks against that final PR head are recorded
in the [PR #582 evidence ledger](https://github.com/techrote/cybersand/pull/582)
after they finish: Documentation/provenance, palette backend, Native C++, full
Godot/coverage and applicable Water apparatus. This fixed audit does not claim
those future runs passed or reuse earlier-head green checks as final evidence.

Human Windows 11/GPU assessment of the final package remains an owner
observation, separate from the already accepted Arched Viaduct v2 reference.
The PR remains unmerged unless the owner explicitly approves a later merge.
