class_name PlayerTimedActionController3D
extends RefCounted

const ItemConsumableServiceScript := preload("res://scripts/items/item_consumable_service.gd")
const DEFAULT_RELOAD_DURATION_SECONDS := 0.8
const RELOAD_PROGRESS_EMIT_STEP := 0.05
const ITEM_USE_PROGRESS_EMIT_STEP := 0.05

signal reload_feedback_changed(result: Dictionary)
signal reload_progress_changed(state: Dictionary)
signal item_use_progress_changed(state: Dictionary)

var _owner: Node
var _inventory_model: InventoryModel
var _equipment: RefCounted
var _weapon_controller: Node

var _is_reloading := false
var _active_reload_duration_seconds := 0.0
var _pending_reload: Dictionary = {}
var _reload_timer: Timer
var _last_reload_result := {
	"reloaded": false,
	"blocked_reason": "",
	"rounds_loaded": 0,
	"current_ammo": 0,
	"reserve_ammo": 0,
	"backpack_ammo_remaining": 0,
	"source": "",
}
var _last_reload_state := {
	"active": false,
	"progress": 0.0,
	"remaining_time": 0.0,
	"source": "",
	"status": "idle",
}
var _last_reload_emit_active := false
var _last_reload_emit_progress := -1.0
var _last_reload_emit_source := ""
var _last_reload_emit_status := ""

var _is_using_item := false
var _active_item_use_duration_seconds := 0.0
var _pending_item_use: Dictionary = {}
var _item_use_timer: Timer
var _last_item_use_emit_active := false
var _last_item_use_emit_progress := -1.0
var _last_item_use_emit_status := ""
var _last_item_use_emit_item_id := ""
var _last_item_use_state := {
	"active": false,
	"progress": 0.0,
	"remaining_time": 0.0,
	"stack_index": -1,
	"item_id": "",
	"name_key": "",
	"status": "idle",
}


func setup(owner: Node, inventory_model: InventoryModel, equipment: RefCounted, weapon_controller: Node) -> void:
	_owner = owner
	_inventory_model = inventory_model
	_equipment = equipment
	_weapon_controller = weapon_controller


func is_reloading() -> bool:
	return _is_reloading


func is_using_item() -> bool:
	return _is_using_item


func is_active() -> bool:
	return _is_reloading or _is_using_item


func get_last_reload_result() -> Dictionary:
	return _last_reload_result.duplicate(true)


func get_reload_state() -> Dictionary:
	return _last_reload_state.duplicate(true)


func get_item_use_state() -> Dictionary:
	return _last_item_use_state.duplicate(true)


func can_use_inventory_stack(stack_index: int) -> bool:
	if _is_using_item or _is_reloading or _owner == null or bool(_owner.get("is_dead")):
		return false
	if stack_index < 0 or stack_index >= _inventory_model.stacks.size():
		return false
	var stack := _inventory_model.stacks[stack_index] as Dictionary
	var item_def := _owner.call("_load_item_from_stack", stack) as ItemDef
	return ItemConsumableServiceScript.can_start_use(
		stack,
		float(_owner.get("health")),
		float(_owner.call("get_total_max_health")),
		float(_owner.get("stamina")),
		float(_owner.get("max_stamina")),
		item_def
	)


func use_inventory_stack(stack_index: int) -> bool:
	if not can_use_inventory_stack(stack_index):
		return false
	var stack := _inventory_model.stacks[stack_index] as Dictionary
	var item_def := _owner.call("_load_item_from_stack", stack) as ItemDef
	_is_using_item = true
	_active_item_use_duration_seconds = ItemConsumableServiceScript.use_duration_seconds(stack, item_def)
	var now_msec := Time.get_ticks_msec()
	_pending_item_use = {
		"stack_index": stack_index,
		"item_id": str(stack.get("id", "")),
		"name_key": str(stack.get("name_key", "")),
		"heal_amount": ItemConsumableServiceScript.healing_amount(stack, item_def),
		"stamina_amount": ItemConsumableServiceScript.stamina_restore_amount(stack, item_def),
		"started_at_msec": now_msec,
		"ends_at_msec": now_msec + int(round(_active_item_use_duration_seconds * 1000.0)),
	}
	_emit_item_use_state(true, 0.0, &"using")
	_start_item_use_timer(_active_item_use_duration_seconds)
	return true


