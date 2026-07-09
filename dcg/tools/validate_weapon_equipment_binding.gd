extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	await _validate_player_starts_unarmed()
	await _validate_equipped_pistol_syncs_to_weapon_controller()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[weapon_equipment_binding] OK start=unarmed equip=pistol_sync hud=visible boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_player_starts_unarmed() -> void:
	var context := await _spawn_context()
	if context.is_empty():
		return
	var weapon: Node = context["weapon"]
	var hud: Control = context["hud"]

	if weapon.get("weapon_def") != null:
		_errors.append("Player should not start with a hardwired pistol in WeaponController3D.")
	if str(weapon.call("get_fire_block_reason")) != "no_weapon":
		_errors.append("Unarmed player should be blocked by no_weapon, not hidden ammo or cooldown state.")
	await process_frame
	var hud_state: Dictionary = hud.call("get_display_state")
	if not str(hud_state.get("ammo", "")).contains("未裝備"):
		_errors.append("Raid HUD should visibly show 未裝備 when no weapon is equipped.")

	_free_node(context["scene"])


func _validate_equipped_pistol_syncs_to_weapon_controller() -> void:
	var context := await _spawn_context()
	if context.is_empty():
		return
	var player: Node = context["player"]
	var weapon: Node = context["weapon"]
	var hud: Control = context["hud"]
	var backpack_model: InventoryModel = player.call("get_inventory_model")

	backpack_model.clear()
	backpack_model.setup(50)
	backpack_model.add_item(Pistol, 1)
	if not bool(player.call("equip_inventory_stack", 0)):
		_errors.append("Player should equip No.5 pistol from backpack through EquipmentModel.")
	await process_frame
	await process_frame

	var equipped_weapon: Variant = weapon.get("weapon_def")
	if equipped_weapon == null:
		_errors.append("WeaponController3D should receive the equipped pistol after EquipmentModel changes.")
	elif int(equipped_weapon.get("catalog_number")) != 5:
		_errors.append("WeaponController3D should bind to No.5 pistol, not an unrelated weapon.")
	var hud_state: Dictionary = hud.call("get_display_state")
	if not str(hud_state.get("ammo", "")).contains(_item_name(Pistol)):
		_errors.append("Raid HUD should visibly show the equipped No.5 pistol name.")

	_free_node(context["scene"])


func _validate_source_boundaries() -> void:
	var player_scene := FileAccess.get_file_as_string("res://scenes/player/player_3d.tscn")
	if player_scene.contains("weapon_def = ExtResource(\"3_pistol\")") or player_scene.contains("data/items/weapons/pistol_9mm.tres"):
		_errors.append("Player scene should not hardwire No.5 pistol into WeaponController3D.")

	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	for required in ["_sync_weapon_from_equipment", "_equipment.sync_weapon_from_equipment"]:
		if not player_source.contains(required):
			_errors.append("PlayerController3D should bridge EquipmentModel to WeaponController3D through %s." % required)
	var equipment_source := FileAccess.get_file_as_string("res://scripts/player/player_equipment_controller_3d.gd")
	for required in ["sync_weapon_from_equipment", "get_equipped_item", "equip_weapon", "clear_weapon"]:
		if not equipment_source.contains(required):
			_errors.append("PlayerEquipmentController3D should own equipment-to-weapon sync through %s." % required)

	var weapon_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_controller_3d.gd")
	for required in ["no_weapon", "equip_weapon", "clear_weapon", "has_weapon"]:
		if not weapon_source.contains(required):
			_errors.append("WeaponController3D should expose unarmed/equip API term: %s." % required)
	for forbidden in ["EquipmentModel", "InventoryEquipmentUI", "get_inventory_model"]:
		if weapon_source.contains(forbidden):
			_errors.append("WeaponController3D should not directly depend on equipment UI or backpack APIs: %s." % forbidden)


func _spawn_context() -> Dictionary:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var player := scene.get_node_or_null("Player3D")
	var weapon := player.get_node_or_null("WeaponController3D") if player != null else null
	var hud := scene.find_child("RaidHudPanel", true, false) as Control
	if player == null:
		_errors.append("Gameplay scene should include Player3D.")
		_free_node(scene)
		return {}
	if weapon == null:
		_errors.append("Player3D should include WeaponController3D.")
		_free_node(scene)
		return {}
	if hud == null:
		_errors.append("Gameplay scene should include RaidHudPanel.")
		_free_node(scene)
		return {}
	return {
		"scene": scene,
		"player": player,
		"weapon": weapon,
		"hud": hud,
	}


func _item_name(item_def: ItemDef) -> String:
	var key := str(item_def.name_key)
	var translated := tr(key)
	return translated if translated != key else item_def.display_name


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
