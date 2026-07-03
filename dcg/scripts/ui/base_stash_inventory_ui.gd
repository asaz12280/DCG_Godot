class_name BaseStashInventoryUI
extends Control

const StashModelScript := preload("res://scripts/base/stash_model.gd")
const InventoryPainterScript := preload("res://scripts/ui/inventory_equipment_painter.gd")

@export var stash_capacity: int = 250
@export var grid_columns: int = 5
@export var visible_stash_rows: int = 6
@export var visible_backpack_rows: int = 3
@export var slot_size: Vector2 = Vector2(70.0, 70.0)
@export var slot_gap: float = 10.0

var player: Node = null
var save_manager: Node = null
var backpack_model := InventoryModel.new()
var safe_pocket_model := InventoryModel.new()
var equipment_model: RefCounted = null
var stash_model := StashModelScript.new()
var backpack_items: Array[Dictionary] = []
var safe_pocket_items: Array[Dictionary] = []
var stash_items: Array[Dictionary] = []
var backpack_scroll_row: int = 0
var stash_scroll_row: int = 0

var equipment_slot_label_keys: Array[StringName] = [
	&"ui.equipment.primary",
	&"ui.equipment.sidearm",
	&"ui.equipment.melee",
	&"ui.equipment.helmet",
	&"ui.equipment.armor",
	&"ui.equipment.glasses",
	&"ui.equipment.headset",
	&"ui.equipment.backpack",
	&"ui.equipment.charm_1",
	&"ui.equipment.charm_2",
]

var equipment_slot_ids: Array[StringName] = [
	&"primary_weapon",
	&"sidearm",
	&"melee",
	&"helmet",
	&"armor",
	&"glasses",
	&"headset",
	&"backpack",
	&"charm_1",
	&"charm_2",
]

var _is_open: bool = false
var _status_key: StringName = &"ui.stash.ready"
var _ui_scale: float = 1.0
var _scaled_slot_size: Vector2 = Vector2.ZERO
var _scaled_slot_gap: float = 0.0
var _painter := InventoryPainterScript.new(self)


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not stash_model.changed.is_connected(_on_stash_changed):
		stash_model.changed.connect(_on_stash_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_stash()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and (mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN or mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP):
			_handle_scroll(mouse_event)
			accept_event()
			return
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(mouse_event.position)
			accept_event()


func open_stash(source_player: Node = null, source_save_manager: Node = null) -> bool:
	player = source_player if source_player != null else _find_player()
	save_manager = source_save_manager if source_save_manager != null else _find_save_manager()
	_bind_models()
	_load_stash_from_save()
	backpack_scroll_row = 0
	stash_scroll_row = 0
	_status_key = &"ui.stash.ready"
	_is_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	queue_redraw()
	return true


func close_stash() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func is_open() -> bool:
	return _is_open


func store_backpack_stack(stack_index: int) -> bool:
	if stack_index < 0 or stack_index >= backpack_items.size():
		return false
	var removed_stack: Dictionary = backpack_model.remove_stack_at(stack_index)
	if removed_stack.is_empty():
		return false
	if not _add_removed_stack_to_stash(removed_stack):
		backpack_model.add_stack(removed_stack)
		_status_key = &"ui.stash.stash_full"
		_refresh_display_items()
		queue_redraw()
		return false
	_status_key = &"ui.stash.saved"
	_refresh_display_items()
	queue_redraw()
	return true


func store_safe_pocket_stack(stack_index: int) -> bool:
	if stack_index < 0 or stack_index >= safe_pocket_items.size():
		return false
	var removed_stack: Dictionary = safe_pocket_model.remove_stack_at(stack_index)
	if removed_stack.is_empty():
		return false
	if not _add_removed_stack_to_stash(removed_stack):
		safe_pocket_model.add_stack(removed_stack)
		_status_key = &"ui.stash.stash_full"
		_refresh_display_items()
		queue_redraw()
		return false
	_status_key = &"ui.stash.saved"
	_refresh_display_items()
	queue_redraw()
	return true


func store_equipment_slot(slot_id: StringName) -> bool:
	if equipment_model == null or not equipment_model.has_method("unequip"):
		return false
	var removed_stack: Dictionary = equipment_model.call("unequip", slot_id)
	if removed_stack.is_empty():
		return false
	if not _add_removed_stack_to_stash(removed_stack):
		if equipment_model.has_method("equip_stack"):
			equipment_model.call("equip_stack", slot_id, removed_stack)
		_status_key = &"ui.stash.stash_full"
		_refresh_display_items()
		queue_redraw()
		return false
	_status_key = &"ui.stash.saved"
	_refresh_display_items()
	queue_redraw()
	return true


func withdraw_stash_stack(stack_index: int) -> bool:
	if stack_index < 0 or stack_index >= stash_items.size():
		return false
	var previous_stash: Array[Dictionary] = stash_model.to_save_data()
	var removed_stack: Dictionary = stash_model.remove_stack_at(stack_index)
	if removed_stack.is_empty():
		return false
	if not backpack_model.can_accept_stack(removed_stack):
		stash_model.load_save_data(previous_stash)
		_status_key = &"ui.stash.backpack_full"
		_refresh_display_items()
		queue_redraw()
		return false
	if not _save_stash():
		stash_model.load_save_data(previous_stash)
		_status_key = &"ui.stash.save_failed"
		_refresh_display_items()
		queue_redraw()
		return false
	if not backpack_model.add_stack(removed_stack):
		stash_model.load_save_data(previous_stash)
		_save_stash()
		_status_key = &"ui.stash.withdraw_failed"
		_refresh_display_items()
		queue_redraw()
		return false
	_status_key = &"ui.stash.saved"
	_refresh_display_items()
	queue_redraw()
	return true


func organize_stash() -> void:
	stash_model.stacks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var type_a := str(a.get("type", ""))
		var type_b := str(b.get("type", ""))
		if type_a == type_b:
			return _get_stack_display_name(a) < _get_stack_display_name(b)
		return type_a < type_b
	)
	_save_stash()
	_status_key = &"ui.stash.saved"
	_on_stash_changed()


