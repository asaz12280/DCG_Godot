extends SceneTree

const SaveSlotPanelScript := preload("res://scripts/ui/save_slot_panel.gd")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")

var _errors: Array[String] = []


func _initialize() -> void:
	await _validate_panel_rows()
	await _validate_panel_text_refresh()
	if _errors.is_empty():
		print("[save_slot_panel] OK rows=3 refresh=ready")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_panel_rows() -> void:
	var save_manager := SaveGameManagerScript.new()
	save_manager.name = "SaveGameManager"
	root.add_child(save_manager)

	var panel := SaveSlotPanelScript.new()
	root.add_child(panel)
	await process_frame
	if panel.get_slot_count() != 3:
		_errors.append("SaveSlotPanel should build three slot rows.")
	panel.queue_free()
	save_manager.queue_free()


func _validate_panel_text_refresh() -> void:
	var save_manager := SaveGameManagerScript.new()
	save_manager.name = "SaveGameManager"
	root.add_child(save_manager)

	var panel := SaveSlotPanelScript.new()
	root.add_child(panel)
	await process_frame
	panel.refresh_texts()
	if panel.title_label == null or panel.title_label.text == "":
		_errors.append("SaveSlotPanel should refresh the load title.")
	if panel.status_label == null or panel.status_label.text == "":
		_errors.append("SaveSlotPanel should expose a visible status message.")
	panel.queue_free()
	save_manager.queue_free()
