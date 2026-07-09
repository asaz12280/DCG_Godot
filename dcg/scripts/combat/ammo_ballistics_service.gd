class_name AmmoBallisticsService
extends RefCounted

const DEFAULT_SPREAD_MULTIPLIER := 1.0
const DEFAULT_RECOIL_MULTIPLIER := 1.0


static func spread_multiplier(ammo_def: ItemDef = null) -> float:
	if ammo_def == null or ammo_def.item_type != "ammo":
		return DEFAULT_SPREAD_MULTIPLIER
	return ammo_def.get_ammo_spread_multiplier()


static func recoil_multiplier(ammo_def: ItemDef = null) -> float:
	if ammo_def == null or ammo_def.item_type != "ammo":
		return DEFAULT_RECOIL_MULTIPLIER
	return ammo_def.get_ammo_recoil_multiplier()
