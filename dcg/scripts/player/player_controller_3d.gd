extends CharacterBody3D

const DEFAULT_STARTER_LOADOUT := preload("res://data/inventory/starter_inventory.tres")
const PlayerStatsProfileScript := preload("res://scripts/player/player_stats_profile.gd")
const PlayerStatsScript := preload("res://scripts/player/player_stats_3d.gd")
const PlayerInputReaderScript := preload("res://scripts/player/player_input_reader_3d.gd")
const PlayerLocomotionScript := preload("res://scripts/player/player_locomotion_3d.gd")
const RaidLossRulesScript := preload("res://scripts/raid/raid_loss_rules.gd")
const BaseProgressionScript := preload("res://scripts/base/base_progression.gd")
const EquipmentModelScript := preload("res://scripts/equipment/equipment_model.gd")
const RaidLoadoutTransferScript := preload("res://scripts/raid/raid_loadout_transfer.gd")

signal health_changed(current: float, maximum: float)
signal died(event: DamageEvent)
signal stamina_changed(current: float, maximum: float)
signal inventory_changed
signal equipment_changed
signal reload_feedback_changed(result: Dictionary)
signal reload_progress_changed(state: Dictionary)

var max_health: float:
	get:
		return _stats.max_health()

var walk_speed: float:
	get:
		return _stats.walk_speed()

var sprint_speed: float:
	get:
		return _stats.sprint_speed()

var max_stamina: float:
	get:
		return _stats.max_stamina()

var roll_distance: float:
	get:
		return _stats.roll_distance()

var roll_speed: float:
	get:
		return _stats.roll_speed()

var backpack_slots: int:
	get:
		return _stats.backpack_slots()

var carry_weight_limit: float:
	get:
		return _stats.carry_weight_limit()

var safe_pocket_slots: int:
	get:
		return _stats.safe_pocket_slots()

var defense: float:
	get:
		return _stats.defense()

var health: float = 0.0
var stamina: float = 0.0
var current_carry_weight: float = 0.0
var is_exhausted: bool = false
var is_dead := false

@export var stats_profile: PlayerStatsProfile = PlayerStatsProfileScript.new()
@export var starter_loadout: Resource = DEFAULT_STARTER_LOADOUT
@export_range(0.05, 5.0, 0.05) var reload_duration_seconds := 0.8

var inventory_model := InventoryModel.new()
var equipment_model := EquipmentModelScript.new()

var _stats: PlayerStats3D
var _input_reader := PlayerInputReaderScript.new(self)
var _locomotion: PlayerLocomotion3D
var _weapon_controller: Node = null
var _is_reloading := false
var _reload_elapsed := 0.0
var _pending_reload := {}
var _last_reload_result := {
	"reloaded": false,
	"blocked_reason": "",
	"rounds_loaded": 0,
	"current_ammo": 0,
	"reserve_ammo": 0,
	"backpack_ammo_remaining": 0,
	"source": "",
}
var _last_reload_state := {
	"active": false,
	"progress": 0.0,
	"remaining_time": 0.0,
	"source": "",
	"status": "idle",
}


func _ready() -> void:
	var runtime_stats_profile := stats_profile.duplicate(true) as PlayerStatsProfile
	var difficulty_manager := get_node_or_null("/root/DifficultyManager")
	if difficulty_manager != null and difficulty_manager.has_method("apply_to_player_stats"):
		difficulty_manager.apply_to_player_stats(runtime_stats_profile)
	_stats = PlayerStatsScript.new(runtime_stats_profile)
	_locomotion = PlayerLocomotionScript.new(self, _stats)
	_weapon_controller = get_node_or_null("WeaponController3D")
	_apply_base_upgrade_effects()
	inventory_model.setup(backpack_slots)
	inventory_model.changed.connect(_on_inventory_changed)
	equipment_model.changed.connect(_on_equipment_changed)
	if not _load_pending_raid_loadout():
		_load_starter_inventory()
	_sync_weapon_from_equipment()
	health = get_total_max_health()
	stamina = max_stamina
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	health_changed.emit(health, get_total_max_health())
	stamina_changed.emit(stamina, max_stamina)


func _unhandled_input(event: InputEvent) -> void:
	if _input_reader.is_gameplay_blocked():
		return
	if _is_reload_event(event):
		reload_equipped_weapon()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_fire_equipped_weapon()


