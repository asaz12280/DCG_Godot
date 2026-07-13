extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const UILayoutScript := preload("res://scripts/ui/ui_layout.gd")
const UISurfacePaletteScript := preload("res://scripts/ui/ui_surface_palette.gd")

const VIEWPORTS: Array[Vector2] = [
	Vector2(1280.0, 720.0),
	Vector2(1920.0, 1080.0),
	Vector2(2048.0, 960.0),
	Vector2(2560.0, 1200.0),
]

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	for viewport_size in VIEWPORTS:
		await _validate_viewport(viewport_size)
	if _errors.is_empty():
		print("[item_codex_layout] OK grid=inside_backing_frame viewports=1280x720,1920x1080,2048x960,2560x1200")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_viewport(viewport_size: Vector2) -> void:
	root.size = Vector2i(int(viewport_size.x), int(viewport_size.y))
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var codex := scene.get_node_or_null("HUD/ItemCodexUI") as Control
	if codex == null:
		_errors.append("Gameplay scene should expose ItemCodexUI.")
		_free_node(scene)
		return
	codex.call("open_codex")
	await process_frame
	var state: Dictionary = codex.call("get_display_state_for_viewport", viewport_size)
	var left_panel_rect: Rect2 = state.get("left_panel_rect", Rect2())
	var right_panel_rect: Rect2 = state.get("right_panel_rect", Rect2())
	var grid_rect: Rect2 = state.get("grid_rect", Rect2())
	var visible_grid_rect: Rect2 = state.get("visible_grid_rect", Rect2())
	var grid_content_rect: Rect2 = state.get("grid_content_rect", Rect2())
	var detail_content_rect: Rect2 = state.get("detail_content_rect", Rect2())
	var actual_grid_panel_rect: Rect2 = state.get("actual_grid_panel_rect", Rect2())
	var actual_detail_panel_rect: Rect2 = state.get("actual_detail_panel_rect", Rect2())
	var actual_detail_content_rect: Rect2 = state.get("actual_detail_content_rect", Rect2())
	var local_slot_union_rect: Rect2 = state.get("local_slot_union_rect", Rect2())
	var detail_visible_text := str(state.get("detail_visible_text", ""))
	var title_origin: Vector2 = state.get("title_origin", Vector2())
	var title_text_position: Vector2 = state.get("title_text_position", Vector2())
	_assert_rect_inside(left_panel_rect, Rect2(Vector2.ZERO, viewport_size), "Codex left panel")
	_assert_rect_inside(right_panel_rect, Rect2(Vector2.ZERO, viewport_size), "Codex detail panel")
	_assert_rect_inside(grid_rect, left_panel_rect, "Codex grid panel")
	_assert_rect_inside(visible_grid_rect, left_panel_rect, "Codex visible grid")
	_assert_rect_inside(detail_content_rect, right_panel_rect, "Codex detail content frame")
	_assert_rect_inside(actual_grid_panel_rect, left_panel_rect, "Actual codex grid panel")
	_assert_rect_inside(actual_detail_panel_rect, right_panel_rect, "Actual codex detail scroll panel")
	_assert_scroll_content_origin(actual_detail_content_rect, actual_detail_panel_rect, "Actual codex detail content")
	_assert_local_content_width(local_slot_union_rect, visible_grid_rect.size.x, "Actual codex slot columns")
	_assert_title_text_position(codex, viewport_size, title_origin, title_text_position)
	if not bool(state.get("detail_panel_has_scroll_container", false)):
		_errors.append("Codex detail information should be hosted by a ScrollContainer at %s." % viewport_size)
	_assert_text_contains(detail_visible_text, str(TranslationServer.translate("ui.weapon_detail.info_title")), "Weapon codex detail information heading")
	_assert_text_contains(detail_visible_text, str(TranslationServer.translate("ui.weapon_detail.stats_title")), "Weapon codex detail stats heading")
	if grid_content_rect.end.x > visible_grid_rect.end.x + 1.0:
		_errors.append("Codex grid columns should fit the backing frame at %s, got content %s visible %s." % [viewport_size, grid_content_rect, visible_grid_rect])
	if grid_rect.end.x > right_panel_rect.position.x - 1.0:
		_errors.append("Codex grid panel should not overlap the detail panel at %s." % viewport_size)
	if actual_grid_panel_rect.end.x > right_panel_rect.position.x - 1.0:
		_errors.append("Actual codex grid panel should not overlap the detail panel at %s." % viewport_size)
	_free_node(scene)


func _assert_rect_inside(rect: Rect2, parent_rect: Rect2, label: String) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		_errors.append("%s should have a positive size." % label)
		return
	if rect.position.x < parent_rect.position.x - 1.0 or rect.position.y < parent_rect.position.y - 1.0 or rect.end.x > parent_rect.end.x + 1.0 or rect.end.y > parent_rect.end.y + 1.0:
		_errors.append("%s should fit inside %s, got %s." % [label, parent_rect, rect])


func _assert_local_content_width(rect: Rect2, max_width: float, label: String) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		_errors.append("%s should have a positive size." % label)
		return
	if rect.position.x < -1.0 or rect.end.x > max_width + 1.0:
		_errors.append("%s should fit horizontally inside %.1fpx, got %s." % [label, max_width, rect])


func _assert_scroll_content_origin(rect: Rect2, parent_rect: Rect2, label: String) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		_errors.append("%s should have a positive size." % label)
		return
	if rect.position.x < parent_rect.position.x - 1.0 or rect.position.y < parent_rect.position.y - 1.0 or rect.position.x > parent_rect.end.x + 1.0 or rect.position.y > parent_rect.end.y + 1.0:
		_errors.append("%s should start inside %s, got %s." % [label, parent_rect, rect])


func _assert_text_contains(text: String, expected: String, label: String) -> void:
	if expected == "" or text.contains(expected):
		return
	_errors.append("%s should be present in codex detail visible text, expected '%s' in '%s'." % [label, expected, text])


func _assert_title_text_position(codex: Control, viewport_size: Vector2, title_origin: Vector2, title_text_position: Vector2) -> void:
	if codex == null:
		return
	var scale := UILayoutScript.design_scale(viewport_size, UISurfacePaletteScript.TOP_MENU_PANEL_MIN_SCALE, 1.0)
	var font_size := maxi(18, roundi(float(UISurfacePaletteScript.FONT_PANEL_TITLE) * scale))
	var expected_position := title_origin + Vector2(0.0, codex.get_theme_default_font().get_ascent(font_size))
	if expected_position.distance_to(title_text_position) > 1.0:
		_errors.append("Codex title text should use font ascent from the shared title origin at %s, expected %s got %s." % [viewport_size, expected_position, title_text_position])


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
