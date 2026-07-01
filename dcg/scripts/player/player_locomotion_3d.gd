class_name PlayerLocomotion3D
extends RefCounted

var owner
var stats: PlayerStats3D

var roll_time_left: float = 0.0
var roll_direction: Vector3 = Vector3.FORWARD


func _init(source_owner, source_stats: PlayerStats3D) -> void:
	owner = source_owner
	stats = source_stats


func physics_update(delta: float, input_reader: PlayerInputReader3D) -> bool:
	var input_blocked: bool = input_reader.is_gameplay_blocked()
	var input_direction: Vector2 = input_reader.movement_vector()
	var world_direction: Vector3 = Vector3(input_direction.x, 0.0, input_direction.y).normalized()

	if roll_time_left > 0.0:
		_update_roll(delta)
	else:
		_update_movement(world_direction, delta, input_reader)
		if not input_blocked:
			_try_start_roll(world_direction, input_reader)

	return input_blocked


func _update_movement(world_direction: Vector3, delta: float, input_reader: PlayerInputReader3D) -> void:
	_update_exhaustion()
	var is_sprinting: bool = input_reader.wants_sprint() and world_direction != Vector3.ZERO and float(owner.stamina) > 0.0 and not bool(owner.is_exhausted)
	var current_speed: float = stats.exhausted_speed() if bool(owner.is_exhausted) else stats.walk_speed()
	if is_sprinting:
		current_speed = stats.sprint_speed()

	current_speed *= stats.weight_speed_multiplier(owner.current_carry_weight)
	owner.velocity.x = world_direction.x * current_speed
	owner.velocity.z = world_direction.z * current_speed
	owner.velocity.y = 0.0

	if world_direction != Vector3.ZERO:
		roll_direction = world_direction

	if is_sprinting:
		owner.stamina = maxf(owner.stamina - stats.sprint_stamina_cost() * delta, 0.0)
		if owner.stamina <= 0.0:
			owner.is_exhausted = true
	else:
		_recover_stamina(delta)


func _try_start_roll(world_direction: Vector3, input_reader: PlayerInputReader3D) -> void:
	if not input_reader.wants_dodge():
		return
	if float(owner.stamina) < stats.roll_stamina_cost():
		return
	if bool(owner.is_exhausted):
		return

	var direction: Vector3 = world_direction
	if direction == Vector3.ZERO:
		direction = roll_direction

	owner.stamina -= stats.roll_stamina_cost()
	roll_time_left = stats.roll_duration()
	roll_direction = direction
	owner.velocity = roll_direction * stats.roll_speed()


func _update_roll(delta: float) -> void:
	roll_time_left = maxf(roll_time_left - delta, 0.0)
	owner.velocity = roll_direction * stats.roll_speed()


func _recover_stamina(delta: float) -> void:
	owner.stamina = minf(owner.stamina + stats.stamina_recovery_rate() * delta, stats.max_stamina())
	_update_exhaustion()


func _update_exhaustion() -> void:
	if owner.stamina <= 0.0:
		owner.is_exhausted = true
	elif owner.is_exhausted and owner.stamina >= stats.exhausted_recovery_threshold():
		owner.is_exhausted = false
