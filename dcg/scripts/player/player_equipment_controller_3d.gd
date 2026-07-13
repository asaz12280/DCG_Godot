class_name PlayerEquipmentController3D
extends RefCounted

const EquipmentModelScript := preload("res://scripts/equipment/equipment_model.gd")
const ItemDurabilityServiceScript := preload("res://scripts/items/item_durability_service.gd")
const PlayerLoadoutSupportScript := preload("res://scripts/player/player_loadout_support_3d.gd")
const ArmorMitigationServiceScript := preload("res://scripts/combat/armor_mitigation_service.gd")
const WeaponAttachmentServiceScript := preload("res://scripts/combat/weapon_attachment_service.gd")
const WeaponTuningServiceScript := preload("res://scripts/combat/weapon_tuning_service.gd")
const ItemInspectionWeaponRowsScript := preload("res://scripts/items/item_inspection_weapon_rows.gd")
const PlayerInventoryActionsScript := preload("res://scripts/player/player_inventory_actions_3d.gd")
const ITEM_ROOT_PATH := "res://data/items"

const DURABILITY_SPREAD_PATTERN := [0.70, -0.45, 0.95, -0.80, 0.35, -0.60]
const WEAPON_RECOIL_RECOVERY_DEGREES_PER_SECOND := 12.0
const WEAPON_RECOIL_MAX_OFFSET_DEGREES := 8.0

var owner: Node = null
var weapon_controller: Node = null
var equipment_model := EquipmentModelScript.new()
var active_weapon_slot_id: StringName = EquipmentModelScript.SLOT_PRIMARY_WEAPON
var _synced_weapon_slot_id: StringName = &""

var _durability_spread_index := 0
var _weapon_recoil_offset_degrees := 0.0
var _last_weapon_spread_state := {
	"active": false,
	"source": "",
	"spread_degrees": 0.0,
	"applied_angle_degrees": 0.0,
	"current_durability": 0,
	"max_durability": 0,
}
var _last_weapon_recoil_state := {
	"active": false,
	"source": "",
	"weapon_vertical_recoil": 0.0,
	"weapon_horizontal_recoil": 0.0,
	"attachment_vertical_recoil_multiplier": 1.0,
	"attachment_horizontal_recoil_multiplier": 1.0,
	"attachment_recoil_recovery_multiplier": 1.0,
	"attachment_ids": [],
	"applied_angle_degrees": 0.0,
	"vertical_impulse_degrees": 0.0,
	"horizontal_impulse_degrees": 0.0,
	"accumulated_angle_degrees": 0.0,
}
var _item_def_lookup_by_id: Dictionary = {}
var _item_def_lookup_by_catalog: Dictionary = {}
var _item_def_lookup_by_path: Dictionary = {}


func _init(source_owner: Node = null, source_weapon_controller: Node = null) -> void:
	owner = source_owner
	weapon_controller = source_weapon_controller


func set_weapon_controller(controller: Node) -> void:
	weapon_controller = controller


func set_active_weapon_slot(slot_id: StringName) -> bool:
	if not EquipmentModelScript.ACTIVE_WEAPON_SLOT_IDS.has(slot_id):
		return false
	if active_weapon_slot_id != slot_id:
		save_synced_weapon_ammo_state(false)
	active_weapon_slot_id = slot_id
	sync_weapon_from_equipment()
	return equipment_model.get_equipped_item(slot_id) is ItemDef


func get_active_weapon_slot_id() -> StringName:
	return active_weapon_slot_id


func get_model() -> RefCounted:
	return equipment_model


func get_defense_bonus() -> float:
	return (
		_defense_bonus_for_slot(&"helmet")
		+ _defense_bonus_for_slot(&"armor")
		+ _defense_bonus_for_slot(&"charm_1")
		+ _defense_bonus_for_slot(&"charm_2")
	)


func get_max_health_bonus() -> float:
	return _max_health_bonus_for_slot(&"charm_1") + _max_health_bonus_for_slot(&"charm_2")


func get_armor_protection_level() -> float:
	return get_defense_bonus()


func damage_after_armor(event: DamageEvent, base_defense: float) -> float:
	return ArmorMitigationServiceScript.damage_after_armor(event, base_defense + get_defense_bonus(), get_armor_protection_level())


func get_armor_effect_state() -> Dictionary:
	var armor := equipment_model.get_equipped_item(&"armor")
	var bonus := get_defense_bonus()
	var protection := get_armor_protection_level()
	var durability_state := get_active_armor_durability_state()
	return {
		"equipped": armor != null,
		"armor_name": item_display_name(armor),
		"defense_bonus": bonus,
		"armor_protection_level": protection,
		"has_durability": bool(durability_state.get("has_durability", false)),
		"durability_is_broken": bool(durability_state.get("durability_is_broken", false)),
		"current_durability": int(durability_state.get("current_durability", 0)),
		"max_durability": int(durability_state.get("max_durability", 0)),
		"effect_text": armor_effect_text(armor, bonus),
	}


