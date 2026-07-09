extends SceneTree

const BaseScreenScene := preload("res://scenes/base/base_screen.tscn")
const Base3DScene := preload("res://scenes/base/base_3d.tscn")
const PlayerScene := preload("res://scenes/player/player_3d.tscn")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")
const WorkbenchUpgrade := preload("res://data/base_upgrades/workbench_level_1.tres")
const FixStationUpgrade := preload("res://data/base_upgrades/workbench_fix_station.tres")
const DisassembleStationUpgrade := preload("res://data/base_upgrades/workbench_disassemble_station.tres")
const StorageExpansionUpgrade1 := preload("res://data/base_upgrades/storage_expansion_level_1.tres")
const StorageExpansionUpgrade2 := preload("res://data/base_upgrades/storage_expansion_level_2.tres")
const BaseProgressionScript := preload("res://scripts/base/base_progression.gd")
const BaseNeededItemServiceScript := preload("res://scripts/base/base_needed_item_service.gd")

const WOOD_PATH := "res://data/items/crafting/wood.tres"
const WIRE_PATH := "res://data/items/electronics/wire.tres"
const JUNK_PATH := "res://data/items/loot/junk.tres"
const AMMO_PATH := "res://data/items/ammo/ammo_9mm.tres"
const MAGAZINE_PATH := "res://data/items/attachments/extended_magazine.tres"
const BLUEPRINT_PATH := "res://data/items/recipes/blueprint.tres"

var _errors: Array[String] = []
var _created_save_manager: Node = null


func _initialize() -> void:
	_validate_upgrade_def()
	_validate_storage_upgrade_def()
	_validate_fix_station_upgrade_def()
	_validate_disassemble_station_upgrade_def()
	_validate_workbench_needed_item_state()
	await _validate_insufficient_upgrade_state()
	await _validate_purchase_upgrade_and_save()
	_validate_fix_station_purchase_rules()
	_validate_disassemble_station_purchase_rules()
	await _validate_storage_capacity_upgrade_and_save()
	await _validate_base_3d_workbench_purchase()
	await _validate_base_3d_workbench_craft()
	await _validate_base_3d_workbench_fix_station()
	await _validate_base_3d_workbench_blueprint_research()
	await _validate_starter_ammo_bonus()
	if _errors.is_empty():
		print("[base_progression] OK upgrade=data_valid cost=deducted save=persists base3d=action mode=tabs recipe=keys selection=save craft=stash blueprint=research repair=fix_station dismantle=station effect=starter_ammo storage_capacity")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_upgrade_def() -> void:
	if WorkbenchUpgrade == null or not WorkbenchUpgrade.has_method("is_valid") or not WorkbenchUpgrade.is_valid():
		_errors.append("Workbench Level 1 UpgradeDef should load and validate.")
	if WorkbenchUpgrade.starter_ammo_bonus != 1:
		_errors.append("Workbench Level 1 should grant starter ammo +1.")
	if BaseProgressionScript.describe_cost(WorkbenchUpgrade) == "":
		_errors.append("Workbench Level 1 should expose readable cost text.")


func _validate_storage_upgrade_def() -> void:
	if StorageExpansionUpgrade1 == null or not StorageExpansionUpgrade1.has_method("is_valid") or not StorageExpansionUpgrade1.is_valid():
		_errors.append("Storage Expansion Level 1 UpgradeDef should load and validate.")
	if int(StorageExpansionUpgrade1.storage_capacity_bonus) != 35:
		_errors.append("Storage Expansion Level 1 should grant warehouse capacity +35.")
	if int(StorageExpansionUpgrade1.starter_ammo_bonus) != 0:
		_errors.append("Storage Expansion Level 1 should not affect combat starter ammo.")
	if StorageExpansionUpgrade2 == null or not StorageExpansionUpgrade2.has_method("is_valid") or not StorageExpansionUpgrade2.is_valid():
		_errors.append("Storage Expansion Level 2 UpgradeDef should load and validate.")
	if int(StorageExpansionUpgrade2.storage_capacity_bonus) != 35:
		_errors.append("Storage Expansion Level 2 should grant warehouse capacity +35.")
	if not StorageExpansionUpgrade2.item_costs.is_empty():
		_errors.append("Storage Expansion Level 2 should not require deleted item materials.")


func _validate_fix_station_upgrade_def() -> void:
	if FixStationUpgrade == null or not FixStationUpgrade.has_method("is_valid") or not FixStationUpgrade.is_valid():
		_errors.append("Fix Station UpgradeDef should load and validate.")
		return
	var required_ids: Array = FixStationUpgrade.required_upgrade_ids
	if not required_ids.has(WorkbenchUpgrade.id):
		_errors.append("Fix Station should require Workbench Level 1 as a prerequisite.")
	if not FixStationUpgrade.item_costs.is_empty():
		_errors.append("Fix Station should not require deleted tool items.")
	if int(FixStationUpgrade.starter_ammo_bonus) != 0 or int(FixStationUpgrade.storage_capacity_bonus) != 0:
		_errors.append("Fix Station should only unlock repair mode and not grant unrelated bonuses.")
	if BaseProgressionScript.describe_cost(FixStationUpgrade) == "":
		_errors.append("Fix Station should expose readable cost text.")