func reload_equipped_weapon(reload_source: StringName = &"manual") -> bool:
	if _is_using_item:
		_record_reload_feedback(false, &"using_item", 0, reload_source)
		return false
	if _is_reloading:
		_record_reload_feedback(false, &"reloading", 0, reload_source)
		return false
	if _weapon_controller == null or not _weapon_controller.has_method("reload_from_item"):
		_record_reload_feedback(false, &"no_weapon", 0, reload_source)
		_emit_reload_state(false, 0.0, reload_source, &"blocked")
		return false
	if not _weapon_controller.has_method("has_weapon") or not bool(_weapon_controller.call("has_weapon")):
		_owner.call("_sync_weapon_from_equipment")
	if not _weapon_controller.has_method("has_weapon") or not bool(_weapon_controller.call("has_weapon")):
		_record_reload_feedback(false, &"no_weapon", 0, reload_source)
		_emit_reload_state(false, 0.0, reload_source, &"blocked")
		return false

	var needed_rounds := int(_weapon_controller.get("magazine_size")) - int(_weapon_controller.get("current_ammo"))
	if needed_rounds <= 0:
		_record_reload_feedback(false, &"magazine_full", 0, reload_source)
		_emit_reload_state(false, 1.0, reload_source, &"blocked")
		return false
	var ammo_stack := _find_compatible_ammo_stack()
	if ammo_stack.is_empty():
		_record_reload_feedback(false, &"no_compatible_ammo", 0, reload_source)
		_emit_reload_state(false, 0.0, reload_source, &"blocked")
		return false
	_start_reload(
		reload_source,
		int(ammo_stack.get("index", -1)),
		ammo_stack.get("item_def") as ItemDef,
		mini(needed_rounds, int(ammo_stack.get("quantity", 0)))
	)
	return true


func unload_equipped_weapon_ammo_to_backpack() -> Dictionary:
	if _is_using_item:
		return _weapon_unload_result(false, &"using_item", null, 0)
	if _is_reloading:
		return _weapon_unload_result(false, &"reloading", null, 0)
	if _weapon_controller == null or not _weapon_controller.has_method("unload_loaded_ammo"):
		return _weapon_unload_result(false, &"no_weapon", null, 0)
	if not _weapon_controller.has_method("has_weapon") or not bool(_weapon_controller.call("has_weapon")):
		_owner.call("_sync_weapon_from_equipment")
	if not _weapon_controller.has_method("has_weapon") or not bool(_weapon_controller.call("has_weapon")):
		return _weapon_unload_result(false, &"no_weapon", null, 0)

	var ammo_model: Variant = _weapon_controller.call("get_ammo_model") if _weapon_controller.has_method("get_ammo_model") else null
	var ammo_item: ItemDef = ammo_model.get("ammo_def") as ItemDef if ammo_model != null else null
	var loaded_rounds := int(_weapon_controller.get("current_ammo"))
	var previous_reserve := int(_weapon_controller.get("reserve_ammo"))
	if ammo_item == null or loaded_rounds <= 0:
		return _weapon_unload_result(false, &"no_loaded_ammo", ammo_item, 0)
	if not _inventory_model.can_accept_stack(ammo_item.to_stack(loaded_rounds)):
		return _weapon_unload_result(false, &"backpack_full", ammo_item, loaded_rounds)
	var result: Dictionary = _weapon_controller.call("unload_loaded_ammo")
	if not bool(result.get("success", false)):
		return result
	var unloaded_count := int(result.get("quantity", 0))
	if unloaded_count <= 0:
		return _weapon_unload_result(false, &"no_loaded_ammo", ammo_item, 0)
	if not _inventory_model.add_item(ammo_item, unloaded_count):
		if _weapon_controller.has_method("restore_ammo_state"):
			_weapon_controller.call("restore_ammo_state", ammo_item, unloaded_count, previous_reserve)
		return _weapon_unload_result(false, &"backpack_full", ammo_item, unloaded_count)
	_equipment.call("save_synced_weapon_ammo_state", false)
	_owner.set("current_carry_weight", float(_owner.call("_get_carried_weight")))
	_owner.emit_signal("inventory_changed")
	return result


func cancel_all(reason: StringName = &"cancelled") -> void:
	if _is_reloading:
		_cancel_reload(reason)
	if _is_using_item:
		_cancel_item_use(reason)


