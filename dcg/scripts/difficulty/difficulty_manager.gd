extends Node

const EASY_PROFILE := preload("res://data/difficulty/easy.tres")
const NORMAL_PROFILE := preload("res://data/difficulty/normal.tres")
const HARD_PROFILE := preload("res://data/difficulty/hard.tres")

signal difficulty_changed(id: StringName)

const DEFAULT_DIFFICULTY_ID := &"normal"

var selected_difficulty_id: StringName = DEFAULT_DIFFICULTY_ID
var _profiles: Dictionary = {}


func _ready() -> void:
	_register_profile(EASY_PROFILE)
	_register_profile(NORMAL_PROFILE)
	_register_profile(HARD_PROFILE)
	if is_inside_tree():
		var settings := get_node_or_null("/root/GameSettings")
		if settings != null and settings.has_method("get_difficulty_id"):
			selected_difficulty_id = StringName(settings.get_difficulty_id())
	if not _profiles.has(selected_difficulty_id):
		selected_difficulty_id = DEFAULT_DIFFICULTY_ID


func set_difficulty(id: StringName) -> void:
	if not _profiles.has(id):
		id = DEFAULT_DIFFICULTY_ID
	if selected_difficulty_id == id:
		return
	selected_difficulty_id = id
	if is_inside_tree():
		var settings := get_node_or_null("/root/GameSettings")
		if settings != null and settings.has_method("set_difficulty_id"):
			settings.set_difficulty_id(str(selected_difficulty_id))
	difficulty_changed.emit(selected_difficulty_id)


func get_selected_profile() -> DifficultyProfile:
	return _profiles.get(selected_difficulty_id, _profiles.get(DEFAULT_DIFFICULTY_ID, null)) as DifficultyProfile


func get_profiles() -> Array[DifficultyProfile]:
	var result: Array[DifficultyProfile] = []
	for id in [&"easy", &"normal", &"hard"]:
		if _profiles.has(id):
			result.append(_profiles[id] as DifficultyProfile)
	return result


func apply_to_player_stats(profile: PlayerStatsProfile) -> void:
	var difficulty := get_selected_profile()
	if difficulty != null:
		difficulty.apply_to_player_stats(profile)


func _register_profile(profile: DifficultyProfile) -> void:
	if profile == null or profile.id == &"":
		return
	_profiles[profile.id] = profile
