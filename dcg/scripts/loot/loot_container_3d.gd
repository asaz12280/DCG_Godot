class_name LootContainer3D
extends Area3D

signal opened(rolled_stacks: Array[Dictionary])
signal open_requested(container: LootContainer3D)

const ContainerInventoryModelScript := preload("res://scripts/inventory/container_inventory_model.gd")

@export var loot_table: Resource
@export_range(1, 12, 1) var roll_count := 1
@export_range(1, 24, 1) var container_capacity := 4
@export var one_shot := true
@export var display_name := "愛心箱"
@export var prompt_key: StringName = &"prompt.open_container"
@export var prompt_text := "按 E 開啟箱子"
@export var opened_prompt_text := "按 E 查看箱子"

var has_opened := false
var container_inventory: RefCounted = ContainerInventoryModelScript.new()
var _player_in_range: Node3D
var _prompt_label: Label3D


func _ready() -> void:
	container_inventory.setup(container_capacity)
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
	if player == null:
		return false
	if not _ensure_container_contents():
		return false
	_update_prompt()
	var ui_manager := get_node_or_null("/root/UIManager") if is_inside_tree() else null
	if ui_manager != null and ui_manager.has_method("open_container_inventory"):
		ui_manager.call("open_container_inventory", self)
	open_requested.emit(self)
	return true


func get_state() -> Dictionary:
	return {
		"has_opened": has_opened,
		"player_in_range": _player_in_range != null,
		"has_loot_table": loot_table != null,
		"roll_count": roll_count,
		"container_capacity": container_inventory.get_capacity(),
		"container_used_slots": container_inventory.get_used_slots(),
	}


func get_container_inventory_model() -> RefCounted:
	return container_inventory


func get_container_display_name() -> String:
	return display_name


func _ensure_container_contents() -> bool:
	if has_opened:
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

	has_opened = true
	opened.emit(rolled_stacks)
	return true


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
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
