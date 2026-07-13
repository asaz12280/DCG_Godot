class_name EquipmentModel
extends RefCounted

signal changed

const SLOT_PRIMARY_WEAPON := &"primary_weapon"
const SLOT_SIDEARM := &"sidearm"
const SLOT_MELEE := &"melee"
const SLOT_HELMET := &"helmet"
const SLOT_ARMOR := &"armor"
const SLOT_GLASSES := &"glasses"
const SLOT_HEADSET := &"headset"
const SLOT_BACKPACK := &"backpack"
const SLOT_WEAPON_MAG := &"weapon_mag"
const SLOT_WEAPON_GRIP := &"weapon_grip"
const SLOT_WEAPON_MUZZLE := &"weapon_muzzle"
const SLOT_WEAPON_SCOPE := &"weapon_scope"
const SLOT_WEAPON_STOCK := &"weapon_stock"
const SLOT_WEAPON_TACTIC := &"weapon_tactic"
const SLOT_CHARM_1 := &"charm_1"
const SLOT_CHARM_2 := &"charm_2"
const ItemStackSaveCodecScript := preload("res://scripts/inventory/item_stack_save_codec.gd")

const SLOT_IDS: Array[StringName] = [
	SLOT_PRIMARY_WEAPON,
	SLOT_SIDEARM,
	SLOT_MELEE,
	SLOT_HELMET,
	SLOT_ARMOR,
	SLOT_GLASSES,
	SLOT_HEADSET,
	SLOT_BACKPACK,
	SLOT_WEAPON_MAG,
	SLOT_WEAPON_GRIP,
	SLOT_WEAPON_MUZZLE,
	SLOT_WEAPON_SCOPE,
	SLOT_WEAPON_STOCK,
	SLOT_WEAPON_TACTIC,
	SLOT_CHARM_1,
	SLOT_CHARM_2,
]

const WEAPON_HARDPOINT_SLOT_IDS: Array[StringName] = [
	SLOT_WEAPON_MAG,
	SLOT_WEAPON_GRIP,
	SLOT_WEAPON_MUZZLE,
	SLOT_WEAPON_SCOPE,
	SLOT_WEAPON_STOCK,
	SLOT_WEAPON_TACTIC,
]

const ACTIVE_WEAPON_SLOT_IDS: Array[StringName] = [
	SLOT_PRIMARY_WEAPON,
	SLOT_SIDEARM,
]

var slots: Dictionary = {}


func _init() -> void:
	clear()


func clear() -> void:
	slots.clear()
	for slot_id in SLOT_IDS:
		slots[slot_id] = {}
	changed.emit()


func get_slot_ids() -> Array[StringName]:
	return SLOT_IDS.duplicate()


func get_visible_slot_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for slot_id in SLOT_IDS:
		if WEAPON_HARDPOINT_SLOT_IDS.has(slot_id):
			continue
		result.append(slot_id)
	return result


func has_slot(slot_id: StringName) -> bool:
	return SLOT_IDS.has(slot_id)


func get_slot(slot_id: StringName) -> Dictionary:
	if not has_slot(slot_id):
		return {}
	return (slots.get(slot_id, {}) as Dictionary).duplicate(true)


func get_equipped_item(slot_id: StringName) -> ItemDef:
	var stack := get_slot(slot_id)
	return _load_item_from_stack(stack)


func get_slots() -> Dictionary:
	var result: Dictionary = {}
	for slot_id in SLOT_IDS:
		result[slot_id] = get_slot(slot_id)
	return result


func is_empty(slot_id: StringName) -> bool:
	return get_slot(slot_id).is_empty()


