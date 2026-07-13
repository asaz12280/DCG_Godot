extends SceneTree

const DMConstants := preload("res://addons/dialogue_manager/constants.gd")
const DIALOGUE_TABLE_PATH := "res://data/localization/dialogue_text.csv"
const GAME_TABLE_PATH := "res://data/localization/game_text.csv"
const STORY_TEMPLATE_PATH := "res://data/dialogue/story_template.dialogue"
const REQUIRED_LOCALES := ["zh_TW", "en"]

var _errors: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_validate_project_wiring()
	var dialogue_rows := _read_localization_table(DIALOGUE_TABLE_PATH)
	_validate_dialogue_rows(dialogue_rows)
	_validate_story_ids(dialogue_rows)
	await _validate_runtime(dialogue_rows)
	if _errors.is_empty():
		print("[dialogue_localization] OK plugin=enabled source=csv tables=split locales=2 story_ids=complete runtime=translated")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _validate_project_wiring() -> void:
	var project_source := FileAccess.get_file_as_string("res://project.godot")
	_expect(project_source.contains("res://addons/dialogue_manager/plugin.cfg"), "Dialogue Manager editor plugin should be enabled.")
	_expect(project_source.contains("DialogueManager=\"*res://addons/dialogue_manager/dialogue_manager.gd\""), "DialogueManager autoload should be configured.")
	_expect(project_source.contains("DialogueLocalizationBridge=\"*res://scripts/localization/dialogue_localization_bridge.gd\""), "Dialogue localization bridge autoload should be configured.")
	var bootstrap_source := FileAccess.get_file_as_string("res://scripts/localization/localization_bootstrap.gd")
	_expect(bootstrap_source.contains(DIALOGUE_TABLE_PATH), "LocalizationBootstrap should load the dialogue translation table.")


func _validate_dialogue_rows(rows: Dictionary) -> void:
	_expect(not rows.is_empty(), "Dialogue translation table should contain localized rows.")
	var game_rows := _read_localization_table(GAME_TABLE_PATH)
	for key in rows.keys():
		_expect(str(key).begins_with("dialogue."), "Dialogue translation key should use the dialogue.* namespace: %s" % key)
		_expect(not game_rows.has(key), "Dialogue translation key should not duplicate game_text.csv: %s" % key)
		var localized := rows[key] as Dictionary
		for locale in REQUIRED_LOCALES:
			_expect(str(localized.get(locale, "")).strip_edges() != "", "Dialogue key %s requires a non-empty %s translation." % [key, locale])


func _validate_story_ids(rows: Dictionary) -> void:
	var source := FileAccess.get_file_as_string(STORY_TEMPLATE_PATH)
	_expect(source.contains("~ start"), "Story template should expose a start title.")
	var regex := RegEx.new()
	regex.compile("\\[ID:([^\\]]+)\\]")
	var ids: Dictionary = {}
	for match_result in regex.search_all(source):
		var key := match_result.get_string(1)
		_expect(not ids.has(key), "Story template should not repeat static dialogue ID: %s" % key)
		ids[key] = true
		_expect(rows.has(key), "Story template ID is missing from dialogue_text.csv: %s" % key)
	_expect(ids.size() >= 3, "Story template should demonstrate dialogue, response, and follow-up localization IDs.")


func _validate_runtime(rows: Dictionary) -> void:
	var bootstrap := root.get_node_or_null("LocalizationBootstrap")
	var dialogue_manager := root.get_node_or_null("DialogueManager")
	var bridge := root.get_node_or_null("DialogueLocalizationBridge")
	_expect(bootstrap != null, "LocalizationBootstrap autoload should be available at runtime.")
	_expect(dialogue_manager != null, "DialogueManager autoload should be available at runtime.")
	_expect(bridge != null, "DialogueLocalizationBridge autoload should be available at runtime.")
	if bootstrap == null or dialogue_manager == null:
		return
	_expect(int(dialogue_manager.get("translation_source")) == DMConstants.TranslationSource.CSV, "Dialogue Manager should be forced to CSV translation mode.")
	var story_source := FileAccess.get_file_as_string(STORY_TEMPLATE_PATH)
	var story_resource = dialogue_manager.call("create_resource_from_text", story_source)
	_expect(story_resource != null, "Dialogue Manager should compile the story template as a DialogueResource.")
	if story_resource == null:
		return
	for locale in REQUIRED_LOCALES:
		bootstrap.call("set_game_locale", locale)
		await process_frame
		var expected_intro := str((rows["dialogue.template.intro"] as Dictionary).get(locale, ""))
		var expected_response := str((rows["dialogue.template.continue"] as Dictionary).get(locale, ""))
		_expect(TranslationServer.translate("dialogue.template.intro") == expected_intro, "TranslationServer should resolve dialogue.template.intro for %s." % locale)
		var line = await dialogue_manager.call("get_next_dialogue_line", story_resource, "start")
		_expect(line != null, "Dialogue Manager should resolve the story template start line for %s." % locale)
		if line == null:
			continue
		_expect(str(line.text) == expected_intro, "Dialogue Manager should return translated intro text for %s." % locale)
		_expect(line.responses.size() == 1, "Story template should expose one localized response for %s." % locale)
		if line.responses.size() == 1:
			_expect(str(line.responses[0].text) == expected_response, "Dialogue Manager should return translated response text for %s." % locale)
	bootstrap.call("set_game_locale", "zh_TW")


func _read_localization_table(path: String) -> Dictionary:
	var rows: Dictionary = {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_errors.append("Localization table could not be opened: %s" % path)
		return rows
	var header := file.get_csv_line()
	var locale_columns: Dictionary = {}
	for locale in REQUIRED_LOCALES:
		var column := header.find(locale)
		_expect(column >= 0, "Localization table %s requires locale column %s." % [path, locale])
		if column >= 0:
			locale_columns[locale] = column
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.is_empty():
			continue
		var key := str(row[0]).strip_edges()
		if key == "":
			continue
		_expect(not rows.has(key), "Localization table %s contains duplicate key %s." % [path, key])
		if rows.has(key):
			continue
		var localized: Dictionary = {}
		for locale in locale_columns.keys():
			var column := int(locale_columns[locale])
			localized[locale] = str(row[column]) if column < row.size() else ""
		rows[key] = localized
	return rows


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