func get_active_weapon_durability_state() -> Dictionary:
	var slot_id := get_equipped_weapon_slot_id()
	if slot_id == &"":
		return {
			"has_weapon": false,
			"slot_id": "",
			"item_id": "",
			"has_durability": false,
		}
	var stack := equipment_model.get_slot(slot_id)
	var item_def := load_item_from_stack(stack)
	var state: Dictionary = ItemDurabilityServiceScript.normalize_stack(stack, item_def)
	state["has_weapon"] = item_def != null
	state["slot_id"] = str(slot_id)
	state["item_id"] = str(item_def.id) if item_def != null else ""
	return state


func get_active_armor_durability_state() -> Dictionary:
	var stack := equipment_model.get_slot(&"armor")
	if stack.is_empty():
		return {
			"has_armor": false,
			"slot_id": "armor",
			"item_id": "",
			"has_durability": false,
			"durability_is_broken": false,
		}
	var item_def := load_item_from_stack(stack)
	var state: Dictionary = ItemDurabilityServiceScript.normalize_stack(stack, item_def)
	state["has_armor"] = item_def != null
	state["slot_id"] = "armor"
	state["item_id"] = str(item_def.id) if item_def != null else ""
	return state


func _defense_bonus_for_slot(slot_id: StringName) -> float:
	var stack := equipment_model.get_slot(slot_id)
	if stack.is_empty():
		return 0.0
	var item_def := load_item_from_stack(stack)
	if item_def == null:
		return 0.0
	var durability: Dictionary = ItemDurabilityServiceScript.normalize_stack(stack, item_def)
	if bool(durability.get("has_durability", false)) and bool(durability.get("durability_is_broken", false)):
		return 0.0
	return maxf(item_def.defense_bonus, 0.0)


func _max_health_bonus_for_slot(slot_id: StringName) -> float:
	var stack := equipment_model.get_slot(slot_id)
	if stack.is_empty():
		return 0.0
	var item_def := load_item_from_stack(stack)
	if item_def == null:
		return 0.0
	return maxf(item_def.max_health_bonus, 0.0)


func get_last_weapon_spread_state() -> Dictionary:
	return _last_weapon_spread_state.duplicate(true)


func get_last_weapon_recoil_state() -> Dictionary:
	return _last_weapon_recoil_state.duplicate(true)


func get_active_weapon_attachment_state() -> Dictionary:
	return attachment_state_for_weapon_slot(get_equipped_weapon_slot_id())


func get_weapon_mod_panel_state(weapon_slot_id: StringName = &"") -> Dictionary:
	var slot_id := weapon_slot_id if weapon_slot_id != &"" else get_equipped_weapon_slot_id()
	if slot_id == &"":
		return {"has_weapon": false, "weapon_slot_id": "", "slots": []}
	var weapon_stack := equipment_model.get_slot(slot_id)
	var weapon_def := load_item_from_stack(weapon_stack)
	if weapon_def == null or weapon_def.item_type != "weapon":
		return {"has_weapon": false, "weapon_slot_id": str(slot_id), "slots": []}
	var rows: Array[Dictionary] = []
	for hardpoint in weapon_def.get_weapon_attachment_slots():
		rows.append({
			"slot_id": str(hardpoint),
			"label_key": weapon_hardpoint_label_key(hardpoint),
			"stack": WeaponAttachmentServiceScript.weapon_mod_stack(weapon_stack, hardpoint),
		})
	var attachment_state := attachment_state_for_weapon_slot(slot_id)
	var loaded_ammo := _loaded_ammo_for_weapon_stack(slot_id, weapon_stack)
	var tuning_snapshot := WeaponTuningServiceScript.resolve_snapshot(weapon_def, current_loaded_ammo_item(), attachment_state, weapon_stack)
	return {
		"has_weapon": true,
		"weapon_slot_id": str(slot_id),
		"weapon_stack": weapon_stack.duplicate(true),
		"catalog_number": weapon_def.catalog_number,
		"description_key": weapon_def.description_key,
		"capabilities": {
			"inspection_kind": "weapon",
			"weapon_kind": weapon_def.get_weapon_kind(),
			"uses_ammo": weapon_def.weapon_uses_ammo(),
			"supports_attachments": weapon_def.weapon_supports_attachments(),
			"has_durability": weapon_def.weapon_has_durability(),
		},
		"stat_rows": _weapon_stat_rows(slot_id, weapon_stack, weapon_def, attachment_state),
		"summary": _weapon_summary(weapon_stack, weapon_def, tuning_snapshot, loaded_ammo),
		"attachment_state": attachment_state.duplicate(true),
		"loaded_ammo": loaded_ammo,
		"can_unload_ammo": loaded_ammo > 0,
		"slots": rows,
}


