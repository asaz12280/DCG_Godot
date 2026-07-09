extends SceneTree

const Base3DScene := preload("res://scenes/base/base_3d.tscn")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")
const BaseRepairServiceScript := preload("res://scripts/base/base_repair_service.gd")
const BaseProgressionScript := preload("res://scripts/base/base_progression.gd")
const StashModelScript := preload("res://scripts/base/stash_model.gd")
const WorkbenchUpgrade := preload("res://data/base_upgrades/workbench_level_1.tres")
const FixStationUpgrade := preload("res://data/base_upgrades/workbench_fix_station.tres")

const PISTOL_PATH := "res://data/items/weapons/pistol_9mm.tres"

var _errors: Array[String] = []
var _created_save_manager: Node = null


class FakeRepairPlayer:
	extends Node3D

	var inventory_model := InventoryModel.new()
	var safe_pocket_model := InventoryModel.new()
	var equipment_model := EquipmentModel.new()

	func _init() -> void:
		inventory_model.setup(12)
		safe_pocket_model.setup(2)

	func get_inventory_model() -> InventoryModel:
		return inventory_model

	func get_safe_pocket_model() -> InventoryModel:
		return safe_pocket_model

	func get_equipment_model() -> RefCounted:
		return equipment_model


func _initialize() -> void:
	_validate_service_locked_state()
	_validate_repair_rows_and_save_data()
	_validate_carried_repair_rows_and_models()
	_validate_missing_money_blocks_repair()
	_validate_stash_model_durability_round_trip()
	await _validate_base_3d_workbench_repair_flow()
	await _validate_base_3d_workbench_carried_repair_flow()
	if _errors.is_empty():
		print("[base_repair_service] OK gate=fix_station rows=stash/carried durability cost=money save=round_trip base3d=repair")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_service_locked_state() -> void:
	var save_data := _save_data(50, _damaged_pistol_stack(), false)
	var state: Dictionary = BaseRepairServiceScript.get_state_from_save_data(save_data)
	if bool(state.get("repair_unlocked", true)):
		_errors.append("Repair service should stay locked before Fix Station is purchased.")
	if not (state.get("repair_rows", []) as Array).is_empty():
		_errors.append("Repair service should not expose rows before Fix Station is purchased.")
	var result: Dictionary = BaseRepairServiceScript.repair_from_save_data(save_data, &"stash:0:pistol_9mm")
	if bool(result.get("success", false)) or str(result.get("reason", "")) != "repair_locked":
		_errors.append("Repair execution should be blocked before Fix Station is purchased.")


func _validate_repair_rows_and_save_data() -> void:
	var save_data := _save_data(50, _damaged_pistol_stack(), true)
	var state: Dictionary = BaseRepairServiceScript.get_state_from_save_data(save_data)
	if not bool(state.get("repair_unlocked", false)):
		_errors.append("Repair service should unlock after Fix Station is purchased.")
	var rows: Array = state.get("repair_rows", []) as Array
	if rows.size() != 1:
		_errors.append("Repair service should expose one damaged stash gear row.")
		return
	var row: Dictionary = rows[0]
	if str(row.get("item_path", "")) != PISTOL_PATH:
		_errors.append("Repair row should point at the damaged pistol stack.")
	if str(row.get("source_label_key", "")) != "ui.base.workbench.repair_source_stash" or str(row.get("source_label", "")) == "":
		_errors.append("Repair row should expose a localized stash source label.")
	if int(row.get("current_durability", 0)) != 42 or int(row.get("max_durability", 0)) != 88:
		_errors.append("Repair row should preserve save-backed current/max durability.")
	if int(row.get("max_after_repair", 0)) != 83:
		_errors.append("Repair row should preview max durability loss after repair.")
	if int(row.get("repair_cost", 0)) <= 0:
		_errors.append("Repair row should expose a positive money cost.")
	if str(state.get("selected_repair_id", "")) != str(row.get("id", "")):
		_errors.append("Repair service should select the first available repair row by default.")
	var selected_result: Dictionary = BaseRepairServiceScript.select_repair_item_in_save_data(save_data, &"workbench", StringName(str(row.get("id", ""))))
	if not bool(selected_result.get("success", false)):
		_errors.append("Repair service should persist selected repair row ids.")
	var repair_result: Dictionary = BaseRepairServiceScript.repair_from_save_data(selected_result.get("save_data", {}) as Dictionary, StringName(str(row.get("id", ""))))
	if not bool(repair_result.get("success", false)):
		_errors.append("Repair service should repair selected damaged gear when money is available.")
		return
	var repaired: Dictionary = ((repair_result.get("save_data", {}) as Dictionary).get("stash", []) as Array)[0] as Dictionary
	if int(repaired.get("current_durability", 0)) != 83 or int(repaired.get("max_durability", 0)) != 83:
		_errors.append("Repair should restore current durability to the reduced maximum.")
	if int(repaired.get("original_max_durability", 0)) != 100:
		_errors.append("Repair should preserve original max durability for future comparison.")
	if int((repair_result.get("save_data", {}) as Dictionary).get("money", 0)) >= 50:
		_errors.append("Repair should deduct money from save data.")
	var after_state: Dictionary = BaseRepairServiceScript.get_state_from_save_data(repair_result.get("save_data", {}) as Dictionary)
	if not (after_state.get("repair_rows", []) as Array).is_empty():
		_errors.append("Fully repaired gear should leave the repair row list until it is damaged again.")