func can_equip(slot_id: StringName, item_def: ItemDef) -> bool:
	if item_def == null or not has_slot(slot_id):
		return false
	match slot_id:
		SLOT_PRIMARY_WEAPON:
			return item_def.item_type == "weapon" and not item_def.tags.has(&"melee")
		SLOT_SIDEARM:
			return item_def.item_type == "weapon" and not item_def.tags.has(&"melee")
		SLOT_MELEE:
			return item_def.item_type == "weapon" and item_def.tags.has(&"melee")
		SLOT_HELMET:
			return item_def.item_type == "armor" and (item_def.tags.has(&"helmet") or str(item_def.id).contains("helmet"))
		SLOT_ARMOR:
			return item_def.item_type == "armor" and not (item_def.tags.has(&"helmet") or str(item_def.id).contains("helmet"))
		SLOT_BACKPACK:
			return item_def.item_type == "backpack"
		SLOT_GLASSES:
			return item_def.item_type == "attachment" and _has_slot_tag(item_def, &"glasses")
		SLOT_HEADSET:
			return item_def.item_type == "attachment" and _has_slot_tag(item_def, &"headset")
		SLOT_WEAPON_MAG:
			return item_def.item_type == "attachment" and _has_slot_tag(item_def, &"magazine")
		SLOT_WEAPON_GRIP:
			return item_def.item_type == "attachment" and _has_slot_tag(item_def, &"grip")
		SLOT_WEAPON_MUZZLE:
			return item_def.item_type == "attachment" and _has_slot_tag(item_def, &"muzzle")
		SLOT_WEAPON_SCOPE:
			return item_def.item_type == "attachment" and (_has_slot_tag(item_def, &"scope") or _has_slot_tag(item_def, &"sight"))
		SLOT_WEAPON_STOCK:
			return item_def.item_type == "attachment" and _has_slot_tag(item_def, &"stock")
		SLOT_WEAPON_TACTIC:
			return item_def.item_type == "attachment" and _has_slot_tag(item_def, &"tactic")
		SLOT_CHARM_1, SLOT_CHARM_2:
			return item_def.item_type == "totem" or (item_def.item_type == "attachment" and _is_charm_attachment(item_def))
		_:
			return false


func equip_item(slot_id: StringName, item_def: ItemDef, quantity: int = 1) -> bool:
	if not can_equip(slot_id, item_def):
		return false
	var stack := item_def.to_stack(maxi(quantity, 1))
	stack["quantity"] = 1
	slots[slot_id] = stack
	_migrate_legacy_weapon_mod_slots()
	changed.emit()
	return true


func equip_stack(slot_id: StringName, stack: Dictionary) -> bool:
	var item_def := _load_item_from_stack(stack)
	if item_def == null or not can_equip(slot_id, item_def):
		return false
	var equipped_stack: Dictionary = ItemStackSaveCodecScript.stack_from_entry(stack, item_def, 1)
	equipped_stack["quantity"] = 1
	slots[slot_id] = equipped_stack
	_migrate_legacy_weapon_mod_slots()
	changed.emit()
	return true


func update_slot_stack_state(slot_id: StringName, state: Dictionary, emit_change: bool = true) -> bool:
	if not has_slot(slot_id) or state.is_empty():
		return false
	var stack: Dictionary = (slots.get(slot_id, {}) as Dictionary).duplicate(true)
	if stack.is_empty():
		return false
	for key in state.keys():
		var value: Variant = state[key]
		stack[key] = value.duplicate(true) if typeof(value) == TYPE_DICTIONARY or typeof(value) == TYPE_ARRAY else value
	slots[slot_id] = stack
	if emit_change:
		changed.emit()
	return true


func unequip(slot_id: StringName) -> Dictionary:
	if not has_slot(slot_id):
		return {}
	var stack := get_slot(slot_id)
	if stack.is_empty():
		return {}
	slots[slot_id] = {}
	changed.emit()
	return stack


func to_save_data() -> Dictionary:
	var saved: Dictionary = {}
	for slot_id in SLOT_IDS:
		var stack := get_slot(slot_id)
		if stack.is_empty():
			saved[str(slot_id)] = {}
			continue
		var entry: Dictionary = ItemStackSaveCodecScript.to_save_entry(stack)
		if entry.is_empty():
			saved[str(slot_id)] = {}
			continue
		entry["quantity"] = 1
		saved[str(slot_id)] = entry
	return {"slots": saved}


func load_save_data(data: Dictionary) -> bool:
	clear()
	var loaded_all := true
	var saved_slots: Dictionary = data.get("slots", {})
	for raw_key in saved_slots.keys():
		var slot_id := StringName(str(raw_key))
		if not has_slot(slot_id):
			loaded_all = false
			continue
		var entry: Variant = saved_slots[raw_key]
		if typeof(entry) != TYPE_DICTIONARY:
			loaded_all = false
			continue
		if (entry as Dictionary).is_empty():
			continue
		var item_path := ItemStackSaveCodecScript.get_item_path(entry as Dictionary)
		if item_path == "" or not ResourceLoader.exists(item_path):
			loaded_all = false
			continue
		var item_def := load(item_path) as ItemDef
		if item_def == null:
			loaded_all = false
			continue
		var target_slot := _migrated_slot_for_stack(slot_id, item_def)
		if not equip_stack(target_slot, entry as Dictionary):
			loaded_all = false
	_migrate_legacy_weapon_mod_slots()
	changed.emit()
	return loaded_all


