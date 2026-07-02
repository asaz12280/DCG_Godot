extends Node

signal active_ui_changed(id: StringName)

const UI_NONE := &""
const UI_BACKPACK := &"backpack"
const UI_QUESTS := &"quests"
const UI_STATUS := &"status"
const UI_MAP := &"map"
const UI_CODEX := &"codex"
const UI_CONTAINER := &"container"
const UI_PAUSE := &"pause"
const TOP_MENU_IDS: Array[StringName] = [
	UI_BACKPACK,
	UI_QUESTS,
	UI_STATUS,
	UI_MAP,
	UI_CODEX,
]

var active_ui: StringName = UI_NONE

var _top_menu_bar: Control = null
var _inventory_ui: Control = null
var _quest_ui: Control = null
var _status_ui: Control = null
var _codex_ui: Control = null
var _container_inventory_ui: Control = null
var _pause_menu: Control = null
var _last_scene: Node = null
var _active_container: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind_ui_nodes.call_deferred()
	if get_tree() != null and not get_tree().tree_changed.is_connected(_on_tree_changed):
		get_tree().tree_changed.connect(_on_tree_changed)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				toggle_top_menu()
				_handle_input_as_handled()
			KEY_ESCAPE:
				if active_ui != UI_NONE:
					close_active_ui()
				else:
					open_ui(UI_PAUSE)
				_handle_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if _top_menu_bar != null and _top_menu_bar.visible:
					_request_selected_top_menu_item()
					_handle_input_as_handled()


func open_ui(id: StringName) -> void:
	_bind_ui_nodes()
	if not TOP_MENU_IDS.has(id) and id != UI_PAUSE:
		close_active_ui()
		return
	if not _can_open_ui(id):
		return
	_set_active_ui(id)


func toggle_ui(id: StringName) -> void:
	if active_ui == id:
		close_active_ui()
	else:
		open_ui(id)


func toggle_top_menu() -> void:
	if TOP_MENU_IDS.has(active_ui):
		close_active_ui()
	else:
		open_ui(UI_BACKPACK)


func close_active_ui() -> void:
	_set_active_ui(UI_NONE)


func close_all() -> void:
	close_active_ui()


func open_container_inventory(container: Node) -> void:
	_bind_ui_nodes()
	if container == null or _container_inventory_ui == null:
		return
	if not container.has_method("get_container_inventory_model"):
		return
	_active_container = container
	_set_active_ui(UI_CONTAINER)


func get_active_ui() -> StringName:
	return active_ui


func is_ui_open(id: StringName = UI_NONE) -> bool:
	if id == UI_NONE:
		return active_ui != UI_NONE
	return active_ui == id


func is_top_menu_open() -> bool:
	return TOP_MENU_IDS.has(active_ui)


func is_gameplay_movement_blocked() -> bool:
	return active_ui == UI_PAUSE


func is_gameplay_action_blocked() -> bool:
	return active_ui != UI_NONE


func _set_active_ui(id: StringName) -> void:
	_bind_ui_nodes()
	active_ui = id
	_set_inventory_open(active_ui == UI_BACKPACK)
	_set_quest_open(active_ui == UI_QUESTS)
	_set_status_open(active_ui == UI_STATUS)
	_set_codex_open(active_ui == UI_CODEX)
	_set_container_inventory_open(active_ui == UI_CONTAINER)
	_set_pause_open(active_ui == UI_PAUSE)
	_update_top_menu_state()
	_update_focus_and_mouse()
	active_ui_changed.emit(active_ui)


func _bind_ui_nodes() -> void:
	_refresh_scene_cache()
	if _top_menu_bar == null or not is_instance_valid(_top_menu_bar):
		_top_menu_bar = _find_control("TopMenuBar")
		if _top_menu_bar != null and _top_menu_bar.has_signal("menu_item_requested"):
			var callback := Callable(self, "_on_top_menu_item_requested")
			if not _top_menu_bar.is_connected("menu_item_requested", callback):
				_top_menu_bar.connect("menu_item_requested", callback)

	if _inventory_ui == null or not is_instance_valid(_inventory_ui):
		_inventory_ui = _find_control("InventoryEquipmentUI")

	if _quest_ui == null or not is_instance_valid(_quest_ui):
		_quest_ui = _find_control("QuestTopMenuPanel")

	if _status_ui == null or not is_instance_valid(_status_ui):
		_status_ui = _find_control("StatusTopMenuPanel")

	if _codex_ui == null or not is_instance_valid(_codex_ui):
		_codex_ui = _find_control("ItemCodexUI")

	if _container_inventory_ui == null or not is_instance_valid(_container_inventory_ui):
		_container_inventory_ui = _find_control("ContainerInventoryUI")
		if _container_inventory_ui != null and _container_inventory_ui.has_signal("close_requested"):
			var close_callback := Callable(self, "_on_container_inventory_close_requested")
			if not _container_inventory_ui.is_connected("close_requested", close_callback):
				_container_inventory_ui.connect("close_requested", close_callback)
		if _container_inventory_ui != null and _container_inventory_ui.has_signal("slot_pressed"):
			var slot_callback := Callable(self, "_on_container_slot_pressed")
			if not _container_inventory_ui.is_connected("slot_pressed", slot_callback):
				_container_inventory_ui.connect("slot_pressed", slot_callback)

	if _pause_menu == null or not is_instance_valid(_pause_menu):
		_pause_menu = _find_control("PauseMenu")


