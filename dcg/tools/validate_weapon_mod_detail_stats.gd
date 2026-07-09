extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")
const SMG := preload("res://data/items/weapons/smg_9mm.tres")
const Ammo := preload("res://data/items/ammo/ammo_9mm.tres")
const ExtendedMagazine := preload("res://data/items/attachments/extended_magazine.tres")
const YellowLockedCrateTable := preload("res://data/loot_tables/crate_yellow_locked_cache.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	_validate_weapon_data_model(Pistol, "Pistol-S", 24, 8, 100)
	_validate_weapon_data_model(SMG, "SMG-S", 16, 24, 120)
	_validate_yellow_locked_cache_entry()
	await _validate_weapon_panel_attach_and_reload_flow()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[weapon_mod_detail_stats] OK data=minimal_weapon_model loot=yellow_extended_mag ui=details_panel attach=8_to_12 reload=12 hold_fire=enabled boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_weapon_data_model(weapon_def: ItemDef, label: String, expected_damage: int, expected_magazine_capacity: int, expected_max_durability: int) -> void:
	if weapon_def.damage != expected_damage:
		_errors.append("%s should keep %d base damage." % [label, expected_damage])
	if weapon_def.fire_rate_per_second <= 0.0:
		_errors.append("%s should expose fire_rate_per_second." % label)
	if weapon_def.weapon_armor_penetration_level < 1.0:
		_errors.append("%s should expose weapon armor penetration." % label)
	if weapon_def.critical_chance < 0.0:
		_errors.append("%s critical_chance should be a valid stat." % label)
	if weapon_def.critical_chance > 100.0:
		_errors.append("%s critical_chance should use 0-100 percent authoring." % label)
	if weapon_def.projectile_pierce_chance < 0.0 or weapon_def.projectile_pierce_chance > 100.0:
		_errors.append("%s projectile_pierce_chance should use 0-100 percent authoring." % label)
	if weapon_def.magazine_capacity != expected_magazine_capacity:
		_errors.append("%s base magazine capacity should stay %d before attachments." % [label, expected_magazine_capacity])
	if weapon_def.reload_duration_seconds <= 0.0:
		_errors.append("%s should expose reload_duration_seconds." % label)
	if weapon_def.weapon_horizontal_recoil <= 0.0:
		_errors.append("%s should expose horizontal sway through weapon_horizontal_recoil." % label)
	if weapon_def.projectile_range <= 0.0:
		_errors.append("%s should expose projectile_range." % label)
	if weapon_def.weapon_durability_wear_per_shot <= 0.0:
		_errors.append("%s should expose weapon_durability_wear_per_shot." % label)
	if weapon_def.max_durability != expected_max_durability:
		_errors.append("%s should expose current/max durability %d through stack data." % [label, expected_max_durability])
	var stack := weapon_def.to_stack(1)
	for key in [
		"fire_rate_per_second",
		"weapon_armor_penetration_level",
		"critical_chance",
		"projectile_pierce_chance",
		"reload_duration_seconds",
		"projectile_range",
		"weapon_durability_wear_per_shot",
	]:
		if not stack.has(key):
			_errors.append("%s stack should preserve stat key: %s." % [label, key])


func _validate_yellow_locked_cache_entry() -> void:
	var entries: Array = YellowLockedCrateTable.get("guaranteed_entries")
	for entry in entries:
		if str(entry.get("item_path")) == "res://data/items/attachments/tactical_headset.tres":
			return
	_errors.append("Yellow locked crate guaranteed entries should include the tactical headset from the new equipment bundle.")


func _validate_weapon_panel_attach_and_reload_flow() -> void:
	await _validate_weapon_panel_attach_and_reload_flow_for_weapon(Pistol, "Pistol-S", 8, 12)
	await _validate_weapon_panel_attach_and_reload_flow_for_weapon(SMG, "SMG-S", 24, 28)


func _validate_weapon_panel_attach_and_reload_flow_for_weapon(weapon_def: ItemDef, label: String, base_capacity: int, extended_capacity: int) -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var player := scene.get_node_or_null("Player3D")
	var weapon := player.get_node_or_null("WeaponController3D") if player != null else null
	var inventory_ui := scene.find_child("InventoryEquipmentUI", true, false) as Control
	if player == null or weapon == null or inventory_ui == null:
		_errors.append("Gameplay scene should include Player3D, WeaponController3D, and InventoryEquipmentUI.")
		_free_node(scene)
		return

	var backpack_model: InventoryModel = player.call("get_inventory_model")
	var equipment_model: RefCounted = player.call("get_equipment_model")
	backpack_model.clear()
	backpack_model.setup(50)
	equipment_model.call("clear")
	backpack_model.add_stack(weapon_def.to_stack(1))
	backpack_model.add_stack(ExtendedMagazine.to_stack(1))
	inventory_ui.call("open_inventory")
	await process_frame
	if not bool(inventory_ui.call("_open_weapon_mod_panel_for_backpack_stack", 0)):
		_errors.append("Backpack %s context action should open the weapon mod panel." % label)
	await process_frame

	var before_state: Dictionary = inventory_ui.call("_weapon_mod_panel_state_for_backpack_stack", 0)
	_expect_panel_stats(before_state, base_capacity, 0)
	var display_state: Dictionary = inventory_ui.call("get_display_state_for_viewport", Vector2(1920.0, 1080.0))
	_expect_panel_text(display_state, false, "")

	var pistol_stack := (backpack_model.stacks[0] as Dictionary).duplicate(true)
	pistol_stack["weapon_mods"] = {"magazine": ExtendedMagazine.to_stack(1)}
	backpack_model.replace_stack_at(0, pistol_stack)
	inventory_ui.call("_refresh_weapon_mod_panel_state")
	await process_frame

	var after_state: Dictionary = inventory_ui.call("_weapon_mod_panel_state_for_backpack_stack", 0)
	_expect_panel_stats(after_state, extended_capacity, 4)
	display_state = inventory_ui.call("get_display_state_for_viewport", Vector2(1920.0, 1080.0))
	_expect_panel_text(display_state, true, "%d (%d+4)" % [extended_capacity, base_capacity])
	if not bool(player.call("equip_inventory_stack", 0, &"primary_weapon")):
		_errors.append("Validation should equip modified %s before reload testing." % label)
	await process_frame
	if int(weapon.get("magazine_size")) != extended_capacity:
		_errors.append("WeaponController3D should apply Extended Magazine-S capacity as %d rounds." % extended_capacity)

	backpack_model.add_stack(Ammo.to_stack(extended_capacity))
	player.set("reload_duration_seconds", 0.05)
	weapon.set("current_ammo", 0)
	weapon.set("reserve_ammo", 0)
	if weapon.has_method("_sync_ammo_result"):
		weapon.call("_sync_ammo_result")
	if not bool(player.call("reload_equipped_weapon", &"validation")):
		_errors.append("Player reload flow should start after installing Extended Magazine-S.")
	await _wait_for_reload_complete(player)
	var reload_result: Dictionary = player.call("get_last_reload_result")
	if not bool(reload_result.get("reloaded", false)):
		_errors.append("Player reload flow should complete with Extended Magazine-S installed.")
	if int(weapon.get("current_ammo")) != extended_capacity:
		_errors.append("Installed Extended Magazine-S should allow loading %d rounds, got %d." % [extended_capacity, int(weapon.get("current_ammo"))])
	_free_node(scene)


func _expect_panel_stats(panel_state: Dictionary, expected_capacity: int, expected_bonus: int) -> void:
	var rows: Array = panel_state.get("stat_rows", []) as Array
	if rows.size() < 10:
		_errors.append("Weapon mod panel should expose the full minimal weapon stat row set.")
	var capacity_found := false
	for row in rows:
		var row_dict := row as Dictionary
		if StringName(str(row_dict.get("label_key", ""))) != &"ui.weapon_stat.magazine_capacity":
			continue
		capacity_found = true
		var value := str(row_dict.get("value", ""))
		if not value.contains(str(expected_capacity)):
			_errors.append("Weapon mod panel magazine stat should show capacity %d, got %s." % [expected_capacity, value])
		if expected_bonus > 0 and not value.contains("+%d" % expected_bonus):
			_errors.append("Weapon mod panel magazine stat should show attachment bonus +%d, got %s." % [expected_bonus, value])
	if not capacity_found:
		_errors.append("Weapon mod panel should include a magazine capacity stat row.")


func _expect_panel_text(display_state: Dictionary, expect_extended_magazine: bool, expected_capacity_text: String) -> void:
	var panel_rect: Rect2 = display_state.get("weapon_mod_panel_rect", Rect2())
	if panel_rect.size.y < 420.0:
		_errors.append("Weapon mod panel should reserve a lower detail area under attachment slots.")
	var panel_text := str(display_state.get("weapon_mod_panel_text", ""))
	for key in [
		"ui.weapon_mod.details_title",
		"ui.weapon_stat.damage",
		"ui.weapon_stat.fire_rate",
		"ui.weapon_stat.armor_penetration",
		"ui.weapon_stat.critical_chance",
		"ui.weapon_stat.projectile_pierce_chance",
		"ui.weapon_stat.magazine_capacity",
		"ui.weapon_stat.reload_duration",
		"ui.weapon_stat.recoil_angle",
		"ui.weapon_stat.projectile_range",
		"ui.weapon_stat.durability_wear",
		"ui.weapon_stat.durability",
	]:
		var translated := TranslationServer.translate(key)
		if not panel_text.contains(translated):
			_errors.append("Weapon mod panel text should include localized stat key %s." % key)
	if expect_extended_magazine and not panel_text.contains(TranslationServer.translate("item.extended_magazine.name")):
		_errors.append("Weapon mod panel should show Extended Magazine-S after installation.")
	if expect_extended_magazine and expected_capacity_text != "" and not panel_text.contains(expected_capacity_text):
		_errors.append("Weapon mod panel should show magazine capacity as %s after installation." % expected_capacity_text)


func _validate_source_boundaries() -> void:
	var item_source := FileAccess.get_file_as_string("res://scripts/items/item_def.gd")
	for required in ["fire_rate_per_second", "weapon_armor_penetration_level", "critical_chance", "projectile_pierce_chance", "reload_duration_seconds", "projectile_range", "weapon_durability_wear_per_shot"]:
		if not item_source.contains(required):
			_errors.append("ItemDef should own weapon stat field: %s." % required)
	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	for required in ["_update_held_primary_fire", "Input.is_mouse_button_pressed", "_current_weapon_reload_duration_seconds"]:
		if not player_source.contains(required):
			_errors.append("PlayerController3D should bridge held fire and weapon reload duration through %s." % required)
	var equipment_source := FileAccess.get_file_as_string("res://scripts/player/player_equipment_controller_3d.gd")
	for required in ["_weapon_stat_rows", "stat_rows", "weapon_durability_wear_per_shot"]:
		if not equipment_source.contains(required):
			_errors.append("PlayerEquipmentController3D should own weapon stat panel state term: %s." % required)
	var presenter_source := FileAccess.get_file_as_string("res://scripts/ui/weapon_mod_panel_presenter.gd")
	for required in ["details_title", "stat_rows", "scroll_details", "_draw_detail_scrollbar"]:
		if not presenter_source.contains(required):
			_errors.append("WeaponModPanelPresenter should draw detail rows and scrollbar through %s." % required)
	var text_source := FileAccess.get_file_as_string("res://data/localization/game_text.csv")
	for required in ["ui.weapon_mod.details_title", "ui.weapon_stat.damage", "ui.weapon_stat.durability"]:
		if not text_source.contains(required):
			_errors.append("Weapon stat UI text should live in localization data: %s." % required)
	var loot_source := FileAccess.get_file_as_string("res://data/loot_tables/crate_yellow_locked_cache.tres")
	for required in ["guaranteed_entries", "res://data/items/attachments/tactical_headset.tres"]:
		if not loot_source.contains(required):
			_errors.append("Yellow locked crate data should list the tactical headset as guaranteed loot through %s." % required)


func _wait_for_reload_complete(player: Node) -> void:
	for _i in range(40):
		var state: Dictionary = player.call("get_reload_state")
		if not bool(state.get("active", false)):
			return
		await process_frame
	_errors.append("Reload flow did not complete within the validation frame budget.")


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
