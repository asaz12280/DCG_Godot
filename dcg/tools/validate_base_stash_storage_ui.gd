extends SceneTree

const Base3DScene := preload("res://scenes/base/base_3d.tscn")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")
const QuestStateScript := preload("res://scripts/quests/quest_state.gd")
const FirstSalvageQuest := preload("res://data/quests/first_salvage.tres")
const StorageExpansionUpgrade1 := preload("res://data/base_upgrades/storage_expansion_level_1.tres")
const StorageExpansionUpgrade2 := preload("res://data/base_upgrades/storage_expansion_level_2.tres")
const WoodItem := preload("res://data/items/crafting/wood.tres")
const JunkItem := preload("res://data/items/loot/junk.tres")
const AmmoItem := preload("res://data/items/ammo/ammo_9mm.tres")
const PistolItem := preload("res://data/items/weapons/pistol_9mm.tres")

const VALIDATION_SAVE_ROOT := "user://validation_base_stash_storage_ui"
const WOOD_PATH := "res://data/items/crafting/wood.tres"
const JUNK_PATH := "res://data/items/loot/junk.tres"
const AMMO_PATH := "res://data/items/ammo/ammo_9mm.tres"
const PISTOL_PATH := "res://data/items/weapons/pistol_9mm.tres"
const WIRE_PATH := "res://data/items/electronics/wire.tres"
const WORKBENCH_UPGRADE_ID := "workbench_level_1"

