class_name NavigationManager3D
extends Node

@export_node_path("NavigationRegion3D") var navigation_region_path: NodePath
@export_node_path("Node") var scope_root_path: NodePath
@export var blocker_group := "navigation_blocker"
@export var bounds_min := Vector2(-16.0, -16.0)
@export var bounds_max := Vector2(16.0, 16.0)
@export_range(0.25, 2.0, 0.05) var cell_size := 0.5
@export_range(0.0, 2.0, 0.05) var agent_radius := 0.45
@export var rebuild_on_ready := true
@export var watch_blocker_movement := true
@export_range(0.1, 5.0, 0.1) var rebuild_check_interval := 0.5
@export_range(0.01, 2.0, 0.01) var blocker_move_threshold := 0.25
@export_range(128, 20000, 1) var max_polygons := 12000

var _navigation_region: NavigationRegion3D
var _scope_root: Node
var _rebuild_check_timer := 0.0
var _last_blocker_positions: Dictionary = {}
var _last_blocker_count := 0
var _last_walkable_polygons := 0


func _ready() -> void:
	_navigation_region = get_node_or_null(navigation_region_path) as NavigationRegion3D
	_scope_root = get_node_or_null(scope_root_path)
	if _scope_root == null:
		_scope_root = get_parent()
	if rebuild_on_ready:
		call_deferred("rebuild_navigation")


func _physics_process(delta: float) -> void:
	if not watch_blocker_movement:
		return
	_rebuild_check_timer = maxf(_rebuild_check_timer - delta, 0.0)
	if _rebuild_check_timer > 0.0:
		return
	_rebuild_check_timer = rebuild_check_interval
	if _blockers_moved():
		rebuild_navigation()


func rebuild_navigation() -> bool:
	if _navigation_region == null:
		_navigation_region = get_node_or_null(navigation_region_path) as NavigationRegion3D
	if _navigation_region == null:
		return false
	var blocker_rects := _collect_blocker_rects()
	var navigation_mesh := _build_grid_navigation_mesh(blocker_rects)
	_navigation_region.navigation_mesh = navigation_mesh
	_last_blocker_count = blocker_rects.size()
	_last_walkable_polygons = navigation_mesh.get_polygon_count()
	_snapshot_blocker_positions()
	return _last_walkable_polygons > 0


func get_navigation_debug_state() -> Dictionary:
	return {
		"blockers": _last_blocker_count,
		"walkable_polygons": _last_walkable_polygons,
		"bounds_min": bounds_min,
		"bounds_max": bounds_max,
		"cell_size": cell_size,
	}


func request_rebuild() -> void:
	call_deferred("rebuild_navigation")


func _build_grid_navigation_mesh(blocker_rects: Array) -> NavigationMesh:
	var navigation_mesh := NavigationMesh.new()
	var width := maxf(bounds_max.x - bounds_min.x, cell_size)
	var depth := maxf(bounds_max.y - bounds_min.y, cell_size)
	var columns := maxi(1, int(ceil(width / cell_size)))
	var rows := maxi(1, int(ceil(depth / cell_size)))
	if columns * rows > max_polygons:
		var scale := sqrt(float(columns * rows) / float(max_polygons))
		columns = maxi(1, int(ceil(float(columns) / scale)))
		rows = maxi(1, int(ceil(float(rows) / scale)))

	var vertices := PackedVector3Array()
	for z_index in range(rows + 1):
		var z := lerpf(bounds_min.y, bounds_max.y, float(z_index) / float(rows))
		for x_index in range(columns + 1):
			var x := lerpf(bounds_min.x, bounds_max.x, float(x_index) / float(columns))
			vertices.append(Vector3(x, 0.0, z))
	navigation_mesh.set_vertices(vertices)

	for z_index in range(rows):
		var z0 := lerpf(bounds_min.y, bounds_max.y, float(z_index) / float(rows))
		var z1 := lerpf(bounds_min.y, bounds_max.y, float(z_index + 1) / float(rows))
		for x_index in range(columns):
			var x0 := lerpf(bounds_min.x, bounds_max.x, float(x_index) / float(columns))
			var x1 := lerpf(bounds_min.x, bounds_max.x, float(x_index + 1) / float(columns))
			if _cell_blocked(Vector2(x0, z0), Vector2(x1, z1), blocker_rects):
				continue
			var top_left := _grid_vertex_index(x_index, z_index, columns)
			var top_right := _grid_vertex_index(x_index + 1, z_index, columns)
			var bottom_right := _grid_vertex_index(x_index + 1, z_index + 1, columns)
			var bottom_left := _grid_vertex_index(x_index, z_index + 1, columns)
			navigation_mesh.add_polygon(PackedInt32Array([top_left, top_right, bottom_right, bottom_left]))
	return navigation_mesh


func _grid_vertex_index(x_index: int, z_index: int, columns: int) -> int:
	return z_index * (columns + 1) + x_index


func _cell_blocked(cell_min: Vector2, cell_max: Vector2, blocker_rects: Array) -> bool:
	for rect in blocker_rects:
		if _rects_overlap(cell_min, cell_max, rect["min"], rect["max"]):
			return true
	return false


func _collect_blocker_rects() -> Array:
	var rects: Array = []
	var blockers := get_tree().get_nodes_in_group(blocker_group)
	for blocker in blockers:
		var node := blocker as Node3D
		if node == null:
			continue
		if _scope_root != null and node != _scope_root and not _is_descendant_of(node, _scope_root):
			continue
		var rect := _blocker_rect(node)
		if rect.has("min"):
			rects.append(rect)
	return rects


