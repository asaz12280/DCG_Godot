extends SceneTree

const EquipmentModelScript := preload("res://scripts/equipment/equipment_model.gd")
const WeaponAttachmentServiceScript := preload("res://scripts/combat/weapon_attachment_service.gd")
const InventoryEquipmentUIScript := preload("res://scripts/ui/inventory_equipment_ui.gd")
const BaseStashInventoryUIScript := preload("res://scripts/ui/base_stash_inventory_ui.gd")
const ContainerInventoryScene := preload("res://scenes/ui/container_inventory_ui.tscn")
const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")
const ExtendedMagazine := preload("res://data/items/attachments/extended_magazine.tres")
const BalancedGrip := preload("res://data/items/attachments/balanced_grip.tres")

const WRONG_EQUIPMENT_SLOTS := [
	"weapon_mag",
	"weapon_grip",
	"weapon_muzzle",
	"weapon_scope",
	"weapon_stock",
	"weapon_tactic",
]

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_weapon_mods_live_on_weapon_stack()
	_validate_legacy_equipment_mods_migrate_into_weapon()
	_validate_inventory_surfaces_hide_weapon_mod_slots()
	await _validate_player_weapon_mod_bridge()
	await _validate_container_sort_button_removed()
	if _errors.is_empty():
		print("[user_corrected_inventory_direction] OK weapon_mods=on_weapon equipment_ui=clean stash_left=clean container_sort=hidden")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_weapon_mods_live_on_weapon_stack() -> void:
	var model := EquipmentModelScript.new()
	if not model.equip_item(&"primary_weapon", Pistol):
		_errors.append("Pistol-S should equip before weapon mods can be attached.")
	if not model.attach_weapon_mod(&"primary_weapon", ExtendedMagazine.to_stack(1)):
		_errors.append("Extended Magazine-S should attach into Pistol-S weapon_mods.")
	var weapon_stack := model.get_slot(&"primary_weapon")
	var mods: Dictionary = weapon_stack.get("weapon_mods", {}) as Dictionary
	if (mods.get("magazine", {}) as Dictionary).is_empty():
		_errors.append("Pistol-S should store magazine mods inside weapon_mods.magazine.")
	if not model.is_empty(&"weapon_mag"):
		_errors.append("Legacy weapon_mag equipment slot should stay empty after weapon-mounted attach.")
	var attachment_state: Dictionary = WeaponAttachmentServiceScript.modifiers_for_weapon_stack(weapon_stack, Pistol)
	if int(attachment_state.get("magazine_capacity_bonus", 0)) <= 0:
		_errors.append("WeaponAttachmentService should read magazine capacity from weapon stack mods.")
	var saved: Dictionary = model.to_save_data()
	var loaded := EquipmentModelScript.new()
	if not loaded.load_save_data(saved):
		_errors.append("Weapon mods should survive equipment save/load.")
	var loaded_mods: Dictionary = loaded.get_slot(&"primary_weapon").get("weapon_mods", {}) as Dictionary
	if (loaded_mods.get("magazine", {}) as Dictionary).is_empty():
		_errors.append("Saved Pistol-S should reload with weapon_mods.magazine intact.")


func _validate_legacy_equipment_mods_migrate_into_weapon() -> void:
	var model := EquipmentModelScript.new()
	if not model.equip_item(&"primary_weapon", Pistol):
		_errors.append("Legacy migration validation should equip Pistol-S.")
	if not model.equip_item(&"weapon_grip", BalancedGrip):
		_errors.append("Legacy weapon_grip entry should still be accepted as migration input.")
	if not model.is_empty(&"weapon_grip"):
		_errors.append("Legacy weapon_grip should be emptied after migration into Pistol-S.")
	var mods: Dictionary = model.get_slot(&"primary_weapon").get("weapon_mods", {}) as Dictionary
	if (mods.get("grip", {}) as Dictionary).is_empty():
		_errors.append("Legacy weapon_grip should migrate into Pistol-S weapon_mods.grip.")


