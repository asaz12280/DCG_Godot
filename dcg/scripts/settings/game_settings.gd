extends Node

const CONFIG_PATH := "user://game_settings.cfg"
const DISPLAY_MODE_FULLSCREEN := "fullscreen"
const DISPLAY_MODE_WINDOWED := "windowed"
const SUPPORTED_DISPLAY_MODES := [DISPLAY_MODE_FULLSCREEN, DISPLAY_MODE_WINDOWED]
const DEFAULT_LOCALE := "zh_TW"
const SUPPORTED_LANGUAGE_LOCALES := [DEFAULT_LOCALE, "en"]
const STANDARD_WINDOW_SIZE := Vector2i(1920, 1080)
const DEFAULT_RESOLUTION := STANDARD_WINDOW_SIZE
const DEFAULT_DISPLAY_MODE := DISPLAY_MODE_FULLSCREEN
const MIN_RENDER_RESOLUTION := Vector2i(1280, 720)
const WINDOW_MARGIN := Vector2i(96, 96)
const BUS_MASTER := "Master"
const BUS_BGM := "BGM"
const BUS_SFX := "SFX"
const DEFAULT_MASTER_VOLUME := 100
const DEFAULT_BGM_VOLUME := 80
const DEFAULT_SFX_VOLUME := 80
const DEFAULT_DIFFICULTY_ID := "normal"

signal settings_changed

var language_locale := DEFAULT_LOCALE
var resolution := DEFAULT_RESOLUTION
var display_mode := DEFAULT_DISPLAY_MODE
var master_volume := DEFAULT_MASTER_VOLUME
var bgm_volume := DEFAULT_BGM_VOLUME
var sfx_volume := DEFAULT_SFX_VOLUME
var difficulty_id := DEFAULT_DIFFICULTY_ID


func _ready() -> void:
	load_settings()
	apply_all()


func set_language_locale(locale: String) -> void:
	var normalized := _normalize_language_locale(locale)
	if language_locale == normalized:
		return
	language_locale = normalized
	_apply_language()
	save_settings()
	settings_changed.emit()


func set_resolution(value: Vector2i) -> void:
	var clamped_value := _clamp_resolution(value)
	if resolution == clamped_value:
		_apply_display()
		return
	resolution = clamped_value
	_apply_display()
	save_settings()
	settings_changed.emit()


func set_display_mode(value: String) -> void:
	var normalized := _normalize_display_mode(value)
	if display_mode == normalized:
		_apply_display()
		return
	display_mode = normalized
	_apply_display()
	save_settings()
	settings_changed.emit()


func set_master_volume(value: int) -> void:
	var clamped_value := clampi(value, 0, 100)
	if master_volume == clamped_value:
		_apply_audio()
		return
	master_volume = clamped_value
	_apply_audio()
	save_settings()
	settings_changed.emit()


func set_bgm_volume(value: int) -> void:
	var clamped_value := clampi(value, 0, 100)
	if bgm_volume == clamped_value:
		_apply_audio()
		return
	bgm_volume = clamped_value
	_apply_audio()
	save_settings()
	settings_changed.emit()


func set_sfx_volume(value: int) -> void:
	var clamped_value := clampi(value, 0, 100)
	if sfx_volume == clamped_value:
		_apply_audio()
		return
	sfx_volume = clamped_value
	_apply_audio()
	save_settings()
	settings_changed.emit()


func set_difficulty_id(value: String) -> void:
	var normalized := value if value in ["easy", "normal", "hard"] else DEFAULT_DIFFICULTY_ID
	if difficulty_id == normalized:
		return
	difficulty_id = normalized
	save_settings()
	settings_changed.emit()


func get_difficulty_id() -> String:
	return difficulty_id


func apply_all() -> void:
	_apply_language()
	_apply_display()
	_apply_audio()


func get_display_debug_state() -> Dictionary:
	var render_size := get_tree().root.content_scale_size
	var window_size := DisplayServer.window_get_size()
	return {
		"language_locale": language_locale,
		"resolution": resolution,
		"display_mode": display_mode,
		"window_mode": DisplayServer.window_get_mode(),
		"window_size": window_size,
		"standard_window_size": STANDARD_WINDOW_SIZE,
		"render_size": render_size,
		"render_matches_resolution": render_size == resolution,
		"window_matches_standard": window_size == STANDARD_WINDOW_SIZE,
		"master_volume": master_volume,
		"bgm_volume": bgm_volume,
		"sfx_volume": sfx_volume,
		"difficulty_id": difficulty_id,
	}


