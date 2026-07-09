class_name BaseWorkbenchService
extends RefCounted

const BaseProgressionScript := preload("res://scripts/base/base_progression.gd")
const BaseRecipeServiceScript := preload("res://scripts/base/base_recipe_service.gd")
const BaseBlueprintServiceScript := preload("res://scripts/base/base_blueprint_service.gd")
const BaseRepairServiceScript := preload("res://scripts/base/base_repair_service.gd")
const BaseDismantleServiceScript := preload("res://scripts/base/base_dismantle_service.gd")
const BaseWorkbenchDescriptionScript := preload("res://scripts/base/base_workbench_description.gd")
const WorkbenchUpgrade := preload("res://data/base_upgrades/workbench_level_1.tres")
const FixStationUpgrade := preload("res://data/base_upgrades/workbench_fix_station.tres")
const DisassembleStationUpgrade := preload("res://data/base_upgrades/workbench_disassemble_station.tres")

const STATION_MODE_CRAFT := "craft"
const STATION_MODE_BLUEPRINTS := "blueprints"
const STATION_MODE_REPAIR := "repair"
const STATION_MODE_DISMANTLE := "dismantle"


static func get_panel_context(save_manager: Node, selected_station_mode: StringName = &"craft", player: Node = null) -> Dictionary:
	var state := get_state(save_manager, selected_station_mode, player)
	return {
		"body": describe(state),
		"action_visible": true,
		"action_enabled": bool(state.get("action_enabled", false)),
		"action_text": str(state.get("action_text", _text(&"ui.base.workbench.action", "Upgrade Workbench"))),
		"action_mode": str(state.get("action_mode", "upgrade")),
		"selected_station_mode": str(state.get("selected_station_mode", "")),
		"station_modes": state.get("station_modes", []),
		"blueprint_rows": state.get("blueprint_rows", []),
		"can_research_blueprint": bool(state.get("can_research_blueprint", false)),
		"recipe_rows": state.get("recipe_rows", []),
		"selected_recipe_id": str(state.get("selected_recipe_id", "")),
		"repair_rows": state.get("repair_rows", []),
		"selected_repair_id": str(state.get("selected_repair_id", "")),
		"can_repair": bool(state.get("can_repair", false)),
		"repair_unlocked": bool(state.get("repair_unlocked", false)),
		"can_purchase_fix_station": bool(state.get("can_purchase_fix_station", false)),
		"dismantle_rows": state.get("dismantle_rows", []),
		"selected_dismantle_id": str(state.get("selected_dismantle_id", "")),
		"can_dismantle": bool(state.get("can_dismantle", false)),
		"dismantle_unlocked": bool(state.get("dismantle_unlocked", false)),
		"can_purchase_disassemble_station": bool(state.get("can_purchase_disassemble_station", false)),
	}


