extends SceneTree

const PlayerStatsProfileScript := preload("res://scripts/player/player_stats_profile.gd")
const PlayerStatsScript := preload("res://scripts/player/player_stats_3d.gd")
const PlayerControllerScript := preload("res://scripts/player/player_controller_3d.gd")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_stats_profile()
	_validate_player_inventory_contract()
	_validate_no_known_gameplay_ui_coupling()
	if _errors.is_empty():
		print("[gameplay_architecture] OK player_stats=resource inventory=player_owned ui_coupling=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_stats_profile() -> void:
	var profile := PlayerStatsProfileScript.new()
	profile.base_walk_speed = 5.0
	profile.equipment_walk_speed_bonus = 1.25
	profile.base_carry_weight_limit = 40.0
	var stats := PlayerStatsScript.new(profile)
	if not is_equal_approx(stats.walk_speed(), 6.25):
		_errors.append("PlayerStats3D should calculate from PlayerStatsProfile without owner string lookup.")
	if not is_equal_approx(stats.carry_weight_limit(), 40.0):
		_errors.append("PlayerStats3D should expose profile carry weight.")


func _validate_player_inventory_contract() -> void:
	var player := CharacterBody3D.new()
	player.set_script(PlayerControllerScript)
	root.add_child(player)
	if not player.has_method("get_inventory_model"):
		_errors.append("PlayerController3D should expose get_inventory_model for UI binding.")
	if not player.has_method("add_item_resource"):
		_errors.append("PlayerController3D should own item pickup insertion.")
	player.queue_free()


func _validate_no_known_gameplay_ui_coupling() -> void:
	_expect_file_not_contains("res://scripts/player/player_input_reader_3d.gd", "current_scene.find_child(\"UIManager\"", "PlayerInputReader3D should use the UIManager autoload contract.")
	_expect_file_not_contains("res://scripts/inventory/loot_pickup_3d.gd", "InventoryEquipmentUI", "LootPickup3D should not depend on inventory UI nodes.")
	_expect_file_not_contains("res://scripts/player/player_stats_3d.gd", "owner.get(", "PlayerStats3D should not read owner properties by string.")


func _expect_file_not_contains(path: String, needle: String, message: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_errors.append("Cannot read %s" % path)
		return
	var content := file.get_as_text()
	if content.contains(needle):
		_errors.append(message)
