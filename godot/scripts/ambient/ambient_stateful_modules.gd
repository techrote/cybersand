extends RefCounted

# Pure value additions for AMBIENT-002. No live World, node, RID, peer policy
# state or position setter is admitted. All local proposals are finite.
const MAX_PEERS := 31 # Future copied-value seam; the current host supplies at most seven.
const MAX_DIRECTIONS := 8


static func module_specs() -> Dictionary:
	return {
		"investigate_material": {
			"label": "Investigate a discovery",
			"description": "Approach a newly observed material patch, inspect it briefly, then become habituated and release the intention.",
			"category": "Intentions",
			"priority": 42,
			"weight": 1,
			"requires": [
				"materials"
			],
			"capabilities": [
				"horizontal"
			],
			"params": {
				"pace": {
					"type": "number",
					"default": 0.45,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Desired actuator pace; physical speed depends on the rig."
				},
				"effort": {
					"type": "number",
					"default": 0.7,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Existing actuator effort; does not bypass physical resources."
				},
				"commit_seconds": {
					"type": "number",
					"default": 3,
					"min": 0.1,
					"max": 30,
					"unit": "s",
					"description": "Finite utility commitment before a similarly attractive goal may replace this one."
				},
				"material_id": {
					"type": "integer",
					"default": 16,
					"min": 1,
					"max": 131,
					"unit": "ID",
					"description": "Stable native material ID; samples never use rendered colours."
				},
				"radius": {
					"type": "integer",
					"default": 64,
					"min": 1,
					"max": 96,
					"unit": "cells",
					"description": "Inclusive circle around copied actor pose; nearest observed sample only."
				},
				"standoff": {
					"type": "number",
					"default": 12,
					"min": 0,
					"max": 96,
					"unit": "cells",
					"description": "Inspection distance from the observed patch."
				},
				"approach_seconds": {
					"type": "number",
					"default": 12,
					"min": 0.5,
					"max": 60,
					"unit": "s",
					"description": "Finite approach deadline, scaled by persistence."
				},
				"inspect_seconds": {
					"type": "number",
					"default": 2,
					"min": 0,
					"max": 20,
					"unit": "s",
					"description": "Neutral inspection interval after arrival."
				},
				"habituation_seconds": {
					"type": "number",
					"default": 12,
					"min": 0.1,
					"max": 120,
					"unit": "s",
					"description": "Continuous observed exposure that removes novelty."
				},
				"cooldown_seconds": {
					"type": "number",
					"default": 8,
					"min": 0.1,
					"max": 120,
					"unit": "s",
					"description": "Time before another investigation may start."
				}
			},
			"minimum_profile_version": 2
		},
		"explore_unfamiliar": {
			"label": "Explore unfamiliar space",
			"description": "Choose a bounded nearby destination with few remembered visits and low obstruction penalty.",
			"category": "Spatial",
			"priority": 30,
			"weight": 0.9,
			"requires": [
				"pose",
				"bounds"
			],
			"capabilities": [
				"horizontal"
			],
			"params": {
				"pace": {
					"type": "number",
					"default": 0.5,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Desired actuator pace; physical speed depends on the rig."
				},
				"effort": {
					"type": "number",
					"default": 0.7,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Existing actuator effort; does not bypass physical resources."
				},
				"commit_seconds": {
					"type": "number",
					"default": 3,
					"min": 0.1,
					"max": 30,
					"unit": "s",
					"description": "Finite utility commitment before a similarly attractive goal may replace this one."
				},
				"radius": {
					"type": "number",
					"default": 64,
					"min": 12,
					"max": 96,
					"unit": "cells",
					"description": "Local candidate distance; no global route is inferred."
				},
				"arrival_radius": {
					"type": "number",
					"default": 10,
					"min": 1,
					"max": 32,
					"unit": "cells",
					"description": "Destination completion distance."
				},
				"duration": {
					"type": "number",
					"default": 12,
					"min": 0.5,
					"max": 60,
					"unit": "s",
					"description": "Finite destination deadline, scaled by persistence."
				},
				"cooldown_seconds": {
					"type": "number",
					"default": 1,
					"min": 0,
					"max": 30,
					"unit": "s",
					"description": "Pause before choosing another local destination."
				}
			},
			"minimum_profile_version": 2
		},
		"revisit_interest": {
			"label": "Revisit a remembered patch",
			"description": "Return to a retained native-material observation after a delay; the destination is explicitly historical.",
			"category": "Memory",
			"priority": 28,
			"weight": 0.8,
			"requires": [
				"pose",
				"memory"
			],
			"capabilities": [
				"horizontal"
			],
			"params": {
				"pace": {
					"type": "number",
					"default": 0.4,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Desired actuator pace; physical speed depends on the rig."
				},
				"effort": {
					"type": "number",
					"default": 0.7,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Existing actuator effort; does not bypass physical resources."
				},
				"commit_seconds": {
					"type": "number",
					"default": 3,
					"min": 0.1,
					"max": 30,
					"unit": "s",
					"description": "Finite utility commitment before a similarly attractive goal may replace this one."
				},
				"material_id": {
					"type": "integer",
					"default": 16,
					"min": 1,
					"max": 131,
					"unit": "ID",
					"description": "Stable native material ID; samples never use rendered colours."
				},
				"radius": {
					"type": "integer",
					"default": 64,
					"min": 1,
					"max": 96,
					"unit": "cells",
					"description": "Inclusive circle around copied actor pose; nearest observed sample only."
				},
				"minimum_age": {
					"type": "number",
					"default": 8,
					"min": 0,
					"max": 120,
					"unit": "s",
					"description": "Wait this long after last visiting a remembered patch."
				},
				"arrival_radius": {
					"type": "number",
					"default": 12,
					"min": 1,
					"max": 32,
					"unit": "cells",
					"description": "Completion distance from the remembered point."
				},
				"duration": {
					"type": "number",
					"default": 15,
					"min": 0.5,
					"max": 60,
					"unit": "s",
					"description": "Maximum historical-point approach time."
				},
				"cooldown_seconds": {
					"type": "number",
					"default": 10,
					"min": 0.1,
					"max": 120,
					"unit": "s",
					"description": "Finite pause after a revisit attempt."
				}
			},
			"minimum_profile_version": 2
		},
		"patrol_route": {
			"label": "Patrol a route",
			"description": "Traverse a reusable home-relative waypoint sequence with bounded approach deadlines and dwell at each waypoint.",
			"category": "Sequences",
			"priority": 32,
			"weight": 1,
			"requires": [
				"pose",
				"home"
			],
			"capabilities": [
				"horizontal"
			],
			"params": {
				"pace": {
					"type": "number",
					"default": 0.38,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Desired actuator pace; physical speed depends on the rig."
				},
				"effort": {
					"type": "number",
					"default": 0.7,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Existing actuator effort; does not bypass physical resources."
				},
				"commit_seconds": {
					"type": "number",
					"default": 3,
					"min": 0.1,
					"max": 30,
					"unit": "s",
					"description": "Finite utility commitment before a similarly attractive goal may replace this one."
				},
				"points": {
					"type": "points",
					"default": [
						[
							-50,
							0
						],
						[
							50,
							0
						]
					],
					"description": "Two to sixteen [x,y] cell offsets from authored home; edit with the waypoint table."
				},
				"arrival_radius": {
					"type": "number",
					"default": 9,
					"min": 1,
					"max": 32,
					"unit": "cells",
					"description": "Waypoint arrival tolerance."
				},
				"dwell_seconds": {
					"type": "number",
					"default": 2,
					"min": 0,
					"max": 30,
					"unit": "s",
					"description": "Neutral pause at each waypoint."
				},
				"leg_seconds": {
					"type": "number",
					"default": 20,
					"min": 1,
					"max": 120,
					"unit": "s",
					"description": "Per-leg deadline; an unreachable leg advances after this finite interval."
				},
				"loop": {
					"type": "boolean",
					"default": true,
					"description": "Loop the authored route; off traverses it once and releases."
				}
			},
			"minimum_profile_version": 2
		},
		"prefer_region": {
			"label": "Prefer an activity region",
			"description": "Return to an authored home or interest rectangle when outside it; territoriality raises this preference.",
			"category": "Regions",
			"priority": 32,
			"weight": 0.9,
			"requires": [
				"pose",
				"regions"
			],
			"capabilities": [
				"horizontal"
			],
			"params": {
				"pace": {
					"type": "number",
					"default": 0.4,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Desired actuator pace; physical speed depends on the rig."
				},
				"effort": {
					"type": "number",
					"default": 0.7,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Existing actuator effort; does not bypass physical resources."
				},
				"commit_seconds": {
					"type": "number",
					"default": 3,
					"min": 0.1,
					"max": 30,
					"unit": "s",
					"description": "Finite utility commitment before a similarly attractive goal may replace this one."
				},
				"region_id": {
					"type": "region",
					"default": "",
					"region_kind": "interest",
					"description": "Choose an authored interest region; empty selects the first matching region."
				},
				"inset": {
					"type": "number",
					"default": 6,
					"min": 0,
					"max": 64,
					"unit": "cells",
					"description": "Preferred interior margin, clipped for small rectangles."
				},
				"cooldown_seconds": {
					"type": "number",
					"default": 3,
					"min": 0,
					"max": 60,
					"unit": "s",
					"description": "Time between finite region approach attempts."
				},
				"duration": {
					"type": "number",
					"default": 20,
					"min": 1,
					"max": 120,
					"unit": "s",
					"description": "Maximum one approach attempt."
				}
			},
			"minimum_profile_version": 2
		},
		"avoid_region": {
			"label": "Avoid an authored region",
			"description": "A reflex exits an authored avoidance rectangle and its margin through the nearest supported axis.",
			"category": "Regions",
			"priority": 78,
			"weight": 1,
			"requires": [
				"pose",
				"regions"
			],
			"capabilities": [
				"horizontal"
			],
			"params": {
				"pace": {
					"type": "number",
					"default": 0.6,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Desired actuator pace; physical speed depends on the rig."
				},
				"effort": {
					"type": "number",
					"default": 0.8,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Existing actuator effort; does not bypass physical resources."
				},
				"region_id": {
					"type": "region",
					"default": "",
					"region_kind": "avoid",
					"description": "Choose an authored avoid region; empty selects the first matching region."
				},
				"margin": {
					"type": "number",
					"default": 8,
					"min": 0,
					"max": 64,
					"unit": "cells",
					"description": "Extra distance outside the rectangle that remains undesirable."
				}
			},
			"minimum_profile_version": 2
		},
		"search_last_seen": {
			"label": "Search when a target is lost",
			"description": "When a material is no longer observed, inspect bounded offsets around its last observed location, then abandon the search.",
			"category": "Sequences",
			"priority": 38,
			"weight": 0.85,
			"requires": [
				"materials",
				"pose"
			],
			"capabilities": [
				"horizontal"
			],
			"params": {
				"pace": {
					"type": "number",
					"default": 0.35,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Desired actuator pace; physical speed depends on the rig."
				},
				"effort": {
					"type": "number",
					"default": 0.7,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Existing actuator effort; does not bypass physical resources."
				},
				"commit_seconds": {
					"type": "number",
					"default": 3,
					"min": 0.1,
					"max": 30,
					"unit": "s",
					"description": "Finite utility commitment before a similarly attractive goal may replace this one."
				},
				"material_id": {
					"type": "integer",
					"default": 16,
					"min": 1,
					"max": 131,
					"unit": "ID",
					"description": "Stable native material ID; samples never use rendered colours."
				},
				"radius": {
					"type": "integer",
					"default": 64,
					"min": 1,
					"max": 96,
					"unit": "cells",
					"description": "Inclusive circle around copied actor pose; nearest observed sample only."
				},
				"search_radius": {
					"type": "number",
					"default": 18,
					"min": 2,
					"max": 48,
					"unit": "cells",
					"description": "Home-free local search offsets around the last observation."
				},
				"duration": {
					"type": "number",
					"default": 10,
					"min": 0.5,
					"max": 45,
					"unit": "s",
					"description": "One finite search window; stale/unavailable coverage does not trigger loss."
				},
				"leg_seconds": {
					"type": "number",
					"default": 2,
					"min": 0.2,
					"max": 10,
					"unit": "s",
					"description": "Time before selecting the next bounded search offset."
				},
				"cooldown_seconds": {
					"type": "number",
					"default": 8,
					"min": 0,
					"max": 60,
					"unit": "s",
					"description": "Delay before another lost-target search."
				}
			},
			"minimum_profile_version": 2
		},
		"exploration_destination": {
			"label": "Choose a temporary destination",
			"description": "Occasionally select a seeded local destination and pursue it for a finite interval, without a visited-space preference.",
			"category": "Intentions",
			"priority": 22,
			"weight": 0.65,
			"requires": [
				"pose",
				"bounds"
			],
			"capabilities": [
				"horizontal"
			],
			"params": {
				"pace": {
					"type": "number",
					"default": 0.45,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Desired actuator pace; physical speed depends on the rig."
				},
				"effort": {
					"type": "number",
					"default": 0.7,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Existing actuator effort; does not bypass physical resources."
				},
				"commit_seconds": {
					"type": "number",
					"default": 3,
					"min": 0.1,
					"max": 30,
					"unit": "s",
					"description": "Finite utility commitment before a similarly attractive goal may replace this one."
				},
				"radius": {
					"type": "number",
					"default": 72,
					"min": 12,
					"max": 96,
					"unit": "cells",
					"description": "Maximum local target distance inside copied canvas bounds."
				},
				"arrival_radius": {
					"type": "number",
					"default": 10,
					"min": 1,
					"max": 32,
					"unit": "cells",
					"description": "Completion distance."
				},
				"duration": {
					"type": "number",
					"default": 10,
					"min": 0.5,
					"max": 60,
					"unit": "s",
					"description": "Finite commitment deadline."
				},
				"cooldown_seconds": {
					"type": "number",
					"default": 4,
					"min": 0,
					"max": 60,
					"unit": "s",
					"description": "Delay between independently chosen destinations."
				}
			},
			"minimum_profile_version": 2
		},
		"withdraw_obstruction": {
			"label": "Withdraw after repeated failure",
			"description": "Repeated actual nonprogress near observed contact causes a finite retreat and quiet interval; it requires retained obstruction outcomes.",
			"category": "Recovery",
			"priority": 84,
			"weight": 1,
			"requires": [
				"pose",
				"memory"
			],
			"capabilities": [
				"horizontal"
			],
			"params": {
				"pace": {
					"type": "number",
					"default": 0.5,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Desired actuator pace; physical speed depends on the rig."
				},
				"effort": {
					"type": "number",
					"default": 0.85,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Existing actuator effort; does not bypass physical resources."
				},
				"duration": {
					"type": "number",
					"default": 2,
					"min": 0.2,
					"max": 10,
					"unit": "s",
					"description": "Latched retreat after the personality's failed-attempt threshold."
				},
				"quiet_seconds": {
					"type": "number",
					"default": 1,
					"min": 0,
					"max": 10,
					"unit": "s",
					"description": "Neutral interval after withdrawal."
				},
				"cooldown_seconds": {
					"type": "number",
					"default": 5,
					"min": 0.5,
					"max": 60,
					"unit": "s",
					"description": "Time before another repeated-failure withdrawal."
				},
				"radius": {
					"type": "number",
					"default": 30,
					"min": 8,
					"max": 96,
					"unit": "cells",
					"description": "How near a remembered failed approach must be to matter."
				}
			},
			"minimum_profile_version": 2
		},
		"rest_resource": {
			"label": "Rest on low supported energy",
			"description": "Use the actual copied normalized rig energy to select a bounded neutral interval; unavailable resources do not imply exhaustion.",
			"category": "Resources",
			"priority": 62,
			"weight": 1,
			"requires": [
				"resources"
			],
			"capabilities": [],
			"params": {
				"low_fraction": {
					"type": "number",
					"default": 0.2,
					"min": 0,
					"max": 0.99,
					"unit": "fraction",
					"description": "Acquire rest at or below this supported energy fraction."
				},
				"resume_fraction": {
					"type": "number",
					"default": 0.65,
					"min": 0.01,
					"max": 1,
					"unit": "fraction",
					"description": "Release once the observed energy reaches this fraction."
				},
				"maximum_seconds": {
					"type": "number",
					"default": 12,
					"min": 0.1,
					"max": 120,
					"unit": "s",
					"description": "Hard deadline even when an environment cannot replenish energy."
				},
				"cooldown_seconds": {
					"type": "number",
					"default": 3,
					"min": 0.1,
					"max": 60,
					"unit": "s",
					"description": "Time before another resource-rest attempt."
				}
			},
			"minimum_profile_version": 2
		},
		"seek_home_drive": {
			"label": "Return home as exploration wanes",
			"description": "An accumulating simulation-time exploration cycle eventually selects home, pauses there, and releases after recuperation.",
			"category": "Drives",
			"priority": 44,
			"weight": 1,
			"requires": [
				"pose",
				"home"
			],
			"capabilities": [
				"horizontal"
			],
			"params": {
				"pace": {
					"type": "number",
					"default": 0.45,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Desired actuator pace; physical speed depends on the rig."
				},
				"effort": {
					"type": "number",
					"default": 0.7,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Existing actuator effort; does not bypass physical resources."
				},
				"commit_seconds": {
					"type": "number",
					"default": 3,
					"min": 0.1,
					"max": 30,
					"unit": "s",
					"description": "Finite utility commitment before a similarly attractive goal may replace this one."
				},
				"trigger": {
					"type": "number",
					"default": 0.3,
					"min": 0,
					"max": 1,
					"unit": "drive",
					"description": "Return when exploration drive falls below this value; territoriality raises it."
				},
				"arrival_radius": {
					"type": "number",
					"default": 16,
					"min": 1,
					"max": 64,
					"unit": "cells",
					"description": "Home arrival radius using supported movement axes."
				},
				"duration": {
					"type": "number",
					"default": 35,
					"min": 1,
					"max": 180,
					"unit": "s",
					"description": "Finite homeward attempt deadline."
				},
				"rest_seconds": {
					"type": "number",
					"default": 4,
					"min": 0.1,
					"max": 60,
					"unit": "s",
					"description": "Neutral home interval before releasing the goal."
				},
				"cooldown_seconds": {
					"type": "number",
					"default": 8,
					"min": 0,
					"max": 120,
					"unit": "s",
					"description": "Time after a homeward attempt before another."
				}
			},
			"minimum_profile_version": 2
		},
		"observe_actor": {
			"label": "Observe a peer",
			"description": "Latch one copied compatible peer, approach a personality-defined distance, watch briefly, and lose interest.",
			"category": "Social",
			"priority": 34,
			"weight": 0.9,
			"requires": [
				"neighbors"
			],
			"capabilities": [
				"horizontal"
			],
			"params": {
				"pace": {
					"type": "number",
					"default": 0.35,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Desired actuator pace; physical speed depends on the rig."
				},
				"effort": {
					"type": "number",
					"default": 0.7,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Existing actuator effort; does not bypass physical resources."
				},
				"commit_seconds": {
					"type": "number",
					"default": 3,
					"min": 0.1,
					"max": 30,
					"unit": "s",
					"description": "Finite utility commitment before a similarly attractive goal may replace this one."
				},
				"radius": {
					"type": "number",
					"default": 96,
					"min": 8,
					"max": 96,
					"unit": "cells",
					"description": "Maximum copied-peer observation radius."
				},
				"minimum_affinity": {
					"type": "number",
					"default": 0,
					"min": -1,
					"max": 1,
					"unit": "affinity",
					"description": "Minimum authored-tag affinity; -1 allows avoided peers, 0 neutral or preferred, 1 preferred only."
				},
				"tolerance": {
					"type": "number",
					"default": 5,
					"min": 1,
					"max": 32,
					"unit": "cells",
					"description": "Comfort band around the personality's preferred distance."
				},
				"duration": {
					"type": "number",
					"default": 10,
					"min": 0.5,
					"max": 60,
					"unit": "s",
					"description": "Maximum finite peer investigation."
				},
				"watch_seconds": {
					"type": "number",
					"default": 2,
					"min": 0,
					"max": 20,
					"unit": "s",
					"description": "Neutral observation interval at a comfortable distance."
				},
				"cooldown_seconds": {
					"type": "number",
					"default": 5,
					"min": 0,
					"max": 60,
					"unit": "s",
					"description": "Time before selecting another peer."
				}
			},
			"minimum_profile_version": 2
		},
		"regroup": {
			"label": "Regroup with compatible peers",
			"description": "Approach the local centroid of copied peers with admitted affinity; no peer memory or private goal is shared.",
			"category": "Social",
			"priority": 29,
			"weight": 1,
			"requires": [
				"neighbors"
			],
			"capabilities": [
				"horizontal"
			],
			"params": {
				"pace": {
					"type": "number",
					"default": 0.42,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Desired actuator pace; physical speed depends on the rig."
				},
				"effort": {
					"type": "number",
					"default": 0.7,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Existing actuator effort; does not bypass physical resources."
				},
				"commit_seconds": {
					"type": "number",
					"default": 3,
					"min": 0.1,
					"max": 30,
					"unit": "s",
					"description": "Finite utility commitment before a similarly attractive goal may replace this one."
				},
				"radius": {
					"type": "number",
					"default": 96,
					"min": 8,
					"max": 96,
					"unit": "cells",
					"description": "Maximum copied-peer observation radius."
				},
				"minimum_affinity": {
					"type": "number",
					"default": 0,
					"min": -1,
					"max": 1,
					"unit": "affinity",
					"description": "Minimum authored-tag affinity; -1 allows avoided peers, 0 neutral or preferred, 1 preferred only."
				},
				"tolerance": {
					"type": "number",
					"default": 6,
					"min": 1,
					"max": 32,
					"unit": "cells",
					"description": "Comfort tolerance around personality distance."
				},
				"minimum_peers": {
					"type": "integer",
					"default": 1,
					"min": 1,
					"max": 7,
					"unit": "peers",
					"description": "Minimum actually copied compatible peers needed to form a local group."
				}
			},
			"minimum_profile_version": 2
		},
		"align_peers": {
			"label": "Loosely align with peers",
			"description": "A continuous influence follows the average copied peer velocity, without inventing a shared leader or destination.",
			"category": "Social",
			"priority": 24,
			"weight": 0.6,
			"requires": [
				"neighbors"
			],
			"capabilities": [
				"horizontal"
			],
			"params": {
				"pace": {
					"type": "number",
					"default": 0.4,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Desired actuator pace; physical speed depends on the rig."
				},
				"effort": {
					"type": "number",
					"default": 0.7,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Existing actuator effort; does not bypass physical resources."
				},
				"radius": {
					"type": "number",
					"default": 96,
					"min": 8,
					"max": 96,
					"unit": "cells",
					"description": "Maximum copied-peer observation radius."
				},
				"minimum_affinity": {
					"type": "number",
					"default": 0,
					"min": -1,
					"max": 1,
					"unit": "affinity",
					"description": "Minimum authored-tag affinity; -1 allows avoided peers, 0 neutral or preferred, 1 preferred only."
				},
				"minimum_speed": {
					"type": "number",
					"default": 2,
					"min": 0.1,
					"max": 60,
					"unit": "cells/s",
					"description": "Ignore peers whose observed velocity is below this magnitude."
				}
			},
			"minimum_profile_version": 2
		},
		"disperse": {
			"label": "Disperse after congregation",
			"description": "A locally crowded group triggers one finite outward intention and a cooldown, permitting congregation and dissolution.",
			"category": "Social",
			"priority": 39,
			"weight": 0.9,
			"requires": [
				"neighbors"
			],
			"capabilities": [
				"horizontal"
			],
			"params": {
				"pace": {
					"type": "number",
					"default": 0.5,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Desired actuator pace; physical speed depends on the rig."
				},
				"effort": {
					"type": "number",
					"default": 0.7,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Existing actuator effort; does not bypass physical resources."
				},
				"commit_seconds": {
					"type": "number",
					"default": 3,
					"min": 0.1,
					"max": 30,
					"unit": "s",
					"description": "Finite utility commitment before a similarly attractive goal may replace this one."
				},
				"radius": {
					"type": "number",
					"default": 55,
					"min": 4,
					"max": 96,
					"unit": "cells",
					"description": "Local congregation radius."
				},
				"minimum_peers": {
					"type": "integer",
					"default": 2,
					"min": 1,
					"max": 7,
					"unit": "peers",
					"description": "Copied compatible peer count needed to start dispersion."
				},
				"duration": {
					"type": "number",
					"default": 3,
					"min": 0.2,
					"max": 20,
					"unit": "s",
					"description": "One finite outward trip."
				},
				"cooldown_seconds": {
					"type": "number",
					"default": 9,
					"min": 0.1,
					"max": 120,
					"unit": "s",
					"description": "Time before another congregation can trigger dispersion."
				}
			},
			"minimum_profile_version": 2
		},
		"follow_material_boundary": {
			"label": "Follow a material boundary",
			"description": "Steer along an actually sampled local material boundary tangent while correcting observed standoff.",
			"category": "Spatial",
			"priority": 29,
			"weight": 0.85,
			"requires": [
				"materials",
				"boundary"
			],
			"capabilities": [
				"horizontal"
			],
			"params": {
				"pace": {
					"type": "number",
					"default": 0.4,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Desired actuator pace; physical speed depends on the rig."
				},
				"effort": {
					"type": "number",
					"default": 0.7,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Existing actuator effort; does not bypass physical resources."
				},
				"material_id": {
					"type": "integer",
					"default": 16,
					"min": 1,
					"max": 131,
					"unit": "ID",
					"description": "Stable native material ID; samples never use rendered colours."
				},
				"radius": {
					"type": "integer",
					"default": 64,
					"min": 1,
					"max": 96,
					"unit": "cells",
					"description": "Inclusive circle around copied actor pose; nearest observed sample only."
				},
				"standoff": {
					"type": "number",
					"default": 10,
					"min": 0,
					"max": 96,
					"unit": "cells",
					"description": "Desired distance from observed material boundary."
				},
				"tolerance": {
					"type": "number",
					"default": 3,
					"min": 0.1,
					"max": 32,
					"unit": "cells",
					"description": "Standoff comfort band."
				},
				"clockwise": {
					"type": "boolean",
					"default": true,
					"description": "Choose a stable orientation along the copied boundary tangent."
				}
			},
			"minimum_profile_version": 2
		},
		"steer_obstacles": {
			"label": "Steer around local obstacles",
			"description": "A short-lived local steering influence selects a copied clear direction when the requested direction is obstructed.",
			"category": "Recovery",
			"priority": 50,
			"weight": 1.8,
			"requires": [
				"navigation"
			],
			"capabilities": [
				"horizontal"
			],
			"params": {
				"pace": {
					"type": "number",
					"default": 0.42,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Desired actuator pace; physical speed depends on the rig."
				},
				"effort": {
					"type": "number",
					"default": 0.7,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Existing actuator effort; does not bypass physical resources."
				},
				"clearance": {
					"type": "number",
					"default": 8,
					"min": 1,
					"max": 24,
					"unit": "cells",
					"description": "Preferred observed hull clearance; caution scales the requirement."
				},
				"max_turn_seconds": {
					"type": "number",
					"default": 1.5,
					"min": 0.1,
					"max": 6,
					"unit": "s",
					"description": "Maximum latched alternative heading before reassessing the current goal."
				}
			},
			"minimum_profile_version": 2
		},
		"avoid_peer": {
			"label": "Avoid disliked peers",
			"description": "Authored negative tag affinity or a chosen avoided peer triggers a local retreat inside the configured distance.",
			"category": "Social",
			"priority": 76,
			"weight": 1,
			"requires": [
				"neighbors"
			],
			"capabilities": [
				"horizontal"
			],
			"params": {
				"pace": {
					"type": "number",
					"default": 0.55,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Desired actuator pace; physical speed depends on the rig."
				},
				"effort": {
					"type": "number",
					"default": 0.8,
					"min": 0,
					"max": 1,
					"unit": "fraction",
					"description": "Existing actuator effort; does not bypass physical resources."
				},
				"radius": {
					"type": "number",
					"default": 50,
					"min": 4,
					"max": 96,
					"unit": "cells",
					"description": "Maximum distance at which a copied negative-affinity peer causes retreat."
				},
				"release_distance": {
					"type": "number",
					"default": 64,
					"min": 4,
					"max": 96,
					"unit": "cells",
					"description": "Retreat release distance; it must not be smaller than entry radius."
				}
			},
			"minimum_profile_version": 2
		}
	}