func _validate_disassemble_station_upgrade_def() -> void:
	if DisassembleStationUpgrade == null or not DisassembleStationUpgrade.has_method("is_valid") or not DisassembleStationUpgrade.is_valid():
		_errors.append("Disassemble Station UpgradeDef should load and validate.")
		return
	var required_ids: Array = DisassembleStationUpgrade.required_upgrade_ids
	if not required_ids.has(WorkbenchUpgrade.id):
		_errors.append("Disassemble Station should require Workbench Level 1 as a prerequisite.")
	if not DisassembleStationUpgrade.item_costs.is_empty():
		_errors.append("Disassemble Station should not require deleted tool items.")
	if int(DisassembleStationUpgrade.starter_ammo_bonus) != 0 or int(DisassembleStationUpgrade.storage_capacity_bonus) != 0:
		_errors.append("Disassemble Station should only unlock dismantle mode and not grant unrelated bonuses.")
	if BaseProgressionScript.describe_cost(DisassembleStationUpgrade) == "":
		_errors.append("Disassemble Station should expose readable cost text.")


func _validate_workbench_needed_item_state() -> void:
	var save_data := {
		"difficulty_id": "normal",
		"money": 0,
		"stash": [{"item_path": WOOD_PATH, "quantity": 1}],
		"base_upgrades": {},
		"quests": {},
	}
	var needed_state: Dictionary = BaseNeededItemServiceScript.get_state_from_save_data(save_data)
	var workbench_paths: Array = needed_state.get("workbench_item_paths", []) as Array
	if not workbench_paths.has(WOOD_PATH) or not workbench_paths.has(WIRE_PATH):
		_errors.append("Needed item service should mark missing unpurchased workbench materials.")
	var upgrade_paths: Array = needed_state.get("upgrade_item_paths", []) as Array
	if not upgrade_paths.has(WOOD_PATH) or not upgrade_paths.has(WIRE_PATH):
		_errors.append("Needed item service should include workbench materials in combined upgrade paths.")
	var purchasable := save_data.duplicate(true)
	purchasable["money"] = 25
	purchasable["stash"] = [
		{"item_path": WOOD_PATH, "quantity": 3},
		{"item_path": WIRE_PATH, "quantity": 2},
	]
	var result: Dictionary = BaseProgressionScript.purchase_upgrade(purchasable, WorkbenchUpgrade)
	var after_purchase: Dictionary = BaseNeededItemServiceScript.get_state_from_save_data(result.get("save_data", {}) as Dictionary)
	var after_workbench_paths: Array = after_purchase.get("workbench_item_paths", []) as Array
	if not after_workbench_paths.is_empty():
		_errors.append("Needed item service should not mark Fix Station item costs after Workbench Level 1 is purchased.")
	var recipe_paths: Array = after_purchase.get("recipe_item_paths", []) as Array
	if not recipe_paths.has(JUNK_PATH) or not recipe_paths.has(WIRE_PATH):
		_errors.append("Needed item service should mark missing unlocked recipe materials after the workbench upgrade is purchased.")
	var fix_ready: Dictionary = result.get("save_data", {}) as Dictionary
	fix_ready["money"] = 30
	fix_ready["stash"] = []
	var fix_result: Dictionary = BaseProgressionScript.purchase_upgrade(fix_ready, FixStationUpgrade)
	var after_fix: Dictionary = BaseNeededItemServiceScript.get_state_from_save_data(fix_result.get("save_data", {}) as Dictionary)
	var after_fix_paths: Array = after_fix.get("workbench_item_paths", []) as Array
	if not after_fix_paths.is_empty():
		_errors.append("Needed item service should not mark Disassemble Station item costs after Fix Station is installed.")
	var dismantle_ready: Dictionary = fix_result.get("save_data", {}) as Dictionary
	dismantle_ready["money"] = 30
	dismantle_ready["stash"] = []
	var dismantle_result: Dictionary = BaseProgressionScript.purchase_upgrade(dismantle_ready, DisassembleStationUpgrade)
	var after_dismantle: Dictionary = BaseNeededItemServiceScript.get_state_from_save_data(dismantle_result.get("save_data", {}) as Dictionary)
	if not (after_dismantle.get("workbench_item_paths", []) as Array).is_empty():
		_errors.append("Needed item service should clear workbench upgrade material marks after Disassemble Station is installed.")


