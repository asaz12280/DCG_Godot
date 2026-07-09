extends Control

const UILayoutHelper := preload("res://scripts/ui/ui_layout.gd")
const ItemCodexGridModelScript := preload("res://scripts/ui/item_codex_grid_model.gd")
const ItemCodexSlotScript := preload("res://scripts/ui/components/item_codex_slot.gd")
const ItemCodexCatalogScript := preload("res://scripts/ui/item_codex_catalog.gd")
const ItemCodexPresenterScript := preload("res://scripts/ui/item_codex_presenter.gd")

const MIN_CATALOG_SLOT_COUNT := 100
const GRID_COLUMNS := 10
const VISIBLE_ROWS := 6
const DESIGN_CONTENT_SIZE := Vector2(1792.0, 810.0)
const GRID_INNER_PADDING := 18.0

var is_open: bool = false
var selected_slot: int = 1

var _ui_scale: float = 1.0
var _content_rect: Rect2 = Rect2()
var _catalog := ItemCodexCatalogScript.new()
var _grid_model := ItemCodexGridModelScript.new()
var _grid_panel: Control = null
var _grid_scroll: ScrollContainer = null
var _grid_shell: Control = null
var _grid_container: Control = null
var _slot_buttons: Array = []
var _last_grid_rect: Rect2 = Rect2()
var _slots_dirty: bool = true


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_model.columns = GRID_COLUMNS
	_grid_model.visible_rows = VISIBLE_ROWS
	_grid_model.minimum_slots = MIN_CATALOG_SLOT_COUNT
	_build_grid_controls()
	_reload_items()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_node_grid(1)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_node_grid(-1)
			accept_event()


func open_codex() -> void:
	_reload_items()
	is_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _grid_panel != null:
		_grid_panel.visible = true
	queue_redraw()


func close_codex() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _grid_panel != null:
		_grid_panel.visible = false
	queue_redraw()


func toggle_codex() -> void:
	if is_open:
		close_codex()
	else:
		open_codex()


func _on_localization_changed() -> void:
	_slots_dirty = true
	_rebuild_grid_slots()
	queue_redraw()


func _draw() -> void:
	if not is_open:
		return
	var viewport_size := get_viewport_rect().size
	_update_layout_for_viewport(viewport_size)
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.0, 0.0, 0.0, 0.10))

	var layout := _layout_rects()
	var left_rect: Rect2 = layout.get("left_panel_rect", Rect2())
	var right_rect: Rect2 = layout.get("right_panel_rect", Rect2())
	var header_rect: Rect2 = layout.get("header_rect", Rect2())
	var grid_rect: Rect2 = layout.get("grid_rect", Rect2())

	_paint_panel_shadow(left_rect)
	_paint_panel(left_rect, Color(0.72, 0.73, 0.66, 0.72), Color(1.0, 1.0, 1.0, 0.14), 1, 20)
	_paint_header(header_rect, _localized_text(&"ui.codex.title"))
	_paint_panel(grid_rect, Color(0.13, 0.18, 0.18, 0.82), Color(1.0, 1.0, 1.0, 0.08), 1, 10)
	_sync_grid_panel(grid_rect)
	_paint_panel_shadow(right_rect)
	_paint_detail(right_rect)


func _reload_items() -> void:
	_catalog.reload()
	_grid_model.configure(_catalog.highest_catalog_number())
	selected_slot = clampi(selected_slot, 1, _grid_model.slot_count)
	_slots_dirty = true
	_rebuild_grid_slots()


func _build_grid_controls() -> void:
	_grid_panel = Control.new()
	_grid_panel.visible = false
	_grid_panel.clip_contents = true
	_grid_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_grid_panel)

	_grid_scroll = ScrollContainer.new()
	_grid_scroll.clip_contents = true
	_grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_grid_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_panel.add_child(_grid_scroll)

	_grid_shell = Control.new()
	_grid_shell.clip_contents = true
	_grid_scroll.add_child(_grid_shell)

	_grid_container = Control.new()
	_grid_container.clip_contents = true
	_grid_shell.add_child(_grid_container)


