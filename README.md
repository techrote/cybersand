# CyberSand development workspace

**Current scope, reviewed 2026-09-08:** active source is a reconstructed snapshot
with no Git metadata. The retained repository has no commits and its source copy
is an incomplete backup of newer changes. Read the
[current documentation audit](source/docs/audits/2026-09-08-documentation-audit.md)
before foundational work; historical setup evidence is linked separately below.

Start with [docs/LOCAL_DEVELOPMENT.md](docs/LOCAL_DEVELOPMENT.md) and the
[executed setup report](LOCAL-DEV-SETUP-REPORT.md).

On the configured Windows host:

```text
dev.cmd native-test
dev.cmd godot-test
dev.cmd web
0Preview.cmd
```

The M11 C++ engine remains authoritative. This copy was reconstructed from the
user-designated `web-demo-m11` branch because the M13 archive was not supplied.
The report distinguishes executed results from missing-package gates.

Threaded Web uses the owner's Auto worker rules and includes a **Performance**
menu with benchmark and stress tests. See [Web threading](docs/WEB_THREADING.md).
Native reference reports are available with `dev.cmd benchmark` and
`dev.cmd stress-test` after building the native extension.

Both Web profiles include Rapier2D v0.35.2. Choose **Physics Pit** to exercise
rigid bodies against terrain, Water, and Sand. The shared native/browser
acceptance fixture is documented in the
[Rapier runbook](source/docs/operations/rapier-2d-migration-runbook.md).
