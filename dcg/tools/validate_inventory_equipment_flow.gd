extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")
const Ammo := preload("res://data/items/ammo/ammo_9mm.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	await _validate_backpack_pistol_equips_to_visible_slot()
	await _validate_drag_pistol_to_primary_weapon_slot()
	await _validate_ammo_stays_in_backpack()
	await _validate_weight_panel_binding()
	await _validate_backpack_organize_button()
	await _validate_layout_fit(Vector2i(1280, 720))
	await _validate_layout_fit(Vector2i(1920, 1080))
	_validate_player_visible_ui_path()
	_validate_responsibility_boundary()
	if _errors.is_empty():
		print("[inventory_equipment_flow] OK backpack=visible equip=primary_weapon ammo=rejected layout=fit boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_backpack_pistol_equips_to_visible_slot() -> void:
	var context := await _spawn_inventory_context()
	if context.is_empty():
		return
	var player: Node = context["player"]
	var inventory_ui: Control = context["inventory_ui"]
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	var equipment_model: RefCounted = player.call("get_equipment_model")

	backpack_model.add_item(Pistol, 1)
	inventory_ui.call("open_inventory")
	await process_frame

	var before_state: Dictionary = inventory_ui.call("get_display_state")
	if not _state_has_catalog(before_state.get("backpack_items", []), 5):
		_errors.append("Inventory UI should visibly show No.5 pistol in backpack before equip.")
	var backpack_tooltip_text := _tooltip_text(inventory_ui.call("get_item_tooltip_by_path", Pistol.resource_path) as Dictionary)
	if not backpack_tooltip_text.contains(_item_name(Pistol)):
		_errors.append("Inventory UI tooltip should show the localized pistol name.")
	if not backpack_tooltip_text.contains(TranslationServer.translate("ui.item.damage_format") % Pistol.damage):
		_errors.append("Inventory UI tooltip should show pistol damage.")
	if not backpack_tooltip_text.contains(TranslationServer.translate("ui.item.magazine_format") % Pistol.magazine_capacity):
		_errors.append("Inventory UI tooltip should show pistol magazine capacity.")
	var panel_rect: Rect2 = before_state.get("panel_rect", Rect2())
	var backpack_start := panel_rect.position + Vector2(24.0, 415.0) + Vector2(28.0, 64.0)
	var backpack_slot_center := backpack_start + Vector2(75.0, 75.0) * 0.5
	var hover_backpack_text := _tooltip_text(inventory_ui.call("get_hover_item_tooltip_for_position", backpack_slot_center) as Dictionary)
	if not hover_backpack_text.contains(_item_name(Pistol)):
		_errors.append("Inventory UI hover tooltip should resolve backpack items.")
	if not bool(player.call("can_equip_inventory_stack", 0)):
		_errors.append("Player should report the visible pistol stack as equippable.")
	if not bool(inventory_ui.call("equip_backpack_stack", 0)):
		_errors.append("Inventory UI should let the player equip the visible pistol stack.")
	await process_frame

	var after_state: Dictionary = inventory_ui.call("get_display_state")
	var primary_stack: Dictionary = equipment_model.call("get_slot", &"primary_weapon")
	if _state_has_catalog(after_state.get("backpack_items", []), 5):
		_errors.append("Equipped No.5 pistol should leave the backpack list.")
	if int(primary_stack.get("catalog_number", 0)) != 5:
		_errors.append("Equipped No.5 pistol should appear in the primary weapon equipment slot.")
	if not str(after_state.get("equipment_text", "")).contains(_item_name(Pistol)):
		_errors.append("Equipment panel should visibly show the equipped pistol name.")
	var rects: Dictionary = after_state.get("equipment_slot_rects", {})
	var primary_rect: Rect2 = rects.get("primary_weapon", Rect2())
	var hover_equipment_text := _tooltip_text(inventory_ui.call("get_hover_item_tooltip_for_position", primary_rect.get_center()) as Dictionary)
	if not hover_equipment_text.contains(_item_name(Pistol)):
		_errors.append("Inventory UI hover tooltip should resolve equipped items.")

	_free_node(context["scene"])


func _validate_drag_pistol_to_primary_weapon_slot() -> void:
	root.size = Vector2i(1920, 1080)
	var context := await _spawn_inventory_context()
	if context.is_empty():
		return
	var player: Node = context["player"]
	var inventory_ui: Control = context["inventory_ui"]
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	var equipment_model: RefCounted = player.call("get_equipment_model")

	backpack_model.add_item(Pistol, 1)
	inventory_ui.call("open_inventory")
	await process_frame

	var state: Dictionary = inventory_ui.call("get_display_state_for_viewport", Vector2(1920.0, 1080.0))
	var rects: Dictionary = state.get("equipment_slot_rects", {})
	var primary_rect: Rect2 = rects.get("primary_weapon", Rect2())
	if primary_rect.size == Vector2.ZERO:
		_errors.append("Inventory UI should expose a primary weapon slot rect for drag equipment validation.")
		_free_node(context["scene"])
		return

	var panel_rect: Rect2 = state.get("panel_rect", Rect2())
	var backpack_start := panel_rect.position + Vector2(24.0, 415.0) + Vector2(28.0, 64.0)
	var backpack_slot_center := backpack_start + Vector2(75.0, 75.0) * 0.5
	var primary_slot_center := primary_rect.get_center()

	_send_mouse_button(inventory_ui, backpack_slot_center, true)
	_send_mouse_motion(inventory_ui, primary_slot_center)
	_send_mouse_button(inventory_ui, primary_slot_center, false)
	await process_frame

	var primary_stack: Dictionary = equipment_model.call("get_slot", &"primary_weapon")
	if int(primary_stack.get("catalog_number", 0)) != 5:
		_errors.append("Dragging No.5 pistol onto the primary weapon slot should equip it there.")
	if _state_has_catalog(backpack_model.get_display_items(), 5):
		_errors.append("Dragged No.5 pistol should leave backpack after primary weapon equip.")

	_free_node(context["scene"])


func _validate_ammo_stays_in_backpack() -> void:
	var context := await _spawn_inventory_context()
	if context.is_empty():
		return
	var player: Node = context["player"]
	var inventory_ui: Control = context["inventory_ui"]
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	var equipment_model: RefCounted = player.call("get_equipment_model")

	backpack_model.add_item(Ammo, 24)
	inventory_ui.call("open_inventory")
	await process_frame

	if bool(player.call("can_equip_inventory_stack", 0)):
		_errors.append("No.7 ammo should not be treated as equippable gear.")
	if bool(inventory_ui.call("equip_backpack_stack", 0)):
		_errors.append("Inventory UI should reject equipping No.7 ammo as gear.")
	await process_frame

	var state: Dictionary = inventory_ui.call("get_display_state")
	if not _state_has_catalog(state.get("backpack_items", []), 7):
		_errors.append("Rejected No.7 ammo should remain visible in the backpack.")
	if not _equipment_slots_are_empty(equipment_model):
		_errors.append("Rejected ammo equip should not alter equipment slots.")

	_free_node(context["scene"])


func _validate_weight_panel_binding() -> void:
	var context := await _spawn_inventory_context()
	if context.is_empty():
		return
	var player: Node = context["player"]
	var inventory_ui: Control = context["inventory_ui"]
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	var equipment_model: RefCounted = player.call("get_equipment_model")

	backpack_model.add_item(Pistol, 1)
	backpack_model.add_item(Ammo, 24)
	inventory_ui.call("open_inventory")
	await process_frame

	var before_state: Dictionary = inventory_ui.call("get_display_state")
	if str(before_state.get("weight_label", "")) != str(TranslationServer.translate("ui.inventory.load")):
		_errors.append("Inventory UI weight panel should use the localized carry-weight label.")
	if str(before_state.get("weight_label", "")).contains("裝備"):
		_errors.append("Inventory UI weight panel should not be mislabeled as equipment.")
	var expected_before_weight: float = backpack_model.get_total_weight()
	if not is_equal_approx(float(before_state.get("current_weight", -1.0)), expected_before_weight):
		_errors.append("Inventory UI weight panel should read the player's current backpack weight before equip.")

	if not bool(player.call("equip_inventory_stack", 0, &"primary_weapon")):
		_errors.append("Player should equip pistol for carry-weight binding validation.")
		_free_node(context["scene"])
		return
	await process_frame

	var after_state: Dictionary = inventory_ui.call("get_display_state")
	var expected_after_weight: float = backpack_model.get_total_weight()
	for stack_value in equipment_model.call("get_slots").values():
		if typeof(stack_value) == TYPE_DICTIONARY:
			var stack := stack_value as Dictionary
			expected_after_weight += float(stack.get("weight", 0.0)) * float(stack.get("quantity", 1))
	if not is_equal_approx(float(after_state.get("current_weight", -1.0)), expected_after_weight):
		_errors.append("Inventory UI weight panel should include equipped item weight through player carry weight.")
	if not str(after_state.get("weight_text", "")).contains("kg"):
		_errors.append("Inventory UI weight panel should show kg units.")

	_free_node(context["scene"])


func _validate_backpack_organize_button() -> void:
	var context := await _spawn_inventory_context()
	if context.is_empty():
		return
	var player: Node = context["player"]
	var inventory_ui: Control = context["inventory_ui"]
	var backpack_model: InventoryModel = player.call("get_inventory_model")

	backpack_model.add_item(Pistol, 1)
	backpack_model.add_item(Ammo, 24)
	inventory_ui.call("open_inventory")
	await process_frame

	var state: Dictionary = inventory_ui.call("get_display_state")
	if str(state.get("sort_button_text", "")) != str(TranslationServer.translate("ui.inventory.sort")):
		_errors.append("Inventory UI organize control should show the fixed localized organize label.")
	if state.has("next_sort_mode"):
		_errors.append("Inventory UI organize control should not expose rotating sort mode state.")
	if bool(state.get("store_all_button_visible", true)):
		_errors.append("Normal Tab inventory should not show the warehouse-only All Store action.")

	inventory_ui.call("organize_backpack")
	await process_frame
	var organized_state: Dictionary = inventory_ui.call("get_display_state")
	var organized_items: Array = organized_state.get("backpack_items", []) as Array
	if str(organized_state.get("sort_button_text", "")) != str(TranslationServer.translate("ui.inventory.sort")):
		_errors.append("Inventory UI organize button text should stay fixed after organizing.")
	if organized_items.is_empty() or int((organized_items[0] as Dictionary).get("catalog_number", 0)) != Ammo.catalog_number:
		_errors.append("Inventory UI organize action should group backpack items by type.")

	inventory_ui.call("organize_backpack", &"weight")
	await process_frame
	var weight_state: Dictionary = inventory_ui.call("get_display_state")
	var weight_items: Array = weight_state.get("backpack_items", []) as Array
	if weight_items.is_empty() or int((weight_items[0] as Dictionary).get("catalog_number", 0)) != Pistol.catalog_number:
		_errors.append("Inventory UI explicit weight organize call should still support validator/debug use.")

	_free_node(context["scene"])


func _validate_layout_fit(size: Vector2i) -> void:
	root.size = size
	var context := await _spawn_inventory_context()
	if context.is_empty():
		return
	var inventory_ui: Control = context["inventory_ui"]
	inventory_ui.call("open_inventory")
	await process_frame
	var state: Dictionary = inventory_ui.call("get_display_state_for_viewport", Vector2(size))
	var rect: Rect2 = state.get("panel_rect", Rect2())
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		_errors.append("Inventory UI should expose a measurable panel rect at %s." % str(size))
	if rect.position.x < -1.0 or rect.position.y < -1.0 or rect.end.x > float(size.x) + 1.0 or rect.end.y > float(size.y) + 1.0:
		_errors.append("Inventory UI panel should fit within %s, got %s." % [str(size), str(rect)])
	_free_node(context["scene"])


func _validate_player_visible_ui_path() -> void:
	var ui_source := FileAccess.get_file_as_string("res://scripts/ui/inventory_equipment_ui.gd")
	for required in [
		"equip_backpack_stack",
		"get_equipment_model",
		"get_equipment_stack_at",
		"InventoryGridMetricsScript",
	]:
		if not ui_source.contains(required):
			_errors.append("Inventory UI should expose visible equip flow term: %s." % required)

	var menu_source := FileAccess.get_file_as_string("res://scripts/ui/inventory_context_menu.gd")
	for required in ["drop_requested", "ui.inventory.split", "ui.inventory.drop"]:
		if not menu_source.contains(required):
			_errors.append("Inventory context menu should expose expected right-click action term: %s." % required)
	for forbidden in ["equip_requested", "ui.inventory.equip", "can_equip_stack", "equip_rect"]:
		if menu_source.contains(forbidden):
			_errors.append("Inventory context menu should not expose removed equip action term: %s." % forbidden)


func _validate_responsibility_boundary() -> void:
	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	for required in ["get_equipment_model", "can_equip_inventory_stack", "equip_inventory_stack", "get_default_equipment_slot_for_stack"]:
		if not player_source.contains(required):
			_errors.append("PlayerController3D should bridge inventory-to-equipment flow: %s." % required)

	var inventory_source := FileAccess.get_file_as_string("res://scripts/inventory/inventory_model.gd")
	for forbidden in ["EquipmentModel", "WeaponController3D", "InventoryEquipmentUI", "PlayerController3D"]:
		if inventory_source.contains(forbidden):
			_errors.append("InventoryModel should stay independent from equipment/UI/combat/player: %s." % forbidden)

	var equipment_source := FileAccess.get_file_as_string("res://scripts/equipment/equipment_model.gd")
	for forbidden in ["Control", "InventoryEquipmentUI", "PlayerController3D", "WeaponController3D", "UIManager"]:
		if equipment_source.contains(forbidden):
			_errors.append("EquipmentModel should stay data-only and independent from %s." % forbidden)


func _spawn_inventory_context() -> Dictionary:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var player := scene.get_node_or_null("Player3D")
	var inventory_ui := scene.find_child("InventoryEquipmentUI", true, false) as Control
	if player == null:
		_errors.append("Gameplay scene should include Player3D for inventory equipment flow.")
		_free_node(scene)
		return {}
	if inventory_ui == null:
		_errors.append("Gameplay scene should include InventoryEquipmentUI for visible equipment flow.")
		_free_node(scene)
		return {}
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	var equipment_model: RefCounted = player.call("get_equipment_model")
	backpack_model.clear()
	backpack_model.setup(50)
	equipment_model.clear()
	await process_frame
	return {
		"scene": scene,
		"player": player,
		"inventory_ui": inventory_ui,
	}


func _state_has_catalog(items: Variant, catalog_number: int) -> bool:
	if typeof(items) != TYPE_ARRAY:
		return false
	for item in items:
		if typeof(item) == TYPE_DICTIONARY and int((item as Dictionary).get("catalog_number", 0)) == catalog_number:
			return true
	return false


func _equipment_slots_are_empty(equipment_model: RefCounted) -> bool:
	var slots: Dictionary = equipment_model.call("get_slots")
	for stack in slots.values():
		if typeof(stack) == TYPE_DICTIONARY and not (stack as Dictionary).is_empty():
			return false
	return true


func _item_name(item_def: ItemDef) -> String:
	var key := str(item_def.name_key)
	var translated := tr(key)
	return translated if translated != key else item_def.display_name


func _tooltip_text(tooltip: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append(str(tooltip.get("title", "")))
	for line in tooltip.get("lines", []) as Array:
		parts.append(str(line))
	var result := ""
	for index in range(parts.size()):
		if index > 0:
			result += "\n"
		result += parts[index]
	return result


func _send_mouse_button(target: Control, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	target.call("_gui_input", event)


func _send_mouse_motion(target: Control, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	target.call("_gui_input", event)


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
