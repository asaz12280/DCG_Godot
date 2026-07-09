class_name BaseStorageUpgradeService
extends RefCounted

const BaseProgressionScript := preload("res://scripts/base/base_progression.gd")
const StorageExpansionUpgrade1 := preload("res://data/base_upgrades/storage_expansion_level_1.tres")
const StorageExpansionUpgrade2 := preload("res://data/base_upgrades/storage_expansion_level_2.tres")


static func get_state(save_manager: Node, base_capacity: int) -> Dictionary:
	var save_data := _get_save_data(save_manager)
	if save_data.is_empty():
		return {
			"has_save": false,
			"can_upgrade": false,
			"is_purchased": false,
			"reason": "no_save",
			"current_capacity": base_capacity,
			"next_capacity": base_capacity,
			"capacity_bonus": int(StorageExpansionUpgrade1.storage_capacity_bonus),
			"upgrade_id": str(StorageExpansionUpgrade1.id),
			"action_text": _text(&"ui.stash.storage_upgrade", "擴容"),
			"summary_text": _text(&"ui.stash.storage_upgrade_no_save", "先建立存檔才能擴容。"),
		}
	var current_capacity := BaseProgressionScript.get_stash_capacity(save_data, base_capacity)
	var next_upgrade := _next_upgrade(save_data)
	var all_purchased := next_upgrade == null
	var check: Dictionary = {"can_purchase": false, "reason": "already_owned"} if all_purchased else BaseProgressionScript.can_purchase_upgrade(save_data, next_upgrade)
	var next_capacity := current_capacity if all_purchased else current_capacity + int(next_upgrade.get("storage_capacity_bonus"))
	var reason := "already_owned" if all_purchased else str(check.get("reason", "unknown"))
	return {
		"has_save": true,
		"can_upgrade": bool(check.get("can_purchase", false)),
		"is_purchased": all_purchased,
		"reason": reason,
		"current_capacity": current_capacity,
		"next_capacity": next_capacity,
		"capacity_bonus": 0 if all_purchased else int(next_upgrade.get("storage_capacity_bonus")),
		"upgrade_id": "" if all_purchased else str(next_upgrade.get("id")),
		"action_text": _text(&"ui.stash.storage_upgrade_owned", "已擴容") if all_purchased else _text(&"ui.stash.storage_upgrade", "擴容"),
		"summary_text": _all_upgrades_complete_text(current_capacity) if all_purchased else describe_compact(next_upgrade, current_capacity, next_capacity, reason),
	}


static func purchase(save_manager: Node) -> Dictionary:
	var save_data := _get_save_data(save_manager)
	if save_data.is_empty():
		return {"success": false, "reason": "no_save"}
	var next_upgrade := _next_upgrade(save_data)
	if next_upgrade == null:
		return {"success": false, "reason": "already_owned"}
	var result: Dictionary = BaseProgressionScript.purchase_upgrade(save_data, next_upgrade)
	if not bool(result.get("success", false)):
		return result
	var slot_index := _current_slot_index(save_manager)
	if save_manager == null or not save_manager.has_method("save_slot_data"):
		return {"success": false, "reason": "missing_save_manager"}
	if not bool(save_manager.call("save_slot_data", slot_index, result.get("save_data", {}) as Dictionary)):
		return {"success": false, "reason": "save_failed"}
	return result


static func get_next_upgrade_for_save_data(save_data: Dictionary) -> Resource:
	return _next_upgrade(save_data)


static func describe_compact(upgrade_def: Resource, current_capacity: int, next_capacity: int, reason: String) -> String:
	var name := _upgrade_display_name(upgrade_def)
	var summary := _storage_upgrade_ready_text(name, current_capacity, next_capacity, BaseProgressionScript.describe_cost(upgrade_def))
	match reason:
		"missing_money":
			return "%s %s" % [summary, _text(&"ui.stash.storage_upgrade_missing_money", "金錢不足。")]
		"missing_items":
			return "%s %s" % [summary, _text(&"ui.stash.storage_upgrade_missing_items", "材料不足。")]
		"no_save":
			return _text(&"ui.stash.storage_upgrade_no_save", "先建立存檔才能擴容。")
		_:
			return summary


static func _storage_upgrade_ready_text(upgrade_name: String, current_capacity: int, next_capacity: int, cost_text: String) -> String:
	var format_text := _text(&"ui.stash.storage_upgrade_ready_format", "%s：%d -> %d，需求 %s。")
	if _format_argument_count(format_text) != 4:
		format_text = "%s：%d -> %d，需求 %s。"
	return format_text % [upgrade_name, current_capacity, next_capacity, cost_text]


static func _format_argument_count(format_text: String) -> int:
	var count := 0
	var index := 0
	while index < format_text.length():
		if format_text.substr(index, 1) == "%":
			if index + 1 < format_text.length() and format_text.substr(index + 1, 1) == "%":
				index += 2
				continue
			count += 1
		index += 1
	return count


static func _next_upgrade(save_data: Dictionary) -> Resource:
	for upgrade_def in _storage_upgrades():
		if not BaseProgressionScript.is_upgrade_purchased(save_data, StringName(str(upgrade_def.get("id")))):
			return upgrade_def
	return null


static func _storage_upgrades() -> Array[Resource]:
	return [StorageExpansionUpgrade1, StorageExpansionUpgrade2]


static func _upgrade_display_name(upgrade_def: Resource) -> String:
	if upgrade_def == null:
		return _text(&"ui.stash.storage_upgrade", "擴容")
	var key := StringName("base_upgrade.%s.name" % str(upgrade_def.get("id")))
	return _text(key, str(upgrade_def.get("display_name")))


static func _all_upgrades_complete_text(current_capacity: int) -> String:
	return _text(&"ui.stash.storage_upgrade_all_owned_format", "已完成目前所有倉庫擴容：容量 %d。") % current_capacity


static func _get_save_data(save_manager: Node) -> Dictionary:
	if save_manager == null or not save_manager.has_method("get_slot_data"):
		return {}
	var data: Dictionary = save_manager.call("get_slot_data", _current_slot_index(save_manager))
	return data.duplicate(true)


static func _current_slot_index(save_manager: Node) -> int:
	if save_manager != null and save_manager.has_method("get_current_slot_index"):
		return int(save_manager.call("get_current_slot_index"))
	return 1


static func _text(key: StringName, fallback: String) -> String:
	var key_text := str(key)
	var translated := TranslationServer.translate(key_text)
	return fallback if translated == key_text or translated == "" else translated
