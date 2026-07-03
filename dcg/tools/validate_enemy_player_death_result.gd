extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")
const WoodItem := preload("res://data/items/crafting/wood.tres")
const BASE_3D_SCENE := "res://scenes/base/base_3d.tscn"
const VALIDATION_SAVE_ROOT := "user://validation_enemy_player_death_result"

var _errors: Array[String] = []
var _save_manager: Node = null
var _original_save_root := ""
var _original_slot := 1
var _enemy_attacked := false


func _initialize() -> void:
	_setup_save_manager()
	await _validate_enemy_attack_death_result_and_base_return()
	_restore_save_manager()
	_cleanup_validation_root(VALIDATION_SAVE_ROOT)
	if _errors.is_empty():
		print("[enemy_player_death_result] OK enemy=attacks death=result_panel lost_items=visible return=base_3d")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_enemy_attack_death_result_and_base_return() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame

	var player := scene.get_node_or_null("Player3D")
	var enemy := scene.get_node_or_null("SceneProps/ScavengerPatrol01")
	var session := scene.get_node_or_null("RaidSession")
	var result_panel := scene.get_node_or_null("HUD/RaidResultPanel")
	var applier := scene.get_node_or_null("RaidResultApplier")
	if player == null or enemy == null or session == null or result_panel == null or applier == null:
		_errors.append("Normal Raid scene should include Player3D, ScavengerPatrol01, RaidSession, RaidResultPanel, and RaidResultApplier.")
		_free_current_scene()
		return

	var inventory: InventoryModel = player.call("get_inventory_model")
	inventory.clear()
	inventory.setup(20)
	inventory.add_item(WoodItem, 4)
	player.set("health", 8.0)
	player.set("max_health", 8.0)
	player.global_position = Vector3.ZERO
	enemy.global_position = Vector3(0.0, 0.0, 0.85)
	enemy.velocity = Vector3.ZERO

	var controller := enemy.get_node_or_null("EnemyController3D")
	if controller == null:
		_errors.append("Scavenger should include EnemyController3D for enemy-caused death validation.")
		_free_current_scene()
		return
	controller.attack_range = 2.0
	controller.attack_windup_duration = 0.03
	controller.attack_cooldown = 0.05
	if controller.has_signal("attacked"):
		controller.attacked.connect(_on_enemy_attacked)
	var enemy_def: Variant = enemy.get_meta("enemy_def", null)
	if enemy_def is Resource:
		enemy_def.set("damage", 20.0)

	for _frame in range(45):
		await physics_frame
		await process_frame
		if bool(player.get("is_dead")):
			break

	if not _enemy_attacked:
		_errors.append("Enemy should visibly attack the player before death result validation.")
	if not bool(player.get("is_dead")):
		_errors.append("Enemy attack should be able to kill the low-health player.")
	if not bool(session.get("dead")):
		_errors.append("Player death should register a dead RaidSession state.")
	if not bool(result_panel.visible):
		_errors.append("Enemy-caused player death should show the RaidResultPanel.")

	var state: Dictionary = result_panel.call("get_display_state")
	if not str(state.get("outcome", "")).contains("死亡"):
		_errors.append("Death result panel should show a readable death outcome.")
	if int(state.get("lost_rows", 0)) < 1:
		_errors.append("Death result panel should show lost backpack item rows.")
	if not str(state.get("transfer_detail", "")).contains("行動失敗"):
		_errors.append("Death result panel should explain the action failed.")
	if not str(state.get("status", "")).contains("遺失物品"):
		_errors.append("Death result panel should explain lost items.")
	if str(state.get("continue_text", "")) != "回到基地":
		_errors.append("Death result panel continue button should say 回到基地.")

	var result: Dictionary = session.call("build_result")
	var lost_items: Array = result.get("lost_items", []) as Array
	if _stack_quantity(lost_items, WoodItem.resource_path) != 4:
		_errors.append("Enemy-caused death result should list backpack wood as lost.")
	if not bool(applier.get("last_apply_result").get("death_loss", false)):
		_errors.append("RaidResultApplier should apply death loss after enemy-caused death.")
	if inventory.get_used_slots() != 0:
		_errors.append("Temporary raid backpack should be cleared after enemy-caused death result.")

	var saved_after: Dictionary = _save_manager.call("get_slot_data", 1)
	if not (saved_after.get("stash", []) as Array).is_empty():
		_errors.append("Lost death items should not enter base stash.")

	result_panel.continue_button.pressed.emit()
	for _index in range(8):
		await process_frame
	if current_scene == null:
		_errors.append("Continue from death result should leave a loaded scene.")
	elif current_scene.scene_file_path != BASE_3D_SCENE:
		_errors.append("Continue from death result should return to 3D Base, got `%s`." % current_scene.scene_file_path)

	_free_current_scene()


func _setup_save_manager() -> void:
	_save_manager = root.get_node_or_null("SaveGameManager")
	if _save_manager == null:
		_save_manager = SaveGameManagerScript.new()
		_save_manager.name = "SaveGameManager"
		root.add_child(_save_manager)
	_original_save_root = str(_save_manager.get("save_root_path"))
	if _save_manager.has_method("get_current_slot_index"):
		_original_slot = int(_save_manager.call("get_current_slot_index"))
	_save_manager.set("save_root_path", VALIDATION_SAVE_ROOT)
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


func _restore_save_manager() -> void:
	if _save_manager == null:
		return
	if _original_save_root != "":
		_save_manager.set("save_root_path", _original_save_root)
	if _save_manager.has_method("set_current_slot_index"):
		_save_manager.call("set_current_slot_index", _original_slot)


func _on_enemy_attacked(_target: Node, _damage: float) -> void:
	_enemy_attacked = true


func _stack_quantity(stacks: Array, item_path: String) -> int:
	var total := 0
	for entry in stacks:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var stack := entry as Dictionary
		if str(stack.get("item_path", stack.get("resource_path", ""))) == item_path:
			total += int(stack.get("quantity", 0))
	return total


func _cleanup_validation_root(root_path: String) -> void:
	var absolute := ProjectSettings.globalize_path(root_path)
	if DirAccess.dir_exists_absolute(absolute):
		DirAccess.remove_absolute("%s/slot_1.json" % absolute)
		DirAccess.remove_absolute("%s/slot_2.json" % absolute)
		DirAccess.remove_absolute("%s/slot_3.json" % absolute)
		DirAccess.remove_absolute(absolute)


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
