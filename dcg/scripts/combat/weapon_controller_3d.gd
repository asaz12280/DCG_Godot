class_name WeaponController3D
extends Node3D

const DamageEventScript := preload("res://scripts/combat/damage_event.gd")
const WeaponAmmoModelScript := preload("res://scripts/combat/weapon_ammo_model.gd")
const WeaponTuningServiceScript := preload("res://scripts/combat/weapon_tuning_service.gd")
const DEFAULT_PROJECTILE_SCENE := preload("res://scenes/combat/projectile_3d.tscn")
const DEFAULT_SHOT_FEEDBACK_SCENE := preload("res://scenes/combat/shot_feedback_3d.tscn")

signal fired(item_def: ItemDef)
signal hit(target: Node, event: DamageEvent)
signal missed(item_def: ItemDef)
signal fire_blocked(reason: StringName)
signal reloaded(rounds_loaded: int, current: int, reserve: int)
signal reload_blocked(reason: StringName)

@export var weapon_def: ItemDef
@export var fallback_damage: float = 10.0
@export var weapon_range: float = 28.0
@export var projectile_scene: PackedScene = DEFAULT_PROJECTILE_SCENE
@export var shot_feedback_scene: PackedScene = DEFAULT_SHOT_FEEDBACK_SCENE
@export_range(0.0, 5.0, 0.01) var fire_cooldown_seconds := 0.28
@export_range(0, 999, 1) var magazine_size := 8
@export_range(0, 999, 1) var magazine_capacity_bonus := 0
@export_range(0, 999, 1) var current_ammo := 0
@export_range(0, 999, 1) var reserve_ammo := 0

var last_fire_result := {
	"fired": false,
	"hit": false,
	"blocked_reason": "",
	"current_ammo": 0,
	"reserve_ammo": 0,
}
var last_reload_result := {
	"reloaded": false,
	"blocked_reason": "",
	"rounds_loaded": 0,
	"current_ammo": 0,
	"reserve_ammo": 0,
}

var _last_fire_time := -9999.0
var _ammo_model := WeaponAmmoModelScript.new()
var _attachment_modifiers: Dictionary = {}


func _init() -> void:
	_connect_ammo_model()


func _ready() -> void:
	_connect_ammo_model()
	_apply_weapon_tuning_from_def()
	_sync_ammo_model_from_public_counts()


func fire_at(target: Node) -> bool:
	if not _begin_fire_attempt():
		return false
	var event := _make_damage_event()
	var damage_target := _resolve_damage_target(target)
	if damage_target == null:
		fired.emit(weapon_def)
		missed.emit(weapon_def)
		_record_fire_result(false, "")
		return false
	var did_hit: bool = damage_target.apply_damage(event)
	fired.emit(weapon_def)
	if did_hit:
		hit.emit(damage_target, event)
	else:
		missed.emit(weapon_def)
	_record_fire_result(did_hit, "")
	return did_hit


func fire_forward(origin: Vector3, direction: Vector3, _space_state: PhysicsDirectSpaceState3D) -> bool:
	if not _begin_fire_attempt():
		return false
	if projectile_scene == null or direction == Vector3.ZERO:
		fired.emit(weapon_def)
		missed.emit(weapon_def)
		_record_fire_result(false, "")
		return false
	if not _spawn_projectile(origin, direction.normalized()):
		fired.emit(weapon_def)
		missed.emit(weapon_def)
		_record_fire_result(false, "")
		return false
	_spawn_shot_feedback(origin, direction.normalized())
	fired.emit(weapon_def)
	_record_fire_result(false, "")
	return true


func can_fire() -> bool:
	return get_fire_block_reason() == &""


func get_fire_block_reason() -> StringName:
	_sync_ammo_model_from_public_counts()
	if weapon_def == null:
		return &"no_weapon"
	if not _ammo_model.can_fire():
		return &"no_ammo"
	if _cooldown_remaining() > 0.0:
		return &"cooldown"
	return &""


func get_reload_block_reason() -> StringName:
	_sync_ammo_model_from_public_counts()
	if weapon_def == null:
		return &"no_weapon"
	if magazine_size <= 0 or current_ammo >= magazine_size:
		return &"magazine_full"
	if reserve_ammo <= 0:
		return &"no_ammo"
	return &""