func can_attach_weapon_mod(weapon_slot_id: StringName, mod_stack: Dictionary) -> bool:
	if mod_stack.is_empty() or not ACTIVE_WEAPON_SLOT_IDS.has(weapon_slot_id):
		return false
	var weapon_stack := get_slot(weapon_slot_id)
	if weapon_stack.is_empty():
		return false
	var weapon_def := _load_item_from_stack(weapon_stack)
	var attachment_def := _load_item_from_stack(mod_stack)
	if weapon_def == null or weapon_def.item_type != "weapon" or attachment_def == null:
		return false
	var hardpoint_slot := _weapon_hardpoint_for_attachment(attachment_def, weapon_def)
	if hardpoint_slot == &"":
		return false
	return _weapon_mod_stack(weapon_stack, hardpoint_slot).is_empty()


func can_attach_weapon_mod_to_hardpoint(weapon_slot_id: StringName, hardpoint_slot: StringName, mod_stack: Dictionary) -> bool:
	if hardpoint_slot == &"" or mod_stack.is_empty() or not ACTIVE_WEAPON_SLOT_IDS.has(weapon_slot_id):
		return false
	var weapon_stack := get_slot(weapon_slot_id)
	if weapon_stack.is_empty():
		return false
	var weapon_def := _load_item_from_stack(weapon_stack)
	var attachment_def := _load_item_from_stack(mod_stack)
	if weapon_def == null or weapon_def.item_type != "weapon" or attachment_def == null:
		return false
	if _weapon_hardpoint_for_attachment(attachment_def, weapon_def) != hardpoint_slot:
		return false
	return _weapon_mod_stack(weapon_stack, hardpoint_slot).is_empty()


func attach_weapon_mod(weapon_slot_id: StringName, mod_stack: Dictionary) -> bool:
	if not can_attach_weapon_mod(weapon_slot_id, mod_stack):
		return false
	var weapon_stack := get_slot(weapon_slot_id)
	var weapon_def := _load_item_from_stack(weapon_stack)
	var attachment_def := _load_item_from_stack(mod_stack)
	var hardpoint_slot := _weapon_hardpoint_for_attachment(attachment_def, weapon_def)
	var mods: Dictionary = weapon_stack.get("weapon_mods", {}) as Dictionary
	var stored_stack: Dictionary = ItemStackSaveCodecScript.stack_from_entry(mod_stack, attachment_def, 1)
	stored_stack["quantity"] = 1
	mods[str(hardpoint_slot)] = stored_stack
	weapon_stack["weapon_mods"] = mods.duplicate(true)
	slots[weapon_slot_id] = weapon_stack
	changed.emit()
	return true


func attach_weapon_mod_to_hardpoint(weapon_slot_id: StringName, hardpoint_slot: StringName, mod_stack: Dictionary) -> bool:
	if not can_attach_weapon_mod_to_hardpoint(weapon_slot_id, hardpoint_slot, mod_stack):
		return false
	var weapon_stack := get_slot(weapon_slot_id)
	var attachment_def := _load_item_from_stack(mod_stack)
	var mods: Dictionary = weapon_stack.get("weapon_mods", {}) as Dictionary
	var stored_stack: Dictionary = ItemStackSaveCodecScript.stack_from_entry(mod_stack, attachment_def, 1)
	stored_stack["quantity"] = 1
	mods[str(hardpoint_slot)] = stored_stack
	weapon_stack["weapon_mods"] = mods.duplicate(true)
	slots[weapon_slot_id] = weapon_stack
	changed.emit()
	return true


func unequip_weapon_mod(weapon_slot_id: StringName, hardpoint_slot: StringName) -> Dictionary:
	if not ACTIVE_WEAPON_SLOT_IDS.has(weapon_slot_id):
		return {}
	var weapon_stack := get_slot(weapon_slot_id)
	if weapon_stack.is_empty():
		return {}
	var mods: Dictionary = weapon_stack.get("weapon_mods", {}) as Dictionary
	var key := str(hardpoint_slot)
	var mod_stack: Variant = mods.get(key, {})
	if typeof(mod_stack) != TYPE_DICTIONARY or (mod_stack as Dictionary).is_empty():
		return {}
	mods.erase(key)
	weapon_stack["weapon_mods"] = mods.duplicate(true)
	slots[weapon_slot_id] = weapon_stack
	changed.emit()
	return (mod_stack as Dictionary).duplicate(true)