static func _inactive(reason: String) -> Dictionary:
	return {"active":false,"reason":reason,"direction":Vector2.ZERO,"pace":0.0,"effort":0.0}


static func _random(state: Dictionary) -> float:
	state.rng = (int(state.get("rng",1)) * 1103515245 + 12345) & 0x7fffffff
	return float(state.rng) / 2147483648.0


static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _trait(context: Dictionary, key: String, fallback: float = 0.5) -> float:
	return float(context.get("personality",{}).get(key,fallback))


static func _direction(value: Vector2, context: Dictionary) -> Vector2:
	var result: Vector2 = value
	if not bool(context.get("capabilities",{}).get("vertical",false)): result.y = 0.0
	return result.normalized() if result.length_squared() > 0.000001 else Vector2.ZERO


static func _distance(first: Vector2, second: Vector2, context: Dictionary) -> float:
	var delta: Vector2 = first - second
	if not bool(context.get("capabilities",{}).get("vertical",false)): delta.y = 0.0
	return delta.length()


static func _duration(seconds: float, context: Dictionary) -> float:
	return seconds * (0.5 + _trait(context,"persistence"))


static func _intent(direction: Vector2, p: Dictionary, reason: String, mode: String = "steer", utility: float = 1.0) -> Dictionary:
	return {"active":true,"reason":reason,"mode":mode,"direction":direction.limit_length(1.0),
		"pace":float(p.get("pace",0.0)) if direction != Vector2.ZERO else 0.0,
		"effort":float(p.get("effort",0.0)),"strength":clampf(utility,0.0,3.0),"primary":false}


