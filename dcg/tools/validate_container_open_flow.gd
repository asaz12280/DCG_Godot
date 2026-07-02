extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const LootContainerScript := preload("res://scripts/loot/loot_container_3d.gd")

var _errors: Array[String] = []


func _initialize() -> void:
	await _validate_gameplay_container_open_flow()
	_validate_responsibility_boundary()
	if _errors.is_empty():
		print("[container_open_flow] OK interaction=opens_ui contents=container_owned ui_manager=owner")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_gameplay_container_open_flow() -> void:
	var ui_manager := root.get_node_or_null("UIManager")
	if ui_manager != null and ui_manager.has_method("close_all"):
		ui_manager.close_all()

	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var player := scene.get_node_or_null("Player3D")
	if player == null:
		_errors.append("Gameplay scene should include Player3D for container open flow.")
		_free_node(scene)
		return
	var container := _first_loot_container(scene)
	if container == null:
		_errors.append("Gameplay scene should include a LootContainer3D for container open flow.")
		_free_node(scene)
		return
	var container_ui := scene.find_child("ContainerInventoryUI", true, false)
	if container_ui == null:
		_errors.append("Gameplay HUD should include ContainerInventoryUI.")
		_free_node(scene)
		return

	if not container.try_open(player):
		_errors.append("LootContainer3D should open ContainerInventoryUI from normal player interaction.")
	await process_frame
	await process_frame

	var model: RefCounted = container.call("get_container_inventory_model")
	if int(model.call("get_used_slots")) <= 0:
		_errors.append("Opened loot container should own visible container contents.")
	var state: Dictionary = container_ui.call("get_display_state")
	if not bool(state.get("visible", false)):
		_errors.append("ContainerInventoryUI should be visible after opening a loot container.")
	if int(state.get("slot_count", 0)) != int(model.call("get_capacity")):
		_errors.append("ContainerInventoryUI should show one slot per container capacity.")
	if not str(state.get("capacity", "")).contains("/"):
		_errors.append("ContainerInventoryUI should show used/capacity text after opening.")
	if ui_manager != null and ui_manager.has_method("get_active_ui"):
		if ui_manager.get_active_ui() != &"container":
			_errors.append("UIManager should own active container UI state.")

	_free_node(scene)


func _validate_responsibility_boundary() -> void:
	var container_source := FileAccess.get_file_as_string("res://scripts/loot/loot_container_3d.gd")
	if container_source.contains("InventoryEquipmentUI") or container_source.contains("add_item_resource"):
		_errors.append("LootContainer3D should not directly write to player backpack UI or inventory.")
	var ui_source := FileAccess.get_file_as_string("res://scripts/ui/container_inventory_ui.gd")
	for forbidden in ["roll(", "loot_table", "change_scene"]:
		if ui_source.contains(forbidden):
			_errors.append("ContainerInventoryUI should not own loot rolling or scene flow: %s" % forbidden)


func _first_loot_container(scene: Node) -> LootContainer3D:
	for node in scene.find_children("*", "Area3D", true, false):
		if node.get_script() == LootContainerScript:
			return node as LootContainer3D
	return null


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
