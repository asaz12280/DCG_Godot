extends SceneTree

const WeaponAmmoModelScript := preload("res://scripts/combat/weapon_ammo_model.gd")
const WeaponControllerScript := preload("res://scripts/combat/weapon_controller_3d.gd")
const DamageableScript := preload("res://scripts/combat/damageable_3d.gd")
const PlayerScene := preload("res://scenes/player/player_3d.tscn")
const Pistol := preload("res://data/items/weapons/pistol_S.tres")
const SMG := preload("res://data/items/weapons/smg_S.tres")
const Ammo := preload("res://data/items/ammo/ammo_S.tres")
const Wood := preload("res://data/items/crafting/wood.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_item_ammo_data()
	_validate_ammo_model()
	_validate_weapon_controller_uses_ammo_model()
	await _validate_player_weapon_magazines_are_weapon_scoped()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[ammo_reload_model] OK data=pistol_s model=reload_consume controller=model_bound boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_item_ammo_data() -> void:
	if Pistol.magazine_capacity != 8:
		_errors.append("No.5 pistol should define magazine_capacity 8.")
	if not Pistol.compatible_ammo_tags.has(&"S"):
		_errors.append("No.5 pistol should list S as compatible small-firearm ammo.")
	if not SMG.get_weapon_compatible_ammo_tags().has(&"S"):
		_errors.append("SMG-S should list S as compatible small-firearm ammo.")
	if Ammo.ammo_tag != &"S" or not Ammo.tags.has(&"S"):
		_errors.append("No.7 ammo should expose S ammo data.")
	if Ammo.item_type != "ammo":
		_errors.append("No.7 ammo item_type should be ammo.")

	var pistol_stack := Pistol.to_stack(1)
	var ammo_stack := Ammo.to_stack(24)
	if int(pistol_stack.get("magazine_capacity", 0)) != 8:
		_errors.append("Pistol stack should carry magazine capacity for UI/validation.")
	if not (pistol_stack.get("compatible_ammo_tags", []) as Array).has(&"S"):
		_errors.append("Pistol stack should carry compatible ammo tags.")
	var smg_stack := SMG.to_stack(1)
	if int(smg_stack.get("magazine_capacity", 0)) != 20:
		_errors.append("SMG stack should carry 20-round magazine capacity for UI/validation.")
	if not (smg_stack.get("compatible_ammo_tags", []) as Array).has(&"S"):
		_errors.append("SMG stack should carry compatible S ammo tags.")
	if StringName(ammo_stack.get("ammo_tag", &"")) != &"S":
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
	if model.unload_loaded_ammo() != 7:
		_errors.append("WeaponAmmoModel should unload loaded rounds for backpack recovery.")
	if int(model.get_state().get("loaded_ammo", 0)) != 0:
		_errors.append("WeaponAmmoModel should clear loaded ammo after unloading.")
	model.configure_weapon(SMG)
	if int(model.get_state().get("magazine_capacity", 0)) != 20:
		_errors.append("WeaponAmmoModel should read SMG magazine capacity.")
	if not model.can_use_ammo(Ammo):
		_errors.append("WeaponAmmoModel should accept S ammo for SMG-S.")
	if not model.set_reserve_ammo(Ammo, 24):
		_errors.append("WeaponAmmoModel should store compatible SMG reserve ammo.")
	if model.reload_from_reserve() != 20:
		_errors.append("WeaponAmmoModel should fill the 20-round SMG magazine from S ammo.")


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
	var unload_result: Dictionary = weapon.unload_loaded_ammo()
	if not bool(unload_result.get("success", false)) or int(unload_result.get("quantity", 0)) != 7:
		_errors.append("WeaponController3D should unload loaded ammo through WeaponAmmoModel.")
	if int(weapon.get("current_ammo")) != 0:
		_errors.append("WeaponController3D current_ammo should be 0 after unloading loaded ammo.")
	if not weapon.equip_weapon(SMG):
		_errors.append("WeaponController3D should equip SMG-S through its weapon API.")
	weapon.current_ammo = 0
	weapon.reserve_ammo = 0
	if weapon.has_method("_sync_ammo_result"):
		weapon.call("_sync_ammo_result")
	if not weapon.add_reserve_ammo_from_item(Ammo, 24):
		_errors.append("WeaponController3D should accept S ammo for SMG-S through WeaponAmmoModel.")
	if not weapon.reload_from_reserve():
		_errors.append("WeaponController3D should reload SMG-S through WeaponAmmoModel.")
	if int(weapon.get("current_ammo")) != 20:
		_errors.append("WeaponController3D should load 20 S-ammo rounds into SMG-S.")

	weapon.queue_free()
	target.queue_free()


func _validate_player_weapon_magazines_are_weapon_scoped() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var player := PlayerScene.instantiate()
	scene.add_child(player)
	await process_frame
	await physics_frame

	if not bool(player.call("add_item_resource", Pistol, 1)):
		_errors.append("Player ammo isolation setup should add Pistol-S.")
		_free_node(scene)
		return
	if not bool(player.call("equip_inventory_stack", 0, &"primary_weapon")):
		_errors.append("Player ammo isolation setup should equip Pistol-S primary.")
		_free_node(scene)
		return
	if not bool(player.call("add_item_resource", SMG, 1)):
		_errors.append("Player ammo isolation setup should add SMG-S.")
		_free_node(scene)
		return
	if not bool(player.call("equip_inventory_stack", 0, &"sidearm")):
		_errors.append("Player ammo isolation setup should equip SMG-S sidearm.")
		_free_node(scene)
		return
	if not bool(player.call("add_item_resource", Ammo, 8)):
		_errors.append("Player ammo isolation setup should add S ammo.")
		_free_node(scene)
		return

	player.call("switch_to_weapon_slot", &"primary_weapon")
	if not bool(player.call("reload_equipped_weapon")):
		_errors.append("Player ammo isolation should start pistol reload.")
		_free_node(scene)
		return
	var timed_actions := player.get("_timed_actions") as RefCounted
	if timed_actions == null or not bool(timed_actions.call("_complete_reload")):
		_errors.append("Player ammo isolation should complete pistol reload.")
		_free_node(scene)
		return
	var weapon := player.get_node_or_null("WeaponController3D")
	if weapon == null:
		_errors.append("Player scene should expose WeaponController3D for ammo isolation.")
		_free_node(scene)
		return
	if int(weapon.get("current_ammo")) != 8:
		_errors.append("Pistol reload should leave 8 rounds in the active pistol magazine.")
	player.call("switch_to_weapon_slot", &"sidearm")
	if int(weapon.get("current_ammo")) != 0:
		_errors.append("Switching to SMG-S should not inherit Pistol-S loaded rounds.")
	player.call("switch_to_weapon_slot", &"primary_weapon")
	if int(weapon.get("current_ammo")) != 8:
		_errors.append("Switching back to Pistol-S should restore its own loaded magazine.")
	var equipment: RefCounted = player.call("get_equipment_model")
	var pistol_stack: Dictionary = equipment.call("get_slot", &"primary_weapon")
	var pistol_ammo_state: Dictionary = pistol_stack.get("weapon_ammo_state", {}) as Dictionary
	if int(pistol_ammo_state.get("loaded_ammo", 0)) != 8:
		_errors.append("Weapon stack should persist its own weapon_ammo_state loaded count.")
	var unload_result: Dictionary = player.call("unload_equipped_weapon_ammo_to_backpack")
	if not bool(unload_result.get("success", false)) or int(unload_result.get("quantity", 0)) != 8:
		_errors.append("Player should unload active weapon ammo back into backpack.")
	if int(weapon.get("current_ammo")) != 0:
		_errors.append("Active weapon current_ammo should be 0 after player unload.")
	pistol_stack = equipment.call("get_slot", &"primary_weapon")
	pistol_ammo_state = pistol_stack.get("weapon_ammo_state", {}) as Dictionary
	if int(pistol_ammo_state.get("loaded_ammo", 0)) != 0:
		_errors.append("Weapon stack should persist unloaded ammo count.")
	var recovered_ammo := 0
	var inventory: InventoryModel = player.call("get_inventory_model")
	for stack in inventory.stacks:
		if StringName(stack.get("id", &"")) == Ammo.id:
			recovered_ammo += int(stack.get("quantity", 0))
	if recovered_ammo != 8:
		_errors.append("Unloaded weapon ammo should return to backpack as an ammo stack.")
	_free_node(scene)


func _validate_source_boundaries() -> void:
	var model_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_ammo_model.gd")
	for forbidden in ["Control", "InventoryEquipmentUI", "UIManager", "PlayerController3D", "LootContainer3D"]:
		if model_source.contains(forbidden):
			_errors.append("WeaponAmmoModel should stay combat-data only and independent from %s." % forbidden)

	var weapon_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_controller_3d.gd")
	for required in ["WeaponAmmoModelScript", "get_ammo_model", "add_reserve_ammo_from_item", "reload_from_reserve", "unload_loaded_ammo"]:
		if not weapon_source.contains(required):
			_errors.append("WeaponController3D should expose model-backed ammo API term: %s." % required)
	for forbidden in ["InventoryEquipmentUI", "get_inventory_model", "ContainerInventoryUI"]:
		if weapon_source.contains(forbidden):
			_errors.append("WeaponController3D should not directly read backpack/container UI: %s." % forbidden)


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
