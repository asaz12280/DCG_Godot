class_name BaseInteractionPanelViewModel
extends RefCounted


static func recipe_button_text(row: Dictionary, text_provider: Callable) -> String:
	var prefix := "> " if bool(row.get("is_selected", false)) else "  "
	var status: String = text_provider.call(&"ui.base.workbench.recipe_ready_short", "Ready") if bool(row.get("can_craft", false)) else text_provider.call(&"ui.base.workbench.recipe_missing_short", "Missing")
	return "%s%s x%d - %s" % [prefix, str(row.get("output_name", "")), int(row.get("output_quantity", 0)), status]


static func blueprint_button_text(row: Dictionary, text_provider: Callable) -> String:
	return "%s -> %s - %s" % [
		str(row.get("blueprint_name", "")),
		str(row.get("recipe_name", "")),
		blueprint_status_text(row, text_provider),
	]


static func repair_button_text(row: Dictionary, text_provider: Callable) -> String:
	var prefix := "> " if bool(row.get("is_selected", false)) else "  "
	var status: String = text_provider.call(&"ui.base.workbench.repair_ready_short", "Ready") if bool(row.get("can_repair", false)) else text_provider.call(&"ui.base.workbench.repair_missing_money_short", "Need money")
	return "%s[%s] %s %d/%d -> %d/%d - $%d - %s" % [
		prefix,
		str(row.get("source_label", "")),
		str(row.get("item_name", "")),
		int(row.get("current_durability", 0)),
		int(row.get("max_durability", 0)),
		int(row.get("max_after_repair", 0)),
		int(row.get("max_after_repair", 0)),
		int(row.get("repair_cost", 0)),
		status,
	]


static func dismantle_button_text(row: Dictionary, text_provider: Callable) -> String:
	var prefix := "> " if bool(row.get("is_selected", false)) else "  "
	var status: String = text_provider.call(&"ui.base.workbench.dismantle_ready_short", "Ready") if bool(row.get("can_dismantle", false)) else text_provider.call(&"ui.base.workbench.dismantle_stash_full_short", "No room")
	return "%s%s -> %s - %s" % [prefix, str(row.get("input_name", "")), str(row.get("output_text", "")), status]


static func blueprint_status_text(row: Dictionary, text_provider: Callable) -> String:
	if bool(row.get("is_researched", false)):
		return text_provider.call(&"ui.base.workbench.blueprint_status_researched", "Researched")
	if not bool(row.get("station_ready", false)):
		return text_provider.call(&"ui.base.workbench.blueprint_status_station_locked", "Station locked")
	if bool(row.get("in_stash", false)):
		return text_provider.call(&"ui.base.workbench.blueprint_status_ready", "Ready")
	return text_provider.call(&"ui.base.workbench.blueprint_status_missing", "Missing blueprint")


static func mode_button_text(row: Dictionary) -> String:
	var prefix := "> " if bool(row.get("is_selected", false)) else ""
	return "%s%s" % [prefix, str(row.get("label", ""))]


static func mode_button_states(mode_tabs: HBoxContainer) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	if mode_tabs == null:
		return states
	for child in mode_tabs.get_children():
		var button := child as Button
		if button == null:
			continue
		states.append({
			"mode_id": str(button.get_meta("mode_id", "")),
			"text": button.text,
			"selected": bool(button.get_meta("selected", false)),
			"enabled": bool(button.get_meta("enabled", false)),
			"has_data": bool(button.get_meta("has_data", false)),
			"disabled": button.disabled,
			"rect": Rect2(button.global_position, button.size),
		})
	return states


static func button_states(recipe_list: VBoxContainer, row_type: String) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	if recipe_list == null:
		return states
	for child in recipe_list.get_children():
		var button := child as Button
		if button == null or str(button.get_meta("row_type", "recipe")) != row_type:
			continue
		states.append(_button_state(button, row_type))
	return states


static func _button_state(button: Button, row_type: String) -> Dictionary:
	var state := {
		"text": button.text,
		"disabled": button.disabled,
		"rect": Rect2(button.global_position, button.size),
	}
	match row_type:
		"blueprint":
			state.merge({
				"blueprint_item_path": str(button.get_meta("blueprint_item_path", "")),
				"can_research": bool(button.get_meta("can_research", false)),
				"is_researched": bool(button.get_meta("is_researched", false)),
			})
		"repair":
			state.merge({
				"repair_id": str(button.get_meta("repair_id", "")),
				"selected": bool(button.get_meta("selected", false)),
				"can_repair": bool(button.get_meta("can_repair", false)),
				"repair_cost": int(button.get_meta("repair_cost", 0)),
				"source_label": str(button.get_meta("source_label", "")),
			})
		"dismantle":
			state.merge({
				"dismantle_id": str(button.get_meta("dismantle_id", "")),
				"selected": bool(button.get_meta("selected", false)),
				"can_dismantle": bool(button.get_meta("can_dismantle", false)),
				"output_text": str(button.get_meta("output_text", "")),
			})
		_:
			state.erase("disabled")
			state.merge({
				"recipe_id": str(button.get_meta("recipe_id", "")),
				"selected": bool(button.get_meta("selected", false)),
				"can_craft": bool(button.get_meta("can_craft", false)),
			})
	return state
