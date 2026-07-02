class_name RaidHudPanel
extends Control

const RaidHUDStyle := preload("res://scripts/ui/ui_style.gd")
const UITextScript := preload("res://scripts/ui/ui_text.gd")

@export var raid_session_path: NodePath = NodePath("../../RaidSession")
@export var extraction_zone_path: NodePath = NodePath("../../SceneProps/ExtractionZone")
@export var player_path: NodePath = NodePath("../../Player3D")
@export var safe_margin := Vector2(36.0, 36.0)
@export var panel_size := Vector2(430.0, 216.0)

@onready var main_panel: PanelContainer = %MainPanel
@onready var goal_title_label: Label = %GoalTitleLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var route_hint_label: Label = %RouteHintLabel
@onready var status_label: Label = %StatusLabel
@onready var vitals_label: Label = %VitalsLabel
@onready var extraction_label: Label = %ExtractionLabel
@onready var extraction_progress: ProgressBar = %ExtractionProgress
@onready var ammo_label: Label = %AmmoLabel
@onready var weapon_status_label: Label = %WeaponStatusLabel
@onready var reload_label: Label = %ReloadLabel
@onready var reload_progress: ProgressBar = %ReloadProgress

var _raid_session: Node = null
var _extraction_zone: Node = null
var _player: Node = null
var _weapon_controller: Node = null
var _extraction_active := false
var _extraction_remaining := 0.0
var _reload_status_hold := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_styles()
	_bind_world_nodes.call_deferred()
	resized.connect(_apply_responsive_layout)
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_apply_responsive_layout):
		get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()


func _process(_delta: float) -> void:
	_update_raid_status()
	_update_vitals()
	_update_ammo()
	_update_weapon_status()
	_update_reload_hold(_delta)


func get_display_state() -> Dictionary:
	return {
		"goal_title": goal_title_label.text,
		"objective": objective_label.text,
		"route_hint": route_hint_label.text,
		"status": status_label.text,
		"vitals": vitals_label.text,
		"extraction": extraction_label.text,
		"extraction_progress": extraction_progress.value,
		"ammo": ammo_label.text,
		"weapon_status": weapon_status_label.text,
		"reload": reload_label.text,
		"reload_progress": reload_progress.value,
		"reload_visible": reload_progress.visible,
		"panel_rect": Rect2(global_position, size),
		"mouse_filter": mouse_filter,
		"visible": visible,
	}


func preview_layout(viewport_size: Vector2) -> Rect2:
	return _layout_for_viewport(viewport_size)


func _bind_world_nodes() -> void:
	_raid_session = get_node_or_null(raid_session_path)
	_extraction_zone = get_node_or_null(extraction_zone_path)
	_player = get_node_or_null(player_path)
	_weapon_controller = _player.get_node_or_null("WeaponController3D") if _player != null else null
	_connect_raid_session()
	_connect_extraction_zone()
	_connect_player_reload()
	_update_objective()
	_update_raid_status()
	_update_vitals()
	_update_extraction_idle()
	_update_ammo()
	_update_weapon_status()
	_update_reload_idle()


func _connect_raid_session() -> void:
	if _raid_session == null:
		return
	if _raid_session.has_signal("raid_started") and not _raid_session.raid_started.is_connected(_on_raid_state_changed):
		_raid_session.raid_started.connect(_on_raid_state_changed)
	if _raid_session.has_signal("raid_state_changed") and not _raid_session.raid_state_changed.is_connected(_on_raid_state_changed):
		_raid_session.raid_state_changed.connect(_on_raid_state_changed)
	if _raid_session.has_signal("raid_completed") and not _raid_session.raid_completed.is_connected(_on_raid_completed):
		_raid_session.raid_completed.connect(_on_raid_completed)