static func _goal(direction: Vector2, p: Dictionary, s: Dictionary, reason: String, utility: float = 1.0) -> Dictionary:
	var result: Dictionary = _intent(direction,p,reason,"goal",utility)
	result.goal_key = str(s.get("serial",0))
	result.commit_seconds = float(p.get("commit_seconds",3.0))
	result.phase = str(s.get("phase","approach"))
	result.phase_selected_seconds = float(s.get("phase_selected_seconds",0.0))
	result.target = s.get("target",Vector2.ZERO)
	result.hold = direction == Vector2.ZERO
	result.remaining_seconds = maxf(0.0,float(s.get("until",0.0)) - float(s.get("now",0.0)))
	return result


static func _begin(state: Dictionary, target: Vector2, now: float, duration: float) -> void:
	state.target = target
	state.until = now + duration
	state.now = now
	state.phase = "approach"
	state.phase_selected_seconds = 0.0
	state.active = true
	state.serial = int(state.get("serial",0)) + 1
	state.erase("dwell_until")


static func _retire(state: Dictionary, now: float, cooldown: float) -> void:
	state.active = false
	state.phase = "cooldown"
	state.cooldown_until = now + cooldown


static func _material(o: Dictionary, p: Dictionary) -> Dictionary:
	var materials: Dictionary = o.get("materials",{})
	if not bool(materials.get("available",false)): return {"available":false,"reason":"material coverage unavailable"}
	var targets: Dictionary = materials.get("targets",{})
	var raw: Variant = targets.get(str(int(p.material_id)),{})
	if not raw is Dictionary or not bool(raw.get("available",false)):
		return {"available":false,"reason":"requested material observation unavailable"}
	if not _number(raw.get("radius_cells")) or float(raw.radius_cells) < float(p.radius) or float(raw.radius_cells) > 96.0:
		return {"available":false,"reason":"material observation radius is insufficient"}
	if not bool(raw.get("present",false)): return {"available":true,"present":false}
	var point: Variant = raw.get("nearest")
	var measured: Variant = raw.get("distance")
	if not point is Vector2 or not point.is_finite() or not _number(measured) or float(measured) < 0.0:
		return {"available":false,"reason":"malformed material position or distance"}
	var distance: float = (o.position as Vector2).distance_to(point)
	if absf(distance - float(measured)) > 0.01:
		return {"available":false,"reason":"material position and distance disagree"}
	if distance > float(p.radius): return {"available":true,"present":false}
	return {"available":true,"present":true,"position":point,"distance":distance,"raw":raw}


