class_name EnemyLootDrop3D
extends Node

const LootPickupScene := preload("res://scenes/items/loot_pickup_wood.tscn")

@export_range(1, 12, 1) var roll_count := 1
@export_range(0.0, 6.0, 0.1) var drop_radius := 0.85
@export var roll_seed := 0

var has_dropped := false
var spawned_pickups: Array[NodePath] = []

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
	for index in range(stacks.size()):
		var pickup := _spawn_pickup(stacks[index], index, stacks.size())
		if pickup == null:
			continue
		spawned.append(pickup)
		spawned_pickups.append(pickup.get_path())
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


func _spawn_pickup(stack: Dictionary, index: int, total_count: int) -> Node3D:
	var item_path := str(stack.get("item_path", ""))
	var quantity := maxi(int(stack.get("quantity", 0)), 0)
	if item_path == "" or quantity <= 0 or not ResourceLoader.exists(item_path):
		return null

	var item_def: Resource = load(item_path) as Resource
	if item_def == null:
		return null

	var pickup := LootPickupScene.instantiate() as Node3D
	if pickup == null:
		return null
	pickup.set("item_def", item_def)
	pickup.set("quantity", quantity)

	var spawn_parent := _get_spawn_parent()
	spawn_parent.add_child(pickup)
	pickup.global_position = _get_drop_position(index, total_count)
	return pickup


func _get_spawn_parent() -> Node:
	if _enemy_body != null and _enemy_body.get_parent() != null:
		return _enemy_body.get_parent()
	return get_tree().root


func _get_drop_position(index: int, total_count: int) -> Vector3:
	if _enemy_body == null:
		return Vector3.ZERO
	var safe_count := maxi(total_count, 1)
	var angle := TAU * float(index) / float(safe_count)
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * drop_radius
	return _enemy_body.global_position + offset + Vector3(0.0, 0.08, 0.0)