func get_display_state() -> Dictionary:
	var viewport_size := get_viewport_rect().size if is_inside_tree() else Vector2(1920.0, 1080.0)
	return get_display_state_for_viewport(viewport_size)


func get_display_state_for_viewport(viewport_size: Vector2) -> Dictionary:
	_update_layout_scale(viewport_size)
	var left_rect := _left_panel_rect(viewport_size)
	var right_rect := _right_panel_rect(viewport_size)
	return {
		"visible": visible,
		"is_open": _is_open,
		"title": _stash_title_text(),
		"status_text": _status_text(),
		"backpack_items": backpack_items.duplicate(true),
		"safe_pocket_items": safe_pocket_items.duplicate(true),
		"stash_items": stash_items.duplicate(true),
		"stash_used": stash_model.get_stack_count(),
		"stash_capacity": stash_capacity,
		"backpack_used": backpack_model.get_used_slots(),
		"backpack_slots": _get_backpack_slots(),
		"safe_pocket_used": safe_pocket_model.get_used_slots(),
		"safe_pocket_slots": _get_safe_pocket_slots(),
		"equipment_slots": _get_equipment_slots_state(),
		"left_panel_rect": left_rect,
		"right_panel_rect": right_rect,
		"stash_grid_rect": _stash_grid_rect(right_rect),
		"backpack_grid_rect": _backpack_grid_rect(left_rect),
		"safe_pocket_rect": _safe_pocket_panel_rect(left_rect),
		"close_button_rect": _close_button_rect(right_rect),
		"sort_button_rect": _sort_button_rect(right_rect),
	}


func refresh_localization() -> void:
	queue_redraw()


func _draw() -> void:
	if not _is_open:
		return
	var viewport_size := get_viewport_rect().size
	_update_layout_scale(viewport_size)
	var left_rect := _left_panel_rect(viewport_size)
	var right_rect := _right_panel_rect(viewport_size)
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.01, 0.02, 0.025, 0.68))
	_draw_left_panel(left_rect)
	_draw_stash_panel(right_rect)


func _draw_left_panel(rect: Rect2) -> void:
	_painter.panel_shadow(rect)
	_painter.panel(rect, Color(0.05, 0.12, 0.18, 0.92), Color(0.20, 0.39, 0.52, 0.90), 2, 8)
	_painter.panel_highlight(rect)
	_painter.header(Rect2(rect.position + _v(18.0, 18.0), Vector2(rect.size.x - 36.0 * _ui_scale, 36.0 * _ui_scale)), _localized_text(&"ui.stash.loadout", "裝備與背包"))
	_draw_equipment_grid(rect)
	_draw_backpack_grid(rect)
	_draw_safe_pocket_grid(rect)


