extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const WeaponAttachmentServiceScript := preload("res://scripts/combat/weapon_attachment_service.gd")
const ItemStackTooltipPresenterScript := preload("res://scripts/ui/item_stack_tooltip_presenter.gd")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")
const Knife := preload("res://data/items/weapons/combat_knife.tres")
const StabilizingStock := preload("res://data/items/attachments/stabilizing_stock.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	_validate_item_data_and_tooltip()
	_validate_weapon_stack_service()
	await _validate_player_weapon_mod_attach()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[weapon_stock_attachment] OK data=stabilizing_stock weapon_mods=stock service=recoil player=attach boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_item_data_and_tooltip() -> void:
	if StabilizingStock.item_type != "attachment":
		_errors.append("Stabilizing Stock-S should remain an attachment item.")
	if not StabilizingStock.tags.has(&"stock") or not StabilizingStock.tags.has(&"pistol"):
		_errors.append("Stabilizing Stock-S should be tagged as a pistol stock attachment.")
	if absf(StabilizingStock.attachment_vertical_recoil_multiplier - 0.9) > 0.001:
		_errors.append("Stabilizing Stock-S should reduce vertical recoil to 0.9x.")
	if absf(StabilizingStock.attachment_horizontal_recoil_multiplier - 0.9) > 0.001:
		_errors.append("Stabilizing Stock-S should reduce horizontal recoil to 0.9x.")
	if absf(StabilizingStock.attachment_recoil_recovery_multiplier - 1.1) > 0.001:
		_errors.append("Stabilizing Stock-S should improve recoil recovery to 1.1x.")
	if not Pistol.weapon_attachment_slots.has(&"stock"):
		_errors.append("Pistol-S should declare stock attachment support before stock modifiers can apply.")
	var stack := StabilizingStock.to_stack(1)
	if absf(float(stack.get("attachment_recoil_recovery_multiplier", 0.0)) - 1.1) > 0.001:
		_errors.append("Attachment stacks should expose stock recoil recovery multiplier.")
	var owner := Control.new()
	root.add_child(owner)
	var tooltip := ItemStackTooltipPresenterScript.build(owner, stack)
	var text := ItemStackTooltipPresenterScript.tooltip_text(tooltip)
	if not text.contains("0.90x") or not text.contains("1.10x"):
		_errors.append("Stabilizing Stock-S tooltip should show its recoil and recovery multipliers.")
	_free_node(owner)


func _validate_weapon_stack_service() -> void:
	var weapon_stack := _weapon_stack_with_mod(&"stock", StabilizingStock.to_stack(1))
	var pistol_mods: Dictionary = WeaponAttachmentServiceScript.modifiers_for_weapon_stack(weapon_stack, Pistol)
	if absf(float(pistol_mods.get("vertical_recoil_multiplier", 0.0)) - 0.9) > 0.001:
		_errors.append("WeaponAttachmentService should apply Stabilizing Stock-S vertical recoil from weapon_mods.")
	if absf(float(pistol_mods.get("horizontal_recoil_multiplier", 0.0)) - 0.9) > 0.001:
		_errors.append("WeaponAttachmentService should apply Stabilizing Stock-S horizontal recoil from weapon_mods.")
	if absf(float(pistol_mods.get("recoil_recovery_multiplier", 0.0)) - 1.1) > 0.001:
		_errors.append("WeaponAttachmentService should apply Stabilizing Stock-S recoil recovery from weapon_mods.")
	if not (pistol_mods.get("attachment_ids", []) as Array).has("stabilizing_stock"):
		_errors.append("WeaponAttachmentService should expose Stabilizing Stock-S as an applied attachment id.")

	var knife_mods: Dictionary = WeaponAttachmentServiceScript.modifiers_for_weapon_stack(weapon_stack, Knife)
	if absf(float(knife_mods.get("vertical_recoil_multiplier", 0.0)) - 1.0) > 0.001:
		_errors.append("Combat Knife should not receive stock recoil modifiers.")

	var scope_only_weapon := _temporary_pistol_weapon([&"scope"])
	var scope_only_mods: Dictionary = WeaponAttachmentServiceScript.modifiers_for_weapon_stack(weapon_stack, scope_only_weapon)
	if (scope_only_mods.get("attachment_ids", []) as Array).has("stabilizing_stock"):
		_errors.append("A weapon without stock support should reject Stabilizing Stock-S.")


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
	backpack_model.add_stack(StabilizingStock.to_stack(1))
	player.call("equip_inventory_stack", 0, &"primary_weapon")
	if not bool(player.call("attach_inventory_stack_to_weapon", 0, &"primary_weapon")):
		_errors.append("Player should attach Stabilizing Stock-S into Pistol-S weapon_mods.")
	await process_frame
	var legacy_slot: Dictionary = equipment_model.call("get_slot", &"weapon_stock")
	if not legacy_slot.is_empty():
		_errors.append("Player stock attach should not leave Stabilizing Stock-S in a visible equipment hardpoint slot.")
	var attachment_state: Dictionary = player.call("get_active_weapon_attachment_state")
	if absf(float(attachment_state.get("vertical_recoil_multiplier", 0.0)) - 0.9) > 0.001:
		_errors.append("Player active weapon attachment state should include Stabilizing Stock-S vertical recoil.")
	if absf(float(attachment_state.get("horizontal_recoil_multiplier", 0.0)) - 0.9) > 0.001:
		_errors.append("Player active weapon attachment state should include Stabilizing Stock-S horizontal recoil.")
	if absf(float(attachment_state.get("recoil_recovery_multiplier", 0.0)) - 1.1) > 0.001:
		_errors.append("Player active weapon attachment state should include Stabilizing Stock-S recoil recovery.")
	var panel_state: Dictionary = player.call("get_weapon_mod_panel_state", &"primary_weapon")
	if not _panel_has_installed_mod(panel_state, &"stock", "stabilizing_stock"):
		_errors.append("Weapon mod panel should show Stabilizing Stock-S in the stock hardpoint.")
	_free_node(scene)


func _validate_source_boundaries() -> void:
	var service_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_attachment_service.gd")
	for required in ["modifiers_for_weapon_stack", "stock", "_weapon_supports_attachment_slot", "recoil_recovery_multiplier"]:
		if not service_source.contains(required):
			_errors.append("WeaponAttachmentService should keep stock compatibility and recoil math: %s." % required)
	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	for required in ["attach_inventory_stack_to_weapon", "modifiers_for_weapon_stack", "get_weapon_mod_panel_state"]:
		if not player_source.contains(required):
			_errors.append("PlayerController3D should route stock attachments through weapon-owned mods: %s." % required)
	if player_source.contains("stabilizing_stock"):
		_errors.append("PlayerController3D should not hardcode a specific stock resource.")
	var localization_source := FileAccess.get_file_as_string("res://data/localization/game_text.csv")
	for required in ["item.stabilizing_stock.name", "item.stabilizing_stock.desc"]:
		if not localization_source.contains(required):
			_errors.append("Stock attachment text should stay centralized in localization: %s." % required)


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
