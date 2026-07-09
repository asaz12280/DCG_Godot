extends SceneTree


func _initialize() -> void:
	push_error("[validation_runner_failure_probe] deliberate ERROR output for runner failure semantics.")
	quit(0)
