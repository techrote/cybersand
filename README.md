# CyberSand development workspace

**Current, reviewed 2026-09-08:** work and test in `C:/kybersand`; executable source
is a separate Git checkout in `source/`. The workspace repository tracks these
guides and build wrappers. [Source identity](source/docs/operations/source-checkpoint-and-recovery.md)
records both checkpoints; inspect actual HEAD/status for later changes.

Start with [local setup](docs/LOCAL_DEVELOPMENT.md), [source AGENTS](source/AGENTS.md),
the [focused documentation](source/docs/README.md) and
[foundational roadmap](source/docs/reference/status-and-roadmap.md).

```text
dev.cmd doctor
dev.cmd native-test
dev.cmd godot-test
dev.cmd web
0Preview.cmd
```

Godot 4.7 is in `C:/Godot47`. Use `Open-Godot.cmd` for the editable project.
`C:/cybersand` contains functional deliverables; builds here do not automatically
update them. [START-HERE](START-HERE.md) explains the editor and explicit delivery.

The source was acquired from `web-demo-m11`; the unavailable M13 ZIP was not
extracted or verified. Existing work is locally checkpointed, and the owner has
confirmed a USB backup. [Dated validation](source/docs/reference/validation-evidence.md)
separates historical setup, Windows tests and retained Chromium evidence. No push
or publication was performed in the documentation rewrite.

The [rewrite audit](source/docs/audits/2026-09-08-structural-documentation-audit.md)
and [retrieval evaluation](source/docs/audits/2026-09-08-retrieval-evaluation.md)
record the completed documentation work and remaining foundational issues.

Both histories are now published to the private `techrote/cybersand` repository.
Use the [GitHub milestone instructions](source/docs/audits/2026-09-08-github-milestone.md)
to reconstruct the paired source/workspace checkout at this checkpoint.

Issues #1/#2 and the validation-policy reconciliation are published through
[PR #6](https://github.com/techrote/cybersand/pull/6).
[Current and historical validation](source/docs/operations/current-and-historical-validation.md)
separates rebuilt artifact acceptance from preserved M11 records. The current
paired tags and source commit are recorded in [SOURCE-CHECKPOINT.json](SOURCE-CHECKPOINT.json).

[Correctness publication receipt](docs/CORRECTNESS-CHECKPOINT-2026-09-08.md) records the final paired checkpoint and acceptance.
