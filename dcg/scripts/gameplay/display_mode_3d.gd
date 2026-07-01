extends Node

const DESIGN_SIZE: Vector2i = Vector2i(1920, 1080)
const WINDOW_MARGIN: Vector2i = Vector2i(96, 96)


func _ready() -> void:
	var settings := get_node_or_null("/root/GameSettings")
	if settings != null and settings.has_method("apply_all"):
		settings.call("apply_all")
		return
	_apply_best_display_mode()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		if DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]:
			_apply_windowed_fit()
		else:
			_apply_fullscreen()


func _apply_best_display_mode() -> void:
	var screen_size := DisplayServer.screen_get_size()
	if screen_size.x >= DESIGN_SIZE.x and screen_size.y >= DESIGN_SIZE.y:
		_apply_fullscreen()
	else:
		_apply_windowed_fit()


func _apply_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _apply_windowed_fit() -> void:
	var screen_size := DisplayServer.screen_get_size()
	var available_size := Vector2i(
		maxi(640, screen_size.x - WINDOW_MARGIN.x),
		maxi(360, screen_size.y - WINDOW_MARGIN.y)
	)
	var scale := minf(float(available_size.x) / float(DESIGN_SIZE.x), float(available_size.y) / float(DESIGN_SIZE.y))
	var window_size := Vector2i(
		maxi(640, roundi(float(DESIGN_SIZE.x) * scale)),
		maxi(360, roundi(float(DESIGN_SIZE.y) * scale))
	)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(window_size)
	_center_window(screen_size, window_size)


func _center_window(screen_size: Vector2i, window_size: Vector2i) -> void:
	var window_position := Vector2i(
		maxi(0, int(floor(float(screen_size.x - window_size.x) / 2.0))),
		maxi(0, int(floor(float(screen_size.y - window_size.y) / 2.0)))
	)
	DisplayServer.window_set_position(window_position)