func _draw_stash_panel(rect: Rect2) -> void:
	_painter.panel_shadow(rect)
	_painter.panel(rect, Color(0.04, 0.11, 0.19, 0.94), Color(0.18, 0.74, 0.37, 0.95), 3, 8)
	_painter.panel_highlight(rect)
	_painter.text(_stash_title_text(), rect.position + _v(22.0, 42.0), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 190.0 * _ui_scale)
	_draw_button(_sort_button_rect(rect), _localized_text(&"ui.stash.sort", "整理"), Color(0.54, 0.84, 0.92, 0.92))
	_draw_button(_close_button_rect(rect), _localized_text(&"ui.common.close", "關閉"), Color(0.32, 0.42, 0.50, 0.92))
	_painter.text(_localized_text(&"ui.stash.store_hint", "點擊左側物品存入倉庫；點擊右側物品取回背包。"), rect.position + _v(22.0, 78.0), 14, Color(0.73, 0.88, 0.90, 0.92), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 44.0 * _ui_scale)
	_painter.text(_status_text(), rect.position + _v(22.0, 104.0), 13, Color(0.96, 0.88, 0.55, 0.92), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 44.0 * _ui_scale)

	var grid_rect := _stash_grid_rect(rect)
	for slot_index in range(grid_columns * visible_stash_rows):
		var absolute_index := stash_scroll_row * grid_columns + slot_index
		if absolute_index >= stash_capacity:
			continue
		var slot_rect := _grid_slot_rect(grid_rect, slot_index, grid_columns)
		_painter.slot(slot_rect, Color(0.07, 0.17, 0.27, 0.92), Color(0.54, 0.65, 0.72, 0.78))
		if absolute_index < stash_items.size():
			_paint_item_label(slot_rect, stash_items[absolute_index])
	if _max_stash_scroll_row() > 0:
		_painter.scroll_bar(rect, stash_scroll_row, _max_stash_scroll_row(), _scaled_slot_size, _scaled_slot_gap)


func _draw_equipment_grid(rect: Rect2) -> void:
	var origin := rect.position + _v(24.0, 74.0)
	_painter.text(_localized_text(&"ui.inventory.equipment", "裝備"), origin + _v(0.0, -12.0), 16, Color(0.85, 0.94, 0.94, 0.95), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 48.0 * _ui_scale)
	for index in range(equipment_slot_ids.size()):
		var slot_rect := _equipment_slot_rect(rect, index)
		_painter.slot(slot_rect, Color(0.08, 0.17, 0.25, 0.92), Color(0.55, 0.66, 0.74, 0.72))
		_painter.equipment_icon(slot_rect.grow(-13.0 * _ui_scale), index)
		var stack := _get_equipment_stack_at(index)
		if stack.is_empty():
			_painter.text(_localized_text(equipment_slot_label_keys[index], ""), slot_rect.position + _v(7.0, 62.0), 11, Color(0.72, 0.80, 0.80, 0.72), HORIZONTAL_ALIGNMENT_CENTER, slot_rect.size.x - 14.0 * _ui_scale)
		else:
			_paint_item_label(slot_rect, stack)


func _draw_backpack_grid(rect: Rect2) -> void:
	var header_rect := Rect2(_backpack_grid_rect(rect).position - _v(0.0, 42.0), Vector2(_backpack_grid_rect(rect).size.x, 32.0 * _ui_scale))
	var backpack_format := _localized_text(&"ui.inventory.backpack_format", "背包 (%d/%d)")
	_painter.header(header_rect, backpack_format % [backpack_model.get_used_slots(), _get_backpack_slots()])
	var grid_rect := _backpack_grid_rect(rect)
	for slot_index in range(grid_columns * visible_backpack_rows):
		var absolute_index := backpack_scroll_row * grid_columns + slot_index
		if absolute_index >= _get_backpack_slots():
			continue
		var slot_rect := _grid_slot_rect(grid_rect, slot_index, grid_columns)
		_painter.slot(slot_rect, Color(0.07, 0.16, 0.24, 0.92), Color(0.51, 0.62, 0.70, 0.72))
		if absolute_index < backpack_items.size():
			_paint_item_label(slot_rect, backpack_items[absolute_index])
	if _max_backpack_scroll_row() > 0:
		_painter.scroll_bar(rect, backpack_scroll_row, _max_backpack_scroll_row(), _scaled_slot_size, _scaled_slot_gap)