func _on_top_menu_item_requested(id: StringName) -> void:
	if id == active_ui and _has_panel_for_ui(id):
		close_active_ui()
	else:
		open_ui(id)


func _set_inventory_open(should_open: bool) -> void:
	if _inventory_ui == null:
		return
	if should_open and _inventory_ui.has_method("open_inventory"):
		_inventory_ui.open_inventory()
	elif not should_open and _inventory_ui.has_method("close_inventory"):
		_inventory_ui.close_inventory()


func _set_quest_open(should_open: bool) -> void:
	if _quest_ui == null:
		return
	if should_open and _quest_ui.has_method("open_quests"):
		_quest_ui.call("open_quests")
	elif not should_open and _quest_ui.has_method("close_quests"):
		_quest_ui.call("close_quests")


func _set_status_open(should_open: bool) -> void:
	if _status_ui == null:
		return
	if should_open and _status_ui.has_method("open_status"):
		_status_ui.call("open_status")
	elif not should_open and _status_ui.has_method("close_status"):
		_status_ui.call("close_status")


func _set_codex_open(should_open: bool) -> void:
	if _codex_ui == null:
		return
	if should_open and _codex_ui.has_method("open_codex"):
		_codex_ui.open_codex()
	elif not should_open and _codex_ui.has_method("close_codex"):
		_codex_ui.close_codex()


func _set_container_inventory_open(should_open: bool) -> void:
	if _container_inventory_ui == null:
		return
	if should_open:
		if _active_container == null or not is_instance_valid(_active_container):
			return
		var model: RefCounted = _active_container.call("get_container_inventory_model")
		var display_name := "物資箱"
		if _active_container.has_method("get_container_display_name"):
			display_name = str(_active_container.call("get_container_display_name"))
		if _container_inventory_ui.has_method("open_container"):
			_container_inventory_ui.call("open_container", model, display_name)
	elif _container_inventory_ui.has_method("close_panel"):
		_container_inventory_ui.call("close_panel")
		_active_container = null


func _set_pause_open(should_open: bool) -> void:
	if _pause_menu == null:
		return
	if should_open and _pause_menu.has_method("open_pause"):
		_pause_menu.open_pause()
	elif not should_open and _pause_menu.has_method("close_pause"):
		_pause_menu.close_pause()


func _update_top_menu_state() -> void:
	if _top_menu_bar == null:
		return
	_top_menu_bar.visible = TOP_MENU_IDS.has(active_ui)
	if _top_menu_bar.has_method("select_item"):
		_top_menu_bar.select_item(active_ui)
	elif _top_menu_bar.has_method("select_index"):
		_top_menu_bar.select_index(TOP_MENU_IDS.find(active_ui))
	if _top_menu_bar.visible and _top_menu_bar.get_parent() != null:
		_top_menu_bar.get_parent().move_child(_top_menu_bar, _top_menu_bar.get_parent().get_child_count() - 1)


func _update_focus_and_mouse() -> void:
	var has_active_ui := active_ui != UI_NONE
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if has_active_ui else Input.MOUSE_MODE_HIDDEN
	if has_active_ui:
		var focus_target := _get_active_focus_target()
		if focus_target != null and focus_target.is_inside_tree():
			focus_target.focus_mode = Control.FOCUS_ALL
			focus_target.grab_focus()
	else:
		var viewport := get_viewport()
		if viewport != null:
			viewport.gui_release_focus()


func _get_active_focus_target() -> Control:
	match active_ui:
		UI_BACKPACK:
			return _inventory_ui
		UI_QUESTS:
			return _quest_ui
		UI_STATUS:
			return _status_ui
		UI_CODEX:
			return _codex_ui
		UI_CONTAINER:
			return _container_inventory_ui
		UI_PAUSE:
			return _pause_menu
		_:
			return _top_menu_bar


func _request_selected_top_menu_item() -> void:
	if _top_menu_bar == null:
		return
	if _top_menu_bar.has_method("get_selected_item_id"):
		open_ui(_top_menu_bar.get_selected_item_id())


func _can_open_ui(id: StringName) -> bool:
	if _top_menu_bar == null:
		return false
	if id == UI_BACKPACK:
		return _inventory_ui != null
	if id == UI_QUESTS:
		return _quest_ui != null
	if id == UI_STATUS:
		return _status_ui != null
	if id == UI_CODEX:
		return _codex_ui != null
	if id == UI_PAUSE:
		return _pause_menu != null
	if id == UI_CONTAINER:
		return _container_inventory_ui != null
	return TOP_MENU_IDS.has(id)


