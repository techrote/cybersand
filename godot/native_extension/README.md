# Native Godot extension

**Current integration route, reviewed 2026-09-08.** `CyberNativeCellWorld` wraps
authoritative native World. Desktop uses it when its matching runtime library is
available and retains a distinct GDScript fallback; Web requires its native extension.
This source is now a [Git checkpoint](../../docs/operations/source-checkpoint-and-recovery.md).

The extension owns no scene-tree node or Rapier RID. Desktop's GDScript Thread
exclusively calls its adapter/value APIs; Web calls synchronously on Godot main.
Internal native workers call no Godot APIs. Consult
[ownership](../../docs/architecture/data-ownership-and-lifetimes.md),
[tick order](../../docs/architecture/simulation-tick-and-threading.md) and
[coupling](../../docs/architecture/rigid-body-and-cellular-coupling.md).

`CyberDemoBridge` handles finite level construction/export/import. Export needs
exclusive ownership and clears the transient mask; CYSD1 is not exact replay.
Use the [save contract](../../docs/reference/level-saves-and-replay.md) and
[API reference](../../docs/reference/interfaces-and-message-contracts.md) for details.

[Build instructions](../../docs/operations/local-build-and-validation.md) give exact
pins, native Windows/Linux scripts and separate Web bindings. The active workspace
uses `dev.cmd native-bindings`, `native-build`, `native-test` and `godot-test`.
Close the editor before replacing a Windows DLL. Godot fixture execution alone does
not rebuild it; [dated evidence](../../docs/reference/validation-evidence.md) records hashes.

Historical offline rebuild inputs and ABI floors remain in
[the native lock](../../third_party/native-toolchain.lock.json),
[M11 records](../../docs/audits/m11/README.md) and the executable
[environment helper](../../tools/prepare_native_build_env.sh). The historical
CyberSand Linux floor is GLIBC2.32, GLIBCXX3.4.30 and CXXABI1.3.9; the complete
project needs GLIBC2.34 because of Rapier. Run the floor checker on newly built
ELFs; local Linux pointer files are not runtime validation.
