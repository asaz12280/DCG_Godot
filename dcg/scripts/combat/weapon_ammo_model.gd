class_name WeaponAmmoModel
extends RefCounted

signal changed

var weapon_def: ItemDef = null
var ammo_def: ItemDef = null
var base_magazine_capacity: int = 0
var magazine_capacity_bonus: int = 0
var magazine_capacity: int = 0
var loaded_ammo: int = 0
var reserve_ammo: int = 0
var compatible_ammo_tags: Array[StringName] = []


func configure_weapon(item_def: ItemDef, keep_counts: bool = false, capacity_bonus: int = 0) -> void:
	weapon_def = item_def
	base_magazine_capacity = _weapon_capacity(item_def)
	magazine_capacity_bonus = maxi(capacity_bonus, 0)
	magazine_capacity = base_magazine_capacity + magazine_capacity_bonus
	compatible_ammo_tags = _weapon_ammo_tags(item_def)
	if not keep_counts:
		loaded_ammo = 0
		reserve_ammo = 0
	else:
		var excess_loaded := maxi(loaded_ammo - magazine_capacity, 0)
		loaded_ammo = clampi(loaded_ammo, 0, magazine_capacity)
		reserve_ammo += excess_loaded
		reserve_ammo = maxi(reserve_ammo, 0)
	if ammo_def != null and not can_use_ammo(ammo_def):
		ammo_def = null
	changed.emit()


func clear_weapon(keep_counts: bool = true) -> void:
	weapon_def = null
	base_magazine_capacity = 0
	magazine_capacity_bonus = 0
	magazine_capacity = 0
	compatible_ammo_tags.clear()
	if not keep_counts:
		ammo_def = null
		loaded_ammo = 0
		reserve_ammo = 0
	changed.emit()


func set_counts(loaded_count: int, reserve_count: int) -> void:
	loaded_ammo = clampi(loaded_count, 0, magazine_capacity if magazine_capacity > 0 else maxi(loaded_count, 0))
	reserve_ammo = maxi(reserve_count, 0)
	changed.emit()


func set_reserve_ammo(ammo_item: ItemDef, quantity: int) -> bool:
	if not can_use_ammo(ammo_item):
		return false
	ammo_def = ammo_item
	reserve_ammo = maxi(quantity, 0)
	changed.emit()
	return true


func add_reserve_ammo(ammo_item: ItemDef, quantity: int) -> bool:
	if quantity <= 0 or not can_use_ammo(ammo_item):
		return false
	ammo_def = ammo_item
	reserve_ammo += quantity
	changed.emit()
	return true


func can_use_ammo(ammo_item: ItemDef) -> bool:
	if weapon_def == null or ammo_item == null or ammo_item.item_type != "ammo":
		return false
	var ammo_tags := _ammo_tags(ammo_item)
	for tag in ammo_tags:
		if compatible_ammo_tags.has(tag):
			return true
	return false


func can_fire() -> bool:
	return weapon_def != null and loaded_ammo > 0


func consume_round() -> bool:
	if not can_fire():
		return false
	loaded_ammo = maxi(loaded_ammo - 1, 0)
	changed.emit()
	return true


func can_reload() -> bool:
	return weapon_def != null and magazine_capacity > 0 and loaded_ammo < magazine_capacity and reserve_ammo > 0


func reload_from_reserve() -> int:
	if not can_reload():
		return 0
	var needed := magazine_capacity - loaded_ammo
	var moved := mini(needed, reserve_ammo)
	loaded_ammo += moved
	reserve_ammo -= moved
	changed.emit()
	return moved


func get_state() -> Dictionary:
	return {
		"weapon_id": weapon_def.id if weapon_def != null else &"",
		"ammo_id": ammo_def.id if ammo_def != null else &"",
		"base_magazine_capacity": base_magazine_capacity,
		"magazine_capacity_bonus": magazine_capacity_bonus,
		"magazine_capacity": magazine_capacity,
		"loaded_ammo": loaded_ammo,
		"reserve_ammo": reserve_ammo,
		"compatible_ammo_tags": compatible_ammo_tags.duplicate(),
	}


func _weapon_capacity(item_def: ItemDef) -> int:
	if item_def == null or item_def.item_type != "weapon":
		return 0
	return item_def.get_weapon_magazine_capacity()


func _weapon_ammo_tags(item_def: ItemDef) -> Array[StringName]:
	var result: Array[StringName] = []
	if item_def == null:
		return result
	for tag in item_def.get_weapon_compatible_ammo_tags():
		if not result.has(tag):
			result.append(tag)
	if result.is_empty():
		for tag in item_def.tags:
			if tag != &"gun" and tag != &"pistol" and tag != &"melee" and not result.has(tag):
				result.append(tag)
	return result


func _ammo_tags(ammo_item: ItemDef) -> Array[StringName]:
	var result: Array[StringName] = []
	if ammo_item == null:
		return result
	var ammo_tag := ammo_item.get_ammo_tag()
	if ammo_tag != &"":
		result.append(ammo_tag)
	for tag in ammo_item.tags:
		if not result.has(tag):
			result.append(tag)
	return result
