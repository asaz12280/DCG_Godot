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
const SLOT_CHARM_1 := &"charm_1"
const SLOT_CHARM_2 := &"charm_2"

const SLOT_IDS: Array[StringName] = [
	SLOT_PRIMARY_WEAPON,
	SLOT_SIDEARM,
	SLOT_MELEE,
	SLOT_HELMET,
	SLOT_ARMOR,
	SLOT_GLASSES,
	SLOT_HEADSET,
	SLOT_BACKPACK,
	SLOT_CHARM_1,
	SLOT_CHARM_2,
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
			return item_def.item_type == "weapon" and item_def.tags.has(&"gun")
		SLOT_SIDEARM:
			return item_def.item_type == "weapon" and item_def.tags.has(&"pistol")
		SLOT_MELEE:
			return item_def.item_type == "weapon" and item_def.tags.has(&"melee")
		SLOT_HELMET:
			return item_def.item_type == "armor" and (item_def.tags.has(&"helmet") or str(item_def.id).contains("helmet"))
		SLOT_ARMOR:
			return item_def.item_type == "armor" and not (item_def.tags.has(&"helmet") or str(item_def.id).contains("helmet"))
		SLOT_BACKPACK:
			return item_def.item_type == "backpack"
		SLOT_GLASSES:
			return item_def.item_type == "attachment" and item_def.tags.has(&"glasses")
		SLOT_HEADSET:
			return item_def.item_type == "attachment" and item_def.tags.has(&"headset")
		SLOT_CHARM_1, SLOT_CHARM_2:
			return item_def.item_type == "attachment" or item_def.tags.has(&"charm")
		_:
			return false


func equip_item(slot_id: StringName, item_def: ItemDef, quantity: int = 1) -> bool:
	if not can_equip(slot_id, item_def):
		return false
	var stack := item_def.to_stack(maxi(quantity, 1))
	stack["quantity"] = 1
	slots[slot_id] = stack
	changed.emit()
	return true


func equip_stack(slot_id: StringName, stack: Dictionary) -> bool:
	var item_def := _load_item_from_stack(stack)
	if item_def == null:
		return false
	return equip_item(slot_id, item_def, int(stack.get("quantity", 1)))


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
		var item_path := str(stack.get("resource_path", ""))
		if item_path == "":
			saved[str(slot_id)] = {}
			continue
		saved[str(slot_id)] = {"item_path": item_path}
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
		var item_path := str((entry as Dictionary).get("item_path", ""))
		if item_path == "" or not ResourceLoader.exists(item_path):
			loaded_all = false
			continue
		var item_def := load(item_path) as ItemDef
		if item_def == null or not equip_item(slot_id, item_def):
			loaded_all = false
	changed.emit()
	return loaded_all


func _load_item_from_stack(stack: Dictionary) -> ItemDef:
	var item_path := str(stack.get("resource_path", stack.get("item_path", "")))
	if item_path == "" or not ResourceLoader.exists(item_path):
		return null
	return load(item_path) as ItemDef
