extends Control

const UILayoutHelper := preload("res://scripts/ui/ui_layout.gd")

signal selected_changed(index: int, id: StringName)
signal menu_item_requested(id: StringName)

const MENU_ITEMS: Array[Dictionary] = [
	{"id": &"backpack"},
	{"id": &"quests"},
	{"id": &"status"},
	{"id": &"map"},
	{"id": &"codex"},
]

@export var selected_index: int = 0
@export var button_size: Vector2 = Vector2(55.0, 55.0)
@export var button_gap: float = 24.0
@export var panel_color: Color = Color(0.33, 0.35, 0.35, 0.46)

const DESIGN_PANEL_SIZE := Vector2(700.0, 84.0)
const DESIGN_TOP_MARGIN := 20.0

var _button_rects: Array[Rect2] = []
var _layout_scale: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_as_relative = false
	z_index = 100
	visible = false
	_apply_responsive_layout()
	if not get_viewport().size_changed.is_connected(_apply_responsive_layout):
		get_viewport().size_changed.connect(_apply_responsive_layout)
	_move_to_front.call_deferred()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_RIGHT:
				if not visible:
					return
				select_index(selected_index + 1)
				get_viewport().set_input_as_handled()
			KEY_LEFT:
				if not visible:
					return
				select_index(selected_index - 1)
				get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for index in range(_button_rects.size()):
			if _button_rects[index].has_point(event.position):
				select_index(index)
				menu_item_requested.emit(MENU_ITEMS[index].get("id", &""))
				accept_event()
				return


func select_index(index: int) -> void:
	selected_index = wrapi(index, 0, MENU_ITEMS.size())
	selected_changed.emit(selected_index, MENU_ITEMS[selected_index].get("id", &""))
	queue_redraw()


func select_item(id: StringName) -> void:
	for index in range(MENU_ITEMS.size()):
		if MENU_ITEMS[index].get("id", &"") == id:
			select_index(index)
			return


func get_selected_item_id() -> StringName:
	return StringName(MENU_ITEMS[selected_index].get("id", &""))


func _move_to_front() -> void:
	if get_parent() != null:
		get_parent().move_child(self, get_parent().get_child_count() - 1)


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var panel_rect := UILayoutHelper.centered_top_rect(viewport_size, DESIGN_PANEL_SIZE, DESIGN_TOP_MARGIN, 0.75, 1.1)
	_layout_scale = panel_rect.size.x / DESIGN_PANEL_SIZE.x
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = panel_rect.position
	size = panel_rect.size
	queue_redraw()


func _draw() -> void:
	_button_rects.clear()
	_paint_panel(Rect2(Vector2.ZERO, size))
	var scaled_button_size := button_size * _layout_scale
	var scaled_button_gap := button_gap * _layout_scale
	var total_width := float(MENU_ITEMS.size()) * scaled_button_size.x + float(MENU_ITEMS.size() - 1) * scaled_button_gap
	var start_x := (size.x - total_width) * 0.5
	var start_y := (size.y - scaled_button_size.y) * 0.5

	for index in range(MENU_ITEMS.size()):
		var rect := Rect2(Vector2(start_x + float(index) * (scaled_button_size.x + scaled_button_gap), start_y), scaled_button_size)
		_button_rects.append(rect)
		_paint_button(rect, index)


func _paint_panel(rect: Rect2) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = panel_color
	style.border_color = Color(0.70, 0.78, 0.82, 0.18)
	style.set_border_width_all(maxi(1, roundi(_layout_scale)))
	style.set_corner_radius_all(roundi(22.0 * _layout_scale))
	draw_style_box(style, rect.grow(-2.0 * _layout_scale))


func _paint_button(rect: Rect2, index: int) -> void:
	var is_selected := index == selected_index
	var center := rect.get_center()
	if is_selected:
		draw_circle(center, rect.size.x * 0.5, Color(0.06, 0.64, 1.0, 0.95))
		draw_circle(center, rect.size.x * 0.5 + 4.0 * _layout_scale, Color(0.20, 0.82, 1.0, 0.22))

	_paint_icon(index, center + Vector2(0.0, 1.0 * _layout_scale), rect.size.x * 0.39, Color(0.33, 0.88, 1.0, 0.26), 6.0 * _layout_scale)
	_paint_icon(index, center + Vector2(0.0, 1.0 * _layout_scale), rect.size.x * 0.39, Color.WHITE, 3.0 * _layout_scale)


func _paint_icon(index: int, center: Vector2, radius: float, color: Color, width: float) -> void:
	match index:
		0:
			_paint_backpack_icon(center, radius, color, width)
		1:
			_paint_quest_icon(center, radius, color, width)
		2:
			_paint_status_icon(center, radius, color, width)
		3:
			_paint_map_icon(center, radius, color, width)
		_:
			_paint_codex_icon(center, radius, color, width)


