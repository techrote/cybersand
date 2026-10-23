class_name CyberPhysicalUsableLoadouts
extends RefCounted

# ACT-005 equipment is authored per mechanism. Every entry resolves an existing
# U01-U32 identity; this table never owns charge, bodies, inventory or cells.
const Usables = preload("res://scripts/usable_catalog.gd")
const VERSION: int = 1
const LOADOUTS: Dictionary = {
	&"runner": [&"brick_stamper", "deposit", 0.55, "Stamp small stepping cover between planted running bursts."],
	&"skimmer": [&"water_lance", "deposit", 0.70, "Sweep a narrow water jet from the moving hover platform."],
	&"crawler": [&"powder_vacuum", "salvage", 0.80, "Clear loose powder from the crawl shoes and nearby route."],
	&"scout": [&"seed_duster", "deposit", 0.65, "Sow short fans during survey patrol, with pauses between patches."],
	&"scrabbler": [&"rotary_borer", "excavate", 0.85, "Brace the tripod and nibble reachable obstructions."],
	&"ripper": [&"borer_round", "breach", 0.90, "Fire penetrating rounds ahead of the sprung track assembly."],
	&"groundeffect": [&"foam_sprayer", "deposit", 0.65, "Lay a visible transient plume along the cushion route."],
	&"digger": [&"rotary_borer", "excavate", 0.95, "Cut the local burrow face while the rocket head advances."],
	&"copter": [&"sticky_delay_charge", "drop", 0.45, "Drop delayed excavation charges during level flight passes."],
	&"pouncer": [&"impact_slug", "breach", 0.85, "Send a chip shot during the controlled part of each leap."],
	&"dropbot": [&"water_contact_charge", "drop", 0.45, "Place a situational payload below a controlled descent."],
	&"lineshank": [&"line_cutter", "excavate", 0.80, "Slice ahead of the weighted grip during a useful swing."],
	&"walljumper": [&"cement_extruder", "deposit", 0.50, "Apply compact cement beads near each contact route."],
	&"clamberer": [&"glass_scorer", "salvage", 0.85, "Score reachable glass while preserving unrelated material."],
	&"swinger": [&"seed_pod", "drop", 0.60, "Cast a seed payload from the outgoing half of a rope swing."],
	&"rocketjumper": [&"oil_igniter", "breach", 0.70, "Demonstrate staged ignition between surface-boost recoveries."],
	&"springjack": [&"cement_blob", "breach", 0.70, "Lob heavy cement from the stabilized part of a pogo cycle."],
	&"gyrocrate": [&"stone_grinder", "processor", 0.70, "Place and revisit a grinder while the gyro holds the crate upright."],
	&"bellows": [&"liquid_drain", "salvage", 0.80, "Drain a nearby pocket between bellows compression strokes."],
	&"winchbug": [&"brine_splitter", "processor", 0.70, "Haul a splitter, lower it, then recover the same device."],
	&"magpie": [&"metal_reclaimer", "processor", 0.70, "Carry and service a local metal-recovery station."],
	&"skatesail": [&"seed_incubator", "processor", 0.65, "Deliver a nursery during a slow grounded sailing interval."],
	&"astra": [&"timer_airburst", "mixed", 0.85, "Vector through a firing pass and time the canister burst."],
	&"claude": [&"glass_reclaimer", "processor", 0.70, "Deliver a glass station, inspect its result, and return for pickup."],
	&"luna": [&"water_capsule", "mixed", 0.75, "Combine brief movement pulses with distinct water-payload shots."],
	&"qwen": [&"cement_finisher", "processor", 0.70, "Switch from travel to a low-speed processor placement window."],
	&"bonsai": [&"seed_incubator", "processor", 0.65, "Plant a compact nursery and keep a short recoverable service route."],
	&"jev": [&"ricochet_pellet", "mixed", 0.90, "Shoot controlled bouncing pellets between vigorous rebound bursts."],
	&"gemini": [&"water_lance", "deposit", 0.65, "Keep paired thrust feedback independent of the water-jet aim."],
	&"monowheel": [&"sand_scatter", "deposit", 0.60, "Scatter short fill fans ahead of the rolling contact patch."],
	&"inchworm": [&"sludge_scrubber", "processor", 0.65, "Draw a scrubber into position with a slow concertina approach."],
	&"pendulum": [&"steam_condenser", "processor", 0.65, "Set a condenser after damping the suspended counterweight."],
	&"rocker": [&"stone_grinder", "processor", 0.70, "Carry a grinder, rock into a placement stance, and recover it."],
	&"hammerhead": [&"sticky_delay_charge", "breach", 0.70, "Place delayed breaching charges from the physical held head."],
	&"rocketblade": [&"acid_wash", "excavate", 0.75, "Apply a reachable acid fan from the moving blade grip."],
	&"tandem": [&"firewarden", "processor", 0.70, "Transport and deploy a suppression unit below the tandem rotors."],
	&"tricopter": [&"timer_airburst", "drop", 0.50, "Drop timed canisters on a controlled three-rotor pass."],
	&"tiltrotor": [&"oil_igniter", "drop", 0.45, "Release staged payloads during a stable transition pass."],
	&"heavylift": [&"stone_grinder", "processor", 0.70, "Transport the suspended processor, lower it, operate it and recover it."],
	&"needlejet": [&"impact_slug", "mixed", 0.90, "Aim brief high-speed firing passes with recovery between shots."],
	&"gyrosled": [&"glass_kiln", "processor", 0.70, "Deliver a heat-dependent kiln from a stabilized ground platform."],
}


static func entry(rig_id: StringName) -> Dictionary:
	if rig_id in [&"4ly_trainer", &"4ly_hauler", &"4ly_drifter", &"4ly_dart"]:
		return {"version": VERSION, "usable_index": -1, "usable_id": "none",
			"preparation": "none", "strategy": "none", "power": 0.0,
			"reason": "4LY training topology is one chassis with no equipment body or mount.",
			"category": "none", "none_reason": "Equipment changes the frozen physical plant.", "transport_seconds": 0.0}
	if rig_id in [&"stuntbuggy", &"trialsbike", &"acrobat", &"arcadelander", &"jetbarrel"]:
		return {"version": VERSION, "usable_index": -1, "usable_id": "none",
			"strategy": "human", "power": 0.8,
			"reason": "Player movement preset; its compact equipment mount starts empty.",
			"category": "none", "none_reason": "Human movement is the default focus.", "transport_seconds": 1.4}
	if not LOADOUTS.has(rig_id):
		return {}
	var row: Array = LOADOUTS[rig_id]
	var index: int = Usables.index_for(row[0])
	return {"version": VERSION, "usable_index": index, "usable_id": str(row[0]),
		"strategy": str(row[1]), "power": float(row[2]), "reason": str(row[3]),
		"category": str(Usables.category_for(index)), "none_reason": "",
		"transport_seconds": 3.0 if rig_id == &"inchworm" else 1.4}


static func all() -> Dictionary:
	var result: Dictionary = {}
	for rig_id: StringName in LOADOUTS:
		result[rig_id] = entry(rig_id)
	for rig_id: StringName in [&"stuntbuggy", &"trialsbike", &"acrobat", &"arcadelander", &"jetbarrel"]:
		result[rig_id] = entry(rig_id)
	return result
