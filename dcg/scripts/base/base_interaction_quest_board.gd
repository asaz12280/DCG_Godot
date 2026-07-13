class_name BaseInteractionQuestBoard
extends RefCounted

const BaseScreenViewModelScript := preload("res://scripts/base/base_screen_view_model.gd")
const QuestStateScript := preload("res://scripts/quests/quest_state.gd")


static func panel_context(controller, save_manager, quest_giver_profile: Resource = null) -> Dictionary:
	if save_manager == null or not save_manager.has_method("get_slot_data"):
		return unavailable_context(controller._localized_text(&"ui.base.quest_no_save", "Create a save first."))
	var slot_index := int(save_manager.call("get_current_slot_index")) if save_manager.has_method("get_current_slot_index") else 1
	var save_data: Dictionary = save_manager.call("get_slot_data", slot_index)
	if save_data.is_empty():
		return unavailable_context(controller._localized_text(&"ui.base.quest_no_save", "Create a save first."))
	var selected := BaseScreenViewModelScript.selected_quest_def(save_data, quest_giver_profile)
	if selected != null:
		var state := BaseScreenViewModelScript.quest_state(save_data, selected)
		return {
			"body": detail_body(controller, selected, state),
			"action_visible": true,
			"action_enabled": QuestStateScript.can_claim(state, selected),
			"action_text": controller._localized_text(&"ui.base.submit_quest", "Submit"),
			"action_mode": "quest_submit",
			"quest_id": str(selected.get("id")),
		}
	var available := BaseScreenViewModelScript.next_available_quest_def(save_data, quest_giver_profile)
	if available != null:
		return {
			"body": "%s\n%s\n%s" % [
				controller._localized_text(&"ui.base.quest_board_available", "Available quest"),
				str(available.get("display_name")),
				BaseScreenViewModelScript.quest_objective_text(controller, available),
			],
			"action_visible": true,
			"action_enabled": true,
			"action_text": controller._localized_text(&"ui.base.accept_quest", "Accept Quest"),
			"action_mode": "quest_accept",
			"quest_id": str(available.get("id")),
		}
	return unavailable_context(controller._localized_text(&"ui.base.quest_board_empty", "No quests available."))


static func unavailable_context(body: String) -> Dictionary:
	return {"body": body, "action_visible": false, "action_enabled": false, "action_mode": "quest_unavailable"}


static func detail_body(controller, quest_def: Resource, quest_state: Dictionary) -> String:
	return "%s\n%s\n%s\n%s" % [
		BaseScreenViewModelScript.quest_display_name(controller, quest_def),
		BaseScreenViewModelScript.quest_objective_text(controller, quest_def),
		BaseScreenViewModelScript.quest_progress_text(controller, quest_state, quest_def),
		status_text(controller, quest_state),
	]


static func status_text(controller, quest_state: Dictionary) -> String:
	match str(quest_state.get("state", QuestStateScript.STATE_INACTIVE)):
		QuestStateScript.STATE_READY:
			return controller._localized_text(&"ui.base.quest_ready", "Ready")
		QuestStateScript.STATE_COMPLETED:
			return controller._localized_text(&"ui.base.quest_completed", "Completed")
		QuestStateScript.STATE_ACTIVE:
			return controller._localized_text(&"ui.base.quest_active", "Active")
	return controller._localized_text(&"ui.top.quest_inactive", "Inactive")


static func execute_action(controller, panel: Control, save_manager, quest_giver_profile: Resource = null) -> Dictionary:
	if save_manager == null or not save_manager.has_method("get_slot_data") or not save_manager.has_method("save_slot_data"):
		return {"success": false, "reason": "no_save"}
	var slot_index := int(save_manager.call("get_current_slot_index")) if save_manager.has_method("get_current_slot_index") else 1
	var save_data: Dictionary = save_manager.call("get_slot_data", slot_index)
	if save_data.is_empty():
		return {"success": false, "reason": "no_save"}
	var mode := str(panel.active_context.get("action_mode", "")) if panel != null else ""
	var quest_id := str(panel.active_context.get("quest_id", "")) if panel != null else ""
	var quest_def := quest_def_by_id(quest_id, quest_giver_profile)
	if quest_def == null:
		return {"success": false, "reason": "missing_quest"}
	var quests: Dictionary = BaseScreenViewModelScript.quests_dict(save_data.get("quests", {}))
	if mode == "quest_accept":
		quests[quest_id] = QuestStateScript.accept(quest_def)
		save_data["quests"] = quests
		return {"success": bool(save_manager.call("save_slot_data", slot_index, save_data)), "reason": "accepted"}
	if mode == "quest_submit":
		var quest_state: Dictionary = quests.get(quest_id, {}) as Dictionary
		var result: Dictionary = QuestStateScript.claim_reward(save_data, quest_state, quest_def)
		if not bool(result.get("success", false)):
			return result
		var updated: Dictionary = result.get("save_data", {}) as Dictionary
		var updated_quests: Dictionary = BaseScreenViewModelScript.quests_dict(updated.get("quests", {}))
		updated_quests[quest_id] = result.get("quest_state", {}) as Dictionary
		updated["quests"] = updated_quests
		result["success"] = bool(save_manager.call("save_slot_data", slot_index, updated))
		return result
	return {"success": false, "reason": "invalid_mode"}


static func quest_def_by_id(quest_id: String, quest_giver_profile: Resource = null) -> Resource:
	for quest_def in BaseScreenViewModelScript.quest_defs(quest_giver_profile):
		if str(quest_def.get("id")) == quest_id:
			return quest_def
	return null
