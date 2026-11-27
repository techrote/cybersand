extends SceneTree
const History = preload("res://scripts/workbench_presentation_history.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error("MEMBER_HISTORY: "+message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var history = History.new()
	var pose := Transform2D(0.2,Vector2(50,60))
	check(history.observe(8,9,4,0,pose,Vector2.ZERO,0,0).is_empty(),"unbound legacy eight-slot limit remains exact")
	var members: Array = []
	for slot: int in range(History.MAX_MEMBERS): members.append({"instance_id":slot+1,"generation":4})
	var last: int = members.size()-1
	var owner: Array = [-99,7,4]
	check(history.bind_members(owner,members),"actual bounded owner and all admitted member identities bind")
	var first: Dictionary = history.observe(last,last+1,4,1,pose,Vector2.ZERO,0,100)
	check(not first.is_empty() and first.is_read_only(),"last admitted physical member owns an immutable actual observation")
	check(history.observe(last+1,last+2,4,1,pose,Vector2.ZERO,0,100).is_empty(),"binding cannot extend native member limit")
	check(history.observe(last,last+2,4,2,pose,Vector2.ZERO,0,200).is_empty(),"another member cannot impersonate boundslot")
	check(history.observe(last,last+1,5,2,pose,Vector2.ZERO,0,200).is_empty(),"another generation cannot borrow boundslot")
	check(history.bind_members(owner,members) and history.observation(last,1)==first,"identical owner closure preserves actual timeline")
	for step: int in range(2,History.CAPACITY+6):
		history.observe(last,last+1,4,step,pose,Vector2.ZERO,0,step*100)
	check(history.retained_observations()==History.CAPACITY and history.observation(last,1).is_empty(),"bound member history retains the original finite ring")
	for invalid_owner: Array in [[0,7,4],[-99,0,4],[-99,7,0],[-99,7],[-99,7.0,4]]:
		check(not history.bind_members(invalid_owner,members),"invalid owner domain refuses "+str(invalid_owner))
	var too_many: Array = members.duplicate(true)
	too_many.append({"instance_id":last+2,"generation":4})
	check(not history.bind_members(owner,too_many),"oversized roster cannot allocate unbounded observations")
	var duplicate: Array = members.duplicate(true)
	duplicate[last].instance_id = 1
	check(not history.bind_members(owner,duplicate),"duplicate member ownership refuses")
	check(not history.bind_members(owner,[]),"empty binding refuses")
	var changed_owner: Array = [-100,8,5]
	check(history.bind_members(changed_owner,members) and history.retained_observations()==0,
		"actual owner replacement clears every old member timeline")
	check(first.step==1 and first.completed_usec==100,"retired immutable readers are unchanged by replacement")
	check(history.observe(last,last+1,4,0,pose,Vector2.ZERO,0,0).completed_usec==0,"new initialized owner invents no completion")
	var replacement: Array = members.duplicate(true)
	replacement[last] = {"instance_id":last+3,"generation":9}
	check(history.bind_members(changed_owner,replacement) and history.retained_observations()==0,
		"reused slot under changed member identity retires old history")
	check(history.observe(last,last+1,4,1,pose,Vector2.ZERO,0,100).is_empty(),"replaced member cannot return through same slot")
	check(not history.observe(last,last+3,9,0,pose,Vector2.ZERO,0,0).is_empty(),"new exact member is independently admitted")
	history.clear()
	check(not history.bound_to(changed_owner) and history.retained_observations()==0 \
		and history.observe(8,9,4,0,pose,Vector2.ZERO,0,0).is_empty(),"teardown retires binding and restores legacy bound")
	print("PUBPRES_MEMBER_HISTORY_RESULT "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
