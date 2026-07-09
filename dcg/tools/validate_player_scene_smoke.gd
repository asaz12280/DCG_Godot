extends SceneTree

const PLAYER_SCENE := "res://scenes/player/player_3d.tscn"


func _initialize() -> void:
	print("[player_scene_smoke] load")
	var packed := load(PLAYER_SCENE) as PackedScene
	if packed == null:
		push_error("Player scene should load.")
		quit(1)
		return
	print("[player_scene_smoke] instantiate")
	var player := packed.instantiate()
	if player == null:
		push_error("Player scene should instantiate.")
		quit(1)
		return
	print("[player_scene_smoke] add_child")
	root.add_child(player)
	await process_frame
	print("[player_scene_smoke] ready health=%s" % str(player.get("health")))
	player.queue_free()
	quit(0)
