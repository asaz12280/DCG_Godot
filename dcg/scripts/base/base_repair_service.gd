class_name BaseRepairService
extends RefCounted

const BaseProgressionScript := preload("res://scripts/base/base_progression.gd")
const ItemDurabilityServiceScript := preload("res://scripts/items/item_durability_service.gd")
const ItemStackSaveCodecScript := preload("res://scripts/inventory/item_stack_save_codec.gd")
const FixStationUpgrade := preload("res://data/base_upgrades/workbench_fix_station.tres")

const SELECTED_REPAIR_KEY := "selected_repair_ids"
const SOURCE_STASH := "stash"
const SOURCE_BACKPACK := "backpack"
const SOURCE_SAFE_POCKET := "safe_pocket"
const SOURCE_EQUIPMENT := "equipment"


static func get_state_from_save_data(save_data: Dictionary, station_id: StringName = &"workbench", player: Node = null) -> Dictionary:
	var rows := get_repair_rows(save_data, station_id, &"", player)
	var selected_id := _selected_repair_id_for_context(save_data, station_id, player)
	var selected_row: Variant = _find_row(rows, selected_id)
	var selected_row_dict: Dictionary = selected_row as Dictionary if typeof(selected_row) == TYPE_DICTIONARY else {}
	var can_repair := not selected_row_dict.is_empty() and bool(selected_row_dict.get("can_repair", false))
	return {
		"repair_unlocked": _is_repair_unlocked(save_data),
		"repair_rows": rows,
		"selected_repair_id": str(selected_id),
		"selected_repair_row": selected_row_dict,
		"can_repair": can_repair,
		"reason": _repair_reason(save_data, selected_row_dict),
		"selected_repair_ids": _dictionary(save_data.get(SELECTED_REPAIR_KEY, {})),
	}


static func get_repair_rows(save_data: Dictionary, station_id: StringName = &"workbench", selected_repair_id: StringName = &"", player: Node = null) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if station_id != &"workbench" or not _is_repair_unlocked(save_data):
		return rows
	var selected_id := selected_repair_id
	if selected_id == &"":
		selected_id = _saved_repair_selection(save_data, station_id)
	var stash: Array = _stash_array(save_data.get("stash", []))
	for index in range(stash.size()):
		var entry: Variant = stash[index]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row := _repair_row_from_stack(entry as Dictionary, SOURCE_STASH, str(index), save_data)
		if row.is_empty():
			continue
		rows.append(row)
	rows.append_array(_inventory_repair_rows(player, SOURCE_BACKPACK, save_data))
	rows.append_array(_inventory_repair_rows(player, SOURCE_SAFE_POCKET, save_data))
	rows.append_array(_equipment_repair_rows(player, save_data))
	if not rows.is_empty() and (selected_id == &"" or _find_row(rows, selected_id) == null):
		selected_id = StringName(str(rows[0].get("id", "")))
	for index in range(rows.size()):
		var row := rows[index]
		row["is_selected"] = selected_id != &"" and str(row.get("id", "")) == str(selected_id)
		rows[index] = row
	return rows


static func get_selected_repair_id(save_data: Dictionary, station_id: StringName = &"workbench") -> StringName:
	var rows := get_repair_rows(save_data, station_id, _saved_repair_selection(save_data, station_id))
	for row in rows:
		if bool(row.get("is_selected", false)):
			return StringName(str(row.get("id", "")))
	return &""


static func select_repair_item(save_manager: Node, station_id: StringName, repair_id: StringName, player: Node = null) -> Dictionary:
	if save_manager == null or not save_manager.has_method("get_slot_data") or not save_manager.has_method("save_slot_data"):
		return {"success": false, "reason": "no_save"}
	var slot_index := _current_slot_index(save_manager)
	var save_data: Dictionary = save_manager.call("get_slot_data", slot_index)
	var result := select_repair_item_in_save_data(save_data, station_id, repair_id, player)
	if not bool(result.get("success", false)):
		return result
	if not bool(save_manager.call("save_slot_data", slot_index, result.get("save_data", {}) as Dictionary)):
		return {"success": false, "reason": "save_failed", "save_data": save_data.duplicate(true)}
	return result