func _draw_safe_pocket_grid(rect: Rect2) -> void:
	var safe_rect := _safe_pocket_panel_rect(rect)
	_painter.header(Rect2(safe_rect.position, Vector2(safe_rect.size.x, 32.0 * _ui_scale)), _localized_text(&"ui.inventory.safe_pocket", "安全口袋"))
	var slot_origin := safe_rect.position + _v(0.0, 44.0)
	var slots := _get_safe_pocket_slots()
	for index in range(slots):
		var slot_rect := Rect2(slot_origin + Vector2(float(index) * (_scaled_slot_size.x + _scaled_slot_gap), 0.0), _scaled_slot_size)
		_painter.slot(slot_rect, Color(0.10, 0.20, 0.19, 0.92), Color(0.57, 0.82, 0.74, 0.74))
		if index < safe_pocket_items.size():
			_paint_item_label(slot_rect, safe_pocket_items[index])


func _draw_button(rect: Rect2, label: String, fill: Color) -> void:
	_painter.panel(rect, fill, Color(0.80, 0.96, 1.0, 0.80), 2, 6)
	_painter.text(label, rect.position + _v(8.0, 24.0), 14, Color(0.04, 0.09, 0.12, 1.0), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 16.0 * _ui_scale)


func _paint_item_label(rect: Rect2, stack: Dictionary) -> void:
	_painter.item_label(rect, _get_stack_display_name(stack), int(stack.get("quantity", 1)))


func _handle_scroll(event: InputEventMouseButton) -> void:
	var viewport_size := get_viewport_rect().size
	_update_layout_scale(viewport_size)
	var left_rect := _left_panel_rect(viewport_size)
	var right_rect := _right_panel_rect(viewport_size)
	var direction := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
	if right_rect.has_point(event.position):
		_scroll_stash(direction)
	elif left_rect.has_point(event.position):
		_scroll_backpack(direction)


func _handle_left_click(position: Vector2) -> void:
	var viewport_size := get_viewport_rect().size
	_update_layout_scale(viewport_size)
	var left_rect := _left_panel_rect(viewport_size)
	var right_rect := _right_panel_rect(viewport_size)
	if _close_button_rect(right_rect).has_point(position):
		close_stash()
		return
	if _sort_button_rect(right_rect).has_point(position):
		organize_stash()
		return
	var equipment_index := _equipment_index_at(position, left_rect)
	if equipment_index >= 0:
		store_equipment_slot(equipment_slot_ids[equipment_index])
		return
	var safe_index := _safe_pocket_index_at(position, left_rect)
	if safe_index >= 0 and safe_index < safe_pocket_items.size():
		store_safe_pocket_stack(safe_index)
		return
	var backpack_index := _backpack_index_at(position, left_rect)
	if backpack_index >= 0 and backpack_index < backpack_items.size():
		store_backpack_stack(backpack_index)
		return
	var stash_index := _stash_index_at(position, right_rect)
	if stash_index >= 0 and stash_index < stash_items.size():
		withdraw_stash_stack(stash_index)


func _add_removed_stack_to_stash(removed_stack: Dictionary) -> bool:
	if not _stash_can_accept_stack(removed_stack):
		return false
	var previous_stash: Array[Dictionary] = stash_model.to_save_data()
	if not stash_model.add_stack(removed_stack):
		return false
	if not _save_stash():
		stash_model.load_save_data(previous_stash)
		_status_key = &"ui.stash.save_failed"
		return false
	return true


