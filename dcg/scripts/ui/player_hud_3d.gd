extends Control

const PlayerHUDPainterScript := preload("res://scripts/ui/player_hud_painter.gd")

@export var health_offset: Vector2 = Vector2(0.0, -76.0)
@export var enemy_health_offset: Vector2 = Vector2(0.0, -76.0)
@export var stamina_offset: Vector2 = Vector2(-54.0, 70.0)
@export var health_size: Vector2 = Vector2(98.0, 16.0)
@export var enemy_health_size: Vector2 = Vector2(98.0, 16.0)
@export var lower_left_health_position: Vector2 = Vector2(42.0, -58.0)
@export var lower_left_health_size: Vector2 = Vector2(250.0, 44.0)
@export var ring_radius: float = 18.0
@export var ring_width: float = 6.0
@export var crosshair_color: Color = Color(0.98, 0.98, 0.94, 1.0)
@export var reload_bar_offset: Vector2 = Vector2(0.0, 48.0)
@export var reload_bar_size: Vector2 = Vector2(190.0, 14.0)
@export var reload_label_offset: Vector2 = Vector2(0.0, 72.0)
@export var ammo_panel_position: Vector2 = Vector2(-250.0, -70.0)
@export var ammo_panel_size: Vector2 = Vector2(210.0, 46.0)
@export var damage_feedback_duration: float = 0.45
@export var melee_slash_duration: float = 0.24

const WORLD_HUD_Z_INDEX := -10

var stamina: float = 100.0
var max_stamina: float = 100.0
var player: Node3D
var weapon_controller: Node = null
var stamina_visible_time: float = 0.0
var damage_feedback_time: float = 0.0
var last_health: float = -1.0
var reload_state: Dictionary = {
	"active": false,
	"progress": 0.0,
	"status": "idle",
}
var melee_attack_state: Dictionary = {
	"active": false,
	"mode_active": false,
	"hit_count": 0,
}
var melee_slash_time: float = 0.0
var melee_slash_direction := 1.0
var item_use_state: Dictionary = {
	"active": false,
	"progress": 0.0,
	"status": "idle",
}
var health_background_style := StyleBoxFlat.new()
var health_fill_style := StyleBoxFlat.new()
var lower_left_panel_style := StyleBoxFlat.new()
var lower_left_fill_style := StyleBoxFlat.new()
var lower_left_icon_style := StyleBoxFlat.new()
var reload_background_style := StyleBoxFlat.new()
var reload_fill_style := StyleBoxFlat.new()
var ammo_panel_style := StyleBoxFlat.new()
var _cached_backpack_ammo_count := 0
var _backpack_ammo_cache_dirty := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_as_relative = false
	z_index = WORLD_HUD_Z_INDEX
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	player = get_tree().get_first_node_in_group("player")
	if player != null:
		weapon_controller = player.get_node_or_null("WeaponController3D")
	if player != null and player.has_signal("stamina_changed"):
		player.stamina_changed.connect(_on_stamina_changed)
	if player != null and player.has_signal("health_changed"):
		player.health_changed.connect(_on_health_changed)
	if player != null and player.has_signal("reload_progress_changed"):
		player.reload_progress_changed.connect(_on_reload_progress_changed)
	if player != null and player.has_signal("item_use_progress_changed"):
		player.item_use_progress_changed.connect(_on_item_use_progress_changed)
	if player != null and player.has_signal("melee_attack_changed"):
		player.melee_attack_changed.connect(_on_melee_attack_changed)
	if player != null and player.has_signal("inventory_changed"):
		player.inventory_changed.connect(_mark_backpack_ammo_cache_dirty)
	if player != null and player.has_signal("equipment_changed"):
		player.equipment_changed.connect(_mark_backpack_ammo_cache_dirty)
	if player != null and player.has_method("get_reload_state"):
		reload_state = player.call("get_reload_state")
	if player != null and player.has_method("get_item_use_state"):
		item_use_state = player.call("get_item_use_state")
	if player != null and player.has_method("get_melee_attack_state"):
		melee_attack_state = player.call("get_melee_attack_state")
	if player != null:
		last_health = _player_float(&"health", -1.0)
	_refresh_backpack_ammo_cache()
	PlayerHUDPainterScript.setup_styles(self)