func _paint_backpack_icon(center: Vector2, r: float, color: Color, width: float) -> void:
	var body := Rect2(center + Vector2(-0.48, -0.18) * r, Vector2(0.96, 0.86) * r)
	draw_arc(center + Vector2(0.0, -0.26) * r, 0.28 * r, PI, TAU, 20, color, width)
	draw_rect(body, color, false, width)
	draw_line(center + Vector2(-0.28, 0.12) * r, center + Vector2(0.28, 0.12) * r, color, width)
	draw_rect(Rect2(center + Vector2(-0.14, 0.18) * r, Vector2(0.28, 0.22) * r), color, false, width)


func _paint_quest_icon(center: Vector2, r: float, color: Color, width: float) -> void:
	draw_rect(Rect2(center + Vector2(-0.42, -0.52) * r, Vector2(0.84, 1.04) * r), color, false, width)
	draw_line(center + Vector2(-0.20, -0.10) * r, center + Vector2(0.18, -0.10) * r, color, width)
	draw_line(center + Vector2(-0.20, 0.12) * r, center + Vector2(0.10, 0.12) * r, color, width)
	draw_line(center + Vector2(-0.10, 0.34) * r, center + Vector2(0.05, 0.48) * r, color, width)
	draw_line(center + Vector2(0.05, 0.48) * r, center + Vector2(0.32, 0.20) * r, color, width)
	draw_circle(center + Vector2(0.0, -0.58) * r, 0.10 * r, color)


func _paint_status_icon(center: Vector2, r: float, color: Color, width: float) -> void:
	draw_circle(center + Vector2(-0.20, -0.34) * r, 0.16 * r, color)
	draw_line(center + Vector2(-0.20, -0.12) * r, center + Vector2(-0.20, 0.42) * r, color, width)
	draw_line(center + Vector2(-0.42, 0.04) * r, center + Vector2(0.02, 0.04) * r, color, width)
	draw_line(center + Vector2(-0.20, 0.42) * r, center + Vector2(-0.42, 0.68) * r, color, width)
	draw_line(center + Vector2(-0.20, 0.42) * r, center + Vector2(0.00, 0.68) * r, color, width)
	var heart := center + Vector2(0.34, 0.16) * r
	draw_arc(heart + Vector2(-0.10, -0.02) * r, 0.13 * r, PI, TAU, 12, color, width)
	draw_arc(heart + Vector2(0.10, -0.02) * r, 0.13 * r, PI, TAU, 12, color, width)
	draw_line(heart + Vector2(-0.23, 0.04) * r, heart + Vector2(0.0, 0.30) * r, color, width)
	draw_line(heart + Vector2(0.23, 0.04) * r, heart + Vector2(0.0, 0.30) * r, color, width)


func _paint_map_icon(center: Vector2, r: float, color: Color, width: float) -> void:
	var left := center + Vector2(-0.52, -0.42) * r
	var mid := center + Vector2(-0.10, -0.28) * r
	var right := center + Vector2(0.34, -0.42) * r
	var bottom_left := center + Vector2(-0.52, 0.48) * r
	var bottom_mid := center + Vector2(-0.10, 0.34) * r
	var bottom_right := center + Vector2(0.34, 0.48) * r
	draw_line(left, bottom_left, color, width)
	draw_line(mid, bottom_mid, color, width)
	draw_line(right, bottom_right, color, width)
	draw_line(left, mid, color, width)
	draw_line(mid, right, color, width)
	draw_line(bottom_left, bottom_mid, color, width)
	draw_line(bottom_mid, bottom_right, color, width)
	draw_circle(center + Vector2(0.50, -0.10) * r, 0.12 * r, color)


func _paint_codex_icon(center: Vector2, r: float, color: Color, width: float) -> void:
	var left := Rect2(center + Vector2(-0.56, -0.46) * r, Vector2(0.52, 0.92) * r)
	var right := Rect2(center + Vector2(0.04, -0.46) * r, Vector2(0.52, 0.92) * r)
	draw_rect(left, color, false, width)
	draw_rect(right, color, false, width)
	draw_line(center + Vector2(0.0, -0.46) * r, center + Vector2(0.0, 0.54) * r, color, width)
	draw_line(center + Vector2(0.18, -0.16) * r, center + Vector2(0.42, -0.16) * r, color, width)
	draw_line(center + Vector2(0.18, 0.08) * r, center + Vector2(0.42, 0.08) * r, color, width)
	draw_rect(Rect2(center + Vector2(-0.40, -0.18) * r, Vector2(0.22, 0.22) * r), color, false, width)
