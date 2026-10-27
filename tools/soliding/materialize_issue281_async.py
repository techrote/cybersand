"""One-shot branch-local integration; publishes ordinary inspectable source.

Checks every before/after byte identity against the locally executed overlay.
No main mutation, force push, runtime substitution or downloaded code execution.
Removed with its assembly-only workflow after source is materialized.
"""
from pathlib import Path
import hashlib

ROOT = Path(__file__).resolve().parents[2]
BEFORE = {
    "godot/native_extension/cyber_native_cell_world.hpp": "69e0759a58debc6da6df80cd5c354975356f7c39ddc97e3342195b89d0e8442c",
    "godot/native_extension/cyber_native_cell_world.cpp": "0085475d766b78efc7635ccea4089aeea00b16ba4e7f880046287e55a4f82163",
    "godot/scripts/simulation_worker.gd": "d2744ce1f8ee3ac5410f7f006d304ae138a75dac960f975b643b3d22dd21191b",
}
AFTER = {
    "godot/native_extension/solid_detachment_adapter.inc": "530fe35550daea55fd1604a1659505911ca3c3279a989a392b2784e67c82b13a",
    "godot/native_extension/cyber_native_cell_world.hpp": "dfb707b2855fe71ad43c5d53b1d7b0d88d16feb438a391b8336d4023f10993dc",
    "godot/native_extension/cyber_native_cell_world.cpp": "96cf3f2bbd3cb5b488617a2f200eba6e93d048fe202edf27b8ae694f7ef28038",
    "godot/scripts/simulation_worker.gd": "b8e8c6f84612c9c42145df399b8abfbd40753e8b29e96a2e29a5006595296654",
    "godot/scripts/solid_detachment_worker.gd": "92454d48efd07f8ca256302ae27adb53f60a78cecdf41284df17badf2ea5f5b2",
    "godot/scripts/solid_detachment_session.gd": "eb161afdfeaf5df36b32ff707a68abffcd267870f92297d246912a533fc6fa1b",
    "godot/scripts/solid_detachment_lab.gd": "57199e67952443ad7403dfe2bb4183a176c681e2c2d5060914f895bd97ffbc28",
    "godot/solid_detachment_lab.tscn": "784ae4ea69942f4fd1eb177a7462846fbc27cca57ea0fd1816f1b46b4342668a",
    "godot/tests/test_solid_detachment.gd": "ef539dfa1dadbba8ebe29febb41a7c57e43cb7c712549c7df926fad3ced1ca1b",
    "godot/tests/test_solid_detachment_failures.gd": "8eecda774dbfca8680a10cad67773e8ca6e187c60b9e6e4762279ca628b02319",
}

def once(text, old, new):
    if text.count(old) != 1:
        raise RuntimeError("Nonunique/missing source anchor: " + old[:90])
    return text.replace(old, new, 1)

for path, expected in BEFORE.items():
    if hashlib.sha256((ROOT/path).read_bytes()).hexdigest() != expected:
        raise RuntimeError("Concurrent/unreviewed drift: " + path)

p=ROOT/"godot/native_extension/cyber_native_cell_world.hpp"
s=p.read_text()
s=once(s,"    bool reset_demo_world();",'''    // SOL281 diagnostic-only value facade. Exclusive native owner, no RIDs.
    [[nodiscard]] bool solid_detachment_fenced() const;
    [[nodiscard]] Dictionary solid_detachment_command(const Dictionary& command);

    bool reset_demo_world();''')
# Match the reviewed blank line after logical_processor_count exactly.
s=once(s,"    [[nodiscard]] static std::int64_t logical_processor_count();\n\n    // SOL281", "    [[nodiscard]] static std::int64_t logical_processor_count();\n\n\n    // SOL281")
p.write_text(s)

p=ROOT/"godot/native_extension/cyber_native_cell_world.cpp"
s=p.read_text()
s=once(s,"#include <godot_cpp/variant/utility_functions.hpp>","#include <godot_cpp/variant/utility_functions.hpp>\n#include <godot_cpp/variant/rect2i.hpp>")
s=once(s,"void CyberNativeCellWorld::_bind_methods() {",'''void CyberNativeCellWorld::_bind_methods() {
    ClassDB::bind_method(D_METHOD("solid_detachment_fenced"), &CyberNativeCellWorld::solid_detachment_fenced);
    ClassDB::bind_method(D_METHOD("solid_detachment_command", "command"), &CyberNativeCellWorld::solid_detachment_command);''')
s=once(s,'#include "pressure_optimization_inspection.inc"','#include "pressure_optimization_inspection.inc"\n#include "solid_detachment_adapter.inc"')
p.write_text(s)

p=ROOT/"godot/scripts/simulation_worker.gd"
s=p.read_text()
s=once(s,'if command.has("step") or command.has("reset") or command.has("water_reset")','if command.has("solid_detachment") or command.has("step") or command.has("reset") or command.has("water_reset")')
s=once(s,'func _worker_loop() -> void:','''func _native_representation_fenced() -> bool:
	# Called only by the exclusive native owner, never the UI/main thread.
	return _world.has_method(&"solid_detachment_fenced") and bool(_world.solid_detachment_fenced())


func _worker_loop() -> void:''')
s=once(s,'var physical_wait: bool = not _prepared_physical_publication.is_empty() '+chr(92), 'var physical_wait: bool = _native_representation_fenced() or _lab_request.has("solid_detachment") '+chr(92)+'\n\t\t\tor not _prepared_physical_publication.is_empty() '+chr(92))
s=once(s,'\t\tif not local_player_environment_profile.is_empty():\n\t\t\t_player_environment_profile = ','''\t\tif _native_representation_fenced():
			# Paused ordinary loops still refresh configuration and clear body
			# masks below. A representation transaction must fence those writes
			# as well as ticks, while continuing copied publication and commands.
			# A staged live body cannot be discarded by an unrelated UI reset.
			if local_reset_requested:
				_lab_status = "Reset refused: finish/cancel the native representation transaction"
				_actor_prototype_result_serial = local_actor_prototype_serial
				_actor_prototype_reset_applied = false
				_actor_prototype_status = _lab_status
			_publish_snapshot(0.0, true, local_render_snapshot_interval_usec, false,
				local_rigid_body_states, local_rigid_body_epoch)
			OS.delay_usec(TICK_INTERVAL_USEC)
			next_tick_usec = Time.get_ticks_usec()
			continue
		if not local_player_environment_profile.is_empty():
			_player_environment_profile = ''')
p.write_text(s)

# Correct one transcription typo before enforcing the exact locally tested hash.
p=ROOT/"godot/native_extension/solid_detachment_adapter.inc"
s=p.read_text()
s=once(s,'outcome = world_->rollback_solid_detachment(token);','outcome = world_->rollback_solid_detachment(s.token);')
p.write_text(s)
for path, expected in AFTER.items():
    actual=hashlib.sha256((ROOT/path).read_bytes()).hexdigest()
    if actual != expected:
        raise RuntimeError(f"Tested source mismatch {path}: {actual} != {expected}")
    print(actual,path)
# Final source has no auto-mutating assembly script or preparation workflow.
(ROOT/".github/workflows/sol281-async-assemble.yml").unlink()
(ROOT/".github/workflows/sol281-toolchain.yml").unlink()
Path(__file__).unlink()