func _stash_can_accept_stack(stack: Dictionary) -> bool:
	if stack.is_empty():
		return false
	var item_def := _load_item_from_stack(stack)
	if item_def == null:
		return stash_model.get_stack_count() < stash_capacity
	var remaining := int(stack.get("quantity", 1))
	for existing_stack in stash_model.stacks:
		if str(existing_stack.get("resource_path", "")) != item_def.resource_path:
			continue
		var max_stack := int(existing_stack.get("max_stack", 1))
		if max_stack <= 1:
			continue
		var room := max_stack - int(existing_stack.get("quantity", 1))
		if room <= 0:
			continue
		remaining -= mini(room, remaining)
		if remaining <= 0:
			return true
	var free_slots := maxi(stash_capacity - stash_model.get_stack_count(), 0)
	var item_max_stack := maxi(item_def.max_stack, 1)
	while remaining > 0 and free_slots > 0:
		remaining -= mini(item_max_stack, remaining)
		free_slots -= 1
	return remaining <= 0


func _load_stash_from_save() -> void:
	stash_model.clear()
	var save_data := _ensure_save_data()
	var stash_data: Variant = save_data.get("stash", [])
	if typeof(stash_data) == TYPE_ARRAY:
		stash_model.load_save_data(stash_data as Array)
	_on_stash_changed()


func _save_stash() -> bool:
	if save_manager == null or not save_manager.has_method("save_slot_data"):
		return false
	var save_data := _ensure_save_data()
	if save_data.is_empty():
		return false
	save_data["stash"] = stash_model.to_save_data()
	return bool(save_manager.call("save_slot_data", _current_slot_index(), save_data))


func _ensure_save_data() -> Dictionary:
	if save_manager == null or not save_manager.has_method("get_slot_data"):
		return {}
	var slot_index := _current_slot_index()
	var save_data: Dictionary = save_manager.call("get_slot_data", slot_index)
	if save_data.is_empty() and save_manager.has_method("save_new_game"):
		save_manager.call("save_new_game", slot_index, "normal", "res://scenes/base/base_3d.tscn")
		save_data = save_manager.call("get_slot_data", slot_index)
	return save_data


func _current_slot_index() -> int:
	if save_manager != null and save_manager.has_method("get_current_slot_index"):
		return int(save_manager.call("get_current_slot_index"))
	return 1


func _bind_models() -> void:
	if player != null and player.has_method("get_inventory_model"):
		backpack_model = player.call("get_inventory_model")
	else:
		backpack_model.setup(_get_backpack_slots())
	if player != null and player.has_method("get_safe_pocket_model"):
		safe_pocket_model = player.call("get_safe_pocket_model")
	else:
		safe_pocket_model.setup(_get_safe_pocket_slots())
	equipment_model = player.call("get_equipment_model") if player != null and player.has_method("get_equipment_model") else null
	_connect_model_signal(backpack_model, "_on_backpack_changed")
	_connect_model_signal(safe_pocket_model, "_on_safe_pocket_changed")
	if equipment_model != null and equipment_model.has_signal("changed"):
		var callable := Callable(self, "_on_equipment_changed")
		if not equipment_model.is_connected("changed", callable):
			equipment_model.connect("changed", callable)
	_refresh_display_items()


func _connect_model_signal(model: RefCounted, method_name: String) -> void:
	if model == null or not model.has_signal("changed"):
		return
	var callable := Callable(self, method_name)
	if not model.is_connected("changed", callable):
		model.connect("changed", callable)


func _on_backpack_changed() -> void:
	backpack_items = backpack_model.get_display_items()
	backpack_scroll_row = clampi(backpack_scroll_row, 0, _max_backpack_scroll_row())
	queue_redraw()


func _on_safe_pocket_changed() -> void:
	safe_pocket_items = safe_pocket_model.get_display_items()
	queue_redraw()


func _on_equipment_changed() -> void:
	queue_redraw()


func _on_stash_changed() -> void:
	stash_items = stash_model.get_stacks()
	stash_scroll_row = clampi(stash_scroll_row, 0, _max_stash_scroll_row())
	queue_redraw()


func _refresh_display_items() -> void:
	backpack_items = backpack_model.get_display_items()
	safe_pocket_items = safe_pocket_model.get_display_items()
	stash_items = stash_model.get_stacks()
	backpack_scroll_row = clampi(backpack_scroll_row, 0, _max_backpack_scroll_row())
	stash_scroll_row = clampi(stash_scroll_row, 0, _max_stash_scroll_row())


func _update_layout_scale(viewport_size: Vector2) -> void:
	_ui_scale = clampf(minf(viewport_size.x / 1600.0, viewport_size.y / 900.0), 0.68, 1.0)
	_scaled_slot_size = slot_size * _ui_scale
	_scaled_slot_gap = slot_gap * _ui_scale
	_painter.set_scale(_ui_scale)