func load_settings() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	language_locale = _normalize_language_locale(str(config.get_value("general", "language_locale", DEFAULT_LOCALE)))
	var width := int(config.get_value("video", "resolution_width", DEFAULT_RESOLUTION.x))
	var height := int(config.get_value("video", "resolution_height", DEFAULT_RESOLUTION.y))
	resolution = _clamp_resolution(Vector2i(width, height))
	display_mode = _normalize_display_mode(str(config.get_value("video", "display_mode", DEFAULT_DISPLAY_MODE)))
	master_volume = clampi(int(config.get_value("audio", "master_volume", DEFAULT_MASTER_VOLUME)), 0, 100)
	bgm_volume = clampi(int(config.get_value("audio", "bgm_volume", DEFAULT_BGM_VOLUME)), 0, 100)
	sfx_volume = clampi(int(config.get_value("audio", "sfx_volume", DEFAULT_SFX_VOLUME)), 0, 100)
	difficulty_id = str(config.get_value("gameplay", "difficulty_id", DEFAULT_DIFFICULTY_ID))
	if not (difficulty_id in ["easy", "normal", "hard"]):
		difficulty_id = DEFAULT_DIFFICULTY_ID


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "language_locale", language_locale)
	config.set_value("video", "resolution_width", resolution.x)
	config.set_value("video", "resolution_height", resolution.y)
	config.set_value("video", "display_mode", display_mode)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "bgm_volume", bgm_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("gameplay", "difficulty_id", difficulty_id)
	config.save(CONFIG_PATH)


func _apply_language() -> void:
	var localization := get_node_or_null("/root/LocalizationBootstrap")
	if localization != null and localization.has_method("set_game_locale"):
		localization.call("set_game_locale", language_locale)
	else:
		TranslationServer.set_locale(language_locale)


func _apply_display() -> void:
	_apply_render_resolution()
	if display_mode == DISPLAY_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		return

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_apply_suggested_window_size()


func _apply_render_resolution() -> void:
	var root := get_tree().root
	root.content_scale_size = resolution


func _clamp_resolution(value: Vector2i) -> Vector2i:
	return Vector2i(
		maxi(value.x, MIN_RENDER_RESOLUTION.x),
		maxi(value.y, MIN_RENDER_RESOLUTION.y)
	)


func _normalize_language_locale(value: String) -> String:
	return value if value in SUPPORTED_LANGUAGE_LOCALES else DEFAULT_LOCALE


func _normalize_display_mode(value: String) -> String:
	return value if value in SUPPORTED_DISPLAY_MODES else DEFAULT_DISPLAY_MODE


func _apply_suggested_window_size() -> void:
	var screen_size := DisplayServer.screen_get_size()
	var available_size := Vector2i(
		maxi(640, screen_size.x - WINDOW_MARGIN.x),
		maxi(360, screen_size.y - WINDOW_MARGIN.y)
	)
	var window_size := Vector2i(
		mini(STANDARD_WINDOW_SIZE.x, available_size.x),
		mini(STANDARD_WINDOW_SIZE.y, available_size.y)
	)
	DisplayServer.window_set_size(window_size)
	var window_position := Vector2i(
		maxi(0, int(floor(float(screen_size.x - window_size.x) / 2.0))),
		maxi(0, int(floor(float(screen_size.y - window_size.y) / 2.0)))
	)
	DisplayServer.window_set_position(window_position)


func _apply_audio() -> void:
	_ensure_audio_bus(BUS_BGM)
	_ensure_audio_bus(BUS_SFX)
	_apply_bus_volume(BUS_MASTER, master_volume)
	_apply_bus_volume(BUS_BGM, bgm_volume)
	_apply_bus_volume(BUS_SFX, sfx_volume)


func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var bus_index := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, BUS_MASTER)


func _apply_bus_volume(bus_name: String, percent: int) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var clamped_percent := clampi(percent, 0, 100)
	AudioServer.set_bus_mute(bus_index, clamped_percent <= 0)
	if clamped_percent <= 0:
		AudioServer.set_bus_volume_db(bus_index, -80.0)
	else:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(float(clamped_percent) / 100.0))