static func select_repair_item_in_save_data(save_data: Dictionary, station_id: StringName, repair_id: StringName, player: Node = null) -> Dictionary:
	if save_data.is_empty():
		return {"success": false, "reason": "no_save", "save_data": {}}
	if not _is_repair_unlocked(save_data):
		return {"success": false, "reason": "repair_locked", "save_data": save_data.duplicate(true)}
	var rows := get_repair_rows(save_data, station_id, repair_id, player)
	if _find_row(rows, repair_id) == null:
		return {
			"success": false,
			"reason": "repair_unavailable",
			"save_data": save_data.duplicate(true),
			"repair_id": str(repair_id),
		}
	var updated := save_data.duplicate(true)
	var selected := _dictionary(updated.get(SELECTED_REPAIR_KEY, {}))
	selected[str(station_id)] = str(repair_id)
	updated[SELECTED_REPAIR_KEY] = selected
	return {
		"success": true,
		"reason": "ok",
		"save_data": updated,
		"selected_repair_id": str(repair_id),
		"repair_rows": get_repair_rows(updated, station_id, repair_id, player),
	}


static func repair_selected(save_manager: Node, station_id: StringName = &"workbench", player: Node = null) -> Dictionary:
	if save_manager == null or not save_manager.has_method("get_slot_data") or not save_manager.has_method("save_slot_data"):
		return {"success": false, "reason": "no_save", "action_type": "repair"}
	var slot_index := _current_slot_index(save_manager)
	var save_data: Dictionary = save_manager.call("get_slot_data", slot_index)
	var result := repair_selected_from_save_data(save_data, station_id, player)
	result["action_type"] = "repair"
	if not bool(result.get("success", false)):
		return result
	if not bool(save_manager.call("save_slot_data", slot_index, result.get("save_data", {}) as Dictionary)):
		return {"success": false, "reason": "save_failed", "save_data": save_data.duplicate(true), "action_type": "repair"}
	return result


static func repair_selected_from_save_data(save_data: Dictionary, station_id: StringName = &"workbench", player: Node = null) -> Dictionary:
	var selected_id := _selected_repair_id_for_context(save_data, station_id, player)
	if selected_id == &"":
		return {"success": false, "reason": "no_repairable_gear", "save_data": save_data.duplicate(true)}
	return repair_from_save_data(save_data, selected_id, player)


static func repair_from_save_data(save_data: Dictionary, repair_id: StringName, player: Node = null) -> Dictionary:
	if save_data.is_empty():
		return {"success": false, "reason": "no_save", "save_data": {}}
	if not _is_repair_unlocked(save_data):
		return {"success": false, "reason": "repair_locked", "save_data": save_data.duplicate(true)}
	var rows := get_repair_rows(save_data, &"workbench", repair_id, player)
	var row_value: Variant = _find_row(rows, repair_id)
	if typeof(row_value) != TYPE_DICTIONARY:
		return {"success": false, "reason": "repair_unavailable", "save_data": save_data.duplicate(true), "repair_id": str(repair_id)}
	var row := row_value as Dictionary
	var cost := int(row.get("repair_cost", 0))
	if int(save_data.get("money", 0)) < cost:
		return {"success": false, "reason": "missing_money", "save_data": save_data.duplicate(true), "repair_id": str(repair_id), "repair_cost": cost}
	var source_index := int(row.get("source_index", -1))
	var updated := save_data.duplicate(true)
	var original_stack := _stack_for_row(updated, player, row)
	if original_stack.is_empty():
		return {"success": false, "reason": "repair_unavailable", "save_data": save_data.duplicate(true), "repair_id": str(repair_id)}
	var repaired_runtime := _repaired_runtime_stack(original_stack)
	var repaired := ItemStackSaveCodecScript.to_save_entry(repaired_runtime)
	if repaired.is_empty():
		return {"success": false, "reason": "repair_unavailable", "save_data": save_data.duplicate(true), "repair_id": str(repair_id)}
	if str(row.get("source", "")) == SOURCE_STASH:
		var stash: Array = _stash_array(updated.get("stash", []))
		if source_index < 0 or source_index >= stash.size():
			return {"success": false, "reason": "repair_unavailable", "save_data": save_data.duplicate(true), "repair_id": str(repair_id)}
		stash[source_index] = repaired
		updated["stash"] = stash
	elif not _apply_repaired_runtime_stack(player, row, repaired_runtime):
		return {"success": false, "reason": "repair_unavailable", "save_data": save_data.duplicate(true), "repair_id": str(repair_id)}
	updated["money"] = maxi(int(updated.get("money", 0)) - cost, 0)
	return {
		"success": true,
		"reason": "ok",
		"repair_id": str(repair_id),
		"item_path": str(row.get("item_path", "")),
		"item_name": str(row.get("item_name", "")),
		"repair_cost": cost,
		"current_before": int(row.get("current_durability", 0)),
		"max_before": int(row.get("max_durability", 0)),
		"current_after": int(repaired.get("current_durability", 0)),
		"max_after": int(repaired.get("max_durability", 0)),
		"save_data": updated,
		"state": get_state_from_save_data(updated, &"workbench", player),
	}


