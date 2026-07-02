extends SceneTree

const ContainerInventoryUIScene := preload("res://scenes/ui/container_inventory_ui.tscn")
const ContainerInventoryModelScript := preload("res://scripts/inventory/container_inventory_model.gd")
const UITextScript := preload("res://scripts/ui/ui_text.gd")
const Wood := preload("res://data/items/crafting/wood.tres")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	await _validate_ui_content_and_layout()
	_validate_scene_is_node_first()
	_validate_responsibility_boundary()
	if _errors.is_empty():
		print("[container_inventory_ui] OK panel=node_first capacity=visible slots=visible layout=fits text=zh")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_ui_content_and_layout() -> void:
	for viewport_size in [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0)]:
		root.size = Vector2i(int(viewport_size.x), int(viewport_size.y))
		var model := ContainerInventoryModelScript.new(4)
		model.add_item(Wood, 2)
		model.add_item(Pistol, 1)
		var panel := ContainerInventoryUIScene.instantiate()
		root.add_child(panel)
		panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		panel.size = viewport_size
		await process_frame
		panel.call("preview_layout", viewport_size)
		panel.call("open_container", model, "愛心箱")
		await process_frame

		var state: Dictionary = panel.call("get_display_state")
		var panel_rect := state.get("panel_rect") as Rect2
		var scroll_rect := state.get("scroll_rect") as Rect2
		if str(state.get("title", "")) != "愛心箱":
			_errors.append("ContainerInventoryUI should show the container name in Traditional Chinese.")
		if str(state.get("capacity", "")) != "2/4":
			_errors.append("ContainerInventoryUI should show used/capacity text like 2/4.")
		if not str(state.get("help", "")).contains("背包"):
			_errors.append("ContainerInventoryUI should explain that items can later transfer to backpack.")
		if int(state.get("slot_count", 0)) != 4:
			_errors.append("ContainerInventoryUI should create one visible slot per container capacity.")
		if panel_rect.position.x < 24.0 or panel_rect.position.y < 24.0:
			_errors.append("ContainerInventoryUI should keep safe margins at %s." % viewport_size)
		if panel_rect.end.x > viewport_size.x or panel_rect.end.y > viewport_size.y:
			_errors.append("ContainerInventoryUI should fit inside %s." % viewport_size)
		if not panel_rect.encloses(scroll_rect):
			_errors.append("ContainerInventoryUI slot grid should stay inside the main panel at %s." % viewport_size)
		_assert_clean_tree_text(panel, "ContainerInventoryUI")
		_free_node(panel)


func _validate_scene_is_node_first() -> void:
	var scene_text := FileAccess.get_file_as_string("res://scenes/ui/container_inventory_ui.tscn")
	for required_node in ["PanelContainer", "MarginContainer", "VBoxContainer", "GridContainer", "ScrollContainer", "Button"]:
		if not scene_text.contains("type=\"%s\"" % required_node):
			_errors.append("ContainerInventoryUI scene should use node-first %s layout." % required_node)


func _validate_responsibility_boundary() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/container_inventory_ui.gd")
	var forbidden_terms := PackedStringArray([
		"LootContainer3D",
		"WeaponController",
		"PlayerController",
		"SaveGameManager",
		"change_scene",
		"roll_loot",
	])
	for term in forbidden_terms:
		if source.contains(term):
			_errors.append("ContainerInventoryUI should not own %s responsibility." % term)


func _assert_clean_tree_text(node: Node, label: String) -> void:
	if node is Label:
		_assert_clean_text((node as Label).text, "%s/%s" % [label, node.name])
	elif node is Button:
		_assert_clean_text((node as Button).text, "%s/%s" % [label, node.name])
	for child in node.get_children():
		_assert_clean_tree_text(child, label)


func _assert_clean_text(text: String, label: String) -> void:
	if text == "":
		return
	if UITextScript.looks_corrupt(text):
		_errors.append("%s should not display mojibake: %s" % [label, text])
	if _looks_like_english_fallback(text):
		_errors.append("%s should not display English fallback: %s" % [label, text])


func _looks_like_english_fallback(text: String) -> bool:
	for token in ["Container", "Inventory", "Close", "Open", "Empty", "Backpack"]:
		if text.contains(token):
			return true
	return false


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
