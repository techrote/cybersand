# Qualified Art interface: isolated proposal bridge review

The production proposal bridge is compatible with an explicit owner adapter around the qualified Art Provider interface. A disposable source-only probe passed **43 checks, zero failures** under pinned Godot `4.7.stable.official.5b4e0cb0f`. This does not complete the Art integration: the qualified ordinary Art panel still sends admitted operations to its drawing executor, and no proposal-only owner handoff has been supplied.

## Refreshed source and delivery status

Specialist B independently read the live [run](https://github.com/techrote/cybersand/actions/runs/45497650568), jobs and [PR773](https://github.com/techrote/cybersand/pull/773), and inspected the exact source `fa22d386b802b686c371bb6e12996c7a93c18588`, tree `3245dfc9090a6f37a0e0824325b21e86b59d50a8`. The run completed successfully. The application-source reuse proof and Windows installed-evaluator job passed. The separate Linux job and the fresh Windows application-test step were skipped under that proof; this review does not relabel them as newly executed application passes. The PR remains Draft and explicitly describes Architecture coordination as a future proposal.

The prior `2eedd8f3` extracted-import failure remains historical. It is not the latest Art packaging status, and the final successful run does not establish the unobserved cause of that earlier failure. Physical owner acceptance remains separate.

## Interface findings

The qualified Provider retains `finished(id:int,text:String,response:Dictionary,error:String)`, a positive serial identity and `cancel(reason:String)`. Its `send` method now has an optional eleventh argument, `pre_dispatch_guard: Callable = Callable()`. The guard is checked before request preparation and again immediately before transport admission. The owner must forward the live Architecture guard into that argument; an owner-side check performed only before `send` cannot cover a later asynchronous preparation interval.

In the exact qualified `art_batch_panel.gd`, the panel connects its Provider's `finished` signal to `provider_finished`; `_apply_provider_response` subsequently admits parsed operations through `executor.submit`. Adding another listener to that signal would not establish exclusive proposal ownership. The handoff must supply an owner-controlled dispatch, completion and cancellation route whose response never also enters ordinary automatic painting.

The Architecture bridge itself imports no Provider implementation. It remains limited to request/callback correlation, live-context checks, bounded historical diagnostics and the public Workflow proposal-admission method. It does not select a proposal, preview, approve or apply native operations.

## Isolated execution and retained negatives

The probe copied 42 exact source dependencies into a disposable project. Four Art dependencies came from the qualified `fa22d386` commit: Provider, redaction, response preparation and traffic archive. Architecture dependencies came from `b49a0947e614e09a7807dd35043f20f88e31381b`, with the production bridge unchanged from `3f0f146e8052cfa8f20af5da6cc1cf89cc662d31`. No files were copied into the accepted application or its Art/provider paths. The JSON review inventories all copied dependencies and their SHA-256 values.

The unchanged accepted-base fixture correctly failed to parse because its inherited ten-argument send override no longer matched the qualified Provider's eleven-argument signature. The probe then changed only that disposable override, forwarded the guard, and added two actual Provider checks: an explicit guard refusal occurs before request preparation, and it creates no HTTPRequest, preparation worker or credentials. A first adapted negative still called the guard inside Provider while omitting only the earlier owner-side call; its expected refusal was therefore invalid. That intermediate fixture failure is retained. The corrected negative deliberately omits both guard paths and again proves the bridge refuses an owner that never checks live context.

The final probe passed all 43 checks. Successful dispatches use the controlled send override and inherited Provider signal. The actual qualified Provider runs only its empty-model refusal, idle cancellation and pre-dispatch guard-refusal paths. There were **zero HTTP calls, model calls and native writes**. This is a local compatibility fixture, not a merged application campaign, real inference test or owner acceptance.

| Retained item | SHA-256 |
| --- | --- |
| Final 43-check log, `m67-evidence/proposal-bridge-fa22-adapted.log` | `3a2dcec17533852fb9912d26684dc84274a9613312a83e93a301b0589cfbb462` |
| Original signature refusal, `m67-evidence/proposal-bridge-fa22-unchanged.log` | `fb1fe837677b0756c3b72ddc8eb156afbb957eaea4bfedf8a7ebbd33b8214f18` |
| Intermediate fixture negative, `m67-evidence/proposal-bridge-fa22-adapted-first.log` | `9dd4ea36a09dc52a19915bb71b1b7dfbf5e39b916f14677abc9bf3f807674f80` |
| Probe-only fixture patch | `ed86f357a07f3f6eda518c13881fa9cc3e6c63fdb2d0f73364c40288305f38ab` |
| Pinned Linux Godot executable | `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75` |

The complete evidence inventory is [qualified-art-bridge-review-b.json](qualified-art-bridge-review-b.json). The [fixture patch](qualified-art-bridge-fixture-b.patch) applies only to a disposable project's `tests/test_architecture_proposal_bridge.gd`; it is not an application change. To reproduce, copy each dependency from the exact commit recorded in the JSON, apply that patch, create a minimal Godot 4.7 project without autoloads, and run the fixture with a fresh isolated user-data directory. Completion marker: `ARCHITECTURE_PROPOSAL_BRIDGE: 43 checks, 0 failures`.
