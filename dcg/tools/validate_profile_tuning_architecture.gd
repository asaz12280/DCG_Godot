extends SceneTree

const WeaponAttachmentServiceScript := preload("res://scripts/combat/weapon_attachment_service.gd")
const WeaponControllerScript := preload("res://scripts/combat/weapon_controller_3d.gd")
const WeaponTuningServiceScript := preload("res://scripts/combat/weapon_tuning_service.gd")
const EnemyControllerScript := preload("res://scripts/ai/enemy_controller_3d.gd")
const Pistol := preload("res://data/items/weapons/pistol_S.tres")
const SMG := preload("res://data/items/weapons/smg_S.tres")
const Ammo := preload("res://data/items/ammo/ammo_S.tres")
const LightArmor := preload("res://data/items/armor/light_armor.tres")
const ExtendedMagazine := preload("res://data/items/attachments/extended_magazine.tres")
const Scavenger := preload("res://data/enemies/scavenger.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_item_profiles()
	_validate_snapshot_resolution()
	await _validate_weapon_controller_bridge()
	await _validate_enemy_behavior_profile()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[profile_tuning_architecture] OK profiles=snapshot weapon_controller=bridge ammo=simple_compat enemy_behavior=data_driven")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_item_profiles() -> void:
	_expect(Pistol.weapon_profile != null, "Pistol-S should have a WeaponProfile.")
	_expect(SMG.weapon_profile != null, "SMG-S should have a WeaponProfile.")
	_expect(LightArmor.armor_profile != null, "Light Armor should have an ArmorProfile.")
	_expect(ExtendedMagazine.attachment_profile != null, "Extended Magazine should have an AttachmentProfile.")
	_expect(Pistol.get_weapon_damage() == 20, "WeaponProfile should feed ItemDef weapon damage getter.")
	_expect(Pistol.get_weapon_magazine_capacity() == 8, "WeaponProfile should feed ItemDef magazine getter.")
	_expect(Pistol.get_max_durability() == 100, "WeaponProfile should feed ItemDef weapon durability getter.")
	_expect(SMG.get_weapon_damage() == 18, "SMG-S WeaponProfile should feed ItemDef weapon damage getter.")
	_expect(SMG.get_weapon_magazine_capacity() == 20, "SMG-S WeaponProfile should feed ItemDef magazine getter.")
	_expect(SMG.get_max_durability() == 120, "SMG-S WeaponProfile should feed ItemDef weapon durability getter.")
	_expect(Ammo.get_ammo_tag() == &"S", "Ammo-S should keep only compatibility ammo tag data.")
	_expect(LightArmor.get_armor_protection_level() == 4.0, "ArmorProfile should feed armor protection getter.")
	_expect(ExtendedMagazine.get_attachment_magazine_capacity_bonus() == 4, "AttachmentProfile should feed magazine bonus getter.")


func _validate_snapshot_resolution() -> void:
	var weapon_stack := _weapon_stack_with_mods(Pistol)
	var attachment_state: Dictionary = WeaponAttachmentServiceScript.modifiers_for_weapon_stack(weapon_stack, Pistol)
	var snapshot: Dictionary = WeaponTuningServiceScript.resolve_snapshot(Pistol, Ammo, attachment_state, weapon_stack)
	_expect(bool(snapshot.get("valid", false)), "WeaponTuningService.resolve_snapshot should return a valid weapon snapshot.")
	_expect_close(float(snapshot.get("damage", 0.0)), 20.0, 0.001, "Snapshot damage should come from weapon tuning, not ammo tuning.")
	_expect(int(snapshot.get("magazine_capacity", 0)) == 12, "Snapshot magazine capacity should include the extended magazine bonus.")
	_expect_close(float(snapshot.get("armor_penetration_level", 0.0)), 1.0, 0.001, "Snapshot armor penetration should come from weapon tuning.")
	_expect_close(float(snapshot.get("weapon_horizontal_recoil", 0.0)), 4.0, 0.001, "Snapshot weapon horizontal recoil should keep base tuning with the magazine attachment.")
	_expect_close(float(snapshot.get("horizontal_recoil", 0.0)), 4.0, 0.001, "Snapshot final horizontal recoil should not include ammo recoil tuning.")
	_expect_close(float(snapshot.get("spread_multiplier", 0.0)), 1.0, 0.001, "Snapshot spread should stay neutral with the magazine attachment.")
	_expect((snapshot.get("attachment_ids", []) as Array).has("extended_magazine"), "Snapshot should expose applied attachment ids.")
	_expect((snapshot.get("attachment_slots", []) as Array).has("magazine"), "Snapshot should expose applied attachment slots.")
	_validate_smg_snapshot_resolution()


func _validate_smg_snapshot_resolution() -> void:
	var weapon_stack := _weapon_stack_with_mods(SMG)
	var attachment_state: Dictionary = WeaponAttachmentServiceScript.modifiers_for_weapon_stack(weapon_stack, SMG)
	var snapshot: Dictionary = WeaponTuningServiceScript.resolve_snapshot(SMG, Ammo, attachment_state, weapon_stack)
	_expect(bool(snapshot.get("valid", false)), "SMG-S should resolve through WeaponTuningService like the pistol template.")
	_expect_close(float(snapshot.get("damage", 0.0)), 18.0, 0.001, "SMG-S snapshot damage should come from weapon tuning.")
	_expect(int(snapshot.get("magazine_capacity", 0)) == 24, "SMG-S snapshot magazine capacity should include the extended magazine bonus.")
	_expect_close(float(snapshot.get("armor_penetration_level", 0.0)), 1.0, 0.001, "SMG-S snapshot armor penetration should come from weapon tuning.")
	_expect_close(float(snapshot.get("weapon_horizontal_recoil", 0.0)), 5.5, 0.001, "SMG-S snapshot recoil should keep base tuning with the magazine attachment.")
	_expect_close(float(snapshot.get("horizontal_recoil", 0.0)), 5.5, 0.001, "SMG-S snapshot final recoil should not include ammo recoil tuning.")
	_expect((snapshot.get("attachment_ids", []) as Array).has("extended_magazine"), "SMG-S snapshot should expose applied attachment ids.")
	_expect((snapshot.get("attachment_slots", []) as Array).has("magazine"), "SMG-S snapshot should expose applied attachment slots.")


func _validate_weapon_controller_bridge() -> void:
	var controller := WeaponControllerScript.new()
	root.add_child(controller)
	var weapon_stack := _weapon_stack_with_mods(Pistol)
	var attachment_state: Dictionary = WeaponAttachmentServiceScript.modifiers_for_weapon_stack(weapon_stack, Pistol)
	if not controller.equip_weapon(Pistol, 0, attachment_state):
		_errors.append("WeaponController3D should equip a weapon with attachment modifiers.")
		_free_node(controller)
		return
	controller.reload_from_item(Ammo, 1)
	var snapshot: Dictionary = controller.get_tuning_snapshot(weapon_stack)
	_expect(int(snapshot.get("magazine_capacity", 0)) == 12, "WeaponController3D snapshot should include attachment magazine capacity.")
	_expect(snapshot.get("ammo_id", &"") == Ammo.id, "WeaponController3D snapshot should include the loaded ammo id.")
	_expect_close(float(snapshot.get("damage", 0.0)), 20.0, 0.001, "WeaponController3D snapshot should use weapon-owned damage resolution.")
	var smg_stack := _weapon_stack_with_mods(SMG)
	var smg_attachment_state: Dictionary = WeaponAttachmentServiceScript.modifiers_for_weapon_stack(smg_stack, SMG)
	if not controller.equip_weapon(SMG, 0, smg_attachment_state):
		_errors.append("WeaponController3D should equip SMG-S through the same weapon template bridge.")
	else:
		controller.reload_from_item(Ammo, 1)
		var smg_snapshot: Dictionary = controller.get_tuning_snapshot(smg_stack)
		_expect(int(smg_snapshot.get("magazine_capacity", 0)) == 24, "WeaponController3D SMG-S snapshot should include attachment magazine capacity.")
		_expect(smg_snapshot.get("ammo_id", &"") == Ammo.id, "WeaponController3D SMG-S snapshot should include the loaded ammo id.")
		_expect_close(float(smg_snapshot.get("damage", 0.0)), 18.0, 0.001, "WeaponController3D SMG-S snapshot should use weapon-owned damage resolution.")
	_free_node(controller)


func _validate_enemy_behavior_profile() -> void:
	_expect(Scavenger.behavior_profile != null, "Scavenger should have an EnemyBehaviorProfile.")
	if Scavenger.behavior_profile == null:
		return
	var body := CharacterBody3D.new()
	body.set_meta("enemy_def", Scavenger)
	var controller := EnemyControllerScript.new()
	body.add_child(controller)
	root.add_child(body)
	await process_frame
	_expect_close(controller.attack_range, Scavenger.behavior_profile.attack_range, 0.001, "EnemyController3D should read attack_range from EnemyBehaviorProfile.")
	_expect_close(controller.attack_windup_duration, Scavenger.behavior_profile.attack_windup_duration, 0.001, "EnemyController3D should read windup from EnemyBehaviorProfile.")
	_expect_close(controller.forget_distance, Scavenger.behavior_profile.forget_distance, 0.001, "EnemyController3D should read forget distance from EnemyBehaviorProfile.")
	_expect_close(controller.search_duration, Scavenger.behavior_profile.search_duration, 0.001, "EnemyController3D should read search duration from EnemyBehaviorProfile.")
	_free_node(body)


func _validate_source_boundaries() -> void:
	var item_source := FileAccess.get_file_as_string("res://scripts/items/item_def.gd")
	for required in ["weapon_profile", "armor_profile", "attachment_profile", "get_weapon_damage", "get_ammo_tag"]:
		if not item_source.contains(required):
			_errors.append("ItemDef should expose profile-backed getter or field: %s." % required)
	for forbidden in ["ammo_profile", "get_ammo_damage_multiplier", "get_ammo_spread_multiplier", "get_ammo_recoil_multiplier", "get_ammo_penetration_level", "get_ammo_weapon_wear_rate"]:
		if item_source.contains(forbidden):
			_errors.append("ItemDef should not reintroduce ammo tuning getter or profile: %s." % forbidden)
	var tuning_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_tuning_service.gd")
	for required in ["resolve_snapshot", "durability", "attachment_state", "ammo_id"]:
		if not tuning_source.contains(required):
			_errors.append("WeaponTuningService should own snapshot calculation term: %s." % required)
	for forbidden in ["ammo_damage_multiplier", "ammo_spread_multiplier", "ammo_recoil_multiplier", "ammo_penetration_level", "weapon_wear_rate"]:
		if tuning_source.contains(forbidden):
			_errors.append("WeaponTuningService should not reintroduce ammo-side tuning term: %s." % forbidden)
	for forbidden in ["Control", "InventoryEquipmentUI", "BaseStashInventoryUI", "SaveGameManager"]:
		if tuning_source.contains(forbidden):
			_errors.append("WeaponTuningService should not depend on UI or persistence class: %s." % forbidden)
	var weapon_controller_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_controller_3d.gd")
	if not weapon_controller_source.contains("get_tuning_snapshot"):
		_errors.append("WeaponController3D should expose get_tuning_snapshot instead of duplicating combat math.")
	var enemy_controller_source := FileAccess.get_file_as_string("res://scripts/ai/enemy_controller_3d.gd")
	for required in ["EnemyBehaviorProfile", "_apply_behavior_profile", "_detect_radius"]:
		if not enemy_controller_source.contains(required):
			_errors.append("EnemyController3D should route behavior tuning through %s." % required)
	var spec_source := FileAccess.get_file_as_string("res://docs/architecture/programming_spec.md")
	for required in ["Profile And Snapshot Rule", "WeaponTuningService.resolve_snapshot()", "EnemyBehaviorProfile"]:
		if not spec_source.contains(required):
			_errors.append("Programming spec should record the profile/snapshot architecture rule: %s." % required)


func _weapon_stack_with_mods(weapon_def: ItemDef) -> Dictionary:
	var stack := weapon_def.to_stack(1)
	stack["weapon_mods"] = {
		"magazine": ExtendedMagazine.to_stack(1),
	}
	return stack


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _expect_close(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		_errors.append("%s Expected %.4f, got %.4f." % [message, expected, actual])


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
