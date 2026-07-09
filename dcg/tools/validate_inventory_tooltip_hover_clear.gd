extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const Wood := preload("res://data/items/crafting/wood.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	await _validate_hover_tooltip_resolves_only_under_item()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[inventory_tooltip_hover_clear] OK hover=item_only stale_position=cleared redraw=tracks_current_mouse boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_hover_tooltip_resolves_only_under_item() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var player := scene.get_node_or_null("Player3D")
	var inventory_ui := scene.find_child("InventoryEquipmentUI", true, false) as Control
	if player == null or inventory_ui == null:
		_errors.append("Gameplay scene should include Player3D and InventoryEquipmentUI.")
		_free_node(scene)
		return
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	backpack_model.clear()
	backpack_model.setup(50)
	backpack_model.add_stack(Wood.to_stack(1))
	inventory_ui.call("open_inventory")
	await process_frame
	var display_state: Dictionary = inventory_ui.call("get_display_state_for_viewport", Vector2(1920.0, 1080.0))
	var panel_rect: Rect2 = display_state.get("panel_rect", Rect2())
	var backpack_position := _find_hover_position(inventory_ui, panel_rect)
	var empty_position := Vector2(1100.0, 540.0)
	var item_tooltip: Dictionary = inventory_ui.call("get_hover_item_tooltip_for_position", backpack_position)
	if item_tooltip.is_empty():
		_errors.append("Inventory hover tooltip should resolve the item under the cursor.")
	var empty_tooltip: Dictionary = inventory_ui.call("get_hover_item_tooltip_for_position", empty_position)
	if not empty_tooltip.is_empty():
		_errors.append("Inventory hover tooltip should clear when the cursor is away from item slots.")
	_free_node(scene)


func _find_hover_position(inventory_ui: Control, panel_rect: Rect2) -> Vector2:
	for y in range(int(panel_rect.position.y), int(panel_rect.end.y), 24):
		for x in range(int(panel_rect.position.x), int(panel_rect.end.x), 24):
			var position := Vector2(float(x), float(y))
			var tooltip: Dictionary = inventory_ui.call("get_hover_item_tooltip_for_position", position)
			if not tooltip.is_empty():
				return position
	return panel_rect.position


func _validate_source_boundaries() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/inventory_equipment_ui.gd")
	for required in ["func _process", "_current_mouse_position", "get_local_mouse_position", "_draw_hover_tooltip(_current_mouse_position())"]:
		if not source.contains(required):
			_errors.append("InventoryEquipmentUI should track current mouse position for hover tooltip clearing: %s." % required)
	if source.contains("_draw_hover_tooltip(_last_mouse_position)"):
		_errors.append("InventoryEquipmentUI should not draw hover tooltips from stale _last_mouse_position.")


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
