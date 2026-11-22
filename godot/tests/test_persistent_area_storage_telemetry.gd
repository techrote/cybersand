extends SceneTree

const Store = preload("res://scripts/persistent_area_store.gd")
var checks := 0
var failures := 0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("RAMCACHE profile I/O telemetry: "+label)


func _initialize() -> void:
	var storage: Object = ClassDB.instantiate("CyberPersistentAreaStorage")
	if not storage.has_method("telemetry"):
		check(false,"executed native runtime includes actual profile I/O instrumentation")
		finish(); return
	var path := ProjectSettings.globalize_path("user://ramcache-io-"+Store.new_nonce())
	check(storage.acquire(path).ok,"native isolated profile acquires")
	var before: Dictionary = storage.telemetry()
	check(before==storage.telemetry(),"telemetry snapshots themselves cause zero profile filesystem operations")
	check(before.profile_directory==path and before.acquired,"counters identify their actual profile owner")
	check(before.read_requests==0 and before.write_requests==0,"fresh profile starts without checkpoint I/O")
	check(storage.read_file("missing.bin",64).ok,"nonexistent bounded profile read is observed")
	var missing: Dictionary = storage.telemetry()
	check(missing.read_requests-before.read_requests==1 and missing.read_open_attempts-before.read_open_attempts==1 \
		and missing.read_bytes==0,"missing-file probe is a filesystem call without invented data bytes")
	var bytes := PackedByteArray([1,2,3,4,5,6])
	check(storage.write_new("area-a-telemetry.cypa",bytes).ok,"actual immutable checkpoint writes")
	var written: Dictionary = storage.telemetry()
	check(written.write_requests==1 and written.write_create_attempts==1 and written.write_system_calls==1,
		"actual create/write calls counted")
	check(written.write_bytes==6 and written.checkpoint_write_bytes==6,"actual checkpoint bytes counted exactly")
	check(written.file_flush_calls==1 and written.checkpoint_read_bytes==6,
		"durability flush and integrity readback remain visible separately")
	check(storage.read_file("area-a-telemetry.cypa",64).bytes==bytes \
		and storage.read_file("area-a-telemetry.cypa",64).bytes==bytes,"repeat filesystem reads return exact data")
	var repeated: Dictionary = storage.telemetry()
	check(repeated.read_requests-written.read_requests==2 and repeated.read_bytes-written.read_bytes==12 \
		and repeated.checkpoint_read_bytes-written.checkpoint_read_bytes==12,
		"kernel-file-cache hits still count as filesystem reads, never HOT transitions")
	check(storage.write_new("area-a-telemetry.cypa",bytes).idempotent,"immutable write replay remains idempotent")
	var retried: Dictionary = storage.telemetry()
	check(retried.write_requests==2 and retried.write_system_calls==1 and retried.write_bytes==6 \
		and retried.file_flush_calls==2,"idempotent write retry counts validation/flush without fabricated rewritten bytes")
	check(storage.write_new("manifest-stage.tmp",bytes).ok,"manifest stage writes")
	var staged: Dictionary = storage.telemetry()
	check(not storage.publish("manifest-stage.tmp","current.cypm","","0".repeat(64)).ok,"wrong staged identity refuses")
	var refused: Dictionary = storage.telemetry()
	check(refused.publication_requests-staged.publication_requests==1 and refused.publication_calls==staged.publication_calls,
		"publication admission refusal does not count an attempted rename syscall")
	check(storage.publish("manifest-stage.tmp","current.cypm","",Store.digest(bytes)).ok,"validated atomic manifest publication executes")
	var published: Dictionary = storage.telemetry()
	check(published.publication_calls==1 and published.publication_requests==2,"actual atomic replacement separately counted")
	var other: Object = ClassDB.instantiate("CyberPersistentAreaStorage")
	check(other.acquire(path+"-other").ok,"independent native profile owner acquires")
	check(other.telemetry().storage_owner_id!=published.storage_owner_id and other.telemetry().read_bytes==0,
		"another profile cannot contaminate this owner's I/O counts")
	check(storage.telemetry()==published,"operations on another owner leave original counters untouched")
	check("not physical device" in str(published.scope),"counter contract distinguishes application and device I/O")
	storage.close_profile()
	other.close_profile()
	finish()


func finish() -> void:
	print("GEN006_RAMCACHE_IO_TELEMETRY checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
