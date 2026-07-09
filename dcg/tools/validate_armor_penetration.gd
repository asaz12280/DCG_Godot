extends SceneTree

const ArmorMitigationServiceScript := preload("res://scripts/combat/armor_mitigation_service.gd")
const DamageEventScript := preload("res://scripts/combat/damage_event.gd")
const DamageableScript := preload("res://scripts/combat/damageable_3d.gd")
const WeaponControllerScript := preload("res://scripts/combat/weapon_controller_3d.gd")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")
const Ammo := preload("res://data/items/ammo/ammo_9mm.tres")
const PolishedAmmo := preload("res://data/items/ammo/ammo_9mm_polished.tres")
const LightArmor := preload("res://data/items/armor/light_armor.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_item_data()
	_validate_service_formula()
	_validate_weapon_damage_uses_loaded_ammo_penetration()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[armor_penetration] OK data=ammo_armor formula=defense_minus_penetration damage=loaded_ammo boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_item_data() -> void:
	if Ammo.ammo_penetration_level != 1.0:
		_errors.append("Baseline Ammo-S should be penetration level 1.")
	if PolishedAmmo.ammo_penetration_level <= Ammo.ammo_penetration_level:
		_errors.append("Polished Ammo-S should have higher penetration than baseline Ammo-S.")
	if LightArmor.armor_protection_level != LightArmor.defense_bonus:
		_errors.append("Light armor armor_protection_level should match defense_bonus so armor has one defense value.")
	var ammo_stack := PolishedAmmo.to_stack(3)
	if float(ammo_stack.get("ammo_penetration_level", 0.0)) != PolishedAmmo.ammo_penetration_level:
		_errors.append("Ammo stacks should expose ammo_penetration_level for UI and planning.")
	var armor_stack := LightArmor.to_stack(1)
	if float(armor_stack.get("armor_protection_level", 0.0)) != LightArmor.armor_protection_level:
		_errors.append("Armor stacks should expose armor_protection_level for UI and planning.")
	if float(armor_stack.get("defense_bonus", 0.0)) != LightArmor.defense_bonus:
		_errors.append("Armor stacks should expose the same data-driven defense_bonus.")


func _validate_service_formula() -> void:
	var full_damage := ArmorMitigationServiceScript.damage_after_armor(_ballistic_event(24.0, 2.0), 0.0, 2.0)
	if not is_equal_approx(full_damage, 24.0):
		_errors.append("Penetration equal to protection should deal full damage, got %.2f." % full_damage)
	var reduced_damage := ArmorMitigationServiceScript.damage_after_armor(_ballistic_event(24.0, 1.0), 0.0, 2.0)
	if not is_equal_approx(reduced_damage, 23.0):
		_errors.append("One remaining protection should reduce 24 damage to 23, got %.2f." % reduced_damage)
	var weak_damage := ArmorMitigationServiceScript.damage_after_armor(_ballistic_event(24.0, 0.0), 0.0, 2.0)
	if not is_equal_approx(weak_damage, 22.0):
		_errors.append("Two remaining protection should reduce 24 damage to 22, got %.2f." % weak_damage)
	var user_example := ArmorMitigationServiceScript.damage_after_armor(_ballistic_event(5.0, 4.0), 0.0, 5.0)
	if not is_equal_approx(user_example, 4.0):
		_errors.append("User example should deal 4 damage from 5 damage, 4 penetration, 5 defense; got %.2f." % user_example)
	var critical_example := ArmorMitigationServiceScript.damage_after_armor(_ballistic_event(10.0, 4.0), 0.0, 5.0)
	if not is_equal_approx(critical_example, 9.0):
		_errors.append("Critical user example should deal 9 damage from 10 damage, 4 penetration, 5 defense; got %.2f." % critical_example)
	var unified_armor := ArmorMitigationServiceScript.damage_after_armor(_ballistic_event(24.0, 0.0), 4.0, 4.0)
	if not is_equal_approx(unified_armor, 20.0):
		_errors.append("Armor defense and armor_protection_level should be unified, not stacked; expected 20 damage, got %.2f." % unified_armor)
	var melee_after_flat := ArmorMitigationServiceScript.damage_after_armor(DamageEventScript.new(8.0, null, null, [&"melee"]), 4.0, 2.0)
	if not is_equal_approx(melee_after_flat, 4.0):
		_errors.append("Melee hits should keep legacy flat armor reduction and skip ballistic penetration, got %.2f." % melee_after_flat)


func _validate_weapon_damage_uses_loaded_ammo_penetration() -> void:
	var baseline_damage := _direct_damage_after_one_shot(Ammo, 2.0)
	var polished_damage := _direct_damage_after_one_shot(PolishedAmmo, 2.0)
	if not is_equal_approx(baseline_damage, 23.0):
		_errors.append("Baseline penetration 1 should deal 23 damage into protection 2, got %.2f." % baseline_damage)
	var expected_polished := float(Pistol.damage) * PolishedAmmo.ammo_damage_multiplier
	if not is_equal_approx(polished_damage, expected_polished):
		_errors.append("Polished penetration 2 should bypass protection 2 and deal %.2f damage, got %.2f." % [expected_polished, polished_damage])
	if polished_damage <= baseline_damage:
		_errors.append("Higher penetration ammo should outperform baseline ammo against stronger armor.")


func _validate_source_boundaries() -> void:
	var item_source := FileAccess.get_file_as_string("res://scripts/items/item_def.gd")
	for required in ["ammo_penetration_level", "armor_protection_level"]:
		if not item_source.contains(required):
			_errors.append("ItemDef should own data field %s." % required)
	var event_source := FileAccess.get_file_as_string("res://scripts/combat/damage_event.gd")
	for required in ["ammo_def", "armor_penetration_level"]:
		if not event_source.contains(required):
			_errors.append("DamageEvent should carry %s." % required)
	var weapon_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_controller_3d.gd")
	for required in ["_current_ammo_item", "armor_penetration_level", "get_tuning_snapshot"]:
		if not weapon_source.contains(required):
			_errors.append("WeaponController3D should attach loaded ammo penetration through %s." % required)
	var tuning_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_tuning_service.gd")
	for required in ["ammo_penetration_level", "get_ammo_penetration_level", "armor_penetration_level"]:
		if not tuning_source.contains(required):
			_errors.append("WeaponTuningService should resolve loaded ammo penetration through %s." % required)
	var service_source := FileAccess.get_file_as_string("res://scripts/combat/armor_mitigation_service.gd")
	for forbidden in ["InventoryModel", "SaveGameManager", "StatusTopMenuPanel", "PlayerController3D"]:
		if service_source.contains(forbidden):
			_errors.append("ArmorMitigationService should stay combat-math only and not depend on %s." % forbidden)
	for path in [
		"res://scripts/combat/damageable_3d.gd",
		"res://scripts/ai/enemy_damageable_3d.gd",
		"res://scripts/player/player_equipment_controller_3d.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		if not source.contains("ArmorMitigationServiceScript.damage_after_armor"):
			_errors.append("%s should use shared armor mitigation." % path)
	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	if not player_source.contains("_equipment.damage_after_armor"):
		_errors.append("PlayerController3D should bridge armor mitigation through PlayerEquipmentController3D.")


func _direct_damage_after_one_shot(ammo_def: ItemDef, armor_protection_level: float) -> float:
	var target := DamageableScript.new()
	target.max_health = 100.0
	target.armor_protection_level = armor_protection_level
	root.add_child(target)
	target._ready()
	var weapon := _weapon_with_loaded_ammo(ammo_def)
	root.add_child(weapon)
	weapon.force_cooldown_ready()
	if not weapon.fire_at(target):
		_errors.append("WeaponController3D should fire directly with %s." % ammo_def.resource_path)
	var damage := 100.0 - float(target.current_health)
	_free_node(weapon)
	_free_node(target)
	return damage


func _weapon_with_loaded_ammo(ammo_def: ItemDef) -> WeaponController3D:
	var weapon := WeaponControllerScript.new()
	var pistol := Pistol.duplicate() as ItemDef
	pistol.weapon_profile = Pistol.weapon_profile.duplicate(true)
	pistol.weapon_profile.critical_chance = 0.0
	pistol.weapon_profile.projectile_pierce_chance = 0.0
	weapon.weapon_def = pistol
	weapon.fire_cooldown_seconds = 0.0
	weapon.equip_weapon(pistol)
	var moved := weapon.reload_from_item(ammo_def, 1)
	if moved != 1:
		_errors.append("Weapon should load one compatible ammo round for armor penetration validation.")
	return weapon


func _ballistic_event(amount: float, penetration_level: float) -> DamageEvent:
	var event: DamageEvent = DamageEventScript.new(amount, null, Pistol, [&"gun", &"validation"])
	event.ammo_def = Ammo
	event.armor_penetration_level = penetration_level
	return event


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
