class_name InventoryContextMenu
extends RefCounted

const UISurfacePaletteScript := preload("res://scripts/ui/ui_surface_palette.gd")

signal use_requested(stack_index: int)
signal unload_ammo_requested(stack_index: int)
signal drop_requested(stack_index: int, stack: Dictionary, screen_position: Vector2, random_near_player: bool)
signal equipment_unload_ammo_requested(slot_id: StringName)
signal equipment_drop_requested(slot_id: StringName, screen_position: Vector2)

var owner: Control
var painter: InventoryEquipmentPainter
var backpack_model: InventoryModel
var ui_scale: float = 1.0
var stack_index: int = -1
var equipment_slot_id: StringName = &""
var menu_position: Vector2 = Vector2.ZERO
var menu_size: Vector2 = Vector2(148.0, 140.0)
var use_rect: Rect2 = Rect2()
var unload_ammo_rect: Rect2 = Rect2()
var split_rect: Rect2 = Rect2()
var drop_rect: Rect2 = Rect2()
var split_stack_index: int = -1
var split_quantity: int = 1
var dialog_rect: Rect2 = Rect2()
var slider_rect: Rect2 = Rect2()
var confirm_rect: Rect2 = Rect2()
var cancel_rect: Rect2 = Rect2()
var is_adjusting_slider: bool = false


func setup(source_owner: Control, source_painter: InventoryEquipmentPainter, source_model: InventoryModel) -> void:
	owner = source_owner
	painter = source_painter
	backpack_model = source_model


func set_model(source_model: InventoryModel) -> void:
	backpack_model = source_model


func set_scale(value: float) -> void:
	ui_scale = value


func handle_mouse_motion(event: InputEventMouseMotion) -> bool:
	if not is_adjusting_slider:
		return false
	_update_split_quantity_from_position(event.position)
	return true


func handle_mouse_button(event: InputEventMouseButton, hit_stack_index: int, backpack_items: Array[Dictionary], backpack_slots: int) -> bool:
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if equipment_slot_id != &"":
			close_context_menu()
		elif hit_stack_index >= 0 and hit_stack_index < backpack_items.size():
			open_context_menu(hit_stack_index, event.position, backpack_items, backpack_slots)
		else:
			close_context_menu()
		return true

	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and is_split_dialog_open(backpack_items):
		if slider_rect.has_point(event.position):
			is_adjusting_slider = true
			_update_split_quantity_from_position(event.position)
			return true
		if confirm_rect.has_point(event.position):
			_confirm_split_stack(backpack_items)
			return true
		if cancel_rect.has_point(event.position) or not dialog_rect.has_point(event.position):
			close_split_dialog()
			return true

	if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and is_adjusting_slider:
		is_adjusting_slider = false
		return true

	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and is_context_menu_open(backpack_items):
		if equipment_slot_id != &"":
			if not unload_ammo_rect.size.is_zero_approx() and unload_ammo_rect.has_point(event.position):
				var target_unload_slot := equipment_slot_id
				close_context_menu()
				equipment_unload_ammo_requested.emit(target_unload_slot)
				return true
			if not drop_rect.size.is_zero_approx() and drop_rect.has_point(event.position):
				var target_drop_slot := equipment_slot_id
				var drop_position := menu_position
				close_context_menu()
				equipment_drop_requested.emit(target_drop_slot, drop_position)
				return true
			if not context_menu_rect().has_point(event.position):
				close_context_menu()
				return true
			return false
		if not use_rect.size.is_zero_approx() and use_rect.has_point(event.position):
			var target_use_index := stack_index
			close_context_menu()
			use_requested.emit(target_use_index)
			return true
		if not unload_ammo_rect.size.is_zero_approx() and unload_ammo_rect.has_point(event.position):
			if _can_unload_ammo_stack(stack_index):
				var target_unload_index := stack_index
				close_context_menu()
				unload_ammo_requested.emit(target_unload_index)
			return true
		if not split_rect.size.is_zero_approx() and split_rect.has_point(event.position):
			open_split_dialog(stack_index, backpack_items, backpack_slots)
			return true
		if not drop_rect.size.is_zero_approx() and drop_rect.has_point(event.position):
			drop_stack_from_context_menu(backpack_items)
			return true
		if not context_menu_rect().has_point(event.position):
			close_context_menu()
			return true

	return false


