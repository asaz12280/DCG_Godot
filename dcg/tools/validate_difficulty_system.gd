extends SceneTree

const DifficultyManagerScript := preload("res://scripts/difficulty/difficulty_manager.gd")
const DifficultySelectPanelScript := preload("res://scripts/ui/difficulty_select_panel.gd")
const PlayerStatsProfileScript := preload("res://scripts/player/player_stats_profile.gd")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_profiles()
	_validate_manager()
	_validate_menu_panel()
	if _errors.is_empty():
		print("[difficulty_system] OK profiles=3 health=scaled menu=available")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_profiles() -> void:
	var easy := load("res://data/difficulty/easy.tres") as DifficultyProfile
	var normal := load("res://data/difficulty/normal.tres") as DifficultyProfile
	var hard := load("res://data/difficulty/hard.tres") as DifficultyProfile
	if easy == null or normal == null or hard == null:
		_errors.append("Difficulty profiles should load from data/difficulty.")
		return
	if easy.player_health_multiplier <= normal.player_health_multiplier:
		_errors.append("Easy difficulty should give more player health than normal.")
	if hard.player_health_multiplier >= normal.player_health_multiplier:
		_errors.append("Hard difficulty should give less player health than normal.")


func _validate_manager() -> void:
	var manager := Node.new()
	manager.set_script(DifficultyManagerScript)
	root.add_child(manager)
	manager._ready()
	if manager.get_profiles().size() != 3:
		_errors.append("DifficultyManager should expose three profiles.")
	manager.set_difficulty(&"hard")
	var profile := PlayerStatsProfileScript.new()
	manager.apply_to_player_stats(profile)
	if not is_equal_approx(profile.base_max_health, 75.0):
		_errors.append("Hard difficulty should scale default player health to 75.")
	manager.queue_free()


func _validate_menu_panel() -> void:
	var panel := DifficultySelectPanelScript.new()
	root.add_child(panel)
	panel._ready()
	if not panel.has_method("open"):
		_errors.append("DifficultySelectPanel should expose open().")
	if not panel.has_method("refresh_texts"):
		_errors.append("DifficultySelectPanel should refresh localized text.")
	panel.queue_free()

