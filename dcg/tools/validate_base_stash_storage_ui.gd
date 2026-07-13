extends SceneTree

const Base3DScene := preload("res://scenes/base/base_3d.tscn")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")
const QuestStateScript := preload("res://scripts/quests/quest_state.gd")
const FirstSalvageQuest := preload("res://data/quests/first_salvage.tres")
const StorageExpansionUpgrade1 := preload("res://data/base_upgrades/storage_expansion_level_1.tres")
const StorageExpansionUpgrade2 := preload("res://data/base_upgrades/storage_expansion_level_2.tres")
const WoodItem := preload("res://data/items/crafting/wood.tres")
const JunkItem := preload("res://data/items/loot/junk.tres")
const AmmoItem := preload("res://data/items/ammo/ammo_S.tres")
const PistolItem := preload("res://data/items/weapons/pistol_S.tres")
const LightArmorItem := preload("res://data/items/armor/light_armor.tres")
const SmallBackpackItem := preload("res://data/items/backpacks/small_backpack.tres")

const VALIDATION_SAVE_ROOT := "user://validation_base_stash_storage_ui"
const WOOD_PATH := "res://data/items/crafting/wood.tres"
const JUNK_PATH := "res://data/items/loot/junk.tres"
const AMMO_PATH := "res://data/items/ammo/ammo_S.tres"
const PISTOL_PATH := "res://data/items/weapons/pistol_S.tres"
const LIGHT_ARMOR_PATH := "res://data/items/armor/light_armor.tres"
const SMALL_BACKPACK_PATH := "res://data/items/backpacks/small_backpack.tres"
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
	await _validate_stash_currency_transfers(scene)
	await _validate_storage_capacity_upgrade(scene)
	await _validate_recipe_needed_marks(scene)
	await _validate_storage_transfers(scene)
	_free_node(scene)
	_cleanup_validation_root(VALIDATION_SAVE_ROOT)
	if _created_save_manager:
		_free_node(_save_manager)
	if _errors.is_empty():
		print("[base_stash_storage_ui] OK open=warehouse_grid currency=deposit_withdraw scrim=clear capacity=purchase lock=L all_store=locked_safe store=backpack/equipment/safe_pocket withdraw=backpack save=persist")
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
		if bool(inventory_state.get("overlay_scrim_visible", true)):
			_errors.append("Stash-open backpack surface should remove the full-screen overlay scrim.")
		var store_all_rect: Rect2 = inventory_state.get("store_all_button_rect", Rect2())
		if store_all_rect.size.x <= 0.0 or store_all_rect.size.y <= 0.0:
			_errors.append("Stash-open backpack All Store action should expose a clickable rect.")
	if int(state.get("stash_capacity", 0)) != 250:
		_errors.append("Stash UI should expose the 250-slot warehouse capacity.")
	if int(state.get("visible_stash_rows", 0)) != 8:
		_errors.append("Warehouse should expose eight visible rows after adding the requested two storage rows.")
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
	if not bool(state.get("sort_button_visible", false)):
		_errors.append("Stash UI should show the warehouse organize button.")
	if str(state.get("sort_button_text", "")) != str(TranslationServer.translate("ui.stash.sort")):
		_errors.append("Warehouse organize button should use localized text.")
	if bool(state.get("storage_upgrade_button_visible", true)):
		_errors.append("Stash UI should not show the storage expansion button on this page.")
	if bool(state.get("stash_hint_visible", true)) or bool(state.get("stash_status_visible", true)):
		_errors.append("Stash UI should not show the marked hint/status text block above the warehouse grid.")
	var close_button_rect: Rect2 = state.get("close_button_rect", Rect2())
	if close_button_rect.size.x > 0.0 or close_button_rect.size.y > 0.0:
		_errors.append("Warehouse page should not expose a redundant close button rect.")
	var left_panel_rect: Rect2 = state.get("left_panel_rect", Rect2())
	var right_panel_rect: Rect2 = state.get("right_panel_rect", Rect2())
	var backpack_grid_rect: Rect2 = state.get("backpack_grid_rect", Rect2())
	var stash_grid_rect: Rect2 = state.get("stash_grid_rect", Rect2())
	var stash_scroll_track_rect: Rect2 = state.get("stash_scroll_track_rect", Rect2())
	var stash_currency_panel_rect: Rect2 = state.get("stash_currency_panel_rect", Rect2())
	var sort_button_rect: Rect2 = state.get("sort_button_rect", Rect2())
	var category_tabs: Array = state.get("stash_category_tabs", []) as Array
	if backpack_grid_rect.position.x >= stash_grid_rect.position.x:
		_errors.append("Normal backpack grid should remain on the left of the warehouse grid.")
	if right_panel_rect.position.x < left_panel_rect.end.x + 120.0:
		_errors.append("Warehouse panel should be anchored on the right side, leaving the center play view readable.")
	if right_panel_rect.size.y + 0.5 < left_panel_rect.size.y:
		_errors.append("Warehouse panel should keep the full inventory panel height.")
	if right_panel_rect.size.x >= left_panel_rect.size.x:
		_errors.append("Warehouse panel should use the compact width that preserves the right-side gutter.")
	if absf(right_panel_rect.position.y - left_panel_rect.position.y) > 1.0:
		_errors.append("Warehouse panel should align vertically with the normal backpack/equipment panel.")
	if stash_grid_rect.position.y > right_panel_rect.position.y + 140.0:
		_errors.append("Warehouse grid should stay near the top while leaving room for category tabs.")
	if sort_button_rect.size.x <= 0.0 or sort_button_rect.size.y <= 0.0 or not right_panel_rect.encloses(sort_button_rect):
		_errors.append("Warehouse organize button should expose a clickable rect inside the right panel.")
	_validate_stash_category_tabs(stash_panel as Control, state, category_tabs, stash_grid_rect, right_panel_rect)
	if absf(stash_scroll_track_rect.position.y - stash_grid_rect.position.y) > 1.0 or stash_scroll_track_rect.position.x <= stash_grid_rect.end.x:
		_errors.append("Warehouse scrollbar should start beside the grid at its top edge.")
	if absf(stash_scroll_track_rect.size.y - stash_grid_rect.size.y) > 1.0:
		_errors.append("Warehouse scrollbar height should align with the visible storage grid rows.")
	if stash_currency_panel_rect.size.x > 0.0 and stash_scroll_track_rect.intersects(stash_currency_panel_rect):
		_errors.append("Warehouse scrollbar should not overlap the bottom coin panel.")
	if stash_scroll_track_rect.size.x < 10.0 or stash_scroll_track_rect.size.x > 16.0:
		_errors.append("Warehouse scrollbar should keep a compact, usable width.")
	if inventory_panel != null and inventory_panel.has_method("get_display_state"):
		var inventory_hover_state: Dictionary = inventory_panel.call("get_display_state")
		var equipment_rects: Dictionary = inventory_hover_state.get("equipment_slot_rects", {})
		var primary_rect: Rect2 = equipment_rects.get("primary_weapon", Rect2())
		if primary_rect.size.x > 0.0:
			var duplicate_tooltip_stack: Dictionary = stash_panel.call("_tooltip_stack_at_position", _control_local_point(stash_panel as Control, inventory_panel, primary_rect.get_center()))
			if not duplicate_tooltip_stack.is_empty():
				_errors.append("Warehouse overlay should not draw duplicate tooltips for the reused left inventory surface.")
	var stash_hover_stack: Dictionary = stash_panel.call("_tooltip_stack_at_position", _grid_slot_center(stash_grid_rect, 0, 5))
	if stash_hover_stack.is_empty():
		_errors.append("Warehouse overlay should still draw tooltips for right-side stash items.")
	_click_control(stash_panel as Control, _grid_slot_center(stash_grid_rect, 0, 5))
	await _wait_frames(1)
	state = stash_panel.call("get_display_state")
	var item_detail_state: Dictionary = state.get("item_detail_panel", {})
	var item_detail_rect: Rect2 = state.get("item_detail_panel_rect", Rect2())
	if item_detail_state.is_empty():
		_errors.append("Single-clicking a warehouse item should open the central item detail panel.")
	if item_detail_rect.size.x <= 0.0 or item_detail_rect.position.x < left_panel_rect.end.x + 10.0 or item_detail_rect.end.x > right_panel_rect.position.x - 10.0:
		_errors.append("Warehouse item detail panel should stay in the reserved center space between inventory and warehouse.")
	var empty_detail_close_index := (state.get("stash_items", []) as Array).size()
	_click_control(stash_panel as Control, _grid_slot_center(stash_grid_rect, empty_detail_close_index, 5))
	await _wait_frames(1)
	state = stash_panel.call("get_display_state")
	if not (state.get("item_detail_panel", {}) as Dictionary).is_empty():
		_errors.append("Clicking an empty warehouse slot should close the item detail panel.")
	var stash_model: RefCounted = stash_panel.get("stash_model")
	if stash_model == null or not bool(stash_model.call("add_stack", PistolItem.to_stack(1))):
		_errors.append("Validation setup should add a stash weapon for weapon mod panel checks.")
	else:
		await _wait_frames(1)
		state = stash_panel.call("get_display_state")
		stash_grid_rect = state.get("stash_grid_rect", Rect2())
		var pistol_stash_index := ((state.get("stash_items", []) as Array).size() - 1)
		_click_control(stash_panel as Control, _grid_slot_center(stash_grid_rect, pistol_stash_index, 5))
		await _wait_frames(1)
		state = stash_panel.call("get_display_state")
		var stash_weapon_mod_state: Dictionary = state.get("weapon_mod_panel", {})
		if not bool(stash_weapon_mod_state.get("has_weapon", false)):
			_errors.append("Single-clicking a warehouse weapon should open the weapon mod panel with attachment slots and stats.")
		if not (state.get("item_detail_panel", {}) as Dictionary).is_empty():
			_errors.append("Warehouse weapons should not fall back to the generic item detail panel when mod slots exist.")
		var stash_weapon_mod_text := str(state.get("weapon_mod_panel_text", ""))
		if stash_weapon_mod_text.contains(TranslationServer.translate("ui.weapon_mod.slot_format") % TranslationServer.translate("ui.equipment.weapon_mag")):
			_errors.append("Warehouse weapon mod panel should keep compact attachment slots free of slot label text.")
	if not str(state.get("title", "")).contains(TranslationServer.translate("ui.base.station.stash")):
		_errors.append("Stash UI title should be localized.")
	var quest_needed_paths: Array = state.get("quest_needed_item_paths", []) as Array
	if not quest_needed_paths.has(WOOD_PATH):
		_errors.append("Active item quests should automatically mark their missing objective items as needed.")
	var workbench_needed_paths: Array = state.get("workbench_needed_item_paths", []) as Array
	if not workbench_needed_paths.has(WOOD_PATH):
		_errors.append("Unpurchased workbench upgrade should automatically mark its missing materials as needed.")
	var automatic_needed_paths: Array = state.get("automatic_needed_item_paths", []) as Array
	if not automatic_needed_paths.has(WOOD_PATH):
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
			if not bool(closed_inventory_state.get("overlay_scrim_visible", false)):
				_errors.append("Closing the warehouse should restore the normal backpack overlay scrim.")
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
	var stash_painter_source := FileAccess.get_file_as_string("res://scripts/ui/base_stash_inventory_painter_support.gd")
	for required_style_token in [
		"UISurfacePaletteScript.panel_fill()",
		"UISurfacePaletteScript.slot_fill()",
		"UISurfacePaletteScript.button_border()",
	]:
		if not stash_painter_source.contains(required_style_token):
			_errors.append("Warehouse panel should reuse the shared UI palette through %s." % required_style_token)
	for required_state_flag in [
		'"left_panel_role": "tab_inventory_reference"',
		'"draws_left_transfer_panel": false',
		'"dims_inventory_surface": false',
		'"store_all_button_visible": false',
		'"sort_button_visible": true',
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
	if not stash_source.contains("ItemCodexCatalogScript") or not stash_source.contains("BaseStashInventoryCategorySupportScript"):
		_errors.append("Warehouse categories should be driven by the item codex index through the category support boundary.")
	var category_source := FileAccess.get_file_as_string("res://scripts/ui/base_stash_inventory_category_support.gd")
	if not category_source.contains("storage_category_id_for_path"):
		_errors.append("Warehouse category support should resolve stack categories through the item codex catalog index.")
	if not stash_source.contains("_painter.lock_badge") or not stash_source.contains("_painter.needed_badge"):
		_errors.append("BaseStashInventoryUI should delegate lock/needed cell badges to the shared inventory painter.")
	var painter_source := FileAccess.get_file_as_string("res://scripts/ui/inventory_equipment_painter.gd")
	for required in ["func lock_badge", "func needed_badge", "func badge"]:
		if not painter_source.contains(required):
			_errors.append("InventoryEquipmentPainter should own shared stack-cell badge drawing: %s." % required)
	stash_panel.call("close_stash")


func _validate_stash_currency_transfers(scene: Node) -> void:
	var controller := scene.get_node_or_null("BaseInteractionController3D")
	var stash_panel := scene.get_node_or_null("HUD/BaseStashInventoryUI") as Control
	var inventory_panel := scene.get_node_or_null("HUD/InventoryEquipmentUI") as Control
	if controller == null or stash_panel == null:
		return
	var save_data: Dictionary = _save_manager.call("get_slot_data", 1)
	save_data["money"] = 37
	save_data["stash_money"] = 8
	if not bool(_save_manager.call("save_slot_data", 1, save_data)):
		_errors.append("Validation setup should save wallet and warehouse coin balances.")
		return
	if not bool(controller.call("open_interaction_by_id", "stash")):
		_errors.append("Stash station should open for warehouse coin validation.")
		return
	await _wait_frames(2)
	var state: Dictionary = stash_panel.call("get_display_state")
	if int(state.get("wallet_money", -1)) != 37 or int(state.get("stash_money", -1)) != 8:
		_errors.append("Warehouse coin panel should expose separate wallet and warehouse balances.")
	var right_panel_rect: Rect2 = state.get("right_panel_rect", Rect2())
	var grid_rect: Rect2 = state.get("stash_grid_rect", Rect2())
	var currency_rect: Rect2 = state.get("stash_currency_panel_rect", Rect2())
	var balance_rect: Rect2 = state.get("stash_currency_balance_rect", Rect2())
	var deposit_rect: Rect2 = state.get("stash_currency_deposit_rect", Rect2())
	var withdraw_rect: Rect2 = state.get("stash_currency_withdraw_rect", Rect2())
	if currency_rect.size.x <= 0.0 or currency_rect.size.y <= 0.0 or not right_panel_rect.encloses(currency_rect):
		_errors.append("Warehouse coin panel should sit inside the right-side warehouse surface.")
	if absf(currency_rect.position.x - grid_rect.position.x) > 1.0 or absf(currency_rect.size.x - grid_rect.size.x) > 1.0:
		_errors.append("Warehouse coin panel should align horizontally with the storage grid.")
	if currency_rect.position.y <= grid_rect.end.y:
		_errors.append("Warehouse coin panel should sit below the visible storage rows.")
	if balance_rect.size.x <= 0.0 or deposit_rect.size.x <= 0.0 or withdraw_rect.size.x <= 0.0 or not currency_rect.encloses(balance_rect) or not currency_rect.encloses(deposit_rect) or not currency_rect.encloses(withdraw_rect):
		_errors.append("Warehouse coin bottom bar should expose contained balance, deposit, and withdraw controls.")
	if absf(balance_rect.position.y - deposit_rect.position.y) > 1.0 or absf(deposit_rect.position.y - withdraw_rect.position.y) > 1.0 or absf(balance_rect.size.y - deposit_rect.size.y) > 1.0 or absf(deposit_rect.size.y - withdraw_rect.size.y) > 1.0:
		_errors.append("Warehouse coin balance and transfer buttons should share one aligned row.")
	if balance_rect.intersects(deposit_rect) or deposit_rect.intersects(withdraw_rect) or balance_rect.intersects(withdraw_rect):
		_errors.append("Warehouse coin balance, deposit, and withdraw controls should not overlap.")
	if inventory_panel != null and inventory_panel.has_method("get_display_state") and bool((inventory_panel.call("get_display_state") as Dictionary).get("overlay_scrim_visible", true)):
		_errors.append("Warehouse coin page should keep the center world clear of the backpack overlay scrim.")

	_click_control(stash_panel, deposit_rect.get_center())
	await _wait_frames(1)
	state = stash_panel.call("get_display_state")
	var deposit_dialog: Dictionary = state.get("currency_transfer_dialog", {}) as Dictionary
	if not bool(deposit_dialog.get("open", false)) or str(deposit_dialog.get("mode", "")) != "deposit" or int(deposit_dialog.get("maximum_amount", -1)) != 37:
		_errors.append("Warehouse deposit should open an amount-selection dialog for the wallet balance.")
	var deposit_slider: Rect2 = deposit_dialog.get("slider_rect", Rect2())
	_click_control(stash_panel, Vector2(deposit_slider.position.x + deposit_slider.size.x * (10.0 / 37.0), deposit_slider.get_center().y))
	state = stash_panel.call("get_display_state")
	deposit_dialog = state.get("currency_transfer_dialog", {}) as Dictionary
	if int(deposit_dialog.get("selected_amount", -1)) != 10:
		_errors.append("Warehouse deposit slider should select a partial coin amount.")
	var deposit_confirm_rect: Rect2 = deposit_dialog.get("confirm_rect", Rect2())
	_click_control(stash_panel, deposit_confirm_rect.get_center())
	await _wait_frames(1)
	state = stash_panel.call("get_display_state")
	if int(state.get("wallet_money", -1)) != 27 or int(state.get("stash_money", -1)) != 18:
		_errors.append("Warehouse deposit confirmation should move only the selected wallet amount.")
	var saved_after_deposit: Dictionary = _save_manager.call("get_slot_data", 1)
	if int(saved_after_deposit.get("money", -1)) != 27 or int(saved_after_deposit.get("stash_money", -1)) != 18:
		_errors.append("Warehouse partial deposit should persist both balances through SaveGameManager.")

	withdraw_rect = state.get("stash_currency_withdraw_rect", Rect2())
	_click_control(stash_panel, withdraw_rect.get_center())
	await _wait_frames(1)
	state = stash_panel.call("get_display_state")
	var withdraw_dialog: Dictionary = state.get("currency_transfer_dialog", {}) as Dictionary
	if not bool(withdraw_dialog.get("open", false)) or str(withdraw_dialog.get("mode", "")) != "withdraw" or int(withdraw_dialog.get("maximum_amount", -1)) != 18:
		_errors.append("Warehouse withdrawal should open an amount-selection dialog for stored coins.")
	var withdraw_slider: Rect2 = withdraw_dialog.get("slider_rect", Rect2())
	_click_control(stash_panel, Vector2(withdraw_slider.position.x + withdraw_slider.size.x * (6.0 / 18.0), withdraw_slider.get_center().y))
	state = stash_panel.call("get_display_state")
	withdraw_dialog = state.get("currency_transfer_dialog", {}) as Dictionary
	var withdraw_confirm_rect: Rect2 = withdraw_dialog.get("confirm_rect", Rect2())
	_click_control(stash_panel, withdraw_confirm_rect.get_center())
	await _wait_frames(1)
	state = stash_panel.call("get_display_state")
	if int(state.get("wallet_money", -1)) != 33 or int(state.get("stash_money", -1)) != 12:
		_errors.append("Warehouse withdrawal confirmation should move only the selected stored amount.")
	var saved_after_withdraw: Dictionary = _save_manager.call("get_slot_data", 1)
	if int(saved_after_withdraw.get("money", -1)) != 33 or int(saved_after_withdraw.get("stash_money", -1)) != 12:
		_errors.append("Warehouse partial withdrawal should persist both balances through SaveGameManager.")

	deposit_rect = state.get("stash_currency_deposit_rect", Rect2())
	_click_control(stash_panel, deposit_rect.get_center())
	await _wait_frames(1)
	state = stash_panel.call("get_display_state")
	deposit_dialog = state.get("currency_transfer_dialog", {}) as Dictionary
	var deposit_cancel_rect: Rect2 = deposit_dialog.get("cancel_rect", Rect2())
	_click_control(stash_panel, deposit_cancel_rect.get_center())
	await _wait_frames(1)
	state = stash_panel.call("get_display_state")
	if bool((state.get("currency_transfer_dialog", {}) as Dictionary).get("open", false)) or int(state.get("wallet_money", -1)) != 33 or int(state.get("stash_money", -1)) != 12:
		_errors.append("Cancelling a warehouse coin transfer should close the dialog without changing balances.")
	var currency_dialog_source := FileAccess.get_file_as_string("res://scripts/ui/stash_currency_transfer_dialog.gd")
	for required_style in ["UISurfacePaletteScript.panel_fill()", "UISurfacePaletteScript.RADIUS_FLOATING_PANEL", "painter.numeric_slider(slider_rect, ratio)"]:
		if not currency_dialog_source.contains(required_style):
			_errors.append("Warehouse currency dialog should reuse the shared floating-panel and numeric-slider style: %s." % required_style)
	if currency_dialog_source.contains("painter.panel(dialog_rect, UISurfacePaletteScript.panel_fill(true)") or currency_dialog_source.contains("owner.draw_circle(knob_center, 10.0 * ui_scale, UISurfacePaletteScript.BAR_FILL)"):
		_errors.append("Warehouse currency dialog should not use a separate dark panel or progress-bar slider style.")
	TranslationServer.set_locale("en")
	if str(TranslationServer.translate("ui.stash.deposit")) != "Deposit" or str(TranslationServer.translate("ui.stash.withdraw")) != "Withdraw" or str(TranslationServer.translate("ui.stash.deposit_title")) != "Deposit Coins" or str(TranslationServer.translate("ui.stash.transfer_confirm")) != "Confirm" or str(TranslationServer.translate("ui.stash.transfer_cancel")) != "Cancel":
		_errors.append("Warehouse currency controls should provide English localization without Chinese fallback text.")
	TranslationServer.set_locale("zh_TW")
	stash_panel.call("close_stash")


func _validate_stash_category_tabs(stash_panel: Control, state: Dictionary, category_tabs: Array, stash_grid_rect: Rect2, right_panel_rect: Rect2) -> void:
	var expected_ids := ["all", "weapon", "ammo", "equipment", "attachment", "totem", "medical", "food", "other"]
	var expected_zh_labels := ["全部", "武器", "彈藥", "裝備", "配件", "圖騰", "藥品", "食物", "其他"]
	var actual_ids: Array[String] = []
	var actual_labels: Array[String] = []
	var tabs_by_id := {}
	for raw_tab in category_tabs:
		var tab: Dictionary = raw_tab as Dictionary
		var category_id := str(tab.get("id", ""))
		actual_ids.append(category_id)
		actual_labels.append(str(tab.get("label", "")))
		tabs_by_id[category_id] = tab
		var rect: Rect2 = tab.get("rect", Rect2())
		if rect.size.x <= 0.0 or rect.size.y <= 0.0 or not right_panel_rect.encloses(rect):
			_errors.append("Warehouse category tab `%s` should expose a clickable rect inside the right panel." % category_id)
		if rect.end.y >= stash_grid_rect.position.y:
			_errors.append("Warehouse category tab `%s` should sit above the storage grid." % category_id)
		if str(tab.get("label", "")).strip_edges() == "" or str(tab.get("short_label", "")).strip_edges() == "":
			_errors.append("Warehouse category tab `%s` should expose localized full and compact labels." % category_id)
	if actual_ids != expected_ids:
		_errors.append("Warehouse categories should follow the codex-derived order: %s." % expected_ids)
	if actual_labels != expected_zh_labels:
		_errors.append("Warehouse categories should expose the requested Traditional Chinese labels.")
	if str(state.get("stash_category_id", "")) != "all":
		_errors.append("Warehouse should open on the All category.")
	if category_tabs.size() != expected_ids.size():
		return

	var ammo_tab: Dictionary = tabs_by_id.get("ammo", {}) as Dictionary
	_click_control(stash_panel, (ammo_tab.get("rect", Rect2()) as Rect2).get_center())
	var ammo_state: Dictionary = stash_panel.call("get_display_state")
	if str(ammo_state.get("stash_category_id", "")) != "ammo":
		_errors.append("Clicking the Ammo category should activate the ammo warehouse filter.")
	for stack in ammo_state.get("visible_stash_items", []) as Array:
		if str((stack as Dictionary).get("resource_path", "")) != AMMO_PATH:
			_errors.append("Ammo warehouse filter should only expose codex-indexed ammo items.")

	var weapon_tab: Dictionary = tabs_by_id.get("weapon", {}) as Dictionary
	_click_control(stash_panel, (weapon_tab.get("rect", Rect2()) as Rect2).get_center())
	var weapon_state: Dictionary = stash_panel.call("get_display_state")
	if str(weapon_state.get("stash_category_id", "")) != "weapon" or not (weapon_state.get("visible_stash_items", []) as Array).is_empty():
		_errors.append("Weapon warehouse filter should hide the ammo-only validation stash.")

	var all_tab: Dictionary = tabs_by_id.get("all", {}) as Dictionary
	_click_control(stash_panel, (all_tab.get("rect", Rect2()) as Rect2).get_center())
	var all_state: Dictionary = stash_panel.call("get_display_state")
	if str(all_state.get("stash_category_id", "")) != "all" or (all_state.get("visible_stash_items", []) as Array).size() != (all_state.get("stash_items", []) as Array).size():
		_errors.append("All warehouse category should restore every stash stack.")

	var organize_rect: Rect2 = all_state.get("sort_button_rect", Rect2())
	_click_control(stash_panel, organize_rect.get_center())
	var organized_state: Dictionary = stash_panel.call("get_display_state")
	if str(organized_state.get("status_text", "")) != str(TranslationServer.translate("ui.stash.sorted_type")):
		_errors.append("Clicking warehouse Organize should sort through the existing stash model and expose localized status.")

	TranslationServer.set_locale("en")
	stash_panel.call("refresh_localization")
	var english_state: Dictionary = stash_panel.call("get_display_state")
	var english_labels: Array[String] = []
	for raw_tab in english_state.get("stash_category_tabs", []) as Array:
		english_labels.append(str((raw_tab as Dictionary).get("label", "")))
	var expected_english_labels := ["All", "Weapons", "Ammunition", "Equipment", "Attachments", "Totems", "Medicine", "Food", "Other"]
	if english_labels != expected_english_labels:
		_errors.append("English warehouse categories should be fully translated without Chinese fallback text.")
	TranslationServer.set_locale("zh_TW")
	stash_panel.call("refresh_localization")


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
	if not recipe_needed_paths.has(JUNK_PATH):
		_errors.append("Stash UI should expose missing recipe material paths after the workbench upgrade is purchased.")
	var automatic_needed_paths: Array = state.get("automatic_needed_item_paths", []) as Array
	if not automatic_needed_paths.has(JUNK_PATH):
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
	await _validate_inventory_reference_hover_clears(stash_panel as Control, inventory_panel)

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

	var inventory_drag_state: Dictionary = inventory_panel.call("get_display_state")
	var equipment_rects: Dictionary = inventory_drag_state.get("equipment_slot_rects", {})
	var sidearm_rect: Rect2 = equipment_rects.get("sidearm", Rect2())
	var stash_drag_state: Dictionary = stash_panel.call("get_display_state")
	var drag_backpack_grid_rect: Rect2 = stash_drag_state.get("backpack_grid_rect", Rect2())
	if sidearm_rect.size.x <= 0.0 or drag_backpack_grid_rect.size.x <= 0.0:
		_errors.append("Stash-open inventory surface should expose equipment and backpack rects for drag forwarding.")
	else:
		var drag_start := _control_local_point(stash_panel as Control, inventory_panel, sidearm_rect.get_center())
		var drag_end := _grid_slot_center(drag_backpack_grid_rect, 0, 5)
		_drag_control(stash_panel as Control, drag_start, drag_end)
		await _wait_frames(2)
		if not equipment.call("is_empty", &"sidearm"):
			_errors.append("Dragging equipped sidearm while stash is open should clear the equipment slot.")
		if _stack_quantity(inventory.get_display_items(), PISTOL_PATH) != 1:
			_errors.append("Dragging equipped sidearm while stash is open should move it back to the normal backpack.")
		var sidearm_backpack_index := _stack_index_with_resource(inventory.get_display_items(), PISTOL_PATH)
		if sidearm_backpack_index < 0 or not bool(player.call("equip_inventory_stack", sidearm_backpack_index, &"sidearm")):
			_errors.append("Validation setup should re-equip sidearm after stash-open drag forwarding.")

	var sidearm_store_state: Dictionary = inventory_panel.call("get_display_state")
	var sidearm_store_rects: Dictionary = sidearm_store_state.get("equipment_slot_rects", {})
	var sidearm_store_rect: Rect2 = sidearm_store_rects.get("sidearm", Rect2())
	if sidearm_store_rect.size.x <= 0.0:
		_errors.append("Stash-open inventory surface should expose sidearm rect for double-click store.")
	else:
		_click_control(stash_panel as Control, _control_local_point(stash_panel as Control, inventory_panel, sidearm_store_rect.get_center()), true)
		await _wait_frames(2)
	if not equipment.call("is_empty", &"sidearm"):
		_errors.append("Double-clicking equipped sidearm on the warehouse page should clear the equipment slot.")
	var saved_after_equipment: Dictionary = _save_manager.call("get_slot_data", 1)
	if _stack_quantity(saved_after_equipment.get("stash", []) as Array, PISTOL_PATH) != 1:
		_errors.append("Double-clicking equipped sidearm on the warehouse page should persist it to save stash.")
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

	var stash_model: RefCounted = stash_panel.get("stash_model")
	if stash_model == null or not bool(stash_model.call("add_stack", LightArmorItem.to_stack(1))):
		_errors.append("Validation setup should add light armor to stash for double-click equip.")
	else:
		stash_panel.call("_save_stash")
		stash_panel.call("_refresh_display_items")
		await _wait_frames(1)
		var armor_state: Dictionary = stash_panel.call("get_display_state")
		var armor_items: Array = armor_state.get("stash_items", []) as Array
		var armor_index := _stack_index_with_resource(armor_items, LIGHT_ARMOR_PATH)
		if armor_index < 0:
			_errors.append("Validation setup should find light armor in the stash.")
		else:
			var armor_grid_rect: Rect2 = armor_state.get("stash_grid_rect", Rect2())
			var armor_click_position := _grid_slot_center(armor_grid_rect, armor_index, 5)
			_click_control(stash_panel as Control, armor_click_position)
			await _wait_frames(2)
			if not (equipment.call("get_slot", &"armor") as Dictionary).is_empty():
				_errors.append("Single-clicking stash armor should not auto-equip it.")
			if _stack_quantity((stash_panel.call("get_display_state").get("stash_items", []) as Array), LIGHT_ARMOR_PATH) != 1:
				_errors.append("Single-clicking stash armor should leave it in the warehouse.")
			_click_control(stash_panel as Control, armor_click_position, true)
			await _wait_frames(2)
			var equipped_armor: Dictionary = equipment.call("get_slot", &"armor")
			if str(equipped_armor.get("resource_path", "")) != LIGHT_ARMOR_PATH:
				_errors.append("Double-clicking stash armor with an empty armor slot should equip it.")
			if _stack_quantity((stash_panel.call("get_display_state").get("stash_items", []) as Array), LIGHT_ARMOR_PATH) != 0:
				_errors.append("Double-clicking equipped stash armor should remove it from the warehouse.")

	if equipment.call("is_empty", &"backpack") and not bool(equipment.call("equip_stack", &"backpack", SmallBackpackItem.to_stack(1))):
		_errors.append("Validation setup should fill the backpack equipment slot before fallback transfer.")
	if stash_model == null or not bool(stash_model.call("add_stack", SmallBackpackItem.to_stack(1))):
		_errors.append("Validation setup should add a second backpack to stash for full-slot fallback.")
	else:
		stash_panel.call("_save_stash")
		stash_panel.call("_refresh_display_items")
		await _wait_frames(1)
		var fallback_state: Dictionary = stash_panel.call("get_display_state")
		var fallback_items: Array = fallback_state.get("stash_items", []) as Array
		var fallback_index := _stack_index_with_resource(fallback_items, SMALL_BACKPACK_PATH)
		if fallback_index < 0:
			_errors.append("Validation setup should find second backpack in the stash.")
		else:
			var fallback_grid_rect: Rect2 = fallback_state.get("stash_grid_rect", Rect2())
			_click_control(stash_panel as Control, _grid_slot_center(fallback_grid_rect, fallback_index, 5), true)
			await _wait_frames(2)
			if _stack_quantity(inventory.get_display_items(), SMALL_BACKPACK_PATH) != 1:
				_errors.append("Double-clicking stash equipment with a full matching slot should move it to backpack.")
			if _stack_quantity((stash_panel.call("get_display_state").get("stash_items", []) as Array), SMALL_BACKPACK_PATH) != 0:
				_errors.append("Double-clicking fallback stash equipment should remove it from warehouse.")

	var state: Dictionary = stash_panel.call("get_display_state")
	var stash_items: Array = state.get("stash_items", []) as Array
	var stash_wood_index := _stack_index_with_resource(stash_items, WOOD_PATH)
	if stash_wood_index < 0:
		_errors.append("Validation setup should find wood in stash before double-click withdraw.")
	else:
		var stash_grid_rect: Rect2 = state.get("stash_grid_rect", Rect2())
		var wood_stash_position := _grid_slot_center(stash_grid_rect, stash_wood_index, 5)
		var wood_backpack_before := _stack_quantity(inventory.get_display_items(), WOOD_PATH)
		_click_control(stash_panel as Control, wood_stash_position)
		await _wait_frames(2)
		if _stack_quantity(inventory.get_display_items(), WOOD_PATH) != wood_backpack_before:
			_errors.append("Single-clicking a warehouse stack should not withdraw it to backpack.")
		_click_control(stash_panel as Control, wood_stash_position, true)
		await _wait_frames(2)
	if _stack_quantity(inventory.get_display_items(), WOOD_PATH) != stored_wood_quantity:
		_errors.append("Double-clicked stash item should enter the backpack.")
	var saved_after_withdraw: Dictionary = _save_manager.call("get_slot_data", 1)
	if _stack_quantity(saved_after_withdraw.get("stash", []) as Array, WOOD_PATH) != 0:
		_errors.append("Double-clicked stash item should be removed from save stash.")
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


func _validate_inventory_reference_hover_clears(stash_panel: Control, inventory_panel: Control) -> void:
	var inventory_state: Dictionary = inventory_panel.call("get_display_state")
	var equipment_rects: Dictionary = inventory_state.get("equipment_slot_rects", {})
	var sidearm_rect: Rect2 = equipment_rects.get("sidearm", Rect2())
	if sidearm_rect.size.x <= 0.0:
		_errors.append("Validation setup should expose sidearm rect for hover clearing.")
		return
	var hover_position := _control_local_point(stash_panel, inventory_panel, sidearm_rect.get_center())
	_send_mouse_motion(stash_panel, hover_position)
	await _wait_frames(1)
	var local_hover_position: Vector2 = inventory_panel.get("_last_mouse_position")
	var hover_tooltip: Dictionary = inventory_panel.call("get_hover_item_tooltip_for_position", local_hover_position)
	if hover_tooltip.is_empty():
		_errors.append("Validation setup should show an inventory tooltip before moving away.")
	_click_control(stash_panel, hover_position)
	await _wait_frames(1)
	var mod_state: Dictionary = inventory_panel.call("get_display_state")
	var mod_rect: Rect2 = mod_state.get("weapon_mod_panel_rect", Rect2())
	if mod_rect.size.x <= 0.0:
		_errors.append("Clicking an equipped weapon through the warehouse page should open the weapon mod panel.")
	else:
		var weapon_mod_panel: RefCounted = inventory_panel.get("_weapon_mod_panel")
		var before_scroll := int(weapon_mod_panel.get("detail_scroll_row"))
		_wheel_control(stash_panel, _control_local_point(stash_panel, inventory_panel, mod_rect.get_center()), MOUSE_BUTTON_WHEEL_DOWN)
		await _wait_frames(1)
		var after_scroll := int(weapon_mod_panel.get("detail_scroll_row"))
		if after_scroll <= before_scroll:
			_errors.append("Warehouse page wheel events over the weapon mod panel should scroll weapon details.")
		var empty_backpack_index := _first_empty_inventory_slot_index(inventory_panel)
		if empty_backpack_index < 0:
			_errors.append("Validation setup should expose an empty backpack slot while warehouse is open.")
		else:
			var empty_slot_position := _control_local_point(stash_panel, inventory_panel, _inventory_backpack_slot_center(inventory_panel, empty_backpack_index))
			_click_control(stash_panel, empty_slot_position)
			await _wait_frames(1)
			var closed_mod_state: Dictionary = inventory_panel.call("get_display_state")
			var closed_panel_state: Dictionary = closed_mod_state.get("weapon_mod_panel", {})
			if bool(closed_panel_state.get("has_weapon", false)):
				_errors.append("Clicking an empty backpack slot through the warehouse page should close the weapon mod panel.")
			_click_control(stash_panel, hover_position)
			await _wait_frames(1)
			var reopened_mod_state: Dictionary = inventory_panel.call("get_display_state")
			if not bool((reopened_mod_state.get("weapon_mod_panel", {}) as Dictionary).get("has_weapon", false)):
				_errors.append("Validation setup should reopen the weapon mod panel before testing empty warehouse slots.")
			else:
				var stash_state: Dictionary = stash_panel.call("get_display_state")
				var empty_stash_index := (stash_state.get("stash_items", []) as Array).size()
				var empty_stash_position := _grid_slot_center(stash_state.get("stash_grid_rect", Rect2()), empty_stash_index, 5)
				_click_control(stash_panel, empty_stash_position)
				await _wait_frames(1)
				var stash_closed_mod_state: Dictionary = inventory_panel.call("get_display_state")
				var stash_closed_panel_state: Dictionary = stash_closed_mod_state.get("weapon_mod_panel", {})
				if bool(stash_closed_panel_state.get("has_weapon", false)):
					_errors.append("Clicking an empty warehouse slot should close the weapon mod panel.")
	var away_position := hover_position + Vector2(sidearm_rect.size.x * 2.5, sidearm_rect.size.y * 3.0)
	_send_mouse_motion(stash_panel, away_position)
	await _wait_frames(1)
	var local_away_position: Vector2 = inventory_panel.get("_last_mouse_position")
	var away_tooltip: Dictionary = inventory_panel.call("get_hover_item_tooltip_for_position", local_away_position)
	if not away_tooltip.is_empty():
		_errors.append("Moving the mouse away on the warehouse page should clear the reused inventory tooltip.")


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


func _first_empty_inventory_slot_index(inventory_panel: Control) -> int:
	var state: Dictionary = inventory_panel.call("get_display_state")
	var used := (state.get("backpack_items", []) as Array).size()
	var slots := int(state.get("backpack_slots", 0))
	if used >= slots:
		return -1
	return used


func _inventory_backpack_slot_center(inventory_panel: Control, stack_index: int) -> Vector2:
	inventory_panel.call("_update_layout_scale", inventory_panel.size)
	var panel_rect: Rect2 = inventory_panel.call("_panel_rect")
	var layout: RefCounted = inventory_panel.get("_layout")
	var backpack_rect: Rect2 = layout.call("backpack_rect", panel_rect)
	var slot_rect: Rect2 = inventory_panel.call("_backpack_slot_rect", backpack_rect, stack_index)
	return slot_rect.get_center()


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


func _send_mouse_motion(control: Control, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	control.call("_gui_input", event)


func _wheel_control(control: Control, position: Vector2, button_index: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button_index
	event.pressed = true
	control.call("_gui_input", event)


func _drag_control(control: Control, start_position: Vector2, end_position: Vector2) -> void:
	var press_event := InputEventMouseButton.new()
	press_event.position = start_position
	press_event.global_position = start_position
	press_event.button_index = MOUSE_BUTTON_LEFT
	press_event.pressed = true
	control.call("_gui_input", press_event)
	var motion_event := InputEventMouseMotion.new()
	motion_event.position = end_position
	motion_event.global_position = end_position
	control.call("_gui_input", motion_event)
	var release_event := InputEventMouseButton.new()
	release_event.position = end_position
	release_event.global_position = end_position
	release_event.button_index = MOUSE_BUTTON_LEFT
	release_event.pressed = false
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
