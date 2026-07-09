class_name UIManagerSceneBinder
extends RefCounted


static func bind(manager) -> void:
	_refresh_scene_cache(manager)
	if manager._top_menu_bar == null or not is_instance_valid(manager._top_menu_bar):
		manager._top_menu_bar = _find_control(manager, "TopMenuBar")
		if manager._top_menu_bar != null and manager._top_menu_bar.has_signal("menu_item_requested"):
			_connect_once(manager._top_menu_bar, "menu_item_requested", Callable(manager, "_on_top_menu_item_requested"))
	manager._inventory_ui = _valid_or_find(manager, manager._inventory_ui, "InventoryEquipmentUI")
	if manager._quest_ui == null or not is_instance_valid(manager._quest_ui):
		manager._quest_ui = _find_control(manager, "QuestTopMenuPanel")
		if manager._quest_ui != null and manager._quest_ui.has_signal("quest_action_requested"):
			_connect_once(manager._quest_ui, "quest_action_requested", Callable(manager, "_on_quest_action_requested"))
	manager._status_ui = _valid_or_find(manager, manager._status_ui, "StatusTopMenuPanel")
	manager._map_ui = _valid_or_find(manager, manager._map_ui, "MapTopMenuPanel")
	manager._codex_ui = _valid_or_find(manager, manager._codex_ui, "ItemCodexUI")
	if manager._container_inventory_ui == null or not is_instance_valid(manager._container_inventory_ui):
		manager._container_inventory_ui = _find_control(manager, "ContainerInventoryUI")
		if manager._container_inventory_ui != null and manager._container_inventory_ui.has_signal("close_requested"):
			_connect_once(manager._container_inventory_ui, "close_requested", Callable(manager, "_on_container_inventory_close_requested"))
		if manager._container_inventory_ui != null and manager._container_inventory_ui.has_signal("slot_pressed"):
			_connect_once(manager._container_inventory_ui, "slot_pressed", Callable(manager, "_on_container_slot_pressed"))
	manager._pause_menu = _valid_or_find(manager, manager._pause_menu, "PauseMenu")
	manager._stash_ui = _valid_or_find(manager, manager._stash_ui, "BaseStashInventoryUI")


static func _valid_or_find(manager, current, node_name: String) -> Control:
	if current != null and is_instance_valid(current):
		return current
	return _find_control(manager, node_name)


static func _connect_once(target: Object, signal_name: StringName, callback: Callable) -> void:
	if not target.is_connected(signal_name, callback):
		target.connect(signal_name, callback)


static func _refresh_scene_cache(manager) -> void:
	var current: Node = null
	if manager.is_inside_tree() and manager.get_tree() != null:
		current = manager.get_tree().current_scene
	if current == manager._last_scene:
		return
	manager._last_scene = current
	manager._top_menu_bar = null
	manager._inventory_ui = null
	manager._quest_ui = null
	manager._status_ui = null
	manager._map_ui = null
	manager._codex_ui = null
	manager._container_inventory_ui = null
	manager._stash_ui = null
	manager._pause_menu = null


static func _find_control(manager, node_name: String) -> Control:
	var search_root: Node = null
	if manager.is_inside_tree() and manager.get_tree() != null:
		search_root = manager.get_tree().current_scene
		if search_root == null:
			search_root = manager.get_tree().root
	if search_root == null:
		search_root = manager.get_parent()
	if search_root == null:
		return null
	var node := search_root.find_child(node_name, true, false)
	return node as Control
