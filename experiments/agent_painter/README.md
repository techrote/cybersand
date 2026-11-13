# Agent-painter shared foundation

New three-family procedural programs, native admission and GitHub-hosted CPU
training for [issue #568](https://github.com/techrote/cybersand/issues/568).
The [operating contract and model-worker handoff](../../docs/operations/agent-painter-foundation.md)
owns APIs, commands, qualification and limits.

This branch starts from accepted `main` at
`ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742` (merged #564/#565).
[SALVAGE.json](SALVAGE.json) identifies the exact read-only #567 and NeuroRunner
donor sources and adaptations. No historical model, compiler, corpus or evidence
is changed or counted as success on the new assignments.

`compiler.py` compiles schema v2 programs; `corpus.py` builds proposals only.
`native/run.py` executes the real Workbench, independently verifies native
material readback and PNGs, and admits the resulting small corpus.
`training/train.py` consumes only the positively admitted TRAIN partition.
The two-update Smol proof establishes optimizer/checkpoint plumbing; useful
neural painting and four full model campaigns remain future work.

Run fast contracts with:

```sh
python3 -m unittest discover -s experiments/agent_painter/tests -p 'test_*.py' -v
```

Changing `qualification-request.json` explicitly requests a new bounded native
build, pilot gallery, CPU proof and fresh-runner checkpoint continuation.
Ordinary PR updates run only the fast contracts. All publication is versioned
research evidence. Keep this PR **Draft/HOLD**; no schedules or merge.
