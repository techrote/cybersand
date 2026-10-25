extends CyberSimulationWorker
var observe_initial: bool=false
var initial_values: Dictionary={}
var water_rows: Array=[]
var last_water_tick: int=-1
var reset_capture: bool=false
func arm() -> void:
	_mutex.lock();observe_initial=true;_mutex.unlock()
func rearm() -> void:
	_mutex.lock();reset_capture=true;observe_initial=true;_mutex.unlock()
func initial() -> Dictionary:
	_mutex.lock();var result: Dictionary={} if reset_capture else initial_values.duplicate(true);_mutex.unlock();return result
func history() -> Array:
	_mutex.lock();var result: Array=water_rows.duplicate(true);_mutex.unlock();return result
func _publish_snapshot(step_ms: float, is_paused: bool, interval: int, force_full: bool=false,
		states: PackedFloat32Array=PackedFloat32Array(), epoch: int=0) -> void:
	super._publish_snapshot(step_ms,is_paused,interval,force_full,states,epoch)
	_mutex.lock()
	if reset_capture:
		initial_values={};water_rows=[];last_water_tick=-1;reset_capture=false
	var armed: bool=observe_initial;var capture: bool=armed and initial_values.is_empty();_mutex.unlock()
	if not armed: return
	var tick: int=_world.get_tick_index()
	if tick!=last_water_tick:
		var row: Dictionary=_water_observe()
		_mutex.lock();water_rows.append(row);_mutex.unlock()
		last_water_tick=tick
	if not capture: return
	var masks: Array=[]
	for offset: int in range(0,_rigid_body_states.size(),CyberRigidBodyCoupling.INPUT_STRIDE):
		masks.append(_world.rigid_body_id_at(int(_rigid_body_states[offset+1]),int(_rigid_body_states[offset+2])))
	var value: Dictionary={"water":_water_observe(),"states":_rigid_body_states.duplicate(),"masks":masks,
		"policy":_world.get_liquid_solver_policy(),"water_policy":_world.get_water_experiment_policy(),
		"receipt":_world.get_applied_liquid_construction_receipt(),"tick":_world.get_tick_index()}
	_mutex.lock();initial_values=value;_mutex.unlock()
