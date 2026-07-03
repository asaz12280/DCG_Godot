extends SceneTree

const Base3DScene := preload("res://scenes/base/base_3d.tscn")
const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const LootContainerScript := preload("res://scripts/loot/loot_container_3d.gd")
const ProjectileScript := preload("res://scripts/combat/projectile_3d.gd")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")

const BASE_3D_SCENE := "res://scenes/base/base_3d.tscn"
const BASE_SCREEN_SCENE := "res://scenes/base/base_screen.tscn"
const PISTOL_PATH := "res://data/items/weapons/pistol_9mm.tres"
const AMMO_PATH := "res://data/items/ammo/ammo_9mm.tres"
const STARTER_LOADOUT_PATH := "res://data/inventory/starter_inventory.tres"
const VALIDATION_SAVE_ROOT := "user://validation_player_visible_v2_slice"

var _errors: Array[String] = []
var _save_manager: Node = null
var _created_save_manager := false


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	_setup_save_manager()
	_validate_normal_flow_sources()
	_validate_test_helper_allowlist()
	await _validate_full_player_visible_v2_smoke()
	_cleanup_validation_root(VALIDATION_SAVE_ROOT)
	if _created_save_manager:
		_free_node(_save_manager)

	if _errors.is_empty():
		print("[player_visible_v2_slice] OK base=3d container=grid transfer=equip reload=visible projectile=3d extract=base_3d")
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


func _validate_full_player_visible_v2_smoke() -> void:
	var base_scene := Base3DScene.instantiate()
	root.add_child(base_scene)
	current_scene = base_scene
	await _wait_frames(3)

	if base_scene.scene_file_path != BASE_3D_SCENE:
		_errors.append("Smoke should start in the 3D Base scene.")
	var base_player := base_scene.find_child("Player3D", true, false)
	var base_controller := base_scene.find_child("BaseInteractionController3D", true, false)
	if base_player == null:
		_errors.append("3D Base should include a visible player.")
	if base_controller == null:
		_errors.append("3D Base should expose visible interaction points.")
	if base_controller == null or base_player == null:
		_free_current_scene()
		return

	var interaction_ids: PackedStringArray = base_controller.call("get_available_interaction_ids")
	if not interaction_ids.has("raid_gate"):
		_errors.append("3D Base should expose a raid_gate interaction for sortie.")
	if _player_has_catalog(base_player, 5) or _player_has_catalog(base_player, 7):
		_errors.append("3D Base loadout should not already contain No.5/No.7 before looting.")
	if not bool(base_controller.call("prepare_raid_loadout")):
		_errors.append("3D Base should prepare a raid loadout before sortie.")
	if not bool(_save_manager.call("has_pending_raid_loadout")):
		_errors.append("3D Base sortie should set a pending raid loadout.")
	_free_current_scene()

	var gameplay := GameplayScene.instantiate()
	root.add_child(gameplay)
	current_scene = gameplay
	await _wait_frames(4)

	var player := gameplay.get_node_or_null("Player3D")
	var container := _first_loot_container(gameplay)
	var container_ui := gameplay.find_child("ContainerInventoryUI", true, false) as Control
	var raid_hud := gameplay.find_child("RaidHudPanel", true, false) as Control
	var player_hud := gameplay.find_child("PlayerHud3D", true, false) as Control
	var session := gameplay.get_node_or_null("RaidSession")
	var result_panel := gameplay.get_node_or_null("HUD/RaidResultPanel")
	var applier := gameplay.get_node_or_null("RaidResultApplier")
	var weapon := player.get_node_or_null("WeaponController3D") if player != null else null
	if player == null or container == null or container_ui == null or raid_hud == null or player_hud == null or session == null or result_panel == null or applier == null or weapon == null:
		_errors.append("Raid scene should include player, loot container, container UI, minimal player HUD, hidden legacy raid HUD, session, result panel, applier, and weapon controller.")
		_free_current_scene()
		return
	if bool(raid_hud.visible):
		_errors.append("Large top-left RaidHudPanel should be hidden in normal gameplay; tasks belong in top-menu panels.")

	var inventory: InventoryModel = player.call("get_inventory_model")
	var equipment: RefCounted = player.call("get_equipment_model")
	if _stack_array_has(inventory.get_display_items(), 5):
		_errors.append("Raid player should not spawn with No.5 pistol in backpack.")
	if _stack_array_has(inventory.get_display_items(), 7):
		_errors.append("Raid player should not spawn with No.7 ammo in backpack before looting.")
	if _equipment_has_catalog(equipment, 5):
		_errors.append("Raid player should not spawn with No.5 pistol equipped before looting.")
	if bool(weapon.call("has_weapon")):
		_errors.append("Raid weapon controller should stay unarmed before equipment is earned.")

	await _open_container_and_transfer_loot(player, container, container_ui, inventory)
	await _equip_pistol_and_reload(player, inventory, equipment, weapon, player_hud)
	await _fire_visible_projectile(gameplay, weapon)
	await _extract_and_return_to_base(inventory, session, result_panel, applier)
	_free_current_scene()