func _complete_reload() -> bool:
	if _pending_reload.is_empty() or _weapon_controller == null:
		_cancel_reload(&"cancelled")
		return false
	var reload_source := StringName(str(_pending_reload.get("source", "manual")))
	var ammo_index := int(_pending_reload.get("ammo_index", -1))
	var ammo_def := _pending_reload.get("ammo_def") as ItemDef
	var quantity_to_load := int(_pending_reload.get("quantity_to_load", 0))
	var loaded_rounds := int(_weapon_controller.call("reload_from_item", ammo_def, quantity_to_load))
	if loaded_rounds <= 0:
		var weapon_result: Dictionary = _weapon_controller.get("last_reload_result")
		var reason := StringName(str(weapon_result.get("blocked_reason", "no_ammo")))
		_record_reload_feedback(false, reason, 0, reload_source)
		_cancel_reload(reason)
		return false
	_inventory_model.consume_stack_quantity(ammo_index, loaded_rounds)
	_equipment.call("save_synced_weapon_ammo_state", false)
	_record_reload_feedback(true, &"", loaded_rounds, reload_source)
	_finish_reload(reload_source)
	return true


func _complete_item_use() -> bool:
	if _owner == null or bool(_owner.get("is_dead")) or _pending_item_use.is_empty():
		_cancel_item_use(&"cancelled")
		return false
	var stack_index := int(_pending_item_use.get("stack_index", -1))
	if stack_index < 0 or stack_index >= _inventory_model.stacks.size():
		_cancel_item_use(&"missing_item")
		return false
	var stack := _inventory_model.stacks[stack_index] as Dictionary
	if str(stack.get("id", "")) != str(_pending_item_use.get("item_id", "")):
		_cancel_item_use(&"missing_item")
		return false
	if _inventory_model.consume_stack_quantity(stack_index, 1) <= 0:
		_cancel_item_use(&"missing_item")
		return false
	var health_gain := maxf(float(_pending_item_use.get("heal_amount", 0.0)), 0.0)
	var stamina_gain := maxf(float(_pending_item_use.get("stamina_amount", 0.0)), 0.0)
	if health_gain <= 0.0 and stamina_gain <= 0.0:
		_cancel_item_use(&"no_effect")
		return false
	var maximum_health := float(_owner.call("get_total_max_health"))
	var maximum_stamina := float(_owner.get("max_stamina"))
	if health_gain > 0.0:
		var next_health := minf(float(_owner.get("health")) + health_gain, maximum_health)
		_owner.set("health", next_health)
		_owner.emit_signal("health_changed", next_health, maximum_health)
	if stamina_gain > 0.0:
		var next_stamina := minf(float(_owner.get("stamina")) + stamina_gain, maximum_stamina)
		_owner.set("stamina", next_stamina)
		_owner.emit_signal("stamina_changed", next_stamina, maximum_stamina)
	_finish_item_use(&"complete")
	return true


func _find_compatible_ammo_stack() -> Dictionary:
	if _weapon_controller == null or not _weapon_controller.has_method("get_ammo_model"):
		return {}
	var ammo_model: Variant = _weapon_controller.call("get_ammo_model")
	if ammo_model == null:
		return {}
	for index in range(_inventory_model.stacks.size()):
		var stack := _inventory_model.stacks[index] as Dictionary
		if int(stack.get("quantity", 0)) <= 0 or not _is_stack_compatible_ammo(stack, ammo_model):
			continue
		var item_def := _owner.call("_load_item_from_stack", stack) as ItemDef
		if item_def != null and item_def.item_type == "ammo":
			return {"index": index, "item_def": item_def, "quantity": int(stack.get("quantity", 1))}
	return {}


func _is_stack_compatible_ammo(stack: Dictionary, ammo_model: Variant) -> bool:
	if ammo_model == null:
		return false
	var stack_type := str(stack.get("type", ""))
	if stack_type != "" and stack_type != "ammo":
		return false
	var ammo_tag := StringName(str(stack.get("ammo_tag", "")))
	if ammo_tag != &"" and _ammo_model_accepts_tag(ammo_model, ammo_tag):
		return true
	for raw_tag in stack.get("tags", []) as Array:
		var tag := StringName(str(raw_tag))
		if tag != &"" and _ammo_model_accepts_tag(ammo_model, tag):
			return true
	if not ammo_model.has_method("can_use_ammo"):
		return false
	var item_def := _owner.call("_load_item_from_stack", stack) as ItemDef
	return item_def != null and bool(ammo_model.call("can_use_ammo", item_def))


func _ammo_model_accepts_tag(ammo_model: Variant, ammo_tag: StringName) -> bool:
	if ammo_model == null or ammo_tag == &"":
		return false
	var compatible_tags_variant: Variant = ammo_model.get("compatible_ammo_tags")
	if typeof(compatible_tags_variant) != TYPE_ARRAY:
		return false
	for raw_tag in compatible_tags_variant as Array:
		if StringName(str(raw_tag)) == ammo_tag:
			return true
	return false


