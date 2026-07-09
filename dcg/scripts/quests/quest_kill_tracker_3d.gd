class_name QuestKillTracker3D
extends Node

const QuestStateScript := preload("res://scripts/quests/quest_state.gd")
const FirstScavengerHuntQuest := preload("res://data/quests/first_scavenger_hunt.tres")

@export var quest_def: Resource = FirstScavengerHuntQuest

var _has_recorded_kill := false


func _ready() -> void:
	var owner_node := get_parent()
	if owner_node != null and owner_node.has_signal("died"):
		owner_node.died.connect(_on_enemy_died)


func record_kill(enemy_id: String) -> bool:
	if _has_recorded_kill or enemy_id == "":
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
	if not quests.has(quest_id):
		return false
	var current_state: Dictionary = quests.get(quest_id, {}) as Dictionary
	var updated_state: Dictionary = QuestStateScript.update_from_enemy_killed(current_state, quest_def, enemy_id, 1)
	quests[quest_id] = updated_state
	save_data["quests"] = quests
	if not save_manager.save_slot_data(slot_index, save_data):
		return false

	_has_recorded_kill = true
	return true


func _on_enemy_died(_event: DamageEvent) -> void:
	record_kill(_enemy_id())


func _enemy_id() -> String:
	var owner_node := get_parent()
	if owner_node == null:
		return ""
	var enemy_def: Variant = owner_node.get_meta("enemy_def", null)
	if enemy_def != null and enemy_def is Resource:
		return str(enemy_def.get("id"))
	return str(owner_node.get_meta("enemy_id", ""))


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