func equip_weapon(item_def: ItemDef, capacity_bonus: int = 0, attachment_modifiers: Dictionary = {}) -> bool:
	if item_def == null or item_def.item_type != "weapon":
		clear_weapon()
		return false
	var loaded_count := current_ammo
	var reserve_count := reserve_ammo
	weapon_def = item_def
	_attachment_modifiers = _attachment_modifiers_with_capacity(capacity_bonus, attachment_modifiers)
	var snapshot := get_tuning_snapshot()
	magazine_capacity_bonus = maxi(int(snapshot.get("magazine_capacity_bonus", capacity_bonus)), 0)
	_apply_weapon_tuning_from_def()
	_ammo_model.configure_weapon(item_def, true, magazine_capacity_bonus)
	_ammo_model.set_counts(loaded_count, reserve_count)
	_sync_public_ammo_counts()
	return true


func clear_weapon() -> void:
	weapon_def = null
	magazine_capacity_bonus = 0
	_attachment_modifiers = {}
	_ammo_model.clear_weapon(true)
	_sync_public_ammo_counts()


func has_weapon() -> bool:
	return weapon_def != null


func get_ammo_model() -> RefCounted:
	return _ammo_model


func get_tuning_snapshot(durability_state: Dictionary = {}) -> Dictionary:
	return WeaponTuningServiceScript.resolve_snapshot(weapon_def, _current_ammo_item(), _attachment_modifiers, durability_state)


func set_reserve_ammo_from_item(ammo_item: ItemDef, quantity: int) -> bool:
	_sync_ammo_model_from_public_counts()
	var result := _ammo_model.set_reserve_ammo(ammo_item, quantity)
	_sync_public_ammo_counts()
	return result


func add_reserve_ammo_from_item(ammo_item: ItemDef, quantity: int) -> bool:
	_sync_ammo_model_from_public_counts()
	var result := _ammo_model.add_reserve_ammo(ammo_item, quantity)
	_sync_public_ammo_counts()
	return result


func reload_from_reserve() -> bool:
	_sync_ammo_model_from_public_counts()
	var block_reason := get_reload_block_reason()
	if block_reason != &"":
		_record_reload_result(false, block_reason, 0)
		reload_blocked.emit(block_reason)
		return false
	var moved := _ammo_model.reload_from_reserve()
	if moved <= 0:
		_record_reload_result(false, &"no_ammo", 0)
		reload_blocked.emit(&"no_ammo")
		return false
	_sync_public_ammo_counts()
	_record_reload_result(true, &"", moved)
	reloaded.emit(moved, current_ammo, reserve_ammo)
	return true


func reload_from_item(ammo_item: ItemDef, quantity: int) -> int:
	_sync_ammo_model_from_public_counts()
	if weapon_def == null:
		_record_reload_result(false, &"no_weapon", 0)
		reload_blocked.emit(&"no_weapon")
		return 0
	if magazine_size <= 0 or current_ammo >= magazine_size:
		_record_reload_result(false, &"magazine_full", 0)
		reload_blocked.emit(&"magazine_full")
		return 0
	if quantity <= 0:
		_record_reload_result(false, &"no_ammo", 0)
		reload_blocked.emit(&"no_ammo")
		return 0
	if not _ammo_model.can_use_ammo(ammo_item):
		_record_reload_result(false, &"incompatible_ammo", 0)
		reload_blocked.emit(&"incompatible_ammo")
		return 0

	var rounds_requested := mini(magazine_size - current_ammo, quantity)
	if not _ammo_model.add_reserve_ammo(ammo_item, rounds_requested):
		_record_reload_result(false, &"incompatible_ammo", 0)
		reload_blocked.emit(&"incompatible_ammo")
		return 0
	var moved := _ammo_model.reload_from_reserve()
	_sync_public_ammo_counts()
	if moved <= 0:
		_record_reload_result(false, &"no_ammo", 0)
		reload_blocked.emit(&"no_ammo")
		return 0
	_record_reload_result(true, &"", moved)
	reloaded.emit(moved, current_ammo, reserve_ammo)
	return moved


func force_cooldown_ready() -> void:
	_last_fire_time = -9999.0


