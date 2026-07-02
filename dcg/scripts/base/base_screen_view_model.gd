class_name BaseScreenViewModel
extends RefCounted

const UITextScript := preload("res://scripts/ui/ui_text.gd")
const QuestStateScript := preload("res://scripts/quests/quest_state.gd")
const FIRST_SALVAGE_QUEST := preload("res://data/quests/first_salvage.tres")
const FIRST_SCAVENGER_HUNT_QUEST := preload("res://data/quests/first_scavenger_hunt.tres")


static func text(owner: Object, key: StringName, fallback: String) -> String:
	return UITextScript.text(owner, key, fallback)


static func first_salvage_quest() -> Resource:
	return FIRST_SALVAGE_QUEST


static func first_scavenger_hunt_quest() -> Resource:
	return FIRST_SCAVENGER_HUNT_QUEST


static func selected_quest_def(save_data: Dictionary) -> Resource:
	for quest_def in quest_defs():
		if str(quest_state(save_data, quest_def).get("state", "")) == QuestStateScript.STATE_READY:
			return quest_def
	for quest_def in quest_defs():
		if str(quest_state(save_data, quest_def).get("state", "")) == QuestStateScript.STATE_ACTIVE:
			return quest_def
	for quest_def in quest_defs():
		if str(quest_state(save_data, quest_def).get("state", "")) != QuestStateScript.STATE_COMPLETED:
			return quest_def
	return quest_defs().back()


static func quest_state(save_data: Dictionary, quest_def: Resource) -> Dictionary:
	var quests: Dictionary = quests_dict(save_data.get("quests", {}))
	var quest_id := str(quest_def.get("id"))
	return QuestStateScript.normalize(quests.get(quest_id, QuestStateScript.create(quest_def)) as Dictionary, quest_def)


static func quest_objective_text(owner: Object, quest_def: Resource) -> String:
	var parts: Array[String] = []
	var objectives: Array = quest_def.get("objectives") as Array
	for objective in objectives:
		if str(quest_def.get("objective_type")) == "kill":
			parts.append("%s x%d" % [enemy_name(owner, str(objective.get("enemy_id", ""))), int(objective.get("quantity", 0))])
		else:
			parts.append("%s x%d" % [item_name_from_path(owner, str(objective.get("item_path", ""))), int(objective.get("quantity", 0))])
	var verb := text(owner, &"ui.base.quest_kill_objective", "擊倒") if str(quest_def.get("objective_type")) == "kill" else text(owner, &"ui.base.quest_objective", "帶回")
	return "%s: %s" % [verb, " 或 ".join(parts)]


static func quest_progress_text(owner: Object, quest_state_data: Dictionary, quest_def: Resource) -> String:
	var progress: Dictionary = quest_state_data.get("progress", {}) as Dictionary
	var parts: Array[String] = []
	var objectives: Array = quest_def.get("objectives") as Array
	for objective in objectives:
		var is_kill := str(quest_def.get("objective_type")) == "kill"
		var item_path := str(objective.get("item_path", ""))
		var enemy_id := str(objective.get("enemy_id", ""))
		var progress_key := QuestStateScript.kill_progress_key(enemy_id) if is_kill else item_path
		var current := int(progress.get(progress_key, 0))
		var required := int(objective.get("quantity", 0))
		var label := enemy_name(owner, enemy_id) if is_kill else item_name_from_path(owner, item_path)
		parts.append("%s %d/%d" % [label, mini(current, required), required])
	return "%s: %s" % [text(owner, &"ui.base.quest_progress", "進度"), " 或 ".join(parts)]


static func upgrade_ready_text(owner: Object, reason: String) -> String:
	match reason:
		"ok":
			return text(owner, &"ui.base.workbench_ready", "可升級")
		"missing_money":
			return text(owner, &"ui.base.workbench_need_money", "金錢不足")
		"missing_items":
			return text(owner, &"ui.base.workbench_need_items", "材料不足")
		"already_owned":
			return text(owner, &"ui.base.workbench_upgraded", "已升級：初始備用彈藥 +1")
		_:
			return text(owner, &"ui.base.workbench_unavailable", "無法升級")


static func upgrade_failure_text(owner: Object, reason: String) -> String:
	match reason:
		"missing_money":
			return text(owner, &"ui.base.upgrade_missing_money", "升級所需金錢不足。")
		"missing_items":
			return text(owner, &"ui.base.upgrade_missing_items", "升級所需材料不足。")
		"already_owned":
			return text(owner, &"ui.base.upgrade_already_owned", "工作台已經升級。")
		_:
			return text(owner, &"ui.base.upgrade_failed", "無法升級工作台。")


static func item_name_from_path(owner: Object, item_path: String) -> String:
	return UITextScript.item_name(owner, item_path, "未知物品")


static func enemy_name(owner: Object, enemy_id: String) -> String:
	match enemy_id:
		"scavenger":
			return text(owner, &"enemy.scavenger.name", "拾荒者")
		_:
			return enemy_id.capitalize() if enemy_id != "" else text(owner, &"enemy.unknown.name", "未知敵人")


static func difficulty_name(owner: Object, difficulty_id: String) -> String:
	match difficulty_id:
		"easy":
			return text(owner, &"ui.difficulty.easy", "簡單")
		"hard":
			return text(owner, &"ui.difficulty.hard", "困難")
		_:
			return text(owner, &"ui.difficulty.normal", "普通")


static func quest_defs() -> Array[Resource]:
	return [FIRST_SALVAGE_QUEST, FIRST_SCAVENGER_HUNT_QUEST]


static func quests_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
