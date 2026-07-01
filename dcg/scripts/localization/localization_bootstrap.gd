extends Node

const DEFAULT_LOCALE := "zh_TW"
const TEXT_TABLE_PATH := "res://data/localization/game_text.csv"
const ENABLE_DEV_HOT_RELOAD := true
const HOT_RELOAD_INTERVAL := 0.5

var _loaded_translations: Array[Translation] = []
var _last_modified_time: int = 0
var _reload_elapsed: float = 0.0


func _ready() -> void:
	_load_csv_translations()
	TranslationServer.set_locale(DEFAULT_LOCALE)
	set_process(ENABLE_DEV_HOT_RELOAD)


func set_game_locale(locale: String) -> void:
	TranslationServer.set_locale(locale)
	_notify_localization_changed()


func _process(delta: float) -> void:
	if not ENABLE_DEV_HOT_RELOAD:
		return
	_reload_elapsed += delta
	if _reload_elapsed < HOT_RELOAD_INTERVAL:
		return
	_reload_elapsed = 0.0
	var modified_time := FileAccess.get_modified_time(TEXT_TABLE_PATH)
	if modified_time != 0 and modified_time != _last_modified_time:
		_load_csv_translations()
		_notify_localization_changed()


func _load_csv_translations() -> void:
	if not FileAccess.file_exists(TEXT_TABLE_PATH):
		push_warning("Localization table not found: %s" % TEXT_TABLE_PATH)
		return

	var file := FileAccess.open(TEXT_TABLE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Localization table could not be opened: %s" % TEXT_TABLE_PATH)
		return

	_remove_loaded_translations()

	var header := file.get_csv_line()
	if header.size() < 2:
		push_warning("Localization table needs at least key and one locale column.")
		return

	var translations: Dictionary = {}
	for column in range(1, header.size()):
		var locale := str(header[column]).strip_edges()
		if locale == "":
			continue
		var translation := Translation.new()
		translation.locale = locale
		translations[column] = translation

	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 0:
			continue
		var key := str(row[0]).strip_edges()
		if key == "":
			continue
		for column in translations.keys():
			if column >= row.size():
				continue
			var text := str(row[column])
			if text == "":
				continue
			(translations[column] as Translation).add_message(key, text)

	for translation in translations.values():
		TranslationServer.add_translation(translation)
		_loaded_translations.append(translation)

	_last_modified_time = FileAccess.get_modified_time(TEXT_TABLE_PATH)


func _remove_loaded_translations() -> void:
	for translation in _loaded_translations:
		TranslationServer.remove_translation(translation)
	_loaded_translations.clear()


func _notify_localization_changed() -> void:
	if get_tree().current_scene == null:
		return
	_notify_node_localization_changed(get_tree().current_scene)


func _notify_node_localization_changed(node: Node) -> void:
	if node.has_method("_on_localization_changed"):
		node.call("_on_localization_changed")
	if node is CanvasItem:
		(node as CanvasItem).queue_redraw()
	for child in node.get_children():
		_notify_node_localization_changed(child)