func open_equipment_context_menu(slot_id: StringName, target_menu_position: Vector2) -> void:
	close_split_dialog()
	stack_index = -1
	equipment_slot_id = slot_id
	var action_count := 1
	if _can_unload_equipment_ammo(slot_id):
		action_count += 1
	menu_size = Vector2(148.0, float(action_count * 44 + 16)) * ui_scale
	var viewport_size := owner.get_viewport_rect().size if owner != null else Vector2(1920.0, 1080.0)
	menu_position = Vector2(
		clampf(target_menu_position.x, 8.0, viewport_size.x - menu_size.x - 8.0),
		clampf(target_menu_position.y, 8.0, viewport_size.y - menu_size.y - 8.0)
	)
	_request_redraw()


func open_context_menu(target_stack_index: int, target_menu_position: Vector2, backpack_items: Array[Dictionary], backpack_slots: int) -> void:
	close_split_dialog()
	stack_index = target_stack_index
	equipment_slot_id = &""
	menu_size = _context_menu_size_for_stack(target_stack_index, backpack_items, backpack_slots)
	var viewport_size := owner.get_viewport_rect().size if owner != null else Vector2(1920.0, 1080.0)
	menu_position = Vector2(
		clampf(target_menu_position.x, 8.0, viewport_size.x - menu_size.x - 8.0),
		clampf(target_menu_position.y, 8.0, viewport_size.y - menu_size.y - 8.0)
	)
	_request_redraw()


func close_all() -> void:
	close_context_menu()
	close_split_dialog()


func close_context_menu() -> void:
	stack_index = -1
	equipment_slot_id = &""
	use_rect = Rect2()
	unload_ammo_rect = Rect2()
	split_rect = Rect2()
	drop_rect = Rect2()
	_request_redraw()


func is_context_menu_open(backpack_items: Array[Dictionary]) -> bool:
	return equipment_slot_id != &"" or (stack_index >= 0 and stack_index < backpack_items.size())


func context_menu_rect() -> Rect2:
	return Rect2(menu_position, menu_size)


func draw(backpack_items: Array[Dictionary], backpack_slots: int) -> void:
	if is_context_menu_open(backpack_items):
		_draw_context_menu(backpack_items, backpack_slots)
	if is_split_dialog_open(backpack_items):
		_draw_split_dialog()


func open_split_dialog(target_stack_index: int, backpack_items: Array[Dictionary], backpack_slots: int) -> void:
	if not _can_split_stack(target_stack_index, backpack_items, backpack_slots):
		return
	split_stack_index = target_stack_index
	var quantity := int(backpack_items[target_stack_index].get("quantity", 1))
	split_quantity = clampi(int(ceil(float(quantity) * 0.5)), 1, quantity - 1)
	close_context_menu()
	_request_redraw()


func close_split_dialog() -> void:
	split_stack_index = -1
	split_quantity = 1
	is_adjusting_slider = false
	_request_redraw()


func is_split_dialog_open(backpack_items: Array[Dictionary]) -> bool:
	return split_stack_index >= 0 and split_stack_index < backpack_items.size()


func drop_stack_from_context_menu(backpack_items: Array[Dictionary]) -> void:
	if equipment_slot_id != &"" or not is_context_menu_open(backpack_items):
		return
	var target_stack_index := stack_index
	var stack := backpack_items[target_stack_index].duplicate(true)
	var drop_position := menu_position
	close_context_menu()
	drop_requested.emit(target_stack_index, stack, drop_position, true)