func _process(delta: float) -> void:
	stamina_visible_time = maxf(stamina_visible_time - delta, 0.0)
	damage_feedback_time = maxf(damage_feedback_time - delta, 0.0)
	melee_slash_time = maxf(melee_slash_time - delta, 0.0)
	queue_redraw()


func _on_stamina_changed(current: float, maximum: float) -> void:
	if current < stamina - 0.05:
		stamina_visible_time = 1.2
	stamina = current
	max_stamina = maximum


func _on_health_changed(current: float, _maximum: float) -> void:
	if last_health >= 0.0 and current < last_health - 0.05:
		damage_feedback_time = damage_feedback_duration
	last_health = current
	queue_redraw()


func _on_reload_progress_changed(state: Dictionary) -> void:
	var was_active := bool(reload_state.get("active", false))
	reload_state = state.duplicate(true)
	if _should_refresh_backpack_ammo_after_reload(was_active, reload_state):
		_refresh_backpack_ammo_cache()
	queue_redraw()


func _on_item_use_progress_changed(state: Dictionary) -> void:
	item_use_state = state.duplicate(true)
	queue_redraw()


func _on_melee_attack_changed(state: Dictionary) -> void:
	melee_attack_state = state.duplicate(true)
	if bool(melee_attack_state.get("active", false)):
		melee_slash_time = melee_slash_duration
	melee_slash_direction *= -1.0
	queue_redraw()


func _mark_backpack_ammo_cache_dirty() -> void:
	_backpack_ammo_cache_dirty = true
	queue_redraw()


func _should_refresh_backpack_ammo_after_reload(was_active: bool, state: Dictionary) -> bool:
	if bool(state.get("active", false)):
		return false
	var status := str(state.get("status", "idle"))
	return was_active or status == "complete"


func get_display_state() -> Dictionary:
	var enemy_health_bars := _enemy_health_bar_states()
	return {
		"visible": visible,
		"has_player": player != null,
		"crosshair_visible": visible,
		"health_current": _player_float("health", 0.0),
		"health_max": _player_max_health(),
		"health_text": _health_display_text(),
		"enemy_health_bar_count": enemy_health_bars.size(),
		"enemy_health_bars": enemy_health_bars,
		"damage_feedback_visible": damage_feedback_time > 0.0,
		"damage_feedback_alpha": _damage_feedback_alpha(),
		"reload_visible": _is_reload_visible(),
		"reload_progress": float(reload_state.get("progress", 0.0)),
		"reload_status": str(reload_state.get("status", "idle")),
		"item_use_visible": _is_item_use_visible(),
		"item_use_progress": float(item_use_state.get("progress", 0.0)),
		"item_use_status": str(item_use_state.get("status", "idle")),
		"melee_mode_active": bool(melee_attack_state.get("mode_active", false)),
		"melee_slash_visible": _is_melee_slash_visible(),
		"melee_slash_alpha": _melee_slash_alpha(),
		"melee_hit_count": int(melee_attack_state.get("hit_count", 0)),
		"held_weapon": _held_weapon_state(),
		"held_weapon_mode": str(_held_weapon_state().get("mode", "firearm")),
		"held_weapon_text": _held_weapon_display_text(),
		"quick_bar_slots": _quick_bar_slots(),
		"ammo_visible": true,
		"ammo_loaded": _weapon_int("current_ammo", 0),
		"ammo_backpack": _backpack_compatible_ammo_count(),
		"ammo_text": _ammo_display_text(),
	}


func _draw() -> void:
	PlayerHUDPainterScript.paint(self)


