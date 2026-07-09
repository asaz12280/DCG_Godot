class_name LootContainer3D
extends Area3D

signal opened(rolled_stacks: Array[Dictionary])
signal open_requested(container: LootContainer3D)
signal open_blocked(reason: StringName, message: String)

const ContainerInventoryModelScript := preload("res://scripts/inventory/container_inventory_model.gd")

@export var loot_table: Resource
@export_range(1, 12, 1) var roll_count := 1
@export_range(1, 24, 1) var container_capacity := 4
@export var interact_keycode := KEY_E
@export var body_color := Color(0.38, 0.31, 0.22, 1.0)
@export var lid_color := Color(0.24, 0.34, 0.31, 1.0)
@export var prompt_color := Color(1.0, 0.95, 0.55, 1.0)
@export var one_shot := true
@export var is_locked := false
@export var required_key: ItemDef
@export_range(0.0, 10.0, 0.1) var locked_open_duration_seconds := 2.0
@export var display_name_key: StringName = &"ui.container.default_name"
@export var display_name := "物資箱"
@export var prompt_key: StringName = &"prompt.open_container"
@export var prompt_text := "按 E 開啟箱子"
@export var opened_prompt_key: StringName = &"prompt.view_container"
@export var opened_prompt_text := "按 E 查看箱子"
@export var locked_prompt_key: StringName = &"prompt.locked_container"
@export var locked_prompt_text := "需要鑰匙"
@export var unlocked_prompt_key: StringName = &"prompt.open_locked_container"
@export var unlocked_prompt_text := "按 E 開啟上鎖箱"
@export var missing_key_feedback_key: StringName = &"prompt.missing_warehouse_key"
@export var missing_key_feedback := "需要倉庫鑰匙"
@export var opening_feedback_key: StringName = &"prompt.opening_locked_container_format"
@export var opening_feedback := "開啟中 %d%%"

var has_opened := false
var has_contents := false
var container_inventory: RefCounted = ContainerInventoryModelScript.new()

var _player_in_range: Node3D
var _prompt_label: Label3D
var _progress_label: Label3D
var _last_blocked_message := ""
var _opening_player: Node = null
var _open_elapsed := 0.0


func _ready() -> void:
	add_to_group("loot_container")
	set_process(false)
	container_inventory.setup(container_capacity)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_prompt_label = find_child("PromptLabel", true, false) as Label3D
	_progress_label = find_child("OpenProgressLabel", true, false) as Label3D
	_apply_visual_colors()
	_update_prompt()
	_update_open_progress()


func _process(delta: float) -> void:
	if not _is_opening():
		return
	_open_elapsed += maxf(delta, 0.0)
	_update_open_progress()
	if _open_elapsed >= locked_open_duration_seconds:
		var player := _opening_player
		_cancel_timed_unlock(false)
		_open_now(player, true)


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range == null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == interact_keycode:
		if try_open(_player_in_range):
			get_viewport().set_input_as_handled()


func try_open(player: Node) -> bool:
	if player == null:
		return false
	if _is_opening():
		return true
	if not _can_open_locked_container(player):
		_last_blocked_message = _lock_message()
		_update_prompt()
		open_blocked.emit(&"missing_key", _last_blocked_message)
		return false
	if _needs_timed_unlock():
		_start_timed_unlock(player)
		return true
	var should_consume_key := is_locked and not has_opened and required_key != null
	return _open_now(player, should_consume_key)


func get_state() -> Dictionary:
	return {
		"has_opened": has_opened,
		"player_in_range": _player_in_range != null,
		"has_loot_table": loot_table != null,
		"roll_count": roll_count,
		"container_capacity": container_inventory.get_capacity(),
		"container_used_slots": container_inventory.get_used_slots(),
		"is_locked": is_locked,
		"requires_key": required_key != null,
		"required_key_id": str(required_key.id) if required_key != null else "",
		"required_key_name": _item_display_name(required_key),
		"can_unlock": _can_open_locked_container(_player_in_range),
		"last_blocked_message": _last_blocked_message,
		"is_opening": _is_opening(),
		"open_progress": _open_progress_ratio(),
		"locked_open_duration_seconds": locked_open_duration_seconds,
	}


func get_container_inventory_model() -> RefCounted:
	return container_inventory


func get_container_display_name() -> String:
	return _localized_text(display_name_key, display_name)


func load_static_contents(stacks: Array[Dictionary]) -> bool:
	container_inventory.setup(maxi(container_capacity, stacks.size()))
	container_inventory.clear()
	var stored_any := false
	for stack in stacks:
		if container_inventory.add_stack(stack):
			stored_any = true
	has_contents = stored_any
	has_opened = false
	_cancel_timed_unlock()
	_update_prompt()
	return stored_any


func _open_now(player: Node, should_consume_key: bool) -> bool:
	if player == null:
		return false
	if not _ensure_container_contents():
		return false
	if should_consume_key and required_key != null and not _consume_player_key(player, required_key):
		_last_blocked_message = _lock_message()
		_update_prompt()
		_update_open_progress()
		open_blocked.emit(&"missing_key", _last_blocked_message)
		return false
	_last_blocked_message = ""
	has_opened = true
	_update_prompt()
	_update_open_progress()
	var ui_manager := get_node_or_null("/root/UIManager") if is_inside_tree() else null
	if ui_manager != null and ui_manager.has_method("open_container_inventory"):
		ui_manager.call("open_container_inventory", self)
	open_requested.emit(self)
	return true


