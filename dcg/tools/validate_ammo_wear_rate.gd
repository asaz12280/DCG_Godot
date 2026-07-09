extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")
const Ammo := preload("res://data/items/ammo/ammo_9mm.tres")
const PolishedAmmo := preload("res://data/items/ammo/ammo_9mm_polished.tres")
const ItemDurabilityServiceScript := preload("res://scripts/items/item_durability_service.gd")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	_validate_item_data()
	_validate_service_fractional_ammo_wear()
	await _validate_fire_path_uses_loaded_ammo_wear_rate()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[ammo_wear_rate] OK data=ammo service=fractional fire=loaded_ammo progress=save_ready boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_item_data() -> void:
	if Ammo.item_type != "ammo":
		_errors.append("Ammo-S should remain an ammo item.")
	if Ammo.weapon_wear_rate <= 0.0:
		_errors.append("Ammo-S should expose a positive weapon_wear_rate for durability wear.")
	var stack := Ammo.to_stack(3)
	if float(stack.get("weapon_wear_rate", 0.0)) != Ammo.weapon_wear_rate:
		_errors.append("Ammo stacks should expose weapon_wear_rate for UI and save-independent planning.")
	if PolishedAmmo.item_type != "ammo" or PolishedAmmo.ammo_tag != Ammo.ammo_tag:
		_errors.append("Polished Ammo-S should remain compatible with the baseline S-type pistol ammo.")
	if PolishedAmmo.weapon_wear_rate >= Ammo.weapon_wear_rate:
		_errors.append("Polished Ammo-S should have a lower weapon wear rate than baseline Ammo-S.")
	var polished_stack := PolishedAmmo.to_stack(3)
	if absf(float(polished_stack.get("weapon_wear_rate", 0.0)) - PolishedAmmo.weapon_wear_rate) > 0.001:
		_errors.append("Polished Ammo-S stacks should expose their lower weapon_wear_rate.")


func _validate_service_fractional_ammo_wear() -> void:
	var slow_ammo := _ammo_def(0.5)
	var fast_ammo := _ammo_def(2.0)
	var stack := _durable_pistol_stack(10, 10)
	var first: Dictionary = ItemDurabilityServiceScript.apply_ammo_use_wear(stack, Pistol, slow_ammo, 1)
	if int(first.get("current_durability", 0)) != 10 or absf(float(first.get("durability_wear_progress", 0.0)) - 0.5) > 0.001:
		_errors.append("A 0.5 wear-rate round should accumulate progress without immediately reducing durability.")
	var second: Dictionary = ItemDurabilityServiceScript.apply_ammo_use_wear(first, Pistol, slow_ammo, 1)
	if int(second.get("current_durability", 0)) != 9 or absf(float(second.get("durability_wear_progress", 0.0))) > 0.001:
		_errors.append("Two 0.5 wear-rate rounds should reduce durability once and clear progress.")
	var polished_first: Dictionary = ItemDurabilityServiceScript.apply_ammo_use_wear(stack, Pistol, PolishedAmmo, 1)
	if int(polished_first.get("current_durability", 0)) != 10 or absf(float(polished_first.get("durability_wear_progress", 0.0)) - 0.5) > 0.001:
		_errors.append("Real Polished Ammo-S should use its lower 0.5 weapon wear rate.")
	var fast: Dictionary = ItemDurabilityServiceScript.apply_ammo_use_wear(stack, Pistol, fast_ammo, 1)
	if int(fast.get("current_durability", 0)) != 8:
		_errors.append("A 2.0 wear-rate round should reduce two durability points.")
	var fallback: Dictionary = ItemDurabilityServiceScript.apply_ammo_use_wear(stack, Pistol, null, 1)
	if int(fallback.get("current_durability", 0)) != 9:
		_errors.append("Missing ammo data should keep the previous one-durability-per-shot baseline.")


