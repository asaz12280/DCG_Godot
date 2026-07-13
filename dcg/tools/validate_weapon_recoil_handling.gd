extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const Pistol := preload("res://data/items/weapons/pistol_S.tres")
const Ammo := preload("res://data/items/ammo/ammo_S.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	_validate_item_data()
	await _validate_sustained_fire_recoil()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[weapon_recoil_handling] OK data=weapon_owned ammo=neutral fire=random_horizontal sustained=offset boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_item_data() -> void:
	if Pistol.weapon_horizontal_recoil <= 0.0:
		_errors.append("Pistol-S should expose authored horizontal recoil.")
	var weapon_stack := Pistol.to_stack(1)
	if absf(float(weapon_stack.get("weapon_horizontal_recoil", 0.0)) - Pistol.weapon_horizontal_recoil) > 0.001:
		_errors.append("Weapon stacks should expose horizontal recoil for UI and save-independent planning.")
	for stack in [Ammo.to_stack(4)]:
		if stack.has("ammo_recoil_multiplier"):
			_errors.append("Ammo stacks should not expose removed ammo_recoil_multiplier.")


func _validate_sustained_fire_recoil() -> void:
	var baseline := await _fire_two_shots_with_ammo(Ammo)
	if baseline.is_empty():
		return
	var first: Dictionary = baseline.get("first", {}) as Dictionary
	var second: Dictionary = baseline.get("second", {}) as Dictionary
	var spread: Dictionary = baseline.get("spread", {}) as Dictionary
	if not bool(first.get("active", false)):
		_errors.append("First shot should record active weapon recoil state.")
	var baseline_range := Pistol.weapon_horizontal_recoil
	if absf(float(first.get("applied_angle_degrees", 99.0))) > baseline_range + 0.001:
		_errors.append("First shot recoil should stay inside the weapon-owned +/-H recoil fan.")
	if absf(float(first.get("horizontal_impulse_degrees", 0.0))) <= 0.001:
		_errors.append("First shot should apply horizontal recoil to the fired projectile.")
	if absf(float(first.get("accumulated_angle_degrees", 0.0))) <= 0.001:
		_errors.append("First shot should expose a non-zero recoil offset for reticle feedback.")
	if absf(float(second.get("applied_angle_degrees", 99.0))) > baseline_range + 0.001:
		_errors.append("Second shot recoil should stay inside the weapon-owned +/-H recoil fan.")
	if bool(spread.get("active", true)):
		_errors.append("Fresh durability recoil validation should not depend on low-durability spread.")
	if first.has("ammo_recoil_multiplier"):
		_errors.append("Recoil debug state should not expose removed ammo_recoil_multiplier.")


func _validate_source_boundaries() -> void:
	var item_source := FileAccess.get_file_as_string("res://scripts/items/item_def.gd")
	if not item_source.contains("weapon_horizontal_recoil"):
		_errors.append("ItemDef should own weapon recoil data.")
	if item_source.contains("ammo_recoil_multiplier"):
		_errors.append("ItemDef should not reintroduce ammo_recoil_multiplier.")
	var equipment_source := FileAccess.get_file_as_string("res://scripts/player/player_equipment_controller_3d.gd")
	if equipment_source.contains("AmmoBallisticsServiceScript") or equipment_source.contains("ammo_ballistics_service"):
		_errors.append("PlayerEquipmentController3D should not depend on an ammo ballistics service.")
	if equipment_source.contains("ammo_recoil_multiplier") or equipment_source.contains("current_ammo_recoil_multiplier"):
		_errors.append("PlayerEquipmentController3D should not keep ammo recoil multiplier state.")
	var weapon_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_controller_3d.gd")
	if weapon_source.contains("ammo_recoil_multiplier"):
		_errors.append("WeaponController3D should not own ammo recoil tuning.")
	var tooltip_source := FileAccess.get_file_as_string("res://scripts/ui/item_stack_tooltip_presenter.gd")
	if tooltip_source.contains("ui.item.ammo_recoil_multiplier_format"):
		_errors.append("Shared item tooltip presenter should not show ammo recoil multiplier.")


func _fire_two_shots_with_ammo(ammo_def: ItemDef) -> Dictionary:
	var context := await _spawn_context()
	if context.is_empty():
		return {}
	var player: Node = context["player"]
	var weapon: Node = context["weapon"]
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	backpack_model.clear()
	backpack_model.setup(50)
	backpack_model.add_stack(_durable_pistol_stack(12, 12))
	if not bool(player.call("equip_inventory_stack", 0, &"primary_weapon")):
		_errors.append("Recoil validation should equip a fresh Pistol-S.")
		_free_node(context["scene"])
		return {}
	await process_frame
	_load_weapon_with_ammo(weapon, ammo_def, 3)
	_press_primary_fire(player)
	var first_recoil: Dictionary = player.call("get_last_weapon_recoil_state")
	var first_spread: Dictionary = player.call("get_last_weapon_spread_state")
	if weapon.has_method("force_cooldown_ready"):
		weapon.call("force_cooldown_ready")
	_press_primary_fire(player)
	var second_recoil: Dictionary = player.call("get_last_weapon_recoil_state")
	_free_node(context["scene"])
	return {
		"first": first_recoil,
		"second": second_recoil,
		"spread": first_spread,
	}


func _load_weapon_with_ammo(weapon: Node, ammo_def: ItemDef, quantity: int) -> void:
	weapon.set("current_ammo", 0)
	weapon.set("reserve_ammo", 0)
	if weapon.has_method("_sync_ammo_result"):
		weapon.call("_sync_ammo_result")
	var moved := int(weapon.call("reload_from_item", ammo_def, quantity))
	if moved != quantity:
		_errors.append("Validation ammo should load %d rounds, got %d." % [quantity, moved])
	if weapon.has_method("force_cooldown_ready"):
		weapon.call("force_cooldown_ready")


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
