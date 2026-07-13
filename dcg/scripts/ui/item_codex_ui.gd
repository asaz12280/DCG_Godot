extends Control

const UILayoutHelper := preload("res://scripts/ui/ui_layout.gd")
const ItemCodexGridModelScript := preload("res://scripts/ui/item_codex_grid_model.gd")
const ItemCodexSlotScript := preload("res://scripts/ui/components/item_codex_slot.gd")
const ItemCodexCatalogScript := preload("res://scripts/ui/item_codex_catalog.gd")
const ItemCodexPresenterScript := preload("res://scripts/ui/item_codex_presenter.gd")
const ItemInspectionFieldPolicyScript := preload("res://scripts/ui/item_inspection_field_policy.gd")
const UISurfacePaletteScript := preload("res://scripts/ui/ui_surface_palette.gd")

const MIN_CATALOG_SLOT_COUNT := 100
const GRID_COLUMNS := 10
const VISIBLE_ROWS := 6
const DESIGN_CONTENT_SIZE := UISurfacePaletteScript.SIZE_TOP_MENU_PANEL
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
var _detail_panel: PanelContainer = null
var _detail_margin: MarginContainer = null
var _detail_scroll: ScrollContainer = null
var _detail_content: VBoxContainer = null
var _slot_buttons: Array = []
var _last_grid_rect: Rect2 = Rect2()
var _last_detail_rect: Rect2 = Rect2()
var _detail_dirty: bool = true
var _detail_signature := ""
var _slots_dirty: bool = true


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_model.columns = GRID_COLUMNS
	_grid_model.visible_rows = VISIBLE_ROWS
	_grid_model.minimum_slots = MIN_CATALOG_SLOT_COUNT
	_build_grid_controls()
	_build_detail_controls()
	_reload_items()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _last_detail_rect.has_point(event.position):
				accept_event()
				return
			_scroll_node_grid(1)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if _last_detail_rect.has_point(event.position):
				accept_event()
				return
			_scroll_node_grid(-1)
			accept_event()


func open_codex() -> void:
	_reload_items()
	is_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _grid_panel != null:
		_grid_panel.visible = true
	if _detail_panel != null:
		_detail_panel.visible = true
	queue_redraw()


func close_codex() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _grid_panel != null:
		_grid_panel.visible = false
	if _detail_panel != null:
		_detail_panel.visible = false
	queue_redraw()


func toggle_codex() -> void:
	if is_open:
		close_codex()
	else:
		open_codex()


func _on_localization_changed() -> void:
	_slots_dirty = true
	_detail_dirty = true
	_rebuild_grid_slots()
	queue_redraw()


func _draw() -> void:
	if not is_open:
		return
	var viewport_size := get_viewport_rect().size
	_update_layout_for_viewport(viewport_size)
	draw_rect(Rect2(Vector2.ZERO, viewport_size), UISurfacePaletteScript.overlay_scrim())

	var layout := _layout_rects()
	var left_rect: Rect2 = layout.get("left_panel_rect", Rect2())
	var right_rect: Rect2 = layout.get("right_panel_rect", Rect2())
	var header_rect: Rect2 = layout.get("header_rect", Rect2())
	var grid_rect: Rect2 = layout.get("grid_rect", Rect2())

	_paint_panel_shadow(left_rect)
	_paint_panel(left_rect, UISurfacePaletteScript.panel_fill(), UISurfacePaletteScript.panel_border(), 1, UISurfacePaletteScript.RADIUS_TOP_MENU_PANEL)
	_paint_header(header_rect, _localized_text(&"ui.codex.title"))
	_paint_panel(grid_rect, UISurfacePaletteScript.section_fill(), UISurfacePaletteScript.slot_border(true), 1, 10)
	_sync_grid_panel(grid_rect)
	_paint_panel_shadow(right_rect)
	_paint_detail(right_rect)


func _reload_items() -> void:
	_catalog.reload()
	_grid_model.configure(_catalog.highest_catalog_number())
	selected_slot = clampi(selected_slot, 1, _grid_model.slot_count)
	_slots_dirty = true
	_detail_dirty = true
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