func _weapon_summary(weapon_stack: Dictionary, weapon_def: ItemDef, snapshot: Dictionary, loaded_ammo: int) -> Dictionary:
	var durability: Dictionary = snapshot.get("durability", {}) as Dictionary
	var ammo_item := current_loaded_ammo_item()
	if ammo_item == null:
		ammo_item = _load_ammo_item_from_state(weapon_stack.get("weapon_ammo_state", {}) as Dictionary)
	return {
		"type_key": StringName("item_type.%s" % weapon_def.item_type),
		"weapon_kind": weapon_def.get_weapon_kind(),
		"uses_ammo": weapon_def.weapon_uses_ammo(),
		"has_durability": weapon_def.weapon_has_durability(),
		"supports_attachments": weapon_def.weapon_supports_attachments(),
		"weight": PlayerLoadoutSupportScript.weapon_total_weight(weapon_stack, ammo_item, loaded_ammo),
		"current_durability": int(durability.get("current_durability", 0)),
		"max_durability": int(durability.get("max_durability", 0)),
		"loaded_ammo": loaded_ammo,
		"magazine_capacity": maxi(int(snapshot.get("magazine_capacity", 0)), 0),
	}


func _loaded_ammo_for_weapon_stack(slot_id: StringName, weapon_stack: Dictionary) -> int:
	if weapon_controller != null and slot_id == _synced_weapon_slot_id:
		return maxi(int(weapon_controller.get("current_ammo")), 0)
	var ammo_state: Dictionary = weapon_stack.get("weapon_ammo_state", {}) as Dictionary
	return maxi(int(ammo_state.get("loaded_ammo", 0)), 0)


func _weapon_stat_rows(_slot_id: StringName, weapon_stack: Dictionary, weapon_def: ItemDef, attachment_state: Dictionary) -> Array[Dictionary]:
	var snapshot := WeaponTuningServiceScript.resolve_snapshot(weapon_def, current_loaded_ammo_item(), attachment_state, weapon_stack)
	var capabilities := {
		"weapon_kind": weapon_def.get_weapon_kind(),
		"uses_ammo": weapon_def.weapon_uses_ammo(),
		"supports_attachments": weapon_def.weapon_supports_attachments(),
		"has_durability": weapon_def.weapon_has_durability(),
	}
	return ItemInspectionWeaponRowsScript.build(snapshot, capabilities)


func can_equip_inventory_stack(stack_index: int, slot_id: StringName = &"") -> bool:
	return PlayerInventoryActionsScript.can_equip_inventory_stack(owner, stack_index, slot_id)


func equip_inventory_stack(stack_index: int, slot_id: StringName = &"") -> bool:
	return PlayerInventoryActionsScript.equip_inventory_stack(owner, stack_index, slot_id)


func can_swap_equipment_slots(source_slot_id: StringName, target_slot_id: StringName) -> bool:
	return PlayerInventoryActionsScript.can_swap_equipment_slots(owner, source_slot_id, target_slot_id)


func swap_equipment_slots(source_slot_id: StringName, target_slot_id: StringName) -> bool:
	return PlayerInventoryActionsScript.swap_equipment_slots(owner, source_slot_id, target_slot_id)


func can_attach_inventory_stack_to_weapon(stack_index: int, weapon_slot_id: StringName = &"") -> bool:
	return PlayerInventoryActionsScript.can_attach_inventory_stack_to_weapon(owner, stack_index, weapon_slot_id)


func can_attach_inventory_stack_to_weapon_hardpoint(stack_index: int, weapon_slot_id: StringName, hardpoint_slot: StringName) -> bool:
	return PlayerInventoryActionsScript.can_attach_inventory_stack_to_weapon_hardpoint(owner, stack_index, weapon_slot_id, hardpoint_slot)


func attach_inventory_stack_to_weapon(stack_index: int, weapon_slot_id: StringName = &"") -> bool:
	return PlayerInventoryActionsScript.attach_inventory_stack_to_weapon(owner, stack_index, weapon_slot_id)


func attach_inventory_stack_to_weapon_hardpoint(stack_index: int, weapon_slot_id: StringName, hardpoint_slot: StringName) -> bool:
	return PlayerInventoryActionsScript.attach_inventory_stack_to_weapon_hardpoint(owner, stack_index, weapon_slot_id, hardpoint_slot)


func unequip_weapon_mod_to_inventory(weapon_slot_id: StringName, hardpoint_slot: StringName) -> bool:
	return PlayerInventoryActionsScript.unequip_weapon_mod_to_inventory(owner, weapon_slot_id, hardpoint_slot)


func can_unequip_equipment_slot(slot_id: StringName) -> bool:
	return PlayerInventoryActionsScript.can_unequip_equipment_slot(owner, slot_id)


func unequip_equipment_slot(slot_id: StringName) -> bool:
	return PlayerInventoryActionsScript.unequip_equipment_slot(owner, slot_id)


func can_drop_equipment_slot(slot_id: StringName) -> bool:
	return PlayerInventoryActionsScript.can_drop_equipment_slot(owner, slot_id)


func drop_equipment_slot(slot_id: StringName) -> bool:
	return PlayerInventoryActionsScript.drop_equipment_slot(owner, slot_id)


