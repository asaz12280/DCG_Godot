extends SceneTree

const RaidSessionScript := preload("res://scripts/raid/raid_session.gd")
const RaidResultScript := preload("res://scripts/raid/raid_result.gd")
const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_begin_and_extraction()
	_validate_death_lockout()
	_validate_restart_after_finish()
	_validate_result_schema_defaults()
	_validate_gameplay_scene_wiring()
	if _errors.is_empty():
		print("[raid_session] OK begin=active extraction=exclusive death=exclusive result=schema_serializable scene=wired")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_begin_and_extraction() -> void:
	var session := _make_session()
	session.begin_raid("validation_map")
	session.elapsed_time = 12.5
	var state := session.get_state()
	if not bool(state.get("active", false)):
		_errors.append("RaidSession should become active after begin_raid().")
	if str(state.get("map_id", "")) != "validation_map":
		_errors.append("RaidSession should keep the selected map id.")
	if not session.register_extraction({"extracted_items": [{"item_path": "res://data/items/crafting/wood.tres", "quantity": 1}]}):
		_errors.append("RaidSession should allow extraction while active.")
	if session.dead:
		_errors.append("RaidSession should not be dead after extraction.")
	var result := session.build_result()
	if str(result.get("outcome", "")) != RaidSessionScript.OUTCOME_EXTRACTED:
		_errors.append("Extraction result should use extracted outcome.")
	if typeof(result.get("extracted_items", null)) != TYPE_ARRAY:
		_errors.append("RaidSession should preserve serializable result context.")
	_validate_required_result_keys(result, "extraction")
	if session.register_player_death():
		_errors.append("RaidSession should reject death after extraction.")
	session.free()


func _validate_death_lockout() -> void:
	var session := _make_session()
	session.begin_raid("death_map")
	session.elapsed_time = 4.0
	if not session.register_player_death({"lost_items": [{"item_path": "res://data/items/currency/cash.tres", "quantity": 2}]}):
		_errors.append("RaidSession should allow player death while active.")
	if session.extracted:
		_errors.append("RaidSession should not be extracted after death.")
	var result := session.build_result()
	if str(result.get("outcome", "")) != RaidSessionScript.OUTCOME_DEAD:
		_errors.append("Death result should use dead outcome.")
	if typeof(result.get("lost_items", null)) != TYPE_ARRAY:
		_errors.append("RaidSession should preserve serializable death context.")
	_validate_required_result_keys(result, "death")
	if session.register_extraction():
		_errors.append("RaidSession should reject extraction after death.")
	session.free()


func _validate_restart_after_finish() -> void:
	var session := _make_session()
	session.begin_raid("first")
	session.register_extraction()
	session.begin_raid("second")
	var state := session.get_state()
	if not bool(state.get("active", false)):
		_errors.append("RaidSession should support a clean new raid after a finished raid.")
	if bool(state.get("extracted", true)) or bool(state.get("dead", true)):
		_errors.append("RaidSession should clear terminal flags when a new raid begins.")
	if str(state.get("outcome", "")) != RaidSessionScript.OUTCOME_ACTIVE:
		_errors.append("New raid should return to active outcome.")
	session.free()


func _validate_result_schema_defaults() -> void:
	var debug_node := Node.new()
	var result := RaidResultScript.create(RaidResultScript.OUTCOME_EXTRACTED, {"debug_node": debug_node})
	debug_node.free()
	_validate_required_result_keys(result, "schema")
	if not RaidResultScript.is_serializable(result):
		_errors.append("RaidResult should sanitize Object references into serializable values.")


func _validate_required_result_keys(result: Dictionary, label: String) -> void:
	var required_keys := [
		"outcome",
		"extracted_items",
		"lost_items",
		"kept_safe_pocket_items",
		"money_delta",
		"duration",
	]
	for key in required_keys:
		if not result.has(key):
			_errors.append("Raid result %s should include `%s`." % [label, key])
	var errors := RaidResultScript.validate(result)
	for error in errors:
		_errors.append("Raid result %s invalid: %s" % [label, error])


func _validate_gameplay_scene_wiring() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	var session := scene.get_node_or_null("RaidSession")
	if session == null:
		_errors.append("Gameplay test scene should include a RaidSession node.")
	elif not session is RaidSession:
		_errors.append("Gameplay RaidSession node should use the RaidSession script.")
	else:
		session._ready()
		if not session.active:
			_errors.append("Gameplay RaidSession should auto-begin when the scene starts.")
	scene.free()


func _make_session() -> RaidSession:
	var session := RaidSessionScript.new()
	session.auto_begin = false
	return session