func _build_detail_controls() -> void:
	_detail_panel = PanelContainer.new()
	_detail_panel.visible = false
	_detail_panel.clip_contents = true
	_detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_detail_panel)

	_detail_margin = MarginContainer.new()
	_detail_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_panel.add_child(_detail_margin)

	_detail_scroll = ScrollContainer.new()
	_detail_scroll.clip_contents = true
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_detail_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_margin.add_child(_detail_scroll)

	_detail_content = VBoxContainer.new()
	_detail_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.add_child(_detail_content)


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
	if selected_slot != catalog_number:
		_detail_dirty = true
		if _detail_scroll != null:
			_detail_scroll.scroll_vertical = 0
	selected_slot = catalog_number
	_update_slot_selection()
	queue_redraw()


func _update_slot_selection() -> void:
	for slot in _slot_buttons:
		if slot != null and slot.has_method("set_selected"):
			slot.set_selected(int(slot.catalog_number) == selected_slot)


func _paint_detail(rect: Rect2) -> void:
	_paint_panel(rect, UISurfacePaletteScript.panel_fill(), UISurfacePaletteScript.panel_border(), 1, 12)
	_paint_text(ItemCodexPresenterScript.catalog_label(selected_slot), rect.position + _v(24.0, 42.0), 18, UISurfacePaletteScript.TEXT_SECONDARY, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 48.0 * _ui_scale)
	var item := _catalog.get_item(selected_slot)
	if item == null:
		_sync_detail_panel(rect, null)
		_paint_text(_localized_text(&"ui.codex.empty_slot"), rect.position + _v(24.0, 90.0), 20, UISurfacePaletteScript.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 48.0 * _ui_scale)
		return

	_paint_item_icon(rect.position + _v(88.0, 120.0), item, 48.0)
	_paint_text(_item_name(item), rect.position + _v(24.0, 206.0), 24, UISurfacePaletteScript.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 48.0 * _ui_scale)
	_paint_text(ItemCodexPresenterScript.codex_category_name(self, item), rect.position + _v(24.0, 242.0), 18, UISurfacePaletteScript.TEXT_SECONDARY, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 48.0 * _ui_scale)
	_sync_detail_panel(rect, item)


func _sync_detail_panel(detail_panel_rect: Rect2, item: ItemDef) -> void:
	if _detail_panel == null:
		return
	var content_rect := _detail_content_rect(detail_panel_rect)
	_last_detail_rect = content_rect
	_detail_panel.visible = is_open and item != null
	if item == null:
		return
	_detail_panel.position = content_rect.position
	_detail_panel.size = content_rect.size
	_detail_panel.custom_minimum_size = Vector2.ZERO
	_detail_panel.add_theme_stylebox_override("panel", _make_panel_style(UISurfacePaletteScript.section_fill(), UISurfacePaletteScript.slot_border(true), 1, 10))
	if _detail_margin != null:
		var margin := roundi(14.0 * _ui_scale)
		_detail_margin.add_theme_constant_override("margin_left", margin)
		_detail_margin.add_theme_constant_override("margin_right", margin)
		_detail_margin.add_theme_constant_override("margin_top", margin)
		_detail_margin.add_theme_constant_override("margin_bottom", margin)
		_detail_margin.position = Vector2.ZERO
		_detail_margin.size = content_rect.size
	if _detail_scroll != null:
		_detail_scroll.position = Vector2.ZERO
		_detail_scroll.size = Vector2(maxf(content_rect.size.x - 28.0 * _ui_scale, 1.0), maxf(content_rect.size.y - 28.0 * _ui_scale, 1.0))
	var signature := "%s|%s|%.3f" % [item.resource_path, TranslationServer.get_locale(), _ui_scale]
	if _detail_dirty or _detail_signature != signature:
		_detail_signature = signature
		_rebuild_detail_content(item)
		_detail_dirty = false


func _detail_content_rect(detail_panel_rect: Rect2) -> Rect2:
	var margin_x := 24.0 * _ui_scale
	var top := 286.0 * _ui_scale
	var bottom := 24.0 * _ui_scale
	return Rect2(
		detail_panel_rect.position + Vector2(margin_x, top),
		Vector2(maxf(detail_panel_rect.size.x - margin_x * 2.0, 1.0), maxf(detail_panel_rect.size.y - top - bottom, 1.0))
	)


