extends SceneTree

const ExtractionZoneScript := preload("res://scripts/raid/extraction_zone_3d.gd")
const RaidSessionScript := preload("res://scripts/raid/raid_session.gd")
const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_zone_countdown_and_cancellation()
	_validate_gameplay_scene_wiring()
	if _errors.is_empty():
		print("[extraction_flow] OK countdown=works cancel=works session=notified scene=wired")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_zone_countdown_and_cancellation() -> void:
	var test_root := Node3D.new()
	root.add_child(test_root)
	var session := RaidSessionScript.new()
	session.name = "RaidSession"
	session.auto_begin = false
	test_root.add_child(session)
	session.begin_raid("validation_map")

	var zone := ExtractionZoneScript.new()
	zone.name = "ExtractionZone"
	zone.required_time = 1.0
	zone.raid_session_path = NodePath("../RaidSession")
	test_root.add_child(zone)

	var player := CharacterBody3D.new()
	player.name = "Player3D"
	test_root.add_child(player)

	zone._on_body_entered(player)
	zone._process(0.4)
	if not bool(zone.get_state().get("active", false)):
		_errors.append("ExtractionZone should start countdown when the player enters.")
	if float(zone.get_state().get("progress", 0.0)) <= 0.0:
		_errors.append("ExtractionZone should advance progress while the player remains inside.")

	zone._on_body_exited(player)
	if bool(zone.get_state().get("active", true)):
		_errors.append("ExtractionZone should cancel countdown when the player exits.")
	if float(zone.get_state().get("progress", 1.0)) != 0.0:
		_errors.append("ExtractionZone should reset progress after cancellation.")
	if session.extracted:
		_errors.append("RaidSession should not extract when the countdown is cancelled.")

	zone._on_body_entered(player)
	zone._process(1.0)
	if not session.extracted:
		_errors.append("ExtractionZone should notify RaidSession when countdown completes.")
	var result := session.build_result()
	if str(result.get("source", "")) != "extraction_zone":
		_errors.append("ExtractionZone result context should stay serializable and identify the source.")

	test_root.free()


func _validate_gameplay_scene_wiring() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	var zone := scene.get_node_or_null("SceneProps/ExtractionZone")
	if zone == null:
		_errors.append("Gameplay scene should include SceneProps/ExtractionZone.")
	elif zone.get_script() != ExtractionZoneScript:
		_errors.append("Gameplay ExtractionZone should use ExtractionZone3D script.")
	else:
		if zone.get_node_or_null("CollisionShape3D") == null:
			_errors.append("Gameplay ExtractionZone should include a CollisionShape3D.")
		var prompt_label := zone.get_node_or_null("PromptLabel")
		if prompt_label == null or not prompt_label is Label3D:
			_errors.append("Gameplay ExtractionZone should include a Label3D prompt.")
		if str(zone.raid_session_path) == "":
			_errors.append("Gameplay ExtractionZone should have a RaidSession path or fallback.")
	var session := scene.get_node_or_null("RaidSession")
	if session == null:
		_errors.append("Gameplay scene should keep the RaidSession node required by extraction.")
	scene.free()