var _errors: Array[String] = []
var _save_manager: Node = null
var _created_save_manager := false


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	_setup_save_manager()
	var scene := Base3DScene.instantiate()
	root.add_child(scene)
	current_scene = scene
	await _wait_frames(3)
	_force_validation_locale()
	await _validate_stash_open_state(scene)
	await _validate_storage_capacity_upgrade(scene)
	await _validate_recipe_needed_marks(scene)
	await _validate_storage_transfers(scene)
	_free_node(scene)
	_cleanup_validation_root(VALIDATION_SAVE_ROOT)
	if _created_save_manager:
		_free_node(_save_manager)
	if _errors.is_empty():
		print("[base_stash_storage_ui] OK open=warehouse_grid capacity=purchase lock=L all_store=locked_safe store=backpack/equipment/safe_pocket withdraw=backpack save=persist")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_stash_open_state(scene: Node) -> void:
	var controller := scene.get_node_or_null("BaseInteractionController3D")
	var stash_panel := scene.get_node_or_null("HUD/BaseStashInventoryUI")
	var inventory_panel := scene.get_node_or_null("HUD/InventoryEquipmentUI")
	var top_menu := scene.get_node_or_null("HUD/TopMenuBar")
	var ui_manager := root.get_node_or_null("UIManager")
	var generic_panel := scene.get_node_or_null("HUD/BaseInteractionPanel")
	if controller == null or stash_panel == null:
		_errors.append("Base scene should expose controller and BaseStashInventoryUI.")
		return
	if not bool(controller.call("open_interaction_by_id", "stash")):
		_errors.append("Stash station should open through BaseInteractionController3D.")
		return
	await _wait_frames(2)
	var state: Dictionary = stash_panel.call("get_display_state")
	if not bool(state.get("visible", false)) or not bool(state.get("is_open", false)):
		_errors.append("Stash station should show an open storage UI.")
	if ui_manager == null or str(ui_manager.call("get_active_ui")) != "stash":
		_errors.append("E-opened stash should be owned by UIManager active_ui=stash.")
	if top_menu == null or not bool(top_menu.get("visible")):
		_errors.append("E-opened stash should keep the top function bar visible.")
	elif top_menu.has_method("get_selected_item_id") and str(top_menu.call("get_selected_item_id")) != "backpack":
		_errors.append("Stash should show the top function bar with the backpack tab selected.")
	if inventory_panel == null or not bool(inventory_panel.get("visible")):
		_errors.append("Stash should keep the normal Tab inventory surface open beside the warehouse.")
	elif inventory_panel.has_method("get_display_state"):
		var inventory_state: Dictionary = inventory_panel.call("get_display_state")
		if not bool(inventory_state.get("store_all_button_visible", false)):
			_errors.append("Stash should enable the All Store action on the normal backpack panel only while the warehouse page is open.")
		if str(inventory_state.get("store_all_button_text", "")) != str(TranslationServer.translate("ui.stash.store_all")):
			_errors.append("Stash-open backpack All Store action should use the localized warehouse label.")
		var store_all_rect: Rect2 = inventory_state.get("store_all_button_rect", Rect2())
		if store_all_rect.size.x <= 0.0 or store_all_rect.size.y <= 0.0:
			_errors.append("Stash-open backpack All Store action should expose a clickable rect.")
	if int(state.get("stash_capacity", 0)) != 250:
		_errors.append("Stash UI should expose the 250-slot warehouse capacity.")
	if str(state.get("left_panel_role", "")) != "tab_inventory_reference":
		_errors.append("Stash UI left side should reuse the normal Tab inventory surface instead of drawing a separate transfer panel.")
	if str(state.get("right_panel_role", "")) != "warehouse":
		_errors.append("Stash UI right panel should be the warehouse surface.")
	if not bool(state.get("uses_tab_inventory_surface", false)):
		_errors.append("Stash UI should explicitly use the normal Tab inventory surface for the left-side backpack/equipment view.")
	if bool(state.get("draws_left_transfer_panel", true)):
		_errors.append("Stash UI should not draw the extra middle backpack transfer panel.")
	if bool(state.get("dims_inventory_surface", true)):
		_errors.append("Stash UI should not dim the normal backpack/equipment panel.")
	if not bool(state.get("equipment_surface_visible", false)):
		_errors.append("Stash UI should keep the normal equipment/backpack UI visible on the left side.")
	if bool(state.get("store_all_button_visible", true)):
		_errors.append("Stash UI should not show the left-side All Store button on this warehouse page.")
	if bool(state.get("sort_button_visible", true)):
		_errors.append("Stash UI should not show the warehouse sort/value button.")
	if bool(state.get("storage_upgrade_button_visible", true)):
		_errors.append("Stash UI should not show the storage expansion button on this page.")
	if bool(state.get("stash_hint_visible", true)) or bool(state.get("stash_status_visible", true)):
		_errors.append("Stash UI should not show the marked hint/status text block above the warehouse grid.")
	var left_panel_rect: Rect2 = state.get("left_panel_rect", Rect2())
	var right_panel_rect: Rect2 = state.get("right_panel_rect", Rect2())
	var backpack_grid_rect: Rect2 = state.get("backpack_grid_rect", Rect2())
	var stash_grid_rect: Rect2 = state.get("stash_grid_rect", Rect2())
	if backpack_grid_rect.position.x >= stash_grid_rect.position.x:
		_errors.append("Normal backpack grid should remain on the left of the warehouse grid.")
	if right_panel_rect.position.x < left_panel_rect.end.x + 120.0:
		_errors.append("Warehouse panel should be anchored on the right side, leaving the center play view readable.")
	if right_panel_rect.size.x + 0.5 < left_panel_rect.size.x or right_panel_rect.size.y + 0.5 < left_panel_rect.size.y:
		_errors.append("Warehouse panel should be at least as large as the normal backpack/equipment panel.")
	if absf(right_panel_rect.position.y - left_panel_rect.position.y) > 1.0:
		_errors.append("Warehouse panel should align vertically with the normal backpack/equipment panel.")
	if stash_grid_rect.position.y > right_panel_rect.position.y + 120.0:
		_errors.append("Warehouse grid should move up after removing the hint/status UI block.")
	if not str(state.get("title", "")).contains(TranslationServer.translate("ui.base.station.stash")):
		_errors.append("Stash UI title should be localized.")
	var quest_needed_paths: Array = state.get("quest_needed_item_paths", []) as Array
	if not quest_needed_paths.has(WOOD_PATH) or not quest_needed_paths.has(WIRE_PATH):
		_errors.append("Active item quests should automatically mark their missing objective items as needed.")
	var workbench_needed_paths: Array = state.get("workbench_needed_item_paths", []) as Array
	if not workbench_needed_paths.has(WOOD_PATH) or not workbench_needed_paths.has(WIRE_PATH):
		_errors.append("Unpurchased workbench upgrade should automatically mark its missing materials as needed.")
	var automatic_needed_paths: Array = state.get("automatic_needed_item_paths", []) as Array
	if not automatic_needed_paths.has(WOOD_PATH) or not automatic_needed_paths.has(WIRE_PATH):
		_errors.append("Quest and workbench needed items should be included in the combined automatic needed item paths.")
	var wood_tooltip: Dictionary = stash_panel.call("get_item_tooltip_by_path", WOOD_PATH)
	var wood_tooltip_text := _tooltip_text(wood_tooltip)
	if not wood_tooltip_text.contains(TranslationServer.translate("item.wood.name")):
		_errors.append("Stash item tooltip should show the localized item name.")
	if not wood_tooltip_text.contains(TranslationServer.translate("ui.item.needed_source.quest")):
		_errors.append("Stash item tooltip should explain quest needed-item sources.")
	if not wood_tooltip_text.contains(TranslationServer.translate("ui.item.needed_source.workbench")):
		_errors.append("Stash item tooltip should explain workbench needed-item sources.")
	if not wood_tooltip_text.contains("kg"):
		_errors.append("Stash item tooltip should expose weight information.")
	if generic_panel != null and generic_panel.has_method("is_open") and bool(generic_panel.call("is_open")):
		_errors.append("Stash station should not show the generic station info panel.")
	if ui_manager != null:
		_press_key_on_ui_manager(ui_manager, KEY_TAB)
		await _wait_frames(2)
		if bool(stash_panel.call("is_open")):
			_errors.append("TAB should close the warehouse page when stash is open.")
		if inventory_panel != null and bool(inventory_panel.get("visible")):
			_errors.append("TAB should also close the left backpack/equipment surface when stash is open.")
		if inventory_panel != null and inventory_panel.has_method("get_display_state"):
			var closed_inventory_state: Dictionary = inventory_panel.call("get_display_state")
			if bool(closed_inventory_state.get("store_all_button_visible", false)):
				_errors.append("Closing the warehouse should hide the backpack All Store action.")
		if top_menu != null and bool(top_menu.get("visible")):
			_errors.append("TAB should hide the top function bar after closing the stash page.")
		if str(ui_manager.call("get_active_ui")) != "":
			_errors.append("TAB should clear UIManager active UI after closing stash.")
		if not bool(controller.call("open_interaction_by_id", "stash")):
			_errors.append("Stash station should reopen after TAB close validation.")
			return
		await _wait_frames(2)
		state = stash_panel.call("get_display_state")
	var stash_source := FileAccess.get_file_as_string("res://scripts/ui/base_stash_inventory_ui.gd")
	if stash_source.contains("_draw_left_panel(left_rect)"):
		_errors.append("BaseStashInventoryUI should not draw the obsolete middle backpack transfer panel.")
	if stash_source.contains("draw_rect(Rect2(Vector2.ZERO, viewport_size)"):
		_errors.append("BaseStashInventoryUI should not draw a full-screen dark overlay over the backpack panel.")
	for forbidden_draw in [
		"_draw_inventory_reference_actions",
		"_draw_button(_store_all_button_rect",
		"_draw_button(_storage_upgrade_button_rect",
		"_draw_button(_sort_button_rect",
		'_painter.text(_localized_text(&"ui.stash.store_hint"',
		"_painter.text(_status_text()",
		'_painter.text(str(_storage_upgrade_state.get("summary_text"',
	]:
		if stash_source.contains(forbidden_draw):
			_errors.append("BaseStashInventoryUI should not draw the marked warehouse control/hint UI: %s." % forbidden_draw)
	if stash_source.contains("_draw_equipment_grid(rect)"):
		_errors.append("BaseStashInventoryUI should not draw a duplicated equipment grid on the warehouse screen.")
	for forbidden_style_token in [
		"Color(0.04, 0.11, 0.19, 0.94)",
		"Color(0.18, 0.74, 0.37, 0.95)",
		"Color(0.07, 0.17, 0.27, 0.92)",
		"Color(0.54, 0.65, 0.72, 0.78)",
		"Color(0.32, 0.42, 0.50, 0.92)",
	]:
		if stash_source.contains(forbidden_style_token):
			_errors.append("Warehouse panel should not use the old deep-blue standalone window color token: %s." % forbidden_style_token)
	for required_style_token in [
		"STASH_PANEL_FILL",
		"STASH_SLOT_FILL",
		"STASH_BUTTON_FILL",
	]:
		if not stash_source.contains(required_style_token):
			_errors.append("Warehouse panel should share the normal backpack visual palette through %s." % required_style_token)
	for required_state_flag in [
		'"left_panel_role": "tab_inventory_reference"',
		'"draws_left_transfer_panel": false',
		'"dims_inventory_surface": false',
		'"store_all_button_visible": false',
		'"sort_button_visible": false',
		'"storage_upgrade_button_visible": false',
		'"stash_hint_visible": false',
		'"stash_status_visible": false',
		'"uses_tab_inventory_surface": true',
	]:
		if not stash_source.contains(required_state_flag):
			_errors.append("BaseStashInventoryUI display state should expose hidden marked UI flag: %s." % required_state_flag)
	if not stash_source.contains('"left_panel_role": "tab_inventory_reference"') or not stash_source.contains('"draws_left_transfer_panel": false') or not stash_source.contains('"dims_inventory_surface": false') or not stash_source.contains('"uses_tab_inventory_surface": true'):
		_errors.append("BaseStashInventoryUI display state should expose the corrected warehouse/Tab-inventory panel roles.")
	if not stash_source.contains("InventoryLayoutScript"):
		_errors.append("BaseStashInventoryUI should reuse the normal InventoryEquipmentLayout for its left-side reference rects.")
	if not stash_source.contains("InventoryGridMetricsScript"):
		_errors.append("BaseStashInventoryUI should reuse shared inventory grid metrics instead of owning duplicate grid math.")
	if not stash_source.contains("_painter.lock_badge") or not stash_source.contains("_painter.needed_badge"):
		_errors.append("BaseStashInventoryUI should delegate lock/needed cell badges to the shared inventory painter.")
	var painter_source := FileAccess.get_file_as_string("res://scripts/ui/inventory_equipment_painter.gd")
	for required in ["func lock_badge", "func needed_badge", "func badge"]:
		if not painter_source.contains(required):
			_errors.append("InventoryEquipmentPainter should own shared stack-cell badge drawing: %s." % required)
	stash_panel.call("close_stash")


