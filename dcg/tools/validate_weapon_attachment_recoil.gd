extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const WeaponAttachmentServiceScript := preload("res://scripts/combat/weapon_attachment_service.gd")
const ItemStackTooltipPresenterScript := preload("res://scripts/ui/item_stack_tooltip_presenter.gd")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")
const Ammo := preload("res://data/items/ammo/ammo_9mm.tres")
const BalancedGrip := preload("res://data/items/attachments/balanced_grip.tres")
const ExtendedMagazine := preload("res://data/items/attachments/extended_magazine.tres")
const Helmet := preload("res://data/items/armor/basic_helmet.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	_validate_item_data_and_tooltip()
	_validate_attachment_service()
	await _validate_player_recoil_bridge()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[weapon_attachment_recoil] OK data=balanced_grip weapon_mods=recoil player=impulse tooltip=visible boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_item_data_and_tooltip() -> void:
	if BalancedGrip.item_type != "attachment":
		_errors.append("Balanced Grip-S should remain an attachment item.")
	if not BalancedGrip.tags.has(&"grip") or not BalancedGrip.tags.has(&"pistol"):
		_errors.append("Balanced Grip-S should be tagged as a pistol grip attachment.")
	if absf(BalancedGrip.attachment_vertical_recoil_multiplier - 0.8) > 0.001:
		_errors.append("Balanced Grip-S should reduce vertical recoil to 0.8x.")
	if absf(BalancedGrip.attachment_horizontal_recoil_multiplier - 0.8) > 0.001:
		_errors.append("Balanced Grip-S should reduce horizontal recoil to 0.8x.")
	if absf(BalancedGrip.attachment_recoil_recovery_multiplier - 1.2) > 0.001:
		_errors.append("Balanced Grip-S should improve recoil recovery to 1.2x.")
	var stack := BalancedGrip.to_stack(1)
	if absf(float(stack.get("attachment_vertical_recoil_multiplier", 0.0)) - 0.8) > 0.001:
		_errors.append("Attachment stacks should expose vertical recoil multiplier for UI and save-independent planning.")
	var owner := Control.new()
	root.add_child(owner)
	var tooltip := ItemStackTooltipPresenterScript.build(owner, stack)
	var text := ItemStackTooltipPresenterScript.tooltip_text(tooltip)
	if not text.contains("0.80x"):
		_errors.append("Balanced Grip-S tooltip should show recoil reduction multiplier.")
	if not text.contains("1.20x"):
		_errors.append("Balanced Grip-S tooltip should show recoil recovery multiplier.")
	_free_node(owner)


func _validate_attachment_service() -> void:
	var weapon_stack := _weapon_stack_with_mods({
		"grip": BalancedGrip.to_stack(1),
		"magazine": ExtendedMagazine.to_stack(1),
	})
	var pistol_mods: Dictionary = WeaponAttachmentServiceScript.modifiers_for_weapon_stack(weapon_stack, Pistol)
	if absf(float(pistol_mods.get("vertical_recoil_multiplier", 0.0)) - 0.8) > 0.001:
		_errors.append("WeaponAttachmentService should apply compatible Pistol-S vertical recoil multiplier from weapon_mods.")
	if absf(float(pistol_mods.get("horizontal_recoil_multiplier", 0.0)) - 0.8) > 0.001:
		_errors.append("WeaponAttachmentService should apply compatible Pistol-S horizontal recoil multiplier from weapon_mods.")
	if absf(float(pistol_mods.get("recoil_recovery_multiplier", 0.0)) - 1.2) > 0.001:
		_errors.append("WeaponAttachmentService should apply compatible Pistol-S recoil recovery multiplier from weapon_mods.")
	if int(pistol_mods.get("magazine_capacity_bonus", 0)) != 4:
		_errors.append("WeaponAttachmentService should preserve magazine capacity while adding recoil modifiers.")
	if not (pistol_mods.get("attachment_ids", []) as Array).has("balanced_grip"):
		_errors.append("WeaponAttachmentService should expose Balanced Grip-S as an applied attachment id.")
	var helmet_mods: Dictionary = WeaponAttachmentServiceScript.modifiers_for_weapon_stack(weapon_stack, Helmet)
	if absf(float(helmet_mods.get("vertical_recoil_multiplier", 0.0)) - 1.0) > 0.001:
		_errors.append("WeaponAttachmentService should not apply grip recoil bonuses to non-weapon armor.")


func _validate_player_recoil_bridge() -> void:
	var baseline := await _fire_one_shot(false)
	var gripped := await _fire_one_shot(true)
	if baseline.is_empty() or gripped.is_empty():
		return
	var baseline_horizontal := absf(float(baseline.get("horizontal_impulse_degrees", 0.0)))
	var gripped_horizontal := absf(float(gripped.get("horizontal_impulse_degrees", 0.0)))
	var baseline_range := Pistol.weapon_horizontal_recoil * Ammo.ammo_recoil_multiplier
	var gripped_range := baseline_range * BalancedGrip.attachment_horizontal_recoil_multiplier
	if baseline_horizontal > baseline_range + 0.001:
		_errors.append("Baseline shot should stay inside the Pistol-S horizontal recoil fan.")
	if gripped_horizontal > gripped_range + 0.001:
		_errors.append("Balanced Grip-S shot should stay inside the reduced horizontal recoil fan.")
	if gripped_range >= baseline_range:
		_errors.append("Balanced Grip-S should reduce the player's horizontal recoil fan.")
	if absf(float(gripped.get("attachment_horizontal_recoil_multiplier", 0.0)) - 0.8) > 0.001:
		_errors.append("Player recoil state should expose the active attachment horizontal multiplier from weapon_mods.")
	if absf(float(gripped.get("attachment_recoil_recovery_multiplier", 0.0)) - 1.2) > 0.001:
		_errors.append("Player recoil state should expose the active attachment recovery multiplier from weapon_mods.")
	if not (gripped.get("attachment_ids", []) as Array).has("balanced_grip"):
		_errors.append("Player recoil state should include the applied Balanced Grip-S id.")


func _validate_source_boundaries() -> void:
	var item_source := FileAccess.get_file_as_string("res://scripts/items/item_def.gd")
	for required in ["attachment_vertical_recoil_multiplier", "attachment_horizontal_recoil_multiplier", "attachment_recoil_recovery_multiplier"]:
		if not item_source.contains(required):
			_errors.append("ItemDef should own attachment recoil data field: %s." % required)
	var service_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_attachment_service.gd")
	for required in ["modifiers_for_weapon_stack", "vertical_recoil_multiplier", "horizontal_recoil_multiplier", "recoil_recovery_multiplier", "_has_weapon_modifier"]:
		if not service_source.contains(required):
			_errors.append("WeaponAttachmentService should own weapon-mounted attachment recoil math: %s." % required)
	for forbidden in ["Control", "InventoryEquipmentUI", "BaseStashInventoryUI", "SaveGameManager", "WeaponController3D"]:
		if service_source.contains(forbidden):
			_errors.append("WeaponAttachmentService should stay data/model focused and not depend on %s." % forbidden)
	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	if not player_source.contains("WeaponAttachmentServiceScript.modifiers_for_weapon_stack"):
		_errors.append("PlayerController3D should bridge recoil attachments through weapon stack modifiers.")
	if player_source.contains("balanced_grip"):
		_errors.append("PlayerController3D should not hardcode a specific attachment resource.")
	var tooltip_source := FileAccess.get_file_as_string("res://scripts/ui/item_stack_tooltip_presenter.gd")
	for required in ["ui.item.attachment_recoil_multiplier_format", "ui.item.attachment_recoil_recovery_format"]:
		if not tooltip_source.contains(required):
			_errors.append("Shared tooltip presenter should show attachment recoil stat key: %s." % required)


func _fire_one_shot(use_grip: bool) -> Dictionary:
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
	backpack_model.add_stack(_durable_pistol_stack(12, 12))
	if use_grip:
		backpack_model.add_stack(BalancedGrip.to_stack(1))
	if not bool(player.call("equip_inventory_stack", 0, &"primary_weapon")):
		_errors.append("Attachment recoil validation should equip Pistol-S.")
		_free_node(scene)
		return {}
	if use_grip and not bool(player.call("attach_inventory_stack_to_weapon", 0, &"primary_weapon")):
		_errors.append("Attachment recoil validation should attach Balanced Grip-S into Pistol-S weapon_mods.")
		_free_node(scene)
		return {}
	await process_frame
	_load_weapon_with_ammo(weapon, Ammo, 2)
	_press_primary_fire(player)
	var recoil_state: Dictionary = player.call("get_last_weapon_recoil_state")
	_free_node(scene)
	return recoil_state


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


func _weapon_stack_with_mods(mods: Dictionary) -> Dictionary:
	var stack := Pistol.to_stack(1)
	stack["weapon_mods"] = mods.duplicate(true)
	return stack


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