func _validate_fix_station_purchase_rules() -> void:
	var no_prerequisite := {
		"difficulty_id": "normal",
		"money": 40,
		"stash": [],
		"base_upgrades": {},
		"quests": {},
	}
	var blocked_prerequisite: Dictionary = BaseProgressionScript.can_purchase_upgrade(no_prerequisite, FixStationUpgrade)
	if bool(blocked_prerequisite.get("can_purchase", false)) or str(blocked_prerequisite.get("reason", "")) != "missing_prerequisite":
		_errors.append("Fix Station should be blocked until Workbench Level 1 is purchased.")

	var purchasable := no_prerequisite.duplicate(true)
	purchasable["base_upgrades"] = {str(WorkbenchUpgrade.id): {"purchased": true}}
	var result: Dictionary = BaseProgressionScript.purchase_upgrade(purchasable, FixStationUpgrade)
	if not bool(result.get("success", false)):
		_errors.append("Fix Station should purchase when prerequisite and money are available.")
		return
	var updated: Dictionary = result.get("save_data", {}) as Dictionary
	if not BaseProgressionScript.is_upgrade_purchased(updated, FixStationUpgrade.id):
		_errors.append("Fix Station purchase should persist in base_upgrades.")
	if int(updated.get("money", 0)) != 20:
		_errors.append("Fix Station should deduct its money cost from save data.")
	if not (updated.get("stash", []) as Array).is_empty():
		_errors.append("Fix Station purchase should not require or consume tool items.")
	var purchased_entry: Dictionary = (updated.get("base_upgrades", {}) as Dictionary).get(str(FixStationUpgrade.id), {}) as Dictionary
	if not (purchased_entry.get("required_upgrade_ids", []) as Array).has(str(WorkbenchUpgrade.id)):
		_errors.append("Fix Station purchase should record prerequisite ids for save inspection.")


func _validate_disassemble_station_purchase_rules() -> void:
	var no_prerequisite := {
		"difficulty_id": "normal",
		"money": 40,
		"stash": [],
		"base_upgrades": {},
		"quests": {},
	}
	var blocked_prerequisite: Dictionary = BaseProgressionScript.can_purchase_upgrade(no_prerequisite, DisassembleStationUpgrade)
	if bool(blocked_prerequisite.get("can_purchase", false)) or str(blocked_prerequisite.get("reason", "")) != "missing_prerequisite":
		_errors.append("Disassemble Station should be blocked until Workbench Level 1 is purchased.")
	var purchasable := no_prerequisite.duplicate(true)
	purchasable["base_upgrades"] = {str(WorkbenchUpgrade.id): {"purchased": true}}
	var result: Dictionary = BaseProgressionScript.purchase_upgrade(purchasable, DisassembleStationUpgrade)
	if not bool(result.get("success", false)):
		_errors.append("Disassemble Station should purchase when prerequisite and money are available.")
		return
	var updated: Dictionary = result.get("save_data", {}) as Dictionary
	if not BaseProgressionScript.is_upgrade_purchased(updated, DisassembleStationUpgrade.id):
		_errors.append("Disassemble Station purchase should persist in base_upgrades.")
	if int(updated.get("money", 0)) != 20:
		_errors.append("Disassemble Station should deduct its money cost from save data.")
	if not (updated.get("stash", []) as Array).is_empty():
		_errors.append("Disassemble Station purchase should not require or consume tool items.")
	var purchased_entry: Dictionary = (updated.get("base_upgrades", {}) as Dictionary).get(str(DisassembleStationUpgrade.id), {}) as Dictionary
	if not (purchased_entry.get("required_upgrade_ids", []) as Array).has(str(WorkbenchUpgrade.id)):
		_errors.append("Disassemble Station purchase should record prerequisite ids for save inspection.")


func _validate_insufficient_upgrade_state() -> void:
	var save_manager := _make_save_manager()
	_cleanup_validation_root(save_manager.save_root_path)
	save_manager.set_current_slot_index(1)
	save_manager.save_slot_data(1, {
		"difficulty_id": "normal",
		"money": 0,
		"stash": [{"item_path": WOOD_PATH, "quantity": 1}],
		"base_upgrades": {},
		"quests": {},
	})
	var screen: BaseScreen = _make_screen()
	await process_frame
	screen.refresh()
	var state: Dictionary = screen.get_display_state()
	if not bool(state.get("upgrade_workbench_disabled", false)):
		_errors.append("Workbench upgrade button should be disabled when costs are missing.")
	if str(state.get("workbench_status", "")) == "":
		_errors.append("Workbench upgrade should show a clear blocked status.")
	_free_node(screen)
	_cleanup_validation_root(save_manager.save_root_path)


func _validate_purchase_upgrade_and_save() -> void:
	var save_manager := _make_save_manager()
	_cleanup_validation_root(save_manager.save_root_path)
	save_manager.set_current_slot_index(1)
	save_manager.save_slot_data(1, {
		"difficulty_id": "normal",
		"money": 25,
		"stash": [
			{"item_path": WOOD_PATH, "quantity": 4},
			{"item_path": WIRE_PATH, "quantity": 2},
		],
		"base_upgrades": {},
		"quests": {},
	})
	var screen: BaseScreen = _make_screen()
	await process_frame
	screen.refresh()
	var before_state: Dictionary = screen.get_display_state()
	if bool(before_state.get("upgrade_workbench_disabled", true)):
		_errors.append("Workbench upgrade button should be enabled when costs are available.")

	var result: Dictionary = screen.upgrade_workbench()
	if not bool(result.get("success", false)):
		_errors.append("BaseScreen should purchase Workbench Level 1 when costs are available.")
	var loaded: Dictionary = save_manager.get_slot_data(1)
	if int(loaded.get("money", 0)) != 10:
		_errors.append("Workbench upgrade should deduct money cost from save data.")
	if _stash_quantity(loaded, WOOD_PATH) != 1 or _stash_quantity(loaded, WIRE_PATH) != 0:
		_errors.append("Workbench upgrade should consume required material stacks and leave only excess materials.")
	if not BaseProgressionScript.is_upgrade_purchased(loaded, WorkbenchUpgrade.id):
		_errors.append("Workbench upgrade purchase should persist in base_upgrades.")
	if BaseProgressionScript.get_starter_ammo_bonus(loaded) != 1:
		_errors.append("Workbench upgrade should persist starter ammo bonus.")

	var after_state: Dictionary = screen.get_display_state()
	if not bool(after_state.get("upgrade_workbench_disabled", false)):
		_errors.append("Workbench upgrade button should disable after purchase.")
	if not (
		str(after_state.get("workbench_status", "")).contains("備用彈藥")
	):
		_errors.append("Workbench status should explain the starter ammo effect after purchase.")
	_free_node(screen)