func _make_damage_event() -> DamageEvent:
	var snapshot := get_tuning_snapshot()
	var damage := maxf(float(snapshot.get("damage", fallback_damage)), 0.0)
	if not bool(snapshot.get("valid", false)):
		damage = fallback_damage
	var tags: Array[StringName] = []
	var critical_chance := WeaponTuningServiceScript.chance_percent(float(snapshot.get("critical_chance", 0.0)))
	var projectile_pierce_chance := WeaponTuningServiceScript.chance_percent(float(snapshot.get("projectile_pierce_chance", 0.0)))
	if weapon_def != null:
		tags = weapon_def.tags.duplicate()
	var is_critical := WeaponTuningServiceScript.chance_succeeds(critical_chance)
	if is_critical:
		damage *= WeaponTuningServiceScript.CRITICAL_DAMAGE_MULTIPLIER
	var event: DamageEvent = DamageEventScript.new(damage, get_parent(), weapon_def, tags)
	var penetration := maxf(float(snapshot.get("armor_penetration_level", 0.0)), 0.0)
	event.critical_chance = critical_chance
	event.is_critical = is_critical
	event.projectile_pierce_chance = projectile_pierce_chance
	var ammo_item := _current_ammo_item()
	if ammo_item != null:
		event.ammo_def = ammo_item
	event.armor_penetration_level = penetration
	return event


func _current_ammo_damage_multiplier() -> float:
	var ammo_item := _current_ammo_item()
	if ammo_item == null:
		return 1.0
	return ammo_item.get_ammo_damage_multiplier()


func _current_ammo_item() -> ItemDef:
	var ammo_item := _ammo_model.ammo_def
	if ammo_item == null or ammo_item.item_type != "ammo":
		return null
	return ammo_item


func _begin_fire_attempt() -> bool:
	var block_reason := get_fire_block_reason()
	if block_reason != &"":
		last_fire_result = {
			"fired": false,
			"hit": false,
			"blocked_reason": str(block_reason),
			"current_ammo": current_ammo,
			"reserve_ammo": reserve_ammo,
		}
		fire_blocked.emit(block_reason)
		return false
	_ammo_model.consume_round()
	_sync_public_ammo_counts()
	_last_fire_time = _now_seconds()
	return true


func _apply_shot_to_target(target: Node) -> bool:
	var event := _make_damage_event()
	var damage_target := _resolve_damage_target(target)
	if damage_target == null:
		fired.emit(weapon_def)
		missed.emit(weapon_def)
		_record_fire_result(false, "")
		return false
	var did_hit: bool = damage_target.apply_damage(event)
	fired.emit(weapon_def)
	if did_hit:
		hit.emit(damage_target, event)
	else:
		missed.emit(weapon_def)
	_record_fire_result(did_hit, "")
	return did_hit


func _spawn_projectile(origin: Vector3, direction: Vector3) -> bool:
	var projectile := projectile_scene.instantiate()
	if not (projectile is Node3D):
		if projectile != null:
			projectile.queue_free()
		return false
	var parent := get_tree().current_scene if is_inside_tree() and get_tree().current_scene != null else null
	if parent == null and get_parent() != null:
		parent = get_parent().get_parent() if get_parent().get_parent() != null else get_parent()
	if parent == null:
		return false
	parent.add_child(projectile)
	var event := _make_damage_event()
	if projectile.has_method("setup"):
		projectile.call("setup", origin, direction, event, weapon_def, get_parent())
	else:
		projectile.global_position = origin
	if _object_has_property(projectile, &"max_distance"):
		projectile.set("max_distance", maxf(weapon_range, 0.0))
	if projectile.has_signal("projectile_hit"):
		projectile.projectile_hit.connect(_on_projectile_hit)
	if projectile.has_signal("projectile_missed"):
		projectile.projectile_missed.connect(_on_projectile_missed)
	return true


func _spawn_shot_feedback(origin: Vector3, direction: Vector3) -> void:
	if shot_feedback_scene == null:
		return
	var feedback := shot_feedback_scene.instantiate()
	if not (feedback is Node3D):
		if feedback != null:
			feedback.queue_free()
		return
	var parent := get_tree().current_scene if is_inside_tree() and get_tree().current_scene != null else null
	if parent == null and get_parent() != null:
		parent = get_parent().get_parent() if get_parent().get_parent() != null else get_parent()
	if parent == null:
		return
	parent.add_child(feedback)
	if feedback.has_method("setup"):
		feedback.call("setup", origin, direction)
	else:
		feedback.global_position = origin


func _on_projectile_hit(target: Node, _event: DamageEvent) -> void:
	hit.emit(target, _event)
	_record_fire_result(true, "")


