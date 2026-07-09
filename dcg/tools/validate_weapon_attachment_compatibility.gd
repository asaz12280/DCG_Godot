extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const WeaponAttachmentServiceScript := preload("res://scripts/combat/weapon_attachment_service.gd")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")
const SMG := preload("res://data/items/weapons/smg_9mm.tres")
const Knife := preload("res://data/items/weapons/combat_knife.tres")
const ExtendedMagazine := preload("res://data/items/attachments/extended_magazine.tres")
const BalancedGrip := preload("res://data/items/attachments/balanced_grip.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	_validate_item_data()
	_validate_service_support()
	await _validate_player_bridge()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[weapon_attachment_compatibility] OK weapon_data=slots service=weapon_mods player=bridge boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_item_data() -> void:
	_validate_weapon_slot_data(Pistol, "Pistol-S")
	_validate_weapon_slot_data(SMG, "SMG-S")
	if not Knife.weapon_attachment_slots.is_empty():
		_errors.append("Combat Knife should not declare firearm attachment slots.")


func _validate_weapon_slot_data(weapon_def: ItemDef, label: String) -> void:
	if not weapon_def.weapon_attachment_slots.has(&"magazine"):
		_errors.append("%s should declare magazine attachment support." % label)
	if not weapon_def.weapon_attachment_slots.has(&"grip"):
		_errors.append("%s should declare grip attachment support." % label)
	var weapon_stack := weapon_def.to_stack(1)
	var stack_slots: Array = weapon_stack.get("weapon_attachment_slots", []) as Array
	if not stack_slots.has(&"magazine") or not stack_slots.has(&"grip"):
		_errors.append("%s stacks should expose weapon_attachment_slots for UI and save-independent planning." % label)


func _validate_service_support() -> void:
	var weapon_stack := _weapon_stack_with_both_attachments(Pistol)
	_validate_service_support_for_weapon(Pistol, weapon_stack, "Pistol-S")
	_validate_service_support_for_weapon(SMG, _weapon_stack_with_both_attachments(SMG), "SMG-S")

	var knife_mods: Dictionary = WeaponAttachmentServiceScript.modifiers_for_weapon_stack(weapon_stack, Knife)
	if int(knife_mods.get("magazine_capacity_bonus", 0)) != 0:
		_errors.append("Combat Knife should reject firearm magazine bonuses.")
	if absf(float(knife_mods.get("horizontal_recoil_multiplier", 0.0)) - 1.0) > 0.001:
		_errors.append("Combat Knife should reject grip recoil multipliers.")
	if not (knife_mods.get("attachment_ids", []) as Array).is_empty():
		_errors.append("Combat Knife should not expose applied weapon attachment ids.")

	var mag_only_weapon := _temporary_pistol_weapon([&"magazine"])
	var mag_only_mods: Dictionary = WeaponAttachmentServiceScript.modifiers_for_weapon_stack(weapon_stack, mag_only_weapon)
	if int(mag_only_mods.get("magazine_capacity_bonus", 0)) != 4:
		_errors.append("A weapon declaring only magazine support should accept the magazine attachment.")
	if absf(float(mag_only_mods.get("horizontal_recoil_multiplier", 0.0)) - 1.0) > 0.001:
		_errors.append("A weapon declaring only magazine support should reject grip modifiers.")
	if (mag_only_mods.get("attachment_ids", []) as Array).has("balanced_grip"):
		_errors.append("A magazine-only weapon should not report Balanced Grip-S as applied.")

	var grip_only_weapon := _temporary_pistol_weapon([&"grip"])
	var grip_only_mods: Dictionary = WeaponAttachmentServiceScript.modifiers_for_weapon_stack(weapon_stack, grip_only_weapon)
	if int(grip_only_mods.get("magazine_capacity_bonus", 0)) != 0:
		_errors.append("A weapon declaring only grip support should reject magazine bonuses.")
	if absf(float(grip_only_mods.get("horizontal_recoil_multiplier", 0.0)) - 0.8) > 0.001:
		_errors.append("A weapon declaring only grip support should accept grip recoil modifiers.")
	if (grip_only_mods.get("attachment_ids", []) as Array).has("extended_magazine"):
		_errors.append("A grip-only weapon should not report Extended Magazine-S as applied.")


func _validate_service_support_for_weapon(weapon_def: ItemDef, weapon_stack: Dictionary, label: String) -> void:
	var modifiers: Dictionary = WeaponAttachmentServiceScript.modifiers_for_weapon_stack(weapon_stack, weapon_def)
	if int(modifiers.get("magazine_capacity_bonus", 0)) != 4:
		_errors.append("%s should apply compatible magazine capacity bonus from weapon_mods." % label)
	if absf(float(modifiers.get("horizontal_recoil_multiplier", 0.0)) - 0.8) > 0.001:
		_errors.append("%s should apply compatible grip recoil multiplier from weapon_mods." % label)
	var attachment_ids: Array = modifiers.get("attachment_ids", []) as Array
	if not attachment_ids.has("extended_magazine") or not attachment_ids.has("balanced_grip"):
		_errors.append("%s should expose both applied compatible attachment ids." % label)


func _validate_player_bridge() -> void:
	await _validate_player_bridge_for_weapon(Pistol, "Pistol-S")
	await _validate_player_bridge_for_weapon(SMG, "SMG-S")


func _validate_player_bridge_for_weapon(weapon_def: ItemDef, label: String) -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var player := scene.get_node_or_null("Player3D")
	if player == null:
		_errors.append("Gameplay scene should include Player3D.")
		_free_node(scene)
		return
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	var equipment_model: RefCounted = player.call("get_equipment_model")
	backpack_model.clear()
	backpack_model.setup(50)
	equipment_model.call("clear")
	backpack_model.add_stack(weapon_def.to_stack(1))
	backpack_model.add_stack(ExtendedMagazine.to_stack(1))
	backpack_model.add_stack(BalancedGrip.to_stack(1))
	player.call("equip_inventory_stack", 0, &"primary_weapon")
	player.call("attach_inventory_stack_to_weapon", 0, &"primary_weapon")
	player.call("attach_inventory_stack_to_weapon", 0, &"primary_weapon")
	await process_frame
	var attachment_state: Dictionary = player.call("get_active_weapon_attachment_state")
	if int(attachment_state.get("magazine_capacity_bonus", 0)) != 4:
		_errors.append("Player active %s should receive magazine hardpoint compatibility." % label)
	if absf(float(attachment_state.get("horizontal_recoil_multiplier", 0.0)) - 0.8) > 0.001:
		_errors.append("Player active %s should receive grip hardpoint compatibility." % label)
	var knife_mods: Dictionary = WeaponAttachmentServiceScript.modifiers_for_weapon_stack(equipment_model.call("get_slot", &"primary_weapon"), Knife)
	if int(knife_mods.get("magazine_capacity_bonus", 0)) != 0 or not (knife_mods.get("attachment_ids", []) as Array).is_empty():
		_errors.append("The same weapon_mods should not apply when the weapon definition is a knife.")
	_free_node(scene)


func _validate_source_boundaries() -> void:
	var item_source := FileAccess.get_file_as_string("res://scripts/items/item_def.gd")
	if not item_source.contains("weapon_attachment_slots"):
		_errors.append("ItemDef should own weapon attachment slot data.")
	var service_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_attachment_service.gd")
	for required in ["modifiers_for_weapon_stack", "weapon_mod_stack", "_weapon_supports_attachment_slot", "_attachment_slot_tags", "weapon_attachment_slots"]:
		if not service_source.contains(required):
			_errors.append("WeaponAttachmentService should own weapon slot compatibility filtering: %s." % required)
	for forbidden in ["Control", "InventoryEquipmentUI", "BaseStashInventoryUI", "SaveGameManager", "WeaponController3D"]:
		if service_source.contains(forbidden):
			_errors.append("WeaponAttachmentService should stay data/model focused and not depend on %s." % forbidden)
	var equipment_source := FileAccess.get_file_as_string("res://scripts/equipment/equipment_model.gd")
	for required in ["attach_weapon_mod", "_weapon_hardpoint_for_attachment"]:
		if not equipment_source.contains(required):
			_errors.append("EquipmentModel should own weapon hardpoint placement without UI dependencies: %s." % required)


func _weapon_stack_with_both_attachments(weapon_def: ItemDef) -> Dictionary:
	var stack := weapon_def.to_stack(1)
	stack["weapon_mods"] = {
		"magazine": ExtendedMagazine.to_stack(1),
		"grip": BalancedGrip.to_stack(1),
	}
	return stack


func _temporary_pistol_weapon(slots: Array[StringName]) -> ItemDef:
	var weapon := ItemDef.new()
	weapon.id = &"validation_pistol"
	weapon.item_type = "weapon"
	weapon.tags = [&"gun", &"pistol", &"S"]
	weapon.compatible_ammo_tags = [&"S"]
	weapon.weapon_attachment_slots = slots.duplicate()
	return weapon


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