func _validate_storage_capacity_upgrade(scene: Node) -> void:
	var controller := scene.get_node_or_null("BaseInteractionController3D")
	var stash_panel := scene.get_node_or_null("HUD/BaseStashInventoryUI")
	if controller == null or stash_panel == null:
		return
	var save_data: Dictionary = _save_manager.call("get_slot_data", 1)
	save_data["money"] = 80
	save_data["base_upgrades"] = {}
	if not bool(_save_manager.call("save_slot_data", 1, save_data)):
		_errors.append("Validation setup should save money for the storage expansion purchase.")
		return
	if not bool(controller.call("open_interaction_by_id", "stash")):
		_errors.append("Stash station should reopen for storage capacity validation.")
		return
	await _wait_frames(2)
	var before_state: Dictionary = stash_panel.call("get_display_state")
	if int(before_state.get("stash_capacity", 0)) != 250:
		_errors.append("Stash UI should show base capacity before buying storage expansion.")
	var upgrade_state: Dictionary = before_state.get("storage_upgrade_state", {}) as Dictionary
	if not bool(upgrade_state.get("can_upgrade", false)):
		_errors.append("Stash UI should expose an enabled Storage Expansion purchase action when money is available.")
	if str(upgrade_state.get("summary_text", "")) == "":
		_errors.append("Stash UI should describe the Storage Expansion effect and cost.")
	var purchase_result: Dictionary = stash_panel.call("purchase_storage_expansion")
	if not bool(purchase_result.get("success", false)):
		_errors.append("Stash UI should purchase Storage Expansion Lv.1 through the storage service.")
	var state: Dictionary = stash_panel.call("get_display_state")
	if int(state.get("base_stash_capacity", 0)) != 250:
		_errors.append("Stash UI should keep a stable base warehouse capacity.")
	if int(state.get("stash_capacity_bonus", 0)) != int(StorageExpansionUpgrade1.storage_capacity_bonus):
		_errors.append("Stash UI should expose save-backed storage capacity bonus.")
	if int(state.get("stash_capacity", 0)) != 250 + int(StorageExpansionUpgrade1.storage_capacity_bonus):
		_errors.append("Stash UI capacity should include purchased storage expansion.")
	var after_upgrade_state: Dictionary = state.get("storage_upgrade_state", {}) as Dictionary
	if str(after_upgrade_state.get("upgrade_id", "")) != str(StorageExpansionUpgrade2.id):
		_errors.append("Stash UI should advance to Storage Expansion Lv.2 after buying Lv.1.")
	if not bool(after_upgrade_state.get("can_upgrade", false)):
		_errors.append("Stash UI should enable Storage Expansion Lv.2 when money is available.")
	var storage_upgrade_needed_paths: Array = state.get("storage_upgrade_needed_item_paths", []) as Array
	if not storage_upgrade_needed_paths.is_empty():
		_errors.append("Storage Expansion Lv.2 should not report item-needed marks.")
	var saved_after_purchase: Dictionary = _save_manager.call("get_slot_data", 1)
	if int(saved_after_purchase.get("money", 0)) != 60:
		_errors.append("Storage Expansion Lv.1 purchase should deduct money through SaveGameManager.")
	stash_panel.call("close_stash")
	if not bool(controller.call("open_interaction_by_id", "stash")):
		_errors.append("Stash station should reopen for Storage Expansion Lv.2 validation.")
		return
	await _wait_frames(2)
	var ready_second_state: Dictionary = stash_panel.call("get_display_state")
	var ready_second_upgrade: Dictionary = ready_second_state.get("storage_upgrade_state", {}) as Dictionary
	if not bool(ready_second_upgrade.get("can_upgrade", false)):
		_errors.append("Stash UI should enable Storage Expansion Lv.2 when money is available.")
	var second_result: Dictionary = stash_panel.call("purchase_storage_expansion")
	if not bool(second_result.get("success", false)):
		_errors.append("Stash UI should purchase Storage Expansion Lv.2 through the storage service.")
	var after_second_state: Dictionary = stash_panel.call("get_display_state")
	if int(after_second_state.get("stash_capacity", 0)) != 250 + int(StorageExpansionUpgrade1.storage_capacity_bonus) + int(StorageExpansionUpgrade2.storage_capacity_bonus):
		_errors.append("Stash UI capacity should include two purchased storage expansions.")
	var final_upgrade_state: Dictionary = after_second_state.get("storage_upgrade_state", {}) as Dictionary
	if not bool(final_upgrade_state.get("is_purchased", false)):
		_errors.append("Stash UI should show all current Storage Expansion tiers as complete.")
	var saved_after_second: Dictionary = _save_manager.call("get_slot_data", 1)
	if int(saved_after_second.get("money", 0)) != 30:
		_errors.append("Storage Expansion Lv.2 purchase should deduct money through SaveGameManager.")
	stash_panel.call("close_stash")