func default_equipment_slot_for_stack(stack: Dictionary) -> StringName:
	return PlayerInventoryActionsScript.default_equipment_slot_for_stack(owner, stack)


func sync_weapon_from_equipment() -> void:
	if weapon_controller == null:
		return
	var target_slot_id := get_equipped_weapon_slot_id()
	if _synced_weapon_slot_id != &"" and _synced_weapon_slot_id != target_slot_id:
		save_synced_weapon_ammo_state(false)
	var weapon_item := get_equipped_weapon_item()
	if weapon_item == null:
		if weapon_controller.has_method("clear_weapon"):
			weapon_controller.call("clear_weapon")
		else:
			weapon_controller.set("weapon_def", null)
		_synced_weapon_slot_id = &""
		return
	var should_restore := _synced_weapon_slot_id != target_slot_id or _controller_weapon_id() != weapon_item.id
	if weapon_controller.has_method("equip_weapon"):
		var attachment_state := attachment_state_for_weapon_slot(get_equipped_weapon_slot_id())
		weapon_controller.call("equip_weapon", weapon_item, int(attachment_state.get("magazine_capacity_bonus", 0)), attachment_state)
	else:
		weapon_controller.set("weapon_def", weapon_item)
	_synced_weapon_slot_id = target_slot_id
	if should_restore:
		_restore_weapon_controller_ammo_state(equipment_model.get_slot(target_slot_id), weapon_item)


func save_synced_weapon_ammo_state(emit_change: bool = false) -> bool:
	if weapon_controller == null or _synced_weapon_slot_id == &"":
		return false
	if not EquipmentModelScript.ACTIVE_WEAPON_SLOT_IDS.has(_synced_weapon_slot_id):
		return false
	var stack := equipment_model.get_slot(_synced_weapon_slot_id)
	if stack.is_empty():
		return false
	var item_def := load_item_from_stack(stack)
	if item_def == null or item_def.id != _controller_weapon_id():
		return false
	var ammo_model: Variant = weapon_controller.call("get_ammo_model") if weapon_controller.has_method("get_ammo_model") else null
	var ammo_state: Dictionary = ammo_model.call("get_state") if ammo_model != null and ammo_model.has_method("get_state") else {}
	var ammo_def: ItemDef = ammo_model.get("ammo_def") as ItemDef if ammo_model != null else null
	var runtime_state := {
		"weapon_id": str(item_def.id),
		"ammo_id": str(ammo_def.id) if ammo_def != null else "",
		"ammo_item_path": ammo_def.resource_path if ammo_def != null else "",
		"loaded_ammo": int(ammo_state.get("loaded_ammo", weapon_controller.get("current_ammo"))),
		"reserve_ammo": int(ammo_state.get("reserve_ammo", weapon_controller.get("reserve_ammo"))),
	}
	return equipment_model.call("update_slot_stack_state", _synced_weapon_slot_id, {"weapon_ammo_state": runtime_state}, emit_change)


func _restore_weapon_controller_ammo_state(weapon_stack: Dictionary, weapon_item: ItemDef) -> bool:
	if weapon_controller == null or weapon_item == null or not weapon_controller.has_method("restore_ammo_state"):
		return false
	var raw_state: Variant = weapon_stack.get("weapon_ammo_state", {})
	if typeof(raw_state) != TYPE_DICTIONARY:
		return bool(weapon_controller.call("restore_ammo_state", null, 0, 0))
	var ammo_state := raw_state as Dictionary
	if str(ammo_state.get("weapon_id", "")) != str(weapon_item.id):
		return bool(weapon_controller.call("restore_ammo_state", null, 0, 0))
	var loaded_count := maxi(int(ammo_state.get("loaded_ammo", 0)), 0)
	var reserve_count := maxi(int(ammo_state.get("reserve_ammo", 0)), 0)
	var ammo_item := _load_ammo_item_from_state(ammo_state)
	if ammo_item == null and (loaded_count > 0 or reserve_count > 0):
		return bool(weapon_controller.call("restore_ammo_state", null, 0, 0))
	return bool(weapon_controller.call("restore_ammo_state", ammo_item, loaded_count, reserve_count))


func _load_ammo_item_from_state(ammo_state: Dictionary) -> ItemDef:
	var ammo_path := str(ammo_state.get("ammo_item_path", "")).strip_edges()
	if ammo_path != "" and ResourceLoader.exists(ammo_path):
		var item := load(ammo_path) as ItemDef
		if item != null and item.item_type == "ammo":
			return item
	return null


func _controller_weapon_id() -> StringName:
	if weapon_controller == null:
		return &""
	var value: Variant = weapon_controller.get("weapon_def")
	var item := value as ItemDef
	return item.id if item != null else &""


