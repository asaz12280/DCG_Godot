extends SceneTree

const BASE_SCENE := "res://scenes/base/base_3d.tscn"


func _initialize() -> void:
	var packed := load(BASE_SCENE) as PackedScene
	if packed == null:
		push_error("Base scene should load.")
		quit(1)
		return
	var scene := packed.instantiate()
	var hud := scene.get_node_or_null("HUD/PlayerHud3D") as CanvasItem
	if hud != null:
		hud.visible = false
	root.add_child(scene)
	await process_frame
	var player := scene.get_node_or_null("Player3D")
	if player == null or not player.has_method("get_quick_bar_state"):
		push_error("Base scene player should expose quick bar state.")
		quit(1)
		return
	var state: Variant = player.call("get_quick_bar_state")
	if typeof(state) != TYPE_ARRAY:
		push_error("Quick bar state should be an array.")
		quit(1)
		return
	print("[quick_bar_state_smoke] OK slots=%d" % (state as Array).size())
	scene.queue_free()
	quit(0)
