extends SceneTree

const Base3DScene := preload("res://scenes/base/base_3d.tscn")
const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const LootContainerScript := preload("res://scripts/loot/loot_container_3d.gd")

const BASE_3D_SCENE := "res://scenes/base/base_3d.tscn"
const BASE_SCREEN_SCENE := "res://scenes/base/base_screen.tscn"
const PISTOL_PATH := "res://data/items/weapons/pistol_9mm.tres"
const AMMO_PATH := "res://data/items/ammo/ammo_9mm.tres"
const STARTER_LOADOUT_PATH := "res://data/inventory/starter_inventory.tres"

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	_validate_normal_flow_sources()
	_validate_test_helper_allowlist()
	await _validate_base_and_raid_are_player_visible()
	await _validate_container_open_does_not_shortcut_to_backpack()
	if _errors.is_empty():
		print("[player_visible_v2_slice] OK shortcuts=removed base=3d raid_loadout=earned container=grid_owned")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_normal_flow_sources() -> void:
	for path in PackedStringArray([
		"res://scripts/ui/difficulty_select_panel.gd",
		"res://scripts/save/save_game_manager.gd",
		"res://scripts/base/base_interaction_controller_3d.gd",
		"res://scripts/ui/raid_result_panel.gd",
	]):
		var source := _read_text(path)
		if source.contains(BASE_SCREEN_SCENE):
			_errors.append("Normal player flow should not route to the old 2D BaseScreen: %s" % path)

	var save_source := _read_text("res://scripts/save/save_game_manager.gd")
	if not save_source.contains("const DEFAULT_BASE_SCENE := \"%s\"" % BASE_3D_SCENE):
		_errors.append("SaveGameManager default base scene should be the 3D Base.")
	var difficulty_source := _read_text("res://scripts/ui/difficulty_select_panel.gd")
	if not difficulty_source.contains("const BASE_SCENE := \"%s\"" % BASE_3D_SCENE):
		_errors.append("New game difficulty flow should enter the 3D Base.")
	var result_source := _read_text("res://scripts/ui/raid_result_panel.gd")
	if not result_source.contains("const BASE_SCENE := \"%s\"" % BASE_3D_SCENE):
		_errors.append("Raid result continue flow should enter the 3D Base.")

	var gameplay_scene := _read_text("res://scenes/gameplay/player_test_world_3d.tscn")
	for forbidden in PackedStringArray([PISTOL_PATH, AMMO_PATH, STARTER_LOADOUT_PATH, "weapon_def ="]):
		if gameplay_scene.contains(forbidden):
			_errors.append("Raid scene should not hardwire loadout shortcut `%s`." % forbidden)

	var player_scene := _read_text("res://scenes/player/player_3d.tscn")
	for forbidden in PackedStringArray([PISTOL_PATH, AMMO_PATH, "weapon_def ="]):
		if player_scene.contains(forbidden):
			_errors.append("Player scene should not hardwire weapon/ammo shortcut `%s`." % forbidden)

	var starter_loadout := _read_text(STARTER_LOADOUT_PATH)
	for forbidden in PackedStringArray([PISTOL_PATH, AMMO_PATH]):
		if starter_loadout.contains(forbidden):
			_errors.append("Starter loadout should not grant No.5 pistol or No.7 ammo: %s" % forbidden)

	var container_source := _read_text("res://scripts/loot/loot_container_3d.gd")
	for forbidden in PackedStringArray(["add_item_resource", "get_inventory_model", "InventoryEquipmentUI"]):
		if container_source.contains(forbidden):
			_errors.append("LootContainer3D should not directly grant loot to the backpack through %s." % forbidden)

	var base_controller := _read_text("res://scripts/base/base_interaction_controller_3d.gd")
	for forbidden in PackedStringArray(["add_item_resource", "equip_inventory_stack(", "reload_equipped_weapon"]):
		if base_controller.contains(forbidden):
			_errors.append("BaseInteractionController3D should not mutate loadout directly through %s." % forbidden)


func _validate_test_helper_allowlist() -> void:
	var allowed_base_screen_helpers := PackedStringArray([
		"res://tools/validate_base_screen.gd",
		"res://tools/validate_base_progression.gd",
		"res://tools/validate_quest_flow.gd",
		"res://tools/validate_three_raid_loop.gd",
		"res://tools/validate_ui_text_quality.gd",
		"res://tools/validate_vendor_sell.gd",
	])
	for path in allowed_base_screen_helpers:
		var source := _read_text(path)
		if not source.contains(BASE_SCREEN_SCENE):
			_errors.append("Allowed BaseScreen test helper should remain explicit or be removed from allowlist: %s" % path)


