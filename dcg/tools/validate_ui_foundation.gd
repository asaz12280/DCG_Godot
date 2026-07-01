extends SceneTree

# // Validates shared UI foundation resources that future UI screens should depend on. //
const EXPECTED_THEME_PATH := "res://data/ui/game_theme.tres"
const UILayoutHelper := preload("res://scripts/ui/ui_layout.gd")
const UIStyleHelper := preload("res://scripts/ui/ui_style.gd")
const UIManagerScript := preload("res://scripts/ui/ui_manager.gd")
const TopMenuBarScript := preload("res://scripts/ui/top_menu_bar.gd")
const InventoryEquipmentUIScript := preload("res://scripts/ui/inventory_equipment_ui.gd")
const ItemCodexGridModelScript := preload("res://scripts/ui/item_codex_grid_model.gd")
const ItemCodexUIScript := preload("res://scripts/ui/item_codex_ui.gd")
const ItemCodexSlotScript := preload("res://scripts/ui/components/item_codex_slot.gd")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_theme()
	_validate_style_tokens()
	_validate_ui_manager()
	_validate_layout_math()
	_validate_codex_grid_model()
	_validate_codex_node_grid()
	if _errors.is_empty():
		print("[ui_foundation] OK theme=loaded layout=centered grid=stable")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_theme() -> void:
	var theme_path := str(ProjectSettings.get_setting("gui/theme/custom", ""))
	if theme_path != EXPECTED_THEME_PATH:
		_errors.append("Project theme should be %s but is %s" % [EXPECTED_THEME_PATH, theme_path])
	var theme := load(EXPECTED_THEME_PATH) as Theme
	if theme == null:
		_errors.append("Cannot load game theme: %s" % EXPECTED_THEME_PATH)
		return
	if not theme.has_stylebox("normal", "Button"):
		_errors.append("Game theme missing Button normal style.")
	if not theme.has_stylebox("panel", "Panel"):
		_errors.append("Game theme missing Panel style.")


func _validate_style_tokens() -> void:
	if UIStyleHelper.FONT_BODY != 18:
		_errors.append("UIStyle FONT_BODY should match game_theme default body size.")
	if UIStyleHelper.SIZE_PANEL_BACK_BUTTON != Vector2(220.0, 48.0):
		_errors.append("UIStyle panel back button size changed unexpectedly.")
	var style := UIStyleHelper.make_overlay_panel_style()
	if style == null:
		_errors.append("UIStyle overlay panel style should be buildable.")
		return
	if style.corner_radius_top_left != UIStyleHelper.OVERLAY_CORNER_RADIUS:
		_errors.append("UIStyle overlay panel corner radius mismatch.")


func _validate_ui_manager() -> void:
	var manager := Node.new()
	manager.set_script(UIManagerScript)
	root.add_child(manager)
	if not manager.has_method("open_ui"):
		_errors.append("UIManager should expose open_ui.")
	if not manager.has_method("toggle_ui"):
		_errors.append("UIManager should expose toggle_ui.")
	if not manager.has_method("close_active_ui"):
		_errors.append("UIManager should expose close_active_ui.")
	manager.queue_free()

	var hud := CanvasLayer.new()
	root.add_child(hud)
	var top_menu := Control.new()
	top_menu.name = "TopMenuBar"
	top_menu.set_script(TopMenuBarScript)
	hud.add_child(top_menu)
	var inventory := Control.new()
	inventory.name = "InventoryEquipmentUI"
	inventory.set_script(InventoryEquipmentUIScript)
	hud.add_child(inventory)
	var codex := Control.new()
	codex.name = "ItemCodexUI"
	codex.set_script(ItemCodexUIScript)
	hud.add_child(codex)
	var state_manager := Node.new()
	state_manager.name = "UIManager"
	state_manager.set_script(UIManagerScript)
	hud.add_child(state_manager)

	state_manager.call("_bind_ui_nodes")
	state_manager.call("open_ui", &"backpack")
	if not bool(inventory.get("is_open")):
		_errors.append("UIManager should open inventory for backpack.")
	if bool(codex.get("is_open")):
		_errors.append("UIManager should keep codex closed while backpack is active.")
	if not top_menu.visible:
		_errors.append("UIManager should show top menu while a UI is active.")

	state_manager.call("open_ui", &"codex")
	if bool(inventory.get("is_open")):
		_errors.append("UIManager should close inventory when codex opens.")
	if not bool(codex.get("is_open")):
		_errors.append("UIManager should open codex.")

	state_manager.call("close_active_ui")
	if bool(inventory.get("is_open")) or bool(codex.get("is_open")):
		_errors.append("UIManager should close all managed panels.")
	if top_menu.visible:
		_errors.append("UIManager should hide top menu when no UI is active.")
	hud.queue_free()


func _validate_layout_math() -> void:
	var cases := [
		Vector2(1920.0, 1080.0),
		Vector2(2560.0, 1440.0),
		Vector2(1680.0, 1050.0),
		Vector2(2560.0, 1080.0),
		Vector2(1280.0, 800.0),
	]
	for viewport_size in cases:
		var rect: Rect2 = UILayoutHelper.centered_top_rect(viewport_size, Vector2(700.0, 84.0), 20.0, 0.75, 1.1)
		var delta := absf(rect.get_center().x - viewport_size.x * 0.5)
		if delta > 1.0:
			_errors.append("Centered top rect drifted by %.2f at %s" % [delta, viewport_size])
		var content_rect: Rect2 = UILayoutHelper.centered_content_rect(viewport_size, Vector2(1792.0, 810.0), 0.65, 1.1)
		if content_rect.position.x < 0.0 or content_rect.position.y < 0.0:
			_errors.append("Content rect escaped viewport at %s" % viewport_size)
		if content_rect.end.x > viewport_size.x + 1.0 or content_rect.end.y > viewport_size.y + 1.0:
			_errors.append("Content rect exceeded viewport at %s" % viewport_size)


func _validate_codex_grid_model() -> void:
	var model := ItemCodexGridModelScript.new()
	model.configure(21)
	if model.slot_count != 100:
		_errors.append("Codex should keep the first 100 planned slots when only 21 items exist.")
	model.configure(137)
	if model.slot_count != 140:
		_errors.append("Codex should round 137 items up to 140 slots.")
	if model.get_slot_number(0, 0, 0) != 1:
		_errors.append("Codex slot 0,0 should be No.1.")
	if model.get_slot_number(1, 0, 0) != 11:
		_errors.append("Codex scroll row 1 should start at No.11.")


func _validate_codex_node_grid() -> void:
	var codex := Control.new()
	codex.set_script(ItemCodexUIScript)
	root.add_child(codex)
	codex.call("_ready")
	codex.call("open_codex")
	codex.call("_update_layout_scale", Vector2(1920.0, 1080.0))
	codex.call("_sync_grid_panel", Rect2(Vector2(80.0, 155.0), Vector2(1326.0, 810.0)))
	var slot_buttons: Array = codex.get("_slot_buttons")
	if slot_buttons.size() != 100:
		_errors.append("Codex node grid should create 100 slot controls but created %d." % slot_buttons.size())
	elif slot_buttons[0].get_script() != ItemCodexSlotScript:
		_errors.append("Codex node grid first child should use ItemCodexSlot script.")
	codex.queue_free()
