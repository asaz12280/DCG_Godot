extends SceneTree

const BaseScreenScene := preload("res://scenes/base/base_screen.tscn")
const Base3DScene := preload("res://scenes/base/base_3d.tscn")
const PlayerScene := preload("res://scenes/player/player_3d.tscn")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")
const WorkbenchUpgrade := preload("res://data/base_upgrades/workbench_level_1.tres")
const BaseProgressionScript := preload("res://scripts/base/base_progression.gd")

const WOOD_PATH := "res://data/items/crafting/wood.tres"
const WIRE_PATH := "res://data/items/electronics/wire.tres"

var _errors: Array[String] = []
var _created_save_manager: Node = null


func _initialize() -> void:
	_validate_upgrade_def()
	await _validate_insufficient_upgrade_state()
	await _validate_purchase_upgrade_and_save()
	await _validate_base_3d_workbench_purchase()
	await _validate_starter_ammo_bonus()
	if _errors.is_empty():
		print("[base_progression] OK upgrade=data_valid cost=deducted save=persists base3d=action effect=starter_ammo")
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
