class_name UIText
extends RefCounted


static func text(owner: Object, key: StringName, fallback: String) -> String:
	var key_text := str(key)
	var translated := owner.tr(key_text) if owner != null and owner.has_method("tr") else key_text
	if translated == key_text or _looks_corrupt(translated):
		return fallback
	return translated


static func item_name(owner: Object, item_path: String, fallback: String = "Unknown item") -> String:
	if item_path == "" or not ResourceLoader.exists(item_path):
		return text(owner, &"item.unknown.name", fallback)
	var item_def := load(item_path) as ItemDef
	if item_def == null:
		return text(owner, &"item.unknown.name", fallback)
	var name_key := str(item_def.name_key)
	if name_key != "":
		var translated := text(owner, StringName(name_key), "")
		if translated != "":
			return translated
	return item_def.display_name if item_def.display_name != "" else str(item_def.id)


static func looks_corrupt(value: String) -> bool:
	return _looks_corrupt(value)


static func _looks_corrupt(value: String) -> bool:
	if value == "":
		return false
	if value.contains("\uFFFD"):
		return true
	for codepoint in value.to_utf32_buffer():
		if codepoint >= 0xE000 and codepoint <= 0xF8FF:
			return true
	var suspicious := 0
	for marker in ["", "", "", "", "", "", "", "", "蝚", "隞", "銝", "摰", "撱", "嚗"]:
		if value.contains(marker):
			suspicious += 1
	return suspicious >= 1
