extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const RaidHudScene := preload("res://scenes/ui/raid_hud_panel.tscn")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")
const Ammo := preload("res://data/items/ammo/ammo_9mm.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	_validate_node_first_structure()
	_validate_layout_quality()
	await _validate_reload_progress_is_player_visible()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[reload_ui] OK node_first=progress_bar visible=reload_progress completion=clears layout=fit boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_node_first_structure() -> void:
	var hud := RaidHudScene.instantiate()
	root.add_child(hud)
	for path in [
		"MainPanel/PanelMargin/Content/WeaponStatusLabel",
		"MainPanel/PanelMargin/Content/ReloadLabel",
		"MainPanel/PanelMargin/Content/ReloadProgress",
	]:
		if hud.get_node_or_null(path) == null:
			_errors.append("Raid HUD should provide node-first reload UI path: %s" % path)
	var progress := hud.get_node_or_null("MainPanel/PanelMargin/Content/ReloadProgress") as ProgressBar
	if progress == null:
		_errors.append("Reload progress should be a Godot ProgressBar node.")
	elif progress.show_percentage:
		_errors.append("Reload progress should use controlled HUD text instead of ProgressBar percentage text.")
	_free_node(hud)


func _validate_layout_quality() -> void:
	var hud := RaidHudScene.instantiate()
	root.add_child(hud)
	for viewport_size in [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0)]:
		var rect: Rect2 = hud.call("preview_layout", viewport_size)
		if rect.position.x < 24.0 or rect.position.y < 24.0:
			_errors.append("Raid HUD reload UI should keep safe top-left margins at %s." % viewport_size)
		if rect.end.x > viewport_size.x or rect.end.y > viewport_size.y:
			_errors.append("Raid HUD reload UI should fit inside viewport at %s." % viewport_size)
		if rect.size.y > viewport_size.y * 0.30:
			_errors.append("Raid HUD reload UI should stay compact vertically at %s." % viewport_size)
	_free_node(hud)


func _validate_reload_progress_is_player_visible() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var player := scene.get_node_or_null("Player3D")
	var weapon := player.get_node_or_null("WeaponController3D") if player != null else null
	var hud := scene.get_node_or_null("HUD/RaidHudPanel")
	if player == null or weapon == null or hud == null:
		_errors.append("Gameplay scene should include Player3D, WeaponController3D, and HUD/RaidHudPanel for reload UI.")
		_free_node(scene)
		return

	player.set("reload_duration_seconds", 0.10)
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	backpack_model.clear()
	backpack_model.setup(50)
	backpack_model.add_item(Pistol, 1)
	backpack_model.add_item(Ammo, 24)
	if not bool(player.call("equip_inventory_stack", 0)):
		_errors.append("Reload UI validation should equip No.5 pistol from backpack.")
	await process_frame
	weapon.set("current_ammo", 0)
	weapon.set("reserve_ammo", 0)
	if weapon.has_method("_sync_ammo_result"):
		weapon.call("_sync_ammo_result")

	_press_reload(player)
	await physics_frame
	await process_frame
	var state: Dictionary = hud.call("get_display_state")
	if not bool(state.get("reload_visible", false)):
		_errors.append("Reload progress bar should become visible after pressing R.")
	if not str(state.get("reload", "")).contains("裝填"):
		_errors.append("Reload label should show Traditional Chinese reload text while active.")
	if not str(state.get("weapon_status", "")).contains("裝填中"):
		_errors.append("Weapon status HUD should show `裝填中` while reload is active.")
	var first_progress := float(state.get("reload_progress", 0.0))
	if first_progress < 0.0 or first_progress >= 100.0:
		_errors.append("Reload progress should start between 0 and 100 while reloading.")

	for _frame in range(12):
		await physics_frame
		await process_frame
	state = hud.call("get_display_state")
	if int(weapon.get("current_ammo")) != 8:
		_errors.append("Reload UI flow should complete and load the pistol magazine.")
	if str(state.get("reload", "")).contains("裝填中"):
		_errors.append("Reload label should leave the active loading state after completion.")

	for _frame in range(40):
		await physics_frame
		await process_frame
	state = hud.call("get_display_state")
	if bool(state.get("reload_visible", true)):
		_errors.append("Reload progress UI should clear after the completion hold.")

	_free_node(scene)


func _validate_source_boundaries() -> void:
	var hud_source := FileAccess.get_file_as_string("res://scripts/ui/raid_hud_panel.gd")
	for required in ["ReloadLabel", "ReloadProgress", "reload_progress_changed", "_on_reload_progress_changed"]:
		if not hud_source.contains(required):
			_errors.append("RaidHudPanel should expose reload UI term: %s." % required)
	for required in ["WeaponStatusLabel", "_update_weapon_status", "get_reload_state"]:
		if not hud_source.contains(required):
			_errors.append("RaidHudPanel should expose weapon status reload term: %s." % required)
	for forbidden in ["consume_stack_quantity", "reload_from_item", "InventoryModel"]:
		if hud_source.contains(forbidden):
			_errors.append("RaidHudPanel should not own reload data mutation: %s." % forbidden)

	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	for required in ["reload_progress_changed", "reload_duration_seconds", "_update_reload", "_emit_reload_state"]:
		if not player_source.contains(required):
			_errors.append("PlayerController3D should expose timed reload state term: %s." % required)


func _press_reload(player: Node) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_R
	event.physical_keycode = KEY_R
	player.call("_unhandled_input", event)


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