static func _memory_ready(c: Dictionary) -> bool:
	var memory: Dictionary = c.get("memory",{})
	return not bool(memory.get("enabled",false)) or bool(memory.get("available",false))


static func _cell_key(point: Vector2, size: float) -> String:
	return "%d:%d" % [int(floorf(point.x / size)),int(floorf(point.y / size))]


static func _novelty(c: Dictionary, point: Vector2, material_id: int, habituation: float) -> float:
	var memory: Dictionary = c.get("memory",{})
	if not bool(memory.get("enabled",false)): return 1.0
	if not bool(memory.get("available",false)): return 0.0
	var key: String = str(material_id) + ":" + _cell_key(point,float(memory.get("cell_size",24.0)))
	for entry: Dictionary in memory.get("interests",[]):
		if str(entry.key) == key:
			return clampf(1.0 - float(entry.exposure_seconds) / habituation,0.0,1.0)
	return 1.0


static func _visit_novelty(c: Dictionary, point: Vector2) -> float:
	var memory: Dictionary = c.get("memory",{})
	if not bool(memory.get("enabled",false)): return 1.0
	if not bool(memory.get("available",false)): return 0.0
	var key: String = _cell_key(point,float(memory.get("cell_size",24.0)))
	for entry: Dictionary in memory.get("visited",[]):
		if str(entry.key) == key: return 1.0 / (1.0 + float(entry.entries))
	return 1.0


static func _failure_penalty(c: Dictionary, position: Vector2, direction: Vector2) -> float:
	var memory: Dictionary = c.get("memory",{})
	if not bool(memory.get("available",false)): return 0.0
	var penalty: float = 0.0
	for entry: Dictionary in memory.get("obstructions",[]):
		if position.distance_to(entry.position) <= float(memory.get("cell_size",24.0)) * 1.5 \
			and (entry.direction as Vector2).dot(direction) > 0.65:
			penalty = maxf(penalty,minf(1.0,float(entry.attempts) / maxf(1.0,_trait(c,"failure_tolerance",3.0))))
	return penalty


static func _bounds(o: Dictionary) -> Rect2:
	var group: Dictionary = o.get("bounds",{})
	var rect: Variant = group.get("rect")
	if bool(group.get("available",false)) and rect is Rect2 and rect.position.is_finite() \
		and rect.size.is_finite() and rect.has_area(): return rect
	return Rect2()


