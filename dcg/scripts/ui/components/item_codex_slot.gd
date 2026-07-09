class_name ItemCodexSlot
extends Control

# // Reusable codex slot component for the future node-based codex UI. Current drawn UI can migrate slot by slot. //
signal slot_selected(catalog_number: int)

const ItemStackTooltipPresenterScript := preload("res://scripts/ui/item_stack_tooltip_presenter.gd")

var catalog_number: int = 0
var item_def: ItemDef = null
var is_selected: bool = false
var text: String = ""
var _fixed_slot_size: Vector2 = Vector2.ZERO
var _is_hovered: bool = false


func set_slot_size(slot_size: Vector2) -> void:
	_fixed_slot_size = slot_size
	custom_minimum_size = slot_size
	size = slot_size
	update_minimum_size()
	queue_redraw()


func setup(number: int, item: ItemDef) -> void:
	catalog_number = number
	item_def = item
	text = _build_label()
	tooltip_text = _build_tooltip()
	queue_redraw()


func clear_slot(number: int) -> void:
	catalog_number = number
	item_def = null
	text = _build_label()
	tooltip_text = ""
	queue_redraw()


func set_selected(value: bool) -> void:
	is_selected = value
	modulate = Color(1.0, 1.0, 1.0, 1.0) if not is_selected else Color(0.82, 1.0, 1.0, 1.0)
	queue_redraw()


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _get_minimum_size() -> Vector2:
	if _fixed_slot_size != Vector2.ZERO:
		return _fixed_slot_size
	if custom_minimum_size != Vector2.ZERO:
		return custom_minimum_size
	return Vector2(96.0, 64.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		slot_selected.emit(catalog_number)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var style := StyleBoxFlat.new()
	style.bg_color = _background_color()
	style.border_color = Color(0.35, 0.58, 0.68, 0.82) if not is_selected else Color(0.62, 0.94, 1.0, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	draw_style_box(style, rect)
	_draw_label()


func _draw_label() -> void:
	if text == "":
		return
	var font := get_theme_default_font()
	var font_size := _label_font_size(font)
	var text_width := maxf(size.x - 14.0, 1.0)
	var text_height := font.get_height(font_size)
	var draw_y: float = floor((size.y - text_height) * 0.5 + font.get_ascent(font_size))
	draw_string(font, Vector2(7.0, draw_y), text, HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size, Color(0.91, 0.96, 0.96, 1.0))


func _label_font_size(font: Font) -> int:
	var text_width := maxf(size.x - 14.0, 1.0)
	var max_size := clampi(roundi(size.y * 0.22), 14, 22)
	for font_size in range(max_size, 11, -1):
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= text_width:
			return font_size
	return 12


func _background_color() -> Color:
	if is_selected:
		return Color(0.19, 0.33, 0.37, 0.94)
	if _is_hovered:
		return Color(0.22, 0.34, 0.39, 0.94)
	return Color(0.19, 0.28, 0.33, 0.90)


func _on_mouse_entered() -> void:
	_is_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_is_hovered = false
	queue_redraw()


func _build_label() -> String:
	if item_def == null:
		return "-"
	var name_key := str(item_def.name_key)
	if name_key != "":
		var translated := tr(name_key)
		if translated != name_key and translated != "":
			return translated
	if item_def.display_name != "":
		return item_def.display_name
	return str(item_def.id)


func _build_tooltip() -> String:
	if item_def == null:
		return ""
	var stack := item_def.to_stack(1)
	stack["catalog_number"] = catalog_number
	return ItemStackTooltipPresenterScript.tooltip_text(
		ItemStackTooltipPresenterScript.build(self, stack)
	)
