extends SceneTree

const PLAYER_PATH := "res://scripts/player/player_controller_3d.gd"
const TIMED_ACTION_PATH := "res://scripts/player/player_timed_action_controller_3d.gd"
const QUICK_SLOT_PATH := "res://scripts/player/player_quick_slot_controller_3d.gd"
const INVENTORY_UI_PATH := "res://scripts/ui/inventory_equipment_ui.gd"
const UI_INPUT_PATH := "res://scripts/ui/inventory_equipment_input_router.gd"
const UI_ACTION_PATH := "res://scripts/ui/inventory_equipment_action_support.gd"
const UI_DRAG_PATH := "res://scripts/ui/inventory_equipment_drag_support.gd"

const PLAYER_REGRESSION_CAP := 1100
const INVENTORY_UI_REGRESSION_CAP := 900
const FOCUSED_HELPER_CAP := 600

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_player_boundaries()
	_validate_inventory_ui_boundaries()
	if _errors.is_empty():
		print("[player_ui_architecture_health] OK player=orchestrator timed_actions=owned quick_slots=owned inventory_ui=orchestrator input=split actions=split drag=split")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _validate_player_boundaries() -> void:
	var source := _read(PLAYER_PATH)
	_expect(_line_count(source) <= PLAYER_REGRESSION_CAP, "PlayerController3D exceeded the 1100-line regression cap.")
	for required in ["PlayerTimedActionControllerScript", "PlayerQuickSlotControllerScript", "_timed_actions.setup", "_quick_slots"]:
		_expect(source.contains(required), "PlayerController3D should coordinate focused helper: %s." % required)
	for forbidden in ["var _reload_timer", "var _item_use_timer", "var _pending_reload", "var _pending_item_use", "var _last_reload_emit_progress"]:
		_expect(not source.contains(forbidden), "PlayerController3D should not reclaim timed-action state: %s." % forbidden)
	_validate_helper(TIMED_ACTION_PATH, ["var _reload_timer", "var _item_use_timer", "func reload_equipped_weapon", "func use_inventory_stack"])
	_validate_helper(QUICK_SLOT_PATH, ["func assign_inventory_stack", "func move_slot", "func select_slot", "func use_slot"])


func _validate_inventory_ui_boundaries() -> void:
	var source := _read(INVENTORY_UI_PATH)
	_expect(_line_count(source) <= INVENTORY_UI_REGRESSION_CAP, "InventoryEquipmentUI exceeded the 900-line regression cap.")
	for required in ["InventoryEquipmentInputRouterScript", "InventoryEquipmentActionSupportScript", "InventoryEquipmentDragSupportScript", "_input_router.handle_gui_input"]:
		_expect(source.contains(required), "InventoryEquipmentUI should coordinate focused helper: %s." % required)
	for forbidden in ["var _dragging_equipment_slot", "var _dragging_weapon_mod_slot", "var _dragging_quick_slot_key", "_drop_controller.finish_drag("]:
		_expect(not source.contains(forbidden), "InventoryEquipmentUI should not reclaim interaction implementation: %s." % forbidden)
	_validate_helper(UI_INPUT_PATH, ["func handle_gui_input", "func _handle_left_press", "func _handle_left_release"])
	_validate_helper(UI_ACTION_PATH, ["func open_weapon_mod_panel_for_slot", "func attach_dragged_stack_to_open_weapon_hardpoint", "func unload_equipment_weapon_ammo_to_backpack"])
	_validate_helper(UI_DRAG_PATH, ["func start_weapon_mod_drag", "func start_quick_slot_drag", "func start_equipment_drag"])


func _validate_helper(path: String, required_terms: Array[String]) -> void:
	var source := _read(path)
	_expect(not source.is_empty(), "Focused helper should exist and be readable: %s." % path)
	_expect(_line_count(source) <= FOCUSED_HELPER_CAP, "Focused helper exceeded the 600-line cap: %s." % path)
	for required in required_terms:
		_expect(source.contains(required), "Focused helper %s should own term: %s." % [path, required])


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _line_count(source: String) -> int:
	return source.split("\n").size()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
