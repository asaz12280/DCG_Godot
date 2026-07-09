class_name RecoilReticle
extends Control

const BASE_COLOR := Color(0.90, 0.98, 0.94, 0.58)
const RECOIL_COLOR := Color(1.0, 0.86, 0.42, 0.82)
const SHADOW_COLOR := Color(0.03, 0.06, 0.05, 0.55)
const OFFSET_SCALE := 5.0
const MAX_OFFSET := 42.0
const LINE_LENGTH := 8.0
const GAP := 5.0
const DOT_RADIUS := 2.25

var _recoil_state := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 80
	_update_size_from_viewport()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_update_size_from_viewport):
		get_viewport().size_changed.connect(_update_size_from_viewport)


func set_recoil_state(state: Dictionary) -> void:
	_recoil_state = state.duplicate(true)
	queue_redraw()


func get_display_state() -> Dictionary:
	var center := size * 0.5
	var offset := _recoil_offset()
	return {
		"visible": visible,
		"mouse_filter": mouse_filter,
		"size": size,
		"center": center,
		"offset": offset,
		"recoil_position": center + offset,
		"state": _recoil_state.duplicate(true),
	}


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var center := size * 0.5
	_draw_cross(center, BASE_COLOR, 1.25)
	var offset := _recoil_offset()
	if offset.length() <= 0.1:
		return
	var recoil_position := center + offset
	draw_circle(recoil_position + Vector2(1.0, 1.0), DOT_RADIUS + 1.0, SHADOW_COLOR)
	draw_circle(recoil_position, DOT_RADIUS, RECOIL_COLOR)
	draw_line(center, recoil_position, Color(RECOIL_COLOR.r, RECOIL_COLOR.g, RECOIL_COLOR.b, 0.28), 1.0)


func _draw_cross(center: Vector2, color: Color, width: float) -> void:
	draw_line(center + Vector2(-GAP - LINE_LENGTH, 0.0), center + Vector2(-GAP, 0.0), SHADOW_COLOR, width + 1.0)
	draw_line(center + Vector2(GAP, 0.0), center + Vector2(GAP + LINE_LENGTH, 0.0), SHADOW_COLOR, width + 1.0)
	draw_line(center + Vector2(0.0, -GAP - LINE_LENGTH), center + Vector2(0.0, -GAP), SHADOW_COLOR, width + 1.0)
	draw_line(center + Vector2(0.0, GAP), center + Vector2(0.0, GAP + LINE_LENGTH), SHADOW_COLOR, width + 1.0)
	draw_line(center + Vector2(-GAP - LINE_LENGTH, 0.0), center + Vector2(-GAP, 0.0), color, width)
	draw_line(center + Vector2(GAP, 0.0), center + Vector2(GAP + LINE_LENGTH, 0.0), color, width)
	draw_line(center + Vector2(0.0, -GAP - LINE_LENGTH), center + Vector2(0.0, -GAP), color, width)
	draw_line(center + Vector2(0.0, GAP), center + Vector2(0.0, GAP + LINE_LENGTH), color, width)


func _recoil_offset() -> Vector2:
	var horizontal := clampf(float(_recoil_state.get("accumulated_angle_degrees", 0.0)) * OFFSET_SCALE, -MAX_OFFSET, MAX_OFFSET)
	return Vector2(horizontal, 0.0)


func _update_size_from_viewport() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	queue_redraw()
