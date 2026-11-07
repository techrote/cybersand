extends "res://tests/test_workbench_agent_step_sequence.gd"
## Independent Windows qualification of the unchanged Step driver. The
## canonical test's manual-step helper can return before the paused native
## publication, then its next agent call correctly refuses that transient.
## Require the real paused publication before testing the subsequent Stop.
func _manual_step_ack(target: int, expected_tick: int, generation: int) -> bool:
	return super._manual_step_ack(target,expected_tick,generation) and main.latest_snapshot != null \
		and main.latest_snapshot.paused
