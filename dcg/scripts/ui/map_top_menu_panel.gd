class_name MapTopMenuPanel
extends Control

const UIStyleScript := preload("res://scripts/ui/ui_style.gd")
const UILayoutScript := preload("res://scripts/ui/ui_layout.gd")
const UITextScript := preload("res://scripts/ui/ui_text.gd")

@export var design_panel_size := Vector2(860.0, 96.0)
@export var design_top_margin := 126.0

@onready var main_panel: PanelContainer = %MainPanel
@onready var info_panel: PanelContainer = $MainPanel/PanelMargin/Content/InfoPanel
@onready var title_label: Label = %TitleLabel
@onready var hint_label: Label = %HintLabel
@onready var area_label: Label = %AreaLabel
@onready var route_label: Label = %RouteLabel
@onready var extraction_label: Label = %ExtractionLabel
@onready var danger_label: Label = %DangerLabel
@onready var loot_label: Label = %LootLabel
@onready var flow_state_label: Label = %FlowStateLabel
@onready var note_label: Label = %NoteLabel

var is_open := false
var _map_summary := {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_styles()
	_apply_responsive_layout()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_apply_responsive_layout):
		get_viewport().size_changed.connect(_apply_responsive_layout)
	refresh()
	_clear_body_text()


func open_map() -> void:
	is_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	refresh()
	_apply_responsive_layout()


func close_map() -> void:
	is_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh() -> void:
	title_label.text = _text(&"ui.top.map_panel_title", "區域地圖")
	_map_summary = _build_map_summary()
	_clear_body_text()


func get_display_state() -> Dictionary:
	var viewport_size := get_viewport_rect().size if is_inside_tree() else Vector2(1920.0, 1080.0)
	return get_display_state_for_viewport(viewport_size)


func get_display_state_for_viewport(viewport_size: Vector2) -> Dictionary:
	var rect := _layout_for_viewport(viewport_size)
	return {
		"visible": visible,
		"is_open": is_open,
		"title": title_label.text,
		"hint": hint_label.text,
		"area": area_label.text,
		"route": route_label.text,
		"extraction": extraction_label.text,
		"danger": danger_label.text,
		"loot": loot_label.text,
		"flow_state": flow_state_label.text,
		"note": note_label.text,
		"summary": _map_summary.duplicate(true),
		"panel_rect": rect,
		"mouse_filter": mouse_filter,
		"body_visible": info_panel.visible if info_panel != null else false,
	}


func preview_layout(viewport_size: Vector2) -> Rect2:
	return _layout_for_viewport(viewport_size)


func _apply_styles() -> void:
	UIStyleScript.apply_overlay_panel_style(main_panel)
	UIStyleScript.apply_font_size(title_label, UIStyleScript.FONT_BODY)
	UIStyleScript.apply_font_color(title_label, UIStyleScript.COLOR_TEXT_PRIMARY)
	UIStyleScript.apply_font_size(hint_label, UIStyleScript.FONT_PLACEHOLDER)
	UIStyleScript.apply_font_color(hint_label, UIStyleScript.COLOR_TEXT_HELP)
	for label in [area_label, route_label, extraction_label, danger_label, loot_label, flow_state_label, note_label]:
		UIStyleScript.apply_font_size(label, UIStyleScript.FONT_PLACEHOLDER)
		UIStyleScript.apply_font_color(label, UIStyleScript.COLOR_TEXT_STATUS)


func _clear_body_text() -> void:
	if hint_label != null:
		hint_label.text = _text(&"ui.top.map_panel_hint", "早期導覽：確認目前位置、撤離方向與行動狀態。")
		hint_label.visible = true
	if info_panel != null:
		info_panel.visible = false
	for label in [area_label, route_label, extraction_label, danger_label, loot_label, flow_state_label, note_label]:
		if label == null:
			continue
		label.text = ""
		label.visible = false


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1920.0, 1080.0)
	var rect := _layout_for_viewport(viewport_size)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = rect.position
	size = rect.size


func _layout_for_viewport(viewport_size: Vector2) -> Rect2:
	return UILayoutScript.centered_top_rect(viewport_size, design_panel_size, design_top_margin, 0.68, 1.0)


func _build_map_summary() -> Dictionary:
	var scene := _current_scene()
	var raid_session := _raid_session(scene)
	var is_base := scene != null and str(scene.scene_file_path).contains("/base/")
	return {
		"area": _area_name(raid_session, is_base),
		"route": _route_text(scene, is_base),
		"extraction": _extraction_text(scene, is_base),
		"danger": _danger_text(scene, is_base),
		"loot": _loot_text(scene, is_base),
		"flow_state": _flow_state_text(raid_session, is_base),
		"note": _text(&"ui.top.map_note_v2", "此頁是出擊用的資訊地圖；完整可探索大地圖會在核心流程穩定後再製作。"),
	}


func _area_name(raid_session: Node, is_base: bool) -> String:
	if is_base:
		return _text(&"ui.top.map_area_base_v2", "基地安全區")
	if raid_session != null and raid_session.has_method("get_state"):
		var state: Dictionary = raid_session.call("get_state")
		if str(state.get("map_id", "")) == "refuge_outskirts":
			return _text(&"ui.top.map_area_refuge_outskirts_v2", "郊外回收區（避難郊區）")
	return _text(&"ui.top.map_area_refuge_outskirts_v2", "郊外回收區（避難郊區）")


