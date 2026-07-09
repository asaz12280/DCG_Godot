extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	await _validate_low_durability_hud_status()
	_validate_source_boundaries()
	_validate_localization_keys()
	if _errors.is_empty():
		print("[weapon_durability_hud] OK status=low_broken empty=depleted_priority localized=true boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_low_durability_hud_status() -> void:
	var context := await _spawn_context()
	if context.is_empty():
		return
	var player: Node = context["player"]
	var weapon: Node = context["weapon"]
	var hud: Node = context["hud"]
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	backpack_model.clear()
	backpack_model.setup(50)
	backpack_model.add_stack(_durable_pistol_stack(5, 12))
	if not bool(player.call("equip_inventory_stack", 0)):
		_errors.append("Durability HUD validation should equip a worn No.5 pistol.")
		_free_node(context["scene"])
		return
	await process_frame
	weapon.set("current_ammo", 2)
	weapon.set("reserve_ammo", 0)
	if weapon.has_method("_sync_ammo_result"):
		weapon.call("_sync_ammo_result")
	if weapon.has_method("force_cooldown_ready"):
		weapon.call("force_cooldown_ready")
	await process_frame

	_require_status(hud, ["戰鬥狀態", "耐久低", "5/12"], "Raid HUD should warn when the equipped firearm is below the durability penalty threshold.")

	var equipment: RefCounted = player.call("get_equipment_model")
	if not bool(equipment.call("equip_stack", &"primary_weapon", _durable_pistol_stack(0, 12))):
		_errors.append("Durability HUD validation should replace the equipped pistol with a depleted stack.")
	await process_frame
	weapon.set("current_ammo", 1)
	if weapon.has_method("_sync_ammo_result"):
		weapon.call("_sync_ammo_result")
	await process_frame

	_require_status(hud, ["戰鬥狀態", "耐久耗盡", "0/12"], "Raid HUD should show depleted durability when the equipped firearm reaches zero.")
	weapon.set("current_ammo", 0)
	if weapon.has_method("_sync_ammo_result"):
		weapon.call("_sync_ammo_result")
	await process_frame

	_require_status(hud, ["戰鬥狀態", "耐久耗盡", "0/12"], "Raid HUD should prioritize depleted durability when the firearm is also out of ammo.")
	_reject_status(hud, [TranslationServer.translate("ui.raid_hud.weapon_status_empty")], "Raid HUD should not hide depleted durability behind an empty-ammo state.")
	_free_node(context["scene"])


func _validate_source_boundaries() -> void:
	var hud_source := FileAccess.get_file_as_string("res://scripts/ui/raid_hud_panel.gd")
	for required in ["get_active_weapon_durability_state", "_weapon_durability_status_text", "weapon_status_durability_low_format", "weapon_status_durability_broken_format"]:
		if not hud_source.contains(required):
			_errors.append("RaidHudPanel should expose durable weapon HUD term: %s." % required)
	for forbidden in ["equip_stack", "apply_use_wear", "repair_from_save_data", "consume_stack_quantity"]:
		if hud_source.contains(forbidden):
			_errors.append("RaidHudPanel should read durability state without mutating gameplay data: %s." % forbidden)
	if not hud_source.contains("_weapon_durability_status_text(true)") or not hud_source.contains("broken_only"):
		_errors.append("RaidHudPanel should expose a broken-only durability status priority path.")
	var durability_index := hud_source.find("var durability_status := _weapon_durability_status_text(true)")
	var ammo_index := hud_source.find("var current := int(_weapon_controller.get(\"current_ammo\"))")
	if durability_index < 0 or ammo_index < 0 or durability_index > ammo_index:
		_errors.append("RaidHudPanel should prioritize durability status before empty-ammo status.")


func _validate_localization_keys() -> void:
	var csv := FileAccess.get_file_as_string("res://data/localization/game_text.csv")
	for key in [
		"ui.raid_hud.weapon_status_durability_low_format",
		"ui.raid_hud.weapon_status_durability_broken_format",
	]:
		if not csv.contains(key):
			_errors.append("Localization should include durability HUD key: %s." % key)
	for token in ["Low durability", "Durability depleted"]:
		if _zh_tw_value_for_key(csv, "ui.raid_hud.weapon_status_durability_low_format").contains(token):
			_errors.append("Traditional Chinese durability HUD text should not be English fallback.")
		if _zh_tw_value_for_key(csv, "ui.raid_hud.weapon_status_durability_broken_format").contains(token):
			_errors.append("Traditional Chinese durability HUD text should not be English fallback.")


func _require_status(hud: Node, terms: Array[String], message: String) -> void:
	var state: Dictionary = hud.call("get_display_state")
	var status := str(state.get("weapon_status", ""))
	for term in terms:
		if not status.contains(term):
			_errors.append("%s Missing `%s` in `%s`." % [message, term, status])
	for token in ["Low durability", "Durability depleted"]:
		if status.contains(token):
			_errors.append("Durability HUD should not show English fallback text: %s" % status)


func _reject_status(hud: Node, terms: Array[String], message: String) -> void:
	var state: Dictionary = hud.call("get_display_state")
	var status := str(state.get("weapon_status", ""))
	for term in terms:
		if term != "" and status.contains(term):
			_errors.append("%s Unexpected `%s` in `%s`." % [message, term, status])


func _spawn_context() -> Dictionary:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var player := scene.get_node_or_null("Player3D")
	var weapon := player.get_node_or_null("WeaponController3D") if player != null else null
	var hud := scene.get_node_or_null("HUD/RaidHudPanel")
	if player == null:
		_errors.append("Gameplay scene should include Player3D.")
		_free_node(scene)
		return {}
	if weapon == null:
		_errors.append("Player3D should include WeaponController3D.")
		_free_node(scene)
		return {}
	if hud == null:
		_errors.append("Gameplay scene should include HUD/RaidHudPanel.")
		_free_node(scene)
		return {}
	return {
		"scene": scene,
		"player": player,
		"weapon": weapon,
		"hud": hud,
	}


func _durable_pistol_stack(current: int, maximum: int) -> Dictionary:
	var stack := Pistol.to_stack(1)
	stack["current_durability"] = current
	stack["max_durability"] = maximum
	stack["original_max_durability"] = Pistol.max_durability
	stack["repair_max_durability_loss"] = Pistol.repair_max_durability_loss
	stack["durability_penalty_ratio"] = Pistol.durability_penalty_ratio
	return stack


func _zh_tw_value_for_key(csv: String, key: String) -> String:
	for raw_line in csv.split("\n", false):
		if not raw_line.begins_with("%s," % key):
			continue
		var columns := raw_line.split(",", false)
		return str(columns[1]) if columns.size() > 1 else ""
	return ""


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
