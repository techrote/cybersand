---
title: IN-TOOLS #361 current-main authority renewal from #404 A01
status: Planned
document-kind: audit
scope: Exact source identity, A01 correction, inherited behavior and outstanding gates; no production gameplay changes
last-reviewed: 2026-11-07
related-documents: [../architecture/in-tools-gameplay-admission.md, ../operations/in-tools-fixtures-and-playtest.md, ../operations/current-and-historical-validation.md]
---

# IN-TOOLS #361 source authority renewal — 2026-11-07

## Separate authority and historical source identities

- Historical PR #379: `e7e404b696fb9fc48cdadc95a69baf3a6f5fc6d1` / tree `3b5acd41fd7fb49ac8b06c94719fa1a700d8fd57`, with actual-Windows [run 41920193030](https://github.com/techrote/cybersand/actions/runs/41920193030) returning `0xC0000005`. No causal repair is inferred.
- Historical Draft #404 A01 repair: head `20e668ce66536f9365d07718bfbb5266a2f8502c` / tree `19e8842f778f3a916f83805aa8af83307b4756d8`, based on `ba9cbc89029be88b812af59b19e5c59829bbcd90`. Historical successful Windows [41963179165](https://github.com/techrote/cybersand/actions/runs/41963179165) executed its **pre-A01 head** `b9abf9aa0ad8fa0e189fe0e4d6a15eccf8c95c33`; do not inherit it.
- Immutable A01 witness: real GitHub-hosted Ubuntu 24.04 / Python 3.12.3 / Git 2.56.0, [run 42332630429](https://github.com/techrote/cybersand/actions/runs/42332630429), 14/14 adversarial tests PASS, 13/13 source authority PASS, verified exact #404 head/tree and clean source state. Includes same-count World substitution and real descendant commit with restored working tree. **It does not qualify the newer successor or replace a distinct code-review decision.**
- Initial #508 checkpoint on `ab12ccef49ba2afaed2520d4d9a86eb14c7779cb`: head `68c1ac8da02d6527abdcd8776135cb67d82b0c73`, tree `2dea236de806219866417c8f9fbd751c2812349c`, actual source 15/15 [42333211721](https://github.com/techrote/cybersand/actions/runs/42333211721), docs/M11/retrieval [42333211638](https://github.com/techrote/cybersand/actions/runs/42333211638), Windows [42333211705](https://github.com/techrote/cybersand/actions/runs/42333211705) 86/0 natural exit 0. Native/GDExtension skipped under Draft. These passes **do not qualify newer accepted source**; four protected files and retained runtime advanced on later main.
- Reconciled Draft #508 adopted `main` `24a8bbe8ccf0d17196ebbab580b924930a964584`, exact tree `9359fb6177a13c5ec204a15d8f3f75919b52bd56`. This is an explicit *new* source authority decision; original #404 pins are unchanged.
- Versioned new registration: `godot/tests/fixtures/lcb/in_tools/in-tools-current-main-admission.2026-11-07.json`, code checker `tools/lcb/in_tools_current_main_admission.py`.

## Thirteen input source set — six requalified blob identities

Seven paths remain byte-identical to #404's adopted base, including the ordinary U10 catalogue and physical usable scripts. Six changed on the renewed accepted main. Four of those six changed **again** relative to the first #508 checkpoint:

| Reviewed authority path | Historical #404-base Git blob | New adopted-main Git blob |
| --- | --- | --- |
| `godot/scripts/simulation_worker.gd` | `67d9e0de91fe719e2be8f6eb3b6ae08d4c9cb61d` | `0e2471d72906cffffdc0a52431e20074dfd3ee4a` |
| `godot/native_extension/cyber_native_cell_world.cpp` | `c73055cf95a0bc7f216f231115231f9db45af75f` | `b43ac4421cf45f6684e2febcad0e793fd1312c16` |
| `godot/native_extension/cyber_native_cell_world.hpp` | `1fa7fd1a290297f0e838ee002d90d0642a692ec2` | `2acbbd5fceaaeaf2665a73b6d53ec718184ea4d5` |
| `native/include/cybersand/world.hpp` | `bb2f6e33dd1ad8e4a2b2aec7b34ccfb8229b6cb3` | `c44f766e9d3a4d070466952e03807b4a2a97669f` |
| `native/src/world.cpp` | `aed1bb10e480493397f5c5eac8ba2336f495b9f9` | `3cfc1b47c32dacd00f864cf031588ab637a6b2bd` |
| `native/src/world_inertial.inc` | `b070dda02477d2eb461d8d2082ee063e04710093` | `da44b76b699bb459d88128b8dbc5106f24ddaa17` |

Read-only current source inspection found the intended native World authority, exclusive worker, Godot adapter and Water inertial implementation still present. Updated source includes optional lockstep/ballistic coupling and the subsequently merged C2048 native capacity work. The second renewal merges the newer accepted main; it is not a retroactive pass of the prior Windows artifact. **Changing the six hash pins is not proof of semantic equivalence** or a free pass for the altered runtime. The new branch does not import any of the six older production sources.

## A01 guard behavior and negative-control contract

A code-owned exact 13-path set is independent of the mutable registration. Admission validates row shape, duplicate path refusal and exact path-set equality **before** trusting blobs/roles; it authenticates the pinned adopted-main commit, historical #379/#404 lineage, 13 approved Git blobs, a committed HEAD diff, and working-tree hashes. The adversarial suite includes same-count README/Makefile substitutions, duplicate/omitted paths, stale/malformed identity, altered World worktree bytes, and a real descendant commit with masked worktree bytes.

## Current/Planned boundary and remaining acceptance

Current inherited U10 `liquid_drain` remains only the ordinary selective liquid sink; `godot/scripts/usable_catalog.gd` retains its exact historical Git blob. **No exact-metered #361 command exists in this admission.** The six v2 concepts — valve-side, valve-bottom, sink-bottom, sink-side, source-channel and usable-liquid-drain — are all `Planned / NOT_RUN`. Committed registration keeps `gameplay_qualified=false`, `runtime_qualified=false` and `windows_gate=NOT_RUN`.

Required separate gates: exact-head new-source admission and adversarial tests, documentation/M11/retrieval/source-provenance, actual Windows unchanged `test_liquid_desktop_default_host` with natural process exit and verified retained source/runtime, applicable Native/GDExtension/Godot matrices (Draft skips are not passes), distinct read-only code review, and later-main integration review. Do not merge or mark source-admission alone as gameplay acceptance.
