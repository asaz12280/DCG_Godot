class_name EnemyLootDrop3D
extends Node

const LootContainerScript := preload("res://scripts/loot/loot_container_3d.gd")

@export_range(1, 12, 1) var roll_count := 1
@export_range(0.0, 6.0, 0.1) var drop_radius := 0.85
@export_range(1, 12, 1) var corpse_container_capacity := 4
@export var roll_seed := 0

var has_dropped := false
var spawned_pickups: Array[NodePath] = []
var spawned_containers: Array[NodePath] = []

var _enemy_body: Node3D = null


func _ready() -> void:
	_enemy_body = get_parent() as Node3D
	if _enemy_body != null and _enemy_body.has_signal("died"):
		_enemy_body.died.connect(_on_enemy_died)


func drop_loot() -> Array[Node3D]:
	var spawned: Array[Node3D] = []
	if has_dropped:
		return spawned

	has_dropped = true
	var table: Resource = _load_loot_table()
	if table == null or not table.has_method("roll"):
		return spawned

	var stacks: Array[Dictionary] = table.roll(roll_count, roll_seed)
	var corpse_container := _spawn_corpse_container(stacks)
	if corpse_container != null:
		spawned.append(corpse_container)
		spawned_pickups.append(corpse_container.get_path())
		spawned_containers.append(corpse_container.get_path())
	return spawned


func _on_enemy_died(_event: DamageEvent) -> void:
	drop_loot()


func _load_loot_table() -> Resource:
	if _enemy_body == null or not _enemy_body.has_meta("enemy_def"):
		return null
	var enemy_def: Resource = _enemy_body.get_meta("enemy_def") as Resource
	if enemy_def == null:
		return null
	var loot_table_path := str(enemy_def.get("loot_table_path"))
	if loot_table_path == "" or not ResourceLoader.exists(loot_table_path):
		return null
	return load(loot_table_path) as Resource


func _spawn_corpse_container(stacks: Array[Dictionary]) -> Node3D:
	if stacks.is_empty():
		return null
	var corpse := LootContainerScript.new() as LootContainer3D
	if corpse == null:
		return null
	corpse.name = "EnemyCorpseLoot"
	corpse.container_capacity = maxi(corpse_container_capacity, stacks.size())
	corpse.interact_keycode = KEY_F
	corpse.display_name_key = &"ui.container.enemy_corpse"
	corpse.display_name = "拾荒者屍體"
	corpse.prompt_key = &"prompt.loot_corpse"
	corpse.prompt_text = "按 F 搜刮屍體"
	corpse.opened_prompt_key = &"prompt.view_corpse"
	corpse.opened_prompt_text = "按 F 查看屍體"

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := SphereShape3D.new()
	shape.radius = 1.35
	collision.shape = shape
	collision.position = Vector3(0.0, 0.55, 0.0)
	corpse.add_child(collision)

	var prompt_label := Label3D.new()
	prompt_label.name = "PromptLabel"
	prompt_label.visible = false
	prompt_label.position = Vector3(0.0, 1.35, 0.0)
	prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt_label.font_size = 34
	prompt_label.modulate = Color(1.0, 0.92, 0.58, 1.0)
	prompt_label.outline_size = 8
	prompt_label.outline_modulate = Color(0.05, 0.05, 0.04, 1.0)
	corpse.add_child(prompt_label)

	var spawn_parent := _get_spawn_parent()
	spawn_parent.add_child(corpse)
	corpse.global_position = _get_drop_position()
	corpse.load_static_contents(stacks)
	return corpse


func _get_spawn_parent() -> Node:
	if _enemy_body != null and _enemy_body.get_parent() != null:
		return _enemy_body.get_parent()
	return get_tree().root


func _get_drop_position() -> Vector3:
	if _enemy_body == null:
		return Vector3.ZERO
	var offset := Vector3.FORWARD * drop_radius
	return _enemy_body.global_position + offset + Vector3(0.0, 0.08, 0.0)
