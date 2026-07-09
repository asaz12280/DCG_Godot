class_name BaseWorkbenchDescription
extends RefCounted

const BaseProgressionScript := preload("res://scripts/base/base_progression.gd")
const WorkbenchUpgrade := preload("res://data/base_upgrades/workbench_level_1.tres")
const FixStationUpgrade := preload("res://data/base_upgrades/workbench_fix_station.tres")
const DisassembleStationUpgrade := preload("res://data/base_upgrades/workbench_disassemble_station.tres")

const STATION_MODE_BLUEPRINTS := "blueprints"
const STATION_MODE_REPAIR := "repair"
const STATION_MODE_DISMANTLE := "dismantle"


static func describe(state: Dictionary) -> String:
	var lines: Array[String] = [
		"%s" % _text(&"base_upgrade.workbench_level_1.name", str(WorkbenchUpgrade.display_name)),
		_text(&"ui.base.workbench.effect_format", "Effect: next raid starts with +%d reserve ammo.") % int(WorkbenchUpgrade.starter_ammo_bonus),
		_text(&"ui.base.workbench.cost_format", "Cost: %s.") % BaseProgressionScript.describe_cost(WorkbenchUpgrade),
	]
	if bool(state.get("is_purchased", false)):
		lines.append(_text(&"ui.base.workbench.status_upgraded", "Status: upgraded."))
		match str(state.get("selected_station_mode", "")):
			STATION_MODE_BLUEPRINTS:
				lines.append_array(_blueprint_lines(state))
			STATION_MODE_REPAIR:
				lines.append_array(_repair_lines(state))
			STATION_MODE_DISMANTLE:
				lines.append_array(_dismantle_lines(state))
			_:
				lines.append_array(_recipe_lines(state))
	elif not bool(state.get("has_save", false)):
		lines.append(_text(&"ui.base.workbench.status_no_save", "Status: create a save before upgrading."))
	elif bool(state.get("can_upgrade", false)):
		lines.append(_text(&"ui.base.workbench.status_ready", "Status: materials ready."))
	else:
		lines.append(_text(&"ui.base.workbench.status_format", "Status: %s") % _blocked_reason_text(str(state.get("reason", "unknown"))))
	return "\n".join(lines)


static func action_text(action_mode: String, selected_recipe: Resource, can_craft: bool, can_research_blueprint: bool, repair_state: Dictionary = {}, dismantle_state: Dictionary = {}) -> String:
	match action_mode:
		"craft":
			return _craft_action_text(selected_recipe) if can_craft else _text(&"ui.base.workbench.craft_missing", "Missing materials")
		"blueprint_research":
			return _text(&"ui.base.workbench.blueprint_research_action", "Research Blueprint") if can_research_blueprint else _text(&"ui.base.workbench.blueprint_research_missing", "No blueprint ready")
		"fix_station_upgrade":
			return _text(&"ui.base.workbench.fix_station_action", "Install Fix Station")
		"repair":
			var row: Dictionary = repair_state.get("selected_repair_row", {}) as Dictionary
			if row.is_empty():
				return _text(&"ui.base.workbench.repair_unavailable", "No repairable gear")
			return _text(&"ui.base.workbench.repair_action_format", "Repair %s") % str(row.get("item_name", ""))
		"disassemble_station_upgrade":
			return _text(&"ui.base.workbench.disassemble_station_action", "Install Disassemble Station")
		"dismantle":
			var row: Dictionary = dismantle_state.get("selected_dismantle_row", {}) as Dictionary
			if row.is_empty():
				return _text(&"ui.base.workbench.dismantle_unavailable", "No dismantle item")
			return _text(&"ui.base.workbench.dismantle_action_format", "Dismantle %s") % str(row.get("input_name", ""))
		_:
			return _text(&"ui.base.workbench.action", "Upgrade Workbench")


