# Active workspace instructions

Read [local development](docs/LOCAL_DEVELOPMENT.md), then [source AGENTS](source/AGENTS.md)
and its required focused documentation before changes. Historical setup/audit
records describe their dated inputs; use [source identity](source/docs/operations/source-checkpoint-and-recovery.md)
for the established Git checkpoints and inspect actual working status.

- Develop/test in `C:/kybersand`; source is `C:/kybersand/source`.
- `C:/cybersand` is for functional deliverables. Keep source edits, toolchains and logs here.
- Godot 4.7 is installed in `C:/Godot47`; `Open-Godot.cmd` opens the editable project.
- The root workspace and source are separate repositories. Use `git -C source`
  for source changes; `.local` and generated outputs are ignored.
- Use `dev.cmd` / `tools/dev.py`, exact pins and separate native/Web bindings.
  Keep local paths in ignored `.local`; never rewrite historical hashes to accept drift.
  Use source current validation and M11 historical integrity as separate gates.
- Godot needs ordinary access to its user-data directory. Past restricted startup
  crashes were environment failures, not solver evidence.
- Follow source ownership and documentation synchronization requirements. Current
  Web threading is synchronous externally; Rapier stays main-thread owned.
- Keep raw test logs in `validation/local`; add scoped evidence summaries to source
  documentation. Do not adopt historical totals as new results.
- Remote mutation requires authorization in the active task. On 2026-09-08 the
  owner authorized pushing the completed work and marking a correctness milestone.
  This supersedes the earlier documentation-only task's no-push scope.

The older Documents workspace is retained history, not the active development
location. The user confirmed a USB backup and explicitly asked to stop looking
for it; do not inspect or search for that backup as part of this task.
