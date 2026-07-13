class_name WeaponModPanelStateBuilder
extends RefCounted

const PlayerLoadoutSupportScript := preload("res://scripts/player/player_loadout_support_3d.gd")
const WeaponAttachmentServiceScript := preload("res://scripts/combat/weapon_attachment_service.gd")
const WeaponTuningServiceScript := preload("res://scripts/combat/weapon_tuning_service.gd")
const ItemInspectionWeaponRowsScript := preload("res://scripts/items/item_inspection_weapon_rows.gd")
const WeaponHardpointLabelsScript := preload("res://scripts/ui/weapon_hardpoint_labels.gd")


static func build(weapon_stack: Dictionary, weapon_def: ItemDef, weapon_slot_id: StringName) -> Dictionary:
	if weapon_def == null or weapon_def.item_type != "weapon":
		return {"has_weapon": false, "weapon_slot_id": weapon_slot_id, "slots": []}
	var capabilities := _capabilities(weapon_def)
	var attachment_state := WeaponAttachmentServiceScript.modifiers_for_weapon_stack(weapon_stack, weapon_def)
	var ammo_state: Dictionary = weapon_stack.get("weapon_ammo_state", {}) as Dictionary
	var loaded_ammo := maxi(int(ammo_state.get("loaded_ammo", 0)), 0)
	var ammo_item := _load_ammo_item(ammo_state)
	if not bool(capabilities.get("uses_ammo", false)):
		loaded_ammo = 0
		ammo_item = null
	var snapshot := WeaponTuningServiceScript.resolve_snapshot(weapon_def, ammo_item, attachment_state, weapon_stack)
	return {
		"has_weapon": true,
		"weapon_slot_id": weapon_slot_id,
		"weapon_stack": weapon_stack.duplicate(true),
		"catalog_number": weapon_def.catalog_number,
		"description_key": weapon_def.description_key,
		"capabilities": capabilities.duplicate(true),
		"stat_rows": _stat_rows(snapshot, capabilities),
		"summary": _summary(weapon_stack, weapon_def, snapshot, ammo_item, loaded_ammo, capabilities),
		"attachment_state": attachment_state.duplicate(true),
		"loaded_ammo": loaded_ammo,
		"can_unload_ammo": loaded_ammo > 0 and ammo_item != null,
		"slots": _slots(weapon_stack, weapon_def),
	}


static func _summary(weapon_stack: Dictionary, weapon_def: ItemDef, snapshot: Dictionary, ammo_item: ItemDef, loaded_ammo: int, capabilities: Dictionary) -> Dictionary:
	var durability: Dictionary = snapshot.get("durability", {}) as Dictionary
	return {
		"type_key": StringName("item_type.%s" % weapon_def.item_type),
		"weapon_kind": str(capabilities.get("weapon_kind", "firearm")),
		"uses_ammo": bool(capabilities.get("uses_ammo", false)),
		"has_durability": bool(capabilities.get("has_durability", false)),
		"supports_attachments": bool(capabilities.get("supports_attachments", false)),
		"weight": PlayerLoadoutSupportScript.weapon_total_weight(weapon_stack, ammo_item, loaded_ammo),
		"current_durability": int(durability.get("current_durability", 0)),
		"max_durability": int(durability.get("max_durability", 0)),
		"loaded_ammo": loaded_ammo,
		"magazine_capacity": maxi(int(snapshot.get("magazine_capacity", 0)), 0),
	}


static func _slots(weapon_stack: Dictionary, weapon_def: ItemDef) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for hardpoint in WeaponAttachmentServiceScript.weapon_mod_slot_ids(weapon_def):
		rows.append({
			"slot_id": str(hardpoint),
			"label_key": WeaponHardpointLabelsScript.label_key(hardpoint),
			"stack": WeaponAttachmentServiceScript.weapon_mod_stack(weapon_stack, hardpoint),
		})
	return rows


static func _stat_rows(snapshot: Dictionary, capabilities: Dictionary) -> Array[Dictionary]:
	return ItemInspectionWeaponRowsScript.build(snapshot, capabilities)


static func _capabilities(weapon_def: ItemDef) -> Dictionary:
	return {
		"inspection_kind": "weapon",
		"weapon_kind": weapon_def.get_weapon_kind(),
		"uses_ammo": weapon_def.weapon_uses_ammo(),
		"supports_attachments": weapon_def.weapon_supports_attachments(),
		"has_durability": weapon_def.weapon_has_durability(),
	}


static func _load_ammo_item(ammo_state: Dictionary) -> ItemDef:
	var ammo_path := str(ammo_state.get("ammo_item_path", "")).strip_edges()
	if ammo_path == "" or not ResourceLoader.exists(ammo_path):
		return null
	var item_def := load(ammo_path) as ItemDef
	return item_def if item_def != null and item_def.item_type == "ammo" else null
