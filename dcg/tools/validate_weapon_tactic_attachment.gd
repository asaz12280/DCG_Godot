extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const WeaponAttachmentServiceScript := preload("res://scripts/combat/weapon_attachment_service.gd")
const ItemStackTooltipPresenterScript := preload("res://scripts/ui/item_stack_tooltip_presenter.gd")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")
const Knife := preload("res://data/items/weapons/combat_knife.tres")
const TargetingLaser := preload("res://data/items/attachments/targeting_laser.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	_validate_item_data_and_tooltip()
	_validate_weapon_stack_service()
	await _validate_player_spread_bridge()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[weapon_tactic_attachment] OK data=targeting_laser weapon_mods=tactic service=spread player=spread_multiplier boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_item_data_and_tooltip() -> void:
	if TargetingLaser.item_type != "attachment":
		_errors.append("Targeting Laser-S should remain an attachment item.")
	if not TargetingLaser.tags.has(&"tactic") or not TargetingLaser.tags.has(&"pistol"):
		_errors.append("Targeting Laser-S should be tagged as a pistol tactic attachment.")
	if absf(TargetingLaser.attachment_spread_multiplier - 0.9) > 0.001:
		_errors.append("Targeting Laser-S should tighten spread to 0.9x.")
	if not Pistol.weapon_attachment_slots.has(&"tactic"):
		_errors.append("Pistol-S should declare tactic attachment support before laser modifiers can apply.")
	var stack := TargetingLaser.to_stack(1)
	if absf(float(stack.get("attachment_spread_multiplier", 0.0)) - 0.9) > 0.001:
		_errors.append("Attachment stacks should expose targeting laser spread multiplier.")
	var owner := Control.new()
	root.add_child(owner)
	var tooltip := ItemStackTooltipPresenterScript.build(owner, stack)
	var text := ItemStackTooltipPresenterScript.tooltip_text(tooltip)
	if not text.contains("0.90x"):
		_errors.append("Targeting Laser-S tooltip should show its spread multiplier.")
	_free_node(owner)


func _validate_weapon_stack_service() -> void:
	var weapon_stack := _weapon_stack_with_mod(&"tactic", TargetingLaser.to_stack(1))
	var pistol_mods: Dictionary = WeaponAttachmentServiceScript.modifiers_for_weapon_stack(weapon_stack, Pistol)
	if absf(float(pistol_mods.get("spread_multiplier", 0.0)) - 0.9) > 0.001:
		_errors.append("WeaponAttachmentService should apply Targeting Laser-S spread multiplier from weapon_mods.")
	if not (pistol_mods.get("attachment_ids", []) as Array).has("targeting_laser"):
		_errors.append("WeaponAttachmentService should expose Targeting Laser-S as an applied attachment id.")

	var knife_mods: Dictionary = WeaponAttachmentServiceScript.modifiers_for_weapon_stack(weapon_stack, Knife)
	if absf(float(knife_mods.get("spread_multiplier", 0.0)) - 1.0) > 0.001:
		_errors.append("Combat Knife should not receive tactic spread modifiers.")

	var stock_only_weapon := _temporary_pistol_weapon([&"stock"])
	var stock_only_mods: Dictionary = WeaponAttachmentServiceScript.modifiers_for_weapon_stack(weapon_stack, stock_only_weapon)
	if (stock_only_mods.get("attachment_ids", []) as Array).has("targeting_laser"):
		_errors.append("A weapon without tactic support should reject Targeting Laser-S.")


func _validate_player_spread_bridge() -> void:
	var baseline := await _fire_worn_pistol(false)
	var lasered := await _fire_worn_pistol(true)
	if baseline.is_empty() or lasered.is_empty():
		return
	if absf(float(baseline.get("attachment_spread_multiplier", 0.0)) - 1.0) > 0.001:
		_errors.append("Baseline worn pistol should report neutral attachment spread multiplier.")
	if absf(float(lasered.get("attachment_spread_multiplier", 0.0)) - 0.9) > 0.001:
		_errors.append("Lasered worn pistol should report Targeting Laser-S attachment spread multiplier from weapon_mods.")
	var expected_spread := float(lasered.get("base_spread_degrees", 0.0)) * 0.9
	if absf(float(lasered.get("spread_degrees", 0.0)) - expected_spread) > 0.001:
		_errors.append("Lasered worn pistol should scale spread to %.2f, got %.2f." % [expected_spread, float(lasered.get("spread_degrees", 0.0))])
	if float(lasered.get("spread_degrees", 0.0)) >= float(baseline.get("spread_degrees", 0.0)):
		_errors.append("Targeting Laser-S should tighten low-durability spread compared with baseline.")


func _validate_source_boundaries() -> void:
	var service_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_attachment_service.gd")
	for required in ["modifiers_for_weapon_stack", "tactic", "_weapon_supports_attachment_slot", "spread_multiplier"]:
		if not service_source.contains(required):
			_errors.append("WeaponAttachmentService should keep tactic compatibility and spread math: %s." % required)
	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	for required in ["_current_attachment_spread_multiplier", "WeaponAttachmentServiceScript.modifiers_for_weapon_stack", "attach_inventory_stack_to_weapon"]:
		if not player_source.contains(required):
			_errors.append("PlayerController3D should route tactic attachments through weapon-owned mods: %s." % required)
	if player_source.contains("targeting_laser"):
		_errors.append("PlayerController3D should not hardcode a specific tactic resource.")
	var localization_source := FileAccess.get_file_as_string("res://data/localization/game_text.csv")
	for required in ["item.targeting_laser.name", "item.targeting_laser.desc"]:
		if not localization_source.contains(required):
			_errors.append("Tactic attachment text should stay centralized in localization: %s." % required)


func _fire_worn_pistol(use_laser: bool) -> Dictionary:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var player := scene.get_node_or_null("Player3D")
	var weapon := player.get_node_or_null("WeaponController3D") if player != null else null
	if player == null or weapon == null:
		_errors.append("Gameplay scene should include Player3D and WeaponController3D.")
		_free_node(scene)
		return {}
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	backpack_model.clear()
	backpack_model.setup(50)
	backpack_model.add_stack(_durable_pistol_stack(5, 12))
	if use_laser:
		backpack_model.add_stack(TargetingLaser.to_stack(1))
	if not bool(player.call("equip_inventory_stack", 0, &"primary_weapon")):
		_errors.append("Tactic spread validation should equip worn Pistol-S.")
		_free_node(scene)
		return {}
	if use_laser and not bool(player.call("attach_inventory_stack_to_weapon", 0, &"primary_weapon")):
		_errors.append("Tactic spread validation should attach Targeting Laser-S into Pistol-S weapon_mods.")
		_free_node(scene)
		return {}
	await process_frame
	_prepare_weapon_to_fire(weapon, 2)
	_press_primary_fire(player)
	await process_frame
	var spread_state: Dictionary = player.call("get_last_weapon_spread_state")
	_free_node(scene)
	return spread_state


func _prepare_weapon_to_fire(weapon: Node, ammo: int) -> void:
	weapon.set("current_ammo", ammo)
	weapon.set("reserve_ammo", 0)
	if weapon.has_method("_sync_ammo_result"):
		weapon.call("_sync_ammo_result")
	if weapon.has_method("force_cooldown_ready"):
		weapon.call("force_cooldown_ready")


func _press_primary_fire(player: Node) -> void:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	player.call("_unhandled_input", event)


func _weapon_stack_with_mod(slot_id: StringName, mod_stack: Dictionary) -> Dictionary:
	var stack := Pistol.to_stack(1)
	stack["weapon_mods"] = {str(slot_id): mod_stack.duplicate(true)}
	return stack


func _temporary_pistol_weapon(slots: Array[StringName]) -> ItemDef:
	var weapon := ItemDef.new()
	weapon.id = &"validation_pistol"
	weapon.item_type = "weapon"
	weapon.tags = [&"gun", &"pistol", &"S"]
	weapon.compatible_ammo_tags = [&"S"]
	weapon.weapon_attachment_slots = slots.duplicate()
	return weapon


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
