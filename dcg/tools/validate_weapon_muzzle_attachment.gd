extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const WeaponAttachmentServiceScript := preload("res://scripts/combat/weapon_attachment_service.gd")
const ItemStackTooltipPresenterScript := preload("res://scripts/ui/item_stack_tooltip_presenter.gd")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")
const Knife := preload("res://data/items/weapons/combat_knife.tres")
const CompactMuzzle := preload("res://data/items/attachments/compact_muzzle.tres")
const BalancedGrip := preload("res://data/items/attachments/balanced_grip.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	_validate_item_data_and_tooltip()
	_validate_weapon_stack_service()
	await _validate_player_weapon_mod_attach()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[weapon_muzzle_attachment] OK data=compact_muzzle weapon_mods=muzzle service=recoil player=attach boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_item_data_and_tooltip() -> void:
	if CompactMuzzle.item_type != "attachment":
		_errors.append("Compact Muzzle-S should remain an attachment item.")
	if not CompactMuzzle.tags.has(&"muzzle") or not CompactMuzzle.tags.has(&"pistol"):
		_errors.append("Compact Muzzle-S should be tagged as a pistol muzzle attachment.")
	if absf(CompactMuzzle.attachment_vertical_recoil_multiplier - 0.9) > 0.001:
		_errors.append("Compact Muzzle-S should reduce vertical recoil to 0.9x.")
	if absf(CompactMuzzle.attachment_horizontal_recoil_multiplier - 0.95) > 0.001:
		_errors.append("Compact Muzzle-S should reduce horizontal recoil to 0.95x.")
	if not Pistol.weapon_attachment_slots.has(&"muzzle"):
		_errors.append("Pistol-S should declare muzzle attachment support before muzzle modifiers can apply.")
	var owner := Control.new()
	root.add_child(owner)
	var tooltip := ItemStackTooltipPresenterScript.build(owner, CompactMuzzle.to_stack(1))
	var text := ItemStackTooltipPresenterScript.tooltip_text(tooltip)
	if not text.contains("0.90x") or not text.contains("0.95x"):
		_errors.append("Compact Muzzle-S tooltip should show its recoil multipliers.")
	_free_node(owner)


func _validate_weapon_stack_service() -> void:
	var weapon_stack := _weapon_stack_with_mod(&"muzzle", CompactMuzzle.to_stack(1))
	var pistol_mods: Dictionary = WeaponAttachmentServiceScript.modifiers_for_weapon_stack(weapon_stack, Pistol)
	if absf(float(pistol_mods.get("vertical_recoil_multiplier", 0.0)) - 0.9) > 0.001:
		_errors.append("WeaponAttachmentService should apply Compact Muzzle-S vertical recoil from weapon_mods.")
	if absf(float(pistol_mods.get("horizontal_recoil_multiplier", 0.0)) - 0.95) > 0.001:
		_errors.append("WeaponAttachmentService should apply Compact Muzzle-S horizontal recoil from weapon_mods.")
	if not (pistol_mods.get("attachment_ids", []) as Array).has("compact_muzzle"):
		_errors.append("WeaponAttachmentService should expose Compact Muzzle-S as an applied attachment id.")

	var knife_mods: Dictionary = WeaponAttachmentServiceScript.modifiers_for_weapon_stack(weapon_stack, Knife)
	if absf(float(knife_mods.get("vertical_recoil_multiplier", 0.0)) - 1.0) > 0.001:
		_errors.append("Combat Knife should not receive muzzle recoil modifiers.")

	var mag_only_weapon := _temporary_pistol_weapon([&"magazine"])
	var mag_only_mods: Dictionary = WeaponAttachmentServiceScript.modifiers_for_weapon_stack(weapon_stack, mag_only_weapon)
	if (mag_only_mods.get("attachment_ids", []) as Array).has("compact_muzzle"):
		_errors.append("A weapon without muzzle support should reject Compact Muzzle-S.")


func _validate_player_weapon_mod_attach() -> void:
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
	backpack_model.add_stack(Pistol.to_stack(1))
	backpack_model.add_stack(CompactMuzzle.to_stack(1))
	player.call("equip_inventory_stack", 0, &"primary_weapon")
	if not bool(player.call("attach_inventory_stack_to_weapon", 0, &"primary_weapon")):
		_errors.append("Player should attach Compact Muzzle-S into Pistol-S weapon_mods.")
	await process_frame
	if not equipment_model.call("get_slot", &"weapon_muzzle").is_empty():
		_errors.append("Player muzzle attach should not leave Compact Muzzle-S in a visible equipment hardpoint slot.")
	var attachment_state: Dictionary = player.call("get_active_weapon_attachment_state")
	if absf(float(attachment_state.get("vertical_recoil_multiplier", 0.0)) - 0.9) > 0.001:
		_errors.append("Player active weapon attachment state should include Compact Muzzle-S vertical recoil.")
	if absf(float(attachment_state.get("horizontal_recoil_multiplier", 0.0)) - 0.95) > 0.001:
		_errors.append("Player active weapon attachment state should include Compact Muzzle-S horizontal recoil.")
	var panel_state: Dictionary = player.call("get_weapon_mod_panel_state", &"primary_weapon")
	if not _panel_has_installed_mod(panel_state, &"muzzle", "compact_muzzle"):
		_errors.append("Weapon mod panel should show Compact Muzzle-S in the muzzle hardpoint.")
	_free_node(scene)


func _validate_source_boundaries() -> void:
	var service_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_attachment_service.gd")
	if not service_source.contains("modifiers_for_weapon_stack") or not service_source.contains("_weapon_supports_attachment_slot"):
		_errors.append("WeaponAttachmentService should keep weapon stack compatibility filtering.")
	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	for required in ["attach_inventory_stack_to_weapon", "modifiers_for_weapon_stack", "get_weapon_mod_panel_state"]:
		if not player_source.contains(required):
			_errors.append("PlayerController3D should route muzzle attachments through weapon-owned mods: %s." % required)
	if player_source.contains("compact_muzzle"):
		_errors.append("PlayerController3D should not hardcode a specific muzzle resource.")
	var localization_source := FileAccess.get_file_as_string("res://data/localization/game_text.csv")
	for required in ["item.compact_muzzle.name", "item.compact_muzzle.desc"]:
		if not localization_source.contains(required):
			_errors.append("Muzzle attachment text should stay centralized in localization: %s." % required)


func _panel_has_installed_mod(panel_state: Dictionary, slot_id: StringName, item_id: String) -> bool:
	for row in panel_state.get("slots", []) as Array:
		var row_dict := row as Dictionary
		if str(row_dict.get("slot_id", "")) != str(slot_id):
			continue
		var stack: Dictionary = row_dict.get("stack", {}) as Dictionary
		return str(stack.get("id", "")) == item_id
	return false


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


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