func _rebuild_detail_content(item: ItemDef) -> void:
	if _detail_content == null:
		return
	for child in _detail_content.get_children():
		_detail_content.remove_child(child)
		child.free()
	var info_title_key := ItemInspectionFieldPolicyScript.section_title_key(item.item_type, ItemInspectionFieldPolicyScript.SECTION_INFO)
	var stats_title_key := ItemInspectionFieldPolicyScript.section_title_key(item.item_type, ItemInspectionFieldPolicyScript.SECTION_STATS)
	_detail_content.add_child(_section_label(_localized_text(info_title_key)))
	for line in ItemCodexPresenterScript.info_lines(self, item):
		_detail_content.add_child(_body_label(line))
	var stats := ItemCodexPresenterScript.stat_rows(self, item)
	if not stats.is_empty():
		_detail_content.add_child(_spacer(8.0))
		_detail_content.add_child(_section_label(_localized_text(stats_title_key)))
		for index in range(stats.size()):
			var stat := stats[index] as Dictionary
			_detail_content.add_child(_detail_stat_row(str(stat.get("label", "")), str(stat.get("value", "")), index))


func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2.ZERO
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", maxi(12, roundi(16.0 * _ui_scale)))
	label.add_theme_color_override("font_color", UISurfacePaletteScript.TEXT_SECONDARY)
	return label


func _body_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2.ZERO
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", maxi(12, roundi(18.0 * _ui_scale)))
	label.add_theme_color_override("font_color", UISurfacePaletteScript.TEXT_PRIMARY)
	return label


func _detail_stat_row(label_text: String, value_text: String, index: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0.0, 36.0 * _ui_scale)
	row.add_theme_stylebox_override("panel", _make_panel_style(UISurfacePaletteScript.row_fill(index), UISurfacePaletteScript.TRANSPARENT, 0, 8))

	var margin := MarginContainer.new()
	var side_margin := roundi(12.0 * _ui_scale)
	margin.add_theme_constant_override("margin_left", side_margin)
	margin.add_theme_constant_override("margin_right", side_margin)
	row.add_child(margin)

	var row_box := HBoxContainer.new()
	row_box.custom_minimum_size = Vector2.ZERO
	row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(row_box)

	var label := Label.new()
	label.text = label_text
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size = Vector2.ZERO
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_stretch_ratio = 1.35
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", maxi(12, roundi(17.0 * _ui_scale)))
	label.add_theme_color_override("font_color", UISurfacePaletteScript.TEXT_SECONDARY)
	row_box.add_child(label)

	var value := Label.new()
	value.text = value_text
	value.clip_text = true
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value.custom_minimum_size = Vector2.ZERO
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.size_flags_stretch_ratio = 1.0
	value.add_theme_font_size_override("font_size", maxi(12, roundi(17.0 * _ui_scale)))
	value.add_theme_color_override("font_color", UISurfacePaletteScript.TEXT_PRIMARY)
	row_box.add_child(value)
	return row


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, height * _ui_scale)
	return spacer


