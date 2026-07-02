extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")
const Ammo := preload("res://data/items/ammo/ammo_9mm.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	await _validate_weapon_status_states()
	_validate_source_boundaries()
	_validate_localization_keys()
	if _errors.is_empty():
		print("[shooting_feedback_hud] OK status=unarmed_empty_ready_reloading node_first=true zh_tw=true boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_weapon_status_states() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var player := scene.get_node_or_null("Player3D")
	var weapon := player.get_node_or_null("WeaponController3D") if player != null else null
	var hud := scene.get_node_or_null("HUD/RaidHudPanel")
	if player == null or weapon == null or hud == null:
		_errors.append("Gameplay scene should include Player3D, WeaponController3D, and HUD/RaidHudPanel.")
		_free_node(scene)
		return

	if weapon.has_method("clear_weapon"):
		weapon.call("clear_weapon")
	await process_frame
	_require_status(hud, "未裝備", "HUD should show `未裝備` when no weapon is equipped.")

	var backpack_model: InventoryModel = player.call("get_inventory_model")
	backpack_model.clear()
	backpack_model.setup(50)
	backpack_model.add_item(Pistol, 1)
	backpack_model.add_item(Ammo, 24)
	if not bool(player.call("equip_inventory_stack", 0)):
		_errors.append("Shooting feedback validation should equip No.5 pistol from backpack.")
	await process_frame

	weapon.set("current_ammo", 0)
	weapon.set("reserve_ammo", 0)
	if weapon.has_method("_sync_ammo_model_from_public_counts"):
		weapon.call("_sync_ammo_model_from_public_counts")
	await process_frame
	_require_status(hud, "空彈", "HUD should show `空彈` when equipped weapon has no loaded ammo.")

	weapon.set("current_ammo", 8)
	weapon.set("reserve_ammo", 16)
	if weapon.has_method("_sync_ammo_model_from_public_counts"):
		weapon.call("_sync_ammo_model_from_public_counts")
	if weapon.has_method("_last_fire_time"):
		weapon.set("_last_fire_time", -9999.0)
	await process_frame
	_require_status(hud, "可射擊", "HUD should show `可射擊` when weapon has loaded ammo and is ready.")

	player.set("reload_duration_seconds", 0.20)
	weapon.set("current_ammo", 0)
	weapon.set("reserve_ammo", 0)
	if weapon.has_method("_sync_ammo_model_from_public_counts"):
		weapon.call("_sync_ammo_model_from_public_counts")
	if not bool(player.call("reload_equipped_weapon")):
		_errors.append("Shooting feedback validation should start timed reload.")
	await physics_frame
	await process_frame
	_require_status(hud, "裝填中", "HUD should show `裝填中` while timed reload is active.")

	_free_node(scene)


func _validate_source_boundaries() -> void:
	var hud_source := FileAccess.get_file_as_string("res://scripts/ui/raid_hud_panel.gd")
	for required in ["WeaponStatusLabel", "_update_weapon_status", "_weapon_status_text", "get_reload_state"]:
		if not hud_source.contains(required):
			_errors.append("RaidHudPanel should expose shooting feedback HUD term: %s." % required)
	for forbidden in ["consume_stack_quantity", "reload_from_item", "InventoryModel", "ContainerInventoryModel"]:
		if hud_source.contains(forbidden):
			_errors.append("RaidHudPanel should not own weapon, reload, or inventory mutation: %s." % forbidden)

	var scene_source := FileAccess.get_file_as_string("res://scenes/ui/raid_hud_panel.tscn")
	if not scene_source.contains("WeaponStatusLabel"):
		_errors.append("Raid HUD scene should define WeaponStatusLabel as a node-first UI element.")


func _validate_localization_keys() -> void:
	var csv := FileAccess.get_file_as_string("res://data/localization/game_text.csv")
	for key in [
		"ui.raid_hud.weapon_status",
		"ui.raid_hud.weapon_status_unarmed",
		"ui.raid_hud.weapon_status_empty",
		"ui.raid_hud.weapon_status_reloading",
		"ui.raid_hud.weapon_status_ready",
	]:
		if not csv.contains(key):
			_errors.append("Localization should include shooting feedback HUD key: %s." % key)


func _require_status(hud: Node, term: String, message: String) -> void:
	var state: Dictionary = hud.call("get_display_state")
	var status := str(state.get("weapon_status", ""))
	if not status.contains("戰鬥狀態") or not status.contains(term):
		_errors.append("%s Got `%s`." % [message, status])
	for token in ["No weapon", "Ready to fire", "Reloading", "Empty", "Combat status"]:
		if status.contains(token):
			_errors.append("Weapon status HUD should not show English fallback text: %s" % status)


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
