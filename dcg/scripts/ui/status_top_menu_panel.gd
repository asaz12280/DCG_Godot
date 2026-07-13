class_name StatusTopMenuPanel
extends Control

const UIStyleScript := preload("res://scripts/ui/ui_style.gd")
const UILayoutScript := preload("res://scripts/ui/ui_layout.gd")
const UITextScript := preload("res://scripts/ui/ui_text.gd")
const UISurfacePaletteScript := preload("res://scripts/ui/ui_surface_palette.gd")

@export var design_panel_size := UISurfacePaletteScript.SIZE_STATUS_PANEL
@export var design_top_margin := UISurfacePaletteScript.TOP_MENU_PANEL_TOP_MARGIN

@onready var main_panel: PanelContainer = %MainPanel
@onready var panel_margin: MarginContainer = $MainPanel/PanelMargin
@onready var title_label: Label = %TitleLabel
@onready var hint_label: Label = %HintLabel
@onready var health_label: Label = %HealthLabel
@onready var stamina_label: Label = %StaminaLabel
@onready var weight_label: Label = %WeightLabel
@onready var weapon_ammo_label: Label = %WeaponAmmoLabel
@onready var equipment_title_label: Label = %EquipmentTitleLabel
@onready var equipment_list_label: Label = %EquipmentListLabel

var is_open := false
var _status_summary := {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_remove_weight_progress_row()
	_apply_styles()
	_apply_responsive_layout()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_apply_responsive_layout):
		get_viewport().size_changed.connect(_apply_responsive_layout)
	refresh()


func open_status() -> void:
	is_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	refresh()
	_apply_responsive_layout()


func close_status() -> void:
	is_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh() -> void:
	title_label.text = _text(&"ui.top.status_panel_title", "角色狀態")
	hint_label.text = _text(&"ui.top.status_panel_hint", "查看生命、體力、負重、裝備與武器彈藥。")
	equipment_title_label.text = _text(&"ui.top.status_equipment", "裝備")
	_status_summary = _build_status_summary()
	health_label.text = "%s：%s" % [_text(&"ui.top.status_health", "生命"), str(_status_summary.get("health", "-- / --"))]
	stamina_label.text = "%s：%s" % [_text(&"ui.top.status_stamina", "體力"), str(_status_summary.get("stamina", "-- / --"))]
	_refresh_weight_row()
	weapon_ammo_label.text = "%s：%s" % [_text(&"ui.top.status_weapon_ammo", "武器彈藥"), str(_status_summary.get("weapon_ammo", _none_text()))]
	equipment_list_label.text = str(_status_summary.get("equipment", _none_text()))


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
		"health": health_label.text,
		"stamina": stamina_label.text,
		"weight": weight_label.text,
		"weight_value": str(_status_summary.get("weight", "")),
		"weight_ratio": float(_status_summary.get("weight_ratio", 0.0)),
		"weight_bar_visible": false,
		"weapon_ammo": weapon_ammo_label.text,
		"equipment": equipment_list_label.text,
		"summary": _status_summary.duplicate(true),
		"panel_rect": rect,
		"title_origin": _title_origin_for_viewport(viewport_size),
		"mouse_filter": mouse_filter,
	}


func preview_layout(viewport_size: Vector2) -> Rect2:
	return _layout_for_viewport(viewport_size)


func _apply_styles() -> void:
	UIStyleScript.apply_top_menu_panel_style(main_panel)
	for label in [title_label, equipment_title_label]:
		UIStyleScript.apply_font_size(label, UIStyleScript.FONT_PANEL_TITLE)
		UIStyleScript.apply_font_color(label, UIStyleScript.COLOR_TEXT_PRIMARY)
	for label in [hint_label]:
		UIStyleScript.apply_font_size(label, UIStyleScript.FONT_PLACEHOLDER)
		UIStyleScript.apply_font_color(label, UIStyleScript.COLOR_TEXT_HELP)
	for label in [health_label, stamina_label, weight_label, weapon_ammo_label, equipment_list_label]:
		UIStyleScript.apply_font_size(label, UIStyleScript.FONT_PLACEHOLDER)
		UIStyleScript.apply_font_color(label, UIStyleScript.COLOR_TEXT_STATUS)