func _make_panel_style(fill_color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_border_width_all(roundi(float(border_width) * _ui_scale))
	style.set_corner_radius_all(roundi(float(radius) * _ui_scale))
	return style


func _paint_item_icon(center: Vector2, item: ItemDef, radius: float = 22.0) -> void:
	var r := radius * _ui_scale
	var color := ItemCodexPresenterScript.codex_category_color(item)
	draw_circle(center, r, color)
	draw_circle(center, r, UISurfacePaletteScript.panel_highlight(), false, maxf(2.0 * _ui_scale, 1.0))
	_paint_text(_item_name(item).left(1), center + Vector2(-r, r * 0.36), int(17.0 * _ui_scale), UISurfacePaletteScript.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0)


func _scroll_node_grid(direction: int) -> void:
	if _grid_scroll == null:
		return
	_grid_scroll.scroll_vertical = maxi(0, _grid_scroll.scroll_vertical + direction * roundi(96.0 * _ui_scale))


func _item_name(item: ItemDef) -> String:
	return ItemCodexPresenterScript.item_name(self, item)


func _localized_text(key: StringName) -> String:
	return ItemCodexPresenterScript.localized_text(self, key)


func _update_layout_for_viewport(viewport_size: Vector2) -> void:
	_ui_scale = UILayoutHelper.design_scale(viewport_size, UISurfacePaletteScript.TOP_MENU_PANEL_MIN_SCALE, 1.0)
	_content_rect = UILayoutHelper.centered_top_rect(
		viewport_size,
		DESIGN_CONTENT_SIZE,
		UISurfacePaletteScript.TOP_MENU_PANEL_TOP_MARGIN,
		UISurfacePaletteScript.TOP_MENU_PANEL_MIN_SCALE,
		1.0
	)
	_content_rect.size.y = minf(_content_rect.size.y, viewport_size.y * UISurfacePaletteScript.TOP_MENU_PANEL_MAX_VIEWPORT_HEIGHT_RATIO)


func _update_layout_scale(viewport_size: Vector2) -> void:
	_update_layout_for_viewport(viewport_size)


func preview_layout(viewport_size: Vector2) -> Dictionary:
	_update_layout_for_viewport(viewport_size)
	return _layout_rects()


func get_display_state_for_viewport(viewport_size: Vector2) -> Dictionary:
	var layout := preview_layout(viewport_size)
	var grid_rect: Rect2 = layout.get("grid_rect", Rect2())
	var right_rect: Rect2 = layout.get("right_panel_rect", Rect2())
	var selected_item := _catalog.get_item(selected_slot)
	if is_open:
		_sync_grid_panel(grid_rect)
		_sync_detail_panel(right_rect, selected_item)
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
		"right_panel_rect": right_rect,
		"title_origin": layout.get("title_origin", Vector2()),
		"title_text_position": _title_text_position(),
		"grid_rect": grid_rect,
		"visible_grid_rect": visible_grid_rect,
		"grid_content_rect": Rect2(visible_grid_rect.position, grid_content_size),
		"detail_content_rect": _detail_content_rect(right_rect),
		"actual_detail_panel_rect": _actual_global_rect(_detail_panel),
		"actual_detail_content_rect": _actual_global_rect(_detail_content),
		"detail_panel_has_scroll_container": _detail_scroll != null,
		"detail_visible_text": _detail_visible_text(),
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
	var header_offset := UISurfacePaletteScript.TOP_MENU_HEADER_OFFSET * _ui_scale
	return {
		"left_panel_rect": left_rect,
		"right_panel_rect": right_rect,
		"title_origin": _content_rect.position + UISurfacePaletteScript.TOP_MENU_TITLE_ORIGIN * _ui_scale,
		"header_rect": Rect2(left_rect.position + header_offset, Vector2(left_rect.size.x - header_offset.x * 2.0, UISurfacePaletteScript.TOP_MENU_HEADER_HEIGHT * _ui_scale)),
		"grid_rect": Rect2(left_rect.position + _v(24.0, 78.0), Vector2(left_rect.size.x - 48.0 * _ui_scale, left_rect.size.y - 102.0 * _ui_scale)),
	}


func _actual_global_rect(control: Control) -> Rect2:
	if control == null or not control.is_inside_tree():
		return Rect2()
	return control.get_global_rect()


func _detail_visible_text() -> String:
	if _detail_content == null:
		return ""
	var parts := PackedStringArray()
	_collect_label_text(_detail_content, parts)
	return "\n".join(parts)


func _collect_label_text(node: Node, parts: PackedStringArray) -> void:
	var label := node as Label
	if label != null and label.text != "":
		parts.append(label.text)
	for child in node.get_children():
		_collect_label_text(child, parts)


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
	var text_position := _title_text_position()
	var text_width := maxf(rect.end.x - text_position.x - float(UISurfacePaletteScript.SPACE_LG) * _ui_scale, 1.0)
	_paint_text(text, text_position, UISurfacePaletteScript.FONT_PANEL_TITLE, UISurfacePaletteScript.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_LEFT, text_width)


func _title_text_position() -> Vector2:
	var font_size := maxi(18, roundi(float(UISurfacePaletteScript.FONT_PANEL_TITLE) * _ui_scale))
	var title_origin := _content_rect.position + UISurfacePaletteScript.TOP_MENU_TITLE_ORIGIN * _ui_scale
	return title_origin + Vector2(0.0, get_theme_default_font().get_ascent(font_size))


func _paint_panel(rect: Rect2, fill_color: Color, border_color: Color, border_width: int, radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_border_width_all(roundi(float(border_width) * _ui_scale))
	style.set_corner_radius_all(roundi(float(radius) * _ui_scale))
	draw_style_box(style, rect)


func _paint_panel_shadow(rect: Rect2) -> void:
	_paint_panel(Rect2(rect.position + _v(10.0, 10.0), rect.size), UISurfacePaletteScript.shadow(), UISurfacePaletteScript.TRANSPARENT, 0, UISurfacePaletteScript.RADIUS_TOP_MENU_PANEL)


func _paint_text(text: String, text_position: Vector2, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(get_theme_default_font(), text_position, text, alignment, width, maxi(18, roundi(float(font_size) * _ui_scale)), color)


func _v(x: float, y: float) -> Vector2:
	return Vector2(x, y) * _ui_scale
