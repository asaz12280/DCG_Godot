class_name ItemCodexSlot
extends Button

# // Reusable codex slot component for the future node-based codex UI. Current drawn UI can migrate slot by slot. //
signal slot_selected(catalog_number: int)

var catalog_number: int = 0
var item_def: ItemDef = null
var is_selected: bool = false


func setup(number: int, item: ItemDef) -> void:
	catalog_number = number
	item_def = item
	toggle_mode = false
	text = _build_label()
	tooltip_text = _build_tooltip()
	disabled = false


func clear_slot(number: int) -> void:
	catalog_number = number
	item_def = null
	toggle_mode = false
	text = "No.%d\n-" % catalog_number
	tooltip_text = ""
	disabled = false


func set_selected(value: bool) -> void:
	is_selected = value
	modulate = Color(1.0, 1.0, 1.0, 1.0) if not is_selected else Color(0.82, 1.0, 1.0, 1.0)


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	slot_selected.emit(catalog_number)


func _build_label() -> String:
	if item_def == null:
		return "No.%d\n-" % catalog_number
	return "No.%d\n%s" % [catalog_number, tr(str(item_def.name_key))]


func _build_tooltip() -> String:
	if item_def == null:
		return ""
	var stack_text := "" if item_def.max_stack <= 1 else "\n%s: %d" % [tr("ui.codex.max_stack"), item_def.max_stack]
	var damage_text := "" if not item_def.tags.has(&"gun") or item_def.damage <= 0 else "\n%s: %d" % [tr("ui.codex.damage"), item_def.damage]
	return "%s\n%s: %.2f kg\n%s: %d%s%s" % [
		tr(str(item_def.description_key)),
		tr("ui.codex.weight"),
		item_def.weight,
		tr("ui.codex.value"),
		item_def.value,
		stack_text,
		damage_text,
	]
