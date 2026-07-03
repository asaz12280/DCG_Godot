class_name BaseMedicalService
extends RefCounted

const HEAL_COST := 10


static func get_state(player: Node, save_manager: Node) -> Dictionary:
	var health_max := _player_max_health(player)
	var health_current := _player_health(player)
	var missing_health := maxf(health_max - health_current, 0.0)
	var money := _current_money(save_manager)
	var has_save := _current_save_data(save_manager).is_empty() == false
	var can_heal := has_save and missing_health > 0.05 and money >= HEAL_COST
	var status := _text(&"ui.base.medical.full_health", "生命已滿，不需要治療。")
	if not has_save:
		status = _text(&"ui.base.medical.no_save", "找不到目前存檔，無法扣款治療。")
	elif missing_health > 0.05 and money < HEAL_COST:
		status = _text(&"ui.base.medical.need_money", "金錢不足，治療需要 $%d。") % HEAL_COST
	elif missing_health > 0.05:
		status = _text(&"ui.base.medical.can_heal", "可支付 $%d 將生命回復至滿。") % HEAL_COST
	return {
		"health_current": health_current,
		"health_max": health_max,
		"missing_health": missing_health,
		"money": money,
		"cost": HEAL_COST,
		"can_heal": can_heal,
		"status": status,
		"action_text": _text(&"ui.base.medical.action", "治療 $%d") % HEAL_COST,
	}


static func describe(player: Node, save_manager: Node) -> String:
	var state := get_state(player, save_manager)
	return _text(&"ui.base.medical.body_format", "醫療站已連接。生命 %d / %d，金錢 $%d。%s") % [
		roundi(float(state.get("health_current", 0.0))),
		roundi(float(state.get("health_max", 0.0))),
		int(state.get("money", 0)),
		str(state.get("status", "")),
	]


static func apply_heal(player: Node, save_manager: Node) -> Dictionary:
	var state := get_state(player, save_manager)
	if not bool(state.get("can_heal", false)):
		return {
			"success": false,
			"reason": str(state.get("status", _text(&"ui.base.medical.cannot_heal", "無法治療。"))),
			"state": state,
		}
	var save_data := _current_save_data(save_manager)
	var slot_index := _current_slot_index(save_manager)
	save_data["money"] = maxi(int(save_data.get("money", 0)) - HEAL_COST, 0)
	if not _restore_player_health(player):
		return {
			"success": false,
			"reason": _text(&"ui.base.medical.full_health", "生命已滿，不需要治療。"),
			"state": get_state(player, save_manager),
		}
	if save_manager == null or not save_manager.has_method("save_slot_data") or not bool(save_manager.call("save_slot_data", slot_index, save_data)):
		return {
			"success": false,
			"reason": _text(&"ui.base.medical.save_failed", "治療完成，但存檔扣款失敗。"),
			"state": get_state(player, save_manager),
		}
	return {
		"success": true,
		"reason": _text(&"ui.base.medical.healed", "治療完成，生命已回滿。"),
		"state": get_state(player, save_manager),
	}


static func _restore_player_health(player: Node) -> bool:
	if player == null:
		return false
	if player.has_method("restore_health_to_full"):
		return bool(player.call("restore_health_to_full"))
	var health_max := _player_max_health(player)
	var health_current := _player_health(player)
	if health_max <= 0.0 or health_current >= health_max:
		return false
	player.set("health", health_max)
	return true


static func _player_health(player: Node) -> float:
	if player == null:
		return 0.0
	return float(player.get("health"))


static func _player_max_health(player: Node) -> float:
	if player == null:
		return 0.0
	if player.has_method("get_total_max_health"):
		return float(player.call("get_total_max_health"))
	return float(player.get("max_health"))


static func _current_money(save_manager: Node) -> int:
	var save_data := _current_save_data(save_manager)
	return int(save_data.get("money", 0))


static func _current_slot_index(save_manager: Node) -> int:
	if save_manager != null and save_manager.has_method("get_current_slot_index"):
		return int(save_manager.call("get_current_slot_index"))
	return 1


static func _current_save_data(save_manager: Node) -> Dictionary:
	if save_manager == null or not save_manager.has_method("get_slot_data"):
		return {}
	return save_manager.call("get_slot_data", _current_slot_index(save_manager)) as Dictionary


static func _text(key: StringName, fallback: String) -> String:
	var key_text := str(key)
	var translated := TranslationServer.translate(key_text)
	return fallback if translated == key_text or translated == "" else translated