static func get_state(save_manager: Node, selected_station_mode: StringName = &"craft", player: Node = null) -> Dictionary:
	var save_data := _get_save_data(save_manager)
	if save_data.is_empty():
		return {
			"has_save": false,
			"can_upgrade": false,
			"can_craft": false,
			"is_purchased": false,
			"reason": "no_save",
			"action_mode": "upgrade",
			"selected_station_mode": "",
			"station_modes": [],
			"action_enabled": false,
			"action_text": _text(&"ui.base.workbench.action", "Upgrade Workbench"),
		}

	var is_purchased := BaseProgressionScript.is_upgrade_purchased(save_data, WorkbenchUpgrade.id)
	var repair_unlocked := is_purchased and BaseProgressionScript.is_upgrade_purchased(save_data, FixStationUpgrade.id)
	var dismantle_unlocked := is_purchased and BaseProgressionScript.is_upgrade_purchased(save_data, DisassembleStationUpgrade.id)
	var check: Dictionary = BaseProgressionScript.can_purchase_upgrade(save_data, WorkbenchUpgrade)
	var fix_station_check: Dictionary = BaseProgressionScript.can_purchase_upgrade(save_data, FixStationUpgrade) if is_purchased else {"can_purchase": false, "reason": "missing_prerequisite"}
	var disassemble_station_check: Dictionary = BaseProgressionScript.can_purchase_upgrade(save_data, DisassembleStationUpgrade) if is_purchased else {"can_purchase": false, "reason": "missing_prerequisite"}
	var recipe_rows := BaseRecipeServiceScript.get_recipe_rows(save_data, &"workbench")
	var selected_recipe := BaseRecipeServiceScript.get_selected_recipe(save_data, &"workbench")
	var blueprint_state := BaseBlueprintServiceScript.get_state_from_save_data(save_data, &"workbench") if is_purchased else {}
	var repair_state := BaseRepairServiceScript.get_state_from_save_data(save_data, &"workbench", player) if repair_unlocked else {}
	var dismantle_state := BaseDismantleServiceScript.get_state_from_save_data(save_data, &"workbench") if dismantle_unlocked else {}
	var blueprint_rows: Array = blueprint_state.get("blueprint_rows", []) as Array
	var repair_rows: Array = repair_state.get("repair_rows", []) as Array
	var dismantle_rows: Array = dismantle_state.get("dismantle_rows", []) as Array
	var can_craft := is_purchased and selected_recipe != null and BaseRecipeServiceScript.can_craft_recipe(save_data, selected_recipe)
	var station_mode := _normalized_station_mode(selected_station_mode, is_purchased)
	var is_blueprint_mode := station_mode == STATION_MODE_BLUEPRINTS
	var is_repair_mode := station_mode == STATION_MODE_REPAIR
	var is_dismantle_mode := station_mode == STATION_MODE_DISMANTLE
	var can_research_blueprint := bool(blueprint_state.get("can_research", false)) if is_purchased else false
	var can_repair := bool(repair_state.get("can_repair", false)) if repair_unlocked else false
	var can_dismantle := bool(dismantle_state.get("can_dismantle", false)) if dismantle_unlocked else false
	var action_mode := _action_mode(is_purchased, is_blueprint_mode, is_repair_mode, repair_unlocked, is_dismantle_mode, dismantle_unlocked)
	var action_enabled := _action_enabled(action_mode, can_craft, can_research_blueprint, can_repair, can_dismantle, check, fix_station_check, disassemble_station_check)
	return {
		"has_save": true,
		"can_upgrade": bool(check.get("can_purchase", false)),
		"can_purchase_fix_station": bool(fix_station_check.get("can_purchase", false)),
		"can_purchase_disassemble_station": bool(disassemble_station_check.get("can_purchase", false)),
		"can_craft": can_craft,
		"has_recipes": not recipe_rows.is_empty(),
		"is_purchased": is_purchased,
		"repair_unlocked": repair_unlocked,
		"dismantle_unlocked": dismantle_unlocked,
		"reason": _state_reason(is_purchased, is_blueprint_mode, is_repair_mode, repair_unlocked, is_dismantle_mode, dismantle_unlocked, recipe_rows, selected_recipe, can_craft, check, fix_station_check, disassemble_station_check, repair_state, dismantle_state),
		"action_mode": action_mode,
		"selected_station_mode": station_mode,
		"station_modes": _station_modes(is_purchased, station_mode, not blueprint_rows.is_empty(), repair_unlocked, dismantle_unlocked),
		"blueprint_rows": blueprint_rows,
		"can_research_blueprint": can_research_blueprint,
		"repair_rows": repair_rows,
		"selected_repair_id": str(repair_state.get("selected_repair_id", "")),
		"can_repair": can_repair,
		"dismantle_rows": dismantle_rows,
		"selected_dismantle_id": str(dismantle_state.get("selected_dismantle_id", "")),
		"can_dismantle": can_dismantle,
		"action_enabled": action_enabled,
		"craft_recipe_id": str(selected_recipe.get("id")) if selected_recipe != null else "",
		"selected_recipe_id": str(selected_recipe.get("id")) if selected_recipe != null else "",
		"recipe_rows": [] if is_blueprint_mode or is_repair_mode or is_dismantle_mode else recipe_rows,
		"save_data": save_data,
		"action_text": BaseWorkbenchDescriptionScript.action_text(action_mode, selected_recipe, can_craft, can_research_blueprint, repair_state, dismantle_state),
	}


static func execute_action(save_manager: Node, selected_station_mode: StringName = &"craft", player: Node = null) -> Dictionary:
	var state := get_state(save_manager, selected_station_mode, player)
	match str(state.get("action_mode", "upgrade")):
		"craft":
			return craft_selected(save_manager)
		"blueprint_research":
			return research_first_blueprint(save_manager)
		"fix_station_upgrade":
			return purchase_fix_station(save_manager)
		"repair":
			return repair_selected(save_manager, player)
		"disassemble_station_upgrade":
			return purchase_disassemble_station(save_manager)
		"dismantle":
			return dismantle_selected(save_manager)
	return purchase(save_manager)


