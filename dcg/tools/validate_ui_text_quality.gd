extends SceneTree

const BaseScreenScene := preload("res://scenes/base/base_screen.tscn")
const RaidHudScene := preload("res://scenes/ui/raid_hud_panel.tscn")
const RaidResultPanelScene := preload("res://scenes/ui/raid_result_panel.tscn")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")
const UITextScript := preload("res://scripts/ui/ui_text.gd")

const REQUIRED_KEYS: Array[String] = [
	"ui.base.title",
	"ui.base.start_raid",
	"ui.base.quest_progress",
	"ui.raid_hud.objective",
	"ui.raid_hud.ammo",
	"ui.raid_result.title",
	"ui.raid_result.continue_to_base",
	"ui.raid_result.extracted_items",
	"enemy.scavenger.name",
]

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	_validate_required_keys()
	await _validate_base_text_and_layout()
	await _validate_raid_hud_text_and_layout()
	await _validate_result_text_and_layout()
	if _errors.is_empty():
		print("[ui_text_quality] OK keys=present text=clean layout=fits")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_required_keys() -> void:
	var rows := _csv_rows()
	for key in REQUIRED_KEYS:
		if not rows.has(key):
			_errors.append("Localization CSV should include key: %s" % key)
			continue
		var row: Array = rows[key]
		for column in range(1, row.size()):
			var text := str(row[column])
			if text == "":
				_errors.append("Localization key %s should not have empty locale text." % key)
			elif UITextScript.looks_corrupt(text):
				_errors.append("Localization key %s contains mojibake text: %s" % [key, text])


func _validate_base_text_and_layout() -> void:
	var save_manager := _make_save_manager()
	save_manager.set_current_slot_index(1)
	save_manager.save_slot_data(1, {
		"difficulty_id": "normal",
		"money": 42,
		"stash": [{"item_path": "res://data/items/crafting/wood.tres", "quantity": 2}],
		"base_upgrades": {},
		"quests": {},
	})
	for viewport_size in [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0)]:
		root.size = Vector2i(int(viewport_size.x), int(viewport_size.y))
		var screen: BaseScreen = BaseScreenScene.instantiate()
		root.add_child(screen)
		screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
		screen.size = viewport_size
		await process_frame
		screen.refresh()
		await process_frame
		_assert_clean_tree_text(screen, "BaseScreen")
		var state: Dictionary = screen.get_display_state()
		var panel_rect := state.get("panel_rect") as Rect2
		var start_rect := state.get("start_button_rect") as Rect2
		var submit_rect := state.get("submit_quest_button_rect") as Rect2
		if panel_rect.end.x > viewport_size.x or panel_rect.end.y > viewport_size.y:
			_errors.append("Base UI text quality check should fit panel inside %s." % viewport_size)
		if not panel_rect.encloses(start_rect) or not panel_rect.encloses(submit_rect):
			_errors.append("Base UI actions should stay inside panel at %s." % viewport_size)
		_free_node(screen)
	_free_node(save_manager)


func _validate_raid_hud_text_and_layout() -> void:
	for viewport_size in [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0)]:
		var hud := RaidHudScene.instantiate()
		root.add_child(hud)
		await process_frame
		var rect: Rect2 = hud.call("preview_layout", viewport_size)
		hud.call("_update_objective")
		hud.call("_update_raid_status")
		hud.call("_update_extraction_idle")
		hud.call("_update_ammo")
		_assert_clean_tree_text(hud, "RaidHudPanel")
		if rect.position.x < 24.0 or rect.position.y < 24.0:
			_errors.append("Raid HUD should keep safe margins at %s." % viewport_size)
		if rect.end.x > viewport_size.x or rect.end.y > viewport_size.y:
			_errors.append("Raid HUD should fit inside %s." % viewport_size)
		_free_node(hud)


func _validate_result_text_and_layout() -> void:
	for viewport_size in [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0)]:
		root.size = Vector2i(int(viewport_size.x), int(viewport_size.y))
		var panel := RaidResultPanelScene.instantiate() as Control
		root.add_child(panel)
		panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		panel.size = viewport_size
		await process_frame
		panel.show_result({
			"outcome": "extracted",
			"duration": 75.0,
			"money_delta": 12,
			"extracted_items": [{"item_path": "res://data/items/valuables/old_watch.tres", "quantity": 1}],
			"lost_items": [],
			"kept_safe_pocket_items": [],
		})
		await process_frame
		_assert_clean_tree_text(panel, "RaidResultPanel")
		var state: Dictionary = panel.get_display_state()
		var panel_rect := state.get("panel_rect") as Rect2
		var button_rect := state.get("button_rect") as Rect2
		if panel_rect.end.x > viewport_size.x or panel_rect.end.y > viewport_size.y:
			_errors.append("Raid result UI should fit inside %s." % viewport_size)
		if not panel_rect.encloses(button_rect):
			_errors.append("Raid result continue button should stay inside panel at %s." % viewport_size)
		_free_node(panel)


func _assert_clean_tree_text(node: Node, label: String) -> void:
	if node is Label:
		_assert_clean_text((node as Label).text, "%s/%s" % [label, node.name])
	elif node is Button:
		_assert_clean_text((node as Button).text, "%s/%s" % [label, node.name])
	for child in node.get_children():
		_assert_clean_tree_text(child, label)


func _assert_clean_text(text: String, label: String) -> void:
	if text == "":
		return
	if UITextScript.looks_corrupt(text):
		_errors.append("%s should not display mojibake: %s" % [label, text])


func _csv_rows() -> Dictionary:
	var rows := {}
	var file := FileAccess.open("res://data/localization/game_text.csv", FileAccess.READ)
	if file == null:
		_errors.append("Cannot open localization CSV.")
		return rows
	file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() <= 1:
			continue
		var key := str(row[0]).strip_edges()
		if key != "":
			rows[key] = row
	return rows


func _make_save_manager() -> Node:
	var existing := root.get_node_or_null("SaveGameManager")
	if existing != null:
		_free_node(existing)
	var save_manager := SaveGameManagerScript.new()
	save_manager.name = "SaveGameManager"
	save_manager.save_root_path = "user://validation_ui_text_quality"
	root.add_child(save_manager)
	_cleanup_validation_root(save_manager.save_root_path)
	return save_manager


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