static func _clip(point: Vector2, rect: Rect2) -> Vector2:
	var inset: Vector2 = Vector2(minf(8.0,rect.size.x * 0.25),minf(8.0,rect.size.y * 0.25))
	return point.clamp(rect.position + inset,rect.end - inset)


static func _region(c: Dictionary, id: String, kinds: Array) -> Dictionary:
	for raw: Variant in c.get("regions",[]):
		if not raw is Dictionary or str(raw.get("kind","")) not in kinds: continue
		if id.is_empty() or str(raw.get("id","")) == id:
			return {"id":str(raw.id),"rect":Rect2(float(raw.x),float(raw.y),float(raw.width),float(raw.height))}
	return {}


static func _peers(o: Dictionary, p: Dictionary, c: Dictionary, allow_negative: bool = false, prefer_positive: bool = true, respect_peer_id: bool = true) -> Array:
	var group: Dictionary = o.get("neighbors",{})
	if not bool(group.get("available",false)): return []
	var actors: Variant = group.get("actors",[])
	if not actors is Array: return []
	var result: Array = []
	var preferred: Array = []
	var preferred_id: int = int(c.get("relations",{}).get("peer_id",-1))
	for index: int in mini(MAX_PEERS,actors.size()):
		var peer: Variant = actors[index]
		if not peer is Dictionary or not bool(peer.get("compatible",false)): continue
		var position: Variant = peer.get("position")
		if not position is Vector2 or not position.is_finite() or int(peer.get("id",-1)) < 0 \
			or int(peer.id) == int(o.instance_id): continue
		if respect_peer_id and preferred_id >= 0 and int(peer.id) != preferred_id: continue
		if (o.position as Vector2).distance_to(position) > float(p.get("radius",96.0)): continue
		var raw_affinity: Variant = peer.get("affinity",0.0)
		if not _number(raw_affinity) or float(raw_affinity) < -1.0 or float(raw_affinity) > 1.0: continue
		var affinity: float = float(raw_affinity)
		if not allow_negative and affinity < float(p.get("minimum_affinity",0.0)): continue
		result.append(peer)
		if affinity > 0.0: preferred.append(peer)
	# Prefer positive observations when present; otherwise admit neutral peers.
	# Explicit identity and admission are applied before that preference.
	return preferred if prefer_positive and not preferred.is_empty() else result

static func follow_peer(p: Dictionary, o: Dictionary, c: Dictionary) -> Dictionary:
	# Version-1 retains its exact nearest-compatible selector in ambient_modules.
	if not bool(o.get("neighbors",{}).get("available",false)):
		return _inactive("copied neighboring actors unavailable")
	var target: Dictionary = _nearest(_peers(o,p,c),o.position)
	if target.is_empty(): return _inactive("no admitted preferred or neutral peer inside follow radius")
	var distance: float = (o.position as Vector2).distance_to(target.position)
	if absf(distance - float(p.separation)) <= float(p.hysteresis):
		return _inactive("selected peer inside preferred separation band")
	var delta: Vector2 = target.position - o.position
	if distance < float(p.separation): delta = -delta
	var direction: Vector2 = _direction(delta,c)
	if direction == Vector2.ZERO: return _inactive("selected peer has no supported movement-axis direction")
	var result: Dictionary = _intent(direction,p,"following the selected authored-affinity peer at comfortable separation")
	result.target_actor = int(target.id)
	result.distance = distance
	return result


static func _nearest(peers: Array, position: Vector2) -> Dictionary:
	var selected: Dictionary = {}
	var distance: float = INF
	for peer: Dictionary in peers:
		var current: float = position.distance_to(peer.position)
		if current < distance or (is_equal_approx(current,distance) and int(peer.id) < int(selected.get("id",2147483647))):
			selected = peer
			distance = current
	return selected


static func evaluate(module: Dictionary, observation: Dictionary, state: Dictionary, now: float, delta: float, context: Dictionary) -> Dictionary:
	var p: Dictionary = module.params
	state.now = now
	# Only an admitted interval selected in this same phase contributes dwell.
	# Eligible but suppressed proposals still keep their absolute deadlines.
	if str(context.get("last_selected_module","")) == str(module.id) \
		and str(context.get("last_goal_phase","")) == str(state.get("phase","")) \
		and str(context.get("last_goal_key","")) == str(state.get("serial",0)):
		state.phase_selected_seconds = float(state.get("phase_selected_seconds",0.0)) + float(context.get("continuity_delta",0.0))
	match str(module.type):
		"investigate_material": return _investigate(p,observation,state,now,context)
		"explore_unfamiliar": return _explore(p,observation,state,now,context,true)
		"revisit_interest": return _revisit(p,observation,state,now,context)
		"patrol_route": return _patrol(p,observation,state,now,context)
		"prefer_region": return _prefer_region(p,observation,state,now,context)
		"avoid_region": return _avoid_region(p,observation,context)
		"search_last_seen": return _search(p,observation,state,now,context)
		"exploration_destination": return _explore(p,observation,state,now,context,false)
		"withdraw_obstruction": return _withdraw(p,observation,state,now,context)
		"rest_resource": return _resource_rest(p,observation,state,now)
		"seek_home_drive": return _drive_home(p,observation,state,now,context)
		"observe_actor": return _observe_peer(p,observation,state,now,context)
		"regroup": return _regroup(p,observation,state,context)
		"align_peers": return _align(p,observation,context)
		"disperse": return _disperse(p,observation,state,now,context)
		"follow_material_boundary": return _boundary_follow(p,observation,context)
		"steer_obstacles": return _steer_obstacles(p,observation,state,now,delta,context)
		"avoid_peer": return _avoid_peer(p,observation,state,context)
	return _inactive("unknown stateful module")


static func _investigate(p: Dictionary, o: Dictionary, s: Dictionary, now: float, c: Dictionary) -> Dictionary:
	if now < float(s.get("cooldown_until",0.0)): return _inactive("discovery investigation cooldown")
	var material: Dictionary = _material(o,p)
	if not bool(material.available): return _inactive(str(material.reason))
	if not bool(material.present):
		if bool(s.get("active",false)): _retire(s,now,float(p.cooldown_seconds))
		return _inactive("requested material is not currently observed")
	if not _memory_ready(c): return _inactive("World-bound novelty memory unavailable")
	var novelty: float = _novelty(c,material.position,int(p.material_id),float(p.habituation_seconds))
	if not bool(s.get("active",false)):
		if novelty <= 0.05: return _inactive("observed patch is habituated; curiosity turns elsewhere")
		_begin(s,material.position,now,_duration(float(p.approach_seconds),c))
		s.novelty = novelty
	if now >= float(s.until):
		_retire(s,now,float(p.cooldown_seconds))
		return _inactive("finite investigation deadline reached")
	if (s.target as Vector2).distance_to(material.position) <= 24.0: s.target = material.position
	if str(s.phase) == "inspect":
		if float(s.get("phase_selected_seconds",0.0)) >= float(p.inspect_seconds):
			_retire(s,now,float(p.cooldown_seconds))
			return _inactive("inspection complete; finite selected interest released")
		return _goal(Vector2.ZERO,p,s,"inspecting a newly observed material patch",0.4 + _trait(c,"curiosity"))
	if _distance(o.position,s.target,c) <= float(p.standoff):
		s.phase = "inspect"
		s.phase_selected_seconds = 0.0
		return _goal(Vector2.ZERO,p,s,"arrived to inspect a material discovery",0.4 + _trait(c,"curiosity"))
	var direction: Vector2 = _direction((s.target as Vector2) - o.position,c)
	if direction == Vector2.ZERO: return _inactive("discovery has no supported approach axis")
	return _goal(direction,p,s,"investigating a novel observed material patch",
		(0.1 + 1.3 * _trait(c,"curiosity")) * maxf(0.08,novelty))


