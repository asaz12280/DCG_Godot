extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")
const Ammo := preload("res://data/items/ammo/ammo_9mm.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	await _validate_r_key_blocks_without_weapon()
	await _validate_r_key_blocks_without_ammo()
	await _validate_r_key_loads_equipped_pistol_from_backpack()
	await _validate_empty_left_click_auto_reloads_without_firing()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[reload_flow] OK r_key=bound empty_fire=auto_reload backpack_ammo=consumed magazine=updated boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_r_key_blocks_without_weapon() -> void:
	var context := await _spawn_context()
	if context.is_empty():
		return
	var player: Node = context["player"]
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	backpack_model.clear()
	backpack_model.setup(50)
	backpack_model.add_item(Ammo, 24)

	_press_reload(player)
	var result: Dictionary = player.call("get_last_reload_result")
	if bool(result.get("reloaded", false)):
		_errors.append("Pressing R without an equipped weapon should not reload.")
	if str(result.get("blocked_reason", "")) != "no_weapon":
		_errors.append("Pressing R without a weapon should report no_weapon.")
	if int(_first_stack_quantity(backpack_model, Ammo)) != 24:
		_errors.append("No-weapon reload attempt should not consume backpack ammo.")

	_free_node(context["scene"])


func _validate_r_key_blocks_without_ammo() -> void:
	var context := await _spawn_context()
	if context.is_empty():
		return
	var player: Node = context["player"]
	var weapon: Node = context["weapon"]
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	player.set("reload_duration_seconds", 0.05)
	backpack_model.clear()
	backpack_model.setup(50)
	backpack_model.add_item(Pistol, 1)
	if not bool(player.call("equip_inventory_stack", 0)):
		_errors.append("Reload validation should equip No.5 pistol before testing no-ammo state.")
	await process_frame
	weapon.set("current_ammo", 0)
	weapon.set("reserve_ammo", 0)
	if weapon.has_method("_sync_ammo_result"):
		weapon.call("_sync_ammo_result")

	_press_reload(player)
	await _wait_for_reload_complete(player, weapon)
	var result: Dictionary = player.call("get_last_reload_result")
	if bool(result.get("reloaded", false)):
		_errors.append("Pressing R without compatible ammo should not reload.")
	if str(result.get("blocked_reason", "")) != "no_compatible_ammo":
		_errors.append("Pressing R without No.7 ammo should report no_compatible_ammo.")
	if int(weapon.get("current_ammo")) != 0:
		_errors.append("No-ammo reload attempt should leave the pistol magazine empty.")

	_free_node(context["scene"])


func _validate_r_key_loads_equipped_pistol_from_backpack() -> void:
	var context := await _spawn_context()
	if context.is_empty():
		return
	var player: Node = context["player"]
	var weapon: Node = context["weapon"]
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	player.set("reload_duration_seconds", 0.05)
	backpack_model.clear()
	backpack_model.setup(50)
	backpack_model.add_item(Pistol, 1)
	backpack_model.add_item(Ammo, 24)
	if not bool(player.call("equip_inventory_stack", 0)):
		_errors.append("Reload validation should equip No.5 pistol from backpack.")
	await process_frame
	weapon.set("current_ammo", 0)
	weapon.set("reserve_ammo", 0)
	if weapon.has_method("_sync_ammo_result"):
		weapon.call("_sync_ammo_result")

	_press_reload(player)
	await _wait_for_reload_complete(player, weapon)
	var result: Dictionary = player.call("get_last_reload_result")
	if not bool(result.get("reloaded", false)):
		_errors.append("Pressing R with No.5 equipped and No.7 ammo in backpack should reload.")
	if int(result.get("rounds_loaded", 0)) != 8:
		_errors.append("R reload should load the 8-round No.5 pistol magazine.")
	if int(weapon.get("current_ammo")) != 8:
		_errors.append("WeaponController3D current_ammo should show 8 after R reload.")
	if int(_first_stack_quantity(backpack_model, Ammo)) != 16:
		_errors.append("Backpack No.7 ammo should drop from 24 to 16 after loading 8 rounds.")
	_free_node(context["scene"])


func _validate_empty_left_click_auto_reloads_without_firing() -> void:
	var context := await _spawn_context()
	if context.is_empty():
		return
	var player: Node = context["player"]
	var weapon: Node = context["weapon"]
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	player.set("reload_duration_seconds", 0.05)
	backpack_model.clear()
	backpack_model.setup(50)
	backpack_model.add_item(Pistol, 1)
	backpack_model.add_item(Ammo, 24)
	if not bool(player.call("equip_inventory_stack", 0)):
		_errors.append("Auto reload validation should equip No.5 pistol from backpack.")
	await process_frame
	weapon.set("current_ammo", 0)
	weapon.set("reserve_ammo", 0)
	if weapon.has_method("_sync_ammo_result"):
		weapon.call("_sync_ammo_result")
	if weapon.has_method("force_cooldown_ready"):
		weapon.call("force_cooldown_ready")

	_press_primary_fire(player)
	await _wait_for_reload_complete(player, weapon)
	var result: Dictionary = player.call("get_last_reload_result")
	if not bool(result.get("reloaded", false)):
		_errors.append("Left-clicking with an empty magazine and compatible backpack ammo should auto-reload.")
	if str(result.get("source", "")) != "empty_fire":
		_errors.append("Auto reload should record empty_fire as the reload source.")
	if int(weapon.get("current_ammo")) != 8:
		_errors.append("Empty-fire auto reload should fill the pistol to 8 rounds.")
	if bool(weapon.get("last_fire_result").get("fired", false)):
		_errors.append("The empty left click that triggers reload should not also fire a shot.")
	if int(_first_stack_quantity(backpack_model, Ammo)) != 16:
		_errors.append("Empty-fire auto reload should consume 8 rounds from backpack No.7 ammo.")
	_free_node(context["scene"])


func _validate_source_boundaries() -> void:
	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	for required in ["KEY_R", "reload_equipped_weapon", "_should_auto_reload_before_fire", "_find_compatible_ammo_stack", "consume_stack_quantity", "empty_fire"]:
		if not player_source.contains(required):
			_errors.append("PlayerController3D should expose R reload flow term: %s." % required)

	var weapon_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_controller_3d.gd")
	for required in ["reload_from_item", "last_reload_result", "reload_blocked", "reloaded"]:
		if not weapon_source.contains(required):
			_errors.append("WeaponController3D should expose reload result API term: %s." % required)
	for forbidden in ["get_inventory_model", "InventoryEquipmentUI", "ContainerInventoryUI"]:
		if weapon_source.contains(forbidden):
			_errors.append("WeaponController3D should not directly read backpack or UI for reload: %s." % forbidden)

	var inventory_source := FileAccess.get_file_as_string("res://scripts/inventory/inventory_model.gd")
	if not inventory_source.contains("consume_stack_quantity"):
		_errors.append("InventoryModel should own partial stack consumption for reload.")


func _press_reload(player: Node) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_R
	event.physical_keycode = KEY_R
	player.call("_unhandled_input", event)


func _press_primary_fire(player: Node) -> void:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	player.call("_unhandled_input", event)


func _wait_for_reload_complete(player: Node, weapon: Node) -> void:
	for _frame in range(20):
		await physics_frame
		await process_frame
		var state: Dictionary = player.call("get_reload_state")
		if not bool(state.get("active", false)) and int(weapon.get("current_ammo")) > 0:
			return


func _first_stack_quantity(inventory_model: InventoryModel, item_def: ItemDef) -> int:
	for stack in inventory_model.get_display_items():
		if stack.get("id") == item_def.id:
			return int(stack.get("quantity", 0))
	return 0


func _spawn_context() -> Dictionary:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var player := scene.get_node_or_null("Player3D")
	var weapon := player.get_node_or_null("WeaponController3D") if player != null else null
	var hud := scene.find_child("RaidHudPanel", true, false) as Control
	if player == null:
		_errors.append("Gameplay scene should include Player3D.")
		_free_node(scene)
		return {}
	if weapon == null:
		_errors.append("Player3D should include WeaponController3D.")
		_free_node(scene)
		return {}
	if hud == null:
		_errors.append("Gameplay scene should include RaidHudPanel.")
		_free_node(scene)
		return {}
	return {
		"scene": scene,
		"player": player,
		"weapon": weapon,
		"hud": hud,
	}


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
