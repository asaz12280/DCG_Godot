extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const Base3DScene := preload("res://scenes/base/base_3d.tscn")
const MapTopMenuScene := preload("res://scenes/ui/map_top_menu_panel.tscn")

const MAP_PANEL_SOURCE := "res://scripts/ui/map_top_menu_panel.gd"
const MAP_PANEL_SCENE := "res://scenes/ui/map_top_menu_panel.tscn"

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	await _validate_gameplay_map_panel()
	await _validate_base_map_panel()
	await _validate_layout_fit()
	_validate_node_first_structure()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[top_menu_map_panel] OK title=visible body=removed layout=fit boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_gameplay_map_panel() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	current_scene = scene
	await _wait_frames(3)

	var ui_manager := root.get_node_or_null("UIManager")
	var top_menu := scene.get_node_or_null("HUD/TopMenuBar")
	var panel := scene.get_node_or_null("HUD/MapTopMenuPanel")
	if ui_manager == null or top_menu == null or panel == null:
		_errors.append("Gameplay scene should include UIManager, TopMenuBar, and MapTopMenuPanel.")
		_free_current_scene()
		return

	ui_manager.call("open_ui", &"map")
	await _wait_frames(3)
	var state: Dictionary = panel.call("get_display_state")
	if not bool(state.get("visible", false)):
		_errors.append("Map tab should open MapTopMenuPanel.")
	if str(ui_manager.call("get_active_ui")) != "map":
		_errors.append("UIManager should own active map UI state.")
	if str(top_menu.call("get_selected_item_id")) != "map":
		_errors.append("TopMenuBar should select the map icon when map panel opens.")
	_validate_gameplay_text(state)

	_free_current_scene()


func _validate_base_map_panel() -> void:
	var scene := Base3DScene.instantiate()
	root.add_child(scene)
	current_scene = scene
	await _wait_frames(3)

	var ui_manager := root.get_node_or_null("UIManager")
	var panel := scene.get_node_or_null("HUD/MapTopMenuPanel")
	if ui_manager == null or panel == null:
		_errors.append("Base scene should include UIManager and MapTopMenuPanel.")
		_free_current_scene()
		return

	ui_manager.call("open_ui", &"map")
	await _wait_frames(3)
	var state: Dictionary = panel.call("get_display_state")
	if not bool(state.get("visible", false)):
		_errors.append("Base map tab should open MapTopMenuPanel.")
	_validate_body_removed(state)

	_free_current_scene()


func _validate_gameplay_text(state: Dictionary) -> void:
	if str(state.get("title", "")).strip_edges() == "":
		_errors.append("Map panel should keep its title while body copy is removed.")
	_validate_body_removed(state)
	for token in ["Area Map", "Current area", "Extraction direction", "Danger zone", "Loot zone", "In raid"]:
		if _state_text(state).contains(token):
			_errors.append("Map panel should not show English fallback text: %s." % token)


func _validate_layout_fit() -> void:
	var panel := MapTopMenuScene.instantiate()
	root.add_child(panel)
	await _wait_frames(2)
	panel.call("open_map")
	await _wait_frames(2)

	for viewport_size in [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0)]:
		var rect: Rect2 = panel.call("preview_layout", viewport_size)
		if rect.position.y < 70.0:
			_errors.append("Map top-menu panel should sit below the icon bar at %s." % viewport_size)
		if rect.position.x < 0.0 or rect.position.y < 0.0:
			_errors.append("Map top-menu panel escapes viewport at %s." % viewport_size)
		if rect.end.x > viewport_size.x or rect.end.y > viewport_size.y:
			_errors.append("Map top-menu panel should fit inside viewport at %s." % viewport_size)
		if rect.size.x > viewport_size.x * 0.84:
			_errors.append("Map panel should not cover too much horizontal gameplay view at %s." % viewport_size)
		if rect.size.y > viewport_size.y * 0.72:
			_errors.append("Map panel should not cover too much vertical gameplay view at %s." % viewport_size)
		var state: Dictionary = panel.call("get_display_state_for_viewport", viewport_size)
		_validate_gameplay_text(state)

	_free_node(panel)


func _validate_node_first_structure() -> void:
	var panel_scene := FileAccess.get_file_as_string(MAP_PANEL_SCENE)
	for node_name in ["RouteLabel", "DangerLabel", "LootLabel", "ExtractionLabel", "AreaLabel", "FlowStateLabel"]:
		if not panel_scene.contains(node_name):
			_errors.append("Map panel scene should provide node-first label: %s." % node_name)
	for node_type in ["PanelContainer", "MarginContainer", "VBoxContainer", "Label"]:
		if not panel_scene.contains(node_type):
			_errors.append("Map panel scene should use Godot Control node type: %s." % node_type)


func _validate_source_boundaries() -> void:
	var source := FileAccess.get_file_as_string(MAP_PANEL_SOURCE)
	for required in ["RaidSession", "ExtractionZone", "Player3D", "Scavenger", "LootContainer", "get_state"]:
		if not source.contains(required):
			_errors.append("MapTopMenuPanel should read visible map state through %s." % required)
	for forbidden in ["register_extraction", "register_player_death", "change_scene", "save_slot_data", "equip_inventory_stack", "reload_equipped_weapon", "add_item_resource"]:
		if source.contains(forbidden):
			_errors.append("MapTopMenuPanel should stay display-only and not mutate gameplay state: %s." % forbidden)


func _state_text(state: Dictionary) -> String:
	return "%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s" % [
		state.get("title", ""),
		state.get("hint", ""),
		state.get("area", ""),
		state.get("route", ""),
		state.get("extraction", ""),
		state.get("danger", ""),
		state.get("loot", ""),
		state.get("flow_state", ""),
	]


func _validate_body_removed(state: Dictionary) -> void:
	for key in ["area", "route", "extraction", "danger", "loot", "flow_state", "note"]:
		if str(state.get(key, "")).strip_edges() != "":
			_errors.append("Map panel body field `%s` should be empty." % key)
	if bool(state.get("body_visible", true)):
		_errors.append("Map panel body container should be hidden.")


func _require_terms(text: String, terms: Array[String], message: String) -> void:
	for term in terms:
		if not text.contains(term):
			_errors.append("%s Missing `%s` in `%s`." % [message, term, text])


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _free_current_scene() -> void:
	var scene := current_scene
	current_scene = null
	_free_node(scene)


func _free_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.queue_free()