func projectile_direction_with_durability_spread(direction: Vector3) -> Dictionary:
	var penalty := active_weapon_combat_penalty_state()
	var attachment_spread_multiplier := current_attachment_spread_multiplier()
	if direction == Vector3.ZERO or not bool(penalty.get("active", false)):
		return {"direction": direction, "state": spread_state_from_penalty(penalty, 0.0, attachment_spread_multiplier)}
	var base_spread_degrees := float(penalty.get("spread_degrees", 0.0))
	var spread_degrees := base_spread_degrees * attachment_spread_multiplier
	if spread_degrees <= 0.0:
		return {"direction": direction, "state": spread_state_from_penalty(penalty, 0.0, attachment_spread_multiplier, base_spread_degrees)}
	var pattern_value := float(DURABILITY_SPREAD_PATTERN[_durability_spread_index % DURABILITY_SPREAD_PATTERN.size()])
	_durability_spread_index += 1
	var applied_angle := spread_degrees * pattern_value
	var adjusted := direction.rotated(Vector3.UP, deg_to_rad(applied_angle)).normalized()
	return {"direction": adjusted, "state": spread_state_from_penalty(penalty, applied_angle, attachment_spread_multiplier, base_spread_degrees)}


func projectile_direction_with_recoil(direction: Vector3) -> Dictionary:
	var profile := active_weapon_recoil_profile()
	var offsets := random_weapon_recoil_offsets(profile)
	var horizontal_angle := float(offsets.get("horizontal_degrees", 0.0))
	var vertical_angle := float(offsets.get("vertical_degrees", 0.0))
	var state := recoil_state_from_profile(profile, horizontal_angle)
	state["vertical_weapon_recoil"] = maxf(float(profile.get("weapon_vertical_recoil", 0.0)), 0.0)
	state["vertical_impulse_degrees"] = vertical_angle
	state["horizontal_impulse_degrees"] = horizontal_angle
	state["accumulated_angle_degrees"] = horizontal_angle
	if direction == Vector3.ZERO or (absf(horizontal_angle) <= 0.001 and absf(vertical_angle) <= 0.001):
		return {"direction": direction, "state": state}
	var adjusted := direction
	if absf(horizontal_angle) > 0.001:
		adjusted = adjusted.rotated(Vector3.UP, deg_to_rad(horizontal_angle)).normalized()
	if absf(vertical_angle) > 0.001:
		var pitch_axis := adjusted.cross(Vector3.UP).normalized()
		if pitch_axis != Vector3.ZERO:
			adjusted = adjusted.rotated(pitch_axis, deg_to_rad(vertical_angle)).normalized()
	return {"direction": adjusted, "state": state}


func apply_weapon_recoil_after_shot(pre_shot_state: Dictionary) -> Dictionary:
	var profile := active_weapon_recoil_profile()
	if not bool(profile.get("active", false)):
		_weapon_recoil_offset_degrees = 0.0
		return empty_weapon_recoil_state()
	var applied_angle := clampf(float(pre_shot_state.get("applied_angle_degrees", 0.0)), -WEAPON_RECOIL_MAX_OFFSET_DEGREES, WEAPON_RECOIL_MAX_OFFSET_DEGREES)
	_weapon_recoil_offset_degrees = applied_angle
	var state := recoil_state_from_profile(profile, applied_angle)
	state["horizontal_impulse_degrees"] = applied_angle
	state["accumulated_angle_degrees"] = _weapon_recoil_offset_degrees
	_last_weapon_recoil_state = state.duplicate(true)
	return state


func recover_weapon_recoil(delta: float) -> void:
	if absf(_weapon_recoil_offset_degrees) <= 0.001:
		_weapon_recoil_offset_degrees = 0.0
		return
	var profile := active_weapon_recoil_profile()
	var recovery_multiplier := maxf(float(profile.get("attachment_recoil_recovery_multiplier", 1.0)), 0.0)
	var recovery_step := WEAPON_RECOIL_RECOVERY_DEGREES_PER_SECOND * recovery_multiplier * maxf(delta, 0.0)
	_weapon_recoil_offset_degrees = move_toward(_weapon_recoil_offset_degrees, 0.0, recovery_step)


func apply_equipped_weapon_durability_wear(wear_amount: int = 1) -> bool:
	var slot_id := get_equipped_weapon_slot_id()
	if slot_id == &"":
		return false
	var stack := equipment_model.get_slot(slot_id)
	if stack.is_empty():
		return false
	var item_def := load_item_from_stack(stack)
	if item_def == null:
		return false
	var snapshot := WeaponTuningServiceScript.resolve_snapshot(item_def, current_loaded_ammo_item(), attachment_state_for_weapon_slot(slot_id), stack)
	var base_wear := float(snapshot.get("durability_wear_per_shot", item_def.get_weapon_durability_wear_per_shot()))
	if base_wear <= 0.0:
		base_wear = float(wear_amount)
	var worn_stack: Dictionary = ItemDurabilityServiceScript.apply_ammo_use_wear(stack, item_def, current_loaded_ammo_item(), base_wear)
	if not bool(worn_stack.get("has_durability", false)):
		return false
	return equipment_model.equip_stack(slot_id, worn_stack)


func apply_equipped_armor_durability_wear(wear_amount: int = 1) -> bool:
	return _apply_equipped_armor_slot_durability_wear(&"armor", wear_amount)