func _get_player_screen_position(offset: Vector2) -> Vector2:
	var camera := get_viewport().get_camera_3d()
	if player == null or camera == null:
		return Vector2(-1000.0, -1000.0)
	return _get_actor_screen_position(player, Vector3(0.0, 0.75, 0.0), offset)


func _crosshair_center() -> Vector2:
	var center := get_viewport().get_mouse_position()
	if center.x <= 0.0 or center.y <= 0.0 or center.x >= size.x or center.y >= size.y:
		center = size * 0.5
	return center


func _enemy_health_bar_states() -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	var tree := get_tree()
	if tree == null:
		return states
	var scene_root := _hud_scene_root()
	for node in tree.get_nodes_in_group("enemy"):
		var enemy := node as Node3D
		if enemy == null or not enemy.is_inside_tree():
			continue
		if scene_root != null and scene_root != self and not _is_descendant_of(enemy, scene_root):
			continue
		if enemy.has_method("is_alive") and not bool(enemy.call("is_alive")):
			continue
		var maximum := _node_float(enemy, &"max_health", 0.0)
		var current := _node_float(enemy, &"current_health", _node_float(enemy, &"health", maximum))
		if maximum <= 0.0 or current <= 0.0:
			continue
		var ratio := clampf(current / maximum, 0.0, 1.0)
		var center := _get_actor_screen_position(enemy, Vector3(0.0, 0.85, 0.0), enemy_health_offset)
		var rect := Rect2(center - enemy_health_size * 0.5, enemy_health_size)
		states.append({
			"node_path": str(enemy.get_path()),
			"health_current": current,
			"health_max": maximum,
			"ratio": ratio,
			"center": center,
			"rect": rect,
			"size": enemy_health_size,
			"visible": visible and _rect_intersects_viewport(rect),
			"style": "player_health",
		})
	return states


func _get_actor_screen_position(actor: Node3D, world_offset: Vector3, pixel_offset: Vector2) -> Vector2:
	var camera := get_viewport().get_camera_3d()
	if actor == null or camera == null:
		return Vector2(-1000.0, -1000.0)
	var world_position := actor.global_position + world_offset
	if camera.is_position_behind(world_position):
		return Vector2(-1000.0, -1000.0)
	return camera.unproject_position(world_position) + pixel_offset


func _rect_intersects_viewport(rect: Rect2) -> bool:
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size
	return rect.end.x >= 0.0 and rect.position.x <= viewport_size.x and rect.end.y >= 0.0 and rect.position.y <= viewport_size.y


func _hud_scene_root() -> Node:
	if not is_inside_tree():
		return null
	var root_node := get_tree().root
	var current: Node = self
	while current.get_parent() != null and current.get_parent() != root_node:
		current = current.get_parent()
	return current


func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var current := node
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false


func _node_float(node: Object, property_name: StringName, fallback: float) -> float:
	if node == null:
		return fallback
	var value: Variant = node.get(property_name)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	return fallback


func _is_reload_visible() -> bool:
	return bool(reload_state.get("active", false))


func _is_item_use_visible() -> bool:
	return bool(item_use_state.get("active", false))


func _is_melee_slash_visible() -> bool:
	return melee_slash_time > 0.0


func _melee_slash_alpha() -> float:
	if melee_slash_duration <= 0.0:
		return 0.0
	return clampf(melee_slash_time / melee_slash_duration, 0.0, 1.0)


func _has_equipped_weapon() -> bool:
	return weapon_controller != null and weapon_controller.get("weapon_def") != null


func _ammo_display_text() -> String:
	var held_mode := str(_held_weapon_state().get("mode", "firearm"))
	if held_mode == "melee" or held_mode == "item":
		return _held_weapon_display_text()
	if not _has_equipped_weapon():
		return _hud_text(&"ui.raid_hud.weapon_missing", "未裝備")
	return "%d %s / %d" % [
		_weapon_int("current_ammo", 0),
		_hud_text(&"ui.player_hud.loaded_bullets", "發子彈"),
		_backpack_compatible_ammo_count(),
	]