func _validate_recipe_needed_marks(scene: Node) -> void:
	var controller := scene.get_node_or_null("BaseInteractionController3D")
	var stash_panel := scene.get_node_or_null("HUD/BaseStashInventoryUI")
	if controller == null or stash_panel == null:
		return
	var save_data := {
		"difficulty_id": "normal",
		"money": 15,
		"stash": [{"item_path": AMMO_PATH, "quantity": 4}],
		"base_upgrades": {
			WORKBENCH_UPGRADE_ID: {"purchased": true},
		},
		"quests": {},
	}
	if not bool(_save_manager.call("save_slot_data", 1, save_data)):
		_errors.append("Validation setup should save a purchased workbench for recipe needed marks.")
		return
	if not bool(controller.call("open_interaction_by_id", "stash")):
		_errors.append("Stash station should reopen for recipe needed-mark validation.")
		return
	await _wait_frames(2)
	var state: Dictionary = stash_panel.call("get_display_state")
	var recipe_needed_paths: Array = state.get("recipe_needed_item_paths", []) as Array
	if not recipe_needed_paths.has(JUNK_PATH) or not recipe_needed_paths.has(WIRE_PATH):
		_errors.append("Stash UI should expose missing recipe material paths after the workbench upgrade is purchased.")
	var automatic_needed_paths: Array = state.get("automatic_needed_item_paths", []) as Array
	if not automatic_needed_paths.has(JUNK_PATH) or not automatic_needed_paths.has(WIRE_PATH):
		_errors.append("Recipe material paths should flow into automatic needed item paths.")
	var junk_tooltip: Dictionary = stash_panel.call("get_item_tooltip_by_path", JUNK_PATH)
	if not _tooltip_text(junk_tooltip).contains(TranslationServer.translate("ui.item.needed_source.recipe")):
		_errors.append("Stash item tooltip should explain recipe needed-item sources.")
	stash_panel.call("close_stash")
	save_data["base_upgrades"] = {}
	if not bool(_save_manager.call("save_slot_data", 1, save_data)):
		_errors.append("Validation setup should restore the base save after recipe needed-mark validation.")


