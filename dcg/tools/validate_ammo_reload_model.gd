extends SceneTree

const WeaponAmmoModelScript := preload("res://scripts/combat/weapon_ammo_model.gd")
const WeaponControllerScript := preload("res://scripts/combat/weapon_controller_3d.gd")
const DamageableScript := preload("res://scripts/combat/damageable_3d.gd")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")
const Ammo := preload("res://data/items/ammo/ammo_9mm.tres")
const Wood := preload("res://data/items/crafting/wood.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_item_ammo_data()
	_validate_ammo_model()
	_validate_weapon_controller_uses_ammo_model()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[ammo_reload_model] OK data=pistol_9mm model=reload_consume controller=model_bound boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_item_ammo_data() -> void:
	if Pistol.magazine_capacity != 8:
		_errors.append("No.5 pistol should define magazine_capacity 8.")
	if not Pistol.compatible_ammo_tags.has(&"9mm"):
		_errors.append("No.5 pistol should list 9mm as compatible ammo.")
	if Ammo.ammo_tag != &"9mm" or not Ammo.tags.has(&"9mm"):
		_errors.append("No.7 ammo should expose 9mm ammo data.")
	if Ammo.item_type != "ammo":
		_errors.append("No.7 ammo item_type should be ammo.")

	var pistol_stack := Pistol.to_stack(1)
	var ammo_stack := Ammo.to_stack(24)
	if int(pistol_stack.get("magazine_capacity", 0)) != 8:
		_errors.append("Pistol stack should carry magazine capacity for UI/validation.")
	if not (pistol_stack.get("compatible_ammo_tags", []) as Array).has(&"9mm"):
		_errors.append("Pistol stack should carry compatible ammo tags.")
	if StringName(ammo_stack.get("ammo_tag", &"")) != &"9mm":
		_errors.append("Ammo stack should carry its ammo tag.")


func _validate_ammo_model() -> void:
	var model := WeaponAmmoModelScript.new()
	model.configure_weapon(Pistol)
	var state: Dictionary = model.get_state()
	if int(state.get("magazine_capacity", 0)) != 8:
		_errors.append("WeaponAmmoModel should read pistol magazine capacity.")
	if not model.can_use_ammo(Ammo):
		_errors.append("WeaponAmmoModel should accept No.7 ammo for No.5 pistol.")
	if model.can_use_ammo(Wood):
		_errors.append("WeaponAmmoModel should reject non-ammo inventory items.")
	if not model.set_reserve_ammo(Ammo, 24):
		_errors.append("WeaponAmmoModel should store compatible reserve ammo.")
	if model.reload_from_reserve() != 8:
		_errors.append("WeaponAmmoModel should fill the 8-round pistol magazine from reserve ammo.")
	if int(model.get_state().get("loaded_ammo", 0)) != 8 or int(model.get_state().get("reserve_ammo", 0)) != 16:
		_errors.append("WeaponAmmoModel should separate loaded and reserve ammo counts.")
	if not model.consume_round():
		_errors.append("WeaponAmmoModel should consume a loaded round.")
	if int(model.get_state().get("loaded_ammo", 0)) != 7:
		_errors.append("WeaponAmmoModel should reduce loaded ammo after consumption.")


func _validate_weapon_controller_uses_ammo_model() -> void:
	var target := DamageableScript.new()
	target.max_health = 50.0
	root.add_child(target)
	target._ready()

	var weapon := WeaponControllerScript.new()
	root.add_child(weapon)
	if str(weapon.get_fire_block_reason()) != "no_weapon":
		_errors.append("WeaponController3D should start without a weapon.")
	if not weapon.equip_weapon(Pistol):
		_errors.append("WeaponController3D should equip No.5 pistol through its weapon API.")
	if str(weapon.get_fire_block_reason()) != "no_ammo":
		_errors.append("Equipped pistol should need ammo before firing.")
	if not weapon.add_reserve_ammo_from_item(Ammo, 24):
		_errors.append("WeaponController3D should accept No.7 ammo through WeaponAmmoModel.")
	if not weapon.reload_from_reserve():
		_errors.append("WeaponController3D should reload through WeaponAmmoModel.")
	if int(weapon.get("current_ammo")) != 8 or int(weapon.get("reserve_ammo")) != 16:
		_errors.append("WeaponController3D public ammo fields should mirror WeaponAmmoModel state.")
	weapon.force_cooldown_ready()
	if not weapon.fire_at(target):
		_errors.append("WeaponController3D should fire after model-backed reload.")
	if int(weapon.get("current_ammo")) != 7:
		_errors.append("WeaponController3D firing should consume loaded ammo through WeaponAmmoModel.")
	var model_state: Dictionary = weapon.get_ammo_model().call("get_state")
	if int(model_state.get("loaded_ammo", 0)) != 7:
		_errors.append("WeaponAmmoModel state should match public current_ammo after firing.")

	weapon.queue_free()
	target.queue_free()


func _validate_source_boundaries() -> void:
	var model_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_ammo_model.gd")
	for forbidden in ["Control", "InventoryEquipmentUI", "UIManager", "PlayerController3D", "LootContainer3D"]:
		if model_source.contains(forbidden):
			_errors.append("WeaponAmmoModel should stay combat-data only and independent from %s." % forbidden)

	var weapon_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_controller_3d.gd")
	for required in ["WeaponAmmoModelScript", "get_ammo_model", "add_reserve_ammo_from_item", "reload_from_reserve"]:
		if not weapon_source.contains(required):
			_errors.append("WeaponController3D should expose model-backed ammo API term: %s." % required)
	for forbidden in ["InventoryEquipmentUI", "get_inventory_model", "ContainerInventoryUI"]:
		if weapon_source.contains(forbidden):
			_errors.append("WeaponController3D should not directly read backpack/container UI: %s." % forbidden)
