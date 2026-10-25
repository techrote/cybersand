extends RefCounted
var arrived := Semaphore.new()
var resume := Semaphore.new()
func enter() -> void:
	arrived.post();resume.wait()
