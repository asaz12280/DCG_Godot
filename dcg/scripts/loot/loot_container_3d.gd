class_name LootContainer3D
extends Area3D

signal opened(rolled_stacks: Array[Dictionary])

@export var loot_table: Resource
@export_range(1, 12, 1) var roll_count := 1
@export var one_shot := true
@export var prompt_key: StringName = &"prompt.open_container"
@export var prompt_text := "Open"
@export var opened_prompt_text := "Empty"

var has_opened := false
var _player_in_range: Node3D
var _prompt_label: Label3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_prompt_label = find_child("PromptLabel", true, false) as Label3D
	_update_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range == null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if try_open(_player_in_range):
			get_viewport().set_input_as_handled()


func try_open(player: Node) -> bool:
	if player == null or not player.has_method("add_item_resource"):
		return false
	if one_shot and has_opened:
		return false
	if loot_table == null or not loot_table.has_method("roll"):
		return false
	if loot_table.has_method("is_valid") and not loot_table.is_valid():
		return false

	var rolled_stacks: Array[Dictionary] = loot_table.roll(roll_count)
	if rolled_stacks.is_empty():
		return false

	var granted_any := false
	for stack in rolled_stacks:
		var item_path := str(stack.get("item_path", stack.get("resource_path", "")))
		var quantity := int(stack.get("quantity", 1))
		if item_path == "" or quantity <= 0 or not ResourceLoader.exists(item_path):
			continue
		var item := load(item_path) as ItemDef
		if item == null:
			continue
		if bool(player.call("add_item_resource", item, quantity)):
			granted_any = true

	if not granted_any:
		return false
	has_opened = true
	_update_prompt()
	opened.emit(rolled_stacks)
	return true


func get_state() -> Dictionary:
	return {
		"has_opened": has_opened,
		"player_in_range": _player_in_range != null,
		"has_loot_table": loot_table != null,
		"roll_count": roll_count,
	}


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.has_method("add_item_resource"):
		_player_in_range = body
		_update_prompt()


func _on_body_exited(body: Node3D) -> void:
	if body == _player_in_range:
		_player_in_range = null
		_update_prompt()


func _update_prompt() -> void:
	if _prompt_label == null:
		return
	_prompt_label.visible = _player_in_range != null
	var prompt := _localized_text(prompt_key, prompt_text)
	_prompt_label.text = opened_prompt_text if has_opened else prompt


func _localized_text(key: StringName, fallback: String) -> String:
	var key_text := str(key)
	if key_text == "":
		return fallback
	var translated := tr(key_text)
	return fallback if translated == key_text else translated
