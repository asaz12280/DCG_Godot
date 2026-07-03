extends SceneTree

const DamageEventScript := preload("res://scripts/combat/damage_event.gd")
const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")

var _errors: Array[String] = []
var _health_signal_count := 0


func _initialize() -> void:
	await _validate_player_damage_updates_hud()
	if _errors.is_empty():
		print("[player_damage_flow] OK damage=accepted health_signal=emits hud=updates death=guarded")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_player_damage_updates_hud() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame

	var player := scene.get_node_or_null("Player3D")
	var hud := scene.get_node_or_null("HUD/PlayerHud3D")
	if player == null or hud == null:
		_errors.append("Gameplay scene should include Player3D and PlayerHud3D.")
		_free_node(scene)
		return
	if not player.has_signal("health_changed") or not player.has_method("apply_damage"):
		_errors.append("Player3D should expose health_changed and apply_damage for damage flow.")
		_free_node(scene)
		return

	player.health_changed.connect(_on_player_health_changed)
	var before := hud.call("get_display_state") as Dictionary
	var max_health := float(player.call("get_total_max_health"))
	var event := DamageEventScript.new(12.0, null, null, [&"validation", &"enemy"])
	if not bool(player.call("apply_damage", event)):
		_errors.append("Player should accept an enemy DamageEvent.")
	await process_frame

	var after := hud.call("get_display_state") as Dictionary
	var damaged_health := float(player.get("health"))
	if _health_signal_count != 1:
		_errors.append("Player damage should emit health_changed once.")
	if damaged_health >= max_health:
		_errors.append("Player health should decrease after damage.")
	if float(after.get("health_current", max_health)) >= float(before.get("health_current", max_health)):
		_errors.append("PlayerHud3D should expose decreased current health after damage.")
	if not str(after.get("health_text", "")).contains(str(roundi(damaged_health))):
		_errors.append("PlayerHud3D should expose readable health text after damage.")
	if bool(player.get("is_dead")):
		_errors.append("Non-lethal damage should not kill the player.")

	_free_node(scene)


func _on_player_health_changed(_current: float, _maximum: float) -> void:
	_health_signal_count += 1


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
