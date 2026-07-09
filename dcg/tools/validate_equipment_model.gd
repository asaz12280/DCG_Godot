extends SceneTree

const EquipmentModelScript := preload("res://scripts/equipment/equipment_model.gd")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")
const Knife := preload("res://data/items/weapons/combat_knife.tres")
const Ammo := preload("res://data/items/ammo/ammo_9mm.tres")
const Helmet := preload("res://data/items/armor/basic_helmet.tres")
const Armor := preload("res://data/items/armor/light_armor.tres")
const Backpack := preload("res://data/items/backpacks/small_backpack.tres")
const ExtendedMagazine := preload("res://data/items/attachments/extended_magazine.tres")
const BalancedGrip := preload("res://data/items/attachments/balanced_grip.tres")
const CompactMuzzle := preload("res://data/items/attachments/compact_muzzle.tres")
const ReflexSight := preload("res://data/items/attachments/reflex_sight.tres")
const StabilizingStock := preload("res://data/items/attachments/stabilizing_stock.tres")
const TargetingLaser := preload("res://data/items/attachments/targeting_laser.tres")
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
		&"weapon_mag",
		&"weapon_grip",
		&"weapon_muzzle",
		&"weapon_scope",
		&"weapon_stock",
		&"weapon_tactic",
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
	var sidearm_model := EquipmentModelScript.new()
	if not sidearm_model.equip_item(&"sidearm", Pistol):
		_errors.append("Any non-melee weapon should be allowed in sidearm.")
	if not model.equip_item(&"melee", Knife):
		_errors.append("Combat knife should equip into melee slot.")
	if not model.equip_item(&"helmet", Helmet):
		_errors.append("Basic helmet should equip into helmet slot.")
	if not model.equip_item(&"armor", Armor):
		_errors.append("Light armor should equip into armor slot.")
	if not model.equip_item(&"backpack", Backpack):
		_errors.append("Small backpack should equip into backpack slot.")
	if not model.equip_item(&"weapon_mag", ExtendedMagazine):
		_errors.append("Extended Magazine-S should equip into the dedicated weapon magazine slot.")
	if not model.equip_item(&"weapon_grip", BalancedGrip):
		_errors.append("Balanced Grip-S should equip into the dedicated weapon grip slot.")
	if not model.equip_item(&"weapon_muzzle", CompactMuzzle):
		_errors.append("Compact Muzzle-S should equip into the dedicated weapon muzzle slot.")
	if not model.equip_item(&"weapon_scope", ReflexSight):
		_errors.append("Reflex Sight-S should equip into the dedicated weapon scope slot.")
	if not model.equip_item(&"weapon_stock", StabilizingStock):
		_errors.append("Stabilizing Stock-S should equip into the dedicated weapon stock slot.")
	if not model.equip_item(&"weapon_tactic", TargetingLaser):
		_errors.append("Targeting Laser-S should equip into the dedicated weapon tactic slot.")