func apply_equipped_helmet_durability_wear(wear_amount: int = 1) -> bool:
	return _apply_equipped_armor_slot_durability_wear(&"helmet", wear_amount)

func _apply_equipped_armor_slot_durability_wear(slot_id: StringName, wear_amount: int = 1) -> bool:
	var stack := equipment_model.get_slot(slot_id)
	if stack.is_empty():
		return false
	var item_def := load_item_from_stack(stack)
	if item_def == null:
		return false
	var worn_stack: Dictionary = ItemDurabilityServiceScript.apply_use_wear(stack, item_def, wear_amount)
	if not bool(worn_stack.get("has_durability", false)):
		return false
	return equipment_model.equip_stack(slot_id, worn_stack)
func should_block_fire_for_broken_weapon() -> bool:
	var state := get_active_weapon_durability_state()
	if not bool(state.get("has_durability", false)):
		return false
	if not bool(state.get("durability_is_broken", false)):
		return false
	var slot_id := StringName(str(state.get("slot_id", "")))
	var stack := equipment_model.get_slot(slot_id)
	var item_def := get_equipped_weapon_item()
	var penalty := ItemDurabilityServiceScript.combat_penalty_state(stack, item_def)
	record_weapon_fire_block(&"broken_weapon")
	_last_weapon_spread_state = spread_state_from_penalty(penalty, 0.0, current_attachment_spread_multiplier())
	return true


func record_weapon_fire_block(reason: StringName) -> void:
	if weapon_controller == null:
		return
	var result := {
		"fired": false,
		"hit": false,
		"blocked_reason": str(reason),
		"current_ammo": int(weapon_controller.get("current_ammo")),
		"reserve_ammo": int(weapon_controller.get("reserve_ammo")),
	}
	weapon_controller.set("last_fire_result", result)
	if weapon_controller.has_signal("fire_blocked"):
		weapon_controller.emit_signal("fire_blocked", reason)


func remember_weapon_fire_result(spread_state: Dictionary, recoil_state: Dictionary) -> void:
	_last_weapon_spread_state = spread_state.duplicate(true)
	_last_weapon_recoil_state = apply_weapon_recoil_after_shot(recoil_state)
	apply_equipped_weapon_durability_wear()


func clear_weapon_fire_result() -> void:
	_last_weapon_spread_state = empty_weapon_spread_state()
	_last_weapon_recoil_state = empty_weapon_recoil_state()


func is_equipped_armor_broken() -> bool:
	var state := get_active_armor_durability_state()
	return bool(state.get("has_durability", false)) and bool(state.get("durability_is_broken", false))


func get_equipped_weapon_slot_id() -> StringName:
	if EquipmentModelScript.ACTIVE_WEAPON_SLOT_IDS.has(active_weapon_slot_id):
		var active_item: Variant = equipment_model.call("get_equipped_item", active_weapon_slot_id)
		if active_item is ItemDef:
			return active_weapon_slot_id
	for slot_id in EquipmentModelScript.ACTIVE_WEAPON_SLOT_IDS:
		var item: Variant = equipment_model.call("get_equipped_item", slot_id)
		if item is ItemDef:
			active_weapon_slot_id = slot_id
			return slot_id
	return &""


func get_equipped_weapon_item() -> ItemDef:
	var slot_id := get_equipped_weapon_slot_id()
	if slot_id != &"":
		var item: Variant = equipment_model.call("get_equipped_item", slot_id)
		if item is ItemDef:
			return item
	return null


func attachment_state_for_weapon_slot(slot_id: StringName) -> Dictionary:
	if slot_id == &"" or equipment_model == null:
		return WeaponAttachmentServiceScript.modifiers_for_weapon_stack({}, null)
	var stack := equipment_model.get_slot(slot_id)
	var item_def := load_item_from_stack(stack)
	return WeaponAttachmentServiceScript.modifiers_for_weapon_stack(stack, item_def)


func weapon_hardpoint_label_key(hardpoint: StringName) -> StringName:
	match hardpoint:
		&"magazine":
			return &"ui.equipment.weapon_mag"
		&"grip":
			return &"ui.equipment.weapon_grip"
		&"muzzle":
			return &"ui.equipment.weapon_muzzle"
		&"scope", &"sight":
			return &"ui.equipment.weapon_scope"
		&"stock":
			return &"ui.equipment.weapon_stock"
		&"tactic":
			return &"ui.equipment.weapon_tactic"
		_:
			return &"ui.item.weapon_attachment_slots_format"


