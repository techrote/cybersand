# Independent final-CI checkpoint: Documentation, Palette and PLAY

**Three final admission workflows pass at the exact published commit `919134a39d31461947c410c233d59d1965c48414`. No P1/P2 finding in these completed gates. Native C++ and GDExtension completion remain pending separate review; overall admission and physical owner acceptance remain HOLD.**

| Workflow | Exact-head run | Independently observed scope |
| --- | --- | --- |
| Documentation and provenance | [44957191341](https://github.com/techrote/cybersand/actions/runs/44957191341) | One successful job; all steps succeed, including materialised runtime/source validation, dependency/provenance checks, failure contracts and Git LFS fsck |
| Palette shader qualification | [44957211504](https://github.com/techrote/cybersand/actions/runs/44957211504) | Eight successful jobs: plan, six actual Linux/Windows cohorts and final independent readback; registered v3 gate passes |
| PLAY desktop packet identity | [44957219135](https://github.com/techrote/cybersand/actions/runs/44957219135) | Three successful jobs: plan and separate Windows/Linux identity/preflight packets; physical/manual cases remain untested |

All three runs are attempt 1, `workflow_dispatch`, on the dedicated integration branch and exact published head. Run/job/step metadata was independently retrieved from GitHub. Five selected retained artifacts were independently downloaded, checked against GitHub's immutable archive digests and sizes, and compared with their extracted members. This checkpoint does not substitute skipped steps for passing tests.

## Hosted publication materialisation

The Documentation job log confirms execution of `check_repository.py --require-materialized`, no unmaterialised runtime files, and successful Git LFS fsck. The original Windows and Linux PLAY prechecks independently list all 20 retained runtime paths as materialised, including **both newly published reciprocal CLIs and both native adapters**, with empty error/unmaterialised lists. Their native identity records preserve build/source `96b8d3fb…` while their clean checkout identity is published commit `919134a…`, tree `78d6df75…`.

This closes the hosted materialisation concern left by the review machine's pointer-only local checkout. It does not imply that the review machine executed those binaries.

Documentation's material-catalogue parity artifact intentionally names its historical compatibility baseline `0fd4af5987e77db4da3e37c757cf2c0917ae9e15`; that field is not a current build label. Its eight current input/tool hashes match immutable blobs at `919134a…`. The report explicitly limits itself to metadata/constant-query parity and does not claim World, physics or Godot execution. The workflow inventory also passes with no errors.

## Palette result and preserved negative diagnostic

The source-bound readback reports **six cohorts and 19 process cases**, with successful `palette-shader-suite-v3` / `palette-bounded-semantics-v3` admission. The registered cross-backend outgoing CPU-base frames have zero pixels beyond the original **2/255** tolerance. The cohort jobs execute actual native GL on Linux and ANGLE on Windows, followed by retained source/pixel/cache-lineage rereading and final suite reduction.

The same report preserves a **failed older v2 finished-image identity diagnostic**. Six blended/full-current frames each have 11 of 2,304 pixels beyond the older threshold; the maximum recorded RGBA difference is `0.3009393513202667`. The other three base-only frames remain within tolerance. The retained diagnostic expressly distinguishes procedural-finish cross-backend identity from the v3 acceptance predicate. No tolerated-pixel allowance is introduced by this integration.

The reviewer compared the Palette workflow, runner, contract, contract tests and material-palette shader against accepted main `846fe053…`: all five files are byte-identical. Thus the passing v3 result uses the existing accepted policy, not a weakened gate invented for SWARM or a reinterpretation of the failed older diagnostic. It is accurate to say that the registered v3 gate passed; it is inaccurate to claim pixel-identical native/ANGLE finished images. This review inspects the retained reducer, job completion and artifact chain; it does not claim a second independent pixel computation from every large cohort archive.

## PLAY limits and next review

Both PLAY packet manifests and prechecks verify, and their clean-source observations are empty. Every one of the **51 manual result rows per platform remains `untested`**, with no operator or acceptance observations. Their scope is identity/preflight only; the engine is authenticated/extracted without being executed for this packet. Passing this workflow neither performs nor accepts the physical NVIDIA/original-map evaluation required for SWARM.

Native C++ run `44957198003` and GDExtension run `44957204571` still require completed exact-head evidence and independent review. The actual-publication checkpoint is already GO; final CI and physical owner acceptance remain separate gates.

Retained machine checkpoint: `swarm45-publication-review-evidence/final-gates/completed-three-checkpoint.json`, SHA256 `393658b1821e76aca2b412ead125dfc2baf6cee7cb672772fe28324357c487eb`. Adjacent files retain the original selected artifacts, decoded Documentation job log and independent GitHub metadata.

Review was read-only. No source, branches, workflows, PRs or SWARM006 evidence were changed or triggered.