func _sync_grid_panel(rect: Rect2) -> void:
	if _grid_panel == null:
		return
	_grid_panel.visible = is_open
	if _last_grid_rect != rect or _slots_dirty:
		_last_grid_rect = rect
		_rebuild_grid_slots()
	_grid_panel.position = rect.position
	_grid_panel.size = rect.size
	_grid_panel.custom_minimum_size = Vector2.ZERO
	if _grid_scroll != null:
		var margin := GRID_INNER_PADDING * _ui_scale
		_grid_scroll.position = Vector2(margin, margin)
		_grid_scroll.size = Vector2(maxf(rect.size.x - margin * 2.0, 1.0), maxf(rect.size.y - margin * 2.0, 1.0))
		_grid_scroll.custom_minimum_size = Vector2.ZERO


func _rebuild_grid_slots() -> void:
	if _grid_container == null:
		return
	if _last_grid_rect.size == Vector2.ZERO:
		return
	if not _slots_dirty and _slot_buttons.size() == _grid_model.slot_count:
		var updated_slot_size := _calculate_node_slot_size()
		_configure_grid_container_layout(updated_slot_size)
		for index in range(_slot_buttons.size()):
			var slot := _slot_buttons[index] as Control
			if slot != null:
				slot.call("set_slot_size", updated_slot_size)
				_position_grid_slot(slot, index, updated_slot_size)
		_update_slot_selection()
		return
	for child in _grid_container.get_children():
		child.queue_free()
	_slot_buttons.clear()
	var slot_size := _calculate_node_slot_size()
	_configure_grid_container_layout(slot_size)
	for number in range(1, _grid_model.slot_count + 1):
		var slot := ItemCodexSlotScript.new()
		slot.set_slot_size(slot_size)
		var item := _catalog.get_item(number)
		if item != null:
			slot.setup(number, item)
		else:
			slot.clear_slot(number)
		slot.slot_selected.connect(_on_slot_selected)
		_grid_container.add_child(slot)
		_position_grid_slot(slot, number - 1, slot_size)
		_slot_buttons.append(slot)
	_slots_dirty = false
	_update_slot_selection()


func _configure_grid_container_layout(slot_size: Vector2) -> void:
	if _grid_container == null or _grid_shell == null:
		return
	var gap := 10.0 * _ui_scale
	var row_count := ceili(float(_grid_model.slot_count) / float(GRID_COLUMNS))
	var grid_width := slot_size.x * float(GRID_COLUMNS) + gap * float(GRID_COLUMNS - 1)
	var grid_height := slot_size.y * float(row_count) + gap * float(maxi(row_count - 1, 0))
	var shell_width := maxf(_last_grid_rect.size.x - GRID_INNER_PADDING * 2.0 * _ui_scale, grid_width)
	var shell_height := maxf(_last_grid_rect.size.y - GRID_INNER_PADDING * 2.0 * _ui_scale, grid_height)
	var centered_x := maxf(0.0, (shell_width - grid_width) * 0.5)

	_grid_shell.custom_minimum_size = Vector2(shell_width, shell_height)
	_grid_shell.position = Vector2.ZERO
	_grid_shell.size = _grid_shell.custom_minimum_size
	_grid_container.position = Vector2(centered_x, 0.0)
	_grid_container.custom_minimum_size = Vector2(grid_width, grid_height)
	_grid_container.size = _grid_container.custom_minimum_size
	for index in range(_grid_container.get_child_count()):
		var child := _grid_container.get_child(index) as Control
		if child != null:
			_position_grid_slot(child, index, slot_size)


func _position_grid_slot(slot: Control, index: int, slot_size: Vector2) -> void:
	var gap := 10.0 * _ui_scale
	var column := index % GRID_COLUMNS
	var row := index / GRID_COLUMNS
	slot.position = Vector2(float(column) * (slot_size.x + gap), float(row) * (slot_size.y + gap))
	slot.size = slot_size
	slot.custom_minimum_size = slot_size


