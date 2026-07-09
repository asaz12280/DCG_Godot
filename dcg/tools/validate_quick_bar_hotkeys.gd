extends SceneTree

const PlayerScene := preload("res://scenes/player/player_3d.tscn")
const PlayerHudScript := preload("res://scripts/ui/player_hud_3d.gd")
const InventoryEquipmentUIScript := preload("res://scripts/ui/inventory_equipment_ui.gd")
const Pistol9mm := preload("res://data/items/weapons/pistol_9mm.tres")
const CombatKnife := preload("res://data/items/weapons/combat_knife.tres")
const Bandage := preload("res://data/items/medical/bandage.tres")
const Bread := preload("res://data/items/food/bread.tres")
const BottledWater := preload("res://data/items/food/bottled_water.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	await _validate_quick_bar_weapon_and_item_flow()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[quick_bar_hotkeys] OK bar=1_2_v_3_8 weapons=switch item=bind_use hud=state")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_quick_bar_weapon_and_item_flow() -> void:
	var scene: Node3D = Node3D.new()
	root.add_child(scene)
	var player: Node = PlayerScene.instantiate()
	scene.add_child(player)
	var hud: Control = PlayerHudScript.new()
	hud.size = Vector2(1280.0, 720.0)
	scene.add_child(hud)
	var inventory_ui: Control = InventoryEquipmentUIScript.new()
	inventory_ui.size = Vector2(1280.0, 720.0)
	scene.add_child(inventory_ui)
	await process_frame
	await physics_frame

	_add_and_equip(player, Pistol9mm, &"primary_weapon")
	_add_and_equip(player, Pistol9mm, &"sidearm")
	_add_and_equip(player, CombatKnife, &"melee")
	if not bool(player.call("add_item_resource", Bandage, 1)):
		_errors.append("Player should be able to add a bandage for quick slot validation.")
		_free_node(scene)
		return
	player.call("add_item_resource", Bread, 1)
	player.call("add_item_resource", BottledWater, 1)
	await process_frame

	var initial_display_state: Variant = hud.call("get_display_state")
	var initial_slots: Array = (initial_display_state as Dictionary).get("quick_bar_slots", []) as Array
	if initial_slots.size() != 9:
		_errors.append("HUD quick bar should expose 1, 2, V, and item keys 3-8.")
	if not _has_key_labels(initial_slots, ["1", "2", "V", "3", "4", "5", "6", "7", "8"]):
		_errors.append("HUD quick bar should preserve expected key labels.")

	_press_key(player, KEY_2)
	await process_frame
	var held_after_two: Dictionary = (player.call("get_held_weapon_state") as Dictionary)
	if str(held_after_two.get("weapon_slot_id", "")) != "sidearm":
		_errors.append("Pressing 2 should select the sidearm weapon slot.")

	var bandage_index: int = _find_inventory_item_index(player, "bandage")
	if bandage_index < 0:
		_errors.append("Validation setup should find bandage in backpack.")
		_free_node(scene)
		return
	if not bool(inventory_ui.call("assign_backpack_stack_to_quick_slot", bandage_index, 3)):
		_errors.append("Tab inventory surface should assign hovered/selected usable stack to quick key 3.")
	var assigned_display_state: Variant = hud.call("get_display_state")
	var assigned_slots: Array = (assigned_display_state as Dictionary).get("quick_bar_slots", []) as Array
	var quick_three := _slot_for_label(assigned_slots, "3")
	if quick_three.is_empty() or not bool(quick_three.get("assigned", false)):
		_errors.append("HUD quick bar should show an assigned item on key 3 after binding.")
	var bread_index: int = _find_inventory_item_index(player, "bread")
	var water_index: int = _find_inventory_item_index(player, "bottled_water")
	if bread_index < 0 or not bool(inventory_ui.call("assign_backpack_stack_to_quick_slot", bread_index, 4)):
		_errors.append("Food should be assignable to quick item key 4.")
	if water_index < 0 or not bool(inventory_ui.call("assign_backpack_stack_to_quick_slot", water_index, 5)):
		_errors.append("Drink should be assignable to quick item key 5.")
	else:
		if not bool(inventory_ui.call("assign_backpack_stack_to_quick_slot", water_index, 6)):
			_errors.append("Drink should be movable from one quick key to another.")
		var moved_display_state: Variant = hud.call("get_display_state")
		var moved_slots: Array = (moved_display_state as Dictionary).get("quick_bar_slots", []) as Array
		var quick_five := _slot_for_label(moved_slots, "5")
		var quick_six := _slot_for_label(moved_slots, "6")
		if not quick_five.is_empty() and bool(quick_five.get("assigned", false)):
			_errors.append("Reassigning the same stack should clear its previous quick slot.")
		if quick_six.is_empty() or not bool(quick_six.get("assigned", false)):
			_errors.append("Reassigning the same stack should place it on the destination quick key.")

	var maximum: float = float(player.call("get_total_max_health"))
	player.set("health", maxf(maximum - Bandage.heal_amount - 5.0, 1.0))
	var before_health: float = float(player.get("health"))
	_press_key(player, KEY_3)
	await process_frame
	var held_quick_item: Dictionary = player.call("get_held_weapon_state")
	if str(held_quick_item.get("mode", "")) != "item" or int(held_quick_item.get("quick_key", -1)) != 3:
		_errors.append("Pressing 3 should put the player into held item mode for the bound bandage.")
	_press_key(player, KEY_2)
	await process_frame
	var held_after_sidearm: Dictionary = player.call("get_held_weapon_state")
	if str(held_after_sidearm.get("mode", "")) != "firearm" or str(held_after_sidearm.get("weapon_slot_id", "")) != "sidearm":
		_errors.append("Pressing 2 while holding quick item 3 should return to the sidearm.")
	_press_key(player, KEY_3)
	await process_frame
	_press_key(player, KEY_V)
	await process_frame
	var held_after_melee: Dictionary = player.call("get_held_weapon_state")
	if str(held_after_melee.get("mode", "")) != "melee" or str(held_after_melee.get("weapon_slot_id", "")) != "melee":
		_errors.append("Pressing V while holding quick item 3 should return to melee weapon mode.")
	_press_key(player, KEY_3)
	await process_frame
	held_quick_item = player.call("get_held_weapon_state")
	if str(held_quick_item.get("mode", "")) != "item" or int(held_quick_item.get("quick_key", -1)) != 3:
		_errors.append("Pressing 3 again after weapon selection should hold the bound bandage again.")
	var item_state: Dictionary = player.call("get_item_use_state")
	if bool(item_state.get("active", false)):
		_errors.append("Pressing 3 should only select/hold the bound bandage, not consume it immediately.")
	_press_left_click(player)
	await process_frame
	item_state = (player.call("get_item_use_state") as Dictionary)
	if not bool(item_state.get("active", false)):
		_errors.append("Left-click while holding quick key 3 should start using the bound bandage.")
	player.call("_update_item_use", Bandage.use_duration_seconds + 0.25)
	var after_health := float(player.get("health"))
	if after_health <= before_health:
		_errors.append("Quick key bandage use should restore health.")
	if _find_inventory_item_index(player, "bandage") >= 0:
		_errors.append("Quick key bandage use should consume the bandage stack.")

	_free_node(scene)


