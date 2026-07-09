class_name RaidResult
extends RefCounted

const OUTCOME_IDLE := "idle"
const OUTCOME_ACTIVE := "active"
const OUTCOME_EXTRACTED := "extracted"
const OUTCOME_DEAD := "dead"

const KEY_OUTCOME := "outcome"
const KEY_EXTRACTED_ITEMS := "extracted_items"
const KEY_EXTRACTED_EQUIPMENT := "extracted_equipment"
const KEY_LOST_ITEMS := "lost_items"
const KEY_KEPT_SAFE_POCKET_ITEMS := "kept_safe_pocket_items"
const KEY_MONEY_DELTA := "money_delta"
const KEY_DURATION := "duration"


static func create(outcome: String, context: Dictionary = {}) -> Dictionary:
	var result := {
		KEY_OUTCOME: outcome,
		KEY_EXTRACTED_ITEMS: _duplicate_array(context.get(KEY_EXTRACTED_ITEMS, [])),
		KEY_EXTRACTED_EQUIPMENT: _duplicate_dictionary(context.get(KEY_EXTRACTED_EQUIPMENT, {})),
		KEY_LOST_ITEMS: _duplicate_array(context.get(KEY_LOST_ITEMS, [])),
		KEY_KEPT_SAFE_POCKET_ITEMS: _duplicate_array(context.get(KEY_KEPT_SAFE_POCKET_ITEMS, [])),
		KEY_MONEY_DELTA: int(context.get(KEY_MONEY_DELTA, 0)),
		KEY_DURATION: float(context.get(KEY_DURATION, 0.0)),
	}
	for key in context.keys():
		if not result.has(key):
			result[key] = _sanitize_value(context[key])
	return result


static func with_session_data(result: Dictionary, session_data: Dictionary) -> Dictionary:
	var merged := result.duplicate(true)
	for key in session_data.keys():
		if not merged.has(key):
			merged[key] = _sanitize_value(session_data[key])
	merged[KEY_DURATION] = float(session_data.get(KEY_DURATION, merged.get(KEY_DURATION, 0.0)))
	return merged


static func validate(result: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not result.has(KEY_OUTCOME) or str(result[KEY_OUTCOME]) == "":
		errors.append("Raid result requires outcome.")
	if typeof(result.get(KEY_EXTRACTED_ITEMS, null)) != TYPE_ARRAY:
		errors.append("Raid result requires extracted_items array.")
	if typeof(result.get(KEY_EXTRACTED_EQUIPMENT, null)) != TYPE_DICTIONARY:
		errors.append("Raid result requires extracted_equipment dictionary.")
	if typeof(result.get(KEY_LOST_ITEMS, null)) != TYPE_ARRAY:
		errors.append("Raid result requires lost_items array.")
	if typeof(result.get(KEY_KEPT_SAFE_POCKET_ITEMS, null)) != TYPE_ARRAY:
		errors.append("Raid result requires kept_safe_pocket_items array.")
	if typeof(result.get(KEY_MONEY_DELTA, null)) != TYPE_INT:
		errors.append("Raid result requires integer money_delta.")
	if not typeof(result.get(KEY_DURATION, null)) in [TYPE_FLOAT, TYPE_INT]:
		errors.append("Raid result requires numeric duration.")
	if _contains_object(result):
		errors.append("Raid result must not contain Object or Node references.")
	return errors


static func is_serializable(result: Dictionary) -> bool:
	return validate(result).is_empty()


static func _duplicate_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return _sanitize_value(value) as Array


static func _duplicate_dictionary(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return _sanitize_value(value) as Dictionary


static func _sanitize_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var sanitized_dict := {}
			for key in value.keys():
				sanitized_dict[key] = _sanitize_value(value[key])
			return sanitized_dict
		TYPE_ARRAY:
			var sanitized_array := []
			for entry in value:
				sanitized_array.append(_sanitize_value(entry))
			return sanitized_array
		TYPE_OBJECT:
			return str(value)
		_:
			return value


static func _contains_object(value: Variant) -> bool:
	match typeof(value):
		TYPE_OBJECT:
			return true
		TYPE_DICTIONARY:
			for key in value.keys():
				if _contains_object(key) or _contains_object(value[key]):
					return true
		TYPE_ARRAY:
			for entry in value:
				if _contains_object(entry):
					return true
	return false
