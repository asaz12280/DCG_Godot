class_name StashCurrencyService
extends RefCounted


static func get_balance(save_manager: Node) -> Dictionary:
	var context := _save_context(save_manager)
	if context.is_empty():
		return {"available": false, "wallet_money": 0, "stash_money": 0}
	var save_data: Dictionary = context.get("save_data", {}) as Dictionary
	return {
		"available": true,
		"wallet_money": maxi(int(save_data.get("money", 0)), 0),
		"stash_money": maxi(int(save_data.get("stash_money", 0)), 0),
	}


static func deposit(save_manager: Node, amount: int) -> Dictionary:
	return _transfer(save_manager, "wallet_to_stash", amount)


static func withdraw(save_manager: Node, amount: int) -> Dictionary:
	return _transfer(save_manager, "stash_to_wallet", amount)


static func _transfer(save_manager: Node, direction: String, amount: int) -> Dictionary:
	var context := _save_context(save_manager)
	if context.is_empty():
		return {"success": false, "reason": "no_save", "amount": 0}
	var save_data: Dictionary = context.get("save_data", {}) as Dictionary
	var source_amount := maxi(int(save_data.get("money", 0)), 0) if direction == "wallet_to_stash" else maxi(int(save_data.get("stash_money", 0)), 0)
	if amount <= 0:
		return {"success": false, "reason": "invalid_amount", "amount": 0, "save_data": save_data}
	if amount > source_amount:
		return {"success": false, "reason": "insufficient_source", "amount": 0, "save_data": save_data}
	if direction == "wallet_to_stash":
		save_data["money"] = source_amount - amount
		save_data["stash_money"] = maxi(int(save_data.get("stash_money", 0)), 0) + amount
	else:
		save_data["stash_money"] = source_amount - amount
		save_data["money"] = maxi(int(save_data.get("money", 0)), 0) + amount
	if not bool(save_manager.call("save_slot_data", int(context.get("slot_index", 1)), save_data)):
		return {"success": false, "reason": "save_failed", "amount": 0}
	return {
		"success": true,
		"reason": "",
		"amount": amount,
		"wallet_money": maxi(int(save_data.get("money", 0)), 0),
		"stash_money": maxi(int(save_data.get("stash_money", 0)), 0),
		"save_data": save_data,
	}


static func _save_context(save_manager: Node) -> Dictionary:
	if save_manager == null or not save_manager.has_method("get_current_slot_index") or not save_manager.has_method("get_slot_data") or not save_manager.has_method("save_slot_data"):
		return {}
	var slot_index := int(save_manager.call("get_current_slot_index"))
	var save_data: Dictionary = save_manager.call("get_slot_data", slot_index)
	if save_data.is_empty():
		return {}
	return {"slot_index": slot_index, "save_data": save_data.duplicate(true)}
