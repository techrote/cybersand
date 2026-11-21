# Independent CLI portability and protocol-pin delta review

Date: 2026-11-21 UTC. Reviewer: `/root/swarm45_native_review`. Repository: `/workspace/scratch/038267c40e11/cybersand-swarm45-mainline`. Reviewed working-tree delta over request commit `9b688aed1f06f031f983c27f50d1f17821446e43`, whose code matches frozen source `a08c0e77601c9451ece3a15248d4255164911d5f`.

**GO for this narrow CLI logging, protocol-pin, and ABI-floor diagnostic repair. No unresolved confirmed P1/P2 findings in this scope.** This does not approve the complete next freeze, publication, Ready, or merge. The separately reported Windows staging/generated-UID refusal and extracted-package startup failures are outside this review and remain with their assigned investigators.

## Source and protocol scope

Only `reciprocal_main.cpp` changes among the **43 native definition inputs**. Its delta replaces `<iostream>` with `<cstdio>` and exactly five progress/error output sites with `printf`/`fprintf`. Parser, solver, campaign selection, geometry, budgets, JSON serialization through file streams, and exit-code branches are unchanged. Campaign progress retains an explicit `fflush(stdout)` where `std::endl` previously flushed. Format arguments match their specifiers: sizes use `%zu`, booleans are converted to `int`, and 64-bit counters are explicitly converted to `unsigned long long` for `%llu`. Error text remains a `%s` argument to a fixed format string.

The two repaired receptor/accounting source files match the preceding frozen commit exactly. The source delta introduces no change to supported-receptor geometry or work accounting, and no change to the disclosed scientific fixtures, policies, ceilings, or holdouts.

Recomputed native definition: `217bfa716e61198f5b3849f2ae14c30e85bc9f623fc1d05438c59df2296ce7f7`. The Godot protocol file is exactly its previous bytes with the one old definition value replaced by this new value; no protocol schema, budget, admission, or authority logic changed. Updating that pin is necessary because the native definition includes the CLI source file.

## Independent bounded evidence

Using the existing local ABI0 core objects and the old `fe62e154...` definition macro for a controlled output comparison, I ran both the old CLI and the repaired diagnostic CLI for three cases, each child bounded to seven seconds. All comparisons passed:

| Case | Exit | Exact stdout/stderr and output comparison |
|---|---:|---|
| `single`: protected_corridor / sparse_regular / seed605 / reciprocal_3 | 0 | Both `RECIPROCAL_SINGLE status=blocked rounds=3 joints=0 apply=0`; empty stderr; raw JSON SHA-256 `d82ed7991aa5901d08b44b8e9fac58c65d5d47d830ea66de88303cfe7411da82` |
| V3 request: irregular profile with compact and supported switches | 0 | Both `RECIPROCAL_REQUEST status=complete joints=0 apply=1`; empty stderr; raw JSON SHA-256 `961afd158017c02bfed30ad066d2abee8528277220ebe6ffe41d43b71c3682ba` |
| Invalid mode | 2 | Both empty stdout and exact `campaign requires OUTPUT SOURCE known\|holdout [SELECTED]` stderr plus newline; no result JSON |

Both diagnostic CLI variants use the same old definition/core configuration, so byte equality requires no normalization. The diagnostic replacement source is byte-identical to the reviewed `reciprocal_main.cpp`. This isolates the console-I/O repair; it is **not** a qualifying build of the new `217bfa...` definition. No campaign or broad native corpus was rerun. The V3 example has zero joints and is not a new reciprocal scientific success.

I also independently ran the real symbol-floor check against both local binaries. The old ABI0 CLI is refused for **GLIBCXX3.4.32**. The repaired diagnostic CLI passes the **unchanged** ceilings and imports maxima **GLIBC2.34 / GLIBCXX3.4.29 / CXXABI1.3.9**. This is local GCC14 diagnostic evidence; the actual pinned-hosted replacement build must still pass its own gate.

## Failure diagnostics review

`linux_floor.py` preserves the existing ceilings and symbol-family validation. It now retains each inspected binary's raw `objdump -T` output and hash before validation, records pass/failure by binary, writes a failed JSON receipt, and then raises a binary-named refusal. A high import requirement cannot turn into acceptance. `native_checks.py` supplies its existing evidence directory. The new regression verifies that a passing adapter plus failing CLI retain both symbol tables and identify the offending CLI.

Independent execution of the new failed-floor regression and the existing ceiling-boundary regression: **2 tests PASS**, exit0. The actual local old/new pair also exercised the failure path and retained both raw symbol tables. The earlier hosted Linux refusal is not waived, and no ABI ceiling was raised.

## Exact source and evidence hashes

| Reviewed repository-relative file | SHA-256 |
|---|---|
| `native/experiments/gentek_swarm/reciprocal_main.cpp` | `85610d2d00e997278394d3ed6310097c546b26ab6588b6b16b7f30de6b46c1ac` |
| `tools/swarm45/linux_floor.py` | `b875adefdd56fa1cd3727b25ab22f435ecce4dad9b482eb86cee4e4aed693b5d` |
| `tools/swarm45/native_checks.py` | `16b8a1bb7d37a4f912a54483c1315cf07112fd7507dfa928c888b0c2fddc4349` |
| `tools/swarm45/test_custody.py` | `223c0fa59b36f787a88c267c191edc6b5c636cd830745c206121fe2a7eceb8f0` |
| `godot/scripts/workbench_reciprocal_protocol.gd` | `8c1e392a108884e1d6a4340d80c9ddf2b6a2b0e28e2d4d9b934ea50927f1ef72` |
| `native/experiments/gentek_swarm/reciprocal_mosaic.cpp` | `94a38e05026e6f16b84d1ba2e506775f4159e21424c958e4886e4981cc65579d` |
| `native/experiments/gentek_swarm/swarm005_research_tests.cpp` | `c7226cae0f92858dad52ff8e285eee22b40274e7c1a01d45d7e840fd3a4861b1` |

Old diagnostic binary SHA-256: `b13d30c8f230cea02f3b2e22faeef98d60dc8fc9cca206c236be59d88c69490d`.
Repaired diagnostic binary SHA-256: `ca0f4473ed9ed14bf867c52e4174a9376833b79517512cd3533e1ca841d4ace0`.

The independent execution record is `swarm45-stdio-review-evidence/summary.json`, SHA-256 `eb379b03fb3e24c841ba2243bb90543b9d9897828722cf7296cc0c66a4a43702`. The focused test log is `swarm45-stdio-review-floor-tests.log`, SHA-256 `32bb08d1d2c1f84958b8264696aa30122cddc6d7172fa67dd28e1517617b274a`. Exact source and evidence hashes are also in `swarm45-stdio-review-evidence/source-checkpoint.json`, SHA-256 `2070ecfc4d5c0071632e7ca573633435b86806390c66bc6f7499ae1cf460cde7`. All evidence paths are relative to `/workspace/scratch/038267c40e11`.

No repository source was edited by this reviewer, and earlier reports remain intact. A new frozen source/request and its actual Linux/Windows, native, graphical, package, and full applicable CI evidence must be reviewed after the other active repairs. Physical owner acceptance remains independent.