static func research_first_blueprint(save_manager: Node) -> Dictionary:
	var result: Dictionary = BaseBlueprintServiceScript.research_first_available(save_manager, &"workbench")
	result["action_type"] = "blueprint_research"
	return result


static func research_blueprint(save_manager: Node, blueprint_item_path: String) -> Dictionary:
	var result: Dictionary = BaseBlueprintServiceScript.research_blueprint(save_manager, blueprint_item_path, &"workbench")
	result["action_type"] = "blueprint_research"
	return result


static func craft_selected(save_manager: Node) -> Dictionary:
	var save_data := _get_save_data(save_manager)
	if save_data.is_empty():
		return {"success": false, "reason": "no_save", "action_type": "craft"}
	var result: Dictionary = BaseRecipeServiceScript.craft_selected(save_manager, &"workbench")
	result["action_type"] = "craft"
	return result


static func select_recipe(save_manager: Node, recipe_id: StringName) -> Dictionary:
	return BaseRecipeServiceScript.select_recipe(save_manager, &"workbench", recipe_id)


static func select_repair_item(save_manager: Node, repair_id: StringName, player: Node = null) -> Dictionary:
	return BaseRepairServiceScript.select_repair_item(save_manager, &"workbench", repair_id, player)


static func repair_selected(save_manager: Node, player: Node = null) -> Dictionary:
	return BaseRepairServiceScript.repair_selected(save_manager, &"workbench", player)


static func select_dismantle_item(save_manager: Node, dismantle_id: StringName) -> Dictionary:
	return BaseDismantleServiceScript.select_dismantle_item(save_manager, &"workbench", dismantle_id)


static func dismantle_selected(save_manager: Node) -> Dictionary:
	return BaseDismantleServiceScript.dismantle_selected(save_manager, &"workbench")


static func get_next_upgrade_for_save_data(save_data: Dictionary) -> Resource:
	if save_data.is_empty():
		return null
	if BaseProgressionScript.is_upgrade_purchased(save_data, WorkbenchUpgrade.id):
		if not BaseProgressionScript.is_upgrade_purchased(save_data, FixStationUpgrade.id):
			return FixStationUpgrade
		if not BaseProgressionScript.is_upgrade_purchased(save_data, DisassembleStationUpgrade.id):
			return DisassembleStationUpgrade
		return null
	return WorkbenchUpgrade


static func describe(state: Dictionary) -> String:
	return BaseWorkbenchDescriptionScript.describe(state)


static func _action_mode(is_purchased: bool, is_blueprint_mode: bool, is_repair_mode: bool, repair_unlocked: bool, is_dismantle_mode: bool, dismantle_unlocked: bool) -> String:
	if not is_purchased:
		return "upgrade"
	if is_blueprint_mode:
		return "blueprint_research"
	if is_repair_mode:
		return "repair" if repair_unlocked else "fix_station_upgrade"
	if is_dismantle_mode:
		return "dismantle" if dismantle_unlocked else "disassemble_station_upgrade"
	return "craft"


static func _action_enabled(action_mode: String, can_craft: bool, can_research_blueprint: bool, can_repair: bool, can_dismantle: bool, workbench_check: Dictionary, fix_station_check: Dictionary, disassemble_station_check: Dictionary) -> bool:
	match action_mode:
		"craft":
			return can_craft
		"blueprint_research":
			return can_research_blueprint
		"fix_station_upgrade":
			return bool(fix_station_check.get("can_purchase", false))
		"repair":
			return can_repair
		"disassemble_station_upgrade":
			return bool(disassemble_station_check.get("can_purchase", false))
		"dismantle":
			return can_dismantle
		_:
			return bool(workbench_check.get("can_purchase", false))


static func _station_modes(is_purchased: bool, selected_station_mode: String, has_blueprint_rows: bool = false, repair_unlocked: bool = false, dismantle_unlocked: bool = false) -> Array[Dictionary]:
	if not is_purchased:
		return []
	return [
		{
			"id": STATION_MODE_CRAFT,
			"label": _text(&"ui.base.workbench.mode_craft", "Craft"),
			"is_selected": selected_station_mode == STATION_MODE_CRAFT,
			"enabled": true,
		},
		{
			"id": STATION_MODE_BLUEPRINTS,
			"label": _text(&"ui.base.workbench.mode_blueprints", "Blueprints"),
			"is_selected": selected_station_mode == STATION_MODE_BLUEPRINTS,
			"enabled": true,
			"has_data": has_blueprint_rows,
		},
		{
			"id": STATION_MODE_REPAIR,
			"label": _text(&"ui.base.workbench.mode_repair", "Repair"),
			"is_selected": selected_station_mode == STATION_MODE_REPAIR,
			"enabled": true,
			"has_data": repair_unlocked,
		},
		{
			"id": STATION_MODE_DISMANTLE,
			"label": _text(&"ui.base.workbench.mode_dismantle", "Dismantle"),
			"is_selected": selected_station_mode == STATION_MODE_DISMANTLE,
			"enabled": true,
			"has_data": dismantle_unlocked,
		},
	]


