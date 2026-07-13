extends SceneTree

const Base3DScene := preload("res://scenes/base/base_3d.tscn")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")
const BaseDismantleServiceScript := preload("res://scripts/base/base_dismantle_service.gd")
const BaseProgressionScript := preload("res://scripts/base/base_progression.gd")
const WorkbenchUpgrade := preload("res://data/base_upgrades/workbench_level_1.tres")
const DisassembleStationUpgrade := preload("res://data/base_upgrades/workbench_disassemble_station.tres")

const PISTOL_PATH := "res://data/items/weapons/pistol_S.tres"
const JUNK_PATH := "res://data/items/loot/junk.tres"

var _errors: Array[String] = []
var _created_save_manager: Node = null


func _initialize() -> void:
	_validate_service_locked_state()
	_validate_dismantle_rows_selection_and_save_data()
	_validate_stash_capacity_blocks_outputs()
	await _validate_base_3d_disassemble_station_install_flow()
	await _validate_base_3d_dismantle_flow()
	if _errors.is_empty():
		print("[base_dismantle_service] OK gate=disassemble_station rows=stash outputs=materials capacity=checked base3d=dismantle")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_service_locked_state() -> void:
	var save_data := _save_data_with_stash([_pistol_stack()], false)
	var state: Dictionary = BaseDismantleServiceScript.get_state_from_save_data(save_data)
	if bool(state.get("dismantle_unlocked", true)):
		_errors.append("Dismantle service should stay locked before Disassemble Station is purchased.")
	if not (state.get("dismantle_rows", []) as Array).is_empty():
		_errors.append("Dismantle service should not expose rows before Disassemble Station is purchased.")
	var result: Dictionary = BaseDismantleServiceScript.dismantle_from_save_data(save_data, &"stash:0:workbench_pistol_S_parts")
	if bool(result.get("success", false)) or str(result.get("reason", "")) != "dismantle_locked":
		_errors.append("Dismantle execution should be blocked before Disassemble Station is purchased.")


func _validate_dismantle_rows_selection_and_save_data() -> void:
	var save_data := _save_data_with_stash([_pistol_stack()], true)
	var state: Dictionary = BaseDismantleServiceScript.get_state_from_save_data(save_data)
	if not bool(state.get("dismantle_unlocked", false)):
		_errors.append("Dismantle service should unlock after Disassemble Station is purchased.")
	var rows: Array = state.get("dismantle_rows", []) as Array
	if rows.size() != 1:
		_errors.append("Dismantle service should expose one pistol dismantle row.")
		return
	var row: Dictionary = rows[0]
	if str(row.get("input_item_path", "")) != PISTOL_PATH:
		_errors.append("Dismantle row should point at the stash pistol stack.")
	if not bool(row.get("can_dismantle", false)):
		_errors.append("Dismantle row should be executable when outputs fit in stash.")
	if str(row.get("output_text", "")).strip_edges() == "":
		_errors.append("Dismantle row should expose readable output text.")
	var output_stacks: Array = row.get("output_stacks", []) as Array
	if _stack_quantity_in_array(output_stacks, JUNK_PATH) != 4:
		_errors.append("Dismantle row should expose configured output material data.")
	if str(state.get("selected_dismantle_id", "")) != str(row.get("id", "")):
		_errors.append("Dismantle service should select the first available row by default.")
	var select_result: Dictionary = BaseDismantleServiceScript.select_dismantle_item_in_save_data(save_data, &"workbench", StringName(str(row.get("id", ""))))
	if not bool(select_result.get("success", false)):
		_errors.append("Dismantle service should persist selected dismantle row ids.")
	var selected: Dictionary = (select_result.get("save_data", {}) as Dictionary).get("selected_dismantle_ids", {}) as Dictionary
	if str(selected.get("workbench", "")) != str(row.get("id", "")):
		_errors.append("Dismantle selection should save under selected_dismantle_ids.")
	var result: Dictionary = BaseDismantleServiceScript.dismantle_from_save_data(select_result.get("save_data", {}) as Dictionary, StringName(str(row.get("id", ""))))
	if not bool(result.get("success", false)):
		_errors.append("Dismantle service should dismantle selected stash gear.")
		return
	var updated: Dictionary = result.get("save_data", {}) as Dictionary
	if _stash_quantity(updated, PISTOL_PATH) != 0:
		_errors.append("Dismantle should consume the input pistol stack.")
	if _stash_quantity(updated, JUNK_PATH) != 4:
		_errors.append("Dismantle should add configured output material stacks.")
	var after_state: Dictionary = BaseDismantleServiceScript.get_state_from_save_data(updated)
	if not (after_state.get("dismantle_rows", []) as Array).is_empty():
		_errors.append("Dismantle row should clear after its input item is consumed.")