func _weapon_int(property_name: StringName, fallback: int) -> int:
	if weapon_controller == null:
		return fallback
	var value: Variant = weapon_controller.get(property_name)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return fallback


func _backpack_compatible_ammo_count() -> int:
	if _is_reload_visible():
		return _cached_backpack_ammo_count
	if not _backpack_ammo_cache_dirty:
		return _cached_backpack_ammo_count
	return _refresh_backpack_ammo_cache()


func _refresh_backpack_ammo_cache() -> int:
	if player == null or not player.has_method("get_compatible_backpack_ammo_count"):
		_cached_backpack_ammo_count = 0
	else:
		_cached_backpack_ammo_count = int(player.call("get_compatible_backpack_ammo_count"))
	_backpack_ammo_cache_dirty = false
	return _cached_backpack_ammo_count


func _held_weapon_state() -> Dictionary:
	if player == null or not player.has_method("get_held_weapon_state"):
		return {"mode": "firearm", "has_item": false}
	return player.call("get_held_weapon_state")


func _is_holding_melee_weapon() -> bool:
	return str(_held_weapon_state().get("mode", "firearm")) == "melee"


func _held_weapon_display_text() -> String:
	var state := _held_weapon_state()
	if not bool(state.get("has_item", false)):
		return _hud_text(&"ui.raid_hud.weapon_missing", "未裝備")
	var name_key := StringName(str(state.get("name_key", "")))
	var translated := _hud_text(name_key, "")
	if translated != "":
		return translated
	return str(state.get("display_name", state.get("item_id", "")))


func _held_weapon_panel_label() -> String:
	var held_mode := str(_held_weapon_state().get("mode", "firearm"))
	if held_mode == "item":
		return _hud_text(&"ui.inventory.use", "使用")
	if held_mode == "melee":
		return _hud_text(&"ui.equipment.melee", "近戰")
	var state := _held_weapon_state()
	if bool(state.get("has_item", false)):
		return _held_weapon_display_text()
	return _hud_text(&"ui.raid_hud.ammo", "彈藥")


func _quick_bar_slots() -> Array[Dictionary]:
	if player == null or not player.has_method("get_quick_bar_state"):
		return []
	var slots_variant: Variant = player.call("get_quick_bar_state")
	if typeof(slots_variant) != TYPE_ARRAY:
		return []
	var slots: Array[Dictionary] = []
	for raw_slot in slots_variant as Array:
		if typeof(raw_slot) == TYPE_DICTIONARY:
			slots.append(raw_slot as Dictionary)
	return slots


func _player_float(property_name: StringName, fallback: float) -> float:
	if player == null:
		return fallback
	var value: Variant = player.get(property_name)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	return fallback


func _player_max_health() -> float:
	if player == null:
		return 0.0
	if player.has_method("get_total_max_health"):
		return float(player.call("get_total_max_health"))
	return _player_float(&"max_health", 0.0)


func _health_display_text() -> String:
	var current := _player_float(&"health", 0.0)
	var maximum := _player_max_health()
	return "%d / %d" % [roundi(current), roundi(maximum)]


func _item_use_display_text() -> String:
	var item_name := _hud_text(StringName(str(item_use_state.get("name_key", ""))), "")
	var format_text := _hud_text(&"ui.item_use.using_format", "")
	return item_name if format_text == "" else format_text % item_name


func _damage_feedback_alpha() -> float:
	if damage_feedback_duration <= 0.0:
		return 0.0
	return clampf(damage_feedback_time / damage_feedback_duration, 0.0, 1.0)


func _hud_text(key: StringName, fallback: String) -> String:
	var translated := tr(str(key))
	return translated if translated != str(key) and translated != "" else fallback