func _ensure_container_contents() -> bool:
	if has_contents:
		return true
	if loot_table == null or not loot_table.has_method("roll"):
		return false
	if loot_table.has_method("is_valid") and not loot_table.is_valid():
		return false

	var rolled_stacks: Array[Dictionary] = loot_table.roll(roll_count)
	if rolled_stacks.is_empty():
		return false

	var stored_any := false
	for stack in rolled_stacks:
		if container_inventory.add_stack(stack):
			stored_any = true
	if not stored_any:
		return false

	has_contents = true
	opened.emit(rolled_stacks)
	return true


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in_range = body
		_update_prompt()


func _on_body_exited(body: Node3D) -> void:
	if body == _player_in_range:
		_cancel_timed_unlock()
		_player_in_range = null
		_update_prompt()


func _update_prompt() -> void:
	if _prompt_label == null:
		return
	_prompt_label.visible = _player_in_range != null
	if _is_opening():
		_prompt_label.text = _localized_text(opening_feedback_key, opening_feedback) % int(round(_open_progress_ratio() * 100.0))
		return
	var prompt := _localized_text(prompt_key, prompt_text)
	if is_locked and not has_opened:
		if _player_in_range != null and not _can_open_locked_container(_player_in_range):
			_prompt_label.text = _lock_message()
		else:
			_prompt_label.text = _localized_text(unlocked_prompt_key, unlocked_prompt_text)
		return
	_prompt_label.text = _localized_text(opened_prompt_key, opened_prompt_text) if has_opened else prompt


func _apply_visual_colors() -> void:
	_apply_mesh_color("CrateBody", body_color)
	_apply_mesh_color("CrateLid", lid_color)
	if _prompt_label != null:
		_prompt_label.modulate = prompt_color
	if _progress_label != null:
		_progress_label.modulate = prompt_color


func _apply_mesh_color(node_name: String, color: Color) -> void:
	var mesh_instance := find_child(node_name, true, false) as MeshInstance3D
	if mesh_instance == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	mesh_instance.set_surface_override_material(0, material)


func _needs_timed_unlock() -> bool:
	return is_locked and not has_opened and locked_open_duration_seconds > 0.0


func _start_timed_unlock(player: Node) -> void:
	_opening_player = player
	_open_elapsed = 0.0
	_last_blocked_message = ""
	set_process(true)
	_update_prompt()
	_update_open_progress()


func _cancel_timed_unlock(update_visuals: bool = true) -> void:
	_opening_player = null
	_open_elapsed = 0.0
	set_process(false)
	if update_visuals:
		_update_open_progress()


func _is_opening() -> bool:
	return _opening_player != null


func _open_progress_ratio() -> float:
	if not _is_opening() or locked_open_duration_seconds <= 0.0:
		return 0.0
	return clampf(_open_elapsed / locked_open_duration_seconds, 0.0, 1.0)


func _update_open_progress() -> void:
	if _progress_label == null:
		return
	if not _is_opening():
		_progress_label.visible = false
		_progress_label.text = ""
		return
	var ratio := _open_progress_ratio()
	var percent := int(round(ratio * 100.0))
	var filled := clampi(int(floor(ratio * 10.0)), 0, 10)
	var bar := "[%s%s]" % ["#".repeat(filled), ".".repeat(10 - filled)]
	_progress_label.visible = true
	_progress_label.text = "%s %s" % [_localized_text(opening_feedback_key, opening_feedback) % percent, bar]


func _can_open_locked_container(player: Node) -> bool:
	if not is_locked or has_opened:
		return true
	if required_key == null or player == null:
		return false
	return _player_has_key(player, required_key)


func _player_has_key(player: Node, key_item: ItemDef) -> bool:
	var inventory: Variant = _player_inventory(player)
	if inventory == null or not inventory.has_method("get_display_items"):
		return false
	var stacks: Array = inventory.call("get_display_items")
	for value in stacks:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		if _stack_matches_key(value as Dictionary, key_item):
			return true
	return false


func _consume_player_key(player: Node, key_item: ItemDef) -> bool:
	var inventory: Variant = _player_inventory(player)
	if inventory == null:
		return false
	if inventory.has_method("consume_item"):
		return int(inventory.call("consume_item", key_item, 1)) == 1
	if not inventory.has_method("get_display_items") or not inventory.has_method("consume_stack_quantity"):
		return false
	var stacks: Array = inventory.call("get_display_items")
	for index in range(stacks.size()):
		var value: Variant = stacks[index]
		if typeof(value) != TYPE_DICTIONARY:
			continue
		if _stack_matches_key(value as Dictionary, key_item):
			return int(inventory.call("consume_stack_quantity", index, 1)) == 1
	return false


func _player_inventory(player: Node) -> Variant:
	var inventory_method := StringName("get_" + "inventory_model")
	if player == null or not player.has_method(inventory_method):
		return null
	return player.call(inventory_method)


func _stack_matches_key(stack: Dictionary, key_item: ItemDef) -> bool:
	if stack.is_empty() or key_item == null:
		return false
	if str(stack.get("resource_path", "")) == key_item.resource_path:
		return true
	return str(stack.get("id", "")) == str(key_item.id)


func _lock_message() -> String:
	if required_key == null:
		return _localized_text(locked_prompt_key, locked_prompt_text)
	var key_name := _item_display_name(required_key)
	if key_name == "":
		return _localized_text(missing_key_feedback_key, missing_key_feedback)
	var format := _localized_text(&"prompt.missing_key_format", "需要%s")
	return format % key_name


func _item_display_name(item_def: ItemDef) -> String:
	if item_def == null:
		return ""
	var name_key := str(item_def.name_key)
	if name_key != "":
		var translated := tr(name_key)
		if translated != name_key and translated != "":
			return translated
	if item_def.display_name != "":
		return item_def.display_name
	return str(item_def.id)


func _localized_text(key: StringName, fallback: String) -> String:
	var key_text := str(key)
	if key_text == "":
		return fallback
	var translated := tr(key_text)
	return fallback if translated == key_text else translated