func _validate_stash_capacity_blocks_outputs() -> void:
	var stash: Array = []
	for _index in range(250):
		stash.append(_pistol_stack())
	var save_data := _save_data_with_stash(stash, true)
	var rows: Array = BaseDismantleServiceScript.get_dismantle_rows(save_data)
	if rows.is_empty():
		_errors.append("Capacity validation should still discover dismantle candidates.")
		return
	var first_row: Dictionary = rows[0]
	if bool(first_row.get("can_dismantle", true)):
		_errors.append("Dismantle row should block when outputs exceed stash capacity after input removal.")
	var result: Dictionary = BaseDismantleServiceScript.dismantle_from_save_data(save_data, StringName(str(first_row.get("id", ""))))
	if bool(result.get("success", false)) or str(result.get("reason", "")) != "stash_full":
		_errors.append("Dismantle execution should fail with stash_full when outputs cannot fit.")


func _validate_base_3d_disassemble_station_install_flow() -> void:
	var save_manager := _make_save_manager()
	_cleanup_validation_root(save_manager.save_root_path)
	save_manager.set_current_slot_index(1)
	save_manager.save_slot_data(1, {
		"difficulty_id": "normal",
		"money": 30,
		"stash": [],
		"base_upgrades": {str(WorkbenchUpgrade.id): {"purchased": true}},
		"quests": {},
	})
	var scene := Base3DScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var controller := scene.get_node_or_null("BaseInteractionController3D")
	if controller == null:
		_errors.append("Base 3D should expose BaseInteractionController3D for dismantle install validation.")
		_free_node(scene)
		return
	if bool(controller.call("open_interaction_by_id", "workbench")):
		var panel := scene.get_node_or_null("HUD/BaseInteractionPanel")
		var dismantle_button := _mode_button(panel, "dismantle")
		if dismantle_button == null:
			_errors.append("Workbench mode tabs should render a Dismantle button for Disassemble Station installation.")
		elif dismantle_button.disabled:
			_errors.append("Dismantle tab should be selectable after Workbench Level 1 so Disassemble Station can be installed.")
		else:
			dismantle_button.pressed.emit()
			await process_frame
		var install_state: Dictionary = controller.call("get_panel_state")
		if str(install_state.get("action_mode", "")) != "disassemble_station_upgrade":
			_errors.append("Uninstalled Dismantle tab should expose Disassemble Station installation action mode.")
		if not bool(install_state.get("action_enabled", false)):
			_errors.append("Disassemble Station installation action should enable when money is available.")
		if panel != null and panel.has_signal("action_requested"):
			panel.emit_signal("action_requested", "workbench")
			await process_frame
		var loaded: Dictionary = save_manager.get_slot_data(1)
		if not BaseProgressionScript.is_upgrade_purchased(loaded, DisassembleStationUpgrade.id):
			_errors.append("Base 3D Disassemble Station action should persist the installed station.")
		if int(loaded.get("money", 0)) != 10:
			_errors.append("Base 3D Disassemble Station action should deduct money cost.")
	_free_node(scene)
	_cleanup_validation_root(save_manager.save_root_path)


