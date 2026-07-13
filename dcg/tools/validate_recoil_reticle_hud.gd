extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const Pistol := preload("res://data/items/weapons/pistol_S.tres")
const Ammo := preload("res://data/items/ammo/ammo_S.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	await _validate_recoil_reticle_wiring()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[recoil_reticle_hud] OK sibling=canvas offset=recoil_state hidden=matches_hud boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_recoil_reticle_wiring() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame

	var hud := scene.get_node_or_null("HUD/RaidHudPanel") as Control
	var hud_layer := scene.get_node_or_null("HUD")
	if hud == null:
		_errors.append("Gameplay scene should include HUD/RaidHudPanel.")
		_free_node(scene)
		return
	if hud_layer == null:
		_errors.append("Gameplay scene should include a HUD CanvasLayer parent.")
		_free_node(scene)
		return

	hud.call("_update_recoil_reticle")
	await process_frame
	var reticle := scene.get_node_or_null("HUD/RecoilReticle") as Control
	if reticle == null:
		_errors.append("Raid HUD should create a RecoilReticle sibling under the HUD CanvasLayer.")
		_free_node(scene)
		return
	if reticle.get_parent() != hud_layer:
		_errors.append("RecoilReticle should be a HUD CanvasLayer child, not clipped by the compact RaidHudPanel.")
	if reticle.get_parent() == hud:
		_errors.append("RecoilReticle should not be nested inside the compact RaidHudPanel.")
	if int(reticle.mouse_filter) != Control.MOUSE_FILTER_IGNORE:
		_errors.append("RecoilReticle should ignore mouse input so it never blocks gameplay or panels.")

	var initial_state: Dictionary = hud.call("get_display_state")
	var initial_reticle: Dictionary = initial_state.get("recoil_reticle", {}) as Dictionary
	if initial_reticle.is_empty():
		_errors.append("RaidHudPanel display state should expose recoil reticle debug state.")
	var initial_size: Vector2 = initial_reticle.get("size", Vector2.ZERO)
	if initial_size.x < 100.0 or initial_size.y < 100.0:
		_errors.append("RecoilReticle should cover the viewport instead of the compact HUD panel. Got %s." % initial_size)

	var player := scene.get_node_or_null("Player3D")
	var weapon := player.get_node_or_null("WeaponController3D") if player != null else null
	if player == null or weapon == null:
		_errors.append("Gameplay scene should include Player3D and WeaponController3D for recoil reticle validation.")
		_free_node(scene)
		return

	var backpack_model: InventoryModel = player.call("get_inventory_model")
	backpack_model.clear()
	backpack_model.setup(50)
	backpack_model.add_stack(_durable_pistol_stack(12, 12))
	if not bool(player.call("equip_inventory_stack", 0, &"primary_weapon")):
		_errors.append("Recoil reticle validation should equip a fresh Pistol-S.")
		_free_node(scene)
		return
	await process_frame

	_load_weapon_with_ammo(weapon, Ammo, 2)
	_press_primary_fire(player)
	hud.call("_update_recoil_reticle")
	await process_frame

	var reticle_state: Dictionary = reticle.call("get_display_state")
	var offset: Vector2 = reticle_state.get("offset", Vector2.ZERO)
	var recoil_state: Dictionary = reticle_state.get("state", {}) as Dictionary
	if offset.length() <= 0.1:
		_errors.append("RecoilReticle should show a visible offset after the player fires a recoil-producing weapon.")
	if not bool(recoil_state.get("active", false)):
		_errors.append("RecoilReticle should receive the active player recoil state from RaidHudPanel.")
	if absf(float(recoil_state.get("accumulated_angle_degrees", 0.0))) <= 0.001:
		_errors.append("RecoilReticle state should include non-zero accumulated recoil after firing.")

	hud.visible = false
	hud.call("_update_recoil_reticle")
	if reticle.visible:
		_errors.append("RecoilReticle should hide with RaidHudPanel so menus do not leave combat reticle artifacts.")
	hud.visible = true
	hud.call("_update_recoil_reticle")
	if not reticle.visible:
		_errors.append("RecoilReticle should become visible again with RaidHudPanel.")

	_free_node(scene)


func _validate_source_boundaries() -> void:
	var reticle_source := FileAccess.get_file_as_string("res://scripts/ui/recoil_reticle.gd")
	for required in ["class_name RecoilReticle", "func set_recoil_state", "func _draw", "_recoil_offset"]:
		if not reticle_source.contains(required):
			_errors.append("RecoilReticle should own draw-only recoil presentation term: %s." % required)
	for forbidden in ["PlayerController3D", "WeaponController3D", "InventoryModel", "ItemDef", "TranslationServer", "_text("]:
		if reticle_source.contains(forbidden):
			_errors.append("RecoilReticle should stay draw-only and not depend on %s." % forbidden)

	var hud_source := FileAccess.get_file_as_string("res://scripts/ui/raid_hud_panel.gd")
	for required in ["RecoilReticleScript", "_ensure_recoil_reticle", "_update_recoil_reticle", "get_last_weapon_recoil_state"]:
		if not hud_source.contains(required):
			_errors.append("RaidHudPanel should bridge recoil state to the reticle through %s." % required)
	for forbidden in ["draw_line", "draw_circle"]:
		if hud_source.contains(forbidden):
			_errors.append("RaidHudPanel should not own custom reticle drawing: %s." % forbidden)

	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	if player_source.contains("RecoilReticle"):
		_errors.append("PlayerController3D should not depend on the HUD reticle class.")


func _load_weapon_with_ammo(weapon: Node, ammo_def: ItemDef, quantity: int) -> void:
	weapon.set("current_ammo", 0)
	weapon.set("reserve_ammo", 0)
	if weapon.has_method("_sync_ammo_result"):
		weapon.call("_sync_ammo_result")
	var moved := int(weapon.call("reload_from_item", ammo_def, quantity))
	if moved != quantity:
		_errors.append("Validation ammo should load %d rounds, got %d." % [quantity, moved])
	if weapon.has_method("force_cooldown_ready"):
		weapon.call("force_cooldown_ready")


func _press_primary_fire(player: Node) -> void:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	player.call("_unhandled_input", event)


func _durable_pistol_stack(current: int, maximum: int) -> Dictionary:
	var stack := Pistol.to_stack(1)
	stack["current_durability"] = current
	stack["max_durability"] = maximum
	stack["original_max_durability"] = Pistol.max_durability
	stack["repair_max_durability_loss"] = Pistol.repair_max_durability_loss
	stack["durability_penalty_ratio"] = Pistol.durability_penalty_ratio
	return stack


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
