extends SceneTree

const PlayerScene := preload("res://scenes/player/player_3d.tscn")
const InventoryEquipmentUIScript := preload("res://scripts/ui/inventory_equipment_ui.gd")
const PlayerQuickBarLayoutScript := preload("res://scripts/ui/player_quick_bar_layout.gd")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")
const CombatKnife := preload("res://data/items/weapons/combat_knife.tres")
const Bandage := preload("res://data/items/medical/bandage.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	await _validate_equipment_double_click_returns_to_backpack()
	await _validate_backpack_double_click_equips_item()
	await _validate_equipment_drag_out_drops_to_world()
	await _validate_quick_slot_drag_out_clears_binding_only()
	_validate_source_contracts()
	if _errors.is_empty():
		print("[inventory_equipment_drag_behaviors] OK equipment=double_click_backpack+world_drop quick_slot=cancel_only")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_equipment_double_click_returns_to_backpack() -> void:
	var context := await _create_context()
	var player: Node = context["player"]
	var inventory_ui: Control = context["inventory_ui"]
	if not _add_and_equip(player, Pistol, &"primary_weapon"):
		_errors.append("Setup should equip pistol into primary weapon.")
		_free_context(context)
		return
	inventory_ui.call("open_inventory")
	await process_frame
	var primary_rect := _equipment_slot_rect(inventory_ui, "primary_weapon")
	_send_left_press(inventory_ui, primary_rect.get_center(), true)
	await process_frame
	var equipment_model: RefCounted = player.call("get_equipment_model")
	if not (equipment_model.call("get_slot", &"primary_weapon") as Dictionary).is_empty():
		_errors.append("Double-clicking equipped primary weapon should unequip it from the slot.")
	if _find_inventory_item_index(player, "pistol_9mm") < 0:
		_errors.append("Double-clicking equipped primary weapon should move it back to backpack.")
	_free_context(context)


func _validate_backpack_double_click_equips_item() -> void:
	var context := await _create_context()
	var player: Node = context["player"]
	var inventory_ui: Control = context["inventory_ui"]
	if not bool(player.call("add_item_resource", Pistol, 1)):
		_errors.append("Setup should add pistol to backpack for double-click equip.")
		_free_context(context)
		return
	inventory_ui.call("open_inventory")
	await process_frame
	var pistol_index := _find_inventory_item_index(player, "pistol_9mm")
	if pistol_index < 0:
		_errors.append("Setup should find pistol in backpack before double-click equip.")
		_free_context(context)
		return
	var backpack_rect := _backpack_stack_rect(inventory_ui, pistol_index)
	_send_left_press(inventory_ui, backpack_rect.get_center(), true)
	await process_frame
	var equipment_model: RefCounted = player.call("get_equipment_model")
	var primary_stack: Dictionary = equipment_model.call("get_slot", &"primary_weapon")
	if str(primary_stack.get("id", "")) != "pistol_9mm":
		_errors.append("Double-clicking an equipable backpack pistol should equip it into primary weapon.")
	if _find_inventory_item_index(player, "pistol_9mm") >= 0:
		_errors.append("Double-clicking an equipable backpack pistol should remove that stack from backpack.")
	_free_context(context)


func _validate_equipment_drag_out_drops_to_world() -> void:
	var context := await _create_context()
	var scene: Node = context["scene"]
	var player: Node = context["player"]
	var inventory_ui: Control = context["inventory_ui"]
	if not _add_and_equip(player, CombatKnife, &"melee"):
		_errors.append("Setup should equip combat knife into melee slot.")
		_free_context(context)
		return
	inventory_ui.call("open_inventory")
	await process_frame
	var before_pickups := _count_pickups(scene, "combat_knife")
	var melee_rect := _equipment_slot_rect(inventory_ui, "melee")
	var outside := Vector2(-180.0, -140.0)
	_send_left_press(inventory_ui, melee_rect.get_center())
	_send_mouse_motion(inventory_ui, outside)
	_send_left_release(inventory_ui, outside)
	await process_frame
	var equipment_model: RefCounted = player.call("get_equipment_model")
	if not (equipment_model.call("get_slot", &"melee") as Dictionary).is_empty():
		_errors.append("Dragging equipped melee weapon outside the UI should remove it from the equipment slot.")
	if _find_inventory_item_index(player, "combat_knife") >= 0:
		_errors.append("Dragging equipped melee weapon outside the UI should drop it, not move it to backpack.")
	if _count_pickups(scene, "combat_knife") <= before_pickups:
		_errors.append("Dragging equipped melee weapon outside the UI should create a world pickup.")
	_free_context(context)


func _validate_quick_slot_drag_out_clears_binding_only() -> void:
	var context := await _create_context()
	var scene: Node = context["scene"]
	var player: Node = context["player"]
	var inventory_ui: Control = context["inventory_ui"]
	if not bool(player.call("add_item_resource", Bandage, 1)):
		_errors.append("Setup should add bandage to backpack.")
		_free_context(context)
		return
	var bandage_index := _find_inventory_item_index(player, "bandage")
	if bandage_index < 0 or not bool(player.call("assign_quick_slot_for_inventory_stack", 3, bandage_index)):
		_errors.append("Setup should bind bandage to quick key 3.")
		_free_context(context)
		return
	inventory_ui.call("open_inventory")
	await process_frame
	var before_pickups := _count_pickups(scene, "bandage")
	var quick_rect := _quick_slot_rect(player, inventory_ui.size, "3")
	var outside := Vector2(-220.0, -160.0)
	_send_left_press(inventory_ui, quick_rect.get_center())
	_send_mouse_motion(inventory_ui, outside)
	_send_left_release(inventory_ui, outside)
	await process_frame
	var quick_state: Dictionary = player.call("get_quick_slot_state", 3)
	if bool(quick_state.get("assigned", false)):
		_errors.append("Dragging quick slot 3 outside the UI should clear only that shortcut binding.")
	if _find_inventory_item_index(player, "bandage") < 0:
		_errors.append("Dragging quick slot 3 outside the UI should not discard the backpack bandage.")
	if _count_pickups(scene, "bandage") != before_pickups:
		_errors.append("Dragging quick slot 3 outside the UI should not create a world pickup.")
	_free_context(context)


func _validate_source_contracts() -> void:
	var inventory_source := FileAccess.get_file_as_string("res://scripts/ui/inventory_equipment_ui.gd")
	for required in ["event.double_click", "_drop_dragged_equipment_to_world", "clear_quick_slot_for_key"]:
		if not inventory_source.contains(required):
			_errors.append("InventoryEquipmentUI should preserve drag/double-click behavior through %s." % required)
	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	if not player_source.contains("drop_equipment_slot") or not player_source.contains("_selected_quick_item_stack"):
		_errors.append("PlayerController3D should expose equipment world-drop and held quick-item state.")
	var drop_source := FileAccess.get_file_as_string("res://scripts/ui/inventory_drop_controller.gd")
	if not drop_source.contains("drop_equipment_stack_at"):
		_errors.append("InventoryDropController should own equipped-item world pickup spawning.")


func _create_context() -> Dictionary:
	var scene := Node3D.new()
	scene.name = "InventoryEquipmentDragBehaviorScene"
	root.add_child(scene)
	current_scene = scene
	var player := PlayerScene.instantiate()
	scene.add_child(player)
	var inventory_ui := InventoryEquipmentUIScript.new()
	inventory_ui.size = Vector2(1280.0, 720.0)
	scene.add_child(inventory_ui)
	await process_frame
	await physics_frame
	return {
		"scene": scene,
		"player": player,
		"inventory_ui": inventory_ui,
	}


func _add_and_equip(player: Node, item_def: ItemDef, slot_id: StringName) -> bool:
	if not bool(player.call("add_item_resource", item_def, 1)):
		return false
	var index := _find_inventory_item_index(player, str(item_def.id))
	return index >= 0 and bool(player.call("equip_inventory_stack", index, slot_id))


func _equipment_slot_rect(inventory_ui: Control, slot_id: String) -> Rect2:
	var state: Dictionary = inventory_ui.call("get_display_state")
	var rects: Dictionary = state.get("equipment_slot_rects", {})
	return rects.get(slot_id, Rect2())


func _backpack_stack_rect(inventory_ui: Control, stack_index: int) -> Rect2:
	inventory_ui.call("_update_layout_scale", inventory_ui.size)
	var panel_rect: Rect2 = inventory_ui.call("_panel_rect")
	var layout: RefCounted = inventory_ui.get("_layout")
	var backpack_rect: Rect2 = layout.call("backpack_rect", panel_rect)
	return inventory_ui.call("_backpack_slot_rect", backpack_rect, stack_index)


func _quick_slot_rect(player: Node, viewport_size: Vector2, key_label: String) -> Rect2:
	var slots: Array = player.call("get_quick_bar_state")
	var rects: Array[Rect2] = PlayerQuickBarLayoutScript.slot_rects(viewport_size, slots)
	for index in range(mini(slots.size(), rects.size())):
		var state := slots[index] as Dictionary
		if str(state.get("key_label", "")) == key_label:
			return rects[index]
	return Rect2()


func _find_inventory_item_index(player: Node, item_id: String) -> int:
	var inventory_model: RefCounted = player.call("get_inventory_model")
	var stacks: Array = inventory_model.get("stacks")
	for index in range(stacks.size()):
		var stack := stacks[index] as Dictionary
		if str(stack.get("id", "")) == item_id:
			return index
	return -1


func _count_pickups(node: Node, item_id: String) -> int:
	var total := 0
	var item_def: Variant = node.get("item_def")
	if item_def is ItemDef and str((item_def as ItemDef).id) == item_id:
		total += 1
	for child in node.get_children():
		total += _count_pickups(child, item_id)
	return total


func _send_left_press(control: Control, position: Vector2, double_click := false) -> void:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.global_position = position
	event.double_click = double_click
	control.call("_gui_input", event)


func _send_left_release(control: Control, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.pressed = false
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.global_position = position
	control.call("_gui_input", event)


func _send_mouse_motion(control: Control, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	control.call("_gui_input", event)


func _free_context(context: Dictionary) -> void:
	var scene: Node = context.get("scene", null)
	if current_scene == scene:
		current_scene = null
	if scene == null:
		return
	if scene.get_parent() != null:
		scene.get_parent().remove_child(scene)
	scene.free()