func _blocker_rect(node: Node3D) -> Dictionary:
	var source := str(node.get_meta("navigation_blocker_source", "collision"))
	var rect := {}
	if source != "visual":
		rect = _collision_rect(node)
	if not rect.has("min"):
		rect = _visual_rect(node)
	if not rect.has("min"):
		return {}
	return {
		"min": rect["min"] - Vector2(agent_radius, agent_radius),
		"max": rect["max"] + Vector2(agent_radius, agent_radius),
	}


func _collision_rect(node: Node3D) -> Dictionary:
	var rect := {}
	for child in node.find_children("*", "CollisionShape3D", true, false):
		var collision := child as CollisionShape3D
		if collision == null or collision.disabled or collision.shape == null:
			continue
		var shape_rect := _shape_rect(collision)
		if shape_rect.has("min"):
			rect = _merge_rects(rect, shape_rect)
	return rect


func _visual_rect(node: Node3D) -> Dictionary:
	var rect := {}
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var mesh_rect := _aabb_rect(mesh_instance.global_transform, mesh_instance.get_aabb())
		if mesh_rect.has("min"):
			rect = _merge_rects(rect, mesh_rect)
	return rect


func _shape_rect(collision: CollisionShape3D) -> Dictionary:
	var shape := collision.shape
	if shape is BoxShape3D:
		return _box_rect(collision.global_transform, (shape as BoxShape3D).size * 0.5)
	if shape is SphereShape3D:
		var radius := (shape as SphereShape3D).radius
		return _box_rect(collision.global_transform, Vector3(radius, radius, radius))
	if shape is CylinderShape3D:
		var cylinder := shape as CylinderShape3D
		return _box_rect(collision.global_transform, Vector3(cylinder.radius, cylinder.height * 0.5, cylinder.radius))
	if shape is CapsuleShape3D:
		var capsule := shape as CapsuleShape3D
		return _box_rect(collision.global_transform, Vector3(capsule.radius, capsule.height * 0.5, capsule.radius))
	return {}


func _aabb_rect(xform: Transform3D, aabb: AABB) -> Dictionary:
	var position := aabb.position
	var end := aabb.end
	return _rect_from_points([
		xform * Vector3(position.x, position.y, position.z),
		xform * Vector3(end.x, position.y, position.z),
		xform * Vector3(position.x, end.y, position.z),
		xform * Vector3(end.x, end.y, position.z),
		xform * Vector3(position.x, position.y, end.z),
		xform * Vector3(end.x, position.y, end.z),
		xform * Vector3(position.x, end.y, end.z),
		xform * Vector3(end.x, end.y, end.z),
	])


func _box_rect(xform: Transform3D, half_extents: Vector3) -> Dictionary:
	return _rect_from_points([
		xform * Vector3(-half_extents.x, -half_extents.y, -half_extents.z),
		xform * Vector3(half_extents.x, -half_extents.y, -half_extents.z),
		xform * Vector3(-half_extents.x, half_extents.y, -half_extents.z),
		xform * Vector3(half_extents.x, half_extents.y, -half_extents.z),
		xform * Vector3(-half_extents.x, -half_extents.y, half_extents.z),
		xform * Vector3(half_extents.x, -half_extents.y, half_extents.z),
		xform * Vector3(-half_extents.x, half_extents.y, half_extents.z),
		xform * Vector3(half_extents.x, half_extents.y, half_extents.z),
	])


func _rect_from_points(points: Array) -> Dictionary:
	if points.is_empty():
		return {}
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for point in points:
		var world_point := point as Vector3
		min_point.x = minf(min_point.x, world_point.x)
		min_point.y = minf(min_point.y, world_point.z)
		max_point.x = maxf(max_point.x, world_point.x)
		max_point.y = maxf(max_point.y, world_point.z)
	return {"min": min_point, "max": max_point}


func _merge_rects(base_rect: Dictionary, next_rect: Dictionary) -> Dictionary:
	if not base_rect.has("min"):
		return next_rect
	return {
		"min": Vector2(
			minf(base_rect["min"].x, next_rect["min"].x),
			minf(base_rect["min"].y, next_rect["min"].y)
		),
		"max": Vector2(
			maxf(base_rect["max"].x, next_rect["max"].x),
			maxf(base_rect["max"].y, next_rect["max"].y)
		),
	}


func _rects_overlap(a_min: Vector2, a_max: Vector2, b_min: Vector2, b_max: Vector2) -> bool:
	return a_min.x < b_max.x and a_max.x > b_min.x and a_min.y < b_max.y and a_max.y > b_min.y


func _blockers_moved() -> bool:
	var changed := false
	var current_ids := {}
	for blocker in get_tree().get_nodes_in_group(blocker_group):
		var node := blocker as Node3D
		if node == null:
			continue
		if _scope_root != null and node != _scope_root and not _is_descendant_of(node, _scope_root):
			continue
		var id := node.get_instance_id()
		current_ids[id] = true
		var position := node.global_position
		if not _last_blocker_positions.has(id):
			changed = true
		elif position.distance_to(_last_blocker_positions[id]) >= blocker_move_threshold:
			changed = true
	for id in _last_blocker_positions.keys():
		if not current_ids.has(id):
			changed = true
	if changed:
		_snapshot_blocker_positions()
	return changed


func _snapshot_blocker_positions() -> void:
	_last_blocker_positions.clear()
	for blocker in get_tree().get_nodes_in_group(blocker_group):
		var node := blocker as Node3D
		if node == null:
			continue
		if _scope_root != null and node != _scope_root and not _is_descendant_of(node, _scope_root):
			continue
		_last_blocker_positions[node.get_instance_id()] = node.global_position


func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var current := node
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false
