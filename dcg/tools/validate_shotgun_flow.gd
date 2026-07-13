extends SceneTree

const WeaponControllerScript := preload("res://scripts/combat/weapon_controller_3d.gd")
const WeaponTuningServiceScript := preload("res://scripts/combat/weapon_tuning_service.gd")
const WeaponAttachmentServiceScript := preload("res://scripts/combat/weapon_attachment_service.gd")
const ItemCodexCatalogScript := preload("res://scripts/ui/item_codex_catalog.gd")
const ItemInspectionSnapshotBuilderScript := preload("res://scripts/ui/item_inspection_snapshot_builder.gd")
const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const Pistol := preload("res://data/items/weapons/pistol_S.tres")
const SMG := preload("res://data/items/weapons/smg_S.tres")
const Shotgun := preload("res://data/items/weapons/shotgun_SG.tres")
const AmmoSG := preload("res://data/items/ammo/ammo_SG.tres")
const ExtendedMagazine := preload("res://data/items/attachments/extended_magazine.tres")
const OrangeCrateTable := preload("res://data/loot_tables/crate_orange_shotgun_kit.tres")

var _errors: Array[String] = []


class DamageTarget:
	extends Node

	var hit_count := 0
	var total_damage := 0.0

	func apply_damage(event: DamageEvent) -> bool:
		hit_count += 1
		total_damage += event.amount
		return true


func _initialize() -> void:
	_validate_profiles_and_snapshot()
	_validate_runtime_volley()
	_validate_attachment_and_codex()
	_validate_orange_crate()
	if _errors.is_empty():
		print("[shotgun_flow] OK pistol=1 smg=1 shotgun=5 ammo=one_round spread=40_degrees range=400 attachment=capacity_plus_4 codex=covered orange_crate=kit vfx=reused")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _validate_profiles_and_snapshot() -> void:
	var pistol_snapshot := WeaponTuningServiceScript.resolve_snapshot(Pistol)
	var smg_snapshot := WeaponTuningServiceScript.resolve_snapshot(SMG)
	var shotgun_snapshot := WeaponTuningServiceScript.resolve_snapshot(Shotgun, AmmoSG)
	_expect(int(pistol_snapshot.get("projectiles_per_shot", 0)) == 1, "Pistol-S should fire one projectile per shot.")
	_expect(int(smg_snapshot.get("projectiles_per_shot", 0)) == 1, "SMG-S should fire one projectile per shot.")
	_expect(int(shotgun_snapshot.get("projectiles_per_shot", 0)) == 5, "Shotgun-SG should fire five projectiles per shot.")
	_expect(is_equal_approx(float(shotgun_snapshot.get("projectile_spread_degrees", 0.0)), 40.0), "Shotgun-SG should expose a 40 degree projectile fan.")
	_expect(is_equal_approx(float(shotgun_snapshot.get("projectile_range", 0.0)), 400.0), "Shotgun-SG should use a 400-unit projectile range.")
	_expect(Shotgun.get_weapon_compatible_ammo_tags().has(&"SG") and AmmoSG.get_ammo_tag() == &"SG", "Shotgun-SG should use Ammo-SG only.")
	var shotgun_vfx := Shotgun.get_weapon_vfx_profile()
	var pistol_vfx := Pistol.get_weapon_vfx_profile()
	_expect(shotgun_vfx != null and pistol_vfx != null and shotgun_vfx.resource_path == pistol_vfx.resource_path, "Shotgun-SG should reuse the approved Pistol-S firearm VFX profile.")


