extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const LootContainerScript := preload("res://scripts/loot/loot_container_3d.gd")
const Pistol := preload("res://data/items/weapons/pistol_S.tres")
const Ammo := preload("res://data/items/ammo/ammo_S.tres")
const PISTOL_PATH := "res://data/items/weapons/pistol_S.tres"
const AMMO_PATH := "res://data/items/ammo/ammo_S.tres"

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	await _validate_early_container_visible_pistol_and_ammo()
	await _validate_click_transfer_to_backpack()
	await _validate_full_backpack_feedback()
	_validate_responsibility_boundary()
	if _errors.is_empty():
		print("[container_transfer] OK click=moves_to_backpack full=feedback boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_early_container_visible_pistol_and_ammo() -> void:
	var context := await _open_first_container()
	if context.is_empty():
		return

	var container: Node = context["container"]
	var container_ui: Control = context["container_ui"]
	var container_model: RefCounted = container.call("get_container_inventory_model")
	var slots: Array = container_model.call("get_slots")
	if not _slots_contain_path(slots, PISTOL_PATH):
		_errors.append("Early container should visibly include No.5 pistol.")
	if not _slots_contain_path(slots, AMMO_PATH):
		_errors.append("Early container should visibly include No.7 ammo.")

	var visible_text := _container_slot_text(container_ui)
	if not visible_text.contains(Pistol.display_name):
		_errors.append("Container UI should show No.5 pistol name matching item catalog: %s" % Pistol.display_name)
	if not visible_text.contains(Ammo.display_name):
		_errors.append("Container UI should show No.7 ammo name matching item catalog: %s" % Ammo.display_name)
	_free_node(context["scene"])


func _validate_click_transfer_to_backpack() -> void:
	var context := await _open_first_container()
	if context.is_empty():
		return

	var player: Node = context["player"]
	var container: Node = context["container"]
	var container_ui: Control = context["container_ui"]
	var backpack_model: RefCounted = player.call("get_inventory_model")
	var container_model: RefCounted = container.call("get_container_inventory_model")
	var occupied_slot := _first_occupied_slot(container_model)
	if occupied_slot < 0:
		_errors.append("Opened container should have at least one occupied slot to transfer.")
		_free_node(context["scene"])
		return

	var initial_backpack_used := int(backpack_model.call("get_used_slots"))
	var initial_container_used := int(container_model.call("get_used_slots"))
	var slot_button := container_ui.find_child("ContainerSlot%d" % occupied_slot, true, false) as Button
	if slot_button == null:
		_errors.append("ContainerInventoryUI should expose clickable slot buttons.")
		_free_node(context["scene"])
		return

	slot_button.pressed.emit()
	await process_frame
	await process_frame

	var next_backpack_used := int(backpack_model.call("get_used_slots"))
	var next_container_used := int(container_model.call("get_used_slots"))
	var state: Dictionary = container_ui.call("get_display_state")
	if next_backpack_used <= initial_backpack_used:
		_errors.append("Clicking a container item should move it into the player backpack.")
	if next_container_used >= initial_container_used:
		_errors.append("Transferred container slot should become empty or reduce container used count.")
	if not str(state.get("status", "")).contains("已移入背包"):
		_errors.append("Container transfer should show visible success feedback.")
	if str(state.get("capacity", "")) == "%d/%d" % [initial_container_used, int(container_model.call("get_capacity"))]:
		_errors.append("Container capacity text should update after transfer.")

	_free_node(context["scene"])


func _validate_full_backpack_feedback() -> void:
	var context := await _open_first_container()
	if context.is_empty():
		return

	var player: Node = context["player"]
	var container: Node = context["container"]
	var container_ui: Control = context["container_ui"]
	var backpack_model: RefCounted = player.call("get_inventory_model")
	var container_model: RefCounted = container.call("get_container_inventory_model")
	backpack_model.call("clear")
	backpack_model.call("setup", 1)
	backpack_model.call("add_item", Pistol, 1)

	var occupied_slot := _first_occupied_slot(container_model)
	if occupied_slot < 0:
		_errors.append("Opened container should have an item for full-backpack validation.")
		_free_node(context["scene"])
		return

	var initial_backpack_used := int(backpack_model.call("get_used_slots"))
	var initial_container_used := int(container_model.call("get_used_slots"))
	var slot_button := container_ui.find_child("ContainerSlot%d" % occupied_slot, true, false) as Button
	if slot_button == null:
		_errors.append("ContainerInventoryUI should expose slot buttons for full-backpack feedback.")
		_free_node(context["scene"])
		return

	slot_button.pressed.emit()
	await process_frame
	await process_frame

	var state: Dictionary = container_ui.call("get_display_state")
	if int(backpack_model.call("get_used_slots")) != initial_backpack_used:
		_errors.append("Full backpack transfer should not alter backpack capacity.")
	if int(container_model.call("get_used_slots")) != initial_container_used:
		_errors.append("Full backpack transfer should leave container contents untouched.")
	if not str(state.get("status", "")).contains("背包已滿"):
		_errors.append("Full backpack transfer should show visible Traditional Chinese feedback.")

	_free_node(context["scene"])


func _validate_responsibility_boundary() -> void:
	var container_ui_source := FileAccess.get_file_as_string("res://scripts/ui/container_inventory_ui.gd")
	var ui_forbidden := PackedStringArray([
		"get_tree().current_scene",
		"Player3D",
		"get_inventory_model",
		"add_stack",
		"remove_from_slot",
		"LootContainer3D",
		"loot_table",
		"roll(",
	])
	for term in ui_forbidden:
		if container_ui_source.contains(term):
			_errors.append("ContainerInventoryUI should display/emit intent only, not own transfer logic: %s" % term)

	var loot_container_source := FileAccess.get_file_as_string("res://scripts/loot/loot_container_3d.gd")
	for term in ["InventoryEquipmentUI", "add_item_resource", "get_inventory_model"]:
		if loot_container_source.contains(term):
			_errors.append("LootContainer3D should not directly write to player backpack: %s" % term)

	var ui_manager_source := FileAccess.get_file_as_string("res://scripts/ui/ui_manager.gd")
	for required in ["slot_pressed", "ContainerTransferScript.transfer_slot"]:
		if not ui_manager_source.contains(required):
			_errors.append("UIManager should own the transfer bridge for container slot intent: %s" % required)
	var transfer_source := FileAccess.get_file_as_string("res://scripts/ui/ui_manager_container_transfer.gd")
	for required in ["get_inventory_model", "remove_from_slot", "add_item"]:
		if not transfer_source.contains(required):
			_errors.append("UIManagerContainerTransfer should own the container transfer operation: %s" % required)


func _open_first_container() -> Dictionary:
	var ui_manager := root.get_node_or_null("UIManager")
	if ui_manager != null and ui_manager.has_method("close_all"):
		ui_manager.close_all()

	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var player := scene.get_node_or_null("Player3D")
	var container := _first_loot_container(scene)
	var container_ui := scene.find_child("ContainerInventoryUI", true, false) as Control
	if player == null:
		_errors.append("Gameplay scene should include Player3D for container transfer validation.")
		_free_node(scene)
		return {}
	if container == null:
		_errors.append("Gameplay scene should include LootContainer3D for container transfer validation.")
		_free_node(scene)
		return {}
	if container_ui == null:
		_errors.append("Gameplay HUD should include ContainerInventoryUI for transfer validation.")
		_free_node(scene)
		return {}
	if not container.try_open(player):
		_errors.append("LootContainer3D should open before transfer validation.")
		_free_node(scene)
		return {}
	await process_frame
	await process_frame
	if ui_manager != null and ui_manager.has_method("get_active_ui") and ui_manager.get_active_ui() != &"container":
		_errors.append("UIManager should be in container state before transfer.")
	return {
		"scene": scene,
		"player": player,
		"container": container,
		"container_ui": container_ui,
	}


func _first_loot_container(scene: Node) -> LootContainer3D:
	for node in scene.find_children("*", "Area3D", true, false):
		if node.get_script() == LootContainerScript:
			return node as LootContainer3D
	return null


func _first_occupied_slot(container_model: RefCounted) -> int:
	var slots: Array = container_model.call("get_slots")
	for index in range(slots.size()):
		var stack: Variant = slots[index]
		if typeof(stack) == TYPE_DICTIONARY and not (stack as Dictionary).is_empty():
			return index
	return -1


func _slots_contain_path(slots: Array, item_path: String) -> bool:
	for stack in slots:
		if typeof(stack) == TYPE_DICTIONARY and str((stack as Dictionary).get("resource_path", "")) == item_path:
			return true
	return false


func _container_slot_text(container_ui: Control) -> String:
	var parts: PackedStringArray = []
	for child in container_ui.find_children("ContainerSlot*", "Button", true, false):
		parts.append((child as Button).text)
	return "\n".join(parts)


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
