class_name ItemInspectionWeaponRows
extends RefCounted


static func build(snapshot: Dictionary, capabilities: Dictionary, include_durability: bool = false) -> Array[Dictionary]:
	if str(capabilities.get("weapon_kind", "firearm")) == "melee":
		return _melee_rows(snapshot, capabilities, include_durability)
	return _firearm_rows(snapshot, capabilities, include_durability)


static func _firearm_rows(snapshot: Dictionary, capabilities: Dictionary, include_durability: bool) -> Array[Dictionary]:
	var base_capacity := maxi(int(snapshot.get("base_magazine_capacity", 0)), 0)
	var capacity_bonus := maxi(int(snapshot.get("magazine_capacity_bonus", 0)), 0)
	var total_capacity := maxi(int(snapshot.get("magazine_capacity", base_capacity + capacity_bonus)), 0)
	var rows: Array[Dictionary] = [
		_row(&"weapon_damage", &"ui.weapon_stat.damage", "%.1f" % maxf(float(snapshot.get("damage", 0.0)), 0.0)),
		_row(&"weapon_fire_rate", &"ui.weapon_stat.fire_rate", "%.1f" % maxf(float(snapshot.get("fire_rate_per_second", 0.0)), 0.0)),
		_row(&"weapon_armor_penetration", &"ui.weapon_stat.armor_penetration", "%.1f" % maxf(float(snapshot.get("armor_penetration_level", 0.0)), 0.0)),
		_row(&"weapon_critical_chance", &"ui.weapon_stat.critical_chance", "%.0f%%" % clampf(float(snapshot.get("critical_chance", 0.0)), 0.0, 100.0)),
		_row(&"weapon_pierce_chance", &"ui.weapon_stat.projectile_pierce_chance", "%.0f%%" % clampf(float(snapshot.get("projectile_pierce_chance", 0.0)), 0.0, 100.0)),
	]
	var projectiles_per_shot := maxi(int(snapshot.get("projectiles_per_shot", 1)), 1)
	if projectiles_per_shot > 1:
		rows.append(_row(&"weapon_projectiles_per_shot", &"ui.weapon_stat.projectiles_per_shot", str(projectiles_per_shot)))
		rows.append(_row(&"weapon_projectile_spread", &"ui.weapon_stat.projectile_spread", "%.1f°" % maxf(float(snapshot.get("projectile_spread_degrees", 0.0)), 0.0)))
	if bool(capabilities.get("uses_ammo", false)):
		rows.append(_row(&"weapon_magazine_capacity", &"ui.weapon_stat.magazine_capacity", _magazine_capacity_text(total_capacity, base_capacity, capacity_bonus)))
		rows.append(_row(&"weapon_reload_duration", &"ui.weapon_stat.reload_duration", "%.2f s" % maxf(float(snapshot.get("reload_duration_seconds", 0.0)), 0.0)))
	rows.append(_row(&"weapon_vertical_recoil", &"ui.weapon_stat.vertical_recoil", "%.1f°" % maxf(float(snapshot.get("vertical_recoil", 0.0)), 0.0)))
	rows.append(_row(&"weapon_horizontal_recoil", &"ui.weapon_stat.horizontal_recoil", "%.1f°" % maxf(float(snapshot.get("horizontal_recoil", 0.0)), 0.0)))
	rows.append(_row(&"weapon_range", &"ui.weapon_stat.projectile_range", "%.1f m" % maxf(float(snapshot.get("projectile_range_meters", 0.0)), 0.0)))
	if bool(capabilities.get("has_durability", false)):
		rows.append(_row(&"weapon_durability_wear", &"ui.weapon_stat.durability_wear", "%.2f" % maxf(float(snapshot.get("durability_wear_per_shot", 0.0)), 0.0)))
	if include_durability:
		_append_durability_row(rows, snapshot)
	return rows


static func _melee_rows(snapshot: Dictionary, capabilities: Dictionary, include_durability: bool) -> Array[Dictionary]:
	var rows: Array[Dictionary] = [
		_row(&"weapon_damage", &"ui.weapon_stat.damage", "%.1f" % maxf(float(snapshot.get("damage", 0.0)), 0.0)),
		_row(&"weapon_attack_rate", &"ui.weapon_stat.attack_rate", "%.1f" % maxf(float(snapshot.get("fire_rate_per_second", 0.0)), 0.0)),
	]
	var armor_penetration := maxf(float(snapshot.get("armor_penetration_level", 0.0)), 0.0)
	if armor_penetration > 0.0:
		rows.append(_row(&"weapon_armor_penetration", &"ui.weapon_stat.armor_penetration", "%.1f" % armor_penetration))
	var critical_chance := clampf(float(snapshot.get("critical_chance", 0.0)), 0.0, 100.0)
	if critical_chance > 0.0:
		rows.append(_row(&"weapon_critical_chance", &"ui.weapon_stat.critical_chance", "%.0f%%" % critical_chance))
	rows.append(_row(&"weapon_attack_range", &"ui.weapon_stat.attack_range", "%.1f m" % maxf(float(snapshot.get("projectile_range_meters", 0.0)), 0.0)))
	if bool(capabilities.get("has_durability", false)):
		rows.append(_row(&"weapon_durability_wear", &"ui.weapon_stat.durability_wear", "%.2f" % maxf(float(snapshot.get("durability_wear_per_shot", 0.0)), 0.0)))
	if include_durability:
		_append_durability_row(rows, snapshot)
	return rows


static func _append_durability_row(rows: Array[Dictionary], snapshot: Dictionary) -> void:
	var durability: Dictionary = snapshot.get("durability", {}) as Dictionary
	var maximum := maxi(int(durability.get("max_durability", 0)), 0)
	if maximum <= 0:
		return
	rows.append(_row(&"durability", &"ui.weapon_stat.durability", "%d/%d" % [maxi(int(durability.get("current_durability", 0)), 0), maximum]))


static func _row(field_id: StringName, label_key: StringName, value: String) -> Dictionary:
	return {"field_id": field_id, "label_key": label_key, "value": value}


static func _magazine_capacity_text(total_capacity: int, base_capacity: int, capacity_bonus: int) -> String:
	if capacity_bonus <= 0:
		return str(total_capacity)
	return "%d (%d+%d)" % [total_capacity, base_capacity, capacity_bonus]
