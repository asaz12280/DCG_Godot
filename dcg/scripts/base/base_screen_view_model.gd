class_name BaseScreenViewModel
extends RefCounted

const UITextScript := preload("res://scripts/ui/ui_text.gd")
const QuestStateScript := preload("res://scripts/quests/quest_state.gd")
const QuestCatalogScript := preload("res://scripts/quests/quest_catalog.gd")


static func text(owner: Object, key: StringName, fallback: String) -> String:
	return UITextScript.text(owner, key, fallback)


static func first_salvage_quest() -> Resource:
	return QuestCatalogScript.first_salvage_quest()


static func first_scavenger_hunt_quest() -> Resource:
	return QuestCatalogScript.first_scavenger_hunt_quest()


static func radio_tower_scout_quest() -> Resource:
	return QuestCatalogScript.radio_tower_scout_quest()


static func selected_quest_def(save_data: Dictionary, quest_giver_profile: Resource = null) -> Resource:
	for quest_def in quest_defs(quest_giver_profile):
		if str(quest_state(save_data, quest_def).get("state", "")) == QuestStateScript.STATE_READY:
			return quest_def
	for quest_def in quest_defs(quest_giver_profile):
		if str(quest_state(save_data, quest_def).get("state", "")) == QuestStateScript.STATE_ACTIVE:
			return quest_def
	return null


static func next_available_quest_def(save_data: Dictionary, quest_giver_profile: Resource = null) -> Resource:
	for quest_def in quest_defs(quest_giver_profile):
		var state_name := str(quest_state(save_data, quest_def).get("state", ""))
		if state_name == QuestStateScript.STATE_INACTIVE:
			return quest_def
	return null


static func tracked_quest_defs(save_data: Dictionary, quest_giver_profile: Resource = null) -> Array[Resource]:
	var result: Array[Resource] = []
	for quest_def in quest_defs(quest_giver_profile):
		var state_name := str(quest_state(save_data, quest_def).get("state", ""))
		if state_name == QuestStateScript.STATE_ACTIVE or state_name == QuestStateScript.STATE_READY or state_name == QuestStateScript.STATE_COMPLETED:
			result.append(quest_def)
	return result


static func quest_state(save_data: Dictionary, quest_def: Resource) -> Dictionary:
	var quests: Dictionary = quests_dict(save_data.get("quests", {}))
	var quest_id := str(quest_def.get("id"))
	return QuestStateScript.normalize(quests.get(quest_id, QuestStateScript.create_inactive(quest_def)) as Dictionary, quest_def)


static func quest_display_name(owner: Object, quest_def: Resource) -> String:
	if quest_def == null:
		return text(owner, &"ui.top.quest_empty", "No quests")
	var quest_id := str(quest_def.get("id"))
	var fallback := str(quest_def.get("display_name"))
	return text(owner, StringName("quest.%s.name" % quest_id), fallback)


static func quest_description(owner: Object, quest_def: Resource) -> String:
	if quest_def == null:
		return ""
	var quest_id := str(quest_def.get("id"))
	var fallback := str(quest_def.get("description"))
	return text(owner, StringName("quest.%s.desc" % quest_id), fallback)


static func quest_objective_text(owner: Object, quest_def: Resource) -> String:
	var parts: Array[String] = []
	var objectives: Array = quest_def.get("objectives") as Array
	for objective in objectives:
		match str(quest_def.get("objective_type")):
			"kill":
				parts.append("%s x%d" % [enemy_name(owner, str(objective.get("enemy_id", ""))), int(objective.get("quantity", 0))])
			"location":
				parts.append("%s x%d" % [location_name(owner, str(objective.get("location_id", ""))), int(objective.get("quantity", 0))])
			_:
				parts.append("%s x%d" % [item_name_from_path(owner, str(objective.get("item_path", ""))), int(objective.get("quantity", 0))])
	var objective_type := str(quest_def.get("objective_type"))
	var verb := text(owner, &"ui.base.quest_objective", "帶回")
	match objective_type:
		"kill":
			verb = text(owner, &"ui.base.quest_kill_objective", "擊倒")
		"location":
			verb = text(owner, &"ui.base.quest_location_objective", "前往")
	return "%s: %s" % [verb, _or_separator(owner).join(parts)]


static func quest_progress_text(owner: Object, quest_state_data: Dictionary, quest_def: Resource) -> String:
	var progress: Dictionary = quest_state_data.get("progress", {}) as Dictionary
	var parts: Array[String] = []
	var objectives: Array = quest_def.get("objectives") as Array
	for objective in objectives:
		var objective_type := str(quest_def.get("objective_type"))
		var is_kill := objective_type == "kill"
		var is_location := objective_type == "location"
		var item_path := str(objective.get("item_path", ""))
		var enemy_id := str(objective.get("enemy_id", ""))
		var location_id := str(objective.get("location_id", ""))
		var progress_key := item_path
		if is_kill:
			progress_key = QuestStateScript.kill_progress_key(enemy_id)
		elif is_location:
			progress_key = QuestStateScript.location_progress_key(location_id)
		var current := int(progress.get(progress_key, 0))
		var required := int(objective.get("quantity", 0))
		var label := item_name_from_path(owner, item_path)
		if is_kill:
			label = enemy_name(owner, enemy_id)
		elif is_location:
			label = location_name(owner, location_id)
		parts.append("%s %d/%d" % [label, mini(current, required), required])
	return "%s: %s" % [text(owner, &"ui.base.quest_progress", "進度"), _or_separator(owner).join(parts)]


static func _or_separator(owner: Object) -> String:
	return text(owner, &"ui.common.or_separator", " or ")


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


static func location_name(owner: Object, location_id: String) -> String:
	match location_id:
		"radio_tower":
			return text(owner, &"location.radio_tower.name", "訊號塔")
		_:
			return location_id.capitalize() if location_id != "" else text(owner, &"location.unknown.name", "未知地點")


static func difficulty_name(owner: Object, difficulty_id: String) -> String:
	match difficulty_id:
		"easy":
			return text(owner, &"ui.difficulty.easy", "簡單")
		"hard":
			return text(owner, &"ui.difficulty.hard", "困難")
		_:
			return text(owner, &"ui.difficulty.normal", "普通")


static func quest_defs(quest_giver_profile: Resource = null) -> Array[Resource]:
	var catalog_defs := QuestCatalogScript.quest_defs()
	if quest_giver_profile != null and quest_giver_profile.has_method("quest_defs_for_catalog"):
		var scoped_defs: Array[Resource] = []
		var value: Variant = quest_giver_profile.call("quest_defs_for_catalog", catalog_defs)
		if typeof(value) == TYPE_ARRAY:
			for quest_def in value as Array:
				if quest_def is Resource:
					scoped_defs.append(quest_def)
		return scoped_defs
	return catalog_defs


static func quests_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
