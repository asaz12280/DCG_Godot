extends Control

@export var health_offset: Vector2 = Vector2(0.0, -76.0)
@export var stamina_offset: Vector2 = Vector2(-54.0, 70.0)
@export var health_size: Vector2 = Vector2(98.0, 16.0)
@export var lower_left_health_position: Vector2 = Vector2(42.0, -58.0)
@export var lower_left_health_size: Vector2 = Vector2(250.0, 44.0)
@export var ring_radius: float = 18.0
@export var ring_width: float = 6.0
@export var crosshair_color: Color = Color(0.98, 0.98, 0.94, 1.0)

var stamina: float = 100.0
var max_stamina: float = 100.0
var player: Node3D
var stamina_visible_time: float = 0.0
var health_background_style := StyleBoxFlat.new()
var health_fill_style := StyleBoxFlat.new()
var lower_left_panel_style := StyleBoxFlat.new()
var lower_left_fill_style := StyleBoxFlat.new()
var lower_left_icon_style := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_signal("stamina_changed"):
		player.stamina_changed.connect(_on_stamina_changed)
	_setup_health_styles()


func _process(delta: float) -> void:
	stamina_visible_time = maxf(stamina_visible_time - delta, 0.0)
	queue_redraw()


func _on_stamina_changed(current: float, maximum: float) -> void:
	if current < stamina - 0.05:
		stamina_visible_time = 1.2
	stamina = current
	max_stamina = maximum


func _draw() -> void:
	_paint_player_health()
	_paint_lower_left_health()
	_paint_stamina_ring()
	_paint_crosshair()


func _setup_health_styles() -> void:
	health_background_style.bg_color = Color(0.18, 0.18, 0.16, 0.82)
	health_background_style.corner_radius_top_left = 8
	health_background_style.corner_radius_top_right = 8
	health_background_style.corner_radius_bottom_left = 8
	health_background_style.corner_radius_bottom_right = 8
	health_fill_style.bg_color = Color(1.0, 0.24, 0.2, 1.0)
	health_fill_style.corner_radius_top_left = 6
	health_fill_style.corner_radius_top_right = 6
	health_fill_style.corner_radius_bottom_left = 6
	health_fill_style.corner_radius_bottom_right = 6
	lower_left_panel_style.bg_color = Color(0.16, 0.16, 0.16, 0.88)
	lower_left_panel_style.corner_radius_top_left = 22
	lower_left_panel_style.corner_radius_top_right = 22
	lower_left_panel_style.corner_radius_bottom_left = 22
	lower_left_panel_style.corner_radius_bottom_right = 22
	lower_left_fill_style.bg_color = Color(1.0, 0.36, 0.4, 0.96)
	lower_left_fill_style.corner_radius_top_left = 16
	lower_left_fill_style.corner_radius_top_right = 16
	lower_left_fill_style.corner_radius_bottom_left = 16
	lower_left_fill_style.corner_radius_bottom_right = 16
	lower_left_icon_style.bg_color = Color(0.26, 0.26, 0.26, 0.98)
	lower_left_icon_style.corner_radius_top_left = 20
	lower_left_icon_style.corner_radius_top_right = 20
	lower_left_icon_style.corner_radius_bottom_left = 20
	lower_left_icon_style.corner_radius_bottom_right = 20


func _get_player_screen_position(offset: Vector2) -> Vector2:
	var camera := get_viewport().get_camera_3d()
	if player == null or camera == null:
		return Vector2(-1000.0, -1000.0)
	return camera.unproject_position(player.global_position + Vector3(0.0, 0.75, 0.0)) + offset


func _paint_player_health() -> void:
	if player == null:
		return

	var current_health: float = player.get("health")
	var maximum_health: float = player.get_total_max_health() if player.has_method("get_total_max_health") else player.get("max_health")
	var ratio := clampf(current_health / maximum_health, 0.0, 1.0)
	var center := _get_player_screen_position(health_offset)
	var background_rect := Rect2(center - health_size * 0.5, health_size)
	var fill_rect := background_rect.grow(-4.0)
	fill_rect.size.x *= ratio

	draw_style_box(health_background_style, background_rect)
	draw_style_box(health_fill_style, fill_rect)


