class_name BaseWorkbenchService
extends RefCounted

const BaseProgressionScript := preload("res://scripts/base/base_progression.gd")
const WorkbenchUpgrade := preload("res://data/base_upgrades/workbench_level_1.tres")


static func get_panel_context(save_manager: Node) -> Dictionary:
	var state := get_state(save_manager)
	return {
		"body": describe(state),
		"action_visible": true,
		"action_enabled": bool(state.get("can_upgrade", false)),
		"action_text": str(state.get("action_text", "升級工作台")),
	}


static func get_state(save_manager: Node) -> Dictionary:
	var save_data := _get_save_data(save_manager)
	if save_data.is_empty():
		return {
			"has_save": false,
			"can_upgrade": false,
			"is_purchased": false,
			"reason": "no_save",
			"action_text": "升級工作台",
		}
	var is_purchased := BaseProgressionScript.is_upgrade_purchased(save_data, WorkbenchUpgrade.id)
	var check: Dictionary = BaseProgressionScript.can_purchase_upgrade(save_data, WorkbenchUpgrade)
	return {
		"has_save": true,
		"can_upgrade": bool(check.get("can_purchase", false)),
		"is_purchased": is_purchased,
		"reason": "already_owned" if is_purchased else str(check.get("reason", "unknown")),
		"action_text": "已升級" if is_purchased else "升級工作台",
	}


static func purchase(save_manager: Node) -> Dictionary:
	var save_data := _get_save_data(save_manager)
	if save_data.is_empty():
		return {"success": false, "reason": "no_save"}
	var result: Dictionary = BaseProgressionScript.purchase_upgrade(save_data, WorkbenchUpgrade)
	if not bool(result.get("success", false)):
		return result
	var slot_index := _current_slot_index(save_manager)
	if save_manager == null or not save_manager.has_method("save_slot_data"):
		return {"success": false, "reason": "missing_save_manager"}
	if not bool(save_manager.call("save_slot_data", slot_index, result.get("save_data", {}) as Dictionary)):
		return {"success": false, "reason": "save_failed"}
	return result


static func describe(state: Dictionary) -> String:
	var lines: Array[String] = [
		"%s" % str(WorkbenchUpgrade.display_name),
		"效果：下一場行動備用彈藥 +%d。" % int(WorkbenchUpgrade.starter_ammo_bonus),
		"需求：%s。" % BaseProgressionScript.describe_cost(WorkbenchUpgrade),
	]
	if bool(state.get("is_purchased", false)):
		lines.append("狀態：已升級。進入下一場 Raid 時會直接套用。")
	elif not bool(state.get("has_save", false)):
		lines.append("狀態：先建立存檔才能升級。")
	elif bool(state.get("can_upgrade", false)):
		lines.append("狀態：材料足夠，可以升級。")
	else:
		lines.append("狀態：%s" % _blocked_reason_text(str(state.get("reason", "unknown"))))
	return "\n".join(lines)


static func _blocked_reason_text(reason: String) -> String:
	match reason:
		"missing_money":
			return "金錢不足。"
		"missing_items":
			return "材料不足。"
		"already_owned":
			return "已升級。"
		"invalid_upgrade":
			return "升級資料異常。"
		_:
			return "暫時無法升級。"


static func _get_save_data(save_manager: Node) -> Dictionary:
	if save_manager == null or not save_manager.has_method("get_slot_data"):
		return {}
	var data: Dictionary = save_manager.call("get_slot_data", _current_slot_index(save_manager))
	return data.duplicate(true)


static func _current_slot_index(save_manager: Node) -> int:
	if save_manager != null and save_manager.has_method("get_current_slot_index"):
		return int(save_manager.call("get_current_slot_index"))
	return 1