func _open_container_and_transfer_loot(player: Node, container: LootContainer3D, container_ui: Control, inventory: InventoryModel) -> void:
	var backpack_used_before := inventory.get_used_slots()
	if not container.try_open(player):
		_errors.append("Loot container should open through normal player interaction.")
		return
	await _wait_frames(3)

	var state: Dictionary = container_ui.call("get_display_state")
	if not bool(state.get("visible", false)):
		_errors.append("Container UI should be visible after opening the container.")
	if not str(state.get("capacity", "")).contains("/"):
		_errors.append("Container UI should show used/capacity slot text.")
	if int(state.get("slot_count", 0)) <= 0:
		_errors.append("Container UI should render capacity slots.")

	var model: RefCounted = container.call("get_container_inventory_model")
	var slots: Array = model.call("get_slots")
	if not _slots_contain_path(slots, PISTOL_PATH):
		_errors.append("Opened container should keep No.5 pistol in its own visible grid.")
	if not _slots_contain_path(slots, AMMO_PATH):
		_errors.append("Opened container should keep No.7 ammo in its own visible grid.")
	if inventory.get_used_slots() != backpack_used_before:
		_errors.append("Opening a container should not directly move loot into the backpack.")

	var pistol_slot := _slot_index_with_path(model, PISTOL_PATH)
	var ammo_slot := _slot_index_with_path(model, AMMO_PATH)
	if pistol_slot < 0 or ammo_slot < 0:
		return
	await _press_container_slot(container_ui, pistol_slot)
	await _press_container_slot(container_ui, ammo_slot)

	if not _stack_array_has(inventory.get_display_items(), 5):
		_errors.append("Clicking No.5 in container UI should move the pistol into the backpack.")
	if not _stack_array_has(inventory.get_display_items(), 7):
		_errors.append("Clicking No.7 in container UI should move ammo into the backpack.")
	var after_slots: Array = model.call("get_slots")
	if _slots_contain_path(after_slots, PISTOL_PATH) or _slots_contain_path(after_slots, AMMO_PATH):
		_errors.append("Transferred No.5/No.7 should leave the container grid.")


