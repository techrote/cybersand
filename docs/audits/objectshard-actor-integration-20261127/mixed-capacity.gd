extends SceneTree
const Fixture=preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
const Setup=preload("res://scripts/workbench_setup.gd")
const Sandbox=preload("res://scripts/workbench_actor_sandbox.gd")
var f:RefCounted
func _initialize()->void: run.call_deferred()
func workload()->void:
 if not await f.open("stress"): return
 var recipe:Dictionary=f.bench.applied.duplicate(true)
 var group:Dictionary=Sandbox.barrel_crowd(PackedInt32Array(recipe.liquid_policy),64)
 for i:int in range(64):
  group.actors[i].spawn=[70+(i%16)*24,64+floori(float(i)/16.0)*24]
 recipe.actors=group.actors;recipe.sandbox_capacity=group.sandbox_capacity;recipe.next_id=65;recipe.selected=1
 if not f.expect(f.bench.apply(recipe),"normal authored start requests 64 barrel actors on the stress scene: "+f.bench.message): return
 if not await f.until(f.installed,"same application admits the 64-actor construction"):return
 if not f.play():return
 if not await f.until(func(): return f.diagnostics().get("attached",false),"structural coordinator attaches to the 64-actor world"):return
 if not await f.pause() or not await f.cut_supports("stress") or not f.play():return
 if not await f.until(func():return f.body_count()>=8,"eight detached stress structures share the actor Rapier space",30000):return
 if not await f.advance(10,"ten more material semantic ticks with both populations") or not await f.pause(): return
 var actor_session:Variant=f.host.physical_actor_session
 var actors:Array=actor_session.bodies()
 var unique:Dictionary={}
 var same_space:RID=f.runtime().bridge.space
 for body:RigidBody2D in actors:
  f.expect(body.get_rid().is_valid() and PhysicsServer2D.body_get_space(body.get_rid())==same_space,"physical actor belongs to same space")
  unique[body.get_rid()]=true
 for row:Dictionary in f.runtime().bridge.bodies.values():
  f.expect(row.rid.is_valid() and PhysicsServer2D.body_get_space(row.rid)==same_space,"structural carrier belongs to same space")
  unique[row.rid]=true
 f.expect(actors.size()==64 and f.body_count()==8 and unique.size()==72,"all 72 physical authorities are unique and live")
 f.expect(f.host._workbench_frame_error.is_empty() and f.runtime().held_reason.is_empty(),"worker accepts mixed sample with 64 actors and eight material carriers")
func run()->void:
 f=Fixture.new(self)
 await workload()
 var receipt={"checks":f.checks,"errors":f.failures,"tick":f.tick(),"structures":f.body_count()}
 await f.close()
 print("ACTOR_STRUCTURAL_CAPACITY ",JSON.stringify(receipt));quit(0 if f.failures.is_empty() else 1)
