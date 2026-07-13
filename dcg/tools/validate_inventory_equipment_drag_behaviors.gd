extends SceneTree

const PlayerScene := preload("res://scenes/player/player_3d.tscn")
const InventoryEquipmentUIScript := preload("res://scripts/ui/inventory_equipment_ui.gd")
const PlayerQuickBarLayoutScript := preload("res://scripts/ui/player_quick_bar_layout.gd")
const Pistol := preload("res://data/items/weapons/pistol_S.tres")
const Smg := preload("res://data/items/weapons/smg_S.tres")
const CombatKnife := preload("res://data/items/weapons/combat_knife.tres")
const Bandage := preload("res://data/items/medical/bandage.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	await _validate_equipment_double_click_returns_to_backpack()
	await _validate_backpack_double_click_equips_item()
	await _validate_weapon_single_click_opens_mod_without_blocking_drag()
	await _validate_backpack_item_single_click_opens_detail_panel()
	await _validate_safe_pocket_single_click_details_double_click_returns_to_backpack()
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
	if _find_inventory_item_index(player, "pistol_S") < 0:
		_errors.append("Double-clicking equipped primary weapon should move it back to backpack.")
	_free_context(context)


func _validate_backpack_double_click_equips_item() -> void:
	var context := await _create_context()
	var player: Node = context["player"]
	var inventory_ui: Control = context["inventory_ui"]
	var setup_equipment: RefCounted = player.call("get_equipment_model")
	setup_equipment.call("unequip", &"primary_weapon")
	setup_equipment.call("unequip", &"sidearm")
	if not bool(player.call("add_item_resource", Smg, 1)):
		_errors.append("Setup should add SMG to backpack for double-click equip.")
		_free_context(context)
		return
	inventory_ui.call("open_inventory")
	await process_frame
	var smg_index := _find_inventory_item_index(player, "smg_S")
	if smg_index < 0:
		_errors.append("Setup should find SMG in backpack before double-click equip.")
		_free_context(context)
		return
	var smg_count_before := _inventory_item_quantity(player, "smg_S")
	var backpack_rect := _backpack_stack_rect(inventory_ui, smg_index)
	_send_left_press(inventory_ui, backpack_rect.get_center(), true)
	await process_frame
	var equipment_model: RefCounted = player.call("get_equipment_model")
	var primary_stack: Dictionary = equipment_model.call("get_slot", &"primary_weapon")
	var sidearm_stack: Dictionary = equipment_model.call("get_slot", &"sidearm")
	if str(primary_stack.get("id", "")) != "smg_S" and str(sidearm_stack.get("id", "")) != "smg_S":
		_errors.append("Double-clicking an equipable backpack SMG should equip it into a weapon slot.")
	if _inventory_item_quantity(player, "smg_S") >= smg_count_before:
		_errors.append("Double-clicking an equipable backpack SMG should remove one matching stack from backpack.")
	_free_context(context)


func _validate_weapon_single_click_opens_mod_without_blocking_drag() -> void:
	var context := await _create_context()
	var scene: Node = context["scene"]
	var player: Node = context["player"]
	var inventory_ui: Control = context["inventory_ui"]
	if not bool(player.call("add_item_resource", Pistol, 1)):
		_errors.append("Setup should add pistol to backpack for single-click mod panel.")
		_free_context(context)
		return
	inventory_ui.call("open_inventory")
	await process_frame
	var pistol_index := _find_inventory_item_index(player, "pistol_S")
	if pistol_index < 0:
		_errors.append("Setup should find pistol in backpack before single-click mod panel.")
		_free_context(context)
		return
	var before_pickups := _count_pickups(scene, "pistol_S")
	var backpack_rect := _backpack_stack_rect(inventory_ui, pistol_index)
	var outside := Vector2(-240.0, -180.0)
	_send_left_press(inventory_ui, backpack_rect.get_center())
	await process_frame
	var state: Dictionary = inventory_ui.call("get_display_state")
	var panel_state: Dictionary = state.get("weapon_mod_panel", {})
	if not bool(panel_state.get("has_weapon", false)):
		_errors.append("Single-clicking a backpack weapon should open the weapon mod panel.")
	var mod_rect: Rect2 = state.get("weapon_mod_panel_rect", Rect2())
	var inventory_panel_rect: Rect2 = state.get("panel_rect", Rect2())
	var viewport_size: Vector2 = state.get("viewport_size", inventory_ui.size)
	if mod_rect.position.y < viewport_size.y * 0.25:
		_errors.append("Weapon mod panel should stay in the lower center safe area instead of overlapping the top UI.")
	if mod_rect.position.x < inventory_panel_rect.end.x + 20.0:
		_errors.append("Weapon mod panel should not overlap the normal inventory panel.")
	if mod_rect.end.x > viewport_size.x - 20.0:
		_errors.append("Weapon mod panel should stay within the viewport safe area.")
	var weapon_mod_panel: RefCounted = inventory_ui.get("_weapon_mod_panel")
	var before_scroll := int(weapon_mod_panel.get("detail_scroll_row"))
	if not bool(inventory_ui.call("scroll_weapon_mod_details_at", mod_rect.get_center(), 1)):
		_errors.append("Weapon mod panel should accept wheel scrolling inside its panel rect.")
	var after_scroll := int(weapon_mod_panel.get("detail_scroll_row"))
	if after_scroll <= before_scroll:
		_errors.append("Weapon mod panel wheel scrolling should move the detail scroll row.")
	var empty_slot_index := _first_empty_backpack_slot_index(inventory_ui)
	if empty_slot_index < 0:
		_errors.append("Validation setup should expose an empty backpack slot.")
	else:
		_send_left_press(inventory_ui, _backpack_stack_rect(inventory_ui, empty_slot_index).get_center())
		await process_frame
		state = inventory_ui.call("get_display_state")
		panel_state = state.get("weapon_mod_panel", {})
		if bool(panel_state.get("has_weapon", false)):
			_errors.append("Clicking an empty backpack slot should close the weapon mod panel.")
		_send_left_press(inventory_ui, backpack_rect.get_center())
		await process_frame
	_send_mouse_motion(inventory_ui, outside)
	_send_left_release(inventory_ui, outside)
	await process_frame
	if _find_inventory_item_index(player, "pistol_S") >= 0:
		_errors.append("Dragging a single-clicked backpack weapon outside the UI should still remove it from backpack.")
	if _count_pickups(scene, "pistol_S") <= before_pickups:
		_errors.append("Dragging a single-clicked backpack weapon outside the UI should still create a world pickup.")
	_free_context(context)


func _validate_backpack_item_single_click_opens_detail_panel() -> void:
	var context := await _create_context()
	var player: Node = context["player"]
	var inventory_ui: Control = context["inventory_ui"]
	if not bool(player.call("add_item_resource", Bandage, 1)):
		_errors.append("Setup should add bandage to backpack for item detail panel.")
		_free_context(context)
		return
	inventory_ui.call("open_inventory")
	await process_frame
	var bandage_index := _find_inventory_item_index(player, "bandage")
	if bandage_index < 0:
		_errors.append("Setup should find bandage in backpack before item detail panel click.")
		_free_context(context)
		return
	var backpack_rect := _backpack_stack_rect(inventory_ui, bandage_index)
	_send_left_press(inventory_ui, backpack_rect.get_center())
	await process_frame
	var state: Dictionary = inventory_ui.call("get_display_state")
	var detail_state: Dictionary = state.get("item_detail_panel", {})
	if detail_state.is_empty():
		_errors.append("Single-clicking a non-weapon backpack item should open the central item detail panel.")
	var catalog_number := int(detail_state.get("catalog_number", 0))
	var item_detail_panel: RefCounted = inventory_ui.get("_item_detail_panel")
	var display_lines: Array = item_detail_panel.call("_display_lines", catalog_number)
	if catalog_number > 0 and display_lines.has("#%d" % catalog_number):
		_errors.append("Item detail panel body should not repeat the catalog number already shown in the header.")
	var detail_text := str(state.get("item_detail_panel_text", ""))
	if not detail_text.contains(TranslationServer.translate("item.bandage.name")):
		_errors.append("Item detail panel should reuse localized item tooltip text.")
	var detail_rect: Rect2 = state.get("item_detail_panel_rect", Rect2())
	var inventory_panel_rect: Rect2 = state.get("panel_rect", Rect2())
	if detail_rect.size.x <= 0.0 or detail_rect.position.x < inventory_panel_rect.end.x + 20.0:
		_errors.append("Item detail panel should reserve the center area outside the left inventory panel.")
	var weapon_mod_panel: RefCounted = inventory_ui.get("_weapon_mod_panel")
	var expected_rect: Rect2 = weapon_mod_panel.call("panel_rect", inventory_ui.get("_ui_scale"), inventory_ui.get("_layout_viewport_size"))
	if detail_rect != expected_rect:
		_errors.append("Item detail panel should use the same centered backing rect as the weapon mod panel.")
	var empty_slot_index := _first_empty_backpack_slot_index(inventory_ui)
	if empty_slot_index < 0:
		_errors.append("Validation setup should expose an empty backpack slot for closing item detail.")
	else:
		_send_left_press(inventory_ui, _backpack_stack_rect(inventory_ui, empty_slot_index).get_center())
		await process_frame
		state = inventory_ui.call("get_display_state")
		if not (state.get("item_detail_panel", {}) as Dictionary).is_empty():
			_errors.append("Clicking an empty backpack slot should close the item detail panel.")
	_free_context(context)


func _validate_safe_pocket_single_click_details_double_click_returns_to_backpack() -> void:
	var context := await _create_context()
	var player: Node = context["player"]
	var inventory_ui: Control = context["inventory_ui"]
	if not bool(player.call("add_item_resource", Bandage, 1)):
		_errors.append("Setup should add bandage to backpack for safe pocket double-click return.")
		_free_context(context)
		return
	if not bool(player.call("move_inventory_stack_to_safe_pocket", 0)):
		_errors.append("Setup should move bandage into safe pocket.")
		_free_context(context)
		return
	inventory_ui.call("open_inventory")
	await process_frame
	var safe_rect := _safe_pocket_slot_rect(inventory_ui, 0)
	_send_left_press(inventory_ui, safe_rect.get_center())
	_send_left_release(inventory_ui, safe_rect.get_center())
	await process_frame
	if _safe_pocket_item_quantity(player, "bandage") != 1:
		_errors.append("Single-clicking safe pocket item should not move it back to backpack.")
	if _inventory_item_quantity(player, "bandage") != 0:
		_errors.append("Single-clicking safe pocket item should only open details, not add backpack quantity.")
	var state: Dictionary = inventory_ui.call("get_display_state")
	if (state.get("item_detail_panel", {}) as Dictionary).is_empty():
		_errors.append("Single-clicking safe pocket item should open the central item detail panel.")
	if not bool(player.call("can_move_safe_pocket_stack_to_inventory", 0)):
		_errors.append("Player model should allow safe pocket item to return to backpack before double-click.")
	safe_rect = _safe_pocket_slot_rect(inventory_ui, 0)
	_send_left_press(inventory_ui, safe_rect.get_center(), true)
	_send_left_release(inventory_ui, safe_rect.get_center())
	await process_frame
	if _safe_pocket_item_quantity(player, "bandage") != 0:
		_errors.append("Double-clicking safe pocket item should remove it from safe pocket.")
	if _inventory_item_quantity(player, "bandage") != 1:
		_errors.append("Double-clicking safe pocket item should move it back to backpack.")
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
	var before_backpack_knives := _inventory_item_quantity(player, "combat_knife")
	var melee_rect := _equipment_slot_rect(inventory_ui, "melee")
	var outside := Vector2(-180.0, -140.0)
	_send_left_press(inventory_ui, melee_rect.get_center())
	_send_mouse_motion(inventory_ui, outside)
	_send_left_release(inventory_ui, outside)
	await process_frame
	var equipment_model: RefCounted = player.call("get_equipment_model")
	if not (equipment_model.call("get_slot", &"melee") as Dictionary).is_empty():
		_errors.append("Dragging equipped melee weapon outside the UI should remove it from the equipment slot.")
	if _inventory_item_quantity(player, "combat_knife") > before_backpack_knives:
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
	inventory_source += FileAccess.get_file_as_string("res://scripts/ui/inventory_equipment_input_router.gd")
	inventory_source += FileAccess.get_file_as_string("res://scripts/ui/inventory_equipment_drag_support.gd")
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


func _safe_pocket_slot_rect(inventory_ui: Control, slot_index: int) -> Rect2:
	inventory_ui.call("_update_layout_scale", inventory_ui.size)
	var panel_rect: Rect2 = inventory_ui.call("_panel_rect")
	var layout: RefCounted = inventory_ui.get("_layout")
	var safe_rect: Rect2 = layout.call("safe_pocket_rect", panel_rect, int(inventory_ui.call("_get_safe_pocket_slots")))
	return inventory_ui.call("_safe_pocket_slot_rect", safe_rect, slot_index)


func _first_empty_backpack_slot_index(inventory_ui: Control) -> int:
	var state: Dictionary = inventory_ui.call("get_display_state")
	var used := (state.get("backpack_items", []) as Array).size()
	var slots := int(state.get("backpack_slots", 0))
	if used >= slots:
		return -1
	return used


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


func _inventory_item_quantity(player: Node, item_id: String) -> int:
	var inventory_model: RefCounted = player.call("get_inventory_model")
	var stacks: Array = inventory_model.get("stacks")
	var total := 0
	for stack_value in stacks:
		var stack := stack_value as Dictionary
		if str(stack.get("id", "")) == item_id:
			total += int(stack.get("quantity", 1))
	return total


func _safe_pocket_item_quantity(player: Node, item_id: String) -> int:
	var safe_pocket_model: RefCounted = player.call("get_safe_pocket_model")
	var stacks: Array = safe_pocket_model.get("stacks")
	var total := 0
	for stack_value in stacks:
		var stack := stack_value as Dictionary
		if str(stack.get("id", "")) == item_id:
			total += int(stack.get("quantity", 1))
	return total


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
