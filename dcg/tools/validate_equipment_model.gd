extends SceneTree

const EquipmentModelScript := preload("res://scripts/equipment/equipment_model.gd")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")
const Knife := preload("res://data/items/weapons/combat_knife.tres")
const Ammo := preload("res://data/items/ammo/ammo_9mm.tres")
const Helmet := preload("res://data/items/armor/basic_helmet.tres")
const Armor := preload("res://data/items/armor/light_armor.tres")
const Backpack := preload("res://data/items/backpacks/small_backpack.tres")
const Wood := preload("res://data/items/crafting/wood.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_slot_setup()
	_validate_legal_equips()
	_validate_rejected_equips()
	_validate_unequip()
	_validate_stack_and_save_round_trip()
	_validate_responsibility_boundary()
	if _errors.is_empty():
		print("[equipment_model] OK slots=ready equip=legal reject=invalid save=round_trip coupling=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_slot_setup() -> void:
	var model := EquipmentModelScript.new()
	var slot_ids: Array[StringName] = model.get_slot_ids()
	for slot_id in [
		&"primary_weapon",
		&"sidearm",
		&"melee",
		&"helmet",
		&"armor",
		&"backpack",
	]:
		if not slot_ids.has(slot_id):
			_errors.append("EquipmentModel should include slot %s." % slot_id)
		if not model.is_empty(slot_id):
			_errors.append("EquipmentModel slot %s should start empty." % slot_id)


func _validate_legal_equips() -> void:
	var model := EquipmentModelScript.new()
	if not model.equip_item(&"primary_weapon", Pistol):
		_errors.append("Pistol should equip into primary weapon slot for early proof.")
	if int(model.get_slot(&"primary_weapon").get("catalog_number", 0)) != 5:
		_errors.append("Primary weapon slot should contain No.5 pistol.")
	if not model.equip_item(&"sidearm", Pistol):
		_errors.append("Pistol should equip into sidearm slot.")
	if not model.equip_item(&"melee", Knife):
		_errors.append("Combat knife should equip into melee slot.")
	if not model.equip_item(&"helmet", Helmet):
		_errors.append("Basic helmet should equip into helmet slot.")
	if not model.equip_item(&"armor", Armor):
		_errors.append("Light armor should equip into armor slot.")
	if not model.equip_item(&"backpack", Backpack):
		_errors.append("Small backpack should equip into backpack slot.")


func _validate_rejected_equips() -> void:
	var model := EquipmentModelScript.new()
	if model.equip_item(&"primary_weapon", Ammo):
		_errors.append("Ammo should not equip into weapon slots.")
	if model.equip_item(&"melee", Pistol):
		_errors.append("Pistol should not equip into melee slot.")
	if model.equip_item(&"armor", Helmet):
		_errors.append("Helmet should not equip into body armor slot.")
	if model.equip_item(&"helmet", Armor):
		_errors.append("Body armor should not equip into helmet slot.")
	if model.equip_item(&"backpack", Wood):
		_errors.append("Crafting material should not equip into backpack slot.")
	if model.equip_item(&"unknown_slot", Pistol):
		_errors.append("Unknown equipment slots should reject items.")


func _validate_unequip() -> void:
	var model := EquipmentModelScript.new()
	model.equip_item(&"sidearm", Pistol)
	var removed: Dictionary = model.unequip(&"sidearm")
	if int(removed.get("catalog_number", 0)) != 5:
		_errors.append("Unequip should return the removed No.5 pistol stack.")
	if not model.is_empty(&"sidearm"):
		_errors.append("Unequip should clear the equipment slot.")
	if not model.unequip(&"sidearm").is_empty():
		_errors.append("Unequipping an empty slot should return empty data.")


func _validate_stack_and_save_round_trip() -> void:
	var model := EquipmentModelScript.new()
	if not model.equip_stack(&"sidearm", Pistol.to_stack(1)):
		_errors.append("EquipmentModel should equip valid item stacks.")
	if model.equip_stack(&"sidearm", Ammo.to_stack(24)):
		_errors.append("EquipmentModel should reject invalid item stacks.")
	var save_data: Dictionary = model.to_save_data()
	var loaded := EquipmentModelScript.new()
	if not loaded.load_save_data(save_data):
		_errors.append("EquipmentModel should round-trip valid save data.")
	if loaded.get_equipped_item(&"sidearm") != Pistol:
		_errors.append("Loaded sidearm should be the No.5 pistol resource.")

	var invalid := EquipmentModelScript.new()
	if invalid.load_save_data({"slots": {"sidearm": {"item_path": "res://missing/nope.tres"}}}):
		_errors.append("EquipmentModel should report invalid save data.")


func _validate_responsibility_boundary() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/equipment/equipment_model.gd")
	for forbidden in [
		"Control",
		"Button",
		"UIManager",
		"InventoryEquipmentUI",
		"WeaponController3D",
		"PlayerController3D",
		"LootContainer3D",
		"SaveGameManager",
		"change_scene",
	]:
		if source.contains(forbidden):
			_errors.append("EquipmentModel should stay independent from %s." % forbidden)
