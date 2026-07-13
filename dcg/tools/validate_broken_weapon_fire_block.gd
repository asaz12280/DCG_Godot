extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const Pistol := preload("res://data/items/weapons/pistol_S.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	await _validate_broken_weapon_blocks_fire()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[broken_weapon_fire_block] OK broken=blocks_fire ammo=preserved durability=preserved hud=depleted boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_broken_weapon_blocks_fire() -> void:
	var context := await _spawn_context()
	if context.is_empty():
		return
	var player: Node = context["player"]
	var weapon: Node = context["weapon"]
	var hud: Node = context["hud"]
	var equipment: RefCounted = player.call("get_equipment_model")
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	backpack_model.clear()
	backpack_model.setup(50)
	backpack_model.add_stack(_durable_pistol_stack(0, 12))
	if not bool(player.call("equip_inventory_stack", 0, &"primary_weapon")):
		_errors.append("Broken weapon block validation should equip a depleted pistol.")
		_free_node(context["scene"])
		return
	await process_frame
	weapon.set("current_ammo", 2)
	weapon.set("reserve_ammo", 0)
	if weapon.has_method("_sync_ammo_result"):
		weapon.call("_sync_ammo_result")
	if weapon.has_method("force_cooldown_ready"):
		weapon.call("force_cooldown_ready")

	_press_primary_fire(player)
	await process_frame
	var fire_result: Dictionary = weapon.get("last_fire_result")
	if bool(fire_result.get("fired", true)):
		_errors.append("A depleted weapon should not record a fired shot.")
	if str(fire_result.get("blocked_reason", "")) != "broken_weapon":
		_errors.append("A depleted weapon should report broken_weapon as the fire block reason.")
	if int(weapon.get("current_ammo")) != 2:
		_errors.append("A depleted weapon should not consume loaded ammo.")
	var primary_stack: Dictionary = equipment.call("get_slot", &"primary_weapon")
	if int(primary_stack.get("current_durability", -1)) != 0:
		_errors.append("A depleted weapon fire block should not mutate durability.")
	var spread_state: Dictionary = player.call("get_last_weapon_spread_state")
	if str(spread_state.get("source", "")) != "depleted_durability":
		_errors.append("Broken fire block should still expose depleted durability as the spread/debug source.")
	var hud_state: Dictionary = hud.call("get_display_state")
	var weapon_status := str(hud_state.get("weapon_status", ""))
	if not weapon_status.contains(TranslationServer.translate("ui.raid_hud.weapon_status_durability_broken_format") % [0, 12]):
		_errors.append("Raid HUD should keep showing depleted durability after a blocked broken-weapon shot.")
	_free_node(context["scene"])


func _validate_source_boundaries() -> void:
	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	for required in ["_should_block_fire_for_broken_weapon", "_record_weapon_fire_block", "broken_weapon"]:
		if not player_source.contains(required):
			_errors.append("PlayerController3D should own broken weapon fire blocking through %s." % required)
	var equipment_source := FileAccess.get_file_as_string("res://scripts/player/player_equipment_controller_3d.gd")
	for required in ["should_block_fire_for_broken_weapon", "durability_is_broken"]:
		if not equipment_source.contains(required):
			_errors.append("PlayerEquipmentController3D should own equipment durability checks through %s." % required)
	var weapon_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_controller_3d.gd")
	for forbidden in ["ItemDurabilityServiceScript", "EquipmentModel", "durability_is_broken", "broken_weapon"]:
		if weapon_source.contains(forbidden):
			_errors.append("WeaponController3D should not own equipment durability blocking: %s." % forbidden)
	var hud_source := FileAccess.get_file_as_string("res://scripts/ui/raid_hud_panel.gd")
	if not hud_source.contains("weapon_status_durability_broken_format"):
		_errors.append("RaidHudPanel should keep using the existing depleted durability display key.")


func _press_primary_fire(player: Node) -> void:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	player.call("_unhandled_input", event)


func _spawn_context() -> Dictionary:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var player := scene.get_node_or_null("Player3D")
	var weapon := player.get_node_or_null("WeaponController3D") if player != null else null
	var hud := scene.get_node_or_null("HUD/RaidHudPanel")
	if player == null:
		_errors.append("Gameplay scene should include Player3D.")
		_free_node(scene)
		return {}
	if weapon == null:
		_errors.append("Player3D should include WeaponController3D.")
		_free_node(scene)
		return {}
	if hud == null:
		_errors.append("Gameplay scene should include HUD/RaidHudPanel.")
		_free_node(scene)
		return {}
	return {
		"scene": scene,
		"player": player,
		"weapon": weapon,
		"hud": hud,
	}


func _durable_pistol_stack(current: int, maximum: int) -> Dictionary:
	var stack := Pistol.to_stack(1)
	stack["current_durability"] = current
	stack["max_durability"] = maximum
	stack["original_max_durability"] = Pistol.max_durability
	stack["repair_max_durability_loss"] = Pistol.repair_max_durability_loss
	stack["durability_penalty_ratio"] = Pistol.durability_penalty_ratio
	return stack


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
