extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const Pistol := preload("res://data/items/weapons/pistol_S.tres")
const Ammo := preload("res://data/items/ammo/ammo_S.tres")
const ItemDurabilityServiceScript := preload("res://scripts/items/item_durability_service.gd")
const RaidLoadoutTransferScript := preload("res://scripts/raid/raid_loadout_transfer.gd")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	_validate_durability_service_use_wear()
	await _validate_successful_fire_wears_equipped_weapon()
	await _validate_blocked_fire_does_not_wear_weapon()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[weapon_durability_wear] OK service=wear fire=equipment_stack no_ammo=no_wear loadout=preserves_worn_durability boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_durability_service_use_wear() -> void:
	var stack := _durable_pistol_stack(2, 6)
	var worn: Dictionary = ItemDurabilityServiceScript.apply_use_wear(stack, Pistol, 1)
	if int(worn.get("current_durability", 0)) != 1:
		_errors.append("ItemDurabilityService.apply_use_wear should reduce current durability by the requested amount.")
	if int(worn.get("max_durability", 0)) != 6:
		_errors.append("Using an item should not reduce max durability; repairs own max durability loss.")
	if not bool(worn.get("durability_is_low", false)):
		_errors.append("Worn gear below half of current max durability should be marked low.")
	var broken: Dictionary = ItemDurabilityServiceScript.apply_use_wear(stack, Pistol, 10)
	if int(broken.get("current_durability", -1)) != 0 or not bool(broken.get("durability_is_broken", false)):
		_errors.append("ItemDurabilityService.apply_use_wear should clamp durability at zero and mark broken.")
	var ammo_stack: Dictionary = ItemDurabilityServiceScript.apply_use_wear(Ammo.to_stack(5), Ammo, 1)
	if bool(ammo_stack.get("has_durability", true)) or int(ammo_stack.get("current_durability", -1)) != 0:
		_errors.append("Non-durable ammo stacks should stay non-durable after use wear is applied.")


func _validate_successful_fire_wears_equipped_weapon() -> void:
	var context := await _spawn_context()
	if context.is_empty():
		return
	var player: Node = context["player"]
	var weapon: Node = context["weapon"]
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	backpack_model.clear()
	backpack_model.setup(50)
	backpack_model.add_stack(_durable_pistol_stack(12, 12))
	if not bool(player.call("equip_inventory_stack", 0)):
		_errors.append("Durability wear validation should equip No.5 pistol from backpack.")
	await process_frame
	weapon.set("current_ammo", 2)
	weapon.set("reserve_ammo", 0)
	if weapon.has_method("_sync_ammo_result"):
		weapon.call("_sync_ammo_result")
	if weapon.has_method("force_cooldown_ready"):
		weapon.call("force_cooldown_ready")

	_press_primary_fire(player)
	await process_frame
	var equipment: RefCounted = player.call("get_equipment_model")
	var primary_stack: Dictionary = equipment.call("get_slot", &"primary_weapon")
	if int(primary_stack.get("current_durability", 0)) != 11:
		_errors.append("A successful shot should reduce equipped weapon durability from 12 to 11.")
	if int(primary_stack.get("max_durability", 0)) != 12:
		_errors.append("A successful shot should preserve equipped weapon max durability.")
	if int(weapon.get("current_ammo")) != 1:
		_errors.append("A successful shot should still consume exactly one loaded round.")
	var state: Dictionary = player.call("get_active_weapon_durability_state")
	if int(state.get("current_durability", 0)) != 11 or str(state.get("slot_id", "")) != "primary_weapon":
		_errors.append("Player should expose the active weapon durability state after a shot.")
	var loadout: Dictionary = RaidLoadoutTransferScript.build_from_player(player)
	var slots: Dictionary = (loadout.get("equipment", {}) as Dictionary).get("slots", {})
	var saved_primary: Dictionary = slots.get("primary_weapon", {}) as Dictionary
	if int(saved_primary.get("current_durability", 0)) != 11 or int(saved_primary.get("max_durability", 0)) != 12:
		_errors.append("RaidLoadoutTransfer should preserve worn equipped weapon durability.")

	_free_node(context["scene"])


func _validate_blocked_fire_does_not_wear_weapon() -> void:
	var context := await _spawn_context()
	if context.is_empty():
		return
	var player: Node = context["player"]
	var weapon: Node = context["weapon"]
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	backpack_model.clear()
	backpack_model.setup(50)
	backpack_model.add_stack(_durable_pistol_stack(7, 12))
	if not bool(player.call("equip_inventory_stack", 0)):
		_errors.append("Blocked fire validation should equip No.5 pistol from backpack.")
	await process_frame
	weapon.set("current_ammo", 0)
	weapon.set("reserve_ammo", 0)
	if weapon.has_method("_sync_ammo_result"):
		weapon.call("_sync_ammo_result")
	if weapon.has_method("force_cooldown_ready"):
		weapon.call("force_cooldown_ready")

	_press_primary_fire(player)
	await process_frame
	var equipment: RefCounted = player.call("get_equipment_model")
	var primary_stack: Dictionary = equipment.call("get_slot", &"primary_weapon")
	if int(primary_stack.get("current_durability", 0)) != 7:
		_errors.append("A no-ammo fire block should not reduce equipped weapon durability.")
	if bool(weapon.get("last_fire_result").get("fired", false)):
		_errors.append("No-ammo fire block should not record a fired shot.")

	_free_node(context["scene"])


func _validate_source_boundaries() -> void:
	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	for required in ["ItemDurabilityServiceScript", "_apply_equipped_weapon_durability_wear", "get_active_weapon_durability_state", "last_fire_result"]:
		if not player_source.contains(required):
			_errors.append("PlayerController3D should bridge fired shots to durable equipment through %s." % required)
	var durability_source := FileAccess.get_file_as_string("res://scripts/items/item_durability_service.gd")
	if not durability_source.contains("apply_use_wear"):
		_errors.append("ItemDurabilityService should own use-wear durability math.")
	for forbidden in ["WeaponController3D", "PlayerController3D", "EquipmentModel"]:
		if durability_source.contains(forbidden):
			_errors.append("ItemDurabilityService should stay model-only and not depend on %s." % forbidden)
	var weapon_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_controller_3d.gd")
	for forbidden in ["ItemDurabilityServiceScript", "EquipmentModel", "get_equipment_model"]:
		if weapon_source.contains(forbidden):
			_errors.append("WeaponController3D should not own equipment durability persistence: %s." % forbidden)


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
	if player == null:
		_errors.append("Gameplay scene should include Player3D.")
		_free_node(scene)
		return {}
	if weapon == null:
		_errors.append("Player3D should include WeaponController3D.")
		_free_node(scene)
		return {}
	return {
		"scene": scene,
		"player": player,
		"weapon": weapon,
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
