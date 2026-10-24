extends RefCounted

# Private preparation values only. This view has no tick/edit API, never exports
# a pending native World, and fails closed after its one-use token is retired.
const ActorSession = preload("res://scripts/actor_prototype_session.gd")
const UsableSession = preload("res://scripts/usable_session.gd")

class CandidateView:
	extends RefCounted
	var bridge: Variant
	var adapter: Variant
	var token: int
	func _init(owner_bridge: Variant, owner_adapter: Variant, preparation: int) -> void:
		bridge = owner_bridge
		adapter = owner_adapter
		token = preparation
	func box_collides(origin: Vector2, size: Vector2) -> bool:
		return character_box_collides(origin, size, 0)
	func character_box_collides(origin: Vector2, size: Vector2, mode: int) -> bool:
		return bridge.prepared_liquid_character_box_collides(adapter, token, origin, size, mode)

static func prepare(bridge: Variant, world: Variant, token: int, spawn: Vector2,
		enabled: bool, runtime_recovery: bool, profile: Dictionary, definitions: Array,
		epoch_floor: int, actor_factory: Callable = Callable(), usable_factory: Callable = Callable()) -> Dictionary:
	if not bridge.has_method(&"prepared_liquid_character_box_collides"):
		return {"ok":false, "error":"Prepared sampled actors require the rebuilt native candidate query adapter"}
	var view := CandidateView.new(bridge, world, token)
	var actors: CyberActorPrototypeSession = actor_factory.call() if actor_factory.is_valid() else ActorSession.new()
	var usables: CyberUsableSession = usable_factory.call() if usable_factory.is_valid() else UsableSession.new()
	if actors == null or usables == null or not actors.configure(definitions, view, epoch_floor):
		return {"ok":false, "error":"Prepared sampled actor configuration refused"}
	if not usables.configure(actors.snapshot()):
		return {"ok":false, "error":"Prepared sampled equipment configuration refused"}
	var character: CyberSampledCharacter = actors.player() if actors.active() else CyberSampledCharacter.new()
	if not actors.active():
		character.configure_profile(profile)
		character.configure_runtime_enclosure_recovery(runtime_recovery)
		character.reset(spawn)
		if enabled: character.recover_invalid_spawn(view)
	# Bounded invalid-spawn recovery retains its existing blocked result rather
	# than inventing a construction refusal for an enclosed actor.
	return {"ok":true, "actors":actors, "usables":usables, "character":character,
		"enabled":enabled or actors.active()}