func _remove_weight_progress_row() -> void:
	if weight_label == null or weight_label.get_parent() == null:
		return
	var rows := weight_label.get_parent()
	var existing_row := rows.get_node_or_null("WeightRow") as HBoxContainer
	if existing_row == null:
		return
	var old_index := existing_row.get_index()
	if weight_label.get_parent() == existing_row:
		existing_row.remove_child(weight_label)
		rows.add_child(weight_label)
		rows.move_child(weight_label, old_index)
	weight_label.custom_minimum_size = Vector2.ZERO
	weight_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	existing_row.queue_free()


func _refresh_weight_row() -> void:
	weight_label.text = _text(&"ui.top.status_weight", "負重")
	weight_label.text = "%s：%s" % [
		weight_label.text,
		str(_status_summary.get("weight", "-- / --")),
	]


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1920.0, 1080.0)
	var rect := _layout_for_viewport(viewport_size)
	UIStyleScript.apply_top_menu_panel_margins(panel_margin, _top_menu_scale(viewport_size))
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = rect.position
	size = rect.size


func _layout_for_viewport(viewport_size: Vector2) -> Rect2:
	var rect := UILayoutScript.centered_top_rect(viewport_size, design_panel_size, design_top_margin, UISurfacePaletteScript.TOP_MENU_PANEL_MIN_SCALE, 1.0)
	rect.size.y = minf(rect.size.y, viewport_size.y * UISurfacePaletteScript.TOP_MENU_PANEL_MAX_VIEWPORT_HEIGHT_RATIO)
	return rect


func _title_origin_for_viewport(viewport_size: Vector2) -> Vector2:
	var rect := _layout_for_viewport(viewport_size)
	return rect.position + UISurfacePaletteScript.TOP_MENU_TITLE_ORIGIN * _top_menu_scale(viewport_size)


func _top_menu_scale(viewport_size: Vector2) -> float:
	return UILayoutScript.design_scale(viewport_size, UISurfacePaletteScript.TOP_MENU_PANEL_MIN_SCALE, 1.0)


func _build_status_summary() -> Dictionary:
	var player := _player()
	if player == null:
		return {
			"health": "-- / --",
			"stamina": "-- / --",
			"weight": "-- / --",
			"current_weight": 0.0,
			"carry_weight_limit": 0.0,
			"weight_ratio": 0.0,
			"weapon_ammo": _none_text(),
			"equipment": _none_text(),
		}
	var weight_state := _weight_state(player)
	return {
		"health": _health_text(player),
		"stamina": _stamina_text(player),
		"weight": str(weight_state.get("text", "-- / --")),
		"current_weight": float(weight_state.get("current", 0.0)),
		"carry_weight_limit": float(weight_state.get("limit", 0.0)),
		"weight_ratio": float(weight_state.get("ratio", 0.0)),
		"weapon_ammo": _weapon_ammo_text(player),
		"equipment": _equipment_text(player),
	}


func _health_text(player: Node) -> String:
	var current := _node_number(player, "health", 0.0)
	var maximum := float(player.call("get_total_max_health")) if player.has_method("get_total_max_health") else _node_number(player, "max_health", 0.0)
	return "%d / %d" % [roundi(current), roundi(maximum)]


func _stamina_text(player: Node) -> String:
	var current := _node_number(player, "stamina", 0.0)
	var maximum := _node_number(player, "max_stamina", 0.0)
	return "%d / %d" % [roundi(current), roundi(maximum)]


func _weight_state(player: Node) -> Dictionary:
	var current := 0.0
	if player.has_method("get_current_carry_weight"):
		current = float(player.call("get_current_carry_weight"))
	elif player.has_method("get_inventory_model"):
		var backpack: RefCounted = player.call("get_inventory_model")
		if backpack != null and backpack.has_method("get_total_weight"):
			current = float(backpack.call("get_total_weight"))
	var limit := float(player.call("get_total_carry_weight_limit")) if player.has_method("get_total_carry_weight_limit") else _node_number(player, "carry_weight_limit", 0.0)
	return {
		"text": "%.1f / %.1fkg" % [current, limit],
		"current": current,
		"limit": limit,
		"ratio": 0.0 if limit <= 0.0 else clampf(current / limit, 0.0, 1.0),
	}


func _weapon_ammo_text(player: Node) -> String:
	var weapon := player.get_node_or_null("WeaponController3D")
	if weapon == null:
		return _none_text()
	var weapon_def: Variant = weapon.get("weapon_def")
	if weapon_def == null:
		return _none_text()
	var weapon_name := _item_def_name(weapon_def)
	return "%s　%d / %d" % [
		weapon_name,
		int(weapon.get("current_ammo")),
		int(weapon.get("reserve_ammo")),
	]