static func _normalized_station_mode(selected_station_mode: StringName, is_purchased: bool) -> String:
	if not is_purchased:
		return ""
	match str(selected_station_mode):
		STATION_MODE_BLUEPRINTS:
			return STATION_MODE_BLUEPRINTS
		STATION_MODE_REPAIR:
			return STATION_MODE_REPAIR
		STATION_MODE_DISMANTLE:
			return STATION_MODE_DISMANTLE
		_:
			return STATION_MODE_CRAFT


static func _state_reason(is_purchased: bool, is_blueprint_mode: bool, is_repair_mode: bool, repair_unlocked: bool, is_dismantle_mode: bool, dismantle_unlocked: bool, recipe_rows: Array, selected_recipe: Resource, can_craft: bool, workbench_check: Dictionary, fix_station_check: Dictionary, disassemble_station_check: Dictionary, repair_state: Dictionary = {}, dismantle_state: Dictionary = {}) -> String:
	if not is_purchased:
		return str(workbench_check.get("reason", "unknown"))
	if is_blueprint_mode:
		return "ok"
	if is_repair_mode:
		return str(repair_state.get("reason", "no_repairable_gear")) if repair_unlocked else str(fix_station_check.get("reason", "unknown"))
	if is_dismantle_mode:
		return str(dismantle_state.get("reason", "no_dismantle_items")) if dismantle_unlocked else str(disassemble_station_check.get("reason", "unknown"))
	return _craft_reason(recipe_rows, selected_recipe, can_craft)


static func _craft_reason(recipe_rows: Array, selected_recipe: Resource, can_craft: bool) -> String:
	if recipe_rows.is_empty():
		return "no_recipes"
	if selected_recipe == null:
		return "no_recipes"
	return "ready" if can_craft else "missing_items"


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
	var translated := str(TranslationServer.translate(key_text))
	return fallback if translated == key_text or translated == "" else translated


static func purchase(save_manager: Node) -> Dictionary:
	return _purchase_upgrade(save_manager, WorkbenchUpgrade, "upgrade")


static func purchase_fix_station(save_manager: Node) -> Dictionary:
	return _purchase_upgrade(save_manager, FixStationUpgrade, "fix_station_upgrade")


static func purchase_disassemble_station(save_manager: Node) -> Dictionary:
	return _purchase_upgrade(save_manager, DisassembleStationUpgrade, "disassemble_station_upgrade")


static func _purchase_upgrade(save_manager: Node, upgrade_def: Resource, action_type: String) -> Dictionary:
	var save_data := _get_save_data(save_manager)
	if save_data.is_empty():
		return {"success": false, "reason": "no_save", "action_type": action_type}
	var result: Dictionary = BaseProgressionScript.purchase_upgrade(save_data, upgrade_def)
	result["action_type"] = action_type
	if not bool(result.get("success", false)):
		return result
	var slot_index := _current_slot_index(save_manager)
	if save_manager == null or not save_manager.has_method("save_slot_data"):
		return {"success": false, "reason": "missing_save_manager", "action_type": action_type}
	if not bool(save_manager.call("save_slot_data", slot_index, result.get("save_data", {}) as Dictionary)):
		return {"success": false, "reason": "save_failed", "action_type": action_type}
	return result


static func craft_first_available(save_manager: Node) -> Dictionary:
	var save_data := _get_save_data(save_manager)
	if save_data.is_empty():
		return {"success": false, "reason": "no_save", "action_type": "craft"}
	var recipe := BaseRecipeServiceScript.get_first_craftable_recipe(save_data, &"workbench")
	if recipe == null:
		return {"success": false, "reason": "missing_items", "action_type": "craft", "save_data": save_data}
	var result: Dictionary = BaseRecipeServiceScript.craft(save_manager, StringName(str(recipe.get("id"))))
	result["action_type"] = "craft"
	return result