func _validate_storage_transfers(scene: Node) -> void:
	var controller := scene.get_node_or_null("BaseInteractionController3D")
	var player := scene.get_node_or_null("Player3D")
	var stash_panel := scene.get_node_or_null("HUD/BaseStashInventoryUI")
	var inventory_panel := scene.get_node_or_null("HUD/InventoryEquipmentUI") as Control
	if controller == null or player == null or stash_panel == null or inventory_panel == null:
		return
	player.call("add_item_resource", WoodItem, 5)
	player.call("add_item_resource", JunkItem, 2)
	player.call("add_item_resource", PistolItem, 1)
	var inventory: InventoryModel = player.call("get_inventory_model")
	var safe_pocket: InventoryModel = player.call("get_safe_pocket_model")
	var equipment: RefCounted = player.call("get_equipment_model")
	var pistol_index := _stack_index_with_resource(inventory.get_display_items(), PISTOL_PATH)
	if pistol_index < 0 or not bool(player.call("equip_inventory_stack", pistol_index, &"sidearm")):
		_errors.append("Validation setup should equip a sidearm from the backpack.")
		return
	safe_pocket.add_item(AmmoItem, 6)

	if not bool(controller.call("open_interaction_by_id", "stash")):
		_errors.append("Stash station should open for storage transfer validation.")
		return
	await _wait_frames(2)

	if not bool(stash_panel.call("toggle_needed_item_by_path", JUNK_PATH)):
		_errors.append("Stash UI should allow marking a known item path with the N shortcut path.")
	var marked_state: Dictionary = stash_panel.call("get_display_state")
	if not (marked_state.get("manual_needed_item_paths", []) as Array).has(JUNK_PATH):
		_errors.append("Stash UI should report manually needed item paths.")
	var marked_save: Dictionary = _save_manager.call("get_slot_data", 1)
	if not bool((marked_save.get("needed_item_marks", {}) as Dictionary).get(JUNK_PATH, false)):
		_errors.append("Needed item marks should persist through SaveGameManager.")
	if not bool(stash_panel.call("toggle_needed_item_by_path", JUNK_PATH)):
		_errors.append("Stash UI should allow removing a needed item mark with the N shortcut path.")
	var unmarked_state: Dictionary = stash_panel.call("get_display_state")
	if (unmarked_state.get("manual_needed_item_paths", []) as Array).has(JUNK_PATH):
		_errors.append("Stash UI should remove manually needed item paths after toggling again.")

	var wood_index := _stack_index_with_resource(inventory.get_display_items(), WOOD_PATH)
	var stored_wood_quantity := _stack_quantity(inventory.get_display_items(), WOOD_PATH)
	var stored_junk_quantity := _stack_quantity(inventory.get_display_items(), JUNK_PATH)
	if wood_index < 0 or not bool(stash_panel.call("toggle_backpack_lock", wood_index)):
		_errors.append("Stash UI should lock a backpack stack with the L shortcut path.")
	var locked_state: Dictionary = stash_panel.call("get_display_state")
	var locked_backpack_slots: Array = locked_state.get("locked_backpack_slots", []) as Array
	if not locked_backpack_slots.has(wood_index):
		_errors.append("Stash UI should report locked backpack slots.")
	if bool(stash_panel.call("store_backpack_stack", wood_index)):
		_errors.append("Locked backpack items should not transfer into the warehouse.")
	var store_all_inventory_state: Dictionary = inventory_panel.call("get_display_state")
	var store_all_rect: Rect2 = store_all_inventory_state.get("store_all_button_rect", Rect2())
	if not bool(store_all_inventory_state.get("store_all_button_visible", false)) or store_all_rect.size.x <= 0.0:
		_errors.append("Warehouse-open backpack panel should expose a clickable All Store button.")
	else:
		_click_control(stash_panel as Control, _control_local_point(stash_panel as Control, inventory_panel, store_all_rect.get_center()))
		await _wait_frames(2)
	if _stack_quantity(inventory.get_display_items(), WOOD_PATH) != stored_wood_quantity:
		_errors.append("All Store should leave locked backpack items in place.")
	if _stack_quantity(inventory.get_display_items(), JUNK_PATH) != 0:
		_errors.append("All Store should remove unlocked junk from the backpack.")
	if safe_pocket.get_used_slots() <= 0:
		_errors.append("All Store should skip the safe pocket by default.")
	var saved_after_store_all: Dictionary = _save_manager.call("get_slot_data", 1)
	if _stack_quantity(saved_after_store_all.get("stash", []) as Array, JUNK_PATH) != stored_junk_quantity:
		_errors.append("All Store should persist moved backpack items to save stash.")
	wood_index = _stack_index_with_resource(inventory.get_display_items(), WOOD_PATH)
	if wood_index < 0 or not bool(stash_panel.call("toggle_backpack_lock", wood_index)):
		_errors.append("Stash UI should unlock a backpack stack with the L shortcut path.")
	var click_state: Dictionary = stash_panel.call("get_display_state")
	var backpack_grid_rect: Rect2 = click_state.get("backpack_grid_rect", Rect2())
	var wood_click_position := _grid_slot_center(backpack_grid_rect, wood_index, 5)
	var wood_quantity_before_single_click := _stack_quantity(inventory.get_display_items(), WOOD_PATH)
	_click_control(stash_panel as Control, wood_click_position)
	await _wait_frames(2)
	if _stack_quantity(inventory.get_display_items(), WOOD_PATH) != wood_quantity_before_single_click:
		_errors.append("Single-clicking a backpack item on the warehouse page should not transfer it.")
	wood_index = _stack_index_with_resource(inventory.get_display_items(), WOOD_PATH)
	if wood_index < 0:
		_errors.append("Single-clicked backpack item should remain available for double-click storage.")
	else:
		wood_click_position = _grid_slot_center(backpack_grid_rect, wood_index, 5)
		_click_control(stash_panel as Control, wood_click_position, true)
		await _wait_frames(2)
	var saved_after_backpack: Dictionary = _save_manager.call("get_slot_data", 1)
	if _stack_quantity(saved_after_backpack.get("stash", []) as Array, WOOD_PATH) != stored_wood_quantity:
		_errors.append("Double-clicked backpack items should persist to save stash.")
	if _stack_quantity(inventory.get_display_items(), WOOD_PATH) != 0:
		_errors.append("Double-clicked backpack items should leave the backpack.")

	if not bool(stash_panel.call("store_equipment_slot", &"sidearm")):
		_errors.append("Stash UI should store equipped sidearm items.")
	if not equipment.call("is_empty", &"sidearm"):
		_errors.append("Stored equipment item should clear the equipment slot.")
	var saved_after_equipment: Dictionary = _save_manager.call("get_slot_data", 1)
	if _stack_quantity(saved_after_equipment.get("stash", []) as Array, PISTOL_PATH) != 1:
		_errors.append("Stored equipment item should persist to save stash.")
	stash_panel.call("organize_stash", &"value")
	await _wait_frames(1)
	var sorted_stash_state: Dictionary = stash_panel.call("get_display_state")
	var sorted_stash_items: Array = sorted_stash_state.get("stash_items", []) as Array
	if sorted_stash_items.is_empty() or int((sorted_stash_items[0] as Dictionary).get("catalog_number", 0)) != PistolItem.catalog_number:
		_errors.append("Stash value sort should put the stored pistol at the front of the warehouse.")
	if str(sorted_stash_state.get("status_text", "")) != str(TranslationServer.translate("ui.stash.sorted_value")):
		_errors.append("Stash sort status should be localized.")

	if not bool(stash_panel.call("store_safe_pocket_stack", 0)):
		_errors.append("Stash UI should store safe pocket stacks.")
	if safe_pocket.get_used_slots() != 0:
		_errors.append("Stored safe pocket item should leave the safe pocket.")
	var saved_after_safe: Dictionary = _save_manager.call("get_slot_data", 1)
	if _stack_quantity(saved_after_safe.get("stash", []) as Array, AMMO_PATH) != 10:
		_errors.append("Stored safe pocket ammo should merge with existing save stash ammo.")

	var state: Dictionary = stash_panel.call("get_display_state")
	var stash_items: Array = state.get("stash_items", []) as Array
	var stash_wood_index := _stack_index_with_resource(stash_items, WOOD_PATH)
	if stash_wood_index < 0 or not bool(stash_panel.call("withdraw_stash_stack", stash_wood_index)):
		_errors.append("Stash UI should withdraw warehouse stacks to backpack.")
	if _stack_quantity(inventory.get_display_items(), WOOD_PATH) != stored_wood_quantity:
		_errors.append("Withdrawn stash item should enter the backpack.")
	var saved_after_withdraw: Dictionary = _save_manager.call("get_slot_data", 1)
	if _stack_quantity(saved_after_withdraw.get("stash", []) as Array, WOOD_PATH) != 0:
		_errors.append("Withdrawn item should be removed from save stash.")
	stash_panel.call("close_stash")