func _validate_storage_capacity_upgrade_and_save() -> void:
	var save_manager := _make_save_manager()
	_cleanup_validation_root(save_manager.save_root_path)
	save_manager.set_current_slot_index(1)
	save_manager.save_slot_data(1, {
		"difficulty_id": "normal",
		"money": 25,
		"stash": [],
		"base_upgrades": {},
		"quests": {},
	})
	var save_data: Dictionary = save_manager.get_slot_data(1)
	var result: Dictionary = BaseProgressionScript.purchase_upgrade(save_data, StorageExpansionUpgrade1)
	if not bool(result.get("success", false)):
		_errors.append("Storage Expansion Level 1 should be purchasable through BaseProgression.")
	else:
		if not bool(save_manager.save_slot_data(1, result.get("save_data", {}) as Dictionary)):
			_errors.append("Storage Expansion Level 1 purchase should save through SaveGameManager.")
		var loaded: Dictionary = save_manager.get_slot_data(1)
		if int(loaded.get("money", 0)) != 5:
			_errors.append("Storage Expansion Level 1 should deduct its money cost from save data.")
		if not BaseProgressionScript.is_upgrade_purchased(loaded, StorageExpansionUpgrade1.id):
			_errors.append("Storage Expansion Level 1 purchase should persist in base_upgrades.")
		if BaseProgressionScript.get_storage_capacity_bonus(loaded) != 35:
			_errors.append("Purchased storage expansion should persist warehouse capacity bonus.")
		if BaseProgressionScript.get_stash_capacity(loaded, 250) != 285:
			_errors.append("BaseProgression should calculate save-backed warehouse capacity.")
		loaded["money"] = 60
		var ready_second: Dictionary = BaseProgressionScript.can_purchase_upgrade(loaded, StorageExpansionUpgrade2)
		if not bool(ready_second.get("can_purchase", false)):
			_errors.append("Storage Expansion Level 2 should be purchasable with money only.")
		var second_result: Dictionary = BaseProgressionScript.purchase_upgrade(loaded, StorageExpansionUpgrade2)
		if not bool(second_result.get("success", false)):
			_errors.append("Storage Expansion Level 2 should purchase when money is available.")
		else:
			var after_second: Dictionary = second_result.get("save_data", {}) as Dictionary
			if BaseProgressionScript.get_stash_capacity(after_second, 250) != 320:
				_errors.append("Two storage expansions should calculate capacity 320.")
			if not (after_second.get("stash", []) as Array).is_empty():
				_errors.append("Storage Expansion Level 2 should not require or consume item materials.")
	_free_created_save_manager()
	_cleanup_validation_root(save_manager.save_root_path)


func _validate_base_3d_workbench_purchase() -> void:
	var save_manager := _make_save_manager()
	_cleanup_validation_root(save_manager.save_root_path)
	save_manager.set_current_slot_index(1)
	save_manager.save_slot_data(1, {
		"difficulty_id": "normal",
		"money": 25,
		"stash": [
			{"item_path": WOOD_PATH, "quantity": 3},
			{"item_path": WIRE_PATH, "quantity": 2},
		],
		"base_upgrades": {},
		"quests": {},
	})
	var scene := Base3DScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var controller := scene.get_node_or_null("BaseInteractionController3D")
	if controller == null:
		_errors.append("Base 3D should expose BaseInteractionController3D for workbench upgrade validation.")
		_free_node(scene)
		return
	if not bool(controller.call("open_interaction_by_id", "workbench")):
		_errors.append("Base 3D workbench should open an upgrade interaction panel.")
	else:
		var state: Dictionary = controller.call("get_panel_state")
		if not bool(state.get("action_visible", false)) or not bool(state.get("action_enabled", false)):
			_errors.append("Base 3D workbench upgrade action should be visible and enabled when costs are available.")
		if bool(state.get("mode_tabs_visible", false)) or int(state.get("mode_button_count", 0)) != 0:
			_errors.append("Unupgraded workbench should not show craft/repair/dismantle station modes yet.")
		if not str(state.get("body", "")).contains("備用彈藥") or not str(state.get("body", "")).contains("需求"):
			_errors.append("Base 3D workbench panel should explain the upgrade effect and cost.")
		var panel := scene.get_node_or_null("HUD/BaseInteractionPanel")
		if panel != null and panel.has_signal("action_requested"):
			panel.emit_signal("action_requested", "workbench")
			await process_frame
		var loaded: Dictionary = save_manager.get_slot_data(1)
		if not BaseProgressionScript.is_upgrade_purchased(loaded, WorkbenchUpgrade.id):
			_errors.append("Base 3D workbench action should persist Workbench Level 1.")
		if int(loaded.get("money", 0)) != 10:
			_errors.append("Base 3D workbench action should deduct money cost.")
		if _stash_quantity(loaded, WOOD_PATH) != 0 or _stash_quantity(loaded, WIRE_PATH) != 0:
			_errors.append("Base 3D workbench action should consume required wood and wire.")
		var after_state: Dictionary = controller.call("get_panel_state")
		if not str(after_state.get("body", "")).contains("升級完成") or not str(after_state.get("body", "")).contains("已升級"):
			_errors.append("Base 3D workbench panel should show a visible completed upgrade state.")
	_free_node(scene)
	_cleanup_validation_root(save_manager.save_root_path)


