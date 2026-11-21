# Independent soliding object reuse review

**Source/contract verdict: GO.** Reviewed against accepted main `846fe0533b3170e7b01f690518da49fc40cc24d1`. No confirmed P1, P2 or P3 finding. The reviewed implementation is identified by the exact file hashes in `soliding-source.json`; publication had not yet assigned a candidate commit at review time.

**Merge admission remains pending:** complete exact-source hosted Linux, Windows and Native qualification plus an independently assessed performance result. This source review is not a speed claim.

## Source and failure review

- `Makefile:156–188` retains separate normal and ASan/UBSan object directories. The forced configuration recipe preserves its timestamp only for identical content. All object recipes depend on that configuration and publish by rename after compiler success. Warm failure leaves the old complete object intact but the changed configuration still forces retry.
- `Makefile:190–285` retains all eight soliding executables and the original eight ordered test invocations. Independent raw GNU Make output from the baseline and candidate expands to exactly the same per-executable compiler flags and source order. Physical translation-unit compilations change from **44 to 14 per mode**.
- `tools/ci/native_build_configuration.py:30–61` binds the actual configured compiler/wrapper, reported GCC identity, cc1plus/linker bytes, flags, relevant environment, all core source/header contents, Makefile and helper identity. Failed identity queries fail the build. `:64–80` atomically replaces the configuration record. This is local object reuse, not restoration of prior test outcomes.
- `.github/workflows/documentation.yml:73–85` places the bounded new tests after the unchanged early documentation and materialized-runtime provenance checks from #714. It retains the existing job/status, Draft policy and failure propagation. The inventory artifact describes a dry-run contract; it is not scientific execution evidence.
- Native/GDExtension workflow bytes, the six-family planner, original 20 outer commands, source/run/attempt reducer, watchdog owner and policy remain identical to accepted main. Native code, Godot code, third-party provenance and physics fixtures are unchanged.

## Executed checks

| Check | Outcome |
|---|---|
| Author’s actual Make/GCC regression suite, independently executed | 12 PASS, 46.695 s |
| Native shard/evidence regressions | 45 PASS, 15.357 s |
| Execution policy regressions | 14 PASS, 33.730 s |
| Independent raw Make contract comparison | Both modes PASS; same eight expanded commands and ordered executions |
| Concurrent normal and sanitized targets under `make -j2` | Six isolated core compilations per profile; both binaries execute; warm rebuild compiles zero |
| Corrupt or absent configuration, changed CPATH | Each forces all six core sources to rebuild |
| Actual test exit 17 | Stops after first two tests; no remaining test is represented as run |
| Actual compiler failure | Zero test executions; no partial object publication |
| Provider policy and whitespace | PASS |

The independently devised controls are in `soliding-independent-controls.py` with their results in `soliding-independent-controls.json`. They reuse only the author’s small fixture constructor; the tested operations and assertions were independently selected. `soliding-independent-contract.json` compares actual baseline Make output against the candidate without using the candidate checker’s expected contract.

## Scope and remaining gates

Local compiler controls used GCC 14.2 and synthetic inputs. Complete production soliding scientific execution, hosted GCC 13.3 behavior, Linux/Windows runtime qualification and measured elapsed/runner savings remain the hosted qualification owner’s responsibility. The existing hosted isolation gives each job its own build directory; concurrent separate Make processes with incompatible configurations sharing one directory are not qualified by this change. No production or source file was modified by this reviewer.