func _equipment_text(player: Node) -> String:
	if not player.has_method("get_equipment_model"):
		return _none_text()
	var equipment: RefCounted = player.call("get_equipment_model")
	if equipment == null or not equipment.has_method("get_slot_ids") or not equipment.has_method("get_slot"):
		return _none_text()
	var rows: Array[String] = []
	for slot_id in equipment.call("get_slot_ids"):
		var stack: Dictionary = equipment.call("get_slot", slot_id)
		if stack.is_empty():
			continue
		rows.append("%s：%s" % [_slot_label(StringName(slot_id)), _stack_name(stack)])
	var armor_effect := _armor_effect_text(player)
	if armor_effect != "":
		rows.append(armor_effect)
	if rows.is_empty():
		return _none_text()
	return "\n".join(rows)


func _armor_effect_text(player: Node) -> String:
	if not player.has_method("get_armor_effect_state"):
		return ""
	var state: Dictionary = player.call("get_armor_effect_state")
	if not bool(state.get("equipped", false)):
		return ""
	var defense_bonus := float(state.get("defense_bonus", 0.0))
	if defense_bonus <= 0.0:
		return _text(&"ui.top.status_armor_no_bonus", "防護效果：尚未提供減傷")
	return _text(&"ui.top.status_armor_bonus_format", "防護效果：每次受擊 -%.0f 傷害") % defense_bonus


func _stack_name(stack: Dictionary) -> String:
	var key := StringName(str(stack.get("name_key", "")))
	if str(key) != "":
		return _text(key, str(stack.get("name", _none_text())))
	return str(stack.get("name", _none_text()))


func _item_def_name(item_def: Variant) -> String:
	if not (item_def is ItemDef):
		return _none_text()
	var key := (item_def as ItemDef).name_key
	if str(key) != "":
		return _text(key, (item_def as ItemDef).display_name)
	return (item_def as ItemDef).display_name if (item_def as ItemDef).display_name != "" else _none_text()


func _slot_label(slot_id: StringName) -> String:
	match slot_id:
		&"primary_weapon":
			return _text(&"ui.top.status_slot_primary_weapon", "主武器")
		&"sidearm":
			return _text(&"ui.top.status_slot_sidearm", "副武器")
		&"melee":
			return _text(&"ui.top.status_slot_melee", "近戰")
		&"helmet":
			return _text(&"ui.top.status_slot_helmet", "頭盔")
		&"armor":
			return _text(&"ui.top.status_slot_armor", "護甲")
		&"glasses":
			return _text(&"ui.top.status_slot_glasses", "眼鏡")
		&"headset":
			return _text(&"ui.top.status_slot_headset", "耳機")
		&"backpack":
			return _text(&"ui.top.status_slot_backpack", "背包")
		&"weapon_mag":
			return _text(&"ui.top.status_slot_weapon_mag", "Magazine")
		&"weapon_grip":
			return _text(&"ui.top.status_slot_weapon_grip", "Grip")
		&"weapon_muzzle":
			return _text(&"ui.top.status_slot_weapon_muzzle", "Muzzle")
		&"weapon_scope":
			return _text(&"ui.top.status_slot_weapon_scope", "Scope")
		&"weapon_stock":
			return _text(&"ui.top.status_slot_weapon_stock", "Stock")
		&"weapon_tactic":
			return _text(&"ui.top.status_slot_weapon_tactic", "Tactic")
		&"charm_1":
			return _text(&"ui.top.status_slot_charm_1", "圖騰 1")
		&"charm_2":
			return _text(&"ui.top.status_slot_charm_2", "圖騰 2")
		_:
			return str(slot_id)


func _player() -> Node:
	var search_root: Node = null
	if is_inside_tree() and get_tree() != null:
		search_root = get_tree().current_scene
		if search_root == null:
			search_root = get_tree().root
	if search_root == null:
		search_root = get_parent()
	if search_root == null:
		return null
	return search_root.find_child("Player3D", true, false)


func _node_number(node: Object, property_name: StringName, fallback: float) -> float:
	if node == null:
		return fallback
	var value: Variant = node.get(property_name)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	return fallback


func _none_text() -> String:
	return _text(&"ui.top.status_none", "無")


func _text(key: StringName, fallback: String) -> String:
	return UITextScript.text(self, key, fallback)