func _validate_base_3d_workbench_craft() -> void:
	var save_manager := _make_save_manager()
	_cleanup_validation_root(save_manager.save_root_path)
	save_manager.set_current_slot_index(1)
	save_manager.save_slot_data(1, {
		"difficulty_id": "normal",
		"money": 10,
		"stash": [
			{"item_path": JUNK_PATH, "quantity": 4},
			{"item_path": WIRE_PATH, "quantity": 2},
		],
		"base_upgrades": {
			str(WorkbenchUpgrade.id): {"purchased": true},
		},
		"quests": {},
	})
	var scene := Base3DScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var controller := scene.get_node_or_null("BaseInteractionController3D")
	if controller == null:
		_errors.append("Base 3D should expose BaseInteractionController3D for workbench craft validation.")
		_free_node(scene)
		return
	if not bool(controller.call("open_interaction_by_id", "workbench")):
		_errors.append("Base 3D workbench should open before crafting.")
	else:
		var state: Dictionary = controller.call("get_panel_state")
		if not bool(state.get("action_visible", false)) or not bool(state.get("action_enabled", false)):
			_errors.append("Upgraded workbench should expose an enabled craft action when recipe materials are available.")
		if str(state.get("action_mode", "")) != "craft":
			_errors.append("Upgraded workbench panel should expose craft action mode.")
		if str(state.get("selected_recipe_id", "")) != "workbench_ammo_9mm":
			_errors.append("Upgraded workbench panel should select the craftable ammo recipe by default.")
		var recipe_rows: Array = state.get("recipe_rows", []) as Array
		if recipe_rows.size() < 2:
			_errors.append("Upgraded workbench panel should expose a recipe list for UI selection.")
		if not bool(state.get("recipe_list_visible", false)) or int(state.get("recipe_button_count", 0)) < 2:
			_errors.append("Upgraded workbench panel should render recipe selection buttons.")
		if not str(state.get("body", "")).contains(TranslationServer.translate("ui.base.workbench.recipe_ready")):
			_errors.append("Workbench panel should explain when recipe materials are ready.")
		if not str(state.get("body", "")).contains(TranslationServer.translate("ui.base.workbench.recipe_list_title")):
			_errors.append("Workbench panel should show a readable recipe list heading.")
		if str(state.get("selected_station_mode", "")) != "craft":
			_errors.append("Upgraded workbench should select the craft station mode.")
		if not bool(state.get("mode_tabs_visible", false)) or int(state.get("mode_button_count", 0)) != 4:
			_errors.append("Upgraded workbench should render craft, blueprint, repair, and dismantle mode tabs.")
		if not _mode_button_selected(state, "craft"):
			_errors.append("Workbench station mode tabs should mark Craft as selected.")
		if _mode_button_disabled(state, "blueprints") or _mode_button_disabled(state, "repair") or _mode_button_disabled(state, "dismantle"):
			_errors.append("Workbench station mode tabs should expose Blueprints, Repair, and Dismantle after Workbench Level 1.")
		var panel := scene.get_node_or_null("HUD/BaseInteractionPanel")
		if _recipe_button(panel, "workbench_ammo_9mm_polished") == null:
			_errors.append("Workbench recipe list should include a polished low-wear ammo selection row.")
		if _recipe_button(panel, "workbench_extended_magazine") == null:
			_errors.append("Workbench recipe list should include an extended magazine selection row.")
		if int(state.get("selected_recipe_button_index", -1)) != 0:
			_errors.append("Workbench recipe list should mark the default recipe row as the first selected row.")
		if panel == null or not panel.has_method("select_next_recipe") or not panel.has_method("select_previous_recipe"):
			_errors.append("Workbench recipe list should expose keyboard/controller selection methods.")
		else:
			if not bool(panel.call("select_next_recipe")):
				_errors.append("Workbench recipe list should select the next recipe through keyboard/controller navigation.")
			await process_frame
			var selected_save: Dictionary = save_manager.get_slot_data(1)
			if str((selected_save.get("selected_recipe_ids", {}) as Dictionary).get("workbench", "")) != "workbench_ammo_9mm_polished":
				_errors.append("Selecting the next Workbench recipe should persist the selected recipe id.")
			var selected_state: Dictionary = controller.call("get_panel_state")
			if str(selected_state.get("selected_recipe_id", "")) != "workbench_ammo_9mm_polished":
				_errors.append("Workbench panel should refresh to the selected recipe after keyboard/controller navigation.")
			if int(selected_state.get("selected_recipe_button_index", -1)) != 1:
				_errors.append("Workbench panel should mark the second recipe row as selected after moving down.")
			if not _recipe_button_selected(selected_state, "workbench_ammo_9mm_polished"):
				_errors.append("Workbench panel display state should mark the navigated recipe as selected.")
			if not bool(panel.call("select_previous_recipe")):
				_errors.append("Workbench recipe list should select the previous recipe through keyboard/controller navigation.")
			await process_frame
			var previous_state: Dictionary = controller.call("get_panel_state")
			if str(previous_state.get("selected_recipe_id", "")) != "workbench_ammo_9mm":
				_errors.append("Workbench panel should return to the default ammo recipe after moving up.")
			if int(previous_state.get("selected_recipe_button_index", -1)) != 0:
				_errors.append("Workbench panel should mark the first recipe row as selected after moving up.")
			if not bool(panel.call("select_next_recipe")):
				_errors.append("Workbench recipe list should reselect the polished ammo recipe before crafting.")
			await process_frame
			if not bool(panel.call("select_next_recipe")):
				_errors.append("Workbench recipe list should select the extended magazine recipe before crafting.")
			await process_frame
		if panel != null and panel.has_signal("action_requested"):
			panel.emit_signal("action_requested", "workbench")
			await process_frame
		var loaded: Dictionary = save_manager.get_slot_data(1)
		if _stash_quantity(loaded, JUNK_PATH) != 0 or _stash_quantity(loaded, WIRE_PATH) != 0:
			_errors.append("Workbench craft action should consume recipe ingredients.")
		if _stash_quantity(loaded, MAGAZINE_PATH) != 1:
			_errors.append("Workbench craft action should save the selected recipe output.")
		var after_state: Dictionary = controller.call("get_panel_state")
		if not str(after_state.get("body", "")).contains(TranslationServer.translate("ui.base.workbench_craft_done")):
			_errors.append("Workbench panel should report a completed craft action.")
		if bool(after_state.get("action_enabled", true)):
			_errors.append("Workbench craft action should disable after materials are consumed.")
	_free_node(scene)
	_cleanup_validation_root(save_manager.save_root_path)