func _connect_extraction_zone() -> void:
	if _extraction_zone == null:
		return
	if _extraction_zone.has_signal("extraction_started") and not _extraction_zone.extraction_started.is_connected(_on_extraction_started):
		_extraction_zone.extraction_started.connect(_on_extraction_started)
	if _extraction_zone.has_signal("extraction_progress") and not _extraction_zone.extraction_progress.is_connected(_on_extraction_progress):
		_extraction_zone.extraction_progress.connect(_on_extraction_progress)
	if _extraction_zone.has_signal("extraction_cancelled") and not _extraction_zone.extraction_cancelled.is_connected(_on_extraction_cancelled):
		_extraction_zone.extraction_cancelled.connect(_on_extraction_cancelled)
	if _extraction_zone.has_signal("extraction_completed") and not _extraction_zone.extraction_completed.is_connected(_on_extraction_completed):
		_extraction_zone.extraction_completed.connect(_on_extraction_completed)


func _connect_player_reload() -> void:
	if _player == null:
		return
	if _player.has_signal("reload_progress_changed") and not _player.reload_progress_changed.is_connected(_on_reload_progress_changed):
		_player.reload_progress_changed.connect(_on_reload_progress_changed)


func _apply_styles() -> void:
	RaidHUDStyle.apply_overlay_panel_style(main_panel)
	RaidHUDStyle.apply_font_size(goal_title_label, RaidHUDStyle.FONT_HELP)
	RaidHUDStyle.apply_font_color(goal_title_label, RaidHUDStyle.COLOR_TEXT_SUBTITLE)
	RaidHUDStyle.apply_font_size(objective_label, RaidHUDStyle.FONT_BODY)
	RaidHUDStyle.apply_font_color(objective_label, RaidHUDStyle.COLOR_TEXT_PRIMARY)
	RaidHUDStyle.apply_font_size(route_hint_label, RaidHUDStyle.FONT_HELP)
	RaidHUDStyle.apply_font_color(route_hint_label, RaidHUDStyle.COLOR_TEXT_HELP)
	RaidHUDStyle.apply_font_size(status_label, RaidHUDStyle.FONT_PLACEHOLDER)
	RaidHUDStyle.apply_font_color(status_label, RaidHUDStyle.COLOR_TEXT_SUBTITLE)
	RaidHUDStyle.apply_font_size(vitals_label, RaidHUDStyle.FONT_PLACEHOLDER)
	RaidHUDStyle.apply_font_color(vitals_label, RaidHUDStyle.COLOR_TEXT_STATUS)
	RaidHUDStyle.apply_font_size(extraction_label, RaidHUDStyle.FONT_PLACEHOLDER)
	RaidHUDStyle.apply_font_color(extraction_label, RaidHUDStyle.COLOR_TEXT_HELP)
	RaidHUDStyle.apply_font_size(ammo_label, RaidHUDStyle.FONT_PLACEHOLDER)
	RaidHUDStyle.apply_font_color(ammo_label, RaidHUDStyle.COLOR_TEXT_STATUS)
	RaidHUDStyle.apply_font_size(weapon_status_label, RaidHUDStyle.FONT_PLACEHOLDER)
	RaidHUDStyle.apply_font_color(weapon_status_label, RaidHUDStyle.COLOR_TEXT_STATUS)
	RaidHUDStyle.apply_font_size(reload_label, RaidHUDStyle.FONT_HELP)
	RaidHUDStyle.apply_font_color(reload_label, RaidHUDStyle.COLOR_TEXT_SUBTITLE)


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1920.0, 1080.0)
	var rect := _layout_for_viewport(viewport_size)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = rect.position
	size = rect.size


func _layout_for_viewport(viewport_size: Vector2) -> Rect2:
	var margin := Vector2(
		minf(safe_margin.x, maxf(24.0, viewport_size.x * 0.028)),
		minf(safe_margin.y, maxf(24.0, viewport_size.y * 0.034))
	)
	var target_size := Vector2(
		minf(panel_size.x, maxf(340.0, viewport_size.x * 0.30)),
		panel_size.y
	)
	target_size.x = minf(target_size.x, maxf(1.0, viewport_size.x - margin.x * 2.0))
	target_size.y = minf(target_size.y, maxf(1.0, viewport_size.y - margin.y * 2.0))
	return Rect2(margin.floor(), target_size)


