extends SceneTree

const ScavengerScene := preload("res://scenes/enemies/scavenger_3d.tscn")
const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const DamageEventScript := preload("res://scripts/combat/damage_event.gd")
const StatusDisplayScript := preload("res://scripts/ai/enemy_status_display_3d.gd")

var _errors: Array[String] = []


func _initialize() -> void:
	await _validate_enemy_health_status_visibility()
	await _validate_player_style_hud_health_bar()
	_validate_decoupling()
	if _errors.is_empty():
		print("[enemy_damageable_3d] OK healthbar=player_style_overlay injured=readable death=readable display=decoupled")
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
	var health_anchor := enemy.get_node_or_null("EnemyHealthAnchor3D") as Node3D
	if health_anchor == null:
		_errors.append("Scavenger should include EnemyHealthAnchor3D for player-style head tracking.")
	elif health_anchor.position.y <= 1.75:
		_errors.append("EnemyHealthAnchor3D should remain above the visible name/head stack.")

	var health_back := enemy.get_node_or_null("EnemyStatusDisplay3D/HealthBarBack")
	var health_fill := enemy.get_node_or_null("EnemyStatusDisplay3D/HealthBarFill")
	if health_back != null or health_fill != null:
		_errors.append("Scavenger should remove legacy 3D health bar meshes because PlayerHud3D owns the visible player-style bar.")

	var hurt_event := DamageEventScript.new(12.0, null, null, [&"validation"])
	if not enemy.apply_damage(hurt_event):
		_errors.append("Scavenger should accept non-lethal damage.")
	await process_frame

	if status_label != null and status_label.text != "受傷":
		_errors.append("Scavenger status should show 受傷 after taking non-lethal damage.")

	var lethal_event := DamageEventScript.new(999.0, null, null, [&"validation"])
	if not enemy.apply_damage(lethal_event):
		_errors.append("Scavenger should accept lethal damage while alive.")
	await process_frame

	if status_label != null and status_label.text != "死亡":
		_errors.append("Scavenger status should show 死亡 after lethal damage.")
	if enemy.has_method("is_alive") and bool(enemy.call("is_alive")):
		_errors.append("Scavenger is_alive should be false after lethal damage.")

	_free_node(enemy)


func _validate_player_style_hud_health_bar() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var hud := scene.get_node_or_null("HUD/PlayerHud3D")
	var enemy := scene.get_node_or_null("SceneProps/ScavengerPatrol01")
	if hud == null or enemy == null:
		_errors.append("Gameplay scene should expose PlayerHud3D and ScavengerPatrol01 for enemy health HUD validation.")
		_free_node(scene)
		return

	var state: Dictionary = hud.call("get_display_state")
	var bars: Array = state.get("enemy_health_bars", [])
	if int(state.get("enemy_health_bar_count", 0)) <= 0 or bars.is_empty():
		_errors.append("PlayerHud3D should expose at least one enemy health bar state.")
	else:
		var bar: Dictionary = bars[0]
		if str(bar.get("style", "")) != "player_health":
			_errors.append("Enemy health bar should use the same player_health HUD style.")
		if not bool(bar.get("visible", false)):
			_errors.append("Enemy health bar should be visible through PlayerHud3D during normal Raid.")
		if float(bar.get("ratio", 0.0)) < 0.95:
			_errors.append("Player-style enemy health bar should start near full health.")
		var enemy_bar_size: Vector2 = bar.get("size", Vector2.ZERO)
		var player_bar_size: Vector2 = hud.get("health_size")
		if enemy_bar_size.distance_to(player_bar_size) > 0.01:
			_errors.append("Enemy health bar should use the same size as the player overhead health bar.")
		var anchor := enemy.get_node_or_null("EnemyHealthAnchor3D") as Node3D
		var camera := scene.get_node_or_null("Camera3D") as Camera3D
		if anchor == null or camera == null:
			_errors.append("Enemy HUD validation needs EnemyHealthAnchor3D and Camera3D.")
		else:
			var enemy_offset: Vector2 = hud.get("enemy_health_offset") as Vector2
			var expected_center: Vector2 = camera.unproject_position(anchor.global_position) + enemy_offset
			var actual_center: Vector2 = bar.get("center", Vector2.INF)
			if actual_center.distance_to(expected_center) > 0.01:
				_errors.append("Enemy health bar should project the EnemyHealthAnchor3D position, not the enemy root.")
			hud.call("_enemy_health_overlay_requires_redraw")
			anchor.global_position += Vector3(0.5, 0.0, 0.0)
			if not bool(hud.call("_enemy_health_overlay_requires_redraw")):
				_errors.append("Enemy health overlay should request a redraw immediately when its head anchor moves.")
			anchor.global_position -= Vector3(0.5, 0.0, 0.0)

	var hurt_event := DamageEventScript.new(12.0, null, null, [&"validation"])
	enemy.apply_damage(hurt_event)
	await process_frame
	state = hud.call("get_display_state")
	bars = state.get("enemy_health_bars", [])
	if bars.is_empty():
		_errors.append("PlayerHud3D should keep showing an enemy health bar after non-lethal damage.")
	else:
		var hurt_bar: Dictionary = bars[0]
		if float(hurt_bar.get("ratio", 1.0)) >= 0.95:
			_errors.append("Player-style enemy health bar should shrink after enemy damage.")

	_free_node(scene)


func _validate_decoupling() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ai/enemy_status_display_3d.gd")
	for forbidden in ["InventoryEquipmentUI", "ContainerInventoryUI", "QuestState", "SaveGameManager"]:
		if source.contains(forbidden):
			_errors.append("EnemyStatusDisplay3D should not depend on %s." % forbidden)
	var hud_source := FileAccess.get_file_as_string("res://scripts/ui/player_hud_3d.gd")
	for required in ["_enemy_health_overlay_requires_redraw", "_enemy_overlay_anchor_positions", "_last_enemy_overlay_camera_transform"]:
		if not hud_source.contains(required):
			_errors.append("PlayerHud3D should keep enemy overlay transform-sync term: %s." % required)


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
