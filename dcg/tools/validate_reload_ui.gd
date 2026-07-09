extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")
const Ammo := preload("res://data/items/ammo/ammo_9mm.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	await _validate_reload_progress_is_player_visible()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[reload_ui] OK minimal_hud=reload_progress visible=true completion=clears legacy_panel=hidden boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_reload_progress_is_player_visible() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var player := scene.get_node_or_null("Player3D")
	var weapon := player.get_node_or_null("WeaponController3D") if player != null else null
	var hud := scene.get_node_or_null("HUD/PlayerHud3D")
	var legacy_hud := scene.get_node_or_null("HUD/RaidHudPanel")
	if player == null or weapon == null or hud == null or legacy_hud == null:
		_errors.append("Gameplay scene should include Player3D, WeaponController3D, PlayerHud3D, and hidden legacy RaidHudPanel for reload UI.")
		_free_node(scene)
		return
	if bool(legacy_hud.visible):
		_errors.append("Legacy top-left RaidHudPanel should be hidden during normal gameplay.")

	player.set("reload_duration_seconds", 0.60)
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
	await process_frame
	var reload_progress_signal_count := 0
	player.reload_progress_changed.connect(func(_state: Dictionary) -> void:
		reload_progress_signal_count += 1
	)

	var ammo_state: Dictionary = hud.call("get_display_state")
	if int(ammo_state.get("ammo_loaded", -1)) != 0 or int(ammo_state.get("ammo_backpack", -1)) != 24:
		_errors.append("PlayerHud3D should show loaded ammo and matching backpack ammo before reload, got `%s`." % str(ammo_state))
	var loaded_bullets := TranslationServer.translate("ui.player_hud.loaded_bullets")
	if not str(ammo_state.get("ammo_text", "")).contains("0 %s / 24" % loaded_bullets):
		_errors.append("PlayerHud3D should show loaded bullets / matching backpack ammo before reload, got `%s`." % str(ammo_state.get("ammo_text", "")))

	_press_reload(player)
	await physics_frame
	await process_frame
	var state: Dictionary = hud.call("get_display_state")
	if not bool(state.get("reload_visible", false)):
		_errors.append("PlayerHud3D reload progress should become visible after pressing R.")
	var first_progress := float(state.get("reload_progress", 0.0))
	if first_progress < 0.0 or first_progress >= 1.0:
		_errors.append("PlayerHud3D reload progress should start between 0 and 1 while reloading.")

	for _frame in range(45):
		await physics_frame
		await process_frame
	state = hud.call("get_display_state")
	if int(weapon.get("current_ammo")) != 8:
		_errors.append("Reload UI flow should complete and load the pistol magazine.")
	if int(state.get("ammo_loaded", -1)) != 8 or int(state.get("ammo_backpack", -1)) != 16:
		_errors.append("PlayerHud3D should show loaded ammo and reduced matching backpack ammo after reload, got `%s`." % str(state))
	if not str(state.get("ammo_text", "")).contains("8 %s / 16" % loaded_bullets):
		_errors.append("PlayerHud3D should show loaded bullets / matching backpack ammo after reload, got `%s`." % str(state.get("ammo_text", "")))
	if reload_progress_signal_count > 24:
		_errors.append("Reload progress should be throttled to avoid UI stutter, got %d signals for a 0.60s reload." % reload_progress_signal_count)

	for _frame in range(40):
		await physics_frame
		await process_frame
	state = hud.call("get_display_state")
	if bool(state.get("reload_visible", true)):
		_errors.append("PlayerHud3D reload progress UI should clear after reload completion.")

	_free_node(scene)


func _validate_source_boundaries() -> void:
	var hud_source := FileAccess.get_file_as_string("res://scripts/ui/player_hud_3d.gd")
	for required in ["reload_progress_changed", "_on_reload_progress_changed", "PlayerHUDPainterScript", "get_display_state", "_mark_backpack_ammo_cache_dirty", "_should_refresh_backpack_ammo_after_reload", "_refresh_backpack_ammo_cache"]:
		if not hud_source.contains(required):
			_errors.append("PlayerHud3D should expose minimal reload UI term: %s." % required)
	for forbidden in ["BACKPACK_AMMO_CACHE_INTERVAL", "_backpack_ammo_cache_age"]:
		if hud_source.contains(forbidden):
			_errors.append("PlayerHud3D should not poll backpack ammo during reload via %s." % forbidden)
	var hud_painter_source := FileAccess.get_file_as_string("res://scripts/ui/player_hud_painter.gd")
	for required in ["_paint_reload_progress", "_paint_ammo_panel"]:
		if not hud_painter_source.contains(required):
			_errors.append("PlayerHUDPainter should own minimal reload paint term: %s." % required)
	for forbidden in ["consume_stack_quantity", "reload_from_item", "InventoryModel"]:
		if hud_source.contains(forbidden):
			_errors.append("PlayerHud3D should not own reload data mutation: %s." % forbidden)

	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	for required in ["reload_progress_changed", "reload_duration_seconds", "_update_reload", "_emit_reload_state", "_should_emit_reload_state", "RELOAD_PROGRESS_EMIT_STEP"]:
		if not player_source.contains(required):
			_errors.append("PlayerController3D should expose timed reload state term: %s." % required)
	if not player_source.contains("get_compatible_backpack_ammo_count"):
		_errors.append("PlayerController3D should expose a read-only compatible backpack ammo count for PlayerHud3D.")
	var csv := FileAccess.get_file_as_string("res://data/localization/game_text.csv")
	for key in [
		"ui.raid_hud.reload_ready",
		"ui.raid_hud.reloading",
		"ui.raid_hud.reload_complete",
		"ui.raid_hud.reload_cancelled",
		"ui.player_hud.loaded_bullets",
	]:
		if not csv.contains(key):
			_errors.append("Localization should include reload HUD key: %s." % key)


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