func _start_reload(reload_source: StringName, ammo_index: int, ammo_def: ItemDef, quantity_to_load: int) -> void:
	_is_reloading = true
	_active_reload_duration_seconds = _current_weapon_reload_duration_seconds()
	var now_msec := Time.get_ticks_msec()
	_pending_reload = {
		"source": str(reload_source),
		"ammo_index": ammo_index,
		"ammo_def": ammo_def,
		"quantity_to_load": quantity_to_load,
		"duration": _active_reload_duration_seconds,
		"started_at_msec": now_msec,
		"ends_at_msec": now_msec + int(round(_active_reload_duration_seconds * 1000.0)),
	}
	_emit_reload_state(true, 0.0, reload_source, &"reloading")
	_start_reload_timer(_active_reload_duration_seconds)


func _start_reload_timer(duration_seconds: float) -> void:
	_stop_reload_timer()
	_reload_timer = Timer.new()
	_reload_timer.one_shot = true
	_reload_timer.wait_time = maxf(duration_seconds, 0.05)
	_reload_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	_reload_timer.timeout.connect(_on_reload_timer_timeout)
	_owner.add_child(_reload_timer)
	_reload_timer.start()


func _stop_reload_timer() -> void:
	if _reload_timer == null:
		return
	if is_instance_valid(_reload_timer):
		_reload_timer.stop()
		_reload_timer.queue_free()
	_reload_timer = null


func _on_reload_timer_timeout() -> void:
	if _is_reloading:
		_complete_reload()


func _start_item_use_timer(duration_seconds: float) -> void:
	_stop_item_use_timer()
	_item_use_timer = Timer.new()
	_item_use_timer.one_shot = true
	_item_use_timer.wait_time = maxf(duration_seconds, 0.05)
	_item_use_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	_item_use_timer.timeout.connect(_on_item_use_timer_timeout)
	_owner.add_child(_item_use_timer)
	_item_use_timer.start()


func _stop_item_use_timer() -> void:
	if _item_use_timer == null:
		return
	if is_instance_valid(_item_use_timer):
		_item_use_timer.stop()
		_item_use_timer.queue_free()
	_item_use_timer = null


func _on_item_use_timer_timeout() -> void:
	if _is_using_item:
		_complete_item_use()


func _finish_item_use(status: StringName) -> void:
	_stop_item_use_timer()
	_is_using_item = false
	_active_item_use_duration_seconds = 0.0
	_emit_item_use_state(false, 1.0, status)
	_pending_item_use = {}


func _cancel_item_use(reason: StringName) -> void:
	_stop_item_use_timer()
	_is_using_item = false
	_active_item_use_duration_seconds = 0.0
	_emit_item_use_state(false, 0.0, reason)
	_pending_item_use = {}


func _finish_reload(reload_source: StringName) -> void:
	_stop_reload_timer()
	_is_reloading = false
	_active_reload_duration_seconds = 0.0
	_pending_reload = {}
	_emit_reload_state(false, 1.0, reload_source, &"complete")


func _cancel_reload(reason: StringName) -> void:
	var source := StringName(str(_pending_reload.get("source", "manual"))) if not _pending_reload.is_empty() else &"manual"
	_stop_reload_timer()
	_is_reloading = false
	_active_reload_duration_seconds = 0.0
	_pending_reload = {}
	_emit_reload_state(false, 0.0, source, reason)


func _emit_item_use_state(active: bool, progress: float, status: StringName) -> void:
	var clamped_progress := clampf(progress, 0.0, 1.0)
	var status_text := str(status)
	var item_id_text := str(_pending_item_use.get("item_id", ""))
	var started_at_msec := int(_pending_item_use.get("started_at_msec", 0))
	var ends_at_msec := int(_pending_item_use.get("ends_at_msec", 0))
	_last_item_use_state = {
		"active": active,
		"progress": clamped_progress,
		"remaining_time": maxf(float(ends_at_msec - Time.get_ticks_msec()) / 1000.0, 0.0) if active and ends_at_msec > 0 else 0.0,
		"duration": _active_item_use_duration_seconds,
		"started_at_msec": started_at_msec,
		"ends_at_msec": ends_at_msec,
		"stack_index": int(_pending_item_use.get("stack_index", -1)),
		"item_id": item_id_text,
		"name_key": str(_pending_item_use.get("name_key", "")),
		"status": status_text,
	}
	if not _should_emit_item_use_state(active, clamped_progress, status_text, item_id_text):
		return
	_last_item_use_emit_active = active
	_last_item_use_emit_progress = clamped_progress
	_last_item_use_emit_status = status_text
	_last_item_use_emit_item_id = item_id_text
	item_use_progress_changed.emit(_last_item_use_state.duplicate(true))