func _validate_carried_repair_rows_and_models() -> void:
	var player := FakeRepairPlayer.new()
	player.inventory_model.add_stack(_damaged_pistol_stack(36, 84))
	player.safe_pocket_model.add_stack(_damaged_pistol_stack(35, 82))
	player.equipment_model.equip_stack(&"sidearm", _damaged_pistol_stack(31, 76))
	var save_data := _save_data_with_stash(80, [], true)
	var state: Dictionary = BaseRepairServiceScript.get_state_from_save_data(save_data, &"workbench", player)
	var rows: Array = state.get("repair_rows", []) as Array
	if rows.size() != 3:
		_errors.append("Repair service should expose damaged backpack, safe pocket, and equipment rows.")
	var backpack_id := _row_id_by_source(rows, "backpack")
	var safe_pocket_id := _row_id_by_source(rows, "safe_pocket")
	var equipment_id := _row_id_by_source(rows, "equipment")
	if backpack_id == "" or safe_pocket_id == "" or equipment_id == "":
		_errors.append("Repair rows should identify backpack, safe pocket, and equipment sources.")
	for source in ["backpack", "safe_pocket", "equipment"]:
		if _row_source_label(rows, source) == "":
			_errors.append("Repair row should expose a readable source label for %s." % source)
	var select_result: Dictionary = BaseRepairServiceScript.select_repair_item_in_save_data(save_data, &"workbench", StringName(backpack_id), player)
	if not bool(select_result.get("success", false)):
		_errors.append("Repair service should allow selecting carried backpack gear.")
	var backpack_result: Dictionary = BaseRepairServiceScript.repair_from_save_data(select_result.get("save_data", {}) as Dictionary, StringName(backpack_id), player)
	if not bool(backpack_result.get("success", false)):
		_errors.append("Repair service should repair carried backpack gear.")
	var repaired_backpack: Dictionary = player.inventory_model.get_display_items()[0] as Dictionary
	if int(repaired_backpack.get("current_durability", 0)) != 79 or int(repaired_backpack.get("max_durability", 0)) != 79:
		_errors.append("Backpack repair should write reduced max durability back to the carried stack.")
	if not ((backpack_result.get("save_data", {}) as Dictionary).get("stash", []) as Array).is_empty():
		_errors.append("Repairing carried gear should not move it into the stash.")
	if int((backpack_result.get("save_data", {}) as Dictionary).get("money", 0)) >= 80:
		_errors.append("Repairing carried gear should still deduct saved money.")
	var equipment_result: Dictionary = BaseRepairServiceScript.repair_from_save_data(backpack_result.get("save_data", {}) as Dictionary, StringName(equipment_id), player)
	if not bool(equipment_result.get("success", false)):
		_errors.append("Repair service should repair equipped gear.")
	var repaired_sidearm: Dictionary = player.equipment_model.get_slot(&"sidearm")
	if int(repaired_sidearm.get("current_durability", 0)) != 71 or int(repaired_sidearm.get("max_durability", 0)) != 71:
		_errors.append("Equipment repair should write reduced max durability back to the equipment slot.")
	player.free()


