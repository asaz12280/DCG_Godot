extends SceneTree

const ScavengerScene := preload("res://scenes/enemies/scavenger_3d.tscn")
const EnemyLootDropScript := preload("res://scripts/ai/enemy_loot_drop_3d.gd")
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
	await _validate_scavenger_drops_pickup_once()
	_validate_ui_independence()
	if _errors.is_empty():
		print("[enemy_loot_drop] OK death=spawns_pickup pickup=adds_inventory repeat=blocked ui_coupling=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_scavenger_drops_pickup_once() -> void:
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

	var pickups := _find_pickups(map_root)
	if pickups.is_empty():
		_errors.append("Killing Scavenger should spawn at least one loot pickup.")
		_free_node(map_root)
		return

	var pickup := pickups[0]
	if pickup.get("item_def") == null:
		_errors.append("Spawned enemy loot pickup should bind an item_def.")
	if int(pickup.get("quantity")) <= 0:
		_errors.append("Spawned enemy loot pickup should have positive quantity.")
	if pickup.global_position.distance_to(enemy.global_position) > 2.0:
		_errors.append("Spawned enemy loot pickup should stay close to the enemy death position.")
	var pickup_mesh := pickup.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if pickup_mesh == null or not pickup_mesh.visible:
		_errors.append("Spawned enemy loot pickup should have a visible 3D mesh.")
	var prompt_label := pickup.get_node_or_null("PromptLabel") as Label3D
	if prompt_label == null:
		_errors.append("Spawned enemy loot pickup should include a 3D prompt label.")

	var pickup_count_after_death := pickups.size()
	dropper.call("drop_loot")
	await process_frame
	if _find_pickups(map_root).size() != pickup_count_after_death:
		_errors.append("EnemyLootDrop3D should not spawn repeat drops for the same enemy.")

	var player := FakePlayer.new()
	map_root.add_child(player)
	pickup.call("_on_body_entered", player)
	if prompt_label != null:
		if not prompt_label.visible:
			_errors.append("Enemy loot pickup prompt should become visible when the player is in range.")
		if prompt_label.text.strip_edges() == "":
			_errors.append("Enemy loot pickup prompt should show readable pickup text and quantity.")
	if not bool(pickup.call("_try_pickup")):
		_errors.append("Spawned enemy loot pickup should be collectible by a player.")
	if player.inventory_model.get_used_slots() <= 0:
		_errors.append("Collecting spawned enemy loot should add an inventory stack.")

	_free_node(map_root)


func _find_pickups(parent: Node) -> Array[Node3D]:
	var pickups: Array[Node3D] = []
	for child in parent.get_children():
		var node_3d := child as Node3D
		if node_3d == null:
			continue
		if child.has_method("_try_pickup"):
			pickups.append(node_3d)
	return pickups


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