static func _repair_row_from_stack(entry: Dictionary, source: String, source_key: String, save_data: Dictionary) -> Dictionary:
	var item_path := ItemStackSaveCodecScript.get_item_path(entry)
	var item_def := _load_item(item_path)
	if item_def == null:
		return {}
	var normalized: Dictionary = ItemDurabilityServiceScript.normalize_stack(_entry_to_stack(entry, item_def), item_def)
	if not bool(normalized.get("repairable", false)):
		return {}
	var current := int(normalized.get("current_durability", 0))
	var maximum := int(normalized.get("max_durability", 0))
	var repair_loss := int(normalized.get("repair_max_durability_loss", 0))
	var repaired_max := _max_after_repair(maximum, repair_loss)
	if current >= maximum or repaired_max <= current:
		return {}
	var cost := _repair_cost(item_def, current, maximum)
	var repair_id := _repair_id(source, source_key, item_path)
	var row := {
		"id": repair_id,
		"source": source,
		"source_index": int(source_key) if source_key.is_valid_int() else -1,
		"source_key": source_key,
		"source_label": _source_label(source),
		"source_label_key": str(_source_label_key(source)),
		"item_path": item_path,
		"item_name": _item_name(item_def),
		"current_durability": current,
		"max_durability": maximum,
		"max_after_repair": repaired_max,
		"repair_max_durability_loss": repair_loss,
		"repair_cost": cost,
		"can_repair": int(save_data.get("money", 0)) >= cost,
	}
	if source == SOURCE_EQUIPMENT:
		row["source_slot"] = source_key
	return row


static func _repaired_runtime_stack(stack: Dictionary) -> Dictionary:
	var item_path := ItemStackSaveCodecScript.get_item_path(stack)
	var item_def := _load_item(item_path)
	if item_def == null:
		return {}
	var normalized: Dictionary = ItemDurabilityServiceScript.normalize_stack(_entry_to_stack(stack, item_def), item_def)
	var maximum := int(normalized.get("max_durability", 0))
	var repair_loss := int(normalized.get("repair_max_durability_loss", 0))
	var repaired_max := _max_after_repair(maximum, repair_loss)
	if repaired_max <= int(normalized.get("current_durability", 0)):
		return {}
	normalized["resource_path"] = item_path
	normalized["quantity"] = maxi(int(stack.get("quantity", 1)), 1)
	normalized["current_durability"] = repaired_max
	normalized["max_durability"] = repaired_max
	return normalized


static func _repair_reason(save_data: Dictionary, selected_row: Dictionary) -> String:
	if not _is_repair_unlocked(save_data):
		return "repair_locked"
	if selected_row.is_empty():
		return "no_repairable_gear"
	if int(save_data.get("money", 0)) < int(selected_row.get("repair_cost", 0)):
		return "missing_money"
	return "ready"


