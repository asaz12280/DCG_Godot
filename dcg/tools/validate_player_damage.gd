extends SceneTree

const DamageEventScript := preload("res://scripts/combat/damage_event.gd")
const PlayerScene := preload("res://scenes/player/player_3d.tscn")
const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const WoodItem := preload("res://data/items/crafting/wood.tres")

var _errors: Array[String] = []
var _death_signal_count := 0
var _last_health := -1.0
var _last_health_max := -1.0


func _initialize() -> void:
	await _validate_player_takes_damage_once()
	await _validate_death_notifies_raid_session()
	if _errors.is_empty():
		print("[player_damage] OK health=decreases death=once raid_result=dead hud_signal=emits")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_player_takes_damage_once() -> void:
	var player := PlayerScene.instantiate()
	root.add_child(player)
	await process_frame
	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)

	var max_health := float(player.get_total_max_health())
	var light_hit := DamageEventScript.new(10.0, null, null, [&"validation"])
	if not player.apply_damage(light_hit):
		_errors.append("Player should accept positive DamageEvent.")
	if float(player.health) >= max_health:
		_errors.append("Player health should decrease after damage.")
	if _last_health < 0.0 or _last_health_max <= 0.0:
		_errors.append("Player should emit health_changed when damaged.")

	var lethal_hit := DamageEventScript.new(max_health * 5.0, null, null, [&"validation"])
	if not player.apply_damage(lethal_hit):
		_errors.append("Player should accept lethal DamageEvent.")
	if not bool(player.is_dead):
		_errors.append("Player should enter dead state at zero health.")
	if _death_signal_count != 1:
		_errors.append("Player death should emit exactly once after first lethal hit.")
	if player.apply_damage(lethal_hit):
		_errors.append("Dead player should reject further damage events.")
	if _death_signal_count != 1:
		_errors.append("Player death should not emit repeatedly.")
	_free_node(player)


func _validate_death_notifies_raid_session() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	var player := scene.get_node_or_null("Player3D")
	var session := scene.get_node_or_null("RaidSession")
	if player == null:
		_errors.append("Gameplay scene should include Player3D.")
		_free_node(scene)
		return
	if session == null:
		_errors.append("Gameplay scene should include RaidSession.")
		_free_node(scene)
		return
	player.add_item_resource(WoodItem, 2)
	var lethal_hit := DamageEventScript.new(float(player.get_total_max_health()) * 5.0, null, null, [&"validation"])
	player.apply_damage(lethal_hit)
	if not bool(session.dead):
		_errors.append("Player death should notify RaidSession and create a dead raid result.")
	var result: Dictionary = session.build_result()
	if str(result.get("outcome", "")) != "dead":
		_errors.append("RaidSession result should use dead outcome after player death.")
	var lost_items := result.get("lost_items", []) as Array
	if lost_items.is_empty():
		_errors.append("Player death result should include lost backpack items.")
	_free_node(scene)


func _on_health_changed(current: float, maximum: float) -> void:
	_last_health = current
	_last_health_max = maximum


func _on_player_died(_event: DamageEvent) -> void:
	_death_signal_count += 1


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