func _setup_save_manager() -> void:
	_save_manager = root.get_node_or_null("SaveGameManager")
	if _save_manager == null:
		_save_manager = SaveGameManagerScript.new()
		_save_manager.name = "SaveGameManager"
		root.add_child(_save_manager)
		_created_save_manager = true
	_save_manager.set("save_root_path", VALIDATION_SAVE_ROOT)
	_cleanup_validation_root(VALIDATION_SAVE_ROOT)
	_save_manager.call("set_current_slot_index", 1)
	_save_manager.call("save_slot_data", 1, {
		"difficulty_id": "normal",
		"money": 15,
		"stash": [{"item_path": AMMO_PATH, "quantity": 4}],
		"base_upgrades": {},
		"quests": {str(FirstSalvageQuest.get("id")): QuestStateScript.accept(FirstSalvageQuest)},
	})


func _stack_index_with_resource(stacks: Array, item_path: String) -> int:
	for index in range(stacks.size()):
		var value: Variant = stacks[index]
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("resource_path", (value as Dictionary).get("item_path", ""))) == item_path:
			return index
	return -1


func _stack_quantity(stacks: Array, item_path: String) -> int:
	var total := 0
	for value in stacks:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var stack := value as Dictionary
		if str(stack.get("item_path", stack.get("resource_path", ""))) == item_path:
			total += int(stack.get("quantity", 0))
	return total


