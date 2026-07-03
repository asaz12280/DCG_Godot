extends SceneTree

const BASE_3D_SCENE := "res://scenes/base/base_3d.tscn"
const REQUIRED_INTERACTIONS := {
	"stash": "倉庫",
	"quests": "任務板",
	"workbench": "工作台",
	"raid_gate": "出擊門",
	"medical": "醫療站",
}

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_scene_exists()
	var scene := _instantiate_scene()
	if scene != null:
		root.add_child(scene)
		_validate_core_hierarchy(scene)
		_validate_interaction_points(scene)
		_validate_not_old_base_panel(scene)
		scene.queue_free()
	if _errors.is_empty():
		print("[base_3d_scene] OK scene=loadable player=present camera=targeted boundaries=present points=5")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_scene_exists() -> void:
	if not ResourceLoader.exists(BASE_3D_SCENE):
		_errors.append("Missing Base 3D scene at %s." % BASE_3D_SCENE)


func _instantiate_scene() -> Node:
	var packed := load(BASE_3D_SCENE) as PackedScene
	if packed == null:
		_errors.append("Cannot load Base 3D scene.")
		return null
	var instance := packed.instantiate()
	if instance == null:
		_errors.append("Cannot instantiate Base 3D scene.")
	return instance


func _validate_core_hierarchy(scene: Node) -> void:
	if scene.name != "Base3D":
		_errors.append("Base 3D root should be named Base3D.")
	if scene.get_node_or_null("Floor") == null:
		_errors.append("Base 3D should include a visible floor.")
	if scene.get_node_or_null("FloorCollision/CollisionShape3D") == null:
		_errors.append("Base 3D should include floor collision.")
	var player := scene.get_node_or_null("Player3D")
	if player == null:
		_errors.append("Base 3D should include Player3D.")
	elif not player.is_in_group("player"):
		_errors.append("Base 3D Player3D should keep the player group.")
	var camera := scene.get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		_errors.append("Base 3D should include Camera3D.")
	elif camera.target_path != NodePath("../Player3D"):
		_errors.append("Base 3D Camera3D should target Player3D.")
	for wall_name in ["NorthWall", "SouthWall", "WestWall", "EastWall"]:
		if scene.get_node_or_null("Boundaries/%s/CollisionShape3D" % wall_name) == null:
			_errors.append("Base 3D boundary %s should have collision." % wall_name)


func _validate_interaction_points(scene: Node) -> void:
	var points: Array[Node] = []
	_collect_interaction_points(scene, points)
	if points.size() < REQUIRED_INTERACTIONS.size():
		_errors.append("Base 3D should expose at least %d interaction point markers." % REQUIRED_INTERACTIONS.size())
	var found: Dictionary = {}
	for point in points:
		var id := str(point.get_meta("interaction_id", ""))
		if id == "":
			_errors.append("Base interaction point %s is missing interaction_id metadata." % point.name)
			continue
		found[id] = point
		var expected_label := str(REQUIRED_INTERACTIONS.get(id, ""))
		var label := str(point.get_meta("display_name_zh", ""))
		if expected_label != "" and label != expected_label:
			_errors.append("Base interaction point %s should display %s but has %s." % [id, expected_label, label])
		if point.get_node_or_null("Marker") == null:
			_errors.append("Base interaction point %s should have a visible marker." % id)
		var label_node := point.get_node_or_null("Label3D") as Label3D
		if label_node == null:
			_errors.append("Base interaction point %s should have a Label3D." % id)
		elif label_node.text != expected_label:
			_errors.append("Base interaction Label3D for %s should be Traditional Chinese." % id)
	for id in REQUIRED_INTERACTIONS.keys():
		if not found.has(id):
			_errors.append("Base 3D missing interaction point id: %s." % id)


func _collect_interaction_points(node: Node, points: Array[Node]) -> void:
	if node.is_in_group("base_interaction_point"):
		points.append(node)
	for child in node.get_children():
		_collect_interaction_points(child, points)


func _validate_not_old_base_panel(scene: Node) -> void:
	if scene.get_node_or_null("BaseScreen") != null:
		_errors.append("Base 3D scene should not embed the old full-screen BaseScreen panel.")