func _validate_base_3d_dismantle_flow() -> void:
	var save_manager := _make_save_manager()
	_cleanup_validation_root(save_manager.save_root_path)
	save_manager.set_current_slot_index(1)
	save_manager.save_slot_data(1, _save_data_with_stash([_pistol_stack()], true))
	var scene := Base3DScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var controller := scene.get_node_or_null("BaseInteractionController3D")
	if controller == null:
		_errors.append("Base 3D should expose BaseInteractionController3D for dismantle validation.")
		_free_node(scene)
		return
	if bool(controller.call("open_interaction_by_id", "workbench")):
		var panel := scene.get_node_or_null("HUD/BaseInteractionPanel")
		var dismantle_button := _mode_button(panel, "dismantle")
		if dismantle_button != null:
			dismantle_button.pressed.emit()
			await process_frame
		var state: Dictionary = controller.call("get_panel_state")
		if str(state.get("action_mode", "")) != "dismantle":
			_errors.append("Installed Dismantle tab should expose dismantle action mode.")
		if int(state.get("dismantle_button_count", 0)) != 1:
			_errors.append("Dismantle tab should render one dismantle row.")
		if not bool(state.get("action_enabled", false)):
			_errors.append("Dismantle action should enable when a row is selected and outputs fit.")
		if not str(state.get("body", "")).contains(TranslationServer.translate("ui.base.workbench.dismantle_list_title")):
			_errors.append("Dismantle panel should show a readable dismantle heading.")
		var buttons: Array = state.get("dismantle_buttons", []) as Array
		if buttons.is_empty() or str((buttons[0] as Dictionary).get("output_text", "")).strip_edges() == "":
			_errors.append("Dismantle row button should show output materials.")
		if panel != null and panel.has_signal("action_requested"):
			panel.emit_signal("action_requested", "workbench")
			await process_frame
		var loaded: Dictionary = save_manager.get_slot_data(1)
		if _stash_quantity(loaded, PISTOL_PATH) != 0:
			_errors.append("Base 3D dismantle action should consume the stash input item.")
		if _stash_quantity(loaded, JUNK_PATH) != 4:
			_errors.append("Base 3D dismantle action should save output materials.")
		var after_state: Dictionary = controller.call("get_panel_state")
		if not str(after_state.get("body", "")).contains(TranslationServer.translate("ui.base.workbench_dismantle_done")):
			_errors.append("Workbench panel should report a completed dismantle action.")
		if bool(after_state.get("action_enabled", true)):
			_errors.append("Dismantle action should disable after the only candidate is consumed.")
	_free_node(scene)
	_cleanup_validation_root(save_manager.save_root_path)
	_free_created_save_manager()


func _save_data_with_stash(stash: Array, disassemble_station_purchased: bool) -> Dictionary:
	var upgrades := {str(WorkbenchUpgrade.id): {"purchased": true}}
	if disassemble_station_purchased:
		upgrades[str(DisassembleStationUpgrade.id)] = {"purchased": true}
	return {
		"difficulty_id": "normal",
		"money": 50,
		"stash": stash,
		"base_upgrades": upgrades,
		"quests": {},
	}


func _pistol_stack() -> Dictionary:
	return {"item_path": PISTOL_PATH, "quantity": 1}


func _stash_quantity(save_data: Dictionary, item_path: String) -> int:
	var total := 0
	for value in save_data.get("stash", []) as Array:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var stack := value as Dictionary
		if str(stack.get("item_path", stack.get("resource_path", ""))) == item_path:
			total += int(stack.get("quantity", 0))
	return total


func _stack_quantity_in_array(stacks: Array, item_path: String) -> int:
	var total := 0
	for value in stacks:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var stack := value as Dictionary
		if str(stack.get("item_path", stack.get("resource_path", ""))) == item_path:
			total += int(stack.get("quantity", 0))
	return total


func _make_save_manager() -> Node:
	var existing := root.get_node_or_null("SaveGameManager")
	if existing != null:
		existing.save_root_path = "user://validation_base_dismantle_service"
		return existing
	var save_manager := SaveGameManagerScript.new()
	save_manager.name = "SaveGameManager"
	save_manager.save_root_path = "user://validation_base_dismantle_service"
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