func _left_panel_rect(viewport_size: Vector2) -> Rect2:
	var left_width := float(grid_columns) * _scaled_slot_size.x + float(grid_columns - 1) * _scaled_slot_gap + 48.0 * _ui_scale
	var panel_height := _panel_height()
	var gap := 72.0 * _ui_scale
	var total_width := left_width * 2.0 + gap
	var x := maxf(22.0 * _ui_scale, (viewport_size.x - total_width) * 0.5)
	var y := maxf(36.0 * _ui_scale, (viewport_size.y - panel_height) * 0.5)
	return Rect2(Vector2(x, y), Vector2(left_width, panel_height))


func _right_panel_rect(viewport_size: Vector2) -> Rect2:
	var left_rect := _left_panel_rect(viewport_size)
	var gap := 72.0 * _ui_scale
	return Rect2(Vector2(left_rect.end.x + gap, left_rect.position.y), left_rect.size)


func _panel_height() -> float:
	var stash_grid_height := float(visible_stash_rows) * _scaled_slot_size.y + float(visible_stash_rows - 1) * _scaled_slot_gap
	var backpack_grid_height := float(visible_backpack_rows) * _scaled_slot_size.y + float(visible_backpack_rows - 1) * _scaled_slot_gap
	var safe_height := 86.0 * _ui_scale + _scaled_slot_size.y
	return maxf(144.0 * _ui_scale + stash_grid_height, 346.0 * _ui_scale + backpack_grid_height + safe_height)


func _stash_grid_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + _v(24.0, 132.0), Vector2(
		float(grid_columns) * _scaled_slot_size.x + float(grid_columns - 1) * _scaled_slot_gap,
		float(visible_stash_rows) * _scaled_slot_size.y + float(visible_stash_rows - 1) * _scaled_slot_gap
	))


func _backpack_grid_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + _v(24.0, 310.0), Vector2(
		float(grid_columns) * _scaled_slot_size.x + float(grid_columns - 1) * _scaled_slot_gap,
		float(visible_backpack_rows) * _scaled_slot_size.y + float(visible_backpack_rows - 1) * _scaled_slot_gap
	))


func _safe_pocket_panel_rect(panel_rect: Rect2) -> Rect2:
	var backpack_rect := _backpack_grid_rect(panel_rect)
	return Rect2(Vector2(panel_rect.position.x + 24.0 * _ui_scale, backpack_rect.end.y + 34.0 * _ui_scale), Vector2(backpack_rect.size.x, 96.0 * _ui_scale + _scaled_slot_size.y))


func _equipment_slot_rect(panel_rect: Rect2, index: int) -> Rect2:
	var origin := panel_rect.position + _v(24.0, 92.0)
	var column := index % grid_columns
	var row := index / grid_columns
	return Rect2(origin + Vector2(float(column) * (_scaled_slot_size.x + _scaled_slot_gap), float(row) * (_scaled_slot_size.y + _scaled_slot_gap)), _scaled_slot_size)


func _grid_slot_rect(grid_rect: Rect2, slot_index: int, columns: int) -> Rect2:
	var column := slot_index % columns
	var row := slot_index / columns
	return Rect2(grid_rect.position + Vector2(float(column) * (_scaled_slot_size.x + _scaled_slot_gap), float(row) * (_scaled_slot_size.y + _scaled_slot_gap)), _scaled_slot_size)


func _sort_button_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(panel_rect.size.x - 176.0 * _ui_scale, 24.0 * _ui_scale), Vector2(76.0 * _ui_scale, 32.0 * _ui_scale))


func _close_button_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(panel_rect.size.x - 90.0 * _ui_scale, 24.0 * _ui_scale), Vector2(66.0 * _ui_scale, 32.0 * _ui_scale))


func _equipment_index_at(position: Vector2, panel_rect: Rect2) -> int:
	for index in range(equipment_slot_ids.size()):
		if _equipment_slot_rect(panel_rect, index).has_point(position):
			return index
	return -1


func _backpack_index_at(position: Vector2, panel_rect: Rect2) -> int:
	var grid_rect := _backpack_grid_rect(panel_rect)
	if not grid_rect.has_point(position):
		return -1
	for slot_index in range(grid_columns * visible_backpack_rows):
		if _grid_slot_rect(grid_rect, slot_index, grid_columns).has_point(position):
			return backpack_scroll_row * grid_columns + slot_index
	return -1


