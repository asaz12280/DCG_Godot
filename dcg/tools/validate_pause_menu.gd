extends SceneTree

const PauseMenuScript := preload("res://scripts/ui/pause_menu.gd")

var _errors: Array[String] = []


func _initialize() -> void:
	var pause_menu := PauseMenuScript.new()
	root.add_child(pause_menu)
	await process_frame

	pause_menu.open_pause()
	if not pause_menu.visible:
		_errors.append("PauseMenu did not become visible.")
	if not paused:
		_errors.append("SceneTree did not enter paused state.")
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		_errors.append("Mouse mode is not visible while paused.")

	pause_menu.close_pause()
	if pause_menu.visible:
		_errors.append("PauseMenu did not hide.")
	if paused:
		_errors.append("SceneTree remained paused after close.")
	pause_menu.queue_free()

	if _errors.is_empty():
		print("[pause_menu] OK open_close=true")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)