func get_total_max_health() -> float:
	return max_health


func get_total_backpack_slots() -> int:
	return backpack_slots


func get_total_carry_weight_limit() -> float:
	return carry_weight_limit


func get_total_safe_pocket_slots() -> int:
	return safe_pocket_slots


func get_total_defense() -> float:
	return defense


func set_current_carry_weight(value: float) -> void:
	current_carry_weight = maxf(value, 0.0)


func get_weight_speed_multiplier() -> float:
	return _stats.weight_speed_multiplier(current_carry_weight)


func get_inventory_model() -> InventoryModel:
	return inventory_model


func get_equipment_model() -> RefCounted:
	return equipment_model


func get_last_reload_result() -> Dictionary:
	return _last_reload_result.duplicate(true)


func get_reload_state() -> Dictionary:
	return _last_reload_state.duplicate(true)


func get_compatible_backpack_ammo_count() -> int:
	return _count_compatible_backpack_ammo()


func add_item_resource(item_def: ItemDef, quantity: int = 1) -> bool:
	return inventory_model.add_item(item_def, quantity)


func can_equip_inventory_stack(stack_index: int, slot_id: StringName = &"") -> bool:
	if stack_index < 0 or stack_index >= inventory_model.stacks.size():
		return false
	var stack := inventory_model.stacks[stack_index]
	var target_slot := slot_id
	if target_slot == &"":
		target_slot = get_default_equipment_slot_for_stack(stack)
	if target_slot == &"" or not equipment_model.has_slot(target_slot) or not equipment_model.is_empty(target_slot):
		return false
	var item_def := _load_item_from_stack(stack)
	return equipment_model.can_equip(target_slot, item_def)


func equip_inventory_stack(stack_index: int, slot_id: StringName = &"") -> bool:
	if not can_equip_inventory_stack(stack_index, slot_id):
		return false
	var stack := inventory_model.stacks[stack_index]
	var target_slot := slot_id
	if target_slot == &"":
		target_slot = get_default_equipment_slot_for_stack(stack)

	var removed_stack := inventory_model.remove_stack_at(stack_index)
	if removed_stack.is_empty():
		return false
	if not equipment_model.equip_stack(target_slot, removed_stack):
		inventory_model.add_stack(removed_stack)
		return false
	return true


func reload_equipped_weapon(reload_source: StringName = &"manual") -> bool:
	if _is_reloading:
		_record_reload_feedback(false, &"reloading", 0, reload_source)
		return false
	if _weapon_controller == null or not _weapon_controller.has_method("reload_from_item"):
		_record_reload_feedback(false, &"no_weapon", 0, reload_source)
		_emit_reload_state(false, 0.0, reload_source, &"blocked")
		return false
	_sync_weapon_from_equipment()
	if not _weapon_controller.has_method("has_weapon") or not bool(_weapon_controller.call("has_weapon")):
		_record_reload_feedback(false, &"no_weapon", 0, reload_source)
		_emit_reload_state(false, 0.0, reload_source, &"blocked")
		return false

	var current_rounds := int(_weapon_controller.get("current_ammo"))
	var magazine_capacity := int(_weapon_controller.get("magazine_size"))
	var needed_rounds := magazine_capacity - current_rounds
	if needed_rounds <= 0:
		_record_reload_feedback(false, &"magazine_full", 0, reload_source)
		_emit_reload_state(false, 1.0, reload_source, &"blocked")
		return false

	var ammo_stack := _find_compatible_ammo_stack()
	if ammo_stack.is_empty():
		_record_reload_feedback(false, &"no_compatible_ammo", 0, reload_source)
		_emit_reload_state(false, 0.0, reload_source, &"blocked")
		return false

	var ammo_index := int(ammo_stack.get("index", -1))
	var ammo_def := ammo_stack.get("item_def") as ItemDef
	var available_quantity := int(ammo_stack.get("quantity", 0))
	var quantity_to_load := mini(needed_rounds, available_quantity)
	_start_reload(reload_source, ammo_index, ammo_def, quantity_to_load)
	return true


