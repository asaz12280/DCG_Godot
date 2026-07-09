extends SceneTree

const PlayerScene := preload("res://scenes/player/player_3d.tscn")
const ScavengerScene := preload("res://scenes/enemies/scavenger_3d.tscn")
const PlayerHudScript := preload("res://scripts/ui/player_hud_3d.gd")
const CombatKnife := preload("res://data/items/weapons/combat_knife.tres")
const Pistol9mm := preload("res://data/items/weapons/pistol_9mm.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	await _validate_v_toggles_melee_and_left_click_slashes()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[melee_weapon_flow] OK toggle=V auto_equip=melee left_click=slash_damage hud=arc_state boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_v_toggles_melee_and_left_click_slashes() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var player := PlayerScene.instantiate()
	scene.add_child(player)
	var enemy := ScavengerScene.instantiate()
	scene.add_child(enemy)
	var hud := PlayerHudScript.new() as Control
	hud.size = Vector2(1280.0, 720.0)
	scene.add_child(hud)
	await process_frame
	await physics_frame

	player.global_position = Vector3.ZERO
	player.look_at(Vector3(0.0, 0.0, -3.0), Vector3.UP)
	enemy.global_position = Vector3(0.0, 0.0, -1.05)
	if not bool(player.call("add_item_resource", Pistol9mm, 1)):
		_errors.append("Player should be able to add Pistol-9mm to backpack for firearm validation.")
		_free_node(scene)
		return
	if not bool(player.call("equip_inventory_stack", 0, &"primary_weapon")):
		_errors.append("Player should be able to equip Pistol-9mm as primary weapon before melee validation.")
		_free_node(scene)
		return
	if not bool(player.call("add_item_resource", CombatKnife, 1)):
		_errors.append("Player should be able to add Combat Knife to backpack for melee validation.")
		_free_node(scene)
		return
	var pistol_visual := player.get_node_or_null("WeaponVisualRoot/PistolVisual") as Node3D
	var knife_visual := player.get_node_or_null("WeaponVisualRoot/KnifeVisual") as Node3D
	if pistol_visual == null or knife_visual == null:
		_errors.append("Player scene should provide simple pistol and combat knife visual nodes.")
	elif not pistol_visual.visible or knife_visual.visible:
		_errors.append("Player should show pistol visual, not knife visual, before switching to melee.")
	_press_key(player, KEY_V)
	await process_frame
	if not bool(player.call("is_melee_mode_active")):
		_errors.append("Pressing V should auto-equip an available backpack melee weapon and enter melee mode.")
	if pistol_visual != null and knife_visual != null and (pistol_visual.visible or not knife_visual.visible):
		_errors.append("Pressing V should show the knife visual and hide the pistol visual.")
	var equipment: RefCounted = player.call("get_equipment_model")
	var melee_stack: Dictionary = equipment.call("get_slot", &"melee")
	if int(melee_stack.get("catalog_number", 0)) != 6:
		_errors.append("V melee toggle should equip Combat Knife into the melee slot when available.")
	var hud_state_after_v: Dictionary = hud.call("get_display_state")
	if bool(hud_state_after_v.get("melee_slash_visible", false)):
		_errors.append("Pressing V should switch to the knife without showing slash feedback.")
	var held_after_v: Dictionary = hud_state_after_v.get("held_weapon", {})
	if str(held_after_v.get("mode", "")) != "melee":
		_errors.append("HUD held weapon state should report melee mode after pressing V.")
	_press_key(player, KEY_V)
	await process_frame
	var hud_state_after_repeated_v: Dictionary = hud.call("get_display_state")
	if not bool(player.call("is_melee_mode_active")):
		_errors.append("Pressing V repeatedly should keep the melee weapon equipped until another weapon key is selected.")
	if bool(hud_state_after_repeated_v.get("melee_slash_visible", false)):
		_errors.append("Pressing V repeatedly should not trigger slash feedback.")
	var health_before := float(enemy.get("current_health"))
	_press_left_click(player)
	await process_frame
	var health_after := float(enemy.get("current_health"))
	var player_state: Dictionary = player.call("get_melee_attack_state")
	var hud_state: Dictionary = hud.call("get_display_state")
	if health_after >= health_before:
		_errors.append("Left-click melee attack should damage an enemy inside the forward slash arc.")
	if int(player_state.get("hit_count", 0)) <= 0:
		_errors.append("Player melee attack state should report at least one hit.")
	if not bool(hud_state.get("melee_slash_visible", false)):
		_errors.append("PlayerHud3D should expose visible slash feedback after melee attack.")
	_press_key(player, KEY_1)
	await process_frame
	if bool(player.call("is_melee_mode_active")):
		_errors.append("Pressing 1 should return from melee mode to firearm mode.")
	var held_after_one: Dictionary = hud.call("get_display_state").get("held_weapon", {})
	if str(held_after_one.get("mode", "")) != "firearm" or str(held_after_one.get("item_id", "")) != "pistol_9mm":
		_errors.append("HUD held weapon state should report Pistol-9mm after pressing 1.")
	if pistol_visual != null and knife_visual != null and (not pistol_visual.visible or knife_visual.visible):
		_errors.append("Pressing 1 should show the pistol visual and hide the knife visual.")
	_free_node(scene)


func _validate_source_boundaries() -> void:
	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	for required in ["toggle_melee_mode", "switch_to_firearm_mode", "_attack_with_melee_weapon", "MeleeAttackServiceScript", "KEY_V", "KEY_1"]:
		if not player_source.contains(required):
			_errors.append("PlayerController3D should bridge melee input through %s." % required)
	var service_source := FileAccess.get_file_as_string("res://scripts/combat/melee_attack_service.gd")
	for required in ["perform_arc_attack", "DamageEventScript", "apply_damage", "damageable"]:
		if not service_source.contains(required):
			_errors.append("MeleeAttackService should own melee hit rules through %s." % required)
	for forbidden in ["Control", "PlayerHud", "InputEvent", "InputMap"]:
		if service_source.contains(forbidden):
			_errors.append("MeleeAttackService should stay combat-only and not own UI/input concerns: %s." % forbidden)
	var hud_source := FileAccess.get_file_as_string("res://scripts/ui/player_hud_painter.gd")
	if not hud_source.contains("_paint_melee_slash") or not hud_source.contains("draw_arc"):
		_errors.append("PlayerHUDPainter should draw code-native slash arc feedback.")


func _press_key(player: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.physical_keycode = keycode
	player.call("_unhandled_input", event)


func _press_left_click(player: Node) -> void:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	player.call("_unhandled_input", event)


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