func _calculate_node_slot_size() -> Vector2:
	return _calculate_node_slot_size_for_rect(_last_grid_rect)


func _calculate_node_slot_size_for_rect(rect: Rect2) -> Vector2:
	if rect.size == Vector2.ZERO:
		return Vector2(110.0, 90.0) * _ui_scale
	var gap := 10.0 * _ui_scale
	var inner_padding := GRID_INNER_PADDING * 2.0 * _ui_scale
	var available_width := rect.size.x - inner_padding - gap * float(GRID_COLUMNS - 1)
	var available_height := rect.size.y - inner_padding - gap * float(VISIBLE_ROWS - 1)
	return Vector2(
		maxf(1.0, floor(available_width / float(GRID_COLUMNS))),
		maxf(1.0, floor(available_height / float(VISIBLE_ROWS)))
	)


func _on_slot_selected(catalog_number: int) -> void:
	selected_slot = catalog_number
	_update_slot_selection()
	queue_redraw()


func _update_slot_selection() -> void:
	for slot in _slot_buttons:
		if slot != null and slot.has_method("set_selected"):
			slot.set_selected(int(slot.catalog_number) == selected_slot)


func _paint_detail(rect: Rect2) -> void:
	_paint_panel(rect, Color(0.16, 0.20, 0.20, 0.74), Color(1.0, 1.0, 1.0, 0.12), 1, 12)
	_paint_text(ItemCodexPresenterScript.catalog_label(selected_slot), rect.position + _v(24.0, 42.0), 22, Color(0.78, 0.92, 0.95, 1.0), HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 48.0 * _ui_scale)
	var item := _catalog.get_item(selected_slot)
	if item == null:
		_paint_text(_localized_text(&"ui.codex.empty_slot"), rect.position + _v(24.0, 90.0), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 48.0 * _ui_scale)
		return

	_paint_item_icon(rect.position + _v(88.0, 120.0), item, 48.0)
	_paint_text(_item_name(item), rect.position + _v(24.0, 206.0), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 48.0 * _ui_scale)
	_paint_text(ItemCodexPresenterScript.codex_category_name(self, item), rect.position + _v(24.0, 242.0), 17, Color(0.72, 0.90, 0.94, 1.0), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 48.0 * _ui_scale)
	_paint_wrapped_text(_localized_text(item.description_key), rect.position + _v(24.0, 310.0), 18, Color(0.93, 0.96, 0.91, 1.0), rect.size.x - 48.0 * _ui_scale, 7)

	var stats := ItemCodexPresenterScript.stat_rows(self, item)
	var stat_y := rect.position.y + rect.size.y - (float(stats.size()) * 48.0 + 16.0) * _ui_scale
	for index in range(stats.size()):
		var stat := stats[index]
		_paint_stat_line(Vector2(rect.position.x + 24.0 * _ui_scale, stat_y + float(index) * 48.0 * _ui_scale), str(stat.get("label", "")), str(stat.get("value", "")), rect.size.x - 48.0 * _ui_scale)


func _paint_item_icon(center: Vector2, item: ItemDef, radius: float = 22.0) -> void:
	var r := radius * _ui_scale
	var color := ItemCodexPresenterScript.codex_category_color(item)
	draw_circle(center, r, color)
	draw_circle(center, r, Color(1.0, 1.0, 1.0, 0.16), false, maxf(2.0 * _ui_scale, 1.0))
	_paint_text(_item_name(item).left(1), center + Vector2(-r, r * 0.36), int(17.0 * _ui_scale), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0)


func _paint_stat_line(draw_position: Vector2, label: String, value: String, width: float) -> void:
	var row_rect := Rect2(draw_position, Vector2(width, 36.0 * _ui_scale))
	_paint_panel(row_rect, Color(0.0, 0.0, 0.0, 0.18), Color.TRANSPARENT, 0, 8)
	_paint_text(label, row_rect.position + _v(14.0, 25.0), 15, Color(0.82, 0.88, 0.86, 1.0), HORIZONTAL_ALIGNMENT_LEFT, row_rect.size.x * 0.48)
	_paint_text(value, row_rect.position + Vector2(row_rect.size.x * 0.52, 25.0 * _ui_scale), 15, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, row_rect.size.x * 0.42)