func get_default_equipment_slot_for_stack(stack: Dictionary) -> StringName:
	var item_def := _load_item_from_stack(stack)
	if item_def == null:
		return &""

	if item_def.item_type == "weapon":
		if item_def.tags.has(&"pistol"):
			if equipment_model.is_empty(&"primary_weapon"):
				return &"primary_weapon"
			if equipment_model.is_empty(&"sidearm"):
				return &"sidearm"
		if item_def.tags.has(&"gun") and equipment_model.is_empty(&"primary_weapon"):
			return &"primary_weapon"
		if item_def.tags.has(&"melee") and equipment_model.is_empty(&"melee"):
			return &"melee"
	if item_def.item_type == "armor":
		if (item_def.tags.has(&"helmet") or str(item_def.id).contains("helmet")) and equipment_model.is_empty(&"helmet"):
			return &"helmet"
		if equipment_model.is_empty(&"armor"):
			return &"armor"
	if item_def.item_type == "backpack" and equipment_model.is_empty(&"backpack"):
		return &"backpack"
	if item_def.item_type == "attachment":
		if item_def.tags.has(&"glasses") and equipment_model.is_empty(&"glasses"):
			return &"glasses"
		if item_def.tags.has(&"headset") and equipment_model.is_empty(&"headset"):
			return &"headset"
		if equipment_model.is_empty(&"charm_1"):
			return &"charm_1"
		if equipment_model.is_empty(&"charm_2"):
			return &"charm_2"
	return &""


func _complete_reload() -> bool:
	if _pending_reload.is_empty() or _weapon_controller == null:
		_cancel_reload(&"cancelled")
		return false
	var reload_source := StringName(str(_pending_reload.get("source", "manual")))
	var ammo_index := int(_pending_reload.get("ammo_index", -1))
	var ammo_def := _pending_reload.get("ammo_def") as ItemDef
	var quantity_to_load := int(_pending_reload.get("quantity_to_load", 0))
	var loaded_rounds := int(_weapon_controller.call("reload_from_item", ammo_def, quantity_to_load))
	if loaded_rounds <= 0:
		var weapon_result: Dictionary = _weapon_controller.get("last_reload_result")
		_record_reload_feedback(false, StringName(str(weapon_result.get("blocked_reason", "no_ammo"))), 0, reload_source)
		_cancel_reload(StringName(str(weapon_result.get("blocked_reason", "no_ammo"))))
		return false

	inventory_model.consume_stack_quantity(ammo_index, loaded_rounds)
	_record_reload_feedback(true, &"", loaded_rounds, reload_source)
	_finish_reload(reload_source)
	return true


func apply_damage(event: DamageEvent) -> bool:
	if event == null or event.amount <= 0.0 or is_dead:
		return false
	var mitigated_amount := maxf(event.amount - defense, 1.0)
	health = maxf(health - mitigated_amount, 0.0)
	health_changed.emit(health, get_total_max_health())
	if health <= 0.0:
		_die(event)
	return true


func restore_health_to_full() -> bool:
	var maximum := get_total_max_health()
	if maximum <= 0.0 or health >= maximum:
		return false
	is_dead = false
	health = maximum
	health_changed.emit(health, maximum)
	return true


func is_alive() -> bool:
	return not is_dead and health > 0.0


func _physics_process(delta: float) -> void:
	_update_reload(delta)
	var input_blocked := _locomotion.physics_update(delta, _input_reader)

	move_and_slide()
	if not input_blocked:
		_face_mouse_on_ground()
	stamina_changed.emit(stamina, max_stamina)


func _face_mouse_on_ground() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	if absf(ray_direction.y) < 0.001:
		return

	var distance := -ray_origin.y / ray_direction.y
	if distance < 0.0:
		return

	var look_position := ray_origin + ray_direction * distance
	look_position.y = global_position.y
	if global_position.distance_to(look_position) > 0.1:
		look_at(look_position, Vector3.UP)


func _fire_equipped_weapon() -> void:
	if _weapon_controller == null or not _weapon_controller.has_method("fire_forward"):
		return
	if _is_reloading:
		return
	_sync_weapon_from_equipment()
	if _should_auto_reload_before_fire():
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	var projectile_origin: Vector3 = _weapon_controller.global_position + Vector3.UP * 0.72
	var projectile_direction: Vector3 = _projectile_direction_from_camera_ray(projectile_origin, ray_origin, ray_direction)
	_weapon_controller.fire_forward(projectile_origin, projectile_direction, get_world_3d().direct_space_state)