func _draw_context_menu(backpack_items: Array[Dictionary], backpack_slots: int) -> void:
	var rect := context_menu_rect()
	painter.panel(Rect2(rect.position + _v(5.0, 5.0), rect.size), UISurfacePaletteScript.shadow(), UISurfacePaletteScript.TRANSPARENT, 0, 14)
	painter.panel(rect, UISurfacePaletteScript.panel_fill(true), UISurfacePaletteScript.panel_border(), 1, 14)

	use_rect = Rect2()
	unload_ammo_rect = Rect2()
	split_rect = Rect2()
	drop_rect = Rect2()
	var next_y := 8.0
	if equipment_slot_id != &"":
		if _can_unload_equipment_ammo(equipment_slot_id):
			unload_ammo_rect = _action_rect(rect, next_y)
			_draw_context_button(unload_ammo_rect, _localized_text(&"ui.weapon_mod.unload_ammo", "Unload ammo"), UISurfacePaletteScript.button_fill(&"success"), true)
			next_y += 44.0
		drop_rect = _action_rect(rect, next_y)
		_draw_context_button(drop_rect, _localized_text(&"ui.inventory.drop", "Drop"), UISurfacePaletteScript.button_fill(&"danger"), true)
		return
	if _can_use_stack(stack_index):
		use_rect = _action_rect(rect, next_y)
		_draw_context_button(use_rect, _localized_text(&"ui.inventory.use", "Use"), UISurfacePaletteScript.button_fill(&"use"), true)
		next_y += 44.0
	if _should_show_unload_ammo_stack(stack_index):
		var can_unload := _can_unload_ammo_stack(stack_index)
		unload_ammo_rect = _action_rect(rect, next_y)
		_draw_context_button(unload_ammo_rect, _localized_text(&"ui.weapon_mod.unload_ammo", "Unload ammo"), UISurfacePaletteScript.button_fill(&"success"), can_unload)
		next_y += 44.0
	if _can_split_stack(stack_index, backpack_items, backpack_slots):
		split_rect = _action_rect(rect, next_y)
		_draw_context_button(split_rect, _localized_text(&"ui.inventory.split", "Split"), UISurfacePaletteScript.button_fill(&"split"), true)
		next_y += 44.0
	drop_rect = _action_rect(rect, next_y)
	_draw_context_button(drop_rect, _localized_text(&"ui.inventory.drop", "Drop"), UISurfacePaletteScript.button_fill(&"danger"), true)


func _action_rect(menu_rect: Rect2, y_offset: float) -> Rect2:
	return Rect2(menu_rect.position + _v(8.0, y_offset), Vector2(menu_rect.size.x - 16.0 * ui_scale, 36.0 * ui_scale))


