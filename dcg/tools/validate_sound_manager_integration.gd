extends SceneTree

const GameSettingsScript := preload("res://scripts/settings/game_settings.gd")
const SOUND_MANAGER_SCENE_PATH := "res://addons/sound_manager/module/SoundManager.tscn"

var _errors: Array[String] = []


func _initialize() -> void:
	_run_validation.call_deferred()


func _run_validation() -> void:
	var manager := root.get_node_or_null("SoundManager")
	if manager == null:
		var sound_manager_scene := load(SOUND_MANAGER_SCENE_PATH) as PackedScene
		if sound_manager_scene == null:
			_errors.append("Sound Manager scene cannot be loaded.")
			_finish()
			return
		manager = sound_manager_scene.instantiate()
		manager.name = "SoundManager"
		root.add_child(manager)
	var settings := GameSettingsScript.new()
	settings.name = "ValidationGameSettings"
	root.add_child(settings)
	settings.master_volume = 70
	settings.bgm_volume = 40
	settings.sfx_volume = 25
	settings.call("_apply_audio")
	_validate_project_wiring()
	_validate_config()
	_validate_runtime(settings, manager)
	settings.queue_free()

	_finish()


func _finish() -> void:
	if _errors.is_empty():
		print("[sound_manager_integration] OK owner=GameSettings routes=BGM/BGS->BGM,SFX/MFX->SFX spatial=local")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_project_wiring() -> void:
	var enabled_plugins: Array = Array(ProjectSettings.get_setting("editor_plugins/enabled", []))
	if not enabled_plugins.has("res://addons/sound_manager/plugin.cfg"):
		_errors.append("Sound Manager editor plugin is not enabled.")
	var autoload_path := str(ProjectSettings.get_setting("autoload/SoundManager", ""))
	if not autoload_path.ends_with("res://addons/sound_manager/module/SoundManager.tscn"):
		_errors.append("SoundManager autoload is missing or points to the wrong scene.")


func _validate_config() -> void:
	var file := FileAccess.open("res://addons/sound_manager/sound_manager.json", FileAccess.READ)
	if file == null:
		_errors.append("Sound Manager configuration cannot be opened.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_errors.append("Sound Manager configuration is not valid JSON.")
		return
	var config := parsed as Dictionary
	var routes := config.get("Audio_Busses", {}) as Dictionary
	var expected := {"BGM": "BGM", "BGS": "BGM", "SFX": "SFX", "MFX": "SFX"}
	for sound_type in expected:
		if str(routes.get(sound_type, "")) != str(expected[sound_type]):
			_errors.append("Unexpected Sound Manager bus route for %s." % sound_type)
	if not (config.get("Audio_Files_Dictionary", {}) as Dictionary).is_empty():
		_errors.append("Sound Manager must not keep addon example audio paths.")


func _validate_runtime(settings: Node, manager: Node) -> void:
	var state: Dictionary = settings.call("get_audio_integration_state")
	if not bool(state.get("available", false)):
		_errors.append("GameSettings did not synchronize with SoundManager: state=%s manager_in_tree=%s" % [state, manager.is_inside_tree()])
	for method_name in [&"get_bgm_volume_db", &"get_bgs_volume_db", &"get_sfx_volume_db", &"get_mfx_volume_db"]:
		if not manager.has_method(method_name) or absf(float(manager.call(method_name))) > 0.001:
			_errors.append("SoundManager category gain must remain at 0 dB: %s." % method_name)
	_validate_bus("Master", 70)
	_validate_bus("BGM", 40)
	_validate_bus("SFX", 25)


func _validate_bus(bus_name: String, expected_percent: int) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		_errors.append("Missing audio bus: %s" % bus_name)
		return
	var expected_db := linear_to_db(float(expected_percent) / 100.0)
	if absf(AudioServer.get_bus_volume_db(bus_index) - expected_db) > 0.01:
		_errors.append("Unexpected volume on %s bus." % bus_name)