func _validate_base_3d_workbench_fix_station() -> void:
	var save_manager := _make_save_manager()
	_cleanup_validation_root(save_manager.save_root_path)
	save_manager.set_current_slot_index(1)
	save_manager.save_slot_data(1, {
		"difficulty_id": "normal",
		"money": 30,
		"stash": [],
		"base_upgrades": {
			str(WorkbenchUpgrade.id): {"purchased": true},
		},
		"quests": {},
	})
	var scene := Base3DScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var controller := scene.get_node_or_null("BaseInteractionController3D")
	if controller == null:
		_errors.append("Base 3D should expose BaseInteractionController3D for Fix Station validation.")
		_free_node(scene)
		return
	if not bool(controller.call("open_interaction_by_id", "workbench")):
		_errors.append("Base 3D workbench should open before installing Fix Station.")
	else:
		var panel := scene.get_node_or_null("HUD/BaseInteractionPanel")
		var repair_button := _mode_button(panel, "repair")
		if repair_button == null:
			_errors.append("Workbench mode tabs should render a Repair button for Fix Station installation.")
		elif repair_button.disabled:
			_errors.append("Repair tab should be selectable after Workbench Level 1 so Fix Station can be installed.")
		else:
			repair_button.pressed.emit()
			await process_frame
		var install_state: Dictionary = controller.call("get_panel_state")
		if str(install_state.get("selected_station_mode", "")) != "repair":
			_errors.append("Clicking Repair should switch the workbench panel to repair station mode.")
		if str(install_state.get("action_mode", "")) != "fix_station_upgrade":
			_errors.append("Uninstalled Repair tab should expose Fix Station installation action mode.")
		if not bool(install_state.get("action_enabled", false)):
			_errors.append("Fix Station installation action should enable when money is available.")
		if not str(install_state.get("body", "")).contains(TranslationServer.translate("base_upgrade.workbench_fix_station.name")):
			_errors.append("Fix Station install panel should show the localized station name.")
		if panel != null and panel.has_signal("action_requested"):
			panel.emit_signal("action_requested", "workbench")
			await process_frame
		var loaded: Dictionary = save_manager.get_slot_data(1)
		if not BaseProgressionScript.is_upgrade_purchased(loaded, FixStationUpgrade.id):
			_errors.append("Base 3D Fix Station action should persist the installed station.")
		if int(loaded.get("money", 0)) != 10:
			_errors.append("Base 3D Fix Station action should deduct money cost.")
		if not (loaded.get("stash", []) as Array).is_empty():
			_errors.append("Base 3D Fix Station action should not require or consume tool items.")
		var repair_state: Dictionary = controller.call("get_panel_state")
		if str(repair_state.get("action_mode", "")) != "repair":
			_errors.append("Installed Fix Station should switch Repair tab into repair action mode.")
		if bool(repair_state.get("action_enabled", true)):
			_errors.append("Repair action should stay disabled until repairable gear execution is implemented.")
		if not str(repair_state.get("body", "")).contains(TranslationServer.translate("ui.base.workbench.repair_none")):
			_errors.append("Installed Fix Station repair panel should show an empty repairable gear state.")
	_free_node(scene)
	_cleanup_validation_root(save_manager.save_root_path)


