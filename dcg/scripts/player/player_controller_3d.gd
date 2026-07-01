extends CharacterBody3D

const DEFAULT_STARTER_LOADOUT := preload("res://data/inventory/starter_inventory.tres")
const PlayerStatsProfileScript := preload("res://scripts/player/player_stats_profile.gd")
const PlayerStatsScript := preload("res://scripts/player/player_stats_3d.gd")
const PlayerInputReaderScript := preload("res://scripts/player/player_input_reader_3d.gd")
const PlayerLocomotionScript := preload("res://scripts/player/player_locomotion_3d.gd")

signal stamina_changed(current: float, maximum: float)
signal inventory_changed

var max_health: float:
	get:
		return _stats.max_health()

var walk_speed: float:
	get:
		return _stats.walk_speed()

var sprint_speed: float:
	get:
		return _stats.sprint_speed()

var max_stamina: float:
	get:
		return _stats.max_stamina()

var roll_distance: float:
	get:
		return _stats.roll_distance()

var roll_speed: float:
	get:
		return _stats.roll_speed()

var backpack_slots: int:
	get:
		return _stats.backpack_slots()

var carry_weight_limit: float:
	get:
		return _stats.carry_weight_limit()

var safe_pocket_slots: int:
	get:
		return _stats.safe_pocket_slots()

var defense: float:
	get:
		return _stats.defense()

var health: float = 0.0
var stamina: float = 0.0
var current_carry_weight: float = 0.0
var is_exhausted: bool = false

@export var stats_profile: PlayerStatsProfile = PlayerStatsProfileScript.new()
@export var starter_loadout: Resource = DEFAULT_STARTER_LOADOUT

var inventory_model := InventoryModel.new()

var _stats: PlayerStats3D
var _input_reader := PlayerInputReaderScript.new(self)
var _locomotion: PlayerLocomotion3D
var _weapon_controller: Node = null


func _ready() -> void:
	var runtime_stats_profile := stats_profile.duplicate(true) as PlayerStatsProfile
	var difficulty_manager := get_node_or_null("/root/DifficultyManager")
	if difficulty_manager != null and difficulty_manager.has_method("apply_to_player_stats"):
		difficulty_manager.apply_to_player_stats(runtime_stats_profile)
	_stats = PlayerStatsScript.new(runtime_stats_profile)
	_locomotion = PlayerLocomotionScript.new(self, _stats)
	_weapon_controller = get_node_or_null("WeaponController3D")
	inventory_model.setup(backpack_slots)
	inventory_model.changed.connect(_on_inventory_changed)
	_load_starter_inventory()
	health = get_total_max_health()
	stamina = max_stamina
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	stamina_changed.emit(stamina, max_stamina)


func _unhandled_input(event: InputEvent) -> void:
	if _input_reader.is_gameplay_blocked():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_fire_equipped_weapon()


func get_total_max_health() -> float:
	return max_health


func get_total_backpack_slots() -> int:
	return backpack_slots


func get_total_carry_weight_limit() -> float:
	return carry_weight_limit


func get_total_safe_pocket_slots() -> int:
	return safe_pocket_slots


func get_total_defense() -> float:
	return defense


func set_current_carry_weight(value: float) -> void:
	current_carry_weight = maxf(value, 0.0)


func get_weight_speed_multiplier() -> float:
	return _stats.weight_speed_multiplier(current_carry_weight)


func get_inventory_model() -> InventoryModel:
	return inventory_model


func add_item_resource(item_def: ItemDef, quantity: int = 1) -> bool:
	return inventory_model.add_item(item_def, quantity)


func _physics_process(delta: float) -> void:
	var input_blocked := _locomotion.physics_update(delta, _input_reader)

	move_and_slide()
	if not input_blocked:
		_face_mouse_on_ground()
	stamina_changed.emit(stamina, max_stamina)


func _face_mouse_on_ground() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	if absf(ray_direction.y) < 0.001:
		return

	var distance := -ray_origin.y / ray_direction.y
	if distance < 0.0:
		return

	var look_position := ray_origin + ray_direction * distance
	look_position.y = global_position.y
	if global_position.distance_to(look_position) > 0.1:
		look_at(look_position, Vector3.UP)


func _fire_equipped_weapon() -> void:
	if _weapon_controller == null or not _weapon_controller.has_method("fire_forward"):
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	_weapon_controller.fire_forward(ray_origin, ray_direction, get_world_3d().direct_space_state)


func _load_starter_inventory() -> void:
	if inventory_model.get_used_slots() > 0:
		return
	if starter_loadout != null and starter_loadout.has_method("add_to_inventory"):
		starter_loadout.add_to_inventory(inventory_model)


func _on_inventory_changed() -> void:
	current_carry_weight = inventory_model.get_total_weight()
	inventory_changed.emit()
