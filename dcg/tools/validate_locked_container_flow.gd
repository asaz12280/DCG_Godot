extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const LootContainerScript := preload("res://scripts/loot/loot_container_3d.gd")
const WarehouseKey := preload("res://data/items/keys/warehouse_key.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	await _validate_locked_container_requires_key()
	await _validate_key_opens_existing_container_grid()
	_validate_responsibility_boundary()
	if _errors.is_empty():
		print("[locked_container_flow] OK locked=visible key=required open=container_grid boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_locked_container_requires_key() -> void:
	var context := await _create_context()
	if context.is_empty():
		return

	var container: LootContainer3D = context["container"]
	var player: Node = context["player"]
	var container_model: RefCounted = container.get_container_inventory_model()
	var ui_manager := root.get_node_or_null("UIManager")
	var blocked_events: Array[Dictionary] = []
	container.open_blocked.connect(func(reason: StringName, message: String) -> void:
		blocked_events.append({"reason": reason, "message": message})
	)

	var opened := container.try_open(player)
	await process_frame
	await process_frame
	var state := container.get_state()
	if opened:
		_errors.append("Locked container should not open without the required key.")
	if not bool(state.get("is_locked", false)):
		_errors.append("Locked container state should report is_locked=true.")
	if str(state.get("required_key_id", "")) != "warehouse_key":
		_errors.append("Locked container should require the warehouse key.")
	if int(container_model.call("get_used_slots")) != 0:
		_errors.append("Blocked locked container should not roll or reveal contents.")
	if blocked_events.is_empty() or str(blocked_events[0].get("message", "")).strip_edges() == "":
		_errors.append("Blocked locked container should emit visible key feedback.")
	if ui_manager != null and ui_manager.has_method("get_active_ui") and ui_manager.get_active_ui() == &"container":
		_errors.append("Missing-key locked container should not open ContainerInventoryUI.")

	_free_node(context["scene"])


func _validate_key_opens_existing_container_grid() -> void:
	var context := await _create_context()
	if context.is_empty():
		return

	var scene: Node = context["scene"]
	var container: LootContainer3D = context["container"]
	var player: Node = context["player"]
	var container_ui := scene.find_child("ContainerInventoryUI", true, false) as Control
	if container_ui == null:
		_errors.append("Gameplay HUD should include ContainerInventoryUI for locked container opening.")
		_free_node(scene)
		return
	if not player.has_method("add_item_resource"):
		_errors.append("Player should expose add_item_resource for validation setup.")
		_free_node(scene)
		return

	player.call("add_item_resource", WarehouseKey, 1)
	var opened := container.try_open(player)
	await process_frame
	await process_frame

	var ui_manager := root.get_node_or_null("UIManager")
	var container_model: RefCounted = container.get_container_inventory_model()
	var state: Dictionary = container_ui.call("get_display_state")
	if not opened:
		_errors.append("Locked container should open after the player has the required key.")
	if int(container_model.call("get_used_slots")) <= 0:
		_errors.append("Opened locked container should roll visible contents.")
	if ui_manager != null and ui_manager.has_method("get_active_ui") and ui_manager.get_active_ui() != &"container":
		_errors.append("Locked container should open through the existing container UI state.")
	if str(state.get("title", "")) != "上鎖箱":
		_errors.append("ContainerInventoryUI should show the locked container display name.")
	if int(state.get("slot_count", 0)) != int(container_model.call("get_capacity")):
		_errors.append("Locked container should use the same visible capacity grid as normal containers.")
	if not str(state.get("capacity", "")).contains("/"):
		_errors.append("Locked container UI should show used/capacity text.")

	_free_node(scene)


func _validate_responsibility_boundary() -> void:
	var container_source := FileAccess.get_file_as_string("res://scripts/loot/loot_container_3d.gd")
	for required in ["is_locked", "required_key", "open_blocked", "get_container_inventory_model"]:
		if not container_source.contains(required):
			_errors.append("LootContainer3D should own locked-container access state: %s" % required)
	for forbidden in ["InventoryEquipmentUI", "add_item_resource", "remove_from_slot", "ContainerInventoryUI", "change_scene"]:
		if container_source.contains(forbidden):
			_errors.append("LootContainer3D should not own UI transfer or scene flow: %s" % forbidden)

	var ui_source := FileAccess.get_file_as_string("res://scripts/ui/container_inventory_ui.gd")
	for forbidden in ["required_key", "is_locked", "open_blocked", "warehouse_key"]:
		if ui_source.contains(forbidden):
			_errors.append("ContainerInventoryUI should display locked container contents, not own lock rules: %s" % forbidden)

	var ui_manager_source := FileAccess.get_file_as_string("res://scripts/ui/ui_manager.gd")
	for forbidden in ["required_key", "warehouse_key", "open_blocked"]:
		if ui_manager_source.contains(forbidden):
			_errors.append("UIManager should route container UI, not own locked-container rules: %s" % forbidden)


func _create_context() -> Dictionary:
	var ui_manager := root.get_node_or_null("UIManager")
	if ui_manager != null and ui_manager.has_method("close_all"):
		ui_manager.close_all()

	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var player := scene.get_node_or_null("Player3D")
	var container := _find_locked_container(scene)
	if player == null:
		_errors.append("Gameplay scene should include Player3D for locked container validation.")
		_free_node(scene)
		return {}
	if container == null:
		_errors.append("Gameplay scene should include one locked LootContainer3D.")
		_free_node(scene)
		return {}
	return {
		"scene": scene,
		"player": player,
		"container": container,
	}


func _find_locked_container(scene: Node) -> LootContainer3D:
	for node in scene.find_children("*", "Area3D", true, false):
		if node.get_script() != LootContainerScript:
			continue
		var state: Dictionary = node.call("get_state")
		if bool(state.get("is_locked", false)):
			return node as LootContainer3D
	return null


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
