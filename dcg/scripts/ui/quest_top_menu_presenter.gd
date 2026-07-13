extends RefCounted

const BaseScreenViewModelScript := preload("res://scripts/base/base_screen_view_model.gd")
const QuestStateScript := preload("res://scripts/quests/quest_state.gd")
const UITextScript := preload("res://scripts/ui/ui_text.gd")

const CATEGORY_AVAILABLE := "available"
const CATEGORY_ACTIVE := "active"
const CATEGORY_COMPLETED := "completed"
const ACTION_ACCEPT := "quest_accept"
const ACTION_SUBMIT := "quest_submit"
const ACTION_ACTIVE := "quest_active"
const ACTION_COMPLETED := "quest_completed"
const ACTION_CANCEL := "quest_cancel"


static func build_entries(owner: Control, save_data: Dictionary, quest_defs: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for quest_def in quest_defs:
		var quest_state := BaseScreenViewModelScript.quest_state(save_data, quest_def)
		var state_name := str(quest_state.get("state", QuestStateScript.STATE_INACTIVE))
		result.append({
			"id": str(quest_def.get("id")),
			"name": BaseScreenViewModelScript.quest_display_name(owner, quest_def),
			"description": description_for_quest(owner, quest_def),
			"objective": BaseScreenViewModelScript.quest_objective_text(owner, quest_def),
			"progress": localized_progress_for_quest(owner, quest_state, quest_def),
			"reward": reward_text(owner, quest_def),
			"status": localized_status_text(owner, quest_state),
			"state": state_name,
			"category": category_for_state(state_name),
			"action_mode": action_mode_for_state(state_name),
		})
	return result


static func category_for_state(state_name: String) -> String:
	match state_name:
		QuestStateScript.STATE_INACTIVE:
			return CATEGORY_AVAILABLE
		QuestStateScript.STATE_COMPLETED:
			return CATEGORY_COMPLETED
		_:
			return CATEGORY_ACTIVE


static func action_mode_for_state(state_name: String) -> String:
	match state_name:
		QuestStateScript.STATE_INACTIVE:
			return ACTION_ACCEPT
		QuestStateScript.STATE_READY:
			return ACTION_SUBMIT
		QuestStateScript.STATE_COMPLETED:
			return ACTION_COMPLETED
		_:
			return ACTION_CANCEL


static func localized_status_text(owner: Control, quest_state: Dictionary) -> String:
	match str(quest_state.get("state", QuestStateScript.STATE_INACTIVE)):
		QuestStateScript.STATE_COMPLETED:
			return _locale_text(owner, &"ui.base.quest_completed", "Completed", "Completed")
		QuestStateScript.STATE_READY:
			return _locale_text(owner, &"ui.base.quest_ready", "Ready", "Ready")
		QuestStateScript.STATE_ACTIVE:
			return _locale_text(owner, &"ui.base.quest_active", "Active", "Active")
		_:
			return _locale_text(owner, &"ui.top.quest_available", "Available", "Available")


static func localized_progress_for_quest(owner: Control, quest_state: Dictionary, quest_def: Resource) -> String:
	if str(quest_state.get("state", QuestStateScript.STATE_INACTIVE)) == QuestStateScript.STATE_INACTIVE:
		return _locale_text(owner, &"ui.top.quest_not_accepted", "Not accepted", "Not accepted")
	return BaseScreenViewModelScript.quest_progress_text(owner, quest_state, quest_def)


static func description_for_quest(owner: Control, quest_def: Resource) -> String:
	var description := BaseScreenViewModelScript.quest_description(owner, quest_def)
	if description.strip_edges() == "" or UITextScript.looks_corrupt(description):
		return _text(owner, &"ui.top.quest_default_description", "Review the quest requirements and return to claim rewards.")
	return description


static func reward_text(owner: Control, quest_def: Resource) -> String:
	if quest_def == null:
		return _locale_text(owner, &"ui.top.quest_no_reward", "None", "None")
	var parts: Array[String] = []
	var money := int(quest_def.get("reward_money"))
	if money > 0:
		parts.append("%s %d" % [_locale_text(owner, &"ui.top.quest_reward_money", "Cash", "Cash"), money])
	var rewards: Array = quest_def.get("reward_items") as Array
	for reward in rewards:
		if typeof(reward) != TYPE_DICTIONARY:
			continue
		var reward_dict := reward as Dictionary
		var item_path := str(reward_dict.get("item_path", ""))
		var quantity := int(reward_dict.get("quantity", 0))
		if item_path == "" or quantity <= 0:
			continue
		parts.append("%s x%d" % [item_name(owner, item_path), quantity])
	if parts.is_empty():
		return _locale_text(owner, &"ui.top.quest_no_reward", "None", "None")
	return _reward_delimiter().join(parts)


static func item_name(owner: Control, item_path: String) -> String:
	if _is_english_locale():
		match item_path:
			"res://data/items/crafting/wood.tres":
				return "Wood"
	var item_name_text := BaseScreenViewModelScript.item_name_from_path(owner, item_path)
	if item_name_text.strip_edges() == "" or UITextScript.looks_corrupt(item_name_text):
		return "Unknown item"
	return item_name_text


static func enemy_name(enemy_id: String) -> String:
	match enemy_id:
		"scavenger":
			return "Scavenger"
		_:
			return enemy_id.capitalize() if enemy_id != "" else "Unknown enemy"


static func location_name(location_id: String) -> String:
	match location_id:
		"radio_tower":
			return "Signal tower"
		_:
			return location_id.capitalize() if location_id != "" else "Unknown location"


static func _text(owner: Control, key: StringName, fallback: String) -> String:
	return UITextScript.text(owner, key, fallback)


static func _locale_text(owner: Control, key: StringName, zh_fallback: String, en_fallback: String) -> String:
	return _text(owner, key, en_fallback if _is_english_locale() else zh_fallback)


static func _is_english_locale() -> bool:
	return TranslationServer.get_locale().begins_with("en")


static func _reward_delimiter() -> String:
	return ", " if _is_english_locale() else " / "
