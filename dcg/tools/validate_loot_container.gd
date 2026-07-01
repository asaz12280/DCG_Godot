extends SceneTree

const LootContainerScene := preload("res://scenes/loot/loot_container_basic.tscn")
const LootContainerScript := preload("res://scripts/loot/loot_container_3d.gd")
const InventoryModelScript := preload("res://scripts/inventory/inventory_model.gd")
const CommonTable := preload("res://data/loot_tables/refuge_outskirts_common.tres")
const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")

var _errors: Array[String] = []
var _opened_signal_count := 0


class FakePlayer:
	extends CharacterBody3D

	var inventory_model := InventoryModel.new()

	func _init() -> void:
		add_to_group("player")
		inventory_model.setup(24)

	func add_item_resource(item_def: ItemDef, quantity: int = 1) -> bool:
		return inventory_model.add_item(item_def, quantity)


func _initialize() -> void:
	_validate_container_grants_loot_once()
	_validate_scene_wiring()
	_validate_gameplay_map_wiring()
	_validate_ui_independence()
	if _errors.is_empty():
		print("[loot_container] OK roll=grants_inventory one_shot=blocks_repeat map=spawn_loot_extract ui_coupling=clean scene=wired")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_container_grants_loot_once() -> void:
	var container := LootContainerScript.new()
	container.loot_table = CommonTable
	container.roll_count = 2
	container.opened.connect(_on_container_opened)
	root.add_child(container)
	var player := FakePlayer.new()
	root.add_child(player)

	_opened_signal_count = 0
	if not container.try_open(player):
		_errors.append("LootContainer3D should open and grant loot to a valid player.")
	if player.inventory_model.get_used_slots() <= 0:
		_errors.append("LootContainer3D should add rolled loot to player inventory.")
	if not bool(container.get_state().get("has_opened", false)):
		_errors.append("LootContainer3D should mark itself opened after granting loot.")
	if _opened_signal_count != 1:
		_errors.append("LootContainer3D should emit opened exactly once on first open.")
	var slots_after_first_open := player.inventory_model.get_used_slots()
	if container.try_open(player):
		_errors.append("LootContainer3D one-shot containers should reject repeat opening.")
	if player.inventory_model.get_used_slots() != slots_after_first_open:
		_errors.append("LootContainer3D should not grant repeat loot after opened.")

	_free_node(container)
	_free_node(player)


func _validate_scene_wiring() -> void:
	var container := LootContainerScene.instantiate()
	root.add_child(container)
	if container.get_script() != LootContainerScript:
		_errors.append("Loot container scene should use LootContainer3D script.")
	if container.get_node_or_null("CollisionShape3D") == null:
		_errors.append("Loot container scene should include CollisionShape3D.")
	var prompt_label := container.get_node_or_null("PromptLabel")
	if prompt_label == null or not prompt_label is Label3D:
		_errors.append("Loot container scene should include a Label3D prompt.")
	if container.get("loot_table") == null:
		_errors.append("Loot container scene should bind a LootTable resource.")
	_free_node(container)


func _validate_gameplay_map_wiring() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	var spawn_marker := scene.get_node_or_null("SceneProps/PlayerSpawnMarker")
	if spawn_marker == null:
		_errors.append("Gameplay map should include a clear PlayerSpawnMarker.")
	var extraction_zone := scene.get_node_or_null("SceneProps/ExtractionZone")
	if extraction_zone == null:
		_errors.append("Gameplay map should include an ExtractionZone.")
	var loot_container_count := 0
	var scene_props := scene.get_node_or_null("SceneProps")
	if scene_props != null:
		for child in scene_props.get_children():
			if child.get_script() == LootContainerScript:
				loot_container_count += 1
	if loot_container_count < 2:
		_errors.append("Gameplay map should include at least two LootContainer3D instances.")
	_free_node(scene)


func _validate_ui_independence() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/loot/loot_container_3d.gd")
	if source.contains("InventoryEquipmentUI") or source.contains("scripts/ui"):
		_errors.append("LootContainer3D should not depend on InventoryEquipmentUI or UI scripts.")


func _on_container_opened(_rolled_stacks: Array[Dictionary]) -> void:
	_opened_signal_count += 1


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
