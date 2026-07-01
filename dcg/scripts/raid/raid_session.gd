class_name RaidSession
extends Node

const RaidResultSchema := preload("res://scripts/raid/raid_result.gd")

signal raid_started(state: Dictionary)
signal raid_state_changed(state: Dictionary)
signal raid_completed(result: Dictionary)

const OUTCOME_IDLE := RaidResultSchema.OUTCOME_IDLE
const OUTCOME_ACTIVE := RaidResultSchema.OUTCOME_ACTIVE
const OUTCOME_EXTRACTED := RaidResultSchema.OUTCOME_EXTRACTED
const OUTCOME_DEAD := RaidResultSchema.OUTCOME_DEAD

@export var auto_begin := true
@export var map_id := "refuge_outskirts"

var active := false
var extracted := false
var dead := false
var elapsed_time := 0.0
var started_at_unix := 0
var completed_at_unix := 0

var _outcome := OUTCOME_IDLE
var _result_context: Dictionary = {}


func _ready() -> void:
	if auto_begin:
		begin_raid(map_id)


func _process(delta: float) -> void:
	if active:
		elapsed_time += delta


func begin_raid(new_map_id: String = "") -> void:
	map_id = new_map_id if new_map_id != "" else map_id
	active = true
	extracted = false
	dead = false
	elapsed_time = 0.0
	started_at_unix = int(Time.get_unix_time_from_system())
	completed_at_unix = 0
	_outcome = OUTCOME_ACTIVE
	_result_context.clear()
	raid_started.emit(get_state())
	raid_state_changed.emit(get_state())


func register_extraction(context: Dictionary = {}) -> bool:
	if not active or dead:
		return false
	active = false
	extracted = true
	dead = false
	completed_at_unix = int(Time.get_unix_time_from_system())
	_outcome = OUTCOME_EXTRACTED
	_result_context = context.duplicate(true)
	var result := build_result()
	raid_state_changed.emit(get_state())
	raid_completed.emit(result)
	return true


func register_player_death(context: Dictionary = {}) -> bool:
	if not active or extracted:
		return false
	active = false
	extracted = false
	dead = true
	completed_at_unix = int(Time.get_unix_time_from_system())
	_outcome = OUTCOME_DEAD
	_result_context = context.duplicate(true)
	var result := build_result()
	raid_state_changed.emit(get_state())
	raid_completed.emit(result)
	return true


func is_finished() -> bool:
	return extracted or dead


func get_state() -> Dictionary:
	return {
		"active": active,
		"extracted": extracted,
		"dead": dead,
		"elapsed_time": elapsed_time,
		"outcome": _outcome,
		"map_id": map_id,
		"started_at_unix": started_at_unix,
		"completed_at_unix": completed_at_unix,
	}


func build_result() -> Dictionary:
	var result := RaidResultSchema.create(_outcome, _result_context)
	return RaidResultSchema.with_session_data(result, {
		"active": active,
		"extracted": extracted,
		"dead": dead,
		"elapsed_time": elapsed_time,
		"duration": elapsed_time,
		"map_id": map_id,
		"started_at_unix": started_at_unix,
		"completed_at_unix": completed_at_unix,
	})
