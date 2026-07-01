class_name InventoryDropController
extends RefCounted

const LootPickupScene := preload("res://scenes/items/loot_pickup_wood.tscn")
const MIN_DROP_DISTANCE := 1.1
const MAX_DROP_DISTANCE := 2.2
const CONTEXT_DROP_MIN_RADIUS := 0.55
const CONTEXT_DROP_MAX_RADIUS := 1.05

var owner: Control
var painter: InventoryEquipmentPainter
var resolver: InventoryItemResolver
var dragging_stack_index: int = -1
var dragging_stack: Dictionary = {}
var drag_position: Vector2 = Vector2.ZERO


func setup(source_owner: Control, source_painter: InventoryEquipmentPainter, source_resolver: InventoryItemResolver) -> void:
	owner = source_owner
	painter = source_painter
	resolver = source_resolver


func start_drag(stack_index: int, stack: Dictionary, mouse_position: Vector2) -> void:
	dragging_stack_index = stack_index
	dragging_stack = stack.duplicate(true)
	drag_position = mouse_position
	_request_redraw()


func update_drag(mouse_position: Vector2) -> void:
	drag_position = mouse_position
	_request_redraw()


func finish_drag(backpack_model: InventoryModel, mouse_position: Vector2, panel_rect: Rect2, target_stack_index: int, player: Node) -> bool:
	var handled := false
	if not panel_rect.has_point(mouse_position):
		handled = drop_stack_at(backpack_model, dragging_stack_index, dragging_stack, mouse_position, player)
	elif target_stack_index >= 0 and target_stack_index < backpack_model.stacks.size():
		handled = backpack_model.merge_or_swap_stack(dragging_stack_index, target_stack_index)
	clear()
	return handled


func clear() -> void:
	dragging_stack_index = -1
	dragging_stack.clear()
	_request_redraw()


func is_dragging() -> bool:
	return dragging_stack_index >= 0 and not dragging_stack.is_empty()


func draw_dragged_item(slot_size: Vector2, item_label: Callable) -> void:
	if not is_dragging() or painter == null:
		return
	var drag_rect := Rect2(drag_position - slot_size * 0.5, slot_size)
	painter.slot(drag_rect, Color(0.30, 0.45, 0.42, 0.68), Color(0.83, 0.95, 0.90, 0.72))
	item_label.call(drag_rect, dragging_stack)


func drop_stack_at(backpack_model: InventoryModel, stack_index: int, stack: Dictionary, screen_position: Vector2, player: Node, random_near_player: bool = false) -> bool:
	if backpack_model == null or stack_index < 0 or stack_index >= backpack_model.stacks.size():
		return false
	if resolver == null:
		return false

	var item_def := resolver.item_def_from_stack(stack)
	if item_def == null:
		return false

	var quantity := maxi(int(stack.get("quantity", 1)), 1)
	var pickup := LootPickupScene.instantiate() as Node3D
	if pickup == null:
		return false
	pickup.set("item_def", item_def)
	pickup.set("quantity", quantity)

	var parent := _get_drop_parent()
	parent.add_child(pickup)
	pickup.global_position = _drop_position_near_player(player) if random_near_player else _drop_position_from_screen(screen_position, player)

	var removed := backpack_model.remove_stack_at(stack_index)
	if removed.is_empty():
		pickup.queue_free()
		return false
	return true


func _get_drop_parent() -> Node:
	var tree := owner.get_tree() if owner != null else Engine.get_main_loop() as SceneTree
	if tree != null:
		var scene := tree.current_scene
		if scene != null:
			var scene_props := scene.find_child("SceneProps", true, false)
			if scene_props != null:
				return scene_props
			return scene
		return tree.root
	return null


func _drop_position_from_screen(screen_position: Vector2, player: Node) -> Vector3:
	var player_3d := player as Node3D
	if player_3d == null:
		return Vector3.ZERO

	var target := player_3d.global_position + _player_forward(player_3d) * MIN_DROP_DISTANCE
	var camera: Camera3D = owner.get_viewport().get_camera_3d() if owner != null else null
	if camera != null:
		var ray_origin := camera.project_ray_origin(screen_position)
		var ray_direction := camera.project_ray_normal(screen_position)
		if absf(ray_direction.y) > 0.001:
			var distance := (player_3d.global_position.y - ray_origin.y) / ray_direction.y
			if distance > 0.0:
				target = ray_origin + ray_direction * distance
	target.y = player_3d.global_position.y

	var offset := target - player_3d.global_position
	offset.y = 0.0
	var distance_from_player := offset.length()
	if distance_from_player < 0.001:
		offset = _player_forward(player_3d) * MIN_DROP_DISTANCE
	elif distance_from_player > MAX_DROP_DISTANCE:
		offset = offset.normalized() * MAX_DROP_DISTANCE
	elif distance_from_player < MIN_DROP_DISTANCE:
		offset = offset.normalized() * MIN_DROP_DISTANCE
	return player_3d.global_position + offset


func _drop_position_near_player(player: Node) -> Vector3:
	var player_3d := player as Node3D
	if player_3d == null:
		return Vector3.ZERO
	var angle := randf() * TAU
	var distance := randf_range(CONTEXT_DROP_MIN_RADIUS, CONTEXT_DROP_MAX_RADIUS)
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * distance
	return player_3d.global_position + offset


func _player_forward(player_3d: Node3D) -> Vector3:
	var forward := -player_3d.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.001:
		return Vector3.FORWARD
	return forward.normalized()


func _request_redraw() -> void:
	if owner != null:
		owner.queue_redraw()
