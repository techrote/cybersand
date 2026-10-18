class_name CyberActorRigCatalog
extends RefCounted

# Authored rig identities and presentation metadata. Numeric movement tuning
# belongs to the motor. This catalogue never reads Input, World or live actors.
# Consumers receive fresh dictionaries; Color/Vector2 values are internal UI
# configuration, not a JSON policy-publication format.
const SET_IDS: Array[StringName] = [&"setA", &"setB", &"setF", &"setY", &"setU", &"setV"]
const RIG_IDS: Array[StringName] = [
	&"runner", &"skimmer", &"crawler",
	&"scout", &"scrabbler", &"ripper", &"groundeffect", &"digger",
	&"copter", &"pouncer", &"dropbot", &"lineshank",
	&"walljumper", &"clamberer", &"swinger", &"rocketjumper",
	&"springjack", &"gyrocrate", &"bellows", &"winchbug", &"magpie", &"skatesail",
	&"astra", &"claude", &"luna", &"qwen", &"bonsai", &"jev", &"gemini",
]

const _THEMES: Dictionary = {
	&"setA": "Reference controls",
	&"setB": "Ground and near-ground machines",
	&"setF": "Unusual flight and descent",
	&"setY": "Contact, rope and impulse traversal",
	&"setU": "Self-propelled salvage tools",
	&"setV": "Speculative interface personas",
}
const _PERSONA_NOTICE: String = "Fictional interface design; not a claim about any real model's behavior, preferences or capabilities."