func _validate_runtime_volley() -> void:
	var weapon := WeaponControllerScript.new()
	root.add_child(weapon)
	_expect(weapon.equip_weapon(Shotgun), "WeaponController3D should equip Shotgun-SG.")
	_expect(weapon.set_reserve_ammo_from_item(AmmoSG, 5), "Shotgun-SG should accept Ammo-SG reserve ammo.")
	_expect(weapon.reload_from_reserve(), "Shotgun-SG should reload Ammo-SG.")
	var directions: Array = weapon.call("_projectile_directions", Vector3.FORWARD)
	_expect(directions.size() == 5, "Shotgun-SG direction resolver should build five projectile directions.")
	if directions.size() == 5:
		_expect((directions[0] as Vector3).distance_to(directions[4] as Vector3) > 0.1, "Shotgun-SG projectiles should form a visible fan instead of overlapping.")
	var target := DamageTarget.new()
	root.add_child(target)
	var ammo_before := int(weapon.get("current_ammo"))
	weapon.force_cooldown_ready()
	_expect(weapon.fire_at(target), "Shotgun-SG direct fire should hit a valid target.")
	_expect(target.hit_count == 5, "One Shotgun-SG shot should apply five projectile damage events.")
	_expect(int(weapon.get("current_ammo")) == ammo_before - 1, "One Shotgun-SG volley should consume one loaded shell.")
	_expect(int(weapon.last_fire_result.get("projectiles_fired", 0)) == 5, "Shotgun-SG fire result should report five projectiles.")
	_free_node(target)
	_free_node(weapon)


func _validate_attachment_and_codex() -> void:
	var shotgun_stack := Shotgun.to_stack(1)
	shotgun_stack["weapon_mods"] = {"magazine": ExtendedMagazine.to_stack(1)}
	var modifiers := WeaponAttachmentServiceScript.modifiers_for_weapon_stack(shotgun_stack, Shotgun)
	var snapshot := WeaponTuningServiceScript.resolve_snapshot(Shotgun, AmmoSG, modifiers, shotgun_stack)
	_expect(int(modifiers.get("magazine_capacity_bonus", 0)) == 4, "Extended Magazine-S should be compatible with Shotgun-SG.")
	_expect(int(snapshot.get("magazine_capacity", 0)) == 9, "Extended Magazine-S should raise Shotgun-SG capacity from 5 to 9.")
	var catalog := ItemCodexCatalogScript.new()
	catalog.reload()
	_expect(catalog.get_item_by_id(&"shotgun_SG") == Shotgun, "Item codex should include Shotgun-SG.")
	_expect(catalog.get_item_by_id(&"ammo_SG") == AmmoSG, "Item codex should include Ammo-SG.")
	_expect(catalog.get_item_by_id(&"extended_magazine") == ExtendedMagazine, "Item codex should include Extended Magazine-S.")
	var owner := Node.new()
	root.add_child(owner)
	var inspection := ItemInspectionSnapshotBuilderScript.build(owner, ExtendedMagazine.to_stack(1))
	var fields: Dictionary = inspection.get("inspection_fields", {}) as Dictionary
	_expect(fields.has(&"attachment_magazine_bonus"), "Extended Magazine-S codex information should show its magazine capacity bonus.")
	_free_node(owner)


func _validate_orange_crate() -> void:
	var rolled := OrangeCrateTable.roll(1, 712)
	var quantities_by_path: Dictionary = {}
	for stack in rolled:
		quantities_by_path[str(stack.get("resource_path", stack.get("item_path", "")))] = int(stack.get("quantity", 0))
	_expect(int(quantities_by_path.get(Shotgun.resource_path, 0)) == 1, "Orange shotgun crate should contain one Shotgun-SG.")
	_expect(int(quantities_by_path.get(AmmoSG.resource_path, 0)) == 20, "Orange shotgun crate should contain twenty Ammo-SG shells.")
	_expect(int(quantities_by_path.get(ExtendedMagazine.resource_path, 0)) == 1, "Orange shotgun crate should contain one Extended Magazine-S.")
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	var container := scene.get_node_or_null("SceneProps/OrangeShotgunCache")
	_expect(container != null, "Gameplay scene should include OrangeShotgunCache.")
	if container != null:
		_expect(not bool(container.get("is_locked")) and container.get("required_key") == null, "OrangeShotgunCache should remain unlocked.")
		var table := container.get("loot_table") as Resource
		_expect(table != null and table.resource_path == OrangeCrateTable.resource_path, "OrangeShotgunCache should use the shotgun kit loot table.")
	_free_node(scene)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