func _has_panel_for_ui(id: StringName) -> bool:
	return id == UI_BACKPACK or id == UI_QUESTS or id == UI_STATUS or id == UI_CODEX or id == UI_CONTAINER or id == UI_PAUSE


func _refresh_scene_cache() -> void:
	var current: Node = null
	if is_inside_tree() and get_tree() != null:
		current = get_tree().current_scene
	if current == _last_scene:
		return
	_last_scene = current
	_top_menu_bar = null
	_inventory_ui = null
	_quest_ui = null
	_status_ui = null
	_codex_ui = null
	_container_inventory_ui = null
	_pause_menu = null


func _handle_input_as_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _on_tree_changed() -> void:
	_bind_ui_nodes.call_deferred()


func _on_container_inventory_close_requested() -> void:
	if active_ui == UI_CONTAINER:
		close_active_ui()


func _on_container_slot_pressed(slot_index: int, stack: Dictionary) -> void:
	if active_ui != UI_CONTAINER:
		return
	if _active_container == null or not is_instance_valid(_active_container):
		return
	if stack.is_empty():
		_set_container_status("這個格子是空的。")
		return
	if not _active_container.has_method("get_container_inventory_model"):
		_set_container_status("目前無法轉移物品。")
		return

	var container_model: RefCounted = _active_container.call("get_container_inventory_model")
	var backpack_model := _get_player_inventory_model()
	if container_model == null or backpack_model == null:
		_set_container_status("目前無法轉移物品。")
		return
	if not _can_backpack_accept_stack(backpack_model, stack):
		_set_container_status("背包已滿，無法放入。")
		return

	var moved_quantity := int(stack.get("quantity", 1))
	var removed_stack: Dictionary = container_model.call("remove_from_slot", slot_index, moved_quantity)
	if removed_stack.is_empty():
		_set_container_status("這個格子是空的。")
		return
	if not _add_stack_to_backpack(backpack_model, removed_stack):
		container_model.call("add_stack", removed_stack)
		_set_container_status("背包已滿，無法放入。")
		return
	_set_container_status("已移入背包。")


func _get_player_inventory_model() -> RefCounted:
	var search_root: Node = null
	if is_inside_tree() and get_tree() != null:
		search_root = get_tree().current_scene
		if search_root == null:
			search_root = get_tree().root
	if search_root == null:
		return null
	var player := search_root.find_child("Player3D", true, false)
	if player == null or not player.has_method("get_inventory_model"):
		return null
	return player.call("get_inventory_model") as RefCounted


func _can_backpack_accept_stack(backpack_model: RefCounted, stack: Dictionary) -> bool:
	var remaining := int(stack.get("quantity", 1))
	if remaining <= 0:
		return false
	var item_path := str(stack.get("resource_path", stack.get("item_path", "")))
	var max_stack := maxi(int(stack.get("max_stack", 1)), 1)
	var existing_stacks: Array = backpack_model.call("get_display_items")
	for existing in existing_stacks:
		if typeof(existing) != TYPE_DICTIONARY:
			continue
		var existing_stack := existing as Dictionary
		if str(existing_stack.get("resource_path", "")) != item_path:
			continue
		if max_stack <= 1:
			continue
		var room := max_stack - int(existing_stack.get("quantity", 1))
		if room <= 0:
			continue
		remaining -= mini(room, remaining)
		if remaining <= 0:
			return true

	var slot_limit := int(backpack_model.get("slot_limit"))
	var free_slots := maxi(slot_limit - existing_stacks.size(), 0)
	while remaining > 0 and free_slots > 0:
		remaining -= mini(max_stack, remaining)
		free_slots -= 1
	return remaining <= 0


func _add_stack_to_backpack(backpack_model: RefCounted, stack: Dictionary) -> bool:
	var item_path := str(stack.get("resource_path", stack.get("item_path", "")))
	if item_path == "" or not ResourceLoader.exists(item_path):
		return backpack_model.call("add_stack", stack)
	var item_def := load(item_path) as ItemDef
	if item_def == null:
		return backpack_model.call("add_stack", stack)
	return bool(backpack_model.call("add_item", item_def, int(stack.get("quantity", 1))))


func _set_container_status(message: String) -> void:
	if _container_inventory_ui != null and _container_inventory_ui.has_method("set_status_message"):
		_container_inventory_ui.call("set_status_message", message)


func _find_control(node_name: String) -> Control:
	var search_root: Node = null
	if is_inside_tree() and get_tree() != null:
		search_root = get_tree().current_scene
		if search_root == null:
			search_root = get_tree().root
	if search_root == null:
		search_root = get_parent()
	if search_root == null:
		return null
	var node := search_root.find_child(node_name, true, false)
	return node as Control
