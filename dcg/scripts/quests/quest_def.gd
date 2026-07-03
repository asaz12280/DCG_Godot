class_name QuestDef
extends Resource

const OBJECTIVE_COLLECT := "collect"
const OBJECTIVE_EXTRACT := "extract"
const OBJECTIVE_EXTRACT_ANY := "extract_any"
const OBJECTIVE_KILL := "kill"
const OBJECTIVE_LOCATION := "location"

@export var id: StringName = &""
@export var display_name := ""
@export var description := ""
@export_enum("collect", "extract", "extract_any", "kill", "location") var objective_type := OBJECTIVE_COLLECT
@export var objectives: Array[Dictionary] = []
@export_range(0, 999999, 1) var reward_money := 0
@export var reward_items: Array[Dictionary] = []


func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if id == &"":
		errors.append("QuestDef requires id.")
	if display_name == "":
		errors.append("QuestDef requires display_name.")
	if description == "":
		errors.append("QuestDef requires description.")
	if not [OBJECTIVE_COLLECT, OBJECTIVE_EXTRACT, OBJECTIVE_EXTRACT_ANY, OBJECTIVE_KILL, OBJECTIVE_LOCATION].has(objective_type):
		errors.append("QuestDef objective_type is unsupported.")
	if objectives.is_empty():
		errors.append("QuestDef requires at least one objective entry.")
	for index in range(objectives.size()):
		match objective_type:
			OBJECTIVE_KILL:
				_validate_enemy_quantity_entry(objectives[index], index, "objective", errors)
			OBJECTIVE_LOCATION:
				_validate_location_quantity_entry(objectives[index], index, "objective", errors)
			_:
				_validate_item_quantity_entry(objectives[index], index, "objective", errors)
	for index in range(reward_items.size()):
		_validate_item_quantity_entry(reward_items[index], index, "reward", errors)
	if reward_money <= 0 and reward_items.is_empty():
		errors.append("QuestDef requires money or item reward.")
	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()


func get_required_quantity(item_path: String) -> int:
	var total := 0
	for objective in objectives:
		if str(objective.get("item_path", "")) == item_path:
			total += int(objective.get("quantity", 0))
	return total


func get_required_kill_quantity(enemy_id: String) -> int:
	var total := 0
	for objective in objectives:
		if str(objective.get("enemy_id", "")) == enemy_id:
			total += int(objective.get("quantity", 0))
	return total


func get_required_location_quantity(location_id: String) -> int:
	var total := 0
	for objective in objectives:
		if str(objective.get("location_id", "")) == location_id:
			total += int(objective.get("quantity", 0))
	return total


func _validate_item_quantity_entry(entry: Dictionary, index: int, label: String, errors: Array[String]) -> void:
	var item_path := str(entry.get("item_path", ""))
	var quantity := int(entry.get("quantity", 0))
	if item_path == "" or not ResourceLoader.exists(item_path):
		errors.append("QuestDef %s %d has invalid item_path." % [label, index])
	if quantity <= 0:
		errors.append("QuestDef %s %d requires positive quantity." % [label, index])


func _validate_enemy_quantity_entry(entry: Dictionary, index: int, label: String, errors: Array[String]) -> void:
	var enemy_id := str(entry.get("enemy_id", ""))
	var quantity := int(entry.get("quantity", 0))
	if enemy_id == "":
		errors.append("QuestDef %s %d has invalid enemy_id." % [label, index])
	if quantity <= 0:
		errors.append("QuestDef %s %d requires positive quantity." % [label, index])


func _validate_location_quantity_entry(entry: Dictionary, index: int, label: String, errors: Array[String]) -> void:
	var location_id := str(entry.get("location_id", ""))
	var quantity := int(entry.get("quantity", 0))
	if location_id == "":
		errors.append("QuestDef %s %d has invalid location_id." % [label, index])
	if quantity <= 0:
		errors.append("QuestDef %s %d requires positive quantity." % [label, index])