func _paint_lower_left_health() -> void:
	if player == null:
		return

	var current_health: float = player.get("health")
	var maximum_health: float = player.get_total_max_health() if player.has_method("get_total_max_health") else player.get("max_health")
	var ratio := clampf(current_health / maximum_health, 0.0, 1.0)
	var panel_position := Vector2(lower_left_health_position.x, size.y + lower_left_health_position.y)
	var panel_rect := Rect2(panel_position, lower_left_health_size)
	var icon_rect := Rect2(panel_rect.position + Vector2(7.0, 6.0), Vector2(36.0, 32.0))
	var bar_rect := Rect2(panel_rect.position + Vector2(48.0, 7.0), Vector2(panel_rect.size.x - 56.0, panel_rect.size.y - 14.0))
	var fill_rect := bar_rect.grow(-4.0)
	fill_rect.size.x *= ratio

	draw_style_box(lower_left_panel_style, panel_rect)
	draw_style_box(lower_left_icon_style, icon_rect)
	draw_style_box(lower_left_fill_style, fill_rect)
	_paint_heart_icon(icon_rect.get_center(), 12.0, Color(1.0, 0.36, 0.4, 1.0))

	var health_text := "%d / %d" % [roundi(current_health), roundi(maximum_health)]
	var font := ThemeDB.fallback_font
	var font_size := 22
	var text_size := font.get_string_size(health_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_position := bar_rect.position + (bar_rect.size - text_size) * 0.5 + Vector2(0.0, text_size.y * 0.72)
	draw_string(font, text_position, health_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 1.0, 1.0, 0.98))


func _paint_heart_icon(center: Vector2, icon_scale: float, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, 0.78) * icon_scale,
		center + Vector2(-0.92, -0.1) * icon_scale,
		center + Vector2(-0.72, -0.78) * icon_scale,
		center + Vector2(-0.24, -0.86) * icon_scale,
		center + Vector2(0.0, -0.55) * icon_scale,
		center + Vector2(0.24, -0.86) * icon_scale,
		center + Vector2(0.72, -0.78) * icon_scale,
		center + Vector2(0.92, -0.1) * icon_scale,
	])
	draw_colored_polygon(points, color)


func _paint_stamina_ring() -> void:
	if stamina >= max_stamina - 0.05 and stamina_visible_time <= 0.0:
		return

	var center := _get_player_screen_position(stamina_offset)
	var ratio := clampf(stamina / max_stamina, 0.0, 1.0)
	var draw_scale := 2.0

	draw_set_transform(center, 0.0, Vector2(1.0 / draw_scale, 1.0 / draw_scale))
	draw_circle(Vector2.ZERO, (ring_radius + 8.0) * draw_scale, Color(0.16, 0.16, 0.16, 0.72))
	draw_arc(Vector2.ZERO, ring_radius * draw_scale, 0.0, TAU, 160, Color(0.78, 0.78, 0.72, 1.0), (ring_width + 4.0) * draw_scale, true)
	draw_arc(Vector2.ZERO, ring_radius * draw_scale, -PI * 0.5, -PI * 0.5 + TAU * ratio, 160, Color(0.56, 1.0, 0.48, 1.0), ring_width * draw_scale, true)
	draw_circle(Vector2.ZERO, 7.0 * draw_scale, Color(0.86, 0.88, 0.82, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _paint_crosshair() -> void:
	var center := get_viewport().get_mouse_position()
	if center.x <= 0.0 or center.y <= 0.0 or center.x >= size.x or center.y >= size.y:
		center = size * 0.5
	var shadow := Color(0.12, 0.12, 0.12, 0.7)
	var gap := 13.0
	var length := 12.0
	var width := 4.0

	_paint_crosshair_line(center + Vector2(-gap - length, 0.0), center + Vector2(-gap, 0.0), shadow, width + 2.0)
	_paint_crosshair_line(center + Vector2(gap, 0.0), center + Vector2(gap + length, 0.0), shadow, width + 2.0)
	_paint_crosshair_line(center + Vector2(0.0, -gap - length), center + Vector2(0.0, -gap), shadow, width + 2.0)
	_paint_crosshair_line(center + Vector2(0.0, gap), center + Vector2(0.0, gap + length), shadow, width + 2.0)

	_paint_crosshair_line(center + Vector2(-gap - length, 0.0), center + Vector2(-gap, 0.0), crosshair_color, width)
	_paint_crosshair_line(center + Vector2(gap, 0.0), center + Vector2(gap + length, 0.0), crosshair_color, width)
	_paint_crosshair_line(center + Vector2(0.0, -gap - length), center + Vector2(0.0, -gap), crosshair_color, width)
	_paint_crosshair_line(center + Vector2(0.0, gap), center + Vector2(0.0, gap + length), crosshair_color, width)


func _paint_crosshair_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	draw_line(from, to, color, width, true)
