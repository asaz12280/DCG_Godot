extends SceneTree

const PlayerScene: PackedScene = preload("res://scenes/player/player_3d.tscn")
const Bandage: ItemDef = preload("res://data/items/medical/bandage.tres")
const BottledWater: ItemDef = preload("res://data/items/food/bottled_water.tres")

func _initialize() -> void:
	var root_node: Node3D = Node3D.new()
	get_root().add_child(root_node)
	var player: Node = PlayerScene.instantiate()
	if player == null:
		push_error("player scene not instantiate")
		quit(1)
		return
	root_node.add_child(player)
	await process_frame
	print("player_ready=%s" % str(player != null))
	print("slots_before=%s" % str(player.call("get_quick_bar_state")))
	var ok_bandage: bool = bool(player.call("add_item_resource", Bandage, 1))
	var ok_water: bool = bool(player.call("add_item_resource", BottledWater, 1))
	print("add_results=%s,%s" % [ok_bandage, ok_water])
	await process_frame
	var inventory: RefCounted = player.call("get_inventory_model")
	if inventory == null:
		push_error("inventory null")
		quit(1)
		return
	var stacks: Array[Dictionary] = inventory.call("get_display_items")
	var bandage_index := -1
	var water_index := -1
	for i in range(stacks.size()):
		var stack: Dictionary = stacks[i]
		if str(stack.get("id", "")) == "bandage":
			bandage_index = i
		if str(stack.get("id", "")) == "bottled_water":
			water_index = i
	print("bandage_index=%s water_index=%s" % [bandage_index, water_index])
	if bandage_index >= 0:
		var assigned: bool = bool(player.call("assign_quick_slot_for_inventory_stack", 3, bandage_index))
		print("assign_bandage_3=%s" % assigned)
	if water_index >= 0:
		var assigned2: bool = bool(player.call("assign_quick_slot_for_inventory_stack", 4, water_index))
		print("assign_water_4=%s" % assigned2)
		var moved: bool = bool(player.call("move_quick_slot_to_key", 4, 5))
		print("move_water_4_to_5=%s" % moved)
		var state: Array = player.call("get_quick_bar_state")
		print("quick_state=%s" % str(state))
	player.call("select_quick_slot", 3)
	player.call("use_selected_quick_item")
	await process_frame
	var item_state: Dictionary = player.call("get_item_use_state")
	print("is_selected=%s item_state=%s" % [str(player.get("_selected_quick_item_key")), str(item_state)])
	player.call("_update_item_use", 3.0)
	print("after_health=%s stamina=%s" % [str(player.get("health")), str(player.get("stamina"))])
	quit(0)
