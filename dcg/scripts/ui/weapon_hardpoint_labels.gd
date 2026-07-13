class_name WeaponHardpointLabels
extends RefCounted


static func label_key(hardpoint: StringName) -> StringName:
	match hardpoint:
		&"magazine":
			return &"ui.equipment.weapon_mag"
		&"grip":
			return &"ui.equipment.weapon_grip"
		&"muzzle":
			return &"ui.equipment.weapon_muzzle"
		&"scope":
			return &"ui.equipment.weapon_scope"
		&"stock":
			return &"ui.equipment.weapon_stock"
		&"tactic":
			return &"ui.equipment.weapon_tactic"
		_:
			return &""