static func _repair_cost(item_def: ItemDef, current: int, maximum: int) -> int:
	if item_def == null or maximum <= 0:
		return 0
	var missing := maxi(maximum - current, 0)
	var base_value := maxi(int(item_def.value), 1)
	return maxi(1, ceili(float(missing * base_value) / float(maximum) * 0.35))


static func _max_after_repair(maximum: int, repair_loss: int) -> int:
	return maxi(maximum - maxi(repair_loss, 0), 1)


static func _is_repair_unlocked(save_data: Dictionary) -> bool:
	return BaseProgressionScript.is_upgrade_purchased(save_data, StringName(str(FixStationUpgrade.id)))


static func _repair_id(source: String, source_key: String, item_path: String) -> String:
	return "%s:%s:%s" % [source, source_key, item_path.get_file().get_basename()]


static func _find_row(rows: Array, repair_id: StringName) -> Variant:
	for row_value in rows:
		if typeof(row_value) == TYPE_DICTIONARY and str((row_value as Dictionary).get("id", "")) == str(repair_id):
			return row_value
	return null


static func _saved_repair_selection(save_data: Dictionary, station_id: StringName) -> StringName:
	var selected := _dictionary(save_data.get(SELECTED_REPAIR_KEY, {}))
	return StringName(str(selected.get(str(station_id), "")))


static func _selected_repair_id_for_context(save_data: Dictionary, station_id: StringName, player: Node = null) -> StringName:
	var rows := get_repair_rows(save_data, station_id, _saved_repair_selection(save_data, station_id), player)
	for row in rows:
		if bool(row.get("is_selected", false)):
			return StringName(str(row.get("id", "")))
	return &""


static func _entry_to_stack(entry: Dictionary, item_def: ItemDef) -> Dictionary:
	var stack := item_def.to_stack(maxi(int(entry.get("quantity", 1)), 1))
	for key in [
		"current_durability",
		"max_durability",
		"original_max_durability",
		"repair_max_durability_loss",
		"durability_penalty_ratio",
	]:
		if entry.has(key):
			stack[key] = entry[key]
	return stack