func _validate_rejected_equips() -> void:
	var model := EquipmentModelScript.new()
	if model.equip_item(&"primary_weapon", Ammo):
		_errors.append("Ammo should not equip into weapon slots.")
	if model.equip_item(&"melee", Pistol):
		_errors.append("Pistol should not equip into melee slot.")
	if model.equip_item(&"primary_weapon", Knife):
		_errors.append("Melee weapons should not equip into primary weapon slot.")
	if model.equip_item(&"sidearm", Knife):
		_errors.append("Melee weapons should not equip into sidearm slot.")
	if model.equip_item(&"armor", Helmet):
		_errors.append("Helmet should not equip into body armor slot.")
	if model.equip_item(&"helmet", Armor):
		_errors.append("Body armor should not equip into helmet slot.")
	if model.equip_item(&"backpack", Wood):
		_errors.append("Crafting material should not equip into backpack slot.")
	if model.equip_item(&"weapon_mag", BalancedGrip):
		_errors.append("Grip attachments should not equip into the weapon magazine slot.")
	if model.equip_item(&"weapon_grip", ExtendedMagazine):
		_errors.append("Magazine attachments should not equip into the weapon grip slot.")
	if model.equip_item(&"weapon_muzzle", BalancedGrip):
		_errors.append("Grip attachments should not equip into the weapon muzzle slot.")
	if model.equip_item(&"weapon_scope", BalancedGrip):
		_errors.append("Grip attachments should not equip into the weapon scope slot.")
	if model.equip_item(&"weapon_stock", BalancedGrip):
		_errors.append("Grip attachments should not equip into the weapon stock slot.")
	if model.equip_item(&"weapon_tactic", BalancedGrip):
		_errors.append("Grip attachments should not equip into the weapon tactic slot.")
	if model.equip_item(&"charm_1", ExtendedMagazine):
		_errors.append("Weapon magazines should no longer equip into generic charm slots.")
	if model.equip_item(&"charm_2", BalancedGrip):
		_errors.append("Weapon grips should no longer equip into generic charm slots.")
	if model.equip_item(&"charm_1", CompactMuzzle):
		_errors.append("Weapon muzzles should no longer equip into generic charm slots.")
	if model.equip_item(&"charm_2", ReflexSight):
		_errors.append("Weapon scopes should no longer equip into generic charm slots.")
	if model.equip_item(&"charm_1", StabilizingStock):
		_errors.append("Weapon stocks should no longer equip into generic charm slots.")
	if model.equip_item(&"charm_2", TargetingLaser):
		_errors.append("Weapon tactic attachments should no longer equip into generic charm slots.")
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
	var damaged_pistol := _damaged_pistol_stack()
	if not model.equip_stack(&"sidearm", damaged_pistol):
		_errors.append("EquipmentModel should equip valid item stacks.")
	if model.equip_stack(&"sidearm", Ammo.to_stack(24)):
		_errors.append("EquipmentModel should reject invalid item stacks.")
	var save_data: Dictionary = model.to_save_data()
	var saved_sidearm: Dictionary = (save_data.get("slots", {}) as Dictionary).get("sidearm", {})
	if int(saved_sidearm.get("current_durability", 0)) != 41 or int(saved_sidearm.get("max_durability", 0)) != 88:
		_errors.append("EquipmentModel save data should preserve equipped item durability.")
	var loaded := EquipmentModelScript.new()
	if not loaded.load_save_data(save_data):
		_errors.append("EquipmentModel should round-trip valid save data.")
	if loaded.get_equipped_item(&"sidearm") != Pistol:
		_errors.append("Loaded sidearm should be the No.5 pistol resource.")
	var loaded_sidearm: Dictionary = loaded.get_slot(&"sidearm")
	if int(loaded_sidearm.get("current_durability", 0)) != 41 or int(loaded_sidearm.get("max_durability", 0)) != 88:
		_errors.append("Loaded sidearm should preserve durability values.")
	var removed := loaded.unequip(&"sidearm")
	if int(removed.get("current_durability", 0)) != 41 or int(removed.get("max_durability", 0)) != 88:
		_errors.append("Unequipped sidearm stack should preserve durability values.")

	var legacy := EquipmentModelScript.new()
	var legacy_data := {
		"slots": {
			"charm_1": ExtendedMagazine.to_stack(1),
			"charm_2": BalancedGrip.to_stack(1),
			"weapon_muzzle": CompactMuzzle.to_stack(1),
			"weapon_scope": ReflexSight.to_stack(1),
			"weapon_stock": StabilizingStock.to_stack(1),
			"weapon_tactic": TargetingLaser.to_stack(1),
		},
	}
	if not legacy.load_save_data(legacy_data):
		_errors.append("EquipmentModel should migrate legacy charm weapon attachments during load.")
	if legacy.is_empty(&"weapon_mag") or legacy.is_empty(&"weapon_grip"):
		_errors.append("Legacy charm attachments should move into dedicated weapon mod slots.")
	if legacy.is_empty(&"weapon_muzzle"):
		_errors.append("Dedicated weapon muzzle slot should load valid muzzle attachments.")
	if legacy.is_empty(&"weapon_scope"):
		_errors.append("Dedicated weapon scope slot should load valid scope attachments.")
	if legacy.is_empty(&"weapon_stock"):
		_errors.append("Dedicated weapon stock slot should load valid stock attachments.")
	if legacy.is_empty(&"weapon_tactic"):
		_errors.append("Dedicated weapon tactic slot should load valid tactic attachments.")
	if not legacy.is_empty(&"charm_1") or not legacy.is_empty(&"charm_2"):
		_errors.append("Legacy weapon attachments should not remain in generic charm slots after migration.")

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


func _damaged_pistol_stack() -> Dictionary:
	var stack := Pistol.to_stack(1)
	stack["current_durability"] = 41
	stack["max_durability"] = 88
	stack["original_max_durability"] = 100
	stack["repair_max_durability_loss"] = 5
	return stack