func _equip_pistol_and_reload(player: Node, inventory: InventoryModel, equipment: RefCounted, weapon: Node, player_hud: Control) -> void:
	var pistol_index := _stack_index_with_catalog(inventory, 5)
	if pistol_index < 0:
		_errors.append("No.5 pistol should be in backpack before equipment.")
		return
	if not bool(player.call("equip_inventory_stack", pistol_index)):
		_errors.append("Player should be able to equip No.5 pistol from backpack.")
	await _wait_frames(2)

	if not _equipment_has_catalog(equipment, 5):
		_errors.append("No.5 pistol should be visible in EquipmentModel after equip.")
	var primary_weapon: Dictionary = equipment.call("get_slot", &"primary_weapon")
	if int(primary_weapon.get("catalog_number", 0)) != 5:
		_errors.append("No.5 pistol should equip into the visible primary weapon slot.")
	if _stack_array_has(inventory.get_display_items(), 5):
		_errors.append("Equipped No.5 pistol should leave the backpack stack list.")
	if not bool(weapon.call("has_weapon")):
		_errors.append("WeaponController3D should bind to the equipped No.5 pistol.")

	var ammo_before := _quantity_by_path(inventory.get_display_items(), AMMO_PATH)
	if ammo_before <= 0:
		_errors.append("No.7 ammo should be in backpack before reload.")
		return
	if not bool(player.call("reload_equipped_weapon", &"validation_manual")):
		_errors.append("Pressing R/reload should start a reload when No.5 and No.7 are available.")
		return
	await _wait_frames(2)

	var reload_state: Dictionary = player.call("get_reload_state")
	if not bool(reload_state.get("active", false)):
		_errors.append("Reload state should be active while the visible reload bar is filling.")
	var hud_state: Dictionary = player_hud.call("get_display_state")
	if not bool(hud_state.get("reload_visible", false)):
		_errors.append("Minimal player HUD should show a visible reload progress bar.")
	if float(hud_state.get("reload_progress", 0.0)) < 0.0:
		_errors.append("Minimal player HUD reload progress should report a valid progress value.")

	for _index in range(70):
		await physics_frame
		if not bool((player.call("get_reload_state") as Dictionary).get("active", false)):
			break
	await _wait_frames(2)

	var result: Dictionary = player.call("get_last_reload_result")
	if not bool(result.get("reloaded", false)):
		_errors.append("Reload should complete and move No.7 ammo into the No.5 magazine.")
	if int(weapon.get("current_ammo")) <= 0:
		_errors.append("Weapon should have loaded rounds after reload completes.")
	var ammo_after := _quantity_by_path(inventory.get_display_items(), AMMO_PATH)
	if ammo_after >= ammo_before:
		_errors.append("No.7 ammo stack should decrease after reload.")


func _fire_visible_projectile(gameplay: Node, weapon: Node) -> void:
	if weapon.has_method("force_cooldown_ready"):
		weapon.call("force_cooldown_ready")
	var ammo_before := int(weapon.get("current_ammo"))
	var projectiles_before := _count_projectiles(gameplay)
	var origin := (weapon as Node3D).global_position + Vector3.UP * 0.72
	var did_fire := bool(weapon.call("fire_forward", origin, Vector3.FORWARD, gameplay.get_world_3d().direct_space_state))
	var projectiles_after := _count_projectiles(gameplay)
	if not did_fire:
		_errors.append("Firing after reload should succeed.")
	if projectiles_after <= projectiles_before:
		_errors.append("Firing should spawn a visible 3D projectile node.")
	if int(weapon.get("current_ammo")) >= ammo_before:
		_errors.append("Firing should consume one loaded round.")


func _extract_and_return_to_base(inventory: InventoryModel, session: Node, result_panel: Node, applier: Node) -> void:
	var extracted_items := inventory.get_display_items()
	if _quantity_by_path(extracted_items, AMMO_PATH) <= 0:
		_errors.append("Backpack should still contain remaining No.7 ammo to extract.")
	if not bool(session.call("register_extraction", {
		"extracted_items": extracted_items,
		"money_delta": 0,
	})):
		_errors.append("Raid session should allow extraction after the smoke flow.")
		return
	await _wait_frames(3)

	if not bool(result_panel.get("visible")):
		_errors.append("Raid result panel should be visible after extraction.")
	var apply_result: Dictionary = applier.get("last_apply_result")
	if not bool(apply_result.get("applied", false)):
		_errors.append("RaidResultApplier should persist extracted loot.")
	var save_data: Dictionary = _save_manager.call("get_slot_data", 1)
	if _stash_quantity(save_data, AMMO_PATH) <= 0:
		_errors.append("Extracted remaining No.7 ammo should be saved into the base stash.")

	result_panel.continue_button.pressed.emit()
	await _wait_frames(8)

	if current_scene == null:
		_errors.append("Continue from raid result should leave a loaded current scene.")
	elif current_scene.scene_file_path != BASE_3D_SCENE:
		_errors.append("Continue from raid result should return to 3D Base, got `%s`." % current_scene.scene_file_path)
	elif current_scene.name != "Base3D":
		_errors.append("Returned scene should be the Base3D root.")