static func _inventory_repair_rows(player: Node, source: String, save_data: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var inventory: Variant = _inventory_model(player, source)
	if inventory == null or not inventory.has_method("get_display_items"):
		return rows
	var stacks: Array = inventory.call("get_display_items")
	for index in range(stacks.size()):
		var value: Variant = stacks[index]
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var row := _repair_row_from_stack(value as Dictionary, source, str(index), save_data)
		if not row.is_empty():
			rows.append(row)
	return rows


static func _equipment_repair_rows(player: Node, save_data: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var equipment: Variant = _equipment_model(player)
	if equipment == null or not equipment.has_method("get_slots"):
		return rows
	var slot_ids: Array = equipment.call("get_slot_ids") if equipment.has_method("get_slot_ids") else (equipment.call("get_slots") as Dictionary).keys()
	for slot_id_value in slot_ids:
		var slot_id := StringName(str(slot_id_value))
		var stack: Dictionary = equipment.call("get_slot", slot_id) if equipment.has_method("get_slot") else ((equipment.call("get_slots") as Dictionary).get(slot_id, {}) as Dictionary)
		if stack.is_empty():
			continue
		var row := _repair_row_from_stack(stack, SOURCE_EQUIPMENT, str(slot_id), save_data)
		if not row.is_empty():
			rows.append(row)
	return rows


static func _stack_for_row(save_data: Dictionary, player: Node, row: Dictionary) -> Dictionary:
	match str(row.get("source", "")):
		SOURCE_STASH:
			var stash: Array = _stash_array(save_data.get("stash", []))
			var index := int(row.get("source_index", -1))
			if index >= 0 and index < stash.size() and typeof(stash[index]) == TYPE_DICTIONARY:
				return (stash[index] as Dictionary).duplicate(true)
		SOURCE_BACKPACK, SOURCE_SAFE_POCKET:
			var inventory: Variant = _inventory_model(player, str(row.get("source", "")))
			var index := int(row.get("source_index", -1))
			if inventory != null and inventory.has_method("get_display_items"):
				var stacks: Array = inventory.call("get_display_items")
				if index >= 0 and index < stacks.size() and typeof(stacks[index]) == TYPE_DICTIONARY:
					return (stacks[index] as Dictionary).duplicate(true)
		SOURCE_EQUIPMENT:
			var equipment: Variant = _equipment_model(player)
			var slot_id := StringName(str(row.get("source_slot", row.get("source_key", ""))))
			if equipment != null and equipment.has_method("get_slot"):
				return equipment.call("get_slot", slot_id) as Dictionary
	return {}


static func _apply_repaired_runtime_stack(player: Node, row: Dictionary, repaired_stack: Dictionary) -> bool:
	match str(row.get("source", "")):
		SOURCE_BACKPACK, SOURCE_SAFE_POCKET:
			var inventory: Variant = _inventory_model(player, str(row.get("source", "")))
			if inventory == null or not inventory.has_method("replace_stack_at"):
				return false
			return bool(inventory.call("replace_stack_at", int(row.get("source_index", -1)), repaired_stack))
		SOURCE_EQUIPMENT:
			var equipment: Variant = _equipment_model(player)
			var slot_id := StringName(str(row.get("source_slot", row.get("source_key", ""))))
			if equipment == null or not equipment.has_method("equip_stack"):
				return false
			return bool(equipment.call("equip_stack", slot_id, repaired_stack))
	return false


static func _inventory_model(player: Node, source: String) -> Variant:
	if player == null:
		return null
	if source == SOURCE_BACKPACK and player.has_method("get_inventory_model"):
		return player.call("get_inventory_model")
	if source == SOURCE_SAFE_POCKET and player.has_method("get_safe_pocket_model"):
		return player.call("get_safe_pocket_model")
	return null


static func _equipment_model(player: Node) -> Variant:
	if player == null or not player.has_method("get_equipment_model"):
		return null
	return player.call("get_equipment_model")


static func _stash_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


static func _dictionary(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


static func _load_item(item_path: String) -> ItemDef:
	if item_path == "" or not ResourceLoader.exists(item_path):
		return null
	return load(item_path) as ItemDef


static func _item_name(item_def: ItemDef) -> String:
	if item_def == null:
		return "Unknown"
	var name_key := str(item_def.name_key)
	if name_key != "":
		var translated := TranslationServer.translate(name_key)
		if translated != name_key and translated != "":
			return translated
	return item_def.display_name if item_def.display_name != "" else str(item_def.id)


static func _source_label(source: String) -> String:
	var key := _source_label_key(source)
	var key_text := str(key)
	var translated := str(TranslationServer.translate(key_text))
	return _source_fallback(source) if translated == key_text or translated == "" else translated


static func _source_label_key(source: String) -> StringName:
	match source:
		SOURCE_STASH:
			return &"ui.base.workbench.repair_source_stash"
		SOURCE_BACKPACK:
			return &"ui.base.workbench.repair_source_backpack"
		SOURCE_SAFE_POCKET:
			return &"ui.base.workbench.repair_source_safe_pocket"
		SOURCE_EQUIPMENT:
			return &"ui.base.workbench.repair_source_equipment"
		_:
			return &"ui.base.workbench.repair_source_unknown"


static func _source_fallback(source: String) -> String:
	match source:
		SOURCE_STASH:
			return "Stash"
		SOURCE_BACKPACK:
			return "Backpack"
		SOURCE_SAFE_POCKET:
			return "Safe pocket"
		SOURCE_EQUIPMENT:
			return "Equipment"
		_:
			return "Unknown"


static func _current_slot_index(save_manager: Node) -> int:
	if save_manager != null and save_manager.has_method("get_current_slot_index"):
		return int(save_manager.call("get_current_slot_index"))
	return 1