func _validate_inventory_surfaces_hide_weapon_mod_slots() -> void:
	var inventory_ui := InventoryEquipmentUIScript.new()
	for slot_id in WRONG_EQUIPMENT_SLOTS:
		if inventory_ui.equipment_slot_ids.has(StringName(slot_id)):
			_errors.append("Inventory equipment UI should not expose weapon mod slot %s." % slot_id)
	var stash_ui := BaseStashInventoryUIScript.new()
	for slot_id in WRONG_EQUIPMENT_SLOTS:
		if stash_ui.equipment_slot_ids.has(StringName(slot_id)):
			_errors.append("Base stash left equipment surface should not expose weapon mod slot %s." % slot_id)
	var stash_layout_state: Dictionary = stash_ui.call("get_display_state_for_viewport", Vector2(1920.0, 1080.0))
	if str(stash_layout_state.get("left_panel_role", "")) != "tab_inventory_reference":
		_errors.append("Base stash UI should reference the normal Tab inventory on the left, not a separate backpack-transfer page.")
	if bool(stash_layout_state.get("draws_left_transfer_panel", true)):
		_errors.append("Base stash UI should not draw the obsolete middle backpack-transfer panel.")
	if bool(stash_layout_state.get("dims_inventory_surface", true)):
		_errors.append("Base stash UI should not dim the normal Tab backpack/equipment panel.")
	for hidden_flag in [
		"store_all_button_visible",
		"sort_button_visible",
		"storage_upgrade_button_visible",
		"stash_hint_visible",
		"stash_status_visible",
	]:
		if bool(stash_layout_state.get(hidden_flag, true)):
			_errors.append("Base stash UI should hide marked warehouse control/hint UI flag: %s." % hidden_flag)
	var left_rect: Rect2 = stash_layout_state.get("left_panel_rect", Rect2())
	var right_rect: Rect2 = stash_layout_state.get("right_panel_rect", Rect2())
	if right_rect.position.x < left_rect.end.x + 120.0:
		_errors.append("Base stash warehouse panel should be laid out on the right side like the corrected reference.")
	var source := FileAccess.get_file_as_string("res://scripts/ui/base_stash_inventory_ui.gd")
	for forbidden_draw in [
		"_draw_inventory_reference_actions",
		"_draw_button(_store_all_button_rect",
		"_draw_button(_storage_upgrade_button_rect",
		"_draw_button(_sort_button_rect",
		'_painter.text(_localized_text(&"ui.stash.store_hint"',
		"_painter.text(_status_text()",
	]:
		if source.contains(forbidden_draw):
			_errors.append("Base stash UI should not draw marked warehouse control/hint UI: %s." % forbidden_draw)
	inventory_ui.free()
	stash_ui.free()


func _validate_player_weapon_mod_bridge() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var player := scene.get_node_or_null("Player3D")
	if player == null:
		_errors.append("Gameplay scene should include Player3D for weapon mod bridge validation.")
		_free_node(scene)
		await process_frame
		return
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	backpack_model.clear()
	backpack_model.setup(50)
	backpack_model.add_stack(Pistol.to_stack(1))
	backpack_model.add_stack(ExtendedMagazine.to_stack(1))
	if not bool(player.call("equip_inventory_stack", 0, &"primary_weapon")):
		_errors.append("Player should equip Pistol-S before attaching weapon mods.")
	if not bool(player.call("attach_inventory_stack_to_weapon", 0, &"primary_weapon")):
		_errors.append("Player should attach Extended Magazine-S into Pistol-S weapon_mods.")
	var attachment_state: Dictionary = player.call("get_active_weapon_attachment_state")
	if int(attachment_state.get("magazine_capacity_bonus", 0)) <= 0:
		_errors.append("Player active weapon attachment state should read Pistol-S weapon_mods.")
	var panel_state: Dictionary = player.call("get_weapon_mod_panel_state", &"primary_weapon")
	var has_mag_slot := false
	for row in panel_state.get("slots", []) as Array:
		var row_dict := row as Dictionary
		if str(row_dict.get("slot_id", "")) == "magazine" and not (row_dict.get("stack", {}) as Dictionary).is_empty():
			has_mag_slot = true
	if not has_mag_slot:
		_errors.append("Weapon mod panel state should expose installed magazine on Pistol-S.")
	_free_node(scene)
	await process_frame


func _validate_container_sort_button_removed() -> void:
	var ui := ContainerInventoryScene.instantiate()
	root.add_child(ui)
	await process_frame
	var state: Dictionary = ui.call("get_display_state")
	if bool(state.get("sort_visible", true)):
		_errors.append("Raid/container loot UI should not show the warehouse-style sort/value button.")
	var source := FileAccess.get_file_as_string("res://scripts/ui/container_inventory_ui.gd")
	for forbidden in ["ItemStackSorter", "organize_container", "_sort_button_text", "_consume_sort_mode"]:
		if source.contains(forbidden):
			_errors.append("Raid/container loot UI should not keep warehouse-style sorting code: %s." % forbidden)
	_free_node(ui)
	await process_frame


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
