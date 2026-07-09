extends SceneTree

const BASE_SCENE := "res://scenes/base/base_3d.tscn"


func _initialize() -> void:
	print("[base_scene_smoke] load")
	var packed := load(BASE_SCENE) as PackedScene
	if packed == null:
		push_error("Base scene should load.")
		quit(1)
		return
	print("[base_scene_smoke] instantiate")
	var scene := packed.instantiate()
	if scene == null:
		push_error("Base scene should instantiate.")
		quit(1)
		return
	var disable_filter := OS.get_environment("DCG_DISABLE_BASE_SCRIPT_FILTER").strip_edges()
	if disable_filter != "":
		for filter_text in disable_filter.split(",", false):
			_disable_matching_scripts(scene, filter_text.strip_edges())
	var hide_node_filter := OS.get_environment("DCG_BASE_HIDE_NODE_FILTER").strip_edges()
	if hide_node_filter != "":
		_apply_visible_to_matching_nodes(scene, hide_node_filter, false)
	var disable_process_filter := OS.get_environment("DCG_BASE_DISABLE_PROCESS_NODE_FILTER").strip_edges()
	if disable_process_filter != "":
		_apply_process_mode_to_matching_nodes(scene, disable_process_filter, Node.PROCESS_MODE_DISABLED)
	print("[base_scene_smoke] add_child")
	root.add_child(scene)
	await process_frame
	print("[base_scene_smoke] current=%s children=%d" % [scene.name, scene.get_child_count()])
	scene.queue_free()
	quit(0)


func _disable_matching_scripts(node: Node, filter_text: String) -> void:
	if filter_text == "":
		return
	var script_value: Variant = node.get_script()
	if script_value != null and str(script_value.resource_path).contains(filter_text):
		print("[base_scene_smoke] disabled %s -> %s" % [node.name, script_value.resource_path])
		node.set_script(null)
	for child in node.get_children():
		_disable_matching_scripts(child, filter_text)


func _apply_visible_to_matching_nodes(node: Node, filter_text: String, is_visible: bool) -> void:
	if filter_text == "":
		return
	if node.name.contains(filter_text) and node is CanvasItem:
		print("[base_scene_smoke] visible %s -> %s" % [node.name, str(is_visible)])
		(node as CanvasItem).visible = is_visible
	for child in node.get_children():
		_apply_visible_to_matching_nodes(child, filter_text, is_visible)


func _apply_process_mode_to_matching_nodes(node: Node, filter_text: String, mode: int) -> void:
	if filter_text == "":
		return
	if node.name.contains(filter_text):
		print("[base_scene_smoke] process_mode %s -> disabled" % node.name)
		node.process_mode = mode
	for child in node.get_children():
		_apply_process_mode_to_matching_nodes(child, filter_text, mode)
