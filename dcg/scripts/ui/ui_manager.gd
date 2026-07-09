extends Node

signal active_ui_changed(id: StringName)

const UITextScript := preload("res://scripts/ui/ui_text.gd")
const SceneBinderScript := preload("res://scripts/ui/ui_manager_scene_binder.gd")
const QuestActionsScript := preload("res://scripts/ui/ui_manager_quest_actions.gd")
const ContainerTransferScript := preload("res://scripts/ui/ui_manager_container_transfer.gd")

const UI_NONE := &""
const UI_BACKPACK := &"backpack"
const UI_QUESTS := &"quests"
const UI_STATUS := &"status"
const UI_MAP := &"map"
const UI_CODEX := &"codex"
const UI_CONTAINER := &"container"
const UI_STASH := &"stash"
const UI_PAUSE := &"pause"
const MAX_PENDING_SCENE_UI_ATTEMPTS := 120
const TOP_MENU_IDS: Array[StringName] = [UI_BACKPACK, UI_QUESTS, UI_STATUS, UI_MAP, UI_CODEX]

var active_ui: StringName = UI_NONE

var _top_menu_bar: Control = null
var _inventory_ui: Control = null
var _quest_ui: Control = null
var _status_ui: Control = null
var _map_ui: Control = null
var _codex_ui: Control = null
var _container_inventory_ui: Control = null
var _stash_ui: Control = null
var _pause_menu: Control = null
var _last_scene: Node = null
var _active_container: Node = null
var _pending_stash_player: Node = null
var _pending_stash_save_manager: Node = null
var _pending_scene_ui: StringName = UI_NONE
var _pending_scene_ui_attempts := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	_bind_ui_nodes.call_deferred()
	if get_tree() != null and not get_tree().tree_changed.is_connected(_on_tree_changed):
		get_tree().tree_changed.connect(_on_tree_changed)


func _process(_delta: float) -> void:
	if _pending_scene_ui != UI_NONE:
		_open_pending_scene_ui(true)


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
	if not TOP_MENU_IDS.has(id) and id != UI_PAUSE and id != UI_STASH:
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
	if TOP_MENU_IDS.has(active_ui) or active_ui == UI_STASH:
		close_active_ui()
	elif _should_tab_open_base_stash():
		open_stash_inventory(_get_current_player_node(), _get_save_manager())
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


func open_stash_inventory(source_player: Node = null, source_save_manager: Node = null) -> bool:
	_bind_ui_nodes()
	if _stash_ui == null:
		return false
	_pending_stash_player = source_player
	_pending_stash_save_manager = source_save_manager
	_set_active_ui(UI_STASH)
	return active_ui == UI_STASH


func open_ui_on_next_scene(id: StringName) -> bool:
	if not TOP_MENU_IDS.has(id) and id != UI_PAUSE and id != UI_STASH:
		return false
	_pending_scene_ui = id
	_pending_scene_ui_attempts = 0
	set_process(true)
	_schedule_pending_scene_ui_open()
	return true


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
	var previous_ui := active_ui
	active_ui = id
	if previous_ui == UI_STASH and active_ui != UI_STASH:
		_set_stash_open(false, active_ui == UI_BACKPACK)
	_set_inventory_open(active_ui == UI_BACKPACK)
	_set_quest_open(active_ui == UI_QUESTS)
	_set_status_open(active_ui == UI_STATUS)
	_set_map_open(active_ui == UI_MAP)
	_set_codex_open(active_ui == UI_CODEX)
	_set_container_inventory_open(active_ui == UI_CONTAINER)
	if previous_ui != UI_STASH:
		_set_stash_open(active_ui == UI_STASH)
	elif active_ui == UI_STASH:
		_set_stash_open(true)
	_set_pause_open(active_ui == UI_PAUSE)
	_update_top_menu_state()
	_update_focus_and_mouse()
	active_ui_changed.emit(active_ui)


func _bind_ui_nodes() -> void:
	SceneBinderScript.bind(self)


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


func _on_quest_action_requested(quest_id: String, action_mode: String) -> void:
	var result := _execute_quest_action(quest_id, action_mode)
	if _quest_ui != null:
		if _quest_ui.has_method("notify_quest_action_result"):
			_quest_ui.call("notify_quest_action_result", result)
		elif _quest_ui.has_method("refresh"):
			_quest_ui.call("refresh")


func _execute_quest_action(quest_id: String, action_mode: String) -> Dictionary:
	return QuestActionsScript.execute(self, quest_id, action_mode)

func _set_status_open(should_open: bool) -> void:
	if _status_ui == null:
		return
	if should_open and _status_ui.has_method("open_status"):
		_status_ui.call("open_status")
	elif not should_open and _status_ui.has_method("close_status"):
		_status_ui.call("close_status")


func _set_map_open(should_open: bool) -> void:
	if _map_ui == null:
		return
	if should_open and _map_ui.has_method("open_map"):
		_map_ui.call("open_map")
	elif not should_open and _map_ui.has_method("close_map"):
		_map_ui.call("close_map")


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
		var display_name := _text(&"ui.container.default_name", "物資箱")
		if _active_container.has_method("get_container_display_name"):
			display_name = str(_active_container.call("get_container_display_name"))
		if _container_inventory_ui.has_method("open_container"):
			_container_inventory_ui.call("open_container", model, display_name)
	elif _container_inventory_ui.has_method("close_panel"):
		_container_inventory_ui.call("close_panel")
		_active_container = null