func _validate_fire_path_uses_loaded_ammo_wear_rate() -> void:
	var context := await _spawn_context()
	if context.is_empty():
		return
	var player: Node = context["player"]
	var weapon: Node = context["weapon"]
	var equipment: RefCounted = player.call("get_equipment_model")
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	backpack_model.clear()
	backpack_model.setup(50)
	backpack_model.add_stack(_durable_pistol_stack(12, 12))
	if not bool(player.call("equip_inventory_stack", 0, &"primary_weapon")):
		_errors.append("Ammo wear validation should equip a durable pistol.")
		_free_node(context["scene"])
		return
	await process_frame
	_load_weapon_with_ammo(weapon, _ammo_def(2.0), 2)
	_press_primary_fire(player)
	await process_frame
	var primary_stack: Dictionary = equipment.call("get_slot", &"primary_weapon")
	if int(primary_stack.get("current_durability", 0)) != 10:
		_errors.append("A shot with 2.0 wear-rate ammo should reduce equipped durability from 12 to 10.")
	if int(weapon.get("current_ammo")) != 1:
		_errors.append("Ammo wear shot should still consume exactly one loaded round.")

	if not bool(equipment.call("equip_stack", &"primary_weapon", _durable_pistol_stack(12, 12))):
		_errors.append("Ammo wear validation should reset equipment for fractional ammo.")
		_free_node(context["scene"])
		return
	await process_frame
	_load_weapon_with_ammo(weapon, PolishedAmmo, 2)
	_press_primary_fire(player)
	await process_frame
	if weapon.has_method("force_cooldown_ready"):
		weapon.call("force_cooldown_ready")
	_press_primary_fire(player)
	await process_frame
	primary_stack = equipment.call("get_slot", &"primary_weapon")
	if int(primary_stack.get("current_durability", 0)) != 11:
		_errors.append("Two shots with 0.5 wear-rate ammo should reduce equipped durability from 12 to 11.")
	if absf(float(primary_stack.get("durability_wear_progress", 0.0))) > 0.001:
		_errors.append("Fractional ammo wear progress should be cleared after reaching a whole durability point.")

	_free_node(context["scene"])


func _validate_source_boundaries() -> void:
	var item_source := FileAccess.get_file_as_string("res://scripts/items/item_def.gd")
	if not item_source.contains("weapon_wear_rate"):
		_errors.append("ItemDef should own ammo weapon_wear_rate data.")
	var durability_source := FileAccess.get_file_as_string("res://scripts/items/item_durability_service.gd")
	for required in ["apply_ammo_use_wear", "ammo_weapon_wear_rate", "durability_wear_progress"]:
		if not durability_source.contains(required):
			_errors.append("ItemDurabilityService should own ammo wear behavior through %s." % required)
	for forbidden in ["WeaponController3D", "PlayerController3D", "EquipmentModel"]:
		if durability_source.contains(forbidden):
			_errors.append("ItemDurabilityService ammo wear should stay model-only and not depend on %s." % forbidden)
	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	for required in ["_current_loaded_ammo_item", "apply_ammo_use_wear"]:
		if not player_source.contains(required):
			_errors.append("PlayerController3D should bridge loaded ammo into durability wear through %s." % required)
	var weapon_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_controller_3d.gd")
	for forbidden in ["ItemDurabilityServiceScript", "EquipmentModel", "weapon_wear_rate"]:
		if weapon_source.contains(forbidden):
			_errors.append("WeaponController3D should not own ammo durability wear rules: %s." % forbidden)


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


func _ammo_def(wear_rate: float) -> ItemDef:
	var ammo := ItemDef.new()
	ammo.id = StringName("validation_ammo_%s" % str(wear_rate).replace(".", "_"))
	ammo.item_type = "ammo"
	ammo.ammo_tag = &"S"
	ammo.weapon_wear_rate = wear_rate
	ammo.max_stack = 60
	return ammo


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
