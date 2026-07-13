class_name QuestGiverProfile
extends Resource

@export var id: StringName = &""
@export var display_name_key: StringName = &""
@export var fallback_display_name := ""
@export var quest_defs: Array[Resource] = []
@export var quest_ids: PackedStringArray = []
@export var allow_catalog_fallback := false


func quest_defs_for_catalog(catalog_defs: Array) -> Array[Resource]:
	var result: Array[Resource] = []
	var seen := {}
	for quest_def in quest_defs:
		_add_quest_def(result, seen, quest_def)
	for quest_id in quest_ids:
		_add_quest_def(result, seen, _find_catalog_quest(catalog_defs, str(quest_id)))
	if result.is_empty() and allow_catalog_fallback:
		for quest_def in catalog_defs:
			_add_quest_def(result, seen, quest_def)
	return result


func allows_quest_id(quest_id: String, catalog_defs: Array) -> bool:
	for quest_def in quest_defs_for_catalog(catalog_defs):
		if str(quest_def.get("id")) == quest_id:
			return true
	return false


func get_validation_errors(catalog_defs: Array = []) -> Array[String]:
	var errors: Array[String] = []
	if id == &"":
		errors.append("QuestGiverProfile requires id.")
	if display_name_key == &"" and fallback_display_name.strip_edges() == "":
		errors.append("QuestGiverProfile requires display_name_key or fallback_display_name.")
	if quest_defs.is_empty() and quest_ids.is_empty() and not allow_catalog_fallback:
		errors.append("QuestGiverProfile requires quest_defs, quest_ids, or allow_catalog_fallback.")
	for quest_def in quest_defs:
		if quest_def == null or not quest_def.has_method("is_valid") or not bool(quest_def.call("is_valid")):
			errors.append("QuestGiverProfile has an invalid quest_def.")
	for quest_id in quest_ids:
		if str(quest_id).strip_edges() == "":
			errors.append("QuestGiverProfile has an empty quest id.")
		elif not catalog_defs.is_empty() and _find_catalog_quest(catalog_defs, str(quest_id)) == null:
			errors.append("QuestGiverProfile references missing quest id: %s." % str(quest_id))
	return errors


func is_valid(catalog_defs: Array = []) -> bool:
	return get_validation_errors(catalog_defs).is_empty()


func _find_catalog_quest(catalog_defs: Array, quest_id: String) -> Resource:
	for quest_def in catalog_defs:
		if quest_def != null and str(quest_def.get("id")) == quest_id:
			return quest_def
	return null


func _add_quest_def(result: Array[Resource], seen: Dictionary, quest_def: Resource) -> void:
	if quest_def == null:
		return
	var quest_id := str(quest_def.get("id"))
	if quest_id == "" or seen.has(quest_id):
		return
	seen[quest_id] = true
	result.append(quest_def)