func _validate_base_3d_workbench_blueprint_research() -> void:
	var save_manager := _make_save_manager()
	_cleanup_validation_root(save_manager.save_root_path)
	save_manager.set_current_slot_index(1)
	save_manager.save_slot_data(1, {
		"difficulty_id": "normal",
		"money": 10,
		"stash": [
			{"item_path": BLUEPRINT_PATH, "quantity": 1},
			{"item_path": JUNK_PATH, "quantity": 3},
		],
		"base_upgrades": {
			str(WorkbenchUpgrade.id): {"purchased": true},
		},
		"quests": {},
		"researched_blueprints": {},
	})
	var scene := Base3DScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var controller := scene.get_node_or_null("BaseInteractionController3D")
	if controller == null:
		_errors.append("Base 3D should expose BaseInteractionController3D for workbench blueprint validation.")
		_free_node(scene)
		return
	if not bool(controller.call("open_interaction_by_id", "workbench")):
		_errors.append("Base 3D workbench should open before blueprint research.")
	else:
		var state: Dictionary = controller.call("get_panel_state")
		if str(state.get("selected_station_mode", "")) != "craft":
			_errors.append("Workbench should start blueprint-capable sessions in Craft mode.")
		if _mode_button_disabled(state, "blueprints"):
			_errors.append("Workbench should allow switching to Blueprint Research after it is upgraded.")
		var panel := scene.get_node_or_null("HUD/BaseInteractionPanel")
		var blueprints_button := _mode_button(panel, "blueprints")
		if blueprints_button == null:
			_errors.append("Workbench mode tabs should render a clickable Blueprints button.")
		else:
			blueprints_button.pressed.emit()
			await process_frame
		var blueprint_state: Dictionary = controller.call("get_panel_state")
		if str(blueprint_state.get("selected_station_mode", "")) != "blueprints":
			_errors.append("Clicking the Blueprints tab should switch the workbench panel mode.")
		if str(blueprint_state.get("action_mode", "")) != "blueprint_research":
			_errors.append("Blueprints tab should expose blueprint_research action mode.")
		if not bool(blueprint_state.get("action_enabled", false)):
			_errors.append("Blueprint research action should enable when a blueprint is in stash.")
		if not str(blueprint_state.get("body", "")).contains(TranslationServer.translate("ui.base.workbench.blueprint_list_title")):
			_errors.append("Blueprints tab should show a readable blueprint list heading.")
		if int(blueprint_state.get("blueprint_button_count", 0)) < 1 or not _blueprint_button_researchable(blueprint_state, BLUEPRINT_PATH):
			_errors.append("Blueprints tab should render a researchable blueprint row.")
		if panel != null and panel.has_signal("action_requested"):
			panel.emit_signal("action_requested", "workbench")
			await process_frame
		var loaded: Dictionary = save_manager.get_slot_data(1)
		var researched := loaded.get("researched_blueprints", {}) as Dictionary
		if not bool(researched.get(BLUEPRINT_PATH, false)):
			_errors.append("Workbench blueprint research should persist the researched blueprint.")
		if _stash_quantity(loaded, BLUEPRINT_PATH) != 0:
			_errors.append("Workbench blueprint research should consume one blueprint item from stash.")
		var researched_state: Dictionary = controller.call("get_panel_state")
		if not str(researched_state.get("body", "")).contains(TranslationServer.translate("ui.base.workbench_blueprint_research_done")):
			_errors.append("Workbench panel should report completed blueprint research.")
		if bool(researched_state.get("action_enabled", true)):
			_errors.append("Blueprint research action should disable after the available blueprint is researched.")
		var craft_button := _mode_button(panel, "craft")
		if craft_button != null:
			craft_button.pressed.emit()
			await process_frame
		var craft_state: Dictionary = controller.call("get_panel_state")
		if not _recipe_row_visible(craft_state, "workbench_reclaimed_wire"):
			_errors.append("Researching a blueprint should unlock its workbench recipe row.")
	_free_node(scene)
	_cleanup_validation_root(save_manager.save_root_path)