func active_weapon_recoil_profile() -> Dictionary:
	var slot_id := get_equipped_weapon_slot_id()
	if slot_id == &"":
		return empty_weapon_recoil_state()
	var stack := equipment_model.get_slot(slot_id)
	var item_def := load_item_from_stack(stack)
	if item_def == null:
		return empty_weapon_recoil_state()
	var attachment_state := WeaponAttachmentServiceScript.modifiers_for_weapon_stack(stack, item_def)
	var snapshot := WeaponTuningServiceScript.resolve_snapshot(item_def, current_loaded_ammo_item(), attachment_state, stack)
	var horizontal := maxf(float(snapshot.get("weapon_horizontal_recoil", 0.0)), 0.0)
	var vertical := maxf(float(snapshot.get("weapon_vertical_recoil", 0.0)), 0.0)
	var attachment_vertical_multiplier := maxf(float(snapshot.get("attachment_vertical_recoil_multiplier", 1.0)), 0.0)
	var attachment_horizontal_multiplier := maxf(float(snapshot.get("attachment_horizontal_recoil_multiplier", 1.0)), 0.0)
	var attachment_recovery_multiplier := maxf(float(snapshot.get("attachment_recoil_recovery_multiplier", 1.0)), 0.0)
	return {
		"active": horizontal > 0.0 or vertical > 0.0,
		"source": "weapon_recoil",
		"weapon_vertical_recoil": vertical,
		"weapon_horizontal_recoil": horizontal,
		"attachment_vertical_recoil_multiplier": attachment_vertical_multiplier,
		"attachment_horizontal_recoil_multiplier": attachment_horizontal_multiplier,
		"attachment_recoil_recovery_multiplier": attachment_recovery_multiplier,
		"attachment_ids": (snapshot.get("attachment_ids", []) as Array).duplicate(),
	}


func active_weapon_combat_penalty_state() -> Dictionary:
	var slot_id := get_equipped_weapon_slot_id()
	if slot_id == &"":
		return empty_weapon_spread_state()
	var stack := equipment_model.get_slot(slot_id)
	var item_def := load_item_from_stack(stack)
	if item_def == null:
		return empty_weapon_spread_state()
	var snapshot := WeaponTuningServiceScript.resolve_snapshot(item_def, current_loaded_ammo_item(), attachment_state_for_weapon_slot(slot_id), stack)
	return (snapshot.get("combat_penalty", {}) as Dictionary).duplicate(true)


func spread_state_from_penalty(penalty: Dictionary, applied_angle: float, attachment_spread_multiplier: float = 1.0, base_spread_degrees: float = -1.0) -> Dictionary:
	var state := empty_weapon_spread_state()
	state["active"] = bool(penalty.get("active", false))
	state["source"] = str(penalty.get("source", ""))
	var base_spread := float(penalty.get("spread_degrees", 0.0)) if base_spread_degrees < 0.0 else base_spread_degrees
	state["base_spread_degrees"] = base_spread
	state["attachment_spread_multiplier"] = attachment_spread_multiplier
	state["spread_degrees"] = base_spread * attachment_spread_multiplier
	state["applied_angle_degrees"] = applied_angle
	state["current_durability"] = int(penalty.get("current_durability", 0))
	state["max_durability"] = int(penalty.get("max_durability", 0))
	return state


func empty_weapon_spread_state() -> Dictionary:
	return {
		"active": false,
		"source": "",
		"base_spread_degrees": 0.0,
		"attachment_spread_multiplier": 1.0,
		"spread_degrees": 0.0,
		"applied_angle_degrees": 0.0,
		"current_durability": 0,
		"max_durability": 0,
	}


func recoil_state_from_profile(profile: Dictionary, applied_angle: float) -> Dictionary:
	var state := empty_weapon_recoil_state()
	state["active"] = bool(profile.get("active", false))
	state["source"] = str(profile.get("source", ""))
	state["weapon_vertical_recoil"] = maxf(float(profile.get("weapon_vertical_recoil", 0.0)), 0.0)
	state["weapon_horizontal_recoil"] = maxf(float(profile.get("weapon_horizontal_recoil", 0.0)), 0.0)
	state["attachment_vertical_recoil_multiplier"] = maxf(float(profile.get("attachment_vertical_recoil_multiplier", 1.0)), 0.0)
	state["attachment_horizontal_recoil_multiplier"] = maxf(float(profile.get("attachment_horizontal_recoil_multiplier", 1.0)), 0.0)
	state["attachment_recoil_recovery_multiplier"] = maxf(float(profile.get("attachment_recoil_recovery_multiplier", 1.0)), 0.0)
	state["attachment_ids"] = (profile.get("attachment_ids", []) as Array).duplicate()
	state["applied_angle_degrees"] = applied_angle
	state["vertical_impulse_degrees"] = 0.0
	state["accumulated_angle_degrees"] = applied_angle
	return state


func empty_weapon_recoil_state() -> Dictionary:
	return {
		"active": false,
		"source": "",
		"weapon_vertical_recoil": 0.0,
		"weapon_horizontal_recoil": 0.0,
		"attachment_vertical_recoil_multiplier": 1.0,
		"attachment_horizontal_recoil_multiplier": 1.0,
		"attachment_recoil_recovery_multiplier": 1.0,
		"attachment_ids": [],
		"applied_angle_degrees": 0.0,
		"vertical_impulse_degrees": 0.0,
		"horizontal_impulse_degrees": 0.0,
		"accumulated_angle_degrees": 0.0,
	}