func _update_objective() -> void:
	goal_title_label.text = _text(&"ui.raid_hud.goal_title", "目前目標")
	objective_label.text = _text(&"ui.raid_hud.objective", "搜索物資 / 小心敵人 / 前往撤離點")
	route_hint_label.text = _text(&"ui.raid_hud.route_hint", "搜完箱子後，確認血量與彈藥，再站進撤離區倒數。")


func _update_raid_status() -> void:
	var state: Dictionary = _raid_session.call("get_state") if _raid_session != null and _raid_session.has_method("get_state") else {}
	if bool(state.get("dead", false)):
		status_label.text = _text(&"ui.raid_hud.status_dead", "行動失敗")
	elif bool(state.get("extracted", false)):
		status_label.text = _text(&"ui.raid_hud.status_extracted", "已撤離")
	elif bool(state.get("active", false)):
		var elapsed := float(state.get("elapsed_time", 0.0))
		status_label.text = "%s %.0f 秒" % [_text(&"ui.raid_hud.status_active", "行動中"), elapsed]
	else:
		status_label.text = _text(&"ui.raid_hud.status_ready", "準備中")


func _update_vitals() -> void:
	if _player == null:
		vitals_label.text = _text(&"ui.raid_hud.vitals_missing", "生命：-- / --　體力：-- / --")
		return
	var health_current: float = _node_number(_player, "health", 0.0)
	var health_max: float = float(_player.call("get_total_max_health")) if _player.has_method("get_total_max_health") else _node_number(_player, "max_health", 0.0)
	var stamina_current: float = _node_number(_player, "stamina", 0.0)
	var stamina_max: float = _node_number(_player, "max_stamina", 0.0)
	vitals_label.text = "%s：%d / %d　%s：%d / %d" % [
		_text(&"ui.raid_hud.health", "生命"),
		roundi(float(health_current)),
		roundi(float(health_max)),
		_text(&"ui.raid_hud.stamina", "體力"),
		roundi(float(stamina_current)),
		roundi(float(stamina_max)),
	]


func _update_extraction_idle() -> void:
	_extraction_active = false
	_extraction_remaining = 0.0
	extraction_label.text = _text(&"ui.raid_hud.extraction_hint", "前往撤離區即可離開")
	extraction_progress.value = 0.0


func _update_ammo() -> void:
	if _weapon_controller == null:
		ammo_label.text = "%s：%s　%s" % [
			_text(&"ui.raid_hud.weapon", "武器"),
			_text(&"ui.raid_hud.weapon_missing", "未裝備"),
			_text(&"ui.raid_hud.ammo_missing", "彈藥：-- / --"),
		]
		return
	ammo_label.text = "%s：%s　%s：%d / %d" % [
		_text(&"ui.raid_hud.weapon", "武器"),
		_weapon_display_name(),
		_text(&"ui.raid_hud.ammo", "彈藥"),
		int(_weapon_controller.get("current_ammo")),
		int(_weapon_controller.get("reserve_ammo")),
	]


func _update_weapon_status() -> void:
	weapon_status_label.text = "%s：%s" % [
		_text(&"ui.raid_hud.weapon_status", "戰鬥狀態"),
		_weapon_status_text(),
	]


func _weapon_status_text() -> String:
	if _is_player_reloading():
		return _text(&"ui.raid_hud.weapon_status_reloading", "裝填中")
	if _weapon_controller == null:
		return _text(&"ui.raid_hud.weapon_status_unarmed", "未裝備")
	if _weapon_controller.has_method("has_weapon") and not bool(_weapon_controller.call("has_weapon")):
		return _text(&"ui.raid_hud.weapon_status_unarmed", "未裝備")
	if _weapon_controller.get("weapon_def") == null:
		return _text(&"ui.raid_hud.weapon_status_unarmed", "未裝備")
	var current := int(_weapon_controller.get("current_ammo"))
	if current <= 0:
		return _text(&"ui.raid_hud.weapon_status_empty", "空彈")
	if _weapon_controller.has_method("get_fire_block_reason"):
		var reason := StringName(_weapon_controller.call("get_fire_block_reason"))
		if reason == &"cooldown":
			return _text(&"ui.raid_hud.weapon_status_cooldown", "射擊間隔")
		if reason == &"no_ammo":
			return _text(&"ui.raid_hud.weapon_status_empty", "空彈")
		if reason == &"no_weapon":
			return _text(&"ui.raid_hud.weapon_status_unarmed", "未裝備")
	return _text(&"ui.raid_hud.weapon_status_ready", "可射擊")