func _validate_base_and_raid_are_player_visible() -> void:
	var base_scene := Base3DScene.instantiate()
	root.add_child(base_scene)
	current_scene = base_scene
	await process_frame
	await process_frame

	if base_scene.scene_file_path != BASE_3D_SCENE:
		_errors.append("Base scene validation should load the 3D Base path.")
	if base_scene.find_child("BaseInteractionController3D", true, false) == null:
		_errors.append("3D Base should expose visible interaction points instead of a full-screen 2D Base shortcut.")
	if base_scene.find_child("Player3D", true, false) == null:
		_errors.append("3D Base should include a visible player.")
	_free_node(base_scene)

	var gameplay := GameplayScene.instantiate()
	root.add_child(gameplay)
	current_scene = gameplay
	await process_frame
	await process_frame
	var player := gameplay.get_node_or_null("Player3D")
	if player == null:
		_errors.append("Raid scene should include Player3D.")
		_free_node(gameplay)
		return
	var inventory: InventoryModel = player.call("get_inventory_model")
	if _stack_array_has(inventory.get_display_items(), 5):
		_errors.append("Raid player should not spawn with No.5 pistol in backpack.")
	if _stack_array_has(inventory.get_display_items(), 7):
		_errors.append("Raid player should not spawn with No.7 ammo in backpack before looting.")
	var equipment: RefCounted = player.call("get_equipment_model")
	if _equipment_has_catalog(equipment, 5):
		_errors.append("Raid player should not spawn with No.5 pistol equipped without Base/container flow.")
	var weapon := player.get_node_or_null("WeaponController3D")
	if weapon != null and weapon.has_method("has_weapon") and bool(weapon.call("has_weapon")):
		_errors.append("WeaponController3D should start unarmed unless loadout/equipment provides a weapon.")
	_free_node(gameplay)


func _validate_container_open_does_not_shortcut_to_backpack() -> void:
	var gameplay := GameplayScene.instantiate()
	root.add_child(gameplay)
	current_scene = gameplay
	await process_frame
	await process_frame

	var player := gameplay.get_node_or_null("Player3D")
	var container := _first_loot_container(gameplay)
	var container_ui := gameplay.find_child("ContainerInventoryUI", true, false) as Control
	if player == null or container == null or container_ui == null:
		_errors.append("Raid scene should include Player3D, LootContainer3D, and ContainerInventoryUI.")
		_free_node(gameplay)
		return

	var inventory: InventoryModel = player.call("get_inventory_model")
	var backpack_used_before := inventory.get_used_slots()
	if not container.try_open(player):
		_errors.append("Loot container should open through normal player interaction.")
		_free_node(gameplay)
		return
	await process_frame
	await process_frame

	var model: RefCounted = container.call("get_container_inventory_model")
	var slots: Array = model.call("get_slots")
	if not _slots_contain_path(slots, PISTOL_PATH):
		_errors.append("Opened container should keep No.5 pistol in its own visible grid.")
	if not _slots_contain_path(slots, AMMO_PATH):
		_errors.append("Opened container should keep No.7 ammo in its own visible grid.")
	if inventory.get_used_slots() != backpack_used_before:
		_errors.append("Opening a container should not directly move loot into the backpack.")
	if _stack_array_has(inventory.get_display_items(), 5) or _stack_array_has(inventory.get_display_items(), 7):
		_errors.append("Opening a container should not grant No.5/No.7 before the player clicks a slot.")
	var state: Dictionary = container_ui.call("get_display_state")
	if not bool(state.get("visible", false)):
		_errors.append("Container UI should be visible after opening the container.")
	if not str(state.get("capacity", "")).contains("/"):
		_errors.append("Container UI should show used/capacity slot text.")

	_free_node(gameplay)


func _first_loot_container(scene: Node) -> LootContainer3D:
	for node in scene.find_children("*", "Area3D", true, false):
		if node.get_script() == LootContainerScript:
			return node as LootContainer3D
	return null


func _slots_contain_path(slots: Array, item_path: String) -> bool:
	for stack in slots:
		if typeof(stack) == TYPE_DICTIONARY and str((stack as Dictionary).get("resource_path", "")) == item_path:
			return true
	return false


func _stack_array_has(value: Variant, catalog_number: int) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	for stack_value in value as Array:
		if typeof(stack_value) != TYPE_DICTIONARY:
			continue
		var stack := stack_value as Dictionary
		if int(stack.get("catalog_number", 0)) == catalog_number:
			return true
		var item_path := str(stack.get("resource_path", stack.get("item_path", "")))
		var item := load(item_path) as ItemDef if item_path != "" and ResourceLoader.exists(item_path) else null
		if item != null and item.catalog_number == catalog_number:
			return true
	return false


func _equipment_has_catalog(equipment: RefCounted, catalog_number: int) -> bool:
	if equipment == null or not equipment.has_method("get_slot_ids"):
		return false
	var slot_ids: PackedStringArray = equipment.call("get_slot_ids")
	for slot_name in slot_ids:
		var item: Variant = equipment.call("get_equipped_item", StringName(slot_name))
		if item is ItemDef and int(item.catalog_number) == catalog_number:
			return true
	return false


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		_errors.append("Missing expected file for V2 shortcut validation: %s" % path)
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_errors.append("Cannot read file for V2 shortcut validation: %s" % path)
		return ""
	return file.get_as_text()


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
