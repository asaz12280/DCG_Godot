extends SceneTree

const BASE_SCENE := "res://scenes/base/base_3d.tscn"


func _initialize() -> void:
	var packed := load(BASE_SCENE) as PackedScene
	var scene := packed.instantiate()
	_print_script_nodes(scene, scene.name)
	scene.free()
	quit(0)


func _print_script_nodes(node: Node, path: String) -> void:
	var script: Variant = node.get_script()
	if script != null:
		print("%s -> %s" % [path, script.resource_path])
	for child in node.get_children():
		_print_script_nodes(child, "%s/%s" % [path, child.name])