func _validate_missing_money_blocks_repair() -> void:
	var save_data := _save_data(0, _damaged_pistol_stack(), true)
	var state: Dictionary = BaseRepairServiceScript.get_state_from_save_data(save_data)
	if str(state.get("reason", "")) != "missing_money":
		_errors.append("Repair state should report missing_money when the selected row cannot be paid for.")
	if bool(state.get("can_repair", true)):
		_errors.append("Repair state should disable repair action when money is missing.")
	var selected_id := StringName(str(state.get("selected_repair_id", "")))
	var result: Dictionary = BaseRepairServiceScript.repair_from_save_data(save_data, selected_id)
	if bool(result.get("success", false)) or str(result.get("reason", "")) != "missing_money":
		_errors.append("Repair execution should fail without enough money.")


func _validate_stash_model_durability_round_trip() -> void:
	var stash := StashModelScript.new()
	if not stash.load_save_data([_damaged_pistol_stack()]):
		_errors.append("StashModel should load damaged durable save stacks.")
	var saved := stash.to_save_data()
	if saved.size() != 1:
		_errors.append("StashModel durability round-trip should keep one stack.")
		return
	var stack: Dictionary = saved[0] as Dictionary
	if int(stack.get("current_durability", 0)) != 42 or int(stack.get("max_durability", 0)) != 88:
		_errors.append("StashModel should preserve save-backed durability fields.")


func _validate_base_3d_workbench_repair_flow() -> void:
	var save_manager := _make_save_manager()
	_cleanup_validation_root(save_manager.save_root_path)
	save_manager.set_current_slot_index(1)
	save_manager.save_slot_data(1, _save_data(50, _damaged_pistol_stack(), true))
	var scene := Base3DScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var controller := scene.get_node_or_null("BaseInteractionController3D")
	if controller == null:
		_errors.append("Base 3D should expose BaseInteractionController3D for repair validation.")
		_free_node(scene)
		return
	if not bool(controller.call("open_interaction_by_id", "workbench")):
		_errors.append("Base 3D workbench should open before repair validation.")
	else:
		var panel := scene.get_node_or_null("HUD/BaseInteractionPanel")
		var repair_button := _mode_button(panel, "repair")
		if repair_button == null:
			_errors.append("Workbench should render Repair tab when Fix Station is installed.")
		else:
			repair_button.pressed.emit()
			await process_frame
		var repair_state: Dictionary = controller.call("get_panel_state")
		if str(repair_state.get("action_mode", "")) != "repair":
			_errors.append("Repair tab should expose repair action mode.")
		if not bool(repair_state.get("action_enabled", false)):
			_errors.append("Repair action should enable when damaged gear and money are available.")
		if int(repair_state.get("repair_button_count", 0)) != 1:
			_errors.append("Repair tab should render one repairable gear row.")
		if not str(repair_state.get("body", "")).contains(TranslationServer.translate("ui.base.workbench.repair_list_title")):
			_errors.append("Repair panel should show a readable repair list heading.")
		if not str(repair_state.get("body", "")).contains(TranslationServer.translate("ui.base.workbench.repair_source_stash")):
			_errors.append("Repair panel body should label stash repair rows.")
		var repair_buttons: Array = repair_state.get("repair_buttons", []) as Array
		if repair_buttons.is_empty() or not str((repair_buttons[0] as Dictionary).get("text", "")).contains(TranslationServer.translate("ui.base.workbench.repair_source_stash")):
			_errors.append("Repair row button should label stash source.")
		if panel != null and panel.has_signal("action_requested"):
			panel.emit_signal("action_requested", "workbench")
			await process_frame
		var loaded: Dictionary = save_manager.get_slot_data(1)
		var repaired: Dictionary = (loaded.get("stash", []) as Array)[0] as Dictionary
		if int(repaired.get("current_durability", 0)) != 83 or int(repaired.get("max_durability", 0)) != 83:
			_errors.append("Base 3D repair action should persist repaired durability values.")
		if int(loaded.get("money", 0)) >= 50:
			_errors.append("Base 3D repair action should deduct repair money.")
		var after_state: Dictionary = controller.call("get_panel_state")
		if bool(after_state.get("action_enabled", true)):
			_errors.append("Repair action should disable after the only damaged item is repaired.")
		if int(after_state.get("repair_button_count", 0)) != 0:
			_errors.append("Repair row list should clear after the only damaged item is repaired.")
	_free_node(scene)
	_cleanup_validation_root(save_manager.save_root_path)
	_free_created_save_manager()