const _DEFINITIONS: Dictionary = {
	&"runner": {
		"set": &"setA", "name": "Runner",
		"description": "Responsive ground movement, a buffered variable-height jump and a short horizontal dash.",
		"body_size": Vector2(8, 14), "visual": &"biped", "color": Color(0.30, 0.83, 1.0),
		"channels": ["movement", "primary", "secondary"], "movement_text": "A/D: run; limited air steering",
		"primary": "Jump; release to shorten the rise", "secondary": "Dash on press", "auxiliary": "",
		"limitations": ["Set A retains its original motor and 16-value observation contract."],
	},
	&"skimmer": {
		"set": &"setA", "name": "Skimmer",
		"description": "Direct two-axis powered movement with boost, an unpowered airbrake and rechargeable energy.",
		"body_size": Vector2(8, 14), "visual": &"jet", "color": Color(0.73, 0.57, 1.0),
		"channels": ["movement", "primary", "secondary"], "movement_text": "WASD: two-axis thrust",
		"primary": "Hold boost", "secondary": "Hold unpowered airbrake", "auxiliary": "",
		"limitations": ["Neutral input still powers hover while energy remains; this is not Water buoyancy."],
	},
	&"crawler": {
		"set": &"setA", "name": "Crawler",
		"description": "Strong ground traction, a low hop, supported clamber and an immediate horizontal brace.",
		"body_size": Vector2(8, 14), "visual": &"crawler", "color": Color(1.0, 0.72, 0.28),
		"channels": ["movement", "primary", "secondary"], "movement_text": "A/D: crawl",
		"primary": "Hop", "secondary": "Hold brace", "auxiliary": "",
		"limitations": ["Clamber needs support and a clear intervening path; it does not grant wall adhesion."],
	},
	&"scout": {
		"set": &"setB", "name": "Scout",
		"description": "A nimble scout with quick ground response, a second air jump and automatic supported vaults.",
		"body_size": Vector2(8, 12), "visual": &"biped", "color": Color(0.40, 1.0, 0.67),
		"channels": ["movement", "effort", "primary", "secondary"], "movement_text": "A/D: run and steer",
		"effort_text": "Pace and jump effort", "primary": "Jump or double jump", "secondary": "Hold glide", "auxiliary": "",
		"limitations": ["Automatic vaults require a supported destination and clearance; there is no route planner."],
	},
	&"scrabbler": {
		"set": &"setB", "name": "Scrabbler",
		"description": "A broad, clumsy three-legged robospider that grips surfaces and commits to powerful lunges.",
		"body_size": Vector2(14, 10), "visual": &"tripod", "color": Color(0.93, 0.53, 0.31),
		"channels": ["movement", "aim", "effort", "trim", "primary", "secondary", "auxiliary"],
		"movement_text": "WASD: contact crawl", "aim_text": "Lunge direction", "effort_text": "Lunge effort", "trim_text": "Body torque",
		"primary": "Lunge away from support", "secondary": "Hold three-foot grip", "auxiliary": "Self-right",
		"limitations": ["The three-leg gait is an authored motor/visual model, not three articulated rigid bodies."],
	},
	&"ripper": {
		"set": &"setB", "name": "Ripper",
		"description": "A tracked microtank with separate drive and tilt control, a traction burst and a cutting front.",
		"body_size": Vector2(10, 10), "visual": &"tracks", "color": Color(0.91, 0.78, 0.30),
		"channels": ["movement", "effort", "trim", "primary", "secondary", "auxiliary"],
		"movement_text": "A/D: track direction", "effort_text": "Drive power", "trim_text": "Independent tilt and torque",
		"primary": "Hold cutting tool; press for traction burst", "secondary": "Hold track brake", "auxiliary": "Hold self-right",
		"limitations": ["Track torque and cutting are bounded gameplay rules; protected cells remain authoritative."],
	},
	&"groundeffect": {
		"set": &"setB", "name": "GroundEffect",
		"description": "A soft, slow floating tank that rides a cushion near the ground and settles when braking.",
		"body_size": Vector2(14, 7), "visual": &"hover", "color": Color(0.44, 0.86, 0.77),
		"channels": ["movement", "effort", "trim", "primary", "secondary"],
		"movement_text": "A/D: cruise; W/S: clearance bias", "effort_text": "Fan output", "trim_text": "Pitch",
		"primary": "Lift burst", "secondary": "Hold settling brake", "auxiliary": "",
		"limitations": ["The cushion uses bounded ground-distance sensing; it does not simulate pressure or Water buoyancy."],
	},
	&"digger": {
		"set": &"setB", "name": "Digger",
		"description": "A compact boring head: slow sideways, fast downward, with deliberately limited steering while drilling.",
		"body_size": Vector2(6, 6), "visual": &"drill", "color": Color(0.94, 0.60, 0.26),
		"channels": ["movement", "aim", "effort", "primary", "secondary"],
		"movement_text": "A/D: slow lateral drift", "aim_text": "Drill direction within the downward cone", "effort_text": "Drill power",
		"primary": "Hold downward drill", "secondary": "Hold drill brake", "auxiliary": "",
		"limitations": ["Excavation has a finite radius/work budget; Wall, body masks and out-of-bounds cells are protected."],
	},
	&"copter": {
		"set": &"setF", "name": "Copter",
		"description": "An erratic little rotor drone with body torque, collective power and a stabilizer for deliberate recovery.",
		"body_size": Vector2(12, 8), "visual": &"rotor", "color": Color(0.72, 0.88, 0.31),
		"channels": ["movement", "effort", "trim", "primary", "secondary", "auxiliary"],
		"movement_text": "WASD: directional correction", "effort_text": "Collective power", "trim_text": "Rotor/body torque",
		"primary": "Hold boost", "secondary": "Hold stabilizer", "auxiliary": "Toggle rotor power",
		"limitations": ["Wobble is bounded and actor-local; rotor motion is not fluid aerodynamics."],
	},
	&"pouncer": {
		"set": &"setF", "name": "Pouncer",
		"description": "A low crawling creature that coils for an athletic leap, then glides or tumbles through its descent.",
		"body_size": Vector2(10, 10), "visual": &"quadruped", "color": Color(1.0, 0.48, 0.53),
		"channels": ["movement", "aim", "effort", "trim", "primary", "secondary", "auxiliary"],
		"movement_text": "A/D: crawl and air steering", "aim_text": "Leap direction", "effort_text": "Charge ceiling", "trim_text": "Air attitude",
		"primary": "Hold to coil; release to leap", "secondary": "Hold glide", "auxiliary": "Tumble or dive",
		"limitations": ["Input cancellation discards an armed leap; it must not act like a deliberate release."],
	},
	&"dropbot": {
		"set": &"setF", "name": "Dropbot",
		"description": "A wall-climbing acrobat that brakes its descent, pushes away from surfaces and commits to a divebomb.",
		"body_size": Vector2(10, 10), "visual": &"climber", "color": Color(0.49, 0.78, 1.0),
		"channels": ["movement", "aim", "effort", "trim", "primary", "secondary", "auxiliary"],
		"movement_text": "WASD: wall climb and air correction", "aim_text": "Push-off direction", "effort_text": "Dive effort", "trim_text": "Air attitude",
		"primary": "Acrobatic push-off", "secondary": "Hold grip or airbrake", "auxiliary": "Commit divebomb",
		"limitations": ["Dive impulses/effects are bounded motor rules; no health or combat-damage system is implied."],
	},
	&"lineshank": {
		"set": &"setF", "name": "Lineshank",
		"description": "A knife rig with a bungee harpoon, horizontal slingshot releases and blade-assisted lift.",
		"body_size": Vector2(8, 12), "visual": &"blade", "color": Color(0.87, 0.79, 1.0),
		"channels": ["movement", "aim", "effort", "reel", "primary", "secondary", "auxiliary"],
		"movement_text": "A/D: ground movement and line pumping", "aim_text": "Harpoon and held blade orientation", "effort_text": "Blade lift and bungee strength", "reel_text": "Bungee length",
		"primary": "Fire bungee harpoon", "secondary": "Hold aimed blade; press adds lift pulse", "auxiliary": "Release for slingshot",
		"limitations": ["One bounded straight line is modeled; there is no rope wrapping or articulated knife physics."],
	},
	&"walljumper": {
		"set": &"setY", "name": "Walljumper",
		"description": "Brief wall and ceiling grabs followed by precise aimed leaps; low stamina rewards decisive movement.",
		"body_size": Vector2(8, 14), "visual": &"biped", "color": Color(0.34, 0.94, 0.92),
		"channels": ["movement", "aim", "effort", "primary", "secondary", "auxiliary"],
		"movement_text": "WASD: ground movement and contact creep", "aim_text": "Leap direction", "effort_text": "Leap distance/effort",
		"primary": "Precision leap", "secondary": "Hold brief wall/ceiling grab", "auxiliary": "Release grab",
		"limitations": ["Stamina deliberately limits attachment; leap reach remains subject to collision and gravity."],
	},
	&"clamberer": {
		"set": &"setY", "name": "Clamberer",
		"description": "A patient surface climber with long adhesion, small push-offs and a tucked shape for hiding in gaps.",
		"body_size": Vector2(8, 12), "visual": &"climber", "color": Color(0.62, 0.91, 0.49),
		"channels": ["movement", "aim", "effort", "primary", "secondary", "auxiliary"],
		"movement_text": "WASD: wall and ceiling crawl", "aim_text": "Short push-off direction", "effort_text": "Creep pace",
		"primary": "Short push-off", "secondary": "Hold long adhesion", "auxiliary": "Hold gap tuck",
		"limitations": ["Tuck reduces the hull to 8 by 6; restoration to the full hull requires clear volume."],
	},
	&"swinger": {
		"set": &"setY", "name": "Swinger",
		"description": "A Worms-style rope mover: aim an anchor, pump the swing, change line length and release with momentum.",
		"body_size": Vector2(8, 12), "visual": &"rope", "color": Color(1.0, 0.79, 0.41),
		"channels": ["movement", "aim", "reel", "primary", "secondary"],
		"movement_text": "A/D: ground movement and pendulum pumping", "aim_text": "Anchor direction", "reel_text": "Rope length",
		"primary": "Cast rope", "secondary": "Release rope", "auxiliary": "",
		"limitations": ["The prototype has one straight anchor segment and bounded occlusion checks, without rope wrapping."],
	},
	&"rocketjumper": {
		"set": &"setY", "name": "Rocketjumper",
		"description": "A ground mover that launches from a nearby aimed surface with explosion impulses and trims its flight between blasts.",
		"body_size": Vector2(10, 12), "visual": &"rocket", "color": Color(1.0, 0.48, 0.27),
		"channels": ["movement", "aim", "effort", "trim", "primary", "secondary"],
		"movement_text": "A/D: ground and air steering", "aim_text": "Blast/recoil direction", "effort_text": "Impulse effort", "trim_text": "Air attitude",
		"primary": "Blast against a nearby surface", "secondary": "Hold brace", "auxiliary": "",
		"limitations": ["A nearby aimed surface is required; recoil is authored and protected cells remain intact."],
	},
	&"springjack": {
		"set": &"setU", "name": "Springjack",
		"description": "A salvage piston that crosses rough ground in a held pogo rhythm, then braces to preload the next bounce.",
		"body_size": Vector2(8, 12), "visual": &"piston", "color": Color(0.98, 0.75, 0.30),
		"channels": ["movement", "effort", "trim", "primary", "secondary"],
		"movement_text": "A/D: bounce steering", "effort_text": "Bounce height", "trim_text": "Piston lean",
		"primary": "Hold rhythmic pogo", "secondary": "Hold brace/preload", "auxiliary": "",
		"limitations": ["Repeated hops require held input and actual support; cancellation stops the automatic cadence."],
	},
	&"gyrocrate": {
		"set": &"setU", "name": "Gyrocrate",
		"description": "A rolling flywheel crate that stores spin, spends it on a hop and counterspins to recover its attitude.",
		"body_size": Vector2(10, 10), "visual": &"wheel", "color": Color(0.68, 0.79, 0.82),
		"channels": ["movement", "effort", "trim", "primary", "secondary", "auxiliary"],
		"movement_text": "A/D: rolling drive", "effort_text": "Flywheel power", "trim_text": "Body torque",
		"primary": "Spin up flywheel", "secondary": "Spend spin on a hop", "auxiliary": "Counterspin/self-right",
		"limitations": ["Angular reserve is a bounded controller state, not a rigid-body inertia or mass calibration."],
	},
	&"bellows": {
		"set": &"setU", "name": "Bellows",
		"description": "A pneumatic salvage bag that alternates aimed air pulses with braking breaths to recover pressure.",
		"body_size": Vector2(10, 10), "visual": &"bellows", "color": Color(0.93, 0.64, 0.45),
		"channels": ["movement", "aim", "effort", "primary", "secondary", "auxiliary"],
		"movement_text": "WASD: weak drift correction", "aim_text": "Pulse direction", "effort_text": "Pulse power",
		"primary": "Pneumatic pulse", "secondary": "Hold inhale/brake", "auxiliary": "Vent without thrust",
		"limitations": ["The pressure reserve is a gameplay resource; no gas-region simulation is introduced."],
	},
	&"winchbug": {
		"set": &"setU", "name": "Winchbug",
		"description": "A small hauling machine that anchors above a route, reels itself through it and uses a clutch to settle its swing.",
		"body_size": Vector2(10, 8), "visual": &"winch", "color": Color(0.40, 0.79, 0.74),
		"channels": ["movement", "aim", "effort", "reel", "primary", "secondary", "auxiliary"],
		"movement_text": "A/D: crawl and line pumping", "aim_text": "Anchor direction", "effort_text": "Winch power", "reel_text": "Winch length",
		"primary": "Fire hook", "secondary": "Hold clutch/damping", "auxiliary": "Detach",
		"limitations": ["One bounded anchor and finite winch motion are modeled; the line does not wrap around terrain."],
	},
	&"magpie": {
		"set": &"setU", "name": "Magpie",
		"description": "A salvage clamp that creeps over a surface, sights another perch and spends capacitor charge on a committed lunge.",
		"body_size": Vector2(8, 10), "visual": &"climber", "color": Color(0.77, 0.82, 0.48),
		"channels": ["movement", "aim", "effort", "primary", "secondary", "auxiliary"],
		"movement_text": "WASD: contact creep", "aim_text": "Visible target surface", "effort_text": "Lunge effort",
		"primary": "Capacitor lunge", "secondary": "Hold contact clamp", "auxiliary": "Release clamp",
		"limitations": ["Targeting uses the first bounded visible surface; movement is swept and never teleports."],
	},
	&"skatesail": {
		"set": &"setU", "name": "Skatesail",
		"description": "A salvage skate with a folding sail: build ground speed, pop into the air and trim that speed into lift.",
		"body_size": Vector2(12, 8), "visual": &"sail", "color": Color(0.53, 0.77, 0.94),
		"channels": ["movement", "effort", "trim", "primary", "secondary", "auxiliary"],
		"movement_text": "A/D: ground acceleration and air steering", "effort_text": "Drive power", "trim_text": "Sail incidence",
		"primary": "Pop hop", "secondary": "Hold sail deployed", "auxiliary": "Fold and brake",
		"limitations": ["Lift requires existing speed; the sail does not grant a powered stationary hover."],
	},
	&"astra": {
		"set": &"setV", "name": "Astra / Vector",
		"description": "An imagined vector interface: drift deliberately, direct a separate burst and cancel momentum with counterthrust.",
		"body_size": Vector2(8, 12), "visual": &"jet", "color": Color(0.38, 0.77, 1.0),
		"channels": ["movement", "aim", "effort", "primary", "secondary", "auxiliary"],
		"movement_text": "WASD: controlled drift", "aim_text": "Independent burst direction", "effort_text": "Impulse effort",
		"primary": "Vector burst", "secondary": "Hold counterthrust", "auxiliary": "Toggle assist/coast",
		"persona": "Astra is a speculative vector-control design persona. " + _PERSONA_NOTICE,
	},
	&"claude": {
		"set": &"setV", "name": "Claude / Contour",
		"description": "An imagined contour interface: deliberate surface motion, controlled vaults and soft transitions back to contact.",
		"body_size": Vector2(8, 12), "visual": &"climber", "color": Color(0.93, 0.70, 0.53),
		"channels": ["movement", "aim", "effort", "primary", "secondary", "auxiliary"],
		"movement_text": "WASD: measured surface motion", "aim_text": "Vault/exit direction", "effort_text": "Pace and leap effort",
		"primary": "Controlled vault", "secondary": "Hold adhesion", "auxiliary": "Airbrake/soft landing",
		"persona": "Claude is a speculative surface-control design persona. " + _PERSONA_NOTICE,
	},
	&"luna": {
		"set": &"setV", "name": "Luna / Pulse",
		"description": "An imagined minimal pulse interface: a quick aimed impulse and a strong, immediate damping action.",
		"body_size": Vector2(8, 10), "visual": &"jet", "color": Color(0.76, 0.66, 1.0),
		"channels": ["movement", "aim", "effort", "primary", "secondary"],
		"movement_text": "WASD: light drift correction", "aim_text": "Short pulse direction", "effort_text": "Pulse power",
		"primary": "Quick pulse", "secondary": "Hold strong damping", "auxiliary": "",
		"persona": "Luna is a speculative pulse-control design persona. " + _PERSONA_NOTICE,
	},
	&"qwen": {
		"set": &"setV", "name": "Qwen / Switchboard",
		"description": "An imagined explicit-mode interface that switches between grounded drive and flight while keeping its current mode observable.",
		"body_size": Vector2(10, 10), "visual": &"tracks", "color": Color(0.78, 0.58, 0.95),
		"channels": ["movement", "aim", "effort", "trim", "primary", "secondary", "auxiliary"],
		"movement_text": "WASD: movement in the selected mode", "aim_text": "Action direction", "effort_text": "Drive/thrust power", "trim_text": "Body attitude",
		"primary": "Jump or thrust in the current mode", "secondary": "Hold brake/contact control", "auxiliary": "Switch ground/flight mode",
		"persona": "Qwen is a speculative mode-switching design persona. " + _PERSONA_NOTICE,
	},
	&"bonsai": {
		"set": &"setV", "name": "Bonsai / Root",
		"description": "An imagined compact interface: cling, gather a spring reserve, choose a short leap and tuck into a sheltered gap.",
		"body_size": Vector2(6, 10), "visual": &"climber", "color": Color(0.55, 0.84, 0.42),
		"channels": ["movement", "aim", "effort", "primary", "secondary", "auxiliary"],
		"movement_text": "WASD: compact contact creep", "aim_text": "Spring-leap direction", "effort_text": "Contact pace",
		"primary": "Stored spring leap", "secondary": "Hold long adhesion", "auxiliary": "Hold gap tuck",
		"limitations": ["Tuck reduces the hull to 6 by 6; restoring its height requires clear volume."],
		"persona": "Bonsai is a speculative compact contact-control design persona. " + _PERSONA_NOTICE,
	},
	&"jev": {
		"set": &"setV", "name": "Jev / Jolt",
		"description": "An imagined ricochet interface: commit to a burst, shape a rebound with body torque and counterspin to recover.",
		"body_size": Vector2(10, 10), "visual": &"wheel", "color": Color(1.0, 0.45, 0.59),
		"channels": ["movement", "aim", "effort", "trim", "primary", "secondary", "auxiliary"],
		"movement_text": "WASD: modest steering", "aim_text": "Burst direction", "effort_text": "Burst power", "trim_text": "Body torque",
		"primary": "Ricochet burst", "secondary": "Hold rebound response", "auxiliary": "Counterspin/self-right",
		"limitations": ["Rebounds use detected contact and lose energy; they do not bypass collision sweeps."],
		"persona": "Jev is a speculative ricochet-control design persona. " + _PERSONA_NOTICE,
	},
	&"gemini": {
		"set": &"setV", "name": "Gemini / Duet",
		"description": "An imagined paired-thruster interface: independent left/right actions, differential trim and a synchronized directional burst.",
		"body_size": Vector2(12, 8), "visual": &"twin_rotor", "color": Color(0.49, 0.77, 0.98),
		"channels": ["movement", "aim", "effort", "trim", "primary", "secondary", "auxiliary"],
		"movement_text": "WASD: fine translation", "aim_text": "Paired-burst direction", "effort_text": "Thrust power", "trim_text": "Differential balance",
		"primary": "Left thruster", "secondary": "Right thruster", "auxiliary": "Synchronized burst",
		"persona": "Gemini is a speculative paired-control design persona. " + _PERSONA_NOTICE,
	},
}


