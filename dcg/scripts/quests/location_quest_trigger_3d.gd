class_name LocationQuestTrigger3D
extends Area3D

signal location_recorded(location_id: String)

const QuestStateScript := preload("res://scripts/quests/quest_state.gd")
const RadioTowerScoutQuest := preload("res://data/quests/radio_tower_scout.tres")

@export var quest_def: Resource = RadioTowerScoutQuest
@export var location_id := "radio_tower"
@export var prompt_key: StringName = &"prompt.record_location"
@export var prompt_text := "按 E 調查訊號塔"
@export var completed_key: StringName = &"prompt.location_recorded"
@export var completed_text := "地點已記錄"

var _player_in_range: Node3D = null
var _has_recorded := false
var _prompt_label: Label3D = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_prompt_label = find_child("PromptLabel", true, false) as Label3D
	_update_prompt()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_update_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range == null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if try_record_location(_player_in_range):
			get_viewport().set_input_as_handled()


func try_record_location(player: Node) -> bool:
	if player == null or location_id == "":
		return false
	var save_manager := _get_save_manager()
	if save_manager == null:
		return false
	if not save_manager.has_method("get_current_slot_index") or not save_manager.has_method("get_slot_data") or not save_manager.has_method("save_slot_data"):
		return false

	var slot_index := int(save_manager.get_current_slot_index())
	var save_data: Dictionary = save_manager.get_slot_data(slot_index)
	if save_data.is_empty():
		return false

	var quests: Dictionary = _quests_dict(save_data.get("quests", {}))
	var quest_id := str(quest_def.get("id"))
	var current_state: Dictionary = quests.get(quest_id, QuestStateScript.create(quest_def)) as Dictionary
	var updated_state: Dictionary = QuestStateScript.update_from_location_reached(current_state, quest_def, location_id, 1)
	quests[quest_id] = updated_state
	save_data["quests"] = quests
	if not save_manager.save_slot_data(slot_index, save_data):
		return false

	_has_recorded = true
	_update_prompt()
	location_recorded.emit(location_id)
	return true


func get_state() -> Dictionary:
	return {
		"location_id": location_id,
		"player_in_range": _player_in_range != null,
		"has_recorded": _has_recorded,
		"quest_id": str(quest_def.get("id")) if quest_def != null else "",
		"prompt_text": _current_prompt_text(),
	}


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in_range = body
		_update_prompt()


func _on_body_exited(body: Node3D) -> void:
	if body == _player_in_range:
		_player_in_range = null
		_update_prompt()


func _update_prompt() -> void:
	if _prompt_label == null:
		return
	_prompt_label.visible = _player_in_range != null or _has_recorded
	_prompt_label.text = _current_prompt_text()


func _current_prompt_text() -> String:
	return _localized_text(completed_key, completed_text) if _has_recorded else _localized_text(prompt_key, prompt_text)


func _localized_text(key: StringName, fallback: String) -> String:
	var key_text := str(key)
	var translated := tr(key_text)
	return fallback if translated == key_text or translated == "" else translated


func _get_save_manager() -> Node:
	var main_loop := Engine.get_main_loop() as SceneTree
	var tree_root := main_loop.root if main_loop != null else null
	if tree_root != null:
		var manager := tree_root.get_node_or_null("SaveGameManager")
		if manager != null:
			return manager
		manager = tree_root.find_child("SaveGameManager", true, false)
		if manager != null:
			return manager
	if is_inside_tree():
		return get_node_or_null("/root/SaveGameManager")
	return null


func _quests_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