func _safe_pocket_index_at(position: Vector2, panel_rect: Rect2) -> int:
	var safe_rect := _safe_pocket_panel_rect(panel_rect)
	var slots := _get_safe_pocket_slots()
	for index in range(slots):
		var slot_rect := Rect2(safe_rect.position + _v(0.0, 44.0) + Vector2(float(index) * (_scaled_slot_size.x + _scaled_slot_gap), 0.0), _scaled_slot_size)
		if slot_rect.has_point(position):
			return index
	return -1


func _stash_index_at(position: Vector2, panel_rect: Rect2) -> int:
	var grid_rect := _stash_grid_rect(panel_rect)
	if not grid_rect.has_point(position):
		return -1
	for slot_index in range(grid_columns * visible_stash_rows):
		if _grid_slot_rect(grid_rect, slot_index, grid_columns).has_point(position):
			return stash_scroll_row * grid_columns + slot_index
	return -1


func _scroll_stash(direction: int) -> void:
	stash_scroll_row = clampi(stash_scroll_row + direction, 0, _max_stash_scroll_row())
	queue_redraw()


func _scroll_backpack(direction: int) -> void:
	backpack_scroll_row = clampi(backpack_scroll_row + direction, 0, _max_backpack_scroll_row())
	queue_redraw()


func _max_stash_scroll_row() -> int:
	return maxi(0, int(ceil(float(stash_capacity) / float(grid_columns))) - visible_stash_rows)


func _max_backpack_scroll_row() -> int:
	return maxi(0, int(ceil(float(_get_backpack_slots()) / float(grid_columns))) - visible_backpack_rows)


func _get_backpack_slots() -> int:
	if player != null and player.has_method("get_total_backpack_slots"):
		return int(player.call("get_total_backpack_slots"))
	return backpack_model.slot_limit if backpack_model != null else 50


func _get_safe_pocket_slots() -> int:
	if player != null and player.has_method("get_total_safe_pocket_slots"):
		return int(player.call("get_total_safe_pocket_slots"))
	return safe_pocket_model.slot_limit if safe_pocket_model != null else 2


func _get_equipment_stack_at(index: int) -> Dictionary:
	if equipment_model == null or index < 0 or index >= equipment_slot_ids.size():
		return {}
	return equipment_model.call("get_slot", equipment_slot_ids[index])


func _get_equipment_slots_state() -> Dictionary:
	if equipment_model == null or not equipment_model.has_method("get_slots"):
		return {}
	return equipment_model.call("get_slots")


func _get_stack_display_name(stack: Dictionary) -> String:
	var key := str(stack.get("name_key", ""))
	if key != "":
		var translated := tr(key)
		if translated != key and translated != "":
			return translated
	var fallback := str(stack.get("name", ""))
	if fallback != "":
		return fallback
	return _localized_text(&"item.unknown.name", "物品")


func _stash_title_text() -> String:
	return _localized_text(&"ui.stash.title_format", "倉庫 (%d/%d)") % [stash_model.get_stack_count(), stash_capacity]


func _status_text() -> String:
	return _localized_text(_status_key, "準備存取物品。")


func _localized_text(key: StringName, fallback: String) -> String:
	var key_text := str(key)
	if key_text == "":
		return fallback
	var translated := tr(key_text)
	if translated == key_text or translated == "":
		return fallback
	return translated


func _load_item_from_stack(stack: Dictionary) -> ItemDef:
	var item_path := str(stack.get("resource_path", stack.get("item_path", "")))
	if item_path == "" or not ResourceLoader.exists(item_path):
		return null
	return load(item_path) as ItemDef


func _find_player() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var grouped := tree.get_first_node_in_group("player")
	if grouped != null:
		return grouped
	if tree.current_scene != null:
		return tree.current_scene.find_child("Player3D", true, false)
	return null


func _find_save_manager() -> Node:
	if is_inside_tree():
		var manager := get_node_or_null("/root/SaveGameManager")
		if manager != null:
			return manager
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("SaveGameManager")


func _v(x: float, y: float) -> Vector2:
	return Vector2(x, y) * _ui_scale