static func _explore(p: Dictionary, o: Dictionary, s: Dictionary, now: float, c: Dictionary, use_visits: bool) -> Dictionary:
	if now < float(s.get("cooldown_until",0.0)): return _inactive("local destination cooldown")
	var rect: Rect2 = _bounds(o)
	if not rect.has_area(): return _inactive("copied canvas bounds unavailable for local destination")
	if use_visits and not _memory_ready(c): return _inactive("World-bound visited-space memory unavailable")
	if bool(s.get("active",false)):
		if now >= float(s.until) or _distance(o.position,s.target,c) <= float(p.arrival_radius):
			_retire(s,now,float(p.cooldown_seconds))
			return _inactive("local destination arrived or finite attempt expired")
	else:
		var selected: Vector2 = o.position
		var selected_score: float = -INF
		var selected_novelty: float = 0.0
		var headings: int = 8 if bool(c.capabilities.get("vertical",false)) else 2
		for index: int in headings:
			var angle: float = float(index) * TAU / float(headings)
			var direction: Vector2 = Vector2(cos(angle),sin(angle))
			var distance: float = float(p.radius) * (0.65 + _random(s) * 0.35)
			var point: Vector2 = _clip((o.position as Vector2) + direction * distance,rect)
			if _distance(o.position,point,c) <= float(p.arrival_radius) * 1.5: continue
			var novelty: float = _visit_novelty(c,point) if use_visits else 1.0
			var score: float = (novelty if use_visits else 0.0) + _random(s) * (0.25 if use_visits else 1.0)
			score -= _failure_penalty(c,o.position,direction)
			if score > selected_score:
				selected = point
				selected_score = score
				selected_novelty = novelty
		if selected_score == -INF: return _inactive("canvas offers no distinct local destination")
		_begin(s,selected,now,_duration(float(p.duration),c))
		s.novelty = selected_novelty
	var utility: float = 0.45
	if use_visits:
		utility = (0.25 + _trait(c,"curiosity")) * (0.25 + 0.75 * float(c.get("drives",{}).get("exploration",1.0))) \
			* (0.4 + 0.6 * float(s.novelty))
	return _goal(_direction((s.target as Vector2) - o.position,c),p,s,
		"exploring a less familiar local destination" if use_visits else "pursuing a finite seeded local destination",utility)


static func _revisit(p: Dictionary, o: Dictionary, s: Dictionary, now: float, c: Dictionary) -> Dictionary:
	var memory: Dictionary = c.get("memory",{})
	if not bool(memory.get("available",false)): return _inactive("remembered material locations unavailable or disabled")
	if now < float(s.get("cooldown_until",0.0)): return _inactive("remembered-patch revisit cooldown")
	if not bool(s.get("active",false)):
		var selected: Dictionary = {}
		var score: float = -INF
		for entry: Dictionary in memory.get("interests",[]):
			if int(entry.material_id) != int(p.material_id): continue
			var since_visit: float = now - maxf(float(entry.get("last_visit",-1000.0)),float(entry.first_seen))
			if since_visit < float(p.minimum_age): continue
			var current: float = since_visit - (o.position as Vector2).distance_to(entry.position) * 0.05
			if current > score:
				selected = entry
				score = current
		if selected.is_empty(): return _inactive("no retained patch old enough to revisit")
		_begin(s,selected.position,now,_duration(float(p.duration),c))
		s.memory_key = str(selected.key)
	var retained: bool = false
	for entry: Dictionary in memory.get("interests",[]):
		if str(entry.get("key","")) == str(s.get("memory_key","")): retained = true
	if not retained:
		_retire(s,now,float(p.cooldown_seconds))
		return _inactive("historical interest expired or was evicted; revisit released")
	if now >= float(s.until) or _distance(o.position,s.target,c) <= float(p.arrival_radius):
		_retire(s,now,float(p.cooldown_seconds))
		return _inactive("remembered destination reached or revisit deadline expired")
	return _goal(_direction((s.target as Vector2) - o.position,c),p,s,
		"returning to a historical material observation; presence is unconfirmed",0.45 + 0.5 * _trait(c,"persistence"))


static func _next_patrol(s: Dictionary, count: int, loop: bool) -> void:
	s.index = int(s.get("index",0)) + 1
	s.active = false
	s.erase("dwell_until")
	s.phase_selected_seconds = 0.0
	if int(s.index) >= count:
		if loop: s.index = 0
		else: s.finished = true


static func _patrol(p: Dictionary, o: Dictionary, s: Dictionary, now: float, c: Dictionary) -> Dictionary:
	if bool(s.get("finished",false)): return _inactive("finite authored patrol completed")
	var home: Variant = c.get("home")
	if not home is Vector2: return _inactive("patrol home unavailable")
	if not bool(s.get("active",false)):
		var index: int = int(s.get("index",0))
		var point: Array = p.points[index]
		var target: Vector2 = home + Vector2(float(point[0]),float(point[1]))
		var rect: Rect2 = _bounds(o)
		if rect.has_area() and not rect.has_point(target):
			_next_patrol(s,p.points.size(),bool(p.loop))
			return _inactive("patrol waypoint lies outside copied canvas; one leg skipped")
		_begin(s,target,now,_duration(float(p.leg_seconds),c))
	if str(s.phase) == "dwell":
		if float(s.get("phase_selected_seconds",0.0)) >= float(p.dwell_seconds):
			_next_patrol(s,p.points.size(),bool(p.loop))
			return _inactive("patrol waypoint selected dwell complete")
		if now >= float(s.until):
			_next_patrol(s,p.points.size(),bool(p.loop))
			return _inactive("patrol dwell interruption deadline reached; waypoint skipped")
		return _goal(Vector2.ZERO,p,s,"resting at an authored patrol waypoint",0.9)
	if now >= float(s.until):
		_next_patrol(s,p.points.size(),bool(p.loop))
		return _inactive("patrol leg deadline reached; unreachable leg skipped")
	if _distance(o.position,s.target,c) <= float(p.arrival_radius):
		s.phase = "dwell"
		s.phase_selected_seconds = 0.0
		s.until = now + maxf(1.0,float(p.dwell_seconds) * 4.0)
		return _goal(Vector2.ZERO,p,s,"arrived at an authored patrol waypoint",0.9)
	return _goal(_direction((s.target as Vector2) - o.position,c),p,s,"following the authored waypoint sequence",0.9)


static func _prefer_region(p: Dictionary, o: Dictionary, s: Dictionary, now: float, c: Dictionary) -> Dictionary:
	var region: Dictionary = _region(c,str(p.region_id),["interest","home"])
	if region.is_empty(): return _inactive("no matching authored activity or home region")
	var rect: Rect2 = region.rect
	var inset: Vector2 = Vector2(minf(float(p.inset),rect.size.x * 0.25),minf(float(p.inset),rect.size.y * 0.25))
	var inside: Rect2 = Rect2(rect.position + inset,rect.size - inset * 2.0)
	var in_region: bool = inside.has_point(o.position) if bool(c.capabilities.get("vertical",false)) \
		else float(o.position.x) >= inside.position.x and float(o.position.x) <= inside.end.x
	if in_region:
		s.active = false
		return _inactive("inside the authored preferred region")
	if now < float(s.get("cooldown_until",0.0)): return _inactive("preferred-region approach cooldown")
	if not bool(s.get("active",false)): _begin(s,inside.get_center(),now,_duration(float(p.duration),c))
	if now >= float(s.until):
		_retire(s,now,float(p.cooldown_seconds))
		return _inactive("preferred-region approach expired")
	return _goal(_direction((s.target as Vector2) - o.position,c),p,s,"returning to an authored preferred region",
		0.3 + _trait(c,"territoriality"))


static func _avoid_region(p: Dictionary, o: Dictionary, c: Dictionary) -> Dictionary:
	var region: Dictionary = _region(c,str(p.region_id),["avoid"])
	if region.is_empty(): return _inactive("no matching authored avoidance region")
	var rect: Rect2 = (region.rect as Rect2).grow(float(p.margin))
	if not rect.has_point(o.position): return _inactive("outside the authored avoidance region")
	var choices: Array = [
		{"direction":Vector2.LEFT,"distance":float(o.position.x) - rect.position.x},
		{"direction":Vector2.RIGHT,"distance":rect.end.x - float(o.position.x)}]
	if bool(c.capabilities.get("vertical",false)):
		choices.append({"direction":Vector2.UP,"distance":float(o.position.y) - rect.position.y})
		choices.append({"direction":Vector2.DOWN,"distance":rect.end.y - float(o.position.y)})
	var chosen: Dictionary = choices[0]
	for choice: Dictionary in choices:
		if float(choice.distance) < float(chosen.distance): chosen = choice
	return _intent(chosen.direction,p,"leaving an authored avoidance region","override")


