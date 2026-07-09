extends SceneTree

const MainMenuScene := preload("res://scenes/ui/main_menu.tscn")
const SaveSlotPanelScript := preload("res://scripts/ui/save_slot_panel.gd")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")

const VIEWPORTS: Array[Vector2] = [
	Vector2(1280.0, 720.0),
	Vector2(1920.0, 1080.0),
	Vector2(2293.0, 1204.0),
]
const MIN_BUTTON_HEIGHT := 44.0

var _errors: Array[String] = []


func _initialize() -> void:
	await _validate_panel_rows()
	await _validate_panel_text_refresh()
	await _validate_main_menu_load_panel_layout()
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


func _validate_main_menu_load_panel_layout() -> void:
	TranslationServer.set_locale("zh_TW")
	var save_manager := root.get_node_or_null("SaveGameManager")
	var created_save_manager := false
	if save_manager == null:
		save_manager = SaveGameManagerScript.new()
		save_manager.name = "SaveGameManager"
		root.add_child(save_manager)
		created_save_manager = true
	save_manager.save_root_path = "user://validation_save_slot_panel_layout"
	_cleanup_validation_root(save_manager.save_root_path)
	save_manager.save_slot_data(1, {
		"difficulty_id": "easy",
		"saved_at_text": "2026-07-04 04:12",
	})
	save_manager.save_slot_data(2, {
		"difficulty_id": "normal",
		"saved_at_text": "2026-07-01 15:12",
	})
	save_manager.save_slot_data(3, {
		"difficulty_id": "hard",
		"saved_at_text": "2026-07-01 15:12",
	})

	for viewport_size in VIEWPORTS:
		_set_root_viewport(viewport_size)
		var menu := MainMenuScene.instantiate() as Control
		root.add_child(menu)
		menu.set_anchors_preset(Control.PRESET_TOP_LEFT)
		menu.size = viewport_size
		await process_frame
		menu.call("_on_load_pressed")
		menu.call("layout_menu")
		await process_frame

		var load_panel := menu.get("load_panel") as Control
		if load_panel == null:
			_errors.append("Main menu should create a load save panel.")
			_free_node(menu)
			continue
		if not load_panel.visible:
			_errors.append("Main menu Load should open the save slot panel at %s." % viewport_size)
		var settings_panel := menu.get("settings_panel") as Control
		if settings_panel != null and load_panel.has_method("get_preferred_panel_size") and settings_panel.has_method("get_preferred_panel_size"):
			var load_preferred: Vector2 = load_panel.call("get_preferred_panel_size")
			var settings_preferred: Vector2 = settings_panel.call("get_preferred_panel_size")
			if load_preferred != settings_preferred:
				_errors.append("Load save panel should reuse the settings overlay frame size.")
		var state: Dictionary = load_panel.call("get_display_state") if load_panel.has_method("get_display_state") else {}
		_assert_rect_inside(state.get("panel_rect", Rect2()), viewport_size, "Load save panel")
		_assert_rect_inside(state.get("scroll_rect", Rect2()), viewport_size, "Load save scroll frame")
		_assert_rect_inside(state.get("status_rect", Rect2()), viewport_size, "Load save status")
		_assert_button_rect(state.get("back_button_rect", Rect2()), "Load save back button")
		var button_rects: Array = state.get("slot_button_rects", [])
		if button_rects.size() != 3:
			_errors.append("Load save panel should expose three slot button rects at %s." % viewport_size)
		for index in range(button_rects.size()):
			var rect := button_rects[index] as Rect2
			_assert_button_rect(rect, "Load save slot button %d" % [index + 1])
			_assert_rect_inside(rect, viewport_size, "Load save slot button %d" % [index + 1])
		var label_rects: Array = state.get("slot_label_rects", [])
		for index in range(label_rects.size()):
			_assert_rect_inside(label_rects[index] as Rect2, viewport_size, "Load save slot label %d" % [index + 1])
		_free_node(menu)

	_cleanup_validation_root(save_manager.save_root_path)
	if created_save_manager:
		save_manager.queue_free()


func _assert_rect_inside(rect: Rect2, viewport_size: Vector2, label: String) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		_errors.append("%s should have a positive layout size." % label)
		return
	if rect.position.x < -1.0 or rect.position.y < -1.0 or rect.end.x > viewport_size.x + 1.0 or rect.end.y > viewport_size.y + 1.0:
		_errors.append("%s should fit inside %s, got %s." % [label, viewport_size, rect])


func _assert_button_rect(rect: Rect2, label: String) -> void:
	if rect.size.y < MIN_BUTTON_HEIGHT:
		_errors.append("%s should be at least %.0fpx tall, got %.1f." % [label, MIN_BUTTON_HEIGHT, rect.size.y])
	if rect.size.x < 80.0:
		_errors.append("%s should have enough width for Traditional Chinese text, got %.1f." % [label, rect.size.x])


func _set_root_viewport(viewport_size: Vector2) -> void:
	root.size = Vector2i(int(viewport_size.x), int(viewport_size.y))


func _cleanup_validation_root(root_path: String) -> void:
	var absolute := ProjectSettings.globalize_path(root_path)
	if DirAccess.dir_exists_absolute(absolute):
		DirAccess.remove_absolute("%s/slot_1.json" % absolute)
		DirAccess.remove_absolute("%s/slot_2.json" % absolute)
		DirAccess.remove_absolute("%s/slot_3.json" % absolute)
		DirAccess.remove_absolute(absolute)


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


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