static func has_rig(rig_id: StringName) -> bool:
	return _DEFINITIONS.has(rig_id)


static func index_of(rig_id: StringName) -> int:
	return RIG_IDS.find(rig_id)


static func set_for(rig_id: StringName) -> StringName:
	if not has_rig(rig_id):
		return &""
	return _DEFINITIONS[rig_id]["set"]


static func rigs_in_set(set_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for rig_id: StringName in RIG_IDS:
		if set_for(rig_id) == set_id:
			result.append(rig_id)
	return result


static func entry(rig_id: StringName) -> Dictionary:
	if not has_rig(rig_id):
		return {}
	var result: Dictionary = _DEFINITIONS[rig_id].duplicate(true)
	result["id"] = rig_id
	result["theme"] = _THEMES[result["set"]]
	var channels: Array[String] = []
	channels.assign(result["channels"])
	result["channels"] = channels
	# Movement tuning remains motor-owned. Keep this extension field fresh and
	# empty until a separately versioned parameter contract is implemented.
	result["parameters"] = {}
	var limitations: Array[String] = []
	limitations.assign(result.get("limitations", []))
	if result["set"] == &"setV":
		limitations.push_front(_PERSONA_NOTICE)
	limitations.append("Provisional sampled controller; no learned policy or exact replay state is supplied.")
	result["limitations"] = limitations
	result["persona"] = str(result.get("persona", ""))
	return result


static func definition(rig_id: StringName) -> Dictionary:
	return entry(rig_id)


static func name_for(rig_id: StringName) -> String:
	if not has_rig(rig_id):
		return str(rig_id)
	return str(_DEFINITIONS[rig_id]["name"])


static func controls_text(rig_id: StringName) -> String:
	var data: Dictionary = entry(rig_id)
	if data.is_empty():
		return ""
	var lines: Array[String] = []
	lines.append(str(data.get("movement_text", "WASD: movement")))
	if "aim" in data["channels"]:
		lines.append("Mouse: " + str(data.get("aim_text", "aim")))
	if "effort" in data["channels"]:
		lines.append("[ / ]: " + str(data.get("effort_text", "effort")))
	if "trim" in data["channels"]:
		lines.append("Q / E: " + str(data.get("trim_text", "trim")))
	if "reel" in data["channels"]:
		lines.append("Z / X: " + str(data.get("reel_text", "reel")))
	if "primary" in data["channels"]:
		lines.append("Space: " + str(data["primary"]))
	if "secondary" in data["channels"]:
		lines.append("Shift: " + str(data["secondary"]))
	if "auxiliary" in data["channels"]:
		lines.append("C: " + str(data["auxiliary"]))
	return "\n".join(lines)
