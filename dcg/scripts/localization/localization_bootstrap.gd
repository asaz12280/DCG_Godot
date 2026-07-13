extends Node

const DEFAULT_LOCALE := "zh_TW"
const TEXT_TABLE_PATHS := [
	"res://data/localization/game_text.csv",
	"res://data/localization/dialogue_text.csv",
]
const ENABLE_DEV_HOT_RELOAD := true
const HOT_RELOAD_INTERVAL := 0.5

var _loaded_translations: Array[Translation] = []
var _last_modified_times: Dictionary = {}
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
	for table_path: String in TEXT_TABLE_PATHS:
		var modified_time := FileAccess.get_modified_time(table_path)
		if modified_time != 0 and modified_time != int(_last_modified_times.get(table_path, 0)):
			_load_csv_translations()
			_notify_localization_changed()
			return


func _load_csv_translations() -> void:
	_remove_loaded_translations()
	var translations: Dictionary = {}
	var seen_keys: Dictionary = {}
	for table_path: String in TEXT_TABLE_PATHS:
		_merge_csv_table(table_path, translations, seen_keys)

	for translation in translations.values():
		TranslationServer.add_translation(translation)
		_loaded_translations.append(translation)

	_last_modified_times.clear()
	for table_path: String in TEXT_TABLE_PATHS:
		_last_modified_times[table_path] = FileAccess.get_modified_time(table_path)


func _merge_csv_table(table_path: String, translations: Dictionary, seen_keys: Dictionary) -> void:
	if not FileAccess.file_exists(table_path):
		push_warning("Localization table not found: %s" % table_path)
		return
	var file := FileAccess.open(table_path, FileAccess.READ)
	if file == null:
		push_warning("Localization table could not be opened: %s" % table_path)
		return

	var header := file.get_csv_line()
	if header.size() < 2:
		push_warning("Localization table needs at least key and one locale column: %s" % table_path)
		return

	var locale_by_column: Dictionary = {}
	for column in range(1, header.size()):
		var locale := str(header[column]).strip_edges()
		if locale == "":
			continue
		locale_by_column[column] = locale
		if not translations.has(locale):
			var translation := Translation.new()
			translation.locale = locale
			translations[locale] = translation

	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 0:
			continue
		var key := str(row[0]).strip_edges()
		if key == "":
			continue
		if seen_keys.has(key):
			push_warning("Duplicate localization key '%s' in %s; first declared in %s." % [key, table_path, seen_keys[key]])
			continue
		seen_keys[key] = table_path
		for column in locale_by_column.keys():
			if column >= row.size():
				continue
			var text := str(row[column])
			if text == "":
				continue
			var locale := str(locale_by_column[column])
			(translations[locale] as Translation).add_message(key, text)


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