func _validate_source_boundaries() -> void:
	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	for required in ["PlayerQuickSlotModelScript", "assign_quick_slot_for_inventory_stack", "select_quick_slot", "use_selected_quick_item", "KEY_3", "KEY_8"]:
		if not player_source.contains(required):
			_errors.append("PlayerController3D should own quick hotkey gameplay bridge through %s." % required)
	var inventory_source := FileAccess.get_file_as_string("res://scripts/ui/inventory_equipment_ui.gd")
	for required in ["assign_backpack_stack_to_quick_slot", "_assign_hovered_stack_to_quick_slot", "_get_quick_item_key_at", "PlayerQuickBarLayoutScript"]:
		if not inventory_source.contains(required):
			_errors.append("InventoryEquipmentUI should expose Tab inventory quick-slot assignment through %s." % required)
	var hud_source := FileAccess.get_file_as_string("res://scripts/ui/player_hud_painter.gd")
	if not hud_source.contains("_paint_quick_bar") or not hud_source.contains("_paint_quick_key_badge"):
		_errors.append("PlayerHUDPainter should draw the bottom quick bar without moving state ownership into UI.")


func _add_and_equip(player: Node, item_def: ItemDef, slot_id: StringName) -> void:
	if not bool(player.call("add_item_resource", item_def, 1)):
		_errors.append("Player should add %s for quick bar validation." % str(item_def.id))
		return
	var index := _find_inventory_item_index(player, str(item_def.id))
	if index < 0 or not bool(player.call("equip_inventory_stack", index, slot_id)):
		_errors.append("Player should equip %s into %s." % [str(item_def.id), str(slot_id)])


func _find_inventory_item_index(player: Node, item_id: String) -> int:
	var inventory_variant: Variant = player.call("get_inventory_model")
	if typeof(inventory_variant) != TYPE_OBJECT:
		return -1
	var inventory: RefCounted = inventory_variant as RefCounted
	var stacks_variant: Variant = inventory.get("stacks")
	if typeof(stacks_variant) != TYPE_ARRAY:
		return -1
	var stacks: Array = stacks_variant as Array
	for index in range(stacks.size()):
		if typeof(stacks[index]) != TYPE_DICTIONARY:
			continue
		var stack := stacks[index] as Dictionary
		if str(stack.get("id", "")) == item_id:
			return index
	return -1


func _has_key_labels(slots: Array, labels: Array[String]) -> bool:
	for label in labels:
		if _slot_for_label(slots, label).is_empty():
			return false
	return true


func _slot_for_label(slots: Array, label: String) -> Dictionary:
	for value in slots:
		var state := value as Dictionary
		if str(state.get("key_label", "")) == label:
			return state
	return {}


func _press_key(player: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.physical_keycode = keycode
	player.call("_unhandled_input", event)


func _press_left_click(player: Node) -> void:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	player.call("_unhandled_input", event)


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
