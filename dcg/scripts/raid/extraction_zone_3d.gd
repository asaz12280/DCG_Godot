class_name ExtractionZone3D
extends Area3D

signal extraction_started(body: Node3D)
signal extraction_progress(progress: float, remaining_time: float)
signal extraction_cancelled(body: Node3D)
signal extraction_completed(body: Node3D)

@export_range(0.25, 30.0, 0.25) var required_time := 3.0
@export var player_group := "player"
@export var raid_session_path: NodePath = NodePath("../../RaidSession")

var _tracked_player: Node3D
var _elapsed := 0.0
var _completed := false

@onready var _prompt_label := get_node_or_null("PromptLabel") as Label3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_process(false)
	_update_prompt()


func _process(delta: float) -> void:
	if _tracked_player == null or _completed:
		return
	_elapsed = minf(_elapsed + delta, required_time)
	var remaining_time: float = maxf(required_time - _elapsed, 0.0)
	extraction_progress.emit(get_progress(), remaining_time)
	_update_prompt()
	if _elapsed >= required_time:
		_complete_extraction()


func get_progress() -> float:
	if required_time <= 0.0:
		return 1.0
	return clampf(_elapsed / required_time, 0.0, 1.0)


func get_state() -> Dictionary:
	return {
		"active": _tracked_player != null and not _completed,
		"completed": _completed,
		"elapsed_time": _elapsed,
		"required_time": required_time,
		"progress": get_progress(),
	}


func cancel_extraction() -> void:
	if _tracked_player == null:
		return
	var cancelled_player := _tracked_player
	_tracked_player = null
	_elapsed = 0.0
	set_process(false)
	_update_prompt()
	extraction_cancelled.emit(cancelled_player)


func _on_body_entered(body: Node3D) -> void:
	if _completed or _tracked_player != null or not _is_player_body(body):
		return
	_tracked_player = body
	_elapsed = 0.0
	set_process(true)
	_update_prompt()
	extraction_started.emit(body)


func _on_body_exited(body: Node3D) -> void:
	if body == _tracked_player and not _completed:
		cancel_extraction()


func _complete_extraction() -> void:
	var session := _find_raid_session()
	if session == null or not session.has_method("register_extraction"):
		return
	var context := {
		"source": "extraction_zone",
		"zone_path": str(get_path()) if is_inside_tree() else name,
		"extracted_items": _collect_player_carried_items(_tracked_player),
	}
	if not bool(session.call("register_extraction", context)):
		return
	_completed = true
	set_process(false)
	_update_prompt()
	extraction_completed.emit(_tracked_player)


func _find_raid_session() -> Node:
	if raid_session_path != NodePath(""):
		var direct_session := get_node_or_null(raid_session_path)
		if direct_session != null:
			return direct_session
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene.get_node_or_null("RaidSession")
	return null


func _is_player_body(body: Node3D) -> bool:
	return body.name == "Player3D" or body.is_in_group(player_group) or body.has_method("get_inventory_model")


func _collect_player_carried_items(player: Node) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	items.append_array(_collect_inventory_model(player.call("get_inventory_model") if player != null and player.has_method("get_inventory_model") else null))
	items.append_array(_collect_inventory_model(player.call("get_safe_pocket_model") if player != null and player.has_method("get_safe_pocket_model") else null))
	items.append_array(_collect_equipment_model(player.call("get_equipment_model") if player != null and player.has_method("get_equipment_model") else null))
	return items


func _collect_player_inventory(player: Node) -> Array[Dictionary]:
	return _collect_player_carried_items(player)


func _collect_inventory_model(inventory: Variant) -> Array[Dictionary]:
	if inventory == null or not inventory.has_method("get_display_items"):
		return []
	return _normalize_stack_list(inventory.get_display_items())


func _collect_equipment_model(equipment: Variant) -> Array[Dictionary]:
	if equipment == null or not equipment.has_method("get_slots"):
		return []
	var stacks: Array[Dictionary] = []
	var slots: Dictionary = equipment.call("get_slots")
	for stack in slots.values():
		if typeof(stack) == TYPE_DICTIONARY:
			stacks.append((stack as Dictionary).duplicate(true))
	return _normalize_stack_list(stacks)


func _normalize_stack_list(stacks: Variant) -> Array[Dictionary]:
	if typeof(stacks) != TYPE_ARRAY:
		return []
	var items: Array[Dictionary] = []
	for stack in stacks as Array:
		if typeof(stack) != TYPE_DICTIONARY:
			continue
		var item_path := str(stack.get("resource_path", stack.get("item_path", "")))
		var quantity := int(stack.get("quantity", 1))
		if item_path == "" or quantity <= 0:
			continue
		items.append({
			"item_path": item_path,
			"quantity": quantity,
		})
	return items


func _update_prompt() -> void:
	if _prompt_label == null:
		return
	if _completed:
		_prompt_label.text = _localized_text(&"prompt.extracted", "已撤離")
	elif _tracked_player != null:
		_prompt_label.text = _localized_text(&"prompt.extracting_format", "撤離中 %.1f 秒") % maxf(required_time - _elapsed, 0.0)
	else:
		_prompt_label.text = _localized_text(&"prompt.extraction_point", "撤離點")


func _localized_text(key: StringName, fallback: String) -> String:
	var key_text := str(key)
	if key_text == "":
		return fallback
	var translated := tr(key_text)
	return fallback if translated == key_text or translated == "" else translated