func _should_emit_item_use_state(active: bool, progress: float, status_text: String, item_id_text: String) -> bool:
	if active != _last_item_use_emit_active or status_text != _last_item_use_emit_status or item_id_text != _last_item_use_emit_item_id:
		return true
	if not active or progress <= 0.0 or progress >= 1.0:
		return true
	return absf(progress - _last_item_use_emit_progress) >= ITEM_USE_PROGRESS_EMIT_STEP


func _emit_reload_state(active: bool, progress: float, reload_source: StringName, status: StringName) -> void:
	var duration := _active_reload_duration_seconds if _active_reload_duration_seconds > 0.0 else _current_weapon_reload_duration_seconds()
	var clamped_progress := clampf(progress, 0.0, 1.0)
	var source_text := str(reload_source)
	var status_text := str(status)
	var started_at_msec := int(_pending_reload.get("started_at_msec", 0))
	var ends_at_msec := int(_pending_reload.get("ends_at_msec", 0))
	_last_reload_state = {
		"active": active,
		"progress": clamped_progress,
		"remaining_time": maxf(float(ends_at_msec - Time.get_ticks_msec()) / 1000.0, 0.0) if active and ends_at_msec > 0 else 0.0,
		"duration": duration,
		"started_at_msec": started_at_msec,
		"ends_at_msec": ends_at_msec,
		"source": source_text,
		"status": status_text,
	}
	if not _should_emit_reload_state(active, clamped_progress, source_text, status_text):
		return
	_last_reload_emit_active = active
	_last_reload_emit_progress = clamped_progress
	_last_reload_emit_source = source_text
	_last_reload_emit_status = status_text
	reload_progress_changed.emit(_last_reload_state.duplicate(true))


func _should_emit_reload_state(active: bool, progress: float, source_text: String, status_text: String) -> bool:
	if active != _last_reload_emit_active or source_text != _last_reload_emit_source or status_text != _last_reload_emit_status:
		return true
	if not active or progress <= 0.0 or progress >= 1.0:
		return true
	return absf(progress - _last_reload_emit_progress) >= RELOAD_PROGRESS_EMIT_STEP


func _current_weapon_reload_duration_seconds() -> float:
	var configured_duration := float(_owner.get("reload_duration_seconds"))
	if not is_equal_approx(configured_duration, DEFAULT_RELOAD_DURATION_SECONDS):
		return maxf(configured_duration, 0.05)
	var weapon_item := _owner.call("_get_equipped_weapon_item") as ItemDef
	if weapon_item != null and weapon_item.reload_duration_seconds > 0.0:
		return maxf(weapon_item.reload_duration_seconds, 0.05)
	return maxf(configured_duration, 0.05)


func _record_reload_feedback(did_reload: bool, blocked_reason: StringName, rounds_loaded: int, reload_source: StringName = &"manual") -> void:
	_last_reload_result = {
		"reloaded": did_reload,
		"blocked_reason": str(blocked_reason),
		"rounds_loaded": rounds_loaded,
		"current_ammo": int(_weapon_controller.get("current_ammo")) if _weapon_controller != null else 0,
		"reserve_ammo": int(_weapon_controller.get("reserve_ammo")) if _weapon_controller != null else 0,
		"backpack_ammo_remaining": _count_compatible_backpack_ammo(),
		"source": str(reload_source),
	}
	reload_feedback_changed.emit(_last_reload_result.duplicate(true))


func _weapon_unload_result(success: bool, reason: StringName, ammo_item: ItemDef, quantity: int) -> Dictionary:
	return {
		"success": success,
		"reason": str(reason),
		"ammo_item": ammo_item,
		"quantity": quantity,
		"current_ammo": int(_weapon_controller.get("current_ammo")) if _weapon_controller != null else 0,
		"reserve_ammo": int(_weapon_controller.get("reserve_ammo")) if _weapon_controller != null else 0,
	}


func _count_compatible_backpack_ammo() -> int:
	if _weapon_controller == null or not _weapon_controller.has_method("get_ammo_model"):
		return 0
	var ammo_model: Variant = _weapon_controller.call("get_ammo_model")
	var total := 0
	for stack_value in _inventory_model.stacks:
		if typeof(stack_value) == TYPE_DICTIONARY and _is_stack_compatible_ammo(stack_value as Dictionary, ammo_model):
			total += int((stack_value as Dictionary).get("quantity", 0))
	return total