func _validate_starter_ammo_bonus() -> void:
	var save_manager := _make_save_manager()
	_cleanup_validation_root(save_manager.save_root_path)
	save_manager.set_current_slot_index(1)
	save_manager.save_slot_data(1, {
		"difficulty_id": "normal",
		"money": 10,
		"stash": [],
		"base_upgrades": {
			str(WorkbenchUpgrade.id): {
				"purchased": true,
				"starter_ammo_bonus": int(WorkbenchUpgrade.starter_ammo_bonus),
			},
		},
		"quests": {},
	})
	var player := PlayerScene.instantiate()
	root.add_child(player)
	await process_frame
	var weapon := player.get_node_or_null("WeaponController3D")
	if weapon == null:
		_errors.append("Player scene should include WeaponController3D for upgrade effect validation.")
	else:
		if int(weapon.get("reserve_ammo")) != 1:
			_errors.append("Purchased Workbench Level 1 should add +1 reserve ammo to the next raid without restoring the removed starter ammo pile.")
	_free_node(player)
	_cleanup_validation_root(save_manager.save_root_path)
	_free_created_save_manager()


func _make_save_manager() -> Node:
	var existing := root.get_node_or_null("SaveGameManager")
	if existing != null:
		existing.save_root_path = "user://validation_base_progression"
		return existing
	var save_manager := SaveGameManagerScript.new()
	save_manager.name = "SaveGameManager"
	save_manager.save_root_path = "user://validation_base_progression"
	root.add_child(save_manager)
	_created_save_manager = save_manager
	return save_manager


func _make_screen() -> BaseScreen:
	var screen := BaseScreenScene.instantiate()
	root.add_child(screen)
	return screen


func _cleanup_validation_root(root_path: String) -> void:
	var absolute := ProjectSettings.globalize_path(root_path)
	if DirAccess.dir_exists_absolute(absolute):
		DirAccess.remove_absolute("%s/slot_1.json" % absolute)
		DirAccess.remove_absolute("%s/slot_2.json" % absolute)
		DirAccess.remove_absolute("%s/slot_3.json" % absolute)
		DirAccess.remove_absolute(absolute)


func _stash_quantity(save_data: Dictionary, item_path: String) -> int:
	var total := 0
	var stash: Array = save_data.get("stash", []) as Array
	for entry in stash:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str((entry as Dictionary).get("item_path", "")) == item_path:
			total += int((entry as Dictionary).get("quantity", 0))
	return total


func _upgrade_cost(upgrade_def: Resource, item_path: String) -> int:
	if upgrade_def == null:
		return 0
	var item_costs: Array = upgrade_def.get("item_costs")
	for cost in item_costs:
		if str(cost.get("item_path", "")) == item_path:
			return int(cost.get("quantity", 0))
	return 0


func _recipe_button(panel: Node, recipe_id: String) -> Button:
	if panel == null:
		return null
	var recipe_list := panel.get_node_or_null("Panel/Margin/Content/RecipeScroll/RecipeList")
	if recipe_list == null:
		return null
	for child in recipe_list.get_children():
		var button := child as Button
		if button != null and str(button.get_meta("recipe_id", "")) == recipe_id:
			return button
	return null


func _mode_button(panel: Node, mode_id: String) -> Button:
	if panel == null:
		return null
	var mode_tabs := panel.get_node_or_null("Panel/Margin/Content/ModeTabs")
	if mode_tabs == null:
		return null
	for child in mode_tabs.get_children():
		var button := child as Button
		if button != null and str(button.get_meta("mode_id", "")) == mode_id:
			return button
	return null


func _recipe_button_selected(panel_state: Dictionary, recipe_id: String) -> bool:
	var buttons: Array = panel_state.get("recipe_buttons", []) as Array
	for value in buttons:
		if typeof(value) == TYPE_DICTIONARY:
			var button := value as Dictionary
			if str(button.get("recipe_id", "")) == recipe_id:
				return bool(button.get("selected", false))
	return false


func _recipe_row_visible(panel_state: Dictionary, recipe_id: String) -> bool:
	var rows: Array = panel_state.get("recipe_rows", []) as Array
	for value in rows:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("id", "")) == recipe_id:
			return true
	return false


func _blueprint_button_researchable(panel_state: Dictionary, blueprint_item_path: String) -> bool:
	var buttons: Array = panel_state.get("blueprint_buttons", []) as Array
	for value in buttons:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var button := value as Dictionary
		if str(button.get("blueprint_item_path", "")) == blueprint_item_path:
			return bool(button.get("can_research", false)) and not bool(button.get("disabled", true))
	return false


func _mode_button_selected(panel_state: Dictionary, mode_id: String) -> bool:
	var buttons: Array = panel_state.get("mode_buttons", []) as Array
	for value in buttons:
		if typeof(value) == TYPE_DICTIONARY:
			var button := value as Dictionary
			if str(button.get("mode_id", "")) == mode_id:
				return bool(button.get("selected", false))
	return false


func _mode_button_disabled(panel_state: Dictionary, mode_id: String) -> bool:
	var buttons: Array = panel_state.get("mode_buttons", []) as Array
	for value in buttons:
		if typeof(value) == TYPE_DICTIONARY:
			var button := value as Dictionary
			if str(button.get("mode_id", "")) == mode_id:
				return bool(button.get("disabled", false))
	return false


func _free_created_save_manager() -> void:
	if _created_save_manager != null:
		_free_node(_created_save_manager)
		_created_save_manager = null


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