func get_weapon_mods(weapon_slot_id: StringName) -> Dictionary:
	var weapon_stack := get_slot(weapon_slot_id)
	if weapon_stack.is_empty():
		return {}
	var mods: Dictionary = weapon_stack.get("weapon_mods", {}) as Dictionary
	return mods.duplicate(true)


func _load_item_from_stack(stack: Dictionary) -> ItemDef:
	var item_path := ItemStackSaveCodecScript.get_item_path(stack)
	if item_path == "" or not ResourceLoader.exists(item_path):
		return null
	return load(item_path) as ItemDef


func _is_charm_attachment(item_def: ItemDef) -> bool:
	if _has_slot_tag(item_def, &"charm"):
		return true
	for generic_weapon_attachment_tag in [&"magazine", &"grip", &"muzzle", &"stock", &"scope", &"sight", &"tactic"]:
		if _has_slot_tag(item_def, generic_weapon_attachment_tag):
			return false
	return item_def.item_type == "attachment"


func _migrated_slot_for_stack(slot_id: StringName, item_def: ItemDef) -> StringName:
	if can_equip(slot_id, item_def):
		return slot_id
	if slot_id == SLOT_CHARM_1 or slot_id == SLOT_CHARM_2:
		if item_def.item_type == "attachment" and _attachment_matches_hardpoint(item_def, &"magazine") and is_empty(SLOT_WEAPON_MAG):
			return SLOT_WEAPON_MAG
		if item_def.item_type == "attachment" and _attachment_matches_hardpoint(item_def, &"grip") and is_empty(SLOT_WEAPON_GRIP):
			return SLOT_WEAPON_GRIP
		if item_def.item_type == "attachment" and _attachment_matches_hardpoint(item_def, &"muzzle") and is_empty(SLOT_WEAPON_MUZZLE):
			return SLOT_WEAPON_MUZZLE
		if item_def.item_type == "attachment" and _attachment_matches_hardpoint(item_def, &"scope") and is_empty(SLOT_WEAPON_SCOPE):
			return SLOT_WEAPON_SCOPE
		if item_def.item_type == "attachment" and _attachment_matches_hardpoint(item_def, &"stock") and is_empty(SLOT_WEAPON_STOCK):
			return SLOT_WEAPON_STOCK
		if item_def.item_type == "attachment" and _attachment_matches_hardpoint(item_def, &"tactic") and is_empty(SLOT_WEAPON_TACTIC):
			return SLOT_WEAPON_TACTIC
	return slot_id


func _migrate_legacy_weapon_mod_slots() -> void:
	for legacy_slot_id in WEAPON_HARDPOINT_SLOT_IDS:
		var mod_stack := get_slot(legacy_slot_id)
		if mod_stack.is_empty():
			continue
		var target_weapon_slot := _first_weapon_slot_for_mod(mod_stack)
		if target_weapon_slot == &"":
			continue
		if attach_weapon_mod(target_weapon_slot, mod_stack):
			slots[legacy_slot_id] = {}


func _first_weapon_slot_for_mod(mod_stack: Dictionary) -> StringName:
	for weapon_slot_id in ACTIVE_WEAPON_SLOT_IDS:
		if can_attach_weapon_mod(weapon_slot_id, mod_stack):
			return weapon_slot_id
	return &""


func _weapon_hardpoint_for_attachment(attachment_def: ItemDef, weapon_def: ItemDef) -> StringName:
	if attachment_def == null or weapon_def == null or attachment_def.item_type != "attachment":
		return &""
	for hardpoint in weapon_def.get_weapon_attachment_slots():
		if _attachment_matches_hardpoint(attachment_def, hardpoint):
			return hardpoint
	return &""


func _attachment_matches_hardpoint(attachment_def: ItemDef, hardpoint: StringName) -> bool:
	match hardpoint:
		&"scope":
			return _has_slot_tag(attachment_def, &"scope") or _has_slot_tag(attachment_def, &"sight")
		_:
			return _has_slot_tag(attachment_def, hardpoint)


func _has_slot_tag(item_def: ItemDef, slot_tag: StringName) -> bool:
	if item_def == null:
		return false
	if item_def.get_attachment_slot_tags().has(slot_tag):
		return true
	return item_def.tags.has(slot_tag)


func _weapon_mod_stack(weapon_stack: Dictionary, hardpoint_slot: StringName) -> Dictionary:
	var mods: Dictionary = weapon_stack.get("weapon_mods", {}) as Dictionary
	var stack: Variant = mods.get(str(hardpoint_slot), {})
	if typeof(stack) != TYPE_DICTIONARY:
		return {}
	return (stack as Dictionary).duplicate(true)
