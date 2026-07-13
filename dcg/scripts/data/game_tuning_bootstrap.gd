extends Node

const CsvDataTableLoaderScript := preload("res://scripts/data/csv_data_table_loader.gd")
const ITEM_TABLE_PATH := "res://data/tuning/items.csv"
const WEAPON_TABLE_PATH := "res://data/tuning/weapons.csv"
const DIFFICULTY_TABLE_PATH := "res://data/tuning/difficulty.csv"
const SCHEMA_VERSION := 1

const WEAPON_INT_FIELDS := [
	"damage",
	"projectiles_per_shot",
	"magazine_capacity",
	"max_durability",
	"repair_max_durability_loss",
]
const WEAPON_FLOAT_FIELDS := [
	"fire_rate_per_second",
	"projectile_spread_degrees",
	"armor_penetration_level",
	"critical_chance",
	"projectile_pierce_chance",
	"reload_duration_seconds",
	"projectile_range",
	"durability_wear_per_shot",
	"durability_penalty_ratio",
	"vertical_recoil",
	"horizontal_recoil",
]
const LEGACY_WEAPON_FIELDS := {
	"damage": "damage",
	"fire_rate_per_second": "fire_rate_per_second",
	"projectiles_per_shot": "projectiles_per_shot",
	"projectile_spread_degrees": "projectile_spread_degrees",
	"armor_penetration_level": "weapon_armor_penetration_level",
	"critical_chance": "critical_chance",
	"projectile_pierce_chance": "projectile_pierce_chance",
	"magazine_capacity": "magazine_capacity",
	"reload_duration_seconds": "reload_duration_seconds",
	"projectile_range": "projectile_range",
	"durability_wear_per_shot": "weapon_durability_wear_per_shot",
	"max_durability": "max_durability",
	"repair_max_durability_loss": "repair_max_durability_loss",
	"durability_penalty_ratio": "durability_penalty_ratio",
	"vertical_recoil": "weapon_vertical_recoil",
	"horizontal_recoil": "weapon_horizontal_recoil",
}
const ITEM_INT_FIELDS := ["value", "max_stack"]
const ITEM_FLOAT_FIELDS := [
	"weight",
	"defense_bonus",
	"heal_amount",
	"use_duration_seconds",
	"max_health_bonus",
	"stamina_restore",
	"thirst_restore",
	"satiety_restore",
]

signal tuning_reloaded(errors: Array[String])

var last_errors: Array[String] = []
var _tuned_item_resources: Array[ItemDef] = []
var _tuned_weapon_resources: Array[ItemDef] = []
var _tuned_difficulty_resources: Array[DifficultyProfile] = []


func _ready() -> void:
	reload_tuning()


func reload_tuning() -> Array[String]:
	last_errors.clear()
	_tuned_item_resources.clear()
	_tuned_weapon_resources.clear()
	_tuned_difficulty_resources.clear()
	_apply_item_rows(CsvDataTableLoaderScript.load_records(ITEM_TABLE_PATH))
	_apply_weapon_rows(CsvDataTableLoaderScript.load_records(WEAPON_TABLE_PATH))
	_apply_difficulty_rows(CsvDataTableLoaderScript.load_records(DIFFICULTY_TABLE_PATH))
	for error in last_errors:
		push_error("Game tuning: %s" % error)
	tuning_reloaded.emit(last_errors.duplicate())
	return last_errors.duplicate()


func _apply_item_rows(rows: Array[Dictionary]) -> void:
	var seen_ids: Dictionary = {}
	for row in rows:
		var item_id := StringName(str(row.get("item_id", "")).strip_edges())
		if not _validate_common_row(row, item_id, "item") or seen_ids.has(item_id):
			if seen_ids.has(item_id):
				last_errors.append("Duplicate item tuning id: %s" % item_id)
			continue
		seen_ids[item_id] = true
		var resource_path := str(row.get("resource_path", ""))
		var item := load(resource_path) as ItemDef
		if item == null or item.id != item_id:
			last_errors.append("Item tuning row %s does not resolve to a matching ItemDef." % item_id)
			continue
		for field in ITEM_INT_FIELDS:
			item.set(field, int(row.get(field, item.get(field))))
		for field in ITEM_FLOAT_FIELDS:
			item.set(field, float(row.get(field, item.get(field))))
		if item.armor_profile != null:
			item.armor_profile.defense_bonus = item.defense_bonus
		_tuned_item_resources.append(item)


func _apply_weapon_rows(rows: Array[Dictionary]) -> void:
	var seen_ids: Dictionary = {}
	for row in rows:
		var weapon_id := StringName(str(row.get("weapon_id", "")).strip_edges())
		if not _validate_common_row(row, weapon_id, "weapon") or seen_ids.has(weapon_id):
			if seen_ids.has(weapon_id):
				last_errors.append("Duplicate weapon tuning id: %s" % weapon_id)
			continue
		seen_ids[weapon_id] = true
		var resource_path := str(row.get("resource_path", ""))
		var item := load(resource_path) as ItemDef
		if item == null or item.id != weapon_id or item.weapon_profile == null:
			last_errors.append("Weapon tuning row %s does not resolve to a matching ItemDef with WeaponProfile." % weapon_id)
			continue
		var profile := item.weapon_profile
		profile.weapon_kind = str(row.get("weapon_kind", profile.weapon_kind))
		for field in WEAPON_INT_FIELDS:
			profile.set(field, int(row.get(field, profile.get(field))))
		for field in WEAPON_FLOAT_FIELDS:
			profile.set(field, float(row.get(field, profile.get(field))))
		for profile_field in LEGACY_WEAPON_FIELDS.keys():
			item.set(LEGACY_WEAPON_FIELDS[profile_field], profile.get(profile_field))
		_tuned_weapon_resources.append(item)


func _apply_difficulty_rows(rows: Array[Dictionary]) -> void:
	var seen_ids: Dictionary = {}
	for row in rows:
		var difficulty_id := StringName(str(row.get("difficulty_id", "")).strip_edges())
		if not _validate_common_row(row, difficulty_id, "difficulty") or seen_ids.has(difficulty_id):
			if seen_ids.has(difficulty_id):
				last_errors.append("Duplicate difficulty tuning id: %s" % difficulty_id)
			continue
		seen_ids[difficulty_id] = true
		var resource_path := str(row.get("resource_path", ""))
		var profile := load(resource_path) as DifficultyProfile
		if profile == null or profile.id != difficulty_id:
			last_errors.append("Difficulty tuning row %s does not resolve to a matching DifficultyProfile." % difficulty_id)
			continue
		profile.player_health_multiplier = maxf(float(row.get("player_health_multiplier", profile.player_health_multiplier)), 0.01)
		_tuned_difficulty_resources.append(profile)


func _validate_common_row(row: Dictionary, id: StringName, domain: String) -> bool:
	if int(row.get("schema_version", 0)) != SCHEMA_VERSION:
		last_errors.append("%s tuning row %s requires schema_version %d." % [domain.capitalize(), id, SCHEMA_VERSION])
		return false
	if id == &"":
		last_errors.append("%s tuning row requires an id." % domain.capitalize())
		return false
	var resource_path := str(row.get("resource_path", ""))
	if resource_path == "" or not ResourceLoader.exists(resource_path):
		last_errors.append("%s tuning row %s has an invalid resource_path." % [domain.capitalize(), id])
		return false
	return true