static func _search(p: Dictionary, o: Dictionary, s: Dictionary, now: float, c: Dictionary) -> Dictionary:
	var material: Dictionary = _material(o,p)
	if bool(material.available) and bool(material.get("present",false)):
		s.last_seen = material.position
		s.last_seen_time = now
		s.was_seen = true
		s.active = false
		return _inactive("target remains observed; local loss search is unnecessary")
	var lifetime: float = float(c.get("memory",{}).get("lifetime_seconds",90.0))
	if (bool(s.get("was_seen",false)) or bool(s.get("active",false))) and now - float(s.get("last_seen_time",now)) >= lifetime:
		s.was_seen = false
		_retire(s,now,float(p.cooldown_seconds))
		return _inactive("last observed material location expired; search forgotten")
	if not bool(material.available): return _inactive("lost-target search waits for available material coverage")
	if now < float(s.get("cooldown_until",0.0)): return _inactive("lost-target search cooldown")
	if not bool(s.get("active",false)):
		if not bool(s.get("was_seen",false)): return _inactive("no last observed material point to search")
		_begin(s,s.last_seen,now,_duration(float(p.duration),c))
		s.was_seen = false
		s.next_leg = now
	if now >= float(s.until):
		_retire(s,now,float(p.cooldown_seconds))
		return _inactive("finite lost-target search exhausted")
	if now >= float(s.get("next_leg",now)):
		var count: int = 8 if bool(c.capabilities.get("vertical",false)) else 2
		var phase: int = int(s.get("search_leg",0))
		var angle: float = float(phase % count) * TAU / float(count)
		var fraction: float = minf(1.0,0.4 + float(phase / count) * 0.2)
		var target: Vector2 = (s.last_seen as Vector2) + Vector2(cos(angle),sin(angle)) * float(p.search_radius) * fraction
		var rect: Rect2 = _bounds(o)
		s.target = _clip(target,rect) if rect.has_area() else target
		s.next_leg = now + float(p.leg_seconds)
		s.search_leg = phase + 1
		s.phase = "search"
	return _goal(_direction((s.target as Vector2) - o.position,c),p,s,
		"searching bounded offsets around the last observed material",0.6 + 0.4 * _trait(c,"persistence"))


static func _withdraw(p: Dictionary, o: Dictionary, s: Dictionary, now: float, c: Dictionary) -> Dictionary:
	if now < float(s.get("retreat_until",0.0)):
		var retained: Dictionary = _intent(s.retreat,p,"withdrawing from repeated failed approaches","override")
		retained.remaining_seconds = float(s.retreat_until) - now
		return retained
	if now < float(s.get("quiet_until",0.0)):
		var quiet: Dictionary = _intent(Vector2.ZERO,p,"quiet interval after repeated-obstruction withdrawal","override")
		quiet.remaining_seconds = float(s.quiet_until) - now
		return quiet
	if now < float(s.get("cooldown_until",0.0)): return _inactive("repeated-obstruction withdrawal cooldown")
	var memory: Dictionary = c.get("memory",{})
	if not bool(memory.get("available",false)): return _inactive("bounded obstruction memory unavailable or disabled")
	var chosen: Dictionary = {}
	var threshold: float = _trait(c,"failure_tolerance",3.0)
	for entry: Dictionary in memory.get("obstructions",[]):
		if (o.position as Vector2).distance_to(entry.position) > float(p.radius) or float(entry.attempts) < threshold: continue
		if chosen.is_empty() or int(entry.attempts) > int(chosen.attempts): chosen = entry
	if chosen.is_empty(): return _inactive("remembered failed approaches remain below personality tolerance")
	var direction: Vector2 = _direction(-(chosen.direction as Vector2),c)
	if direction == Vector2.ZERO: return _inactive("remembered obstruction has no supported retreat axis")
	s.retreat = direction
	s.retreat_until = now + float(p.duration)
	s.quiet_until = float(s.retreat_until) + float(p.quiet_seconds)
	s.cooldown_until = float(s.quiet_until) + float(p.cooldown_seconds)
	var result: Dictionary = _intent(direction,p,"repeated failed approaches triggered a finite withdrawal","override")
	result.remaining_seconds = float(p.duration)
	return result


static func _resource_rest(p: Dictionary, o: Dictionary, s: Dictionary, now: float) -> Dictionary:
	var resources: Dictionary = o.get("resources",{})
	if not bool(resources.get("available",false)) or not _number(resources.get("energy")):
		return _inactive("actual supported energy observation unavailable")
	var energy: float = float(resources.energy)
	if energy < 0.0 or energy > 1.0: return _inactive("energy is outside the supported normalized resource range")
	if bool(s.get("active",false)):
		if now >= float(s.until) or energy >= float(p.resume_fraction):
			_retire(s,now,float(p.cooldown_seconds))
			return _inactive("resource recovered or finite rest deadline expired")
	else:
		if now < float(s.get("cooldown_until",0.0)) or energy > float(p.low_fraction):
			return _inactive("actual energy does not warrant another rest")
		s.active = true
		s.until = now + float(p.maximum_seconds)
	var result: Dictionary = _intent(Vector2.ZERO,p,"neutral rest requested by actual low rig energy","override")
	result.remaining_seconds = maxf(0.0,float(s.until) - now)
	return result


static func _drive_home(p: Dictionary, o: Dictionary, s: Dictionary, now: float, c: Dictionary) -> Dictionary:
	var home: Variant = c.get("home")
	if not home is Vector2: return _inactive("authored home unavailable")
	if now < float(s.get("cooldown_until",0.0)): return _inactive("homeward-cycle cooldown")
	var drive: float = float(c.get("drives",{}).get("exploration",1.0))
	var trigger: float = clampf(float(p.trigger) + (_trait(c,"territoriality") - 0.5) * 0.3,0.0,1.0)
	if not bool(s.get("active",false)):
		if drive > trigger: return _inactive("exploration drive still favours activity")
		_begin(s,home,now,_duration(float(p.duration),c))
	if str(s.phase) == "home_rest":
		if float(s.get("phase_selected_seconds",0.0)) >= float(p.rest_seconds):
			_retire(s,now,float(p.cooldown_seconds))
			return _inactive("finite selected home interval complete; activity may resume")
		if now >= float(s.until):
			_retire(s,now,float(p.cooldown_seconds))
			return _inactive("home rest interruption deadline reached; intention released")
		return _goal(Vector2.ZERO,p,s,"resting at home after an exploration cycle",1.1)
	if now >= float(s.until):
		_retire(s,now,float(p.cooldown_seconds))
		return _inactive("finite homeward attempt expired")
	if _distance(o.position,home,c) <= float(p.arrival_radius):
		s.phase = "home_rest"
		s.phase_selected_seconds = 0.0
		s.until = now + maxf(1.0,float(p.rest_seconds) * 4.0)
		return _goal(Vector2.ZERO,p,s,"arrived home after exploration",1.1)
	return _goal(_direction(home - o.position,c),p,s,"returning home as exploration drive declines",
		0.65 + (1.0 - drive) + _trait(c,"territoriality") * 0.3)


static func _observe_peer(p: Dictionary, o: Dictionary, s: Dictionary, now: float, c: Dictionary) -> Dictionary:
	if not bool(o.get("neighbors",{}).get("available",false)): return _inactive("copied peer observations unavailable")
	if now < float(s.get("cooldown_until",0.0)): return _inactive("peer-investigation cooldown")
	var peers: Array = _peers(o,p,c)
	var target: Dictionary = {}
	if bool(s.get("active",false)):
		for peer: Dictionary in peers:
			if int(peer.id) == int(s.peer_id): target = peer
		if target.is_empty() or now >= float(s.until):
			_retire(s,now,float(p.cooldown_seconds))
			return _inactive("peer left observation scope or finite interest expired")
	else:
		target = _nearest(peers,o.position)
		if target.is_empty(): return _inactive("no admitted peer available to investigate")
		_begin(s,target.position,now,_duration(float(p.duration),c))
		s.peer_id = int(target.id)
	s.target = target.position
	var distance: float = _distance(o.position,target.position,c)
	var preferred: float = minf(_trait(c,"preferred_distance",24.0),float(p.radius) - float(p.tolerance))
	if absf(distance - preferred) <= float(p.tolerance):
		if str(s.phase) != "watch":
			s.phase = "watch"
			s.phase_selected_seconds = 0.0
		if float(s.get("phase_selected_seconds",0.0)) >= float(p.watch_seconds):
			_retire(s,now,float(p.cooldown_seconds))
			return _inactive("peer observation complete; attention released")
		var watching: Dictionary = _goal(Vector2.ZERO,p,s,"watching a copied peer from a comfortable distance",0.25 + _trait(c,"sociability"))
		watching.target_actor = int(target.id)
		return watching
	s.phase = "approach"
	s.phase_selected_seconds = 0.0
	var delta: Vector2 = target.position - o.position
	if distance < preferred: delta = -delta
	var result: Dictionary = _goal(_direction(delta,c),p,s,"approaching a copied peer for a temporary observation",
		0.1 + _trait(c,"sociability") * (0.65 + float(c.get("drives",{}).get("social",0.5)) * 0.5))
	result.target_actor = int(target.id)
	return result


static func _regroup(p: Dictionary, o: Dictionary, s: Dictionary, c: Dictionary) -> Dictionary:
	if not bool(o.get("neighbors",{}).get("available",false)): return _inactive("copied peer observations unavailable")
	var peers: Array = _peers(o,p,c)
	if peers.size() < int(p.minimum_peers): return _inactive("too few admitted copied peers to regroup")
	var centre := Vector2.ZERO
	for peer: Dictionary in peers: centre += peer.position
	centre /= float(peers.size())
	var distance: float = _distance(o.position,centre,c)
	var preferred: float = minf(_trait(c,"preferred_distance",24.0),float(p.radius) - float(p.tolerance))
	if distance <= preferred + float(p.tolerance): return _inactive("local group is within preferred spacing")
	s.target = centre
	s.phase = "regroup"
	var result: Dictionary = _goal(_direction(centre - o.position,c),p,s,"regrouping toward the copied local peer centroid",
		0.15 + _trait(c,"sociability") * (0.5 + float(c.get("drives",{}).get("social",0.5))))
	result.peer_count = peers.size()
	return result


