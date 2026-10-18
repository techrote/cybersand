extends RefCounted

const HumanWire = preload("res://examples/thunderbowl/human_wire.gd")
const HumanMetal = preload("res://examples/thunderbowl/human_metal.gd")
const WireSeek = preload("res://examples/thunderbowl/wire_seek.gd")
const MetalPulse = preload("res://examples/thunderbowl/metal_pulse.gd")
const Oracle = preload("res://examples/thunderbowl/oracle.gd")
const Lemming = preload("res://examples/thunderbowl/lemming.gd")
const Emergent = preload("res://examples/thunderbowl/emergent.gd")
const LocalSwarm = preload("res://examples/thunderbowl/local_swarm.gd")
const NCA = preload("res://examples/thunderbowl/nca.gd")
const SmartLink = preload("res://examples/thunderbowl/smart_link.gd")


static func create(id: String) -> RefCounted:
	match id:
		"human_wire": return HumanWire.new()
		"human_metal": return HumanMetal.new()
		"wire_seek": return WireSeek.new()
		"metal_pulse": return MetalPulse.new()
		"oracle": return Oracle.new()
		"lemming": return Lemming.new()
		"emergent": return Emergent.new()
		"local_swarm": return LocalSwarm.new()
		"nca": return NCA.new()
		"smart_link": return SmartLink.new()
	return null
