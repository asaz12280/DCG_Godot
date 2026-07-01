extends Area3D

@export var item_def: ItemDef
@export var quantity: int = 1
@export var prompt_text: String = ""
@export var prompt_key: StringName = &"prompt.pickup"

var _player_in_range: Node3D = null
var _prompt_label: Label3D = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_prompt_label = find_child("PromptLabel", true, false) as Label3D
	_update_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range == null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if _try_pickup():
			get_viewport().set_input_as_handled()


func _try_pickup() -> bool:
	if _player_in_range == null or not _player_in_range.has_method("add_item_resource"):
		return false
	if not _player_in_range.add_item_resource(item_def, quantity):
		return false
	queue_free()
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
	var item_name := _get_item_display_name()
	var prompt := _localized_text(prompt_key, prompt_text)
	_prompt_label.text = "%s: %s x%d" % [prompt, item_name, maxi(quantity, 1)]


func _on_localization_changed() -> void:
	_update_prompt()


func _get_item_display_name() -> String:
	if item_def != null:
		var key := str(item_def.name_key)
		if key != "":
			return _localized_text(item_def.name_key, item_def.display_name)
		if item_def.display_name != "":
			return item_def.display_name
	return _localized_text(&"item.unknown.name", "")


func _localized_text(key: StringName, fallback: String) -> String:
	var key_text := str(key)
	if key_text == "":
		return fallback
	var translated := tr(key_text)
	if translated == key_text:
		return fallback
	return translated