func _validate_base_3d_workbench_carried_repair_flow() -> void:
	var save_manager := _make_save_manager()
	_cleanup_validation_root(save_manager.save_root_path)
	save_manager.set_current_slot_index(1)
	save_manager.save_slot_data(1, _save_data_with_stash(50, [], true))
	var scene := Base3DScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var controller := scene.get_node_or_null("BaseInteractionController3D")
	var player := scene.get_node_or_null("Player3D")
	if controller == null or player == null:
		_errors.append("Base 3D should expose controller and player for carried repair validation.")
		_free_node(scene)
		return
	var inventory: InventoryModel = player.call("get_inventory_model")
	inventory.clear()
	inventory.setup(12)
	inventory.add_stack(_damaged_pistol_stack())
	if not bool(controller.call("open_interaction_by_id", "workbench")):
		_errors.append("Base 3D workbench should open before carried repair validation.")
	else:
		var panel := scene.get_node_or_null("HUD/BaseInteractionPanel")
		var repair_button := _mode_button(panel, "repair")
		if repair_button != null:
			repair_button.pressed.emit()
			await process_frame
		var repair_state: Dictionary = controller.call("get_panel_state")
		if int(repair_state.get("repair_button_count", 0)) != 1:
			_errors.append("Repair tab should render carried backpack damaged gear when stash is empty.")
		var repair_buttons: Array = repair_state.get("repair_buttons", []) as Array
		if repair_buttons.is_empty() or not str((repair_buttons[0] as Dictionary).get("text", "")).contains(TranslationServer.translate("ui.base.workbench.repair_source_backpack")):
			_errors.append("Repair row button should label backpack source.")
		if panel != null and panel.has_signal("action_requested"):
			panel.emit_signal("action_requested", "workbench")
			await process_frame
		var repaired_stack: Dictionary = inventory.get_display_items()[0] as Dictionary
		if int(repaired_stack.get("current_durability", 0)) != 83 or int(repaired_stack.get("max_durability", 0)) != 83:
			_errors.append("Base 3D carried repair action should persist repaired backpack durability values.")
		var loaded: Dictionary = save_manager.get_slot_data(1)
		if int(loaded.get("money", 0)) >= 50:
			_errors.append("Base 3D carried repair action should deduct repair money.")
		if not (loaded.get("stash", []) as Array).is_empty():
			_errors.append("Base 3D carried repair should not create stash entries.")
	_free_node(scene)
	_cleanup_validation_root(save_manager.save_root_path)
	_free_created_save_manager()


func _save_data(money: int, stack: Dictionary, fix_station_purchased: bool) -> Dictionary:
	return _save_data_with_stash(money, [stack], fix_station_purchased)


func _save_data_with_stash(money: int, stash: Array, fix_station_purchased: bool) -> Dictionary:
	var upgrades := {str(WorkbenchUpgrade.id): {"purchased": true}}
	if fix_station_purchased:
		upgrades[str(FixStationUpgrade.id)] = {"purchased": true}
	return {
		"difficulty_id": "normal",
		"money": money,
		"stash": stash,
		"base_upgrades": upgrades,
		"quests": {},
	}


func _damaged_pistol_stack(current: int = 42, maximum: int = 88) -> Dictionary:
	return {
		"item_path": PISTOL_PATH,
		"quantity": 1,
		"current_durability": current,
		"max_durability": maximum,
		"original_max_durability": 100,
		"repair_max_durability_loss": 5,
		"durability_penalty_ratio": 0.5,
	}


func _make_save_manager() -> Node:
	var existing := root.get_node_or_null("SaveGameManager")
	if existing != null:
		existing.save_root_path = "user://validation_base_repair_service"
		return existing
	var save_manager := SaveGameManagerScript.new()
	save_manager.name = "SaveGameManager"
	save_manager.save_root_path = "user://validation_base_repair_service"
	root.add_child(save_manager)
	_created_save_manager = save_manager
	return save_manager


func _cleanup_validation_root(root_path: String) -> void:
	var absolute := ProjectSettings.globalize_path(root_path)
	if DirAccess.dir_exists_absolute(absolute):
		DirAccess.remove_absolute("%s/slot_1.json" % absolute)
		DirAccess.remove_absolute("%s/slot_2.json" % absolute)
		DirAccess.remove_absolute("%s/slot_3.json" % absolute)
		DirAccess.remove_absolute(absolute)


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


func _row_id_by_source(rows: Array, source: String) -> String:
	for value in rows:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var row := value as Dictionary
		if str(row.get("source", "")) == source:
			return str(row.get("id", ""))
	return ""


func _row_source_label(rows: Array, source: String) -> String:
	for value in rows:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var row := value as Dictionary
		if str(row.get("source", "")) == source:
			return str(row.get("source_label", ""))
	return ""


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