func _projectile_direction_from_camera_ray(origin: Vector3, ray_origin: Vector3, ray_direction: Vector3) -> Vector3:
	if absf(ray_direction.y) < 0.001:
		var fallback := ray_direction
		fallback.y = 0.0
		return fallback.normalized() if fallback != Vector3.ZERO else -global_transform.basis.z.normalized()
	var ground_distance := -ray_origin.y / ray_direction.y
	var ground_position := ray_origin + ray_direction * ground_distance
	var direction := ground_position - origin
	direction.y = 0.0
	if direction.length() < 0.001:
		return -global_transform.basis.z.normalized()
	return direction.normalized()


func _should_auto_reload_before_fire() -> bool:
	if _weapon_controller == null or not _weapon_controller.has_method("get_fire_block_reason"):
		return false
	if StringName(str(_weapon_controller.call("get_fire_block_reason"))) != &"no_ammo":
		return false
	if _find_compatible_ammo_stack().is_empty():
		return false
	return reload_equipped_weapon(&"empty_fire")


func _is_reload_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R or event.physical_keycode == KEY_R:
			return true
	if InputMap.has_action("reload") and event.is_action_pressed("reload"):
		return true
	return false


func _find_compatible_ammo_stack() -> Dictionary:
	if _weapon_controller == null or not _weapon_controller.has_method("get_ammo_model"):
		return {}
	var ammo_model: Variant = _weapon_controller.call("get_ammo_model")
	if ammo_model == null or not ammo_model.has_method("can_use_ammo"):
		return {}
	for index in range(inventory_model.stacks.size()):
		var stack := inventory_model.stacks[index]
		if int(stack.get("quantity", 0)) <= 0:
			continue
		var item_def := _load_item_from_stack(stack)
		if item_def == null or item_def.item_type != "ammo":
			continue
		if bool(ammo_model.call("can_use_ammo", item_def)):
			return {
				"index": index,
				"item_def": item_def,
				"quantity": int(stack.get("quantity", 1)),
			}
	return {}


func _start_reload(reload_source: StringName, ammo_index: int, ammo_def: ItemDef, quantity_to_load: int) -> void:
	_is_reloading = true
	_reload_elapsed = 0.0
	_pending_reload = {
		"source": str(reload_source),
		"ammo_index": ammo_index,
		"ammo_def": ammo_def,
		"quantity_to_load": quantity_to_load,
	}
	_emit_reload_state(true, 0.0, reload_source, &"reloading")


func _update_reload(delta: float) -> void:
	if not _is_reloading:
		return
	_reload_elapsed += maxf(delta, 0.0)
	var duration := maxf(reload_duration_seconds, 0.05)
	var progress := clampf(_reload_elapsed / duration, 0.0, 1.0)
	var source := StringName(str(_pending_reload.get("source", "manual")))
	_emit_reload_state(true, progress, source, &"reloading")
	if progress >= 1.0:
		_complete_reload()


func _finish_reload(reload_source: StringName) -> void:
	_is_reloading = false
	_reload_elapsed = 0.0
	_pending_reload = {}
	_emit_reload_state(false, 1.0, reload_source, &"complete")


func _cancel_reload(reason: StringName) -> void:
	var source := StringName(str(_pending_reload.get("source", "manual"))) if not _pending_reload.is_empty() else &"manual"
	_is_reloading = false
	_reload_elapsed = 0.0
	_pending_reload = {}
	_emit_reload_state(false, 0.0, source, reason)


func _emit_reload_state(active: bool, progress: float, reload_source: StringName, status: StringName) -> void:
	_last_reload_state = {
		"active": active,
		"progress": clampf(progress, 0.0, 1.0),
		"remaining_time": maxf(reload_duration_seconds * (1.0 - clampf(progress, 0.0, 1.0)), 0.0) if active else 0.0,
		"source": str(reload_source),
		"status": str(status),
	}
	reload_progress_changed.emit(_last_reload_state.duplicate(true))


func _record_reload_feedback(did_reload: bool, blocked_reason: StringName, rounds_loaded: int, reload_source: StringName = &"manual") -> void:
	_last_reload_result = {
		"reloaded": did_reload,
		"blocked_reason": str(blocked_reason),
		"rounds_loaded": rounds_loaded,
		"current_ammo": int(_weapon_controller.get("current_ammo")) if _weapon_controller != null else 0,
		"reserve_ammo": int(_weapon_controller.get("reserve_ammo")) if _weapon_controller != null else 0,
		"backpack_ammo_remaining": _count_compatible_backpack_ammo(),
		"source": str(reload_source),
	}
	reload_feedback_changed.emit(_last_reload_result.duplicate(true))