func _set_stash_open(should_open: bool, preserve_inventory_reference: bool = false) -> void:
	if _stash_ui == null:
		return
	if should_open:
		if _stash_ui.has_method("open_stash"):
			_stash_ui.call("open_stash", _pending_stash_player, _pending_stash_save_manager)
		_pending_stash_player = null
		_pending_stash_save_manager = null
	elif _stash_ui.has_method("close_stash"):
		_stash_ui.call("close_stash", not preserve_inventory_reference, false)
		_pending_stash_player = null
		_pending_stash_save_manager = null


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
	_top_menu_bar.visible = TOP_MENU_IDS.has(active_ui) or active_ui == UI_STASH
	if _top_menu_bar.has_method("select_item"):
		_top_menu_bar.select_item(UI_BACKPACK if active_ui == UI_STASH else active_ui)
	elif _top_menu_bar.has_method("select_index"):
		var selected_ui := UI_BACKPACK if active_ui == UI_STASH else active_ui
		_top_menu_bar.select_index(TOP_MENU_IDS.find(selected_ui))
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
	var panel := _panel_for_ui(active_ui)
	return panel if panel != null else _top_menu_bar


func _request_selected_top_menu_item() -> void:
	if _top_menu_bar == null:
		return
	if _top_menu_bar.has_method("get_selected_item_id"):
		open_ui(_top_menu_bar.get_selected_item_id())


func _can_open_ui(id: StringName) -> bool:
	if _top_menu_bar == null:
		return false
	return _panel_for_ui(id) != null or TOP_MENU_IDS.has(id)


func _has_panel_for_ui(id: StringName) -> bool:
	return id == UI_BACKPACK or id == UI_QUESTS or id == UI_STATUS or id == UI_MAP or id == UI_CODEX or id == UI_CONTAINER or id == UI_PAUSE


func _panel_for_ui(id: StringName) -> Control:
	match id:
		UI_BACKPACK:
			return _inventory_ui
		UI_QUESTS:
			return _quest_ui
		UI_STATUS:
			return _status_ui
		UI_MAP:
			return _map_ui
		UI_CODEX:
			return _codex_ui
		UI_CONTAINER:
			return _container_inventory_ui
		UI_STASH:
			return _stash_ui
		UI_PAUSE:
			return _pause_menu
	return null


func _handle_input_as_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _on_tree_changed() -> void:
	_bind_ui_nodes.call_deferred()
	_schedule_pending_scene_ui_open()


func _schedule_pending_scene_ui_open() -> void:
	if _pending_scene_ui == UI_NONE:
		return
	_open_pending_scene_ui.call_deferred()


func _open_pending_scene_ui(count_attempt: bool = false) -> void:
	if _pending_scene_ui == UI_NONE:
		set_process(false)
		return
	_bind_ui_nodes()
	if _can_open_ui(_pending_scene_ui):
		var ui_to_open := _pending_scene_ui
		_pending_scene_ui = UI_NONE
		_pending_scene_ui_attempts = 0
		set_process(false)
		open_ui(ui_to_open)
		return
	if count_attempt:
		_pending_scene_ui_attempts += 1
		if _pending_scene_ui_attempts >= MAX_PENDING_SCENE_UI_ATTEMPTS:
			_pending_scene_ui = UI_NONE
			_pending_scene_ui_attempts = 0
			set_process(false)
			return


func _on_container_inventory_close_requested() -> void:
	if active_ui == UI_CONTAINER:
		close_active_ui()


func _on_container_slot_pressed(slot_index: int, stack: Dictionary) -> void:
	ContainerTransferScript.transfer_slot(self, slot_index, stack)

func _get_save_manager() -> Node:
	if is_inside_tree():
		var manager := get_node_or_null("/root/SaveGameManager")
		if manager != null:
			return manager
	var tree := get_tree()
	if tree != null:
		return tree.root.get_node_or_null("SaveGameManager")
	return null


func _set_container_status(message: String) -> void:
	if _container_inventory_ui != null and _container_inventory_ui.has_method("set_status_message"):
		_container_inventory_ui.call("set_status_message", message)


func _should_tab_open_base_stash() -> bool:
	_bind_ui_nodes()
	return _stash_ui != null and _is_base_scene_context()


func _is_base_scene_context() -> bool:
	var scene := _current_scene_node()
	if scene == null:
		return false
	if scene.scene_file_path == "res://scenes/base/base_3d.tscn":
		return true
	return scene.find_child("BaseInteractionController3D", true, false) != null


func _get_current_player_node() -> Node:
	var scene := _current_scene_node()
	if scene == null:
		return null
	return scene.find_child("Player3D", true, false)


func _current_scene_node() -> Node:
	if is_inside_tree() and get_tree() != null:
		if get_tree().current_scene != null:
			return get_tree().current_scene
		return get_tree().root
	return null


func _text(key: StringName, fallback: String) -> String:
	return UITextScript.text(self, key, fallback)