func _is_player_reloading() -> bool:
	if _player == null or not _player.has_method("get_reload_state"):
		return false
	var state: Dictionary = _player.call("get_reload_state")
	return bool(state.get("active", false))


func _update_reload_idle() -> void:
	reload_label.visible = false
	reload_progress.visible = false
	reload_progress.value = 0.0
	reload_label.text = _text(&"ui.raid_hud.reload_ready", "裝填：待命")


func _update_reload_hold(delta: float) -> void:
	if _reload_status_hold <= 0.0:
		return
	_reload_status_hold = maxf(_reload_status_hold - delta, 0.0)
	if _reload_status_hold <= 0.0:
		_update_reload_idle()


func _on_raid_state_changed(_state: Dictionary) -> void:
	_update_raid_status()


func _on_raid_completed(_result: Dictionary) -> void:
	_update_raid_status()


func _on_extraction_started(_body: Node3D) -> void:
	_extraction_active = true
	extraction_label.text = _text(&"ui.raid_hud.extracting", "撤離中...")
	extraction_progress.value = 0.0


func _on_extraction_progress(progress: float, remaining_time: float) -> void:
	_extraction_active = true
	_extraction_remaining = remaining_time
	extraction_progress.value = clampf(progress, 0.0, 1.0) * 100.0
	extraction_label.text = "%s %.1f 秒" % [_text(&"ui.raid_hud.extraction_remaining", "撤離"), _extraction_remaining]


func _on_extraction_cancelled(_body: Node3D) -> void:
	_update_extraction_idle()


func _on_extraction_completed(_body: Node3D) -> void:
	_extraction_active = false
	extraction_progress.value = 100.0
	extraction_label.text = _text(&"ui.raid_hud.extracted", "已撤離")


func _on_reload_progress_changed(state: Dictionary) -> void:
	var active := bool(state.get("active", false))
	var status := str(state.get("status", "idle"))
	var progress := clampf(float(state.get("progress", 0.0)), 0.0, 1.0)
	reload_progress.value = progress * 100.0
	if active:
		_reload_status_hold = 0.0
		reload_label.visible = true
		reload_progress.visible = true
		reload_label.text = "%s %.0f%%" % [_text(&"ui.raid_hud.reloading", "裝填中"), progress * 100.0]
		_update_weapon_status()
		return
	if status == "complete":
		reload_label.visible = true
		reload_progress.visible = true
		reload_progress.value = 100.0
		reload_label.text = _text(&"ui.raid_hud.reload_complete", "裝填完成")
		_reload_status_hold = 0.55
		_update_weapon_status()
		return
	if status != "idle":
		reload_label.visible = true
		reload_progress.visible = false
		reload_label.text = _text(&"ui.raid_hud.reload_cancelled", "裝填取消")
		_reload_status_hold = 0.55
		_update_weapon_status()
		return
	_update_reload_idle()
	_update_weapon_status()


func _text(key: StringName, fallback: String) -> String:
	return UITextScript.text(self, key, fallback)


func _weapon_display_name() -> String:
	if _weapon_controller == null:
		return _text(&"ui.raid_hud.weapon_missing", "未裝備")
	var weapon: Variant = _weapon_controller.get("weapon_def")
	if weapon == null:
		return _text(&"ui.raid_hud.weapon_missing", "未裝備")
	var name_key := str(weapon.get("name_key")) if weapon is Object else ""
	if name_key != "":
		var translated := _text(StringName(name_key), "")
		if translated != "":
			return translated
	var display_name := str(weapon.get("display_name")) if weapon is Object else ""
	return display_name if display_name != "" else _text(&"ui.raid_hud.weapon_missing", "未裝備")


func _node_number(node: Node, property_name: String, fallback: float) -> float:
	var value: Variant = node.get(property_name)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return fallback
