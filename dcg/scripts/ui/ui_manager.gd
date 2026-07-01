extends Node

signal active_ui_changed(id: StringName)

const UI_NONE := &""
const UI_BACKPACK := &"backpack"
const UI_QUESTS := &"quests"
const UI_STATUS := &"status"
const UI_MAP := &"map"
const UI_CODEX := &"codex"
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
var _codex_ui: Control = null
var _pause_menu: Control = null
var _last_scene: Node = null


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
	_set_codex_open(active_ui == UI_CODEX)
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

	if _codex_ui == null or not is_instance_valid(_codex_ui):
		_codex_ui = _find_control("ItemCodexUI")

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


func _set_codex_open(should_open: bool) -> void:
	if _codex_ui == null:
		return
	if should_open and _codex_ui.has_method("open_codex"):
		_codex_ui.open_codex()
	elif not should_open and _codex_ui.has_method("close_codex"):
		_codex_ui.close_codex()


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
		UI_CODEX:
			return _codex_ui
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
	if id == UI_CODEX:
		return _codex_ui != null
	if id == UI_PAUSE:
		return _pause_menu != null
	return TOP_MENU_IDS.has(id)


func _has_panel_for_ui(id: StringName) -> bool:
	return id == UI_BACKPACK or id == UI_CODEX or id == UI_PAUSE


func _refresh_scene_cache() -> void:
	var current: Node = null
	if is_inside_tree() and get_tree() != null:
		current = get_tree().current_scene
	if current == _last_scene:
		return
	_last_scene = current
	_top_menu_bar = null
	_inventory_ui = null
	_codex_ui = null
	_pause_menu = null


func _handle_input_as_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _on_tree_changed() -> void:
	_bind_ui_nodes.call_deferred()


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