func _draw_context_button(rect: Rect2, text: String, color: Color, enabled: bool) -> void:
	var fill := color if enabled else UISurfacePaletteScript.button_fill(&"disabled")
	var text_color := UISurfacePaletteScript.button_text(enabled)
	painter.panel(rect, fill, UISurfacePaletteScript.button_border(), 1, 12)
	painter.text(text, rect.position + _v(0.0, 25.0), 18, text_color, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


func _draw_split_dialog() -> void:
	var viewport_size := owner.get_viewport_rect().size if owner != null else Vector2(1920.0, 1080.0)
	dialog_rect = Rect2((viewport_size - Vector2(360.0, 210.0) * ui_scale) * 0.5, Vector2(360.0, 210.0) * ui_scale)
	painter.panel(Rect2(dialog_rect.position + _v(8.0, 8.0), dialog_rect.size), UISurfacePaletteScript.shadow(), UISurfacePaletteScript.TRANSPARENT, 0, 18)
	painter.panel(dialog_rect, UISurfacePaletteScript.panel_fill(), UISurfacePaletteScript.panel_border(), 1, UISurfacePaletteScript.RADIUS_FLOATING_PANEL)
	painter.text(_localized_text(&"ui.inventory.split", "Split"), dialog_rect.position + _v(0.0, 42.0), 24, UISurfacePaletteScript.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_CENTER, dialog_rect.size.x)
	painter.text(_localized_text(&"ui.inventory.split_amount", "Split Amount"), dialog_rect.position + _v(0.0, 76.0), 18, UISurfacePaletteScript.TEXT_SECONDARY, HORIZONTAL_ALIGNMENT_CENTER, dialog_rect.size.x)
	painter.text(str(split_quantity), dialog_rect.position + _v(0.0, 108.0), 18, UISurfacePaletteScript.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_CENTER, dialog_rect.size.x)

	slider_rect = Rect2(dialog_rect.position + _v(42.0, 122.0), Vector2(dialog_rect.size.x - 84.0 * ui_scale, 18.0 * ui_scale))
	var max_quantity := _split_max_quantity()
	var ratio := 0.0 if max_quantity <= 1 else float(split_quantity - 1) / float(max_quantity - 1)
	painter.numeric_slider(slider_rect, ratio)

	confirm_rect = Rect2(dialog_rect.position + _v(34.0, 156.0), Vector2(138.0, 36.0) * ui_scale)
	cancel_rect = Rect2(dialog_rect.position + _v(188.0, 156.0), Vector2(138.0, 36.0) * ui_scale)
	_draw_context_button(confirm_rect, _localized_text(&"ui.inventory.split_confirm", "Confirm Split"), UISurfacePaletteScript.button_fill(), true)
	_draw_context_button(cancel_rect, _localized_text(&"ui.main.back", "Back"), UISurfacePaletteScript.button_fill(&"neutral"), true)


func _update_split_quantity_from_position(mouse_position: Vector2) -> void:
	var max_quantity := _split_max_quantity()
	if max_quantity <= 1:
		split_quantity = 1
		return
	var ratio := clampf((mouse_position.x - slider_rect.position.x) / maxf(slider_rect.size.x, 1.0), 0.0, 1.0)
	split_quantity = clampi(1 + roundi(ratio * float(max_quantity - 1)), 1, max_quantity)
	_request_redraw()


func _confirm_split_stack(backpack_items: Array[Dictionary]) -> void:
	if is_split_dialog_open(backpack_items) and backpack_model != null:
		backpack_model.split_stack_at(split_stack_index, split_quantity)
	close_split_dialog()


func _split_max_quantity() -> int:
	if backpack_model == null or split_stack_index < 0 or split_stack_index >= backpack_model.stacks.size():
		return 1
	return maxi(int(backpack_model.stacks[split_stack_index].get("quantity", 1)) - 1, 1)


func _can_split_stack(target_stack_index: int, backpack_items: Array[Dictionary], backpack_slots: int) -> bool:
	if target_stack_index < 0 or target_stack_index >= backpack_items.size():
		return false
	if backpack_model == null or backpack_model.stacks.size() >= backpack_slots:
		return false
	return int(backpack_items[target_stack_index].get("quantity", 1)) > 1


func _can_use_stack(target_stack_index: int) -> bool:
	if owner != null and owner.has_method("can_use_backpack_stack"):
		return bool(owner.call("can_use_backpack_stack", target_stack_index))
	return false


func _should_show_unload_ammo_stack(target_stack_index: int) -> bool:
	if owner != null and owner.has_method("is_backpack_weapon_stack"):
		return bool(owner.call("is_backpack_weapon_stack", target_stack_index))
	return false


func _can_unload_ammo_stack(target_stack_index: int) -> bool:
	if owner != null and owner.has_method("can_unload_backpack_weapon_ammo"):
		return bool(owner.call("can_unload_backpack_weapon_ammo", target_stack_index))
	return false


func _can_unload_equipment_ammo(slot_id: StringName) -> bool:
	if owner != null and owner.has_method("can_unload_equipment_weapon_ammo"):
		return bool(owner.call("can_unload_equipment_weapon_ammo", slot_id))
	return false


func _context_menu_size_for_stack(target_stack_index: int, backpack_items: Array[Dictionary], backpack_slots: int) -> Vector2:
	var action_count := 1
	if _can_use_stack(target_stack_index):
		action_count += 1
	if _should_show_unload_ammo_stack(target_stack_index):
		action_count += 1
	if _can_split_stack(target_stack_index, backpack_items, backpack_slots):
		action_count += 1
	return Vector2(148.0, float(action_count * 44 + 16)) * ui_scale


func _localized_text(key: StringName, fallback: String) -> String:
	if owner != null and owner.has_method("_localized_text"):
		return owner.call("_localized_text", key, fallback)
	return fallback


func _v(x: float, y: float) -> Vector2:
	return Vector2(x, y) * ui_scale


func _request_redraw() -> void:
	if owner != null:
		owner.queue_redraw()
