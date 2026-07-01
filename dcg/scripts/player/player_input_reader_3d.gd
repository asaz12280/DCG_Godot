class_name PlayerInputReader3D
extends RefCounted

var owner: Node


func _init(source_owner: Node) -> void:
	owner = source_owner


func is_gameplay_blocked() -> bool:
	return is_gameplay_action_blocked()


func is_movement_blocked() -> bool:
	if owner == null or owner.get_tree() == null:
		return false
	var ui_manager := owner.get_node_or_null("/root/UIManager")
	if ui_manager == null:
		return false
	if ui_manager.has_method("is_gameplay_movement_blocked"):
		return bool(ui_manager.call("is_gameplay_movement_blocked"))
	if ui_manager.has_method("is_ui_open"):
		var top_menu_open := false
		if ui_manager.has_method("is_top_menu_open"):
			top_menu_open = bool(ui_manager.call("is_top_menu_open"))
		return bool(ui_manager.call("is_ui_open")) and not top_menu_open
	return StringName(ui_manager.get("active_ui")) != &""


func is_gameplay_action_blocked() -> bool:
	if owner == null or owner.get_tree() == null:
		return false
	var ui_manager := owner.get_node_or_null("/root/UIManager")
	if ui_manager == null:
		return false
	if ui_manager.has_method("is_gameplay_action_blocked"):
		return bool(ui_manager.call("is_gameplay_action_blocked"))
	if ui_manager.has_method("is_ui_open"):
		return bool(ui_manager.call("is_ui_open"))
	return StringName(ui_manager.get("active_ui")) != &""


func movement_vector() -> Vector2:
	if is_movement_blocked():
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func wants_sprint() -> bool:
	return not is_movement_blocked() and Input.is_action_pressed("sprint")


func wants_dodge() -> bool:
	return not is_movement_blocked() and Input.is_action_just_pressed("dodge")