func _route_text(scene: Node, is_base: bool) -> String:
	if is_base:
		return _text(&"ui.top.map_route_base", "整理裝備後，從出擊門進入郊外回收區。")
	var loot_direction := _direction_to_named_node(scene, "LootContainer")
	var extraction_direction := _extraction_direction(scene)
	return _text(&"ui.top.map_route_raid", "出生點 → %s 箱子區 → %s 撤離點。") % [loot_direction, extraction_direction]


func _extraction_text(scene: Node, is_base: bool) -> String:
	if is_base:
		return _text(&"ui.top.map_extraction_base_v2", "基地內無撤離壓力")
	var extraction_zone := _find_node(scene, "ExtractionZone") as Node3D
	var player := _find_node(scene, "Player3D") as Node3D
	if extraction_zone == null or player == null:
		return _text(&"ui.top.map_extraction_unknown", "尋找撤離點標記")
	return _text(&"ui.top.map_extraction_toward", "往 %s 的撤離點前進") % _cardinal_direction(extraction_zone.global_position - player.global_position)


func _danger_text(scene: Node, is_base: bool) -> String:
	if is_base:
		return _text(&"ui.top.map_danger_base", "基地內無敵人；出擊後才會遭遇威脅。")
	var direction := _direction_to_named_node(scene, "Scavenger")
	return _text(&"ui.top.map_danger_raid", "%s 巡邏區有拾荒者，靠近會追蹤並攻擊。") % direction


func _loot_text(scene: Node, is_base: bool) -> String:
	if is_base:
		return _text(&"ui.top.map_loot_base", "基地倉庫可整理帶回物資；出擊中才有箱子。")
	var count := _count_nodes(scene, "LootContainer")
	var direction := _direction_to_named_node(scene, "LootContainer")
	return _text(&"ui.top.map_loot_raid", "%s 可見 %d 個物資箱，優先搜尋後再撤離。") % [direction, count]


func _flow_state_text(raid_session: Node, is_base: bool) -> String:
	if is_base:
		return _text(&"ui.top.map_flow_base", "基地中")
	if raid_session == null or not raid_session.has_method("get_state"):
		return _text(&"ui.top.map_flow_raid", "出擊中")
	var state: Dictionary = raid_session.call("get_state")
	if bool(state.get("extracted", false)):
		return _text(&"ui.top.map_flow_extracted", "已撤離")
	if bool(state.get("dead", false)):
		return _text(&"ui.top.map_flow_failed", "行動失敗")
	if bool(state.get("active", false)):
		return _text(&"ui.top.map_flow_raid", "出擊中")
	return _text(&"ui.top.map_flow_ready", "準備中")


func _direction_to_named_node(scene: Node, name_token: String) -> String:
	var player := _find_node(scene, "Player3D") as Node3D
	var target := _find_first_node_containing(scene, name_token) as Node3D
	if player == null or target == null:
		return _text(&"ui.top.map_dir_unknown", "未知方向")
	return _cardinal_direction(target.global_position - player.global_position)


func _extraction_direction(scene: Node) -> String:
	var player := _find_node(scene, "Player3D") as Node3D
	var target := _find_node(scene, "ExtractionZone") as Node3D
	if player == null or target == null:
		return _text(&"ui.top.map_dir_unknown", "未知方向")
	return _cardinal_direction(target.global_position - player.global_position)


func _cardinal_direction(direction: Vector3) -> String:
	var planar := Vector2(direction.x, direction.z)
	if planar.length() < 0.01:
		return _text(&"ui.top.map_dir_here", "目前位置")
	var angle := atan2(planar.x, -planar.y)
	var index := int(round(angle / (PI / 4.0))) % 8
	if index < 0:
		index += 8
	var keys: Array[StringName] = [
		&"ui.top.map_dir_n",
		&"ui.top.map_dir_ne",
		&"ui.top.map_dir_e",
		&"ui.top.map_dir_se",
		&"ui.top.map_dir_s",
		&"ui.top.map_dir_sw",
		&"ui.top.map_dir_w",
		&"ui.top.map_dir_nw",
	]
	var fallbacks := ["北側", "東北側", "東側", "東南側", "南側", "西南側", "西側", "西北側"]
	return _text(keys[index], fallbacks[index])


func _raid_session(scene: Node) -> Node:
	if scene == null:
		return null
	return scene.get_node_or_null("RaidSession")


func _current_scene() -> Node:
	if is_inside_tree() and get_tree() != null:
		return get_tree().current_scene
	return null


func _find_node(search_root: Node, node_name: String) -> Node:
	if search_root == null:
		return null
	return search_root.find_child(node_name, true, false)


func _find_first_node_containing(search_root: Node, token: String) -> Node:
	if search_root == null:
		return null
	if search_root.name.contains(token):
		return search_root
	for child in search_root.get_children():
		var found := _find_first_node_containing(child, token)
		if found != null:
			return found
	return null


func _count_nodes(search_root: Node, token: String) -> int:
	if search_root == null:
		return 0
	var count := 1 if search_root.name.contains(token) else 0
	for child in search_root.get_children():
		count += _count_nodes(child, token)
	return count


func _unknown_text() -> String:
	return _text(&"ui.top.map_unknown", "未知")


func _text(key: StringName, fallback: String) -> String:
	return UITextScript.text(self, key, fallback)
