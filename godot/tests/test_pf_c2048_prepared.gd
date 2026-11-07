extends SceneTree
# PF-C2048 exact-source GDExtension / prepared-host acceptance smoke.
# No historical fixture or production default is rewritten.
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
    run.call_deferred()

func verify(ok: bool, message: String) -> bool:
    checks += 1
    if not ok:
        failures += 1
        push_error("PF_C2048_PREPARED: " + message)
    return ok

func options(cap: int = 1024) -> Dictionary:
    return {
        "region": PackedInt32Array([0, 0, 320, 180]),
        "intent": "exploratory", "pacing": "host_paced",
        "simulation_window_enabled": true, "cadence_lod_enabled": false,
        "liquid_surface_adhesion_enabled": true,
        "maximum_rule_radius": 2, "pressure_gas_compartment_capacity": cap
    }

func run() -> void:
    var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
    var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
    if not verify(bridge != null and world != null and bridge.has_method(&"prepare_liquid_default_demo"),
            "built C2048 native extension and prepared bridge are required"):
        finish()
        return
    if not verify(world.diagnostic_reset({"workers": 1}) and world.reset_demo_world(),
            "ordinary native default demo prerequisite failed"):
        finish()
        return
    var unchanged: String = world.get_physical_state_hash()
    var old_receipt: Dictionary = world.get_applied_liquid_construction_receipt()
    var policy: PackedInt32Array = bridge.default_liquid_policy()
    var requested: PackedInt32Array
    for candidate: Dictionary in bridge.liquid_policy_assignment_choices(policy, 3):
        if candidate.get("accepted", false) and candidate.get("family", "") == "pressure_flow_v1" \
                and candidate.get("variant", "") == "reference":
            requested = candidate.request
            break
    if not verify(not requested.is_empty(), "PF reference policy choice unavailable"):
        finish()
        return
    # Default C1024 must still reject the original full demo without adopting.
    var old_token: int = bridge.prepare_liquid_default_demo(world, requested, options())
    verify(old_token == 0 and world.get_physical_state_hash() == unchanged and not world.has_failed(),
            "original C1024 capacity refusal did not preserve the old healthy owner")
    verify(bridge.get_last_liquid_policy_refusal().get("code", "") == "capacity_refused",
            "C1024 default demo did not provide typed native capacity_refused")
    var malformed := options(2048)
    malformed["pressure_gas_compartment_capacity"] = "2048"
    verify(bridge.prepare_liquid_default_demo(world, requested, malformed) == 0 and
            world.get_physical_state_hash() == unchanged,
            "string-valued capacity bypassed typed refusal")
    verify(bridge.prepare_liquid_default_demo(world, requested, options(2049)) == 0 and
            world.get_physical_state_hash() == unchanged,
            "unsupported capacity bypassed exact admission")
    var token: int = bridge.prepare_liquid_default_demo(world, requested, options(2048))
    if verify(token > 0, "explicit C2048 candidate refused: " + str(bridge.get_last_error())):
        verify(world.get_physical_state_hash() == unchanged and
                world.get_applied_liquid_construction_receipt() == old_receipt,
                "preparing C2048 modified the retained owner/receipt")
        if verify(bridge.commit_liquid_world(world, token), "C2048 prepared candidate failed to commit"):
            var applied: Dictionary = world.get_liquid_solver_policy()
            var parameters: Dictionary = applied.get("family_parameters", {}).get("pressure_flow_v1", {})
            var gas: Dictionary = world.inspect_gas_compartments()
            verify(int(parameters.get("compartment_capacity", 0)) == 2048 and
                    int(gas.get("compartment_capacity", 0)) == 2048 and
                    world.get_physical_state_hash_version() == 5 and
                    world.get_physical_state_format_version() == 5,
                    "applied readback did not identify C2048/CYPS5")
            verify(world.get_liquid_construction_attempt().is_empty(),
                    "successful C2048 adoption retained a previous refusal")
            verify(world.simulation_tick() and not world.has_failed(),
                    "C2048 PF default demo failed its first actual native tick")
            gas = world.inspect_gas_compartments()
            verify(gas.get("ledger", {}).get("closes", false) and
                    gas.get("compartments", []).size() <= 2048,
                    "C2048 gas ledger or compartment capacity failed after tick")
            var saved_level: PackedByteArray = bridge.export_level(world)
            verify(not saved_level.is_empty(), "C2048 level export failed")
            # Ordinary reset must discard PF gas capacity along with the solver.
            verify(world.reset_demo_world() and world.get_physical_state_hash_version() == 2 and
                    not world.inspect_gas_compartments().get("available", false),
                    "C2048 ordinary native reset retained PF-only capacity")
            # An explicit re-adoption may still use C2048 after that reset.
            var again: int = bridge.prepare_liquid_default_demo(world, requested, options(2048))
            if verify(again > 0 and bridge.commit_liquid_world(world, again),
                    "explicit C2048 re-adoption after ordinary reset failed"):
                verify(bridge.import_level(world, saved_level) and
                        world.get_physical_state_hash_version() == 2 and
                        not world.inspect_gas_compartments().get("available", false),
                        "lossy CYSD1 default-family import incorrectly retained C2048")
    finish()

func finish() -> void:
    print("PF_C2048_PREPARED: ", checks, " checks; ", failures, " failures")
    quit(0 if failures == 0 else 1)