func _paint_wrapped_text(text: String, draw_position: Vector2, font_size: int, color: Color, width: float, max_lines: int) -> void:
	var font := get_theme_default_font()
	var lines := _wrap_text(font, text, font_size, width)
	for index in range(mini(lines.size(), max_lines)):
		_paint_text(lines[index], draw_position + Vector2(0.0, float(index) * 24.0 * _ui_scale), font_size, color, HORIZONTAL_ALIGNMENT_LEFT, width)


func _wrap_text(font: Font, text: String, font_size: int, width: float) -> Array[String]:
	var words := text.split(" ", false)
	var lines: Array[String] = []
	var current := ""
	var scaled_font_size := maxi(11, roundi(float(font_size) * _ui_scale))
	for word in words:
		if font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, scaled_font_size).x > width:
			if current != "":
				lines.append(current)
				current = ""
			lines.append_array(_wrap_long_word(font, word, scaled_font_size, width))
			continue
		var candidate := word if current == "" else "%s %s" % [current, word]
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, scaled_font_size).x <= width:
			current = candidate
		else:
			if current != "":
				lines.append(current)
			current = word
	if current != "":
		lines.append(current)
	if lines.is_empty() and text != "":
		lines.append(text)
	return lines


func _wrap_long_word(font: Font, text: String, font_size: int, width: float) -> Array[String]:
	var lines: Array[String] = []
	var current := ""
	for index in range(text.length()):
		var next_char := text.substr(index, 1)
		var candidate := current + next_char
		if current != "" and font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > width:
			lines.append(current)
			current = next_char
		else:
			current = candidate
	if current != "":
		lines.append(current)
	return lines


func _scroll_node_grid(direction: int) -> void:
	if _grid_scroll == null:
		return
	_grid_scroll.scroll_vertical = maxi(0, _grid_scroll.scroll_vertical + direction * roundi(96.0 * _ui_scale))


func _item_name(item: ItemDef) -> String:
	return ItemCodexPresenterScript.item_name(self, item)


func _localized_text(key: StringName) -> String:
	return ItemCodexPresenterScript.localized_text(self, key)


func _update_layout_for_viewport(viewport_size: Vector2) -> void:
	_ui_scale = UILayoutHelper.design_scale(viewport_size, 0.65, 1.1)
	_content_rect = UILayoutHelper.centered_content_rect(viewport_size, DESIGN_CONTENT_SIZE, 0.65, 1.1)


func _update_layout_scale(viewport_size: Vector2) -> void:
	_update_layout_for_viewport(viewport_size)


func preview_layout(viewport_size: Vector2) -> Dictionary:
	_update_layout_for_viewport(viewport_size)
	return _layout_rects()


func get_display_state_for_viewport(viewport_size: Vector2) -> Dictionary:
	var layout := preview_layout(viewport_size)
	var grid_rect: Rect2 = layout.get("grid_rect", Rect2())
	if is_open:
		_sync_grid_panel(grid_rect)
	var slot_size := _calculate_node_slot_size_for_rect(grid_rect)
	var gap := 10.0 * _ui_scale
	var row_count := ceili(float(_grid_model.slot_count) / float(GRID_COLUMNS))
	var grid_content_size := Vector2(
		slot_size.x * float(GRID_COLUMNS) + gap * float(GRID_COLUMNS - 1),
		slot_size.y * float(row_count) + gap * float(maxi(row_count - 1, 0))
	)
	var visible_grid_rect := grid_rect.grow(-GRID_INNER_PADDING * _ui_scale)
	return {
		"visible": is_open,
		"left_panel_rect": layout.get("left_panel_rect", Rect2()),
		"right_panel_rect": layout.get("right_panel_rect", Rect2()),
		"grid_rect": grid_rect,
		"visible_grid_rect": visible_grid_rect,
		"grid_content_rect": Rect2(visible_grid_rect.position, grid_content_size),
		"actual_grid_panel_rect": _actual_global_rect(_grid_panel),
		"actual_grid_container_rect": _actual_global_rect(_grid_container),
		"actual_slot_union_rect": _actual_slot_union_rect(),
		"local_slot_union_rect": _local_slot_union_rect(),
		"slot_size": slot_size,
		"columns": GRID_COLUMNS,
		"visible_rows": VISIBLE_ROWS,
	}


