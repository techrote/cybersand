# Local workspace handover

Read `docs/LOCAL_DEVELOPMENT.md`, `LOCAL-DEV-SETUP-REPORT.md`, then
`source/AGENTS.md` and its referenced documentation before changing code.

- M13 is the Web packaging identity; M11 C++ remains authoritative.
- This is a reconstructed `web-demo-m11` snapshot, not the unavailable M13 ZIP.
  There is no active source Git checkout; the retained outer repository has no
  commits and its older source copy is an incomplete backup. Read the current
  [documentation audit](source/docs/audits/2026-09-08-documentation-audit.md)
  for verified identity, evidence scope, and remaining foundational decisions.
- Use `dev.cmd` / `tools/dev.py`; preserve exact versions and separate native/Web bindings.
- Godot requires normal access to its user-data directory. Restricted command
  execution caused startup crashes; do not diagnose those as solver failures.
- Keep tools/local paths in ignored `.local/`; do not alter historical release
  hashes to hide local build differences.
- Web defaults to single-worker compatibility mode. The optional threaded profile
  now uses the owner's 2/4/6 Auto rules and offers reference benchmark/stress tests;
  read docs/WEB_THREADING.md. Both profiles include pinned Rapier2D and Physics
  Pit; see source/docs/operations/rapier-2d-migration-runbook.md. Fully
  asynchronous Web simulation/render ownership remains out of scope.
- No push, PR, upload, deployment or remote mutation is part of this workspace setup.
- Browser results are in `validation/browser-results.json`; raw local logs are
  under `validation/local/`. Do not adopt old package totals as new test results.

## Active locations (user direction, 2026-09-08)

- C:/kybersand is the canonical workspace for human/agent collaboration, development and testing.
- C:/cybersand contains functional deliverables; keep toolchains, source work and test logs here in C:/kybersand.
- Use Godot 4.7 from C:/Godot47. Open the editable project with Open-Godot.cmd.
- Source builds stage under source/build; run Deliver-Web.ps1 to copy the verified Web output to C:/cybersand/web.
- The old Documents/ChatGPT/cybersand workspace is a retained backup; do not continue development there.