func _setup_save_manager() -> void:
	_save_manager = root.get_node_or_null("SaveGameManager")
	if _save_manager == null:
		_save_manager = SaveGameManagerScript.new()
		_save_manager.name = "SaveGameManager"
		root.add_child(_save_manager)
		_created_save_manager = true
	_save_manager.save_root_path = VALIDATION_SAVE_ROOT
	_cleanup_validation_root(VALIDATION_SAVE_ROOT)
	_save_manager.call("set_current_slot_index", 1)
	_save_manager.call("save_slot_data", 1, {
		"difficulty_id": "normal",
		"scene_path": BASE_3D_SCENE,
		"money": 0,
		"stash": [],
		"base_upgrades": {},
		"quests": {},
	})


func _press_container_slot(container_ui: Control, slot_index: int) -> void:
	var button := container_ui.find_child("ContainerSlot%d" % slot_index, true, false) as Button
	if button == null:
		_errors.append("Container UI should expose a clickable slot button for index %d." % slot_index)
		return
	button.pressed.emit()
	await _wait_frames(2)


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


func _slot_index_with_path(model: RefCounted, item_path: String) -> int:
	if model == null or not model.has_method("get_slots"):
		return -1
	var slots: Array = model.call("get_slots")
	for index in range(slots.size()):
		var stack: Variant = slots[index]
		if typeof(stack) == TYPE_DICTIONARY and str((stack as Dictionary).get("resource_path", "")) == item_path:
			return index
	return -1


func _stack_index_with_catalog(inventory: InventoryModel, catalog_number: int) -> int:
	if inventory == null:
		return -1
	var stacks := inventory.get_display_items()
	for index in range(stacks.size()):
		var stack := stacks[index]
		if int(stack.get("catalog_number", 0)) == catalog_number:
			return index
	return -1


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
	var slot_ids: Array[StringName] = equipment.call("get_slot_ids")
	for slot_name in slot_ids:
		var item: Variant = equipment.call("get_equipped_item", StringName(slot_name))
		if item is ItemDef and int(item.catalog_number) == catalog_number:
			return true
	return false


func _player_has_catalog(player: Node, catalog_number: int) -> bool:
	if player == null or not player.has_method("get_inventory_model") or not player.has_method("get_equipment_model"):
		return false
	var inventory: InventoryModel = player.call("get_inventory_model")
	var equipment: RefCounted = player.call("get_equipment_model")
	return _stack_array_has(inventory.get_display_items(), catalog_number) or _equipment_has_catalog(equipment, catalog_number)


func _quantity_by_path(value: Variant, item_path: String) -> int:
	if typeof(value) != TYPE_ARRAY:
		return 0
	var total := 0
	for stack_value in value as Array:
		if typeof(stack_value) != TYPE_DICTIONARY:
			continue
		var stack := stack_value as Dictionary
		if str(stack.get("resource_path", stack.get("item_path", ""))) == item_path:
			total += int(stack.get("quantity", 0))
	return total


func _stash_quantity(save_data: Dictionary, item_path: String) -> int:
	var total := 0
	var stash: Array = save_data.get("stash", []) as Array
	for entry in stash:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var stack := entry as Dictionary
		if str(stack.get("item_path", stack.get("resource_path", ""))) == item_path:
			total += int(stack.get("quantity", 0))
	return total


func _count_projectiles(scene: Node) -> int:
	var count := 0
	for node in scene.find_children("*", "Area3D", true, false):
		if node.get_script() == ProjectileScript:
			count += 1
	return count


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		_errors.append("Missing expected file for V2 shortcut validation: %s" % path)
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_errors.append("Cannot read file for V2 shortcut validation: %s" % path)
		return ""
	return file.get_as_text()


func _cleanup_validation_root(root_path: String) -> void:
	var absolute := ProjectSettings.globalize_path(root_path)
	if DirAccess.dir_exists_absolute(absolute):
		DirAccess.remove_absolute("%s/slot_1.json" % absolute)
		DirAccess.remove_absolute("%s/slot_2.json" % absolute)
		DirAccess.remove_absolute("%s/slot_3.json" % absolute)
		DirAccess.remove_absolute(absolute)


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _free_current_scene() -> void:
	if current_scene != null:
		_free_node(current_scene)
		current_scene = null


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