func get_display_state() -> Dictionary:
	return get_display_state_for_viewport(get_viewport_rect().size)


func _layout_rects() -> Dictionary:
	var left_rect := _left_panel_rect()
	var right_rect := _right_panel_rect()
	return {
		"left_panel_rect": left_rect,
		"right_panel_rect": right_rect,
		"header_rect": Rect2(left_rect.position + _v(20.0, 18.0), Vector2(left_rect.size.x - 40.0 * _ui_scale, 42.0 * _ui_scale)),
		"grid_rect": Rect2(left_rect.position + _v(24.0, 78.0), Vector2(left_rect.size.x - 48.0 * _ui_scale, left_rect.size.y - 102.0 * _ui_scale)),
	}


func _actual_global_rect(control: Control) -> Rect2:
	if control == null or not control.is_inside_tree():
		return Rect2()
	return control.get_global_rect()


func _actual_slot_union_rect() -> Rect2:
	var union_rect := Rect2()
	var has_rect := false
	for slot in _slot_buttons:
		var control := slot as Control
		if control == null or not control.is_inside_tree():
			continue
		var rect := control.get_global_rect()
		if not has_rect:
			union_rect = rect
			has_rect = true
		else:
			union_rect = union_rect.merge(rect)
	return union_rect


func _local_slot_union_rect() -> Rect2:
	var union_rect := Rect2()
	var has_rect := false
	for slot in _slot_buttons:
		var control := slot as Control
		if control == null:
			continue
		var rect := Rect2(control.position, control.size)
		if not has_rect:
			union_rect = rect
			has_rect = true
		else:
			union_rect = union_rect.merge(rect)
	return union_rect


func _left_panel_rect() -> Rect2:
	var detail_width := 430.0 * _ui_scale
	var gap := 18.0 * _ui_scale
	var width := _content_rect.size.x - detail_width - gap
	return Rect2(_content_rect.position, Vector2(width, _content_rect.size.y))


func _right_panel_rect() -> Rect2:
	var left_rect := _left_panel_rect()
	var gap := 18.0 * _ui_scale
	return Rect2(Vector2(left_rect.end.x + gap, left_rect.position.y), Vector2(430.0 * _ui_scale, left_rect.size.y))


func _paint_header(rect: Rect2, text: String) -> void:
	_paint_panel(rect, Color(0.28, 0.31, 0.29, 0.78), Color.TRANSPARENT, 0, 10)
	_paint_text(text, rect.position + _v(16.0, 29.0), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 32.0 * _ui_scale)


func _paint_panel(rect: Rect2, fill_color: Color, border_color: Color, border_width: int, radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_border_width_all(roundi(float(border_width) * _ui_scale))
	style.set_corner_radius_all(roundi(float(radius) * _ui_scale))
	draw_style_box(style, rect)


func _paint_panel_shadow(rect: Rect2) -> void:
	_paint_panel(Rect2(rect.position + _v(10.0, 10.0), rect.size), Color(0.0, 0.0, 0.0, 0.18), Color.TRANSPARENT, 0, 20)


func _paint_text(text: String, text_position: Vector2, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(get_theme_default_font(), text_position, text, alignment, width, maxi(11, roundi(float(font_size) * _ui_scale)), color)


func _v(x: float, y: float) -> Vector2:
	return Vector2(x, y) * _ui_scale