static func _recipe_lines(state: Dictionary) -> Array[String]:
	var rows: Array = state.get("recipe_rows", []) as Array
	if rows.is_empty():
		return [_text(&"ui.base.workbench.recipe_none", "No recipes available.")]
	var lines: Array[String] = [_text(&"ui.base.workbench.recipe_list_title", "Recipes")]
	for row_value in rows:
		if typeof(row_value) != TYPE_DICTIONARY:
			continue
		var row := row_value as Dictionary
		var row_text_key := &"ui.base.workbench.recipe_selected_row_format" if bool(row.get("is_selected", false)) else &"ui.base.workbench.recipe_row_format"
		var row_text_fallback := "> %s x%d - %s" if bool(row.get("is_selected", false)) else "  %s x%d - %s"
		lines.append(_text(row_text_key, row_text_fallback) % [
			str(row.get("output_name", "")),
			int(row.get("output_quantity", 0)),
			_recipe_status_text(bool(row.get("can_craft", false))),
		])
		if bool(row.get("is_selected", false)):
			lines.append(_text(&"ui.base.workbench.recipe_cost_format", "Recipe cost: %s.") % str(row.get("cost_text", "")))
	return lines


static func _blueprint_lines(state: Dictionary) -> Array[String]:
	var rows: Array = state.get("blueprint_rows", []) as Array
	if rows.is_empty():
		return [_text(&"ui.base.workbench.blueprint_none", "No blueprints available.")]
	var lines: Array[String] = [_text(&"ui.base.workbench.blueprint_list_title", "Blueprint Research")]
	for row_value in rows:
		if typeof(row_value) != TYPE_DICTIONARY:
			continue
		var row := row_value as Dictionary
		lines.append(_text(&"ui.base.workbench.blueprint_row_format", "%s -> %s - %s") % [
			str(row.get("blueprint_name", "")),
			str(row.get("recipe_name", "")),
			_blueprint_status_text(row),
		])
	return lines


static func _repair_lines(state: Dictionary) -> Array[String]:
	var lines: Array[String] = [
		"%s" % _text(&"base_upgrade.workbench_fix_station.name", str(FixStationUpgrade.display_name)),
		_text(&"ui.base.workbench.fix_station_effect", "Effect: unlocks workbench repair mode."),
		_text(&"ui.base.workbench.cost_format", "Cost: %s.") % BaseProgressionScript.describe_cost(FixStationUpgrade),
	]
	if not bool(state.get("repair_unlocked", false)):
		lines.append(_text(&"ui.base.workbench.fix_station_ready", "Status: materials ready for installation.") if bool(state.get("can_purchase_fix_station", false)) else _text(&"ui.base.workbench.status_format", "Status: %s") % _blocked_reason_text(str(state.get("reason", "unknown"))))
		return lines
	lines.append(_text(&"ui.base.workbench.fix_station_installed", "Fix Station installed."))
	var rows: Array = state.get("repair_rows", []) as Array
	if rows.is_empty():
		lines.append(_text(&"ui.base.workbench.repair_none", "No repairable gear available."))
		return lines
	lines.append(_text(&"ui.base.workbench.repair_list_title", "Repair"))
	for row_value in rows:
		if typeof(row_value) != TYPE_DICTIONARY:
			continue
		var row := row_value as Dictionary
		var row_text_key := &"ui.base.workbench.repair_selected_row_format" if bool(row.get("is_selected", false)) else &"ui.base.workbench.repair_row_format"
		var row_text_fallback := "> [%s] %s %d/%d -> %d/%d - $%d" if bool(row.get("is_selected", false)) else "  [%s] %s %d/%d -> %d/%d - $%d"
		lines.append(_text(row_text_key, row_text_fallback) % [
			str(row.get("source_label", "")),
			str(row.get("item_name", "")),
			int(row.get("current_durability", 0)),
			int(row.get("max_durability", 0)),
			int(row.get("max_after_repair", 0)),
			int(row.get("max_after_repair", 0)),
			int(row.get("repair_cost", 0)),
		])
	return lines


