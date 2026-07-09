class_name UIManagerQuestActions
extends RefCounted

const BaseScreenViewModelScript := preload("res://scripts/base/base_screen_view_model.gd")
const QuestStateScript := preload("res://scripts/quests/quest_state.gd")


static func execute(manager, quest_id: String, action_mode: String) -> Dictionary:
	var save_manager: Node = manager._get_save_manager()
	if save_manager == null or not save_manager.has_method("get_slot_data") or not save_manager.has_method("save_slot_data"):
		return _result(false, action_mode, manager._text(&"ui.base.quest_no_save", "Create a save first."))
	var slot_index := int(save_manager.call("get_current_slot_index")) if save_manager.has_method("get_current_slot_index") else 1
	var save_data: Dictionary = save_manager.call("get_slot_data", slot_index)
	if save_data.is_empty():
		return _result(false, action_mode, manager._text(&"ui.base.quest_no_save", "Create a save first."))
	var quest_def := _quest_def_by_id(quest_id)
	if quest_def == null:
		return _result(false, action_mode, manager._text(&"ui.base.quest_action_failed", "Quest action failed."))
	var quests: Dictionary = BaseScreenViewModelScript.quests_dict(save_data.get("quests", {}))
	if action_mode == "quest_accept":
		quests[quest_id] = QuestStateScript.accept(quest_def)
		save_data["quests"] = quests
		var accepted := bool(save_manager.call("save_slot_data", slot_index, save_data))
		return _result(accepted, action_mode, manager._text(&"ui.base.quest_accepted", "Quest accepted.") if accepted else manager._text(&"ui.base.quest_action_failed", "Quest action failed."))
	if action_mode == "quest_submit":
		var quest_state: Dictionary = quests.get(quest_id, {}) as Dictionary
		var reward_result: Dictionary = QuestStateScript.claim_reward(save_data, quest_state, quest_def)
		if not bool(reward_result.get("success", false)):
			return _result(false, action_mode, manager._text(&"ui.base.quest_not_ready", "Quest is not ready."))
		var updated: Dictionary = reward_result.get("save_data", {}) as Dictionary
		var updated_quests: Dictionary = BaseScreenViewModelScript.quests_dict(updated.get("quests", {}))
		updated_quests[quest_id] = reward_result.get("quest_state", {}) as Dictionary
		updated["quests"] = updated_quests
		var submitted := bool(save_manager.call("save_slot_data", slot_index, updated))
		return _result(submitted, action_mode, manager._text(&"ui.base.quest_claimed", "Quest reward claimed.") if submitted else manager._text(&"ui.base.quest_action_failed", "Quest action failed."))
	if action_mode == "quest_cancel":
		if not quests.has(quest_id):
			return _result(false, action_mode, manager._text(&"ui.base.quest_action_failed", "Quest action failed."))
		quests.erase(quest_id)
		save_data["quests"] = quests
		var cancelled := bool(save_manager.call("save_slot_data", slot_index, save_data))
		return _result(cancelled, action_mode, manager._text(&"ui.top.quest_cancelled", "Quest cancelled.") if cancelled else manager._text(&"ui.base.quest_action_failed", "Quest action failed."))
	return _result(false, action_mode, manager._text(&"ui.base.quest_action_failed", "Quest action failed."))


static func _result(success: bool, action_mode: String, message: String) -> Dictionary:
	return {"success": success, "action_mode": action_mode, "message": message}


static func _quest_def_by_id(quest_id: String) -> Resource:
	for quest_def in BaseScreenViewModelScript.quest_defs():
		if str(quest_def.get("id")) == quest_id:
			return quest_def
	return null
