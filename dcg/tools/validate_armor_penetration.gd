extends SceneTree

const ArmorMitigationServiceScript := preload("res://scripts/combat/armor_mitigation_service.gd")
const DamageEventScript := preload("res://scripts/combat/damage_event.gd")
const DamageableScript := preload("res://scripts/combat/damageable_3d.gd")
const WeaponControllerScript := preload("res://scripts/combat/weapon_controller_3d.gd")
const Pistol := preload("res://data/items/weapons/pistol_S.tres")
const Ammo := preload("res://data/items/ammo/ammo_S.tres")
const LightArmor := preload("res://data/items/armor/light_armor.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_item_data()
	_validate_service_formula()
	_validate_weapon_damage_uses_weapon_penetration()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[armor_penetration] OK data=weapon_armor formula=defense_minus_penetration damage=ammo_neutral boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_item_data() -> void:
	if Pistol.get_weapon_armor_penetration_level() != 1.0:
		_errors.append("Pistol-S should keep weapon-owned penetration level 1.")
	if LightArmor.armor_protection_level != LightArmor.defense_bonus:
		_errors.append("Light armor armor_protection_level should match defense_bonus so armor has one defense value.")
	for stack in [Ammo.to_stack(3)]:
		if stack.has("ammo_penetration_level"):
			_errors.append("Ammo stacks should not expose removed ammo_penetration_level.")
	var armor_stack := LightArmor.to_stack(1)
	if float(armor_stack.get("armor_protection_level", 0.0)) != LightArmor.armor_protection_level:
		_errors.append("Armor stacks should expose armor_protection_level for UI and planning.")


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
	var unified_armor := ArmorMitigationServiceScript.damage_after_armor(_ballistic_event(24.0, 0.0), 4.0, 4.0)
	if not is_equal_approx(unified_armor, 20.0):
		_errors.append("Armor defense and armor_protection_level should be unified, not stacked; expected 20 damage, got %.2f." % unified_armor)
	var melee_after_flat := ArmorMitigationServiceScript.damage_after_armor(DamageEventScript.new(8.0, null, null, [&"melee"]), 4.0, 2.0)
	if not is_equal_approx(melee_after_flat, 4.0):
		_errors.append("Melee hits should keep legacy flat armor reduction and skip ballistic penetration, got %.2f." % melee_after_flat)


func _validate_weapon_damage_uses_weapon_penetration() -> void:
	var baseline_damage := _direct_damage_after_one_shot(Ammo, 2.0)
	var expected_damage := float(Pistol.damage) - 1.0
	if not is_equal_approx(baseline_damage, expected_damage):
		_errors.append("Baseline ammo should deal weapon-owned penetration damage %.2f, got %.2f." % [expected_damage, baseline_damage])


func _validate_source_boundaries() -> void:
	var item_source := FileAccess.get_file_as_string("res://scripts/items/item_def.gd")
	if item_source.contains("ammo_penetration_level"):
		_errors.append("ItemDef should not reintroduce ammo_penetration_level.")
	var event_source := FileAccess.get_file_as_string("res://scripts/combat/damage_event.gd")
	for required in ["ammo_def", "armor_penetration_level"]:
		if not event_source.contains(required):
			_errors.append("DamageEvent should carry %s." % required)
	var weapon_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_controller_3d.gd")
	for required in ["_current_ammo_item", "armor_penetration_level", "get_tuning_snapshot"]:
		if not weapon_source.contains(required):
			_errors.append("WeaponController3D should attach weapon-owned penetration through %s." % required)
	var tuning_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_tuning_service.gd")
	if tuning_source.contains("ammo_penetration_level"):
		_errors.append("WeaponTuningService should not reintroduce ammo penetration tuning.")
	for required in ["weapon_armor_penetration_level", "armor_penetration_level"]:
		if not tuning_source.contains(required):
			_errors.append("WeaponTuningService should resolve weapon-owned penetration through %s." % required)


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