func _on_projectile_missed() -> void:
	missed.emit(weapon_def)
	_record_fire_result(false, "")


func _record_fire_result(did_hit: bool, blocked_reason: String) -> void:
	last_fire_result = {
		"fired": true,
		"hit": did_hit,
		"blocked_reason": blocked_reason,
		"current_ammo": current_ammo,
		"reserve_ammo": reserve_ammo,
	}


func _record_reload_result(did_reload: bool, blocked_reason: StringName, rounds_loaded: int) -> void:
	last_reload_result = {
		"reloaded": did_reload,
		"blocked_reason": str(blocked_reason),
		"rounds_loaded": rounds_loaded,
		"current_ammo": current_ammo,
		"reserve_ammo": reserve_ammo,
	}


func _sync_ammo_result() -> void:
	_sync_ammo_model_from_public_counts()
	_sync_public_ammo_counts()


func _connect_ammo_model() -> void:
	if not _ammo_model.changed.is_connected(_sync_public_ammo_counts):
		_ammo_model.changed.connect(_sync_public_ammo_counts)


func _sync_public_ammo_counts() -> void:
	magazine_size = int(_ammo_model.get_state().get("magazine_capacity", magazine_size))
	magazine_capacity_bonus = int(_ammo_model.get_state().get("magazine_capacity_bonus", magazine_capacity_bonus))
	current_ammo = int(_ammo_model.get_state().get("loaded_ammo", current_ammo))
	reserve_ammo = int(_ammo_model.get_state().get("reserve_ammo", reserve_ammo))
	last_fire_result["current_ammo"] = current_ammo
	last_fire_result["reserve_ammo"] = reserve_ammo
	last_reload_result["current_ammo"] = current_ammo
	last_reload_result["reserve_ammo"] = reserve_ammo


func _sync_ammo_model_from_public_counts() -> void:
	var loaded_count := current_ammo
	var reserve_count := reserve_ammo
	if weapon_def == null:
		_ammo_model.clear_weapon(true)
		_ammo_model.set_counts(loaded_count, reserve_count)
		return
	var model_state: Dictionary = _ammo_model.get_state()
	if model_state.get("weapon_id", &"") != weapon_def.id or int(model_state.get("magazine_capacity_bonus", 0)) != maxi(magazine_capacity_bonus, 0):
		_ammo_model.configure_weapon(weapon_def, true, magazine_capacity_bonus)
	_ammo_model.set_counts(loaded_count, reserve_count)


func _apply_weapon_tuning_from_def() -> void:
	if weapon_def == null:
		return
	var snapshot := get_tuning_snapshot()
	if float(snapshot.get("fire_rate_per_second", 0.0)) > 0.0:
		fire_cooldown_seconds = float(snapshot.get("fire_cooldown_seconds", fire_cooldown_seconds))
	if float(snapshot.get("projectile_range", 0.0)) > 0.0:
		weapon_range = float(snapshot.get("projectile_range_meters", weapon_range))


func _attachment_modifiers_with_capacity(capacity_bonus: int, attachment_modifiers: Dictionary) -> Dictionary:
	var result := attachment_modifiers.duplicate(true)
	if result.is_empty():
		result = {
			"magazine_capacity_bonus": maxi(capacity_bonus, 0),
			"vertical_recoil_multiplier": 1.0,
			"horizontal_recoil_multiplier": 1.0,
			"recoil_recovery_multiplier": 1.0,
			"spread_multiplier": 1.0,
			"attachment_ids": [],
			"attachment_slots": [],
		}
	else:
		result["magazine_capacity_bonus"] = maxi(int(result.get("magazine_capacity_bonus", capacity_bonus)), maxi(capacity_bonus, 0))
	return result


func _cooldown_remaining() -> float:
	return maxf((_last_fire_time + fire_cooldown_seconds) - _now_seconds(), 0.0)


func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _object_has_property(object: Object, property_name: StringName) -> bool:
	if object == null:
		return false
	for property in object.get_property_list():
		if StringName(str(property.get("name", ""))) == property_name:
			return true
	return false


func _resolve_damage_target(target: Node) -> Node:
	if target == null:
		return null
	if target.has_method("apply_damage"):
		return target
	for child in target.get_children():
		if child is Node and child.has_method("apply_damage"):
			return child
	var parent := target.get_parent()
	if parent != null and parent.has_method("apply_damage"):
		return parent
	return null