func current_attachment_spread_multiplier() -> float:
	var attachment_state := attachment_state_for_weapon_slot(get_equipped_weapon_slot_id())
	return maxf(float(attachment_state.get("spread_multiplier", 1.0)), 0.0)


func current_loaded_ammo_item() -> ItemDef:
	if weapon_controller == null or not weapon_controller.has_method("get_ammo_model"):
		return null
	var ammo_model: Variant = weapon_controller.call("get_ammo_model")
	if ammo_model == null:
		return null
	var ammo_value: Variant = ammo_model.get("ammo_def")
	return ammo_value as ItemDef


func random_weapon_recoil_angle(profile: Dictionary) -> float:
	return float(random_weapon_recoil_offsets(profile).get("horizontal_degrees", 0.0))


func random_weapon_recoil_offsets(profile: Dictionary) -> Dictionary:
	if not bool(profile.get("active", false)):
		return {"horizontal_degrees": 0.0, "vertical_degrees": 0.0}
	var horizontal := maxf(float(profile.get("weapon_horizontal_recoil", 0.0)), 0.0)
	var vertical := maxf(float(profile.get("weapon_vertical_recoil", 0.0)), 0.0)
	return {
		"horizontal_degrees": randf_range(-horizontal, horizontal) if horizontal > 0.001 else 0.0,
		"vertical_degrees": randf_range(-vertical, vertical) if vertical > 0.001 else 0.0,
	}


func load_item_from_stack(stack: Dictionary) -> ItemDef:
	var item_path := str(stack.get("resource_path", stack.get("item_path", ""))).strip_edges()
	if item_path != "":
		if _item_def_lookup_by_path.has(item_path):
			return _item_def_lookup_by_path.get(item_path, null) as ItemDef
	if item_path != "" and ResourceLoader.exists(item_path):
		var item_from_path := load(item_path) as ItemDef
		if item_from_path != null:
			return _cache_item_def(item_from_path, item_path)
	return _find_item_def(
		ITEM_ROOT_PATH,
		int(stack.get("catalog_number", 0)),
		StringName(str(stack.get("id", "")))
	)


func _cache_item_def(item_def: ItemDef, item_path: String = "") -> ItemDef:
	if item_def == null:
		return null
	var normalized_path := item_path.strip_edges()
	if normalized_path != "":
		_item_def_lookup_by_path[normalized_path] = item_def
	if item_def.catalog_number > 0:
		_item_def_lookup_by_catalog[item_def.catalog_number] = item_def
	if item_def.id != &"":
		_item_def_lookup_by_id[str(item_def.id)] = item_def
	return item_def


func _find_item_def(path: String, catalog_number: int, item_id: StringName) -> ItemDef:
	if item_id != &"" and _item_def_lookup_by_id.has(str(item_id)):
		return _item_def_lookup_by_id.get(str(item_id), null) as ItemDef
	if catalog_number > 0 and _item_def_lookup_by_catalog.has(catalog_number):
		return _item_def_lookup_by_catalog.get(catalog_number, null) as ItemDef

	var dir := DirAccess.open(path)
	if dir == null:
		return null
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue

		var full_path := "%s/%s" % [path, entry]
		if dir.current_is_dir():
			var nested := _find_item_def(full_path, catalog_number, item_id)
			if nested != null:
				dir.list_dir_end()
				return nested
		elif entry.ends_with(".tres") or entry.ends_with(".res"):
			var item_def := load(full_path) as ItemDef
			if item_def != null:
				_cache_item_def(item_def, full_path)
				var matched_id := StringName(str(item_def.id)) != &"" and StringName(str(item_def.id)) == item_id
				var matched_catalog := catalog_number > 0 and item_def.catalog_number == catalog_number
				if matched_id or matched_catalog:
					dir.list_dir_end()
					return item_def
		entry = dir.get_next()
	dir.list_dir_end()
	return null


func item_display_name(item_def: ItemDef) -> String:
	if item_def == null:
		return ""
	var name_key := str(item_def.name_key)
	if name_key != "":
		var translated := localized_text(StringName(name_key), "")
		if translated != "":
			return translated
	if item_def.display_name != "":
		return item_def.display_name
	return str(item_def.id)


func localized_text(key: StringName, fallback: String) -> String:
	var key_text := str(key)
	var translated := tr(key_text)
	if owner != null:
		translated = owner.tr(key_text)
	return fallback if translated == key_text or translated == "" else translated


func armor_effect_text(item_def: ItemDef, bonus: float) -> String:
	if item_def == null:
		return localized_text(&"ui.top.status_armor_missing", "未裝備護甲")
	if bonus <= 0.0:
		return localized_text(&"ui.top.status_armor_item_no_bonus_format", "%s：無防護效果") % item_display_name(item_def)
	return localized_text(&"ui.top.status_armor_item_bonus_format", "%s：每次受擊減少 %.0f 傷害") % [item_display_name(item_def), bonus]