static func _align(p: Dictionary, o: Dictionary, c: Dictionary) -> Dictionary:
	var peers: Array = _peers(o,p,c)
	var velocity := Vector2.ZERO
	var count: int = 0
	for peer: Dictionary in peers:
		var observed: Variant = peer.get("velocity")
		if not observed is Vector2 or not observed.is_finite() or observed.length() < float(p.minimum_speed): continue
		velocity += observed.normalized()
		count += 1
	if count == 0: return _inactive("no admitted moving peer velocity to align with")
	var direction: Vector2 = _direction(velocity,c)
	if direction == Vector2.ZERO: return _inactive("copied peer velocities cancel or lack a supported axis")
	return _intent(direction,p,"loosely aligning with copied peer movement","steer",_trait(c,"sociability"))


static func _disperse(p: Dictionary, o: Dictionary, s: Dictionary, now: float, c: Dictionary) -> Dictionary:
	if now < float(s.get("cooldown_until",0.0)): return _inactive("congregation dispersion cooldown")
	if bool(s.get("active",false)):
		if now >= float(s.until):
			_retire(s,now,float(p.cooldown_seconds))
			return _inactive("finite congregation dispersion complete")
		return _goal(s.direction,p,s,"dispersing after a temporary congregation",0.95)
	var peers: Array = _peers(o,p,c,false,false,false)
	if peers.size() < int(p.minimum_peers): return _inactive("local congregation below dispersion threshold")
	var centre := Vector2.ZERO
	for peer: Dictionary in peers: centre += peer.position
	centre /= float(peers.size())
	var direction: Vector2 = _direction((o.position as Vector2) - centre,c)
	if direction == Vector2.ZERO:
		direction = Vector2.LEFT if int(o.instance_id) % 2 == 0 else Vector2.RIGHT
	_begin(s,(o.position as Vector2) + direction * float(p.radius),now,float(p.duration))
	s.direction = direction
	s.phase = "disperse"
	return _goal(direction,p,s,"temporary congregation triggered a finite dispersion",0.95)


static func _boundary_follow(p: Dictionary, o: Dictionary, c: Dictionary) -> Dictionary:
	var material: Dictionary = _material(o,p)
	if not bool(material.available): return _inactive(str(material.reason))
	if not bool(material.present): return _inactive("requested material boundary is not observed")
	var boundary: Variant = material.raw.get("boundary",{})
	if not boundary is Dictionary or not bool(boundary.get("available",false)):
		return _inactive("actual bounded material-boundary refinement unavailable")
	var normal: Variant = boundary.get("normal")
	var tangent: Variant = boundary.get("tangent")
	if not normal is Vector2 or not tangent is Vector2 or not normal.is_finite() or not tangent.is_finite() \
		or normal.length_squared() < 0.01 or tangent.length_squared() < 0.01:
		return _inactive("malformed observed boundary orientation")
	var direction: Vector2 = tangent.normalized() * (1.0 if bool(p.clockwise) else -1.0)
	var error: float = float(material.distance) - float(p.standoff)
	if absf(error) > float(p.tolerance):
		# The vector to the actual material sample supplies standoff correction;
		# tangent supplies only local edge orientation, never a global route.
		direction += ((material.position as Vector2) - o.position).normalized() * clampf(error / maxf(1.0,float(p.standoff)), -1.0,1.0)
	direction = _direction(direction,c)
	if direction == Vector2.ZERO: return _inactive("observed boundary tangent has no supported movement axis")
	var result: Dictionary = _intent(direction,p,"following an observed material boundary with standoff correction")
	result.target = material.position
	return result


static func _steer_obstacles(p: Dictionary, o: Dictionary, s: Dictionary, now: float, _delta: float, c: Dictionary) -> Dictionary:
	var navigation: Dictionary = o.get("navigation",{})
	if not bool(navigation.get("available",false)):
		s.erase("direction")
		s.erase("until")
		return _inactive("copied local navigation rays unavailable; alternative heading released")
	var rays: Variant = navigation.get("directions",[])
	if not rays is Array:
		s.erase("direction")
		s.erase("until")
		return _inactive("local navigation directions unavailable; alternative heading released")
	var requested: Vector2 = _direction(c.get("last_direction",Vector2.RIGHT),c)
	if requested == Vector2.ZERO:
		s.erase("direction")
		s.erase("until")
		return _inactive("no current motion preference requires obstacle steering")
	var clearance: float = clampf(float(p.clearance) * (0.65 + 0.7 * _trait(c,"caution")),1.0,31.0)
	var retaining: bool = now < float(s.get("until",0.0))
	var retained_direction: Vector2 = s.get("direction",Vector2.ZERO)
	var retained_clear: bool = false
	var blocked: bool = false
	var best_score: float = -INF
	var best := Vector2.ZERO
	for index: int in mini(MAX_DIRECTIONS,rays.size()):
		var ray: Variant = rays[index]
		if not ray is Dictionary or not bool(ray.get("available",false)): continue
		var raw_direction: Variant = ray.get("direction")
		var distance: Variant = ray.get("clearance_cells")
		var maximum: Variant = ray.get("maximum_distance_cells")
		if not raw_direction is Vector2 or not raw_direction.is_finite() or not _number(distance) or not _number(maximum) \
			or float(distance) < 0.0 or float(maximum) <= 0.0 or float(distance) > float(maximum): continue
		# A diagonal free ray does not prove horizontal ground clearance.
		if not bool(c.capabilities.get("vertical",false)) and absf(raw_direction.normalized().y) > 0.01: continue
		var direction: Vector2 = _direction(raw_direction,c)
		if direction == Vector2.ZERO: continue
		var dot: float = direction.dot(requested)
		if dot > 0.7 and bool(ray.get("hit",false)) and float(distance) < clearance: blocked = true
		if float(distance) < clearance or bool(ray.get("boundary",false)): continue
		if retaining and direction.dot(retained_direction) > 0.99: retained_clear = true
		var score: float = dot * 0.5 + float(distance) / float(maximum) * 0.5 - _failure_penalty(c,o.position,direction)
		if score > best_score:
			best_score = score
			best = direction
	# A successful first steering response changes last_direction. Requiring that
	# new direction to be blocked would drop the maneuver after one decision and
	# let attraction alternate right/left on every tick. Retain only the existing
	# finite deadline, and only while THIS copied observation confirms clearance.
	if retaining and retained_clear:
		var retained: Dictionary = _intent(retained_direction,p,"holding a finite locally observed clearer approach","steer",1.2)
		retained.remaining_seconds = float(s.until) - now
		return retained
	s.erase("direction")
	s.erase("until")
	if not blocked: return _inactive("requested direction has no observed nearby obstruction")
	if best == Vector2.ZERO: return _inactive("no adequately observed alternative clearance; recovery may withdraw")
	s.direction = best
	s.until = now + float(p.max_turn_seconds)
	var result: Dictionary = _intent(best,p,"steering toward a locally observed clearer approach","steer",1.2)
	result.remaining_seconds = maxf(0.0,float(s.until) - now)
	return result


static func _avoid_peer(p: Dictionary, o: Dictionary, s: Dictionary, c: Dictionary) -> Dictionary:
	if not bool(o.get("neighbors",{}).get("available",false)): return _inactive("copied peer observations unavailable")
	var expanded: Dictionary = p.duplicate(true)
	expanded.radius = float(p.release_distance)
	var peers: Array = _peers(o,expanded,c,true,false,false)
	var chosen: Dictionary = {}
	for peer: Dictionary in peers:
		if float(peer.get("affinity",0.0)) >= 0.0: continue
		var distance: float = (o.position as Vector2).distance_to(peer.position)
		if distance > float(p.radius) and int(s.get("peer_id",-1)) != int(peer.id): continue
		if chosen.is_empty() or distance < (o.position as Vector2).distance_to(chosen.position): chosen = peer
	if chosen.is_empty():
		s.erase("peer_id")
		return _inactive("no disliked copied peer inside the avoidance band")
	s.peer_id = int(chosen.id)
	var direction: Vector2 = _direction((o.position as Vector2) - chosen.position,c)
	if direction == Vector2.ZERO: direction = Vector2.LEFT if int(o.instance_id) < int(chosen.id) else Vector2.RIGHT
	var result: Dictionary = _intent(direction,p,"retreating from a copied peer with negative authored affinity","override")
	result.target_actor = int(chosen.id)
	return result