static func _dismantle_lines(state: Dictionary) -> Array[String]:
	var lines: Array[String] = [
		"%s" % _text(&"base_upgrade.workbench_disassemble_station.name", str(DisassembleStationUpgrade.display_name)),
		_text(&"ui.base.workbench.disassemble_station_effect", "Effect: unlocks workbench dismantle mode."),
		_text(&"ui.base.workbench.cost_format", "Cost: %s.") % BaseProgressionScript.describe_cost(DisassembleStationUpgrade),
	]
	if not bool(state.get("dismantle_unlocked", false)):
		lines.append(_text(&"ui.base.workbench.disassemble_station_ready", "Status: materials ready for installation.") if bool(state.get("can_purchase_disassemble_station", false)) else _text(&"ui.base.workbench.status_format", "Status: %s") % _blocked_reason_text(str(state.get("reason", "unknown"))))
		return lines
	lines.append(_text(&"ui.base.workbench.disassemble_station_installed", "Disassemble Station installed."))
	var rows: Array = state.get("dismantle_rows", []) as Array
	if rows.is_empty():
		lines.append(_text(&"ui.base.workbench.dismantle_none", "No dismantle candidates available."))
		return lines
	lines.append(_text(&"ui.base.workbench.dismantle_list_title", "Dismantle"))
	for row_value in rows:
		if typeof(row_value) != TYPE_DICTIONARY:
			continue
		var row := row_value as Dictionary
		var row_text_key := &"ui.base.workbench.dismantle_selected_row_format" if bool(row.get("is_selected", false)) else &"ui.base.workbench.dismantle_row_format"
		var row_text_fallback := "> %s -> %s" if bool(row.get("is_selected", false)) else "  %s -> %s"
		lines.append(_text(row_text_key, row_text_fallback) % [str(row.get("input_name", "")), str(row.get("output_text", ""))])
	return lines


static func _craft_action_text(recipe: Resource) -> String:
	if recipe == null:
		return _text(&"ui.base.workbench.craft_missing", "Missing materials")
	return _text(&"ui.base.workbench.craft_action_format", "Craft %s") % _item_name(str(recipe.get("output_item_path")))


static func _blocked_reason_text(reason: String) -> String:
	match reason:
		"no_recipes":
			return _text(&"ui.base.workbench.recipe_none", "No recipes available.")
		"missing_money":
			return _text(&"ui.base.workbench.blocked_money", "Need more money.")
		"missing_items":
			return _text(&"ui.base.workbench.blocked_items", "Need more materials.")
		"missing_prerequisite":
			return _text(&"ui.base.workbench.blocked_prerequisite", "Requires prerequisite upgrade.")
		"already_owned":
			return _text(&"ui.base.workbench.blocked_owned", "Already upgraded.")
		"invalid_upgrade":
			return _text(&"ui.base.workbench.blocked_invalid", "Upgrade data is invalid.")
		"no_repairable_gear":
			return _text(&"ui.base.workbench.repair_none", "No repairable gear available.")
		"no_dismantle_items":
			return _text(&"ui.base.workbench.dismantle_none", "No dismantle candidates available.")
		"dismantle_locked":
			return _text(&"ui.base.workbench.dismantle_locked", "Disassemble Station is not installed.")
		"stash_full":
			return _text(&"ui.base.workbench.dismantle_stash_full", "Warehouse has no room for dismantle outputs.")
		_:
			return _text(&"ui.base.workbench.blocked_unknown", "Upgrade unavailable.")


static func _recipe_status_text(can_craft: bool) -> String:
	return _text(&"ui.base.workbench.recipe_ready", "Materials ready. Crafting available.") if can_craft else _text(&"ui.base.workbench.recipe_missing", "Missing recipe materials.")


static func _blueprint_status_text(row: Dictionary) -> String:
	if bool(row.get("is_researched", false)):
		return _text(&"ui.base.workbench.blueprint_status_researched", "Researched")
	if not bool(row.get("station_ready", false)):
		return _text(&"ui.base.workbench.blueprint_status_station_locked", "Station locked")
	if bool(row.get("in_stash", false)):
		return _text(&"ui.base.workbench.blueprint_status_ready", "Ready")
	return _text(&"ui.base.workbench.blueprint_status_missing", "Missing blueprint")


static func _item_name(item_path: String) -> String:
	if item_path == "" or not ResourceLoader.exists(item_path):
		return "Unknown"
	var item_def := load(item_path) as ItemDef
	if item_def == null:
		return "Unknown"
	var name_key := str(item_def.name_key)
	if name_key != "":
		var translated := TranslationServer.translate(name_key)
		if translated != name_key and translated != "":
			return translated
	return item_def.display_name if item_def.display_name != "" else str(item_def.id)


static func _text(key: StringName, fallback: String) -> String:
	var key_text := str(key)
	var translated := str(TranslationServer.translate(key_text))
	return fallback if translated == key_text or translated == "" else translated
