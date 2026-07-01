class_name RaidHudPanel
extends Control

const RaidHUDStyle := preload("res://scripts/ui/ui_style.gd")

@export var raid_session_path: NodePath = NodePath("../../RaidSession")
@export var extraction_zone_path: NodePath = NodePath("../../SceneProps/ExtractionZone")
@export var player_path: NodePath = NodePath("../../Player3D")
@export var safe_margin := Vector2(36.0, 36.0)
@export var panel_size := Vector2(390.0, 166.0)

@onready var main_panel: PanelContainer = %MainPanel
@onready var objective_label: Label = %ObjectiveLabel
@onready var status_label: Label = %StatusLabel
@onready var extraction_label: Label = %ExtractionLabel
@onready var extraction_progress: ProgressBar = %ExtractionProgress
@onready var ammo_label: Label = %AmmoLabel

var _raid_session: Node = null
var _extraction_zone: Node = null
var _weapon_controller: Node = null
var _extraction_active := false
var _extraction_remaining := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_styles()
	_bind_world_nodes.call_deferred()
	resized.connect(_apply_responsive_layout)
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_apply_responsive_layout):
		get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()


func _process(_delta: float) -> void:
	_update_ammo()


func get_display_state() -> Dictionary:
	return {
		"objective": objective_label.text,
		"status": status_label.text,
		"extraction": extraction_label.text,
		"extraction_progress": extraction_progress.value,
		"ammo": ammo_label.text,
		"panel_rect": Rect2(global_position, size),
		"mouse_filter": mouse_filter,
		"visible": visible,
	}


func preview_layout(viewport_size: Vector2) -> Rect2:
	return _layout_for_viewport(viewport_size)


func _bind_world_nodes() -> void:
	_raid_session = get_node_or_null(raid_session_path)
	_extraction_zone = get_node_or_null(extraction_zone_path)
	var player := get_node_or_null(player_path)
	_weapon_controller = player.get_node_or_null("WeaponController3D") if player != null else null
	_connect_raid_session()
	_connect_extraction_zone()
	_update_objective()
	_update_raid_status()
	_update_extraction_idle()
	_update_ammo()


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


func _apply_styles() -> void:
	RaidHUDStyle.apply_overlay_panel_style(main_panel)
	RaidHUDStyle.apply_font_size(objective_label, RaidHUDStyle.FONT_BODY)
	RaidHUDStyle.apply_font_color(objective_label, RaidHUDStyle.COLOR_TEXT_PRIMARY)
	RaidHUDStyle.apply_font_size(status_label, RaidHUDStyle.FONT_PLACEHOLDER)
	RaidHUDStyle.apply_font_color(status_label, RaidHUDStyle.COLOR_TEXT_SUBTITLE)
	RaidHUDStyle.apply_font_size(extraction_label, RaidHUDStyle.FONT_PLACEHOLDER)
	RaidHUDStyle.apply_font_color(extraction_label, RaidHUDStyle.COLOR_TEXT_HELP)
	RaidHUDStyle.apply_font_size(ammo_label, RaidHUDStyle.FONT_PLACEHOLDER)
	RaidHUDStyle.apply_font_color(ammo_label, RaidHUDStyle.COLOR_TEXT_STATUS)


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
	objective_label.text = _text(&"ui.raid_hud.objective", "Find supplies and extract")


func _update_raid_status() -> void:
	var state: Dictionary = _raid_session.call("get_state") if _raid_session != null and _raid_session.has_method("get_state") else {}
	if bool(state.get("dead", false)):
		status_label.text = _text(&"ui.raid_hud.status_dead", "Raid failed")
	elif bool(state.get("extracted", false)):
		status_label.text = _text(&"ui.raid_hud.status_extracted", "Extracted")
	elif bool(state.get("active", false)):
		var elapsed := float(state.get("elapsed_time", 0.0))
		status_label.text = "%s %.0fs" % [_text(&"ui.raid_hud.status_active", "Raid active"), elapsed]
	else:
		status_label.text = _text(&"ui.raid_hud.status_ready", "Ready")


func _update_extraction_idle() -> void:
	_extraction_active = false
	_extraction_remaining = 0.0
	extraction_label.text = _text(&"ui.raid_hud.extraction_hint", "Reach extraction zone to leave")
	extraction_progress.value = 0.0


func _update_ammo() -> void:
	if _weapon_controller == null:
		ammo_label.text = _text(&"ui.raid_hud.ammo_missing", "Ammo: -- / --")
		return
	ammo_label.text = "%s: %d / %d" % [
		_text(&"ui.raid_hud.ammo", "Ammo"),
		int(_weapon_controller.get("current_ammo")),
		int(_weapon_controller.get("reserve_ammo")),
	]


func _on_raid_state_changed(_state: Dictionary) -> void:
	_update_raid_status()


func _on_raid_completed(_result: Dictionary) -> void:
	_update_raid_status()


func _on_extraction_started(_body: Node3D) -> void:
	_extraction_active = true
	extraction_label.text = _text(&"ui.raid_hud.extracting", "Extracting...")
	extraction_progress.value = 0.0


func _on_extraction_progress(progress: float, remaining_time: float) -> void:
	_extraction_active = true
	_extraction_remaining = remaining_time
	extraction_progress.value = clampf(progress, 0.0, 1.0) * 100.0
	extraction_label.text = "%s %.1fs" % [_text(&"ui.raid_hud.extraction_remaining", "Extraction"), _extraction_remaining]


func _on_extraction_cancelled(_body: Node3D) -> void:
	_update_extraction_idle()


func _on_extraction_completed(_body: Node3D) -> void:
	_extraction_active = false
	extraction_progress.value = 100.0
	extraction_label.text = _text(&"ui.raid_hud.extracted", "Extracted")


func _text(key: StringName, fallback: String) -> String:
	var key_text := str(key)
	var translated := tr(key_text)
	return fallback if translated == key_text else translated
