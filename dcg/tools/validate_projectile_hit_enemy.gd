extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")
const Ammo := preload("res://data/items/ammo/ammo_9mm.tres")

var _errors: Array[String] = []
var _hit_count := 0


func _initialize() -> void:
	await _validate_equipped_pistol_projectile_kills_enemy()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[projectile_hit_enemy] OK equip_reload_fire=works projectile=kills_enemy death=visible controller=stops")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_equipped_pistol_projectile_kills_enemy() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var player := scene.get_node_or_null("Player3D")
	var enemy := scene.get_node_or_null("SceneProps/ScavengerPatrol01")
	if player == null or enemy == null:
		_errors.append("Normal Raid scene should include Player3D and ScavengerPatrol01.")
		_free_node(scene)
		return
	var weapon := player.get_node_or_null("WeaponController3D")
	var controller := enemy.get_node_or_null("EnemyController3D")
	var status_label := enemy.get_node_or_null("EnemyStatusDisplay3D/StatusLabel") as Label3D
	if weapon == null or controller == null:
		_errors.append("Player weapon and enemy controller should be present for projectile enemy validation.")
		_free_node(scene)
		return
	if not weapon.has_signal("hit"):
		_errors.append("WeaponController3D should emit hit when projectile damages an enemy.")
		_free_node(scene)
		return
	weapon.hit.connect(_on_weapon_hit)

	var backpack_model: InventoryModel = player.call("get_inventory_model")
	backpack_model.clear()
	backpack_model.setup(50)
	backpack_model.add_item(Pistol, 1)
	backpack_model.add_item(Ammo, 24)
	if not bool(player.call("equip_inventory_stack", 0, &"primary_weapon")):
		_errors.append("Player should equip No.5 pistol into primary weapon slot before firing.")
	await process_frame
	player.set("reload_duration_seconds", 0.05)
	if not bool(player.call("reload_equipped_weapon")):
		_errors.append("Player should start reloading No.5 pistol with No.7 ammo.")
	await _wait_for_reload_complete(player, weapon)
	if int(weapon.get("current_ammo")) != 8:
		_errors.append("No.5 pistol should have 8 loaded rounds before shooting the enemy.")

	player.global_position = Vector3.ZERO
	enemy.global_position = Vector3(0.0, 0.0, 2.4)
	enemy.velocity = Vector3.ZERO
	controller.set_physics_process(false)
	if controller.has_method("_cancel_windup"):
		controller.call("_cancel_windup")
	weapon.set("fire_cooldown_seconds", 0.0)
	await physics_frame
	await process_frame

	for _shot in range(2):
		if weapon.has_method("force_cooldown_ready"):
			weapon.call("force_cooldown_ready")
		var origin: Vector3 = player.global_position + Vector3(0.0, 0.72, 0.9)
		var direction: Vector3 = (enemy.global_position + Vector3(0.0, 0.72, 0.0) - origin).normalized()
		if not bool(weapon.call("fire_forward", origin, direction, player.get_world_3d().direct_space_state)):
			_errors.append("Equipped No.5 pistol should fire a 3D projectile toward the enemy.")
		await _wait_for_projectile_resolution(enemy)
		if enemy.has_method("is_alive") and not bool(enemy.call("is_alive")):
			break

	if enemy.has_method("is_alive") and bool(enemy.call("is_alive")):
		_errors.append("Two loaded No.5 pistol projectile hits should kill the visible Scavenger.")
	if str(controller.state) != "dead":
		_errors.append("EnemyController3D should stop in dead state after projectile kill.")
	if status_label == null or status_label.text != "死亡":
		_errors.append("Enemy status label should show 死亡 after projectile kill.")
	if _hit_count < 2:
		_errors.append("WeaponController3D should emit hit for projectile hits against the enemy.")

	_free_node(scene)


func _wait_for_reload_complete(player: Node, weapon: Node) -> void:
	for _frame in range(20):
		await physics_frame
		await process_frame
		var state: Dictionary = player.call("get_reload_state")
		if not bool(state.get("active", false)) and int(weapon.get("current_ammo")) > 0:
			return


func _wait_for_projectile_resolution(enemy: Node) -> void:
	var health_before := float(enemy.get("current_health"))
	for _frame in range(35):
		await physics_frame
		await process_frame
		if float(enemy.get("current_health")) < health_before or (enemy.has_method("is_alive") and not bool(enemy.call("is_alive"))):
			return


func _validate_source_boundaries() -> void:
	var weapon_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_controller_3d.gd")
	for required in ["projectile_scene", "_spawn_projectile", "_on_projectile_hit", "shot_feedback_scene"]:
		if not weapon_source.contains(required):
			_errors.append("WeaponController3D should keep projectile/fire VFX term: %s." % required)
	for forbidden in ["InventoryEquipmentUI", "ContainerInventoryUI", "Quest", "SaveGame"]:
		if weapon_source.contains(forbidden):
			_errors.append("WeaponController3D should not depend on unrelated systems for projectile hits: %s." % forbidden)
	var enemy_source := FileAccess.get_file_as_string("res://scripts/ai/enemy_damageable_3d.gd")
	for forbidden in ["PlayerHud3D", "Inventory", "WeaponController3D"]:
		if enemy_source.contains(forbidden):
			_errors.append("EnemyDamageable3D should not depend on %s for projectile damage." % forbidden)


func _on_weapon_hit(_target: Node, _event: DamageEvent) -> void:
	_hit_count += 1


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