func _load_starter_inventory() -> void:
	if inventory_model.get_used_slots() > 0:
		return
	if starter_loadout != null and starter_loadout.has_method("add_to_inventory"):
		starter_loadout.add_to_inventory(inventory_model)


func _load_pending_raid_loadout() -> bool:
	var save_manager := get_node_or_null("/root/SaveGameManager")
	if save_manager == null or not save_manager.has_method("consume_pending_raid_loadout"):
		return false
	var loadout: Dictionary = save_manager.call("consume_pending_raid_loadout")
	if loadout.is_empty():
		return false
	return RaidLoadoutTransferScript.apply_to_player(self, loadout)


func _apply_base_upgrade_effects() -> void:
	if _weapon_controller == null:
		return
	var save_manager := get_node_or_null("/root/SaveGameManager")
	if save_manager == null or not save_manager.has_method("get_current_slot_index") or not save_manager.has_method("get_slot_data"):
		return
	var slot_index := int(save_manager.get_current_slot_index())
	var save_data: Dictionary = save_manager.get_slot_data(slot_index)
	var starter_ammo_bonus := BaseProgressionScript.get_starter_ammo_bonus(save_data)
	if starter_ammo_bonus <= 0:
		return
	_weapon_controller.set("reserve_ammo", int(_weapon_controller.get("reserve_ammo")) + starter_ammo_bonus)
	if _weapon_controller.has_method("_sync_ammo_result"):
		_weapon_controller.call("_sync_ammo_result")


func _on_inventory_changed() -> void:
	current_carry_weight = inventory_model.get_total_weight()
	inventory_changed.emit()


func _on_equipment_changed() -> void:
	_sync_weapon_from_equipment()
	equipment_changed.emit()


func _sync_weapon_from_equipment() -> void:
	if _weapon_controller == null:
		return
	var weapon_item := _get_equipped_weapon_item()
	if weapon_item == null:
		if _weapon_controller.has_method("clear_weapon"):
			_weapon_controller.call("clear_weapon")
		else:
			_weapon_controller.set("weapon_def", null)
		return
	if _weapon_controller.has_method("equip_weapon"):
		_weapon_controller.call("equip_weapon", weapon_item)
	else:
		_weapon_controller.set("weapon_def", weapon_item)


func _get_equipped_weapon_item() -> ItemDef:
	for slot_id in [&"primary_weapon", &"sidearm"]:
		var item: Variant = equipment_model.call("get_equipped_item", slot_id)
		if item is ItemDef:
			return item
	return null


func _count_compatible_backpack_ammo() -> int:
	if _weapon_controller == null or not _weapon_controller.has_method("get_ammo_model"):
		return 0
	var ammo_model: Variant = _weapon_controller.call("get_ammo_model")
	if ammo_model == null or not ammo_model.has_method("can_use_ammo"):
		return 0
	var total := 0
	for stack in inventory_model.stacks:
		if int(stack.get("quantity", 0)) <= 0:
			continue
		var item_def := _load_item_from_stack(stack)
		if item_def == null or item_def.item_type != "ammo":
			continue
		if bool(ammo_model.call("can_use_ammo", item_def)):
			total += int(stack.get("quantity", 0))
	return total


func _load_item_from_stack(stack: Dictionary) -> ItemDef:
	var item_path := str(stack.get("resource_path", stack.get("item_path", "")))
	if item_path == "" or not ResourceLoader.exists(item_path):
		return null
	return load(item_path) as ItemDef


func _die(event: DamageEvent) -> void:
	if is_dead:
		return
	is_dead = true
	died.emit(event)
	var raid_session := _find_raid_session()
	if raid_session != null and raid_session.has_method("register_player_death"):
		var context := RaidLossRulesScript.build_death_context_from_player(self)
		context["source"] = "player_death"
		raid_session.call("register_player_death", context)


func _find_raid_session() -> Node:
	var current_scene := get_tree().current_scene if is_inside_tree() else null
	if current_scene != null:
		var session := current_scene.get_node_or_null("RaidSession")
		if session != null:
			return session
	if get_parent() != null:
		return get_parent().get_node_or_null("RaidSession")
	return null
