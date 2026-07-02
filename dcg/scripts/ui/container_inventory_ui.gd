class_name ContainerInventoryUI
extends Control

signal close_requested
signal slot_pressed(index: int, stack: Dictionary)

const UIStyle := preload("res://scripts/ui/ui_style.gd")
const UILayout := preload("res://scripts/ui/ui_layout.gd")
const InventoryItemResolverScript := preload("res://scripts/ui/inventory_item_resolver.gd")

@onready var main_panel: PanelContainer = %MainPanel
@onready var title_label: Label = %TitleLabel
@onready var capacity_label: Label = %CapacityLabel
@onready var help_label: Label = %HelpLabel
@onready var slot_scroll: ScrollContainer = %SlotScroll
@onready var slot_grid: GridContainer = %SlotGrid
@onready var empty_label: Label = %EmptyLabel
@onready var close_button: Button = %CloseButton

var container_model: RefCounted = null
var container_display_name := "物資箱"
var slot_button_size := Vector2(96.0, 74.0)

var _item_resolver := InventoryItemResolverScript.new()


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_overlay_panel_style(main_panel)
	UIStyle.apply_font_size(title_label, UIStyle.FONT_PANEL_TITLE)
	UIStyle.apply_font_color(title_label, UIStyle.COLOR_TEXT_PRIMARY)
	UIStyle.apply_font_size(capacity_label, UIStyle.FONT_SUBTITLE)
	UIStyle.apply_font_color(capacity_label, UIStyle.COLOR_TEXT_SUBTITLE)
	UIStyle.apply_font_size(help_label, UIStyle.FONT_PLACEHOLDER)
	UIStyle.apply_font_color(help_label, UIStyle.COLOR_TEXT_HELP)
	UIStyle.apply_font_size(empty_label, UIStyle.FONT_BODY)
	UIStyle.apply_font_color(empty_label, UIStyle.COLOR_TEXT_HELP)
	UIStyle.apply_font_size(close_button, UIStyle.FONT_BODY)
	slot_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_button.pressed.connect(close_panel)
	resized.connect(_on_resized)
	_on_resized()


func _on_resized() -> void:
	if get_viewport() == null:
		return
	preview_layout(get_viewport_rect().size)


func open_container(model: RefCounted, display_name: String = "物資箱") -> void:
	if container_model != null and container_model.changed.is_connected(refresh):
		container_model.changed.disconnect(refresh)
	container_model = model
	container_display_name = display_name if display_name != "" else "物資箱"
	if container_model != null and not container_model.changed.is_connected(refresh):
		container_model.changed.connect(refresh)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh()
	close_button.grab_focus.call_deferred()


func close_panel() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	close_requested.emit()


func refresh() -> void:
	title_label.text = container_display_name
	_clear_grid()
	if container_model == null:
		capacity_label.text = "0/0"
		empty_label.visible = true
		return

	var slots: Array[Dictionary] = container_model.call("get_slots")
	capacity_label.text = "%d/%d" % [container_model.get_used_slots(), container_model.get_capacity()]
	empty_label.visible = container_model.get_used_slots() == 0
	for index in range(slots.size()):
		slot_grid.add_child(_make_slot_button(index, slots[index]))


func preview_layout(viewport_size: Vector2) -> Rect2:
	var rect := UILayout.centered_top_rect(viewport_size, Vector2(480.0, 220.0), 92.0, 1.0, 1.0)
	main_panel.anchor_left = 0.0
	main_panel.anchor_top = 0.0
	main_panel.anchor_right = 0.0
	main_panel.anchor_bottom = 0.0
	main_panel.offset_left = rect.position.x
	main_panel.offset_top = rect.position.y
	main_panel.offset_right = rect.position.x + rect.size.x
	main_panel.offset_bottom = rect.position.y + rect.size.y
	slot_grid.columns = 4
	var scale := rect.size.x / 480.0
	slot_button_size = Vector2(96.0, 74.0) * scale
	return rect


func get_display_state() -> Dictionary:
	return {
		"visible": visible,
		"title": title_label.text if title_label != null else "",
		"capacity": capacity_label.text if capacity_label != null else "",
		"help": help_label.text if help_label != null else "",
		"empty": empty_label.text if empty_label != null else "",
		"close": close_button.text if close_button != null else "",
		"panel_rect": main_panel.get_global_rect() if main_panel != null else Rect2(),
		"grid_rect": slot_grid.get_global_rect() if slot_grid != null else Rect2(),
		"scroll_rect": slot_scroll.get_global_rect() if slot_scroll != null else Rect2(),
		"slot_count": slot_grid.get_child_count() if slot_grid != null else 0,
	}


func _make_slot_button(index: int, stack: Dictionary) -> Button:
	var button := Button.new()
	button.name = "ContainerSlot%d" % index
	button.custom_minimum_size = slot_button_size
	button.focus_mode = Control.FOCUS_ALL
	button.text = _slot_text(index, stack)
	button.tooltip_text = _slot_tooltip(stack)
	button.pressed.connect(func() -> void:
		slot_pressed.emit(index, stack.duplicate(true))
	)
	UIStyle.apply_font_size(button, UIStyle.FONT_HELP)
	return button


func _slot_text(index: int, stack: Dictionary) -> String:
	if stack.is_empty():
		return "%02d\n空格" % [index + 1]
	var item_def := _item_resolver.item_def_from_stack(stack)
	var name := str(stack.get("name", "物品"))
	if item_def != null:
		name = tr(str(item_def.name_key))
		if name == str(item_def.name_key) or name == "":
			name = item_def.display_name
	var quantity := int(stack.get("quantity", 1))
	return "%02d\n%s x%d" % [index + 1, name, quantity]


func _slot_tooltip(stack: Dictionary) -> String:
	if stack.is_empty():
		return "空格"
	var item_def := _item_resolver.item_def_from_stack(stack)
	if item_def == null:
		return "未知物品"
	return "%s\n重量 %.2f kg\n價值 %d" % [
		tr(str(item_def.description_key)),
		item_def.weight,
		item_def.value,
	]


func _clear_grid() -> void:
	for child in slot_grid.get_children():
		slot_grid.remove_child(child)
		child.queue_free()
