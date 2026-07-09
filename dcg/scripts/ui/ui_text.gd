class_name UIText
extends RefCounted


static func text(owner: Object, key: StringName, fallback: String) -> String:
	var key_text := str(key)
	var translated := owner.tr(key_text) if owner != null and owner.has_method("tr") else key_text
	if translated == key_text or _looks_corrupt(translated) or _prefer_zh_fallback(translated, fallback):
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
			if _prefer_zh_resource_name(translated, item_def.display_name):
				return item_def.display_name
			return translated
	return item_def.display_name if item_def.display_name != "" else str(item_def.id)


static func looks_corrupt(value: String) -> bool:
	return _looks_corrupt(value)


static func _prefer_zh_fallback(translated: String, fallback: String) -> bool:
	if not _is_zh_locale():
		return false
	if fallback == "" or not _contains_cjk(fallback):
		return false
	return _has_ascii_word(translated) and not _contains_cjk(translated)


static func _prefer_zh_resource_name(translated: String, resource_name: String) -> bool:
	if not _is_zh_locale():
		return false
	if resource_name == "" or not _contains_cjk(resource_name):
		return false
	return _has_ascii_word(translated) and not _contains_cjk(translated)


static func _is_zh_locale() -> bool:
	return TranslationServer.get_locale().begins_with("zh")


static func _contains_cjk(value: String) -> bool:
	for codepoint in value.to_utf32_buffer():
		if (codepoint >= 0x3400 and codepoint <= 0x9FFF) or (codepoint >= 0xF900 and codepoint <= 0xFAFF):
			return true
	return false


static func _has_ascii_word(value: String) -> bool:
	var run_length := 0
	for codepoint in value.to_utf32_buffer():
		var is_ascii_letter := (codepoint >= 65 and codepoint <= 90) or (codepoint >= 97 and codepoint <= 122)
		if is_ascii_letter:
			run_length += 1
			if run_length >= 3:
				return true
		else:
			run_length = 0
	return false


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
