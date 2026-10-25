extends RefCounted
var worker: CyberSimulationWorker
var command: Dictionary
var applied: bool = false
func run() -> void:
	applied = worker._apply_lab(command)