func _tooltip_text(tooltip: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append(str(tooltip.get("title", "")))
	for line in tooltip.get("lines", []) as Array:
		parts.append(str(line))
	var result := ""
	for index in range(parts.size()):
		if index > 0:
			result += "\n"
		result += parts[index]
	return result


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


func _force_validation_locale() -> void:
	var localization := root.get_node_or_null("LocalizationBootstrap")
	if localization != null and localization.has_method("set_game_locale"):
		localization.call("set_game_locale", "zh_TW")
	else:
		TranslationServer.set_locale("zh_TW")


func _press_key_on_ui_manager(ui_manager: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	ui_manager.call("_input", event)


func _click_control(control: Control, position: Vector2, double_click := false) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.double_click = double_click
	control.call("_gui_input", event)
	var release_event := InputEventMouseButton.new()
	release_event.position = position
	release_event.global_position = position
	release_event.button_index = MOUSE_BUTTON_LEFT
	release_event.pressed = false
	release_event.double_click = double_click
	control.call("_gui_input", release_event)


func _grid_slot_center(grid_rect: Rect2, stack_index: int, columns: int) -> Vector2:
	var safe_columns := maxi(columns, 1)
	var cell_size := Vector2(grid_rect.size.x / float(safe_columns), grid_rect.size.x / float(safe_columns))
	var column := stack_index % safe_columns
	var row := stack_index / safe_columns
	return grid_rect.position + Vector2((float(column) + 0.5) * cell_size.x, (float(row) + 0.5) * cell_size.y)


func _control_local_point(target: Control, source: Control, source_local_position: Vector2) -> Vector2:
	if target == null or source == null or not target.is_inside_tree() or not source.is_inside_tree():
		return source_local_position
	var global_position: Vector2 = source.get_global_transform_with_canvas() * source_local_position
	return target.get_global_transform_with_canvas().affine_inverse() * global_position


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
