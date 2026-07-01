extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const PlayerStatsProfileScript := preload("res://scripts/player/player_stats_profile.gd")
const ScavengerDef := preload("res://data/enemies/scavenger.tres")
const ScavengerScene := preload("res://scenes/enemies/scavenger_3d.tscn")
const LootTable := preload("res://data/loot_tables/refuge_outskirts_common.tres")
const WorkbenchUpgrade := preload("res://data/base_upgrades/workbench_level_1.tres")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")

const WOOD_PATH := "res://data/items/crafting/wood.tres"
const WIRE_PATH := "res://data/items/electronics/wire.tres"
const CASH_PATH := "res://data/items/currency/cash.tres"
const JUNK_PATH := "res://data/items/loot/junk.tres"

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_player_baseline()
	_validate_enemy_pressure()
	_validate_loot_pacing()
	_validate_extraction_timer()
	_validate_upgrade_cost()
	if _errors.is_empty():
		print("[early_balance] OK player=forgiving enemy=readable loot=progression extraction=pressure upgrade=reachable")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_player_baseline() -> void:
	var profile := PlayerStatsProfileScript.new()
	if profile.base_max_health < 105.0 or profile.base_max_health > 125.0:
		_errors.append("Early player max health should stay in the forgiving 105-125 range.")
	if profile.base_max_stamina < 105.0 or profile.base_max_stamina > 125.0:
		_errors.append("Early player stamina should support short looting routes in the 105-125 range.")
	if profile.sprint_stamina_cost < 18.0 or profile.sprint_stamina_cost > 24.0:
		_errors.append("Sprint stamina cost should allow several short bursts before exhaustion.")
	if profile.stamina_recovery_rate < 22.0 or profile.stamina_recovery_rate > 30.0:
		_errors.append("Stamina recovery should be quick enough for early route testing.")
	if profile.base_sprint_speed <= profile.base_walk_speed:
		_errors.append("Sprint speed should remain faster than walk speed.")


func _validate_enemy_pressure() -> void:
	var enemy_def := ScavengerDef as Resource
	if enemy_def == null or not enemy_def.has_method("is_valid") or not enemy_def.is_valid():
		_errors.append("Scavenger balance validation requires a valid EnemyDef.")
		return
	var pistol_shots_to_kill := ceili(float(enemy_def.max_health) / maxf(float(Pistol.damage), 1.0))
	if pistol_shots_to_kill < 2 or pistol_shots_to_kill > 3:
		_errors.append("Scavenger should take 2-3 pistol hits in the early slice, got %d." % pistol_shots_to_kill)
	var hits_to_kill_player := ceili(110.0 / maxf(float(enemy_def.damage), 1.0))
	if hits_to_kill_player < 8 or hits_to_kill_player > 14:
		_errors.append("Scavenger should threaten the player without deleting them, got %d hits to kill." % hits_to_kill_player)
	if float(enemy_def.detect_radius) < 8.0 or float(enemy_def.detect_radius) > 11.0:
		_errors.append("Scavenger detect radius should create readable aggro before close contact.")
	if float(enemy_def.move_speed) < 2.7 or float(enemy_def.move_speed) > 3.4:
		_errors.append("Scavenger move speed should be chaseable but not faster than sprint.")
	var scene := ScavengerScene.instantiate()
	root.add_child(scene)
	if not is_equal_approx(float(scene.get("max_health")), float(enemy_def.max_health)):
		_errors.append("Scavenger scene max_health should match EnemyDef after tuning.")
	var marker := scene.get_node_or_null("DetectRadiusMarker")
	if marker == null or not is_equal_approx(float(marker.get_meta("detect_radius", 0.0)), float(enemy_def.detect_radius)):
		_errors.append("Scavenger scene detect marker should match EnemyDef after tuning.")
	scene.free()


func _validate_loot_pacing() -> void:
	var entries: Dictionary = {}
	for entry in LootTable.entries:
		if entry == null:
			continue
		entries[str(entry.item_path)] = entry
	for required_path in [WOOD_PATH, WIRE_PATH, CASH_PATH, JUNK_PATH]:
		if not entries.has(required_path):
			_errors.append("Common loot table should include early pacing item: %s" % required_path)
	var wood: Resource = entries.get(WOOD_PATH, null) as Resource
	var wire: Resource = entries.get(WIRE_PATH, null) as Resource
	var cash: Resource = entries.get(CASH_PATH, null) as Resource
	if wood != null and (int(wood.min_quantity) < 2 or int(wood.max_quantity) < 4):
		_errors.append("Wood drops should be generous enough to support first-upgrade routing.")
	if wire != null and float(wire.weight) < 2.0:
		_errors.append("Wire should not be too rare for the first-upgrade loop.")
	if cash != null and (int(cash.min_quantity) < 6 or int(cash.max_quantity) < 20):
		_errors.append("Cash drops should support early economy testing without requiring many raids.")
	var rolled := LootTable.roll(24, 2801)
	if rolled.size() < 24:
		_errors.append("Common loot table should roll one stack per requested roll.")
	if _total_quantity(rolled, WOOD_PATH) < 4:
		_errors.append("A deterministic early route sample should produce at least 4 wood across 24 rolls.")
	if _total_quantity(rolled, WIRE_PATH) < 2:
		_errors.append("A deterministic early route sample should produce at least 2 wire across 24 rolls.")


func _validate_extraction_timer() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	var zone := scene.get_node_or_null("SceneProps/ExtractionZone")
	if zone == null:
		_errors.append("Gameplay scene should include ExtractionZone for balance validation.")
	else:
		var required_time := float(zone.get("required_time"))
		if required_time < 4.0 or required_time > 6.0:
			_errors.append("Early extraction timer should be 4-6 seconds for readable pressure, got %.1f." % required_time)
	scene.free()


func _validate_upgrade_cost() -> void:
	if int(WorkbenchUpgrade.money_cost) < 10 or int(WorkbenchUpgrade.money_cost) > 20:
		_errors.append("Workbench Level 1 money cost should stay reachable after the first quest reward.")
	if _upgrade_cost(WOOD_PATH) != 3:
		_errors.append("Workbench Level 1 should cost 3 wood in the early balance pass.")
	if _upgrade_cost(WIRE_PATH) != 2:
		_errors.append("Workbench Level 1 should cost 2 wire in the early balance pass.")
	if WorkbenchUpgrade.starter_ammo_bonus != 1:
		_errors.append("Workbench Level 1 should keep the small +1 starter ammo reward.")


func _upgrade_cost(item_path: String) -> int:
	for cost in WorkbenchUpgrade.item_costs:
		if str(cost.get("item_path", "")) == item_path:
			return int(cost.get("quantity", 0))
	return 0


func _total_quantity(stacks: Array, item_path: String) -> int:
	var total := 0
	for stack in stacks:
		if typeof(stack) != TYPE_DICTIONARY:
			continue
		if str((stack as Dictionary).get("item_path", "")) == item_path:
			total += int((stack as Dictionary).get("quantity", 0))
	return total
