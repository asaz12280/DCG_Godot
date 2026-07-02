extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")
const Ammo := preload("res://data/items/ammo/ammo_9mm.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	await _validate_backpack_pistol_equips_to_visible_slot()
	await _validate_ammo_stays_in_backpack()
	await _validate_layout_fit(Vector2i(1280, 720))
	await _validate_layout_fit(Vector2i(1920, 1080))
	_validate_player_visible_ui_path()
	_validate_responsibility_boundary()
	if _errors.is_empty():
		print("[inventory_equipment_flow] OK backpack=visible equip=sidearm ammo=rejected layout=fit boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_backpack_pistol_equips_to_visible_slot() -> void:
	var context := await _spawn_inventory_context()
	if context.is_empty():
		return
	var player: Node = context["player"]
	var inventory_ui: Control = context["inventory_ui"]
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	var equipment_model: RefCounted = player.call("get_equipment_model")

	backpack_model.add_item(Pistol, 1)
	inventory_ui.call("open_inventory")
	await process_frame

	var before_state: Dictionary = inventory_ui.call("get_display_state")
	if not _state_has_catalog(before_state.get("backpack_items", []), 5):
		_errors.append("Inventory UI should visibly show No.5 pistol in backpack before equip.")
	if not bool(player.call("can_equip_inventory_stack", 0)):
		_errors.append("Player should report the visible pistol stack as equippable.")
	if not bool(inventory_ui.call("equip_backpack_stack", 0)):
		_errors.append("Inventory UI should let the player equip the visible pistol stack.")
	await process_frame

	var after_state: Dictionary = inventory_ui.call("get_display_state")
	var sidearm_stack: Dictionary = equipment_model.call("get_slot", &"sidearm")
	if _state_has_catalog(after_state.get("backpack_items", []), 5):
		_errors.append("Equipped No.5 pistol should leave the backpack list.")
	if int(sidearm_stack.get("catalog_number", 0)) != 5:
		_errors.append("Equipped No.5 pistol should appear in the sidearm equipment slot.")
	if not str(after_state.get("equipment_text", "")).contains(_item_name(Pistol)):
		_errors.append("Equipment panel should visibly show the equipped pistol name.")

	_free_node(context["scene"])


func _validate_ammo_stays_in_backpack() -> void:
	var context := await _spawn_inventory_context()
	if context.is_empty():
		return
	var player: Node = context["player"]
	var inventory_ui: Control = context["inventory_ui"]
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	var equipment_model: RefCounted = player.call("get_equipment_model")

	backpack_model.add_item(Ammo, 24)
	inventory_ui.call("open_inventory")
	await process_frame

	if bool(player.call("can_equip_inventory_stack", 0)):
		_errors.append("No.7 ammo should not be treated as equippable gear.")
	if bool(inventory_ui.call("equip_backpack_stack", 0)):
		_errors.append("Inventory UI should reject equipping No.7 ammo as gear.")
	await process_frame

	var state: Dictionary = inventory_ui.call("get_display_state")
	if not _state_has_catalog(state.get("backpack_items", []), 7):
		_errors.append("Rejected No.7 ammo should remain visible in the backpack.")
	if not _equipment_slots_are_empty(equipment_model):
		_errors.append("Rejected ammo equip should not alter equipment slots.")

	_free_node(context["scene"])


func _validate_layout_fit(size: Vector2i) -> void:
	root.size = size
	var context := await _spawn_inventory_context()
	if context.is_empty():
		return
	var inventory_ui: Control = context["inventory_ui"]
	inventory_ui.call("open_inventory")
	await process_frame
	var state: Dictionary = inventory_ui.call("get_display_state_for_viewport", Vector2(size))
	var rect: Rect2 = state.get("panel_rect", Rect2())
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		_errors.append("Inventory UI should expose a measurable panel rect at %s." % str(size))
	if rect.position.x < -1.0 or rect.position.y < -1.0 or rect.end.x > float(size.x) + 1.0 or rect.end.y > float(size.y) + 1.0:
		_errors.append("Inventory UI panel should fit within %s, got %s." % [str(size), str(rect)])
	_free_node(context["scene"])


func _validate_player_visible_ui_path() -> void:
	var ui_source := FileAccess.get_file_as_string("res://scripts/ui/inventory_equipment_ui.gd")
	for required in [
		"equip_backpack_stack",
		"equip_requested",
		"get_equipment_model",
		"get_equipment_stack_at",
	]:
		if not ui_source.contains(required):
			_errors.append("Inventory UI should expose visible equip flow term: %s." % required)

	var menu_source := FileAccess.get_file_as_string("res://scripts/ui/inventory_context_menu.gd")
	for required in ["equip_requested", "ui.inventory.equip", "can_equip_stack"]:
		if not menu_source.contains(required):
			_errors.append("Inventory context menu should expose equip action term: %s." % required)


func _validate_responsibility_boundary() -> void:
	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	for required in ["get_equipment_model", "can_equip_inventory_stack", "equip_inventory_stack", "get_default_equipment_slot_for_stack"]:
		if not player_source.contains(required):
			_errors.append("PlayerController3D should bridge inventory-to-equipment flow: %s." % required)

	var inventory_source := FileAccess.get_file_as_string("res://scripts/inventory/inventory_model.gd")
	for forbidden in ["EquipmentModel", "WeaponController3D", "InventoryEquipmentUI", "PlayerController3D"]:
		if inventory_source.contains(forbidden):
			_errors.append("InventoryModel should stay independent from equipment/UI/combat/player: %s." % forbidden)

	var equipment_source := FileAccess.get_file_as_string("res://scripts/equipment/equipment_model.gd")
	for forbidden in ["Control", "InventoryEquipmentUI", "PlayerController3D", "WeaponController3D", "UIManager"]:
		if equipment_source.contains(forbidden):
			_errors.append("EquipmentModel should stay data-only and independent from %s." % forbidden)


func _spawn_inventory_context() -> Dictionary:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var player := scene.get_node_or_null("Player3D")
	var inventory_ui := scene.find_child("InventoryEquipmentUI", true, false) as Control
	if player == null:
		_errors.append("Gameplay scene should include Player3D for inventory equipment flow.")
		_free_node(scene)
		return {}
	if inventory_ui == null:
		_errors.append("Gameplay scene should include InventoryEquipmentUI for visible equipment flow.")
		_free_node(scene)
		return {}
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	var equipment_model: RefCounted = player.call("get_equipment_model")
	backpack_model.clear()
	backpack_model.setup(50)
	equipment_model.clear()
	await process_frame
	return {
		"scene": scene,
		"player": player,
		"inventory_ui": inventory_ui,
	}


func _state_has_catalog(items: Variant, catalog_number: int) -> bool:
	if typeof(items) != TYPE_ARRAY:
		return false
	for item in items:
		if typeof(item) == TYPE_DICTIONARY and int((item as Dictionary).get("catalog_number", 0)) == catalog_number:
			return true
	return false


func _equipment_slots_are_empty(equipment_model: RefCounted) -> bool:
	var slots: Dictionary = equipment_model.call("get_slots")
	for stack in slots.values():
		if typeof(stack) == TYPE_DICTIONARY and not (stack as Dictionary).is_empty():
			return false
	return true


func _item_name(item_def: ItemDef) -> String:
	var key := str(item_def.name_key)
	var translated := tr(key)
	return translated if translated != key else item_def.display_name


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
