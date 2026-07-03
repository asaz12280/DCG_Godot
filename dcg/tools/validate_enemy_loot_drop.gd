extends SceneTree

const ScavengerScene := preload("res://scenes/enemies/scavenger_3d.tscn")
const EnemyLootDropScript := preload("res://scripts/ai/enemy_loot_drop_3d.gd")
const LootContainerScript := preload("res://scripts/loot/loot_container_3d.gd")
const DamageEventScript := preload("res://scripts/combat/damage_event.gd")

var _errors: Array[String] = []


class FakePlayer:
	extends CharacterBody3D

	var inventory_model := InventoryModel.new()

	func _init() -> void:
		add_to_group("player")
		inventory_model.setup(24)

	func add_item_resource(item_def: ItemDef, quantity: int = 1) -> bool:
		return inventory_model.add_item(item_def, quantity)


func _initialize() -> void:
	await _validate_scavenger_creates_lootable_body_once()
	_validate_ui_independence()
	if _errors.is_empty():
		print("[enemy_loot_drop] OK death=corpse_container key=F grid=container repeat=blocked ui_coupling=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_scavenger_creates_lootable_body_once() -> void:
	var map_root := Node3D.new()
	root.add_child(map_root)
	var enemy := ScavengerScene.instantiate()
	map_root.add_child(enemy)
	await process_frame

	var dropper := enemy.get_node_or_null("EnemyLootDrop3D")
	if dropper == null:
		_errors.append("Scavenger should include EnemyLootDrop3D.")
		_free_node(map_root)
		return
	if dropper.get_script() != EnemyLootDropScript:
		_errors.append("EnemyLootDrop3D should use the enemy loot drop script.")
	dropper.set("roll_seed", 101)

	enemy.global_position = Vector3(2.0, 0.0, -1.0)
	var lethal := DamageEventScript.new(999.0, null, null, [&"validation"])
	enemy.apply_damage(lethal)
	await process_frame

	var containers := _find_loot_containers(map_root)
	if containers.is_empty():
		_errors.append("Killing Scavenger should create a lootable corpse container.")
		_free_node(map_root)
		return

	var corpse := containers[0]
	if int(corpse.get("interact_keycode")) != KEY_F:
		_errors.append("Enemy corpse loot should use F for looting.")
	if corpse.global_position.distance_to(enemy.global_position) > 2.0:
		_errors.append("Enemy corpse loot container should stay close to the enemy death position.")
	var prompt_label := corpse.get_node_or_null("PromptLabel") as Label3D
	if prompt_label == null:
		_errors.append("Enemy corpse loot should include a 3D prompt label.")
	var model: RefCounted = corpse.call("get_container_inventory_model")
	if model == null or int(model.call("get_capacity")) < 1:
		_errors.append("Enemy corpse loot should expose a container inventory model.")
	elif int(model.call("get_used_slots")) <= 0:
		_errors.append("Enemy corpse loot container should own dropped item slots.")

	var container_count_after_death := containers.size()
	dropper.call("drop_loot")
	await process_frame
	if _find_loot_containers(map_root).size() != container_count_after_death:
		_errors.append("EnemyLootDrop3D should not create repeat corpse containers for the same enemy.")

	var player := FakePlayer.new()
	map_root.add_child(player)
	corpse.call("_on_body_entered", player)
	if prompt_label != null:
		if not prompt_label.visible:
			_errors.append("Enemy corpse loot prompt should become visible when the player is in range.")
		if prompt_label.text.strip_edges() == "":
			_errors.append("Enemy corpse loot prompt should show readable loot text.")
	if not bool(corpse.call("try_open", player)):
		_errors.append("Enemy corpse loot should open through the container interaction path.")

	_free_node(map_root)


func _find_loot_containers(parent: Node) -> Array[Node3D]:
	var containers: Array[Node3D] = []
	for child in parent.find_children("*", "Area3D", true, false):
		var node_3d := child as Node3D
		if node_3d != null and child.get_script() == LootContainerScript:
			containers.append(node_3d)
	return containers


func _validate_ui_independence() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ai/enemy_loot_drop_3d.gd")
	if source.contains("InventoryEquipmentUI") or source.contains("scripts/ui"):
		_errors.append("EnemyLootDrop3D should not depend on InventoryEquipmentUI or UI scripts.")


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
