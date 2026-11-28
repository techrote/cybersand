# Q3 publication absence compatibility correction

## Exact failed source and retained evidence

The source was [d9cc40b2da9ab447b9b25eef79158913e01fec01](https://github.com/techrote/cybersand/commit/d9cc40b2da9ab447b9b25eef79158913e01fec01), tree `591aeca0b4741c2f9b2a8eff1cf8f8dad0a3a108`, in [Q3 run 46139433132](https://github.com/techrote/cybersand/actions/runs/46139433132), attempt 1. Its frozen gate failed on both platforms. This source is not retroactively marked passing.

| Original artifact | ZIP bytes | ZIP SHA-256 |
|---|---:|---|
| [Linux 15260559908](https://github.com/techrote/cybersand/actions/runs/46139433132/artifacts/15260559908) | 37063839 | `ec1dc2392ffbcc50d81ecbb3aa2bdd188302617872ab3867e4e0ab56fa9dc65b` |
| [Windows 15261133104](https://github.com/techrote/cybersand/actions/runs/46139433132/artifacts/15261133104) | 18433189 | `cb90960157b18c2f484689fd15a4de6cf46e05e849f911840cd018767f3232ea` |

A separately owned read-only evidence branch, `codex/pubpres-mainline-evidence-001-20261128`, preserves application-source stability while inspecting original artifacts. [Inspection run 46140230163](https://github.com/techrote/cybersand/actions/runs/46140230163) used inspection source `9516e45a3869b053ffb4297620393549db084971`. It authenticated the original application source/tree/run/attempt, both exact artifact identities, original ZIP digest/size/CRC, and all 19 original case identities. It did not check out or execute the application.

## Actual failure, not an inferred final-case result

Both original frozen summaries contain 19 outcomes: 18 valid and one invalid. The invalid process is `test_workbench_physics_publication-slots2`, return code 1, with no timeout and no source mutations.

Its actual 64-check terminal receipt has exactly one failure: `independent-completion physical receipt grants no material upload authority`. The unchanged test requires an early `render_snapshot_serial == 0` with empty material bytes. The first Ambient repair unnecessarily changed that established absence serial to `-1`.

The same original process still recorded exactly one real physical admission while the early native completion's material packing was held, and zero in the combined control. Each platform recorded nine genuine completed callbacks during each registered 150 ms hold window. The other timing, ownership, native feedback, terrain, pause, retirement and shutdown assertions did not fail. These observations do not turn the 64-check case or the frozen gate into a pass.

Original failed stdout SHA-256 values are `4cca84abfff57d05dbfdf5116939fd5103916cbc0a441b10ff7986e94b3a2cd5` on Linux and `1f074b9c9c9cd39134b6761161935b8fc3dfd5c15c234356559d6431a90f716d` on Windows. The complete original archives and failed process records remain in the independent inspection artifacts as well.

## Narrow compatibility repair

The integration owner chose to preserve the established zero-serial absence contract. There was no architectural need to change it.

The resulting source makes exactly three implementation/test-line changes relative to Q3:

- The early worker packet retains `render_snapshot_serial = 0`.
- The session recognizes owner-only delivery by absent render World, zero render serial and both empty material payload arrays.
- The new 49-control immutable-envelope fixture represents that same historical zero serial.

The early packet still explicitly has `render_world_generation = -1` and truthful native World, backend and failure metadata. The Ambient consumer still advances native freshness separately from material authority. Its internal cached-material serial remains `-1` until genuine material arrives. No material identity, image, simulation step or callback is fabricated.

All 19 inherited frozen fixtures, their process population, clock windows, watchdogs and assertions remain byte-identical. The original 130-check native perception fixture also remains unchanged. The compatible source requires its own complete resulting-source campaign; a source review or the previous focused pass cannot substitute for that run.

The principal and specialists A, B and C independently checked the exact three-line difference and its ownership meaning. Local execution remained unavailable; hosted qualification supplies the execution evidence. Mainline promotion and new physical owner acceptance remain HOLD.
