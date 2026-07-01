extends SceneTree

const GameSettingsScript := preload("res://scripts/settings/game_settings.gd")

var _errors: Array[String] = []


func _initialize() -> void:
	var settings := GameSettingsScript.new()
	root.add_child(settings)
	settings.set_master_volume(70)
	settings.set_bgm_volume(0)
	settings.set_sfx_volume(35)
	_validate_bus("Master", 70, false)
	_validate_bus("BGM", 0, true)
	_validate_bus("SFX", 35, false)
	settings.queue_free()

	if _errors.is_empty():
		print("[audio_settings] OK buses=Master/BGM/SFX")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_bus(bus_name: String, expected_volume: int, expected_muted: bool) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		_errors.append("Missing audio bus: %s" % bus_name)
		return
	if AudioServer.is_bus_mute(bus_index) != expected_muted:
		_errors.append("Unexpected mute state for %s" % bus_name)
	if expected_volume > 0:
		var expected_db := linear_to_db(float(expected_volume) / 100.0)
		if absf(AudioServer.get_bus_volume_db(bus_index) - expected_db) > 0.01:
			_errors.append("Unexpected volume db for %s" % bus_name)
