extends SceneTree

const ScavengerScene := preload("res://scenes/enemies/scavenger_3d.tscn")
const DamageEventScript := preload("res://scripts/combat/damage_event.gd")
const StatusDisplayScript := preload("res://scripts/ai/enemy_status_display_3d.gd")

var _errors: Array[String] = []


func _initialize() -> void:
	await _validate_enemy_health_status_visibility()
	if _errors.is_empty():
		print("[enemy_damageable_3d] OK healthbar=visible injured=readable death=readable display=decoupled")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_enemy_health_status_visibility() -> void:
	var enemy := ScavengerScene.instantiate()
	root.add_child(enemy)
	await process_frame

	if not enemy.has_signal("health_changed") or not enemy.has_signal("died"):
		_errors.append("Scavenger should expose health_changed and died signals for player-visible state.")

	var display := enemy.get_node_or_null("EnemyStatusDisplay3D")
	if display == null:
		_errors.append("Scavenger should include EnemyStatusDisplay3D for readable health and state.")
	else:
		if display.get_script() != StatusDisplayScript:
			_errors.append("EnemyStatusDisplay3D should use enemy_status_display_3d.gd.")

	var status_label := enemy.get_node_or_null("EnemyStatusDisplay3D/StatusLabel") as Label3D
	if status_label == null:
		_errors.append("Scavenger should include a 3D StatusLabel.")
	elif status_label.text.strip_edges() == "":
		_errors.append("StatusLabel should show an initial readable state.")

	var health_back := enemy.get_node_or_null("EnemyStatusDisplay3D/HealthBarBack") as MeshInstance3D
	var health_fill := enemy.get_node_or_null("EnemyStatusDisplay3D/HealthBarFill") as MeshInstance3D
	if health_back == null or health_fill == null:
		_errors.append("Scavenger should include visible 3D health bar back and fill meshes.")
	else:
		if not health_back.visible or not health_fill.visible:
			_errors.append("Scavenger health bar meshes should be visible.")
		if health_fill.scale.x < 0.95:
			_errors.append("HealthBarFill should start near full health.")

	var hurt_event := DamageEventScript.new(12.0, null, null, [&"validation"])
	if not enemy.apply_damage(hurt_event):
		_errors.append("Scavenger should accept non-lethal damage.")
	await process_frame

	if status_label != null and status_label.text != "受傷":
		_errors.append("Scavenger status should show 受傷 after taking non-lethal damage.")
	if health_fill != null and health_fill.scale.x >= 0.95:
		_errors.append("HealthBarFill should shrink after the enemy is damaged.")

	var lethal_event := DamageEventScript.new(999.0, null, null, [&"validation"])
	if not enemy.apply_damage(lethal_event):
		_errors.append("Scavenger should accept lethal damage while alive.")
	await process_frame

	if status_label != null and status_label.text != "死亡":
		_errors.append("Scavenger status should show 死亡 after lethal damage.")
	if health_fill != null and health_fill.scale.x > 0.01:
		_errors.append("HealthBarFill should be empty after enemy death.")
	if enemy.has_method("is_alive") and bool(enemy.call("is_alive")):
		_errors.append("Scavenger is_alive should be false after lethal damage.")

	_validate_decoupling()
	_free_node(enemy)


func _validate_decoupling() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ai/enemy_status_display_3d.gd")
	for forbidden in ["InventoryEquipmentUI", "ContainerInventoryUI", "QuestState", "SaveGameManager"]:
		if source.contains(forbidden):
			_errors.append("EnemyStatusDisplay3D should not depend on %s." % forbidden)


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
