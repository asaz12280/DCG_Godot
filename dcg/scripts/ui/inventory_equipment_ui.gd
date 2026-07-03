extends Control

const InventoryLayoutScript := preload("res://scripts/ui/inventory_equipment_layout.gd")
const InventoryPainterScript := preload("res://scripts/ui/inventory_equipment_painter.gd")
const InventoryItemResolverScript := preload("res://scripts/ui/inventory_item_resolver.gd")
const InventoryDropControllerScript := preload("res://scripts/ui/inventory_drop_controller.gd")
const InventoryContextMenuScript := preload("res://scripts/ui/inventory_context_menu.gd")

@export var backpack_columns: int = 5
@export var slot_size: Vector2 = Vector2(75.0, 75.0)
@export var slot_gap: float = 12.0
@export var inventory_ui_scale: float = 1.0

var is_open: bool = false
var backpack_scroll_row: int = 0
var player: Node = null
var money: int = 0
var premium_money: int = 0
var backpack_model := InventoryModel.new()
var equipment_model = null
var backpack_items: Array[Dictionary] = []
var safe_pocket_items: Array[Dictionary] = []

var equipment_slot_label_keys: Array[StringName] = [
	&"ui.equipment.primary",
	&"ui.equipment.sidearm",
	&"ui.equipment.melee",
	&"ui.equipment.helmet",
	&"ui.equipment.armor",
	&"ui.equipment.glasses",
	&"ui.equipment.headset",
	&"ui.equipment.backpack",
	&"ui.equipment.charm_1",
	&"ui.equipment.charm_2",
]

var equipment_slot_ids: Array[StringName] = [
	&"primary_weapon",
	&"sidearm",
	&"melee",
	&"helmet",
	&"armor",
	&"glasses",
	&"headset",
	&"backpack",
	&"charm_1",
	&"charm_2",
]

var _organize_button_rect: Rect2 = Rect2()
var _ui_scale: float = 1.0
var _scaled_slot_size: Vector2 = Vector2.ZERO
var _scaled_slot_gap: float = 0.0
var _layout := InventoryLayoutScript.new()
var _painter := InventoryPainterScript.new(self)
var _item_resolver := InventoryItemResolverScript.new()
var _drop_controller := InventoryDropControllerScript.new()
var _context_menu := InventoryContextMenuScript.new()


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	player = get_tree().get_first_node_in_group("player")
	if player == null and get_tree().current_scene != null:
		player = get_tree().current_scene.find_child("Player3D", true, false)
	if player != null and player.has_method("get_inventory_model"):
		backpack_model = player.get_inventory_model()
	else:
		backpack_model.setup(_get_backpack_slots())
	if player != null and player.has_method("get_equipment_model"):
		equipment_model = player.get_equipment_model()

	_drop_controller.setup(self, _painter, _item_resolver)
	_context_menu.setup(self, _painter, backpack_model)
	_context_menu.drop_requested.connect(_on_context_drop_requested)
	_context_menu.equip_requested.connect(_on_context_equip_requested)
	backpack_model.changed.connect(_on_backpack_changed)
	if equipment_model != null:
		equipment_model.changed.connect(_on_equipment_changed)
	_on_backpack_changed()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_backpack(1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_backpack(-1)
			get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not is_open:
		return

	if event is InputEventMouseMotion:
		if _drop_controller.is_dragging():
			_drop_controller.update_drag(event.position)
			accept_event()
			return
		if _context_menu.handle_mouse_motion(event):
			accept_event()
			return

	if event is InputEventMouseButton:
		var hit_stack_index := _get_backpack_stack_index_at(event.position)
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_drop_controller.clear()
		if _context_menu.handle_mouse_button(event, hit_stack_index, backpack_items, _get_backpack_slots(), _can_equip_stack_index(hit_stack_index)):
			accept_event()
			return

		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _organize_button_rect.has_point(event.position):
				organize_backpack()
				accept_event()
				return
			if hit_stack_index >= 0 and hit_stack_index < backpack_items.size():
				_context_menu.close_all()
				_drop_controller.start_drag(hit_stack_index, backpack_items[hit_stack_index], event.position)
				accept_event()
				return

		if not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _drop_controller.is_dragging():
			var target_stack_index := _get_backpack_stack_index_at(event.position)
			var target_equipment_slot := _get_equipment_slot_id_at(event.position)
			_drop_controller.finish_drag(backpack_model, event.position, _panel_rect(), target_stack_index, player, target_equipment_slot)
			accept_event()


func toggle_inventory() -> void:
	is_open = not is_open
	if not is_open:
		_reset_interaction_state()
	visible = is_open
	mouse_filter = Control.MOUSE_FILTER_STOP if is_open else Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func open_inventory() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func close_inventory() -> void:
	if not is_open:
		return
	_reset_interaction_state()
	is_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func organize_backpack() -> void:
	backpack_model.organize()


func add_item_resource(item_def: ItemDef, quantity: int = 1) -> bool:
	if player != null and player.has_method("add_item_resource"):
		return player.add_item_resource(item_def, quantity)
	return backpack_model.add_item(item_def, quantity)


func equip_backpack_stack(stack_index: int) -> bool:
	if player == null or not player.has_method("equip_inventory_stack"):
		return false
	if not player.call("equip_inventory_stack", stack_index):
		return false
	_context_menu.close_all()
	_drop_controller.clear()
	queue_redraw()
	return true


func get_display_state() -> Dictionary:
	var viewport_size := get_viewport_rect().size if is_inside_tree() else Vector2(1920.0, 1080.0)
	return get_display_state_for_viewport(viewport_size)


func get_display_state_for_viewport(viewport_size: Vector2) -> Dictionary:
	_update_layout_scale(viewport_size)
	return {
		"visible": visible,
		"is_open": is_open,
		"backpack_items": backpack_items.duplicate(true),
		"equipment_slots": _get_equipment_slots_state(),
		"equipment_slot_rects": _get_equipment_slot_rects_state(),
		"equipment_text": _get_equipment_visible_text(),
		"panel_rect": _panel_rect(),
		"backpack_used": backpack_model.get_used_slots(),
		"backpack_slots": _get_backpack_slots(),
	}


func _reset_interaction_state() -> void:
	_drop_controller.clear()
	_context_menu.close_all()


func _on_backpack_changed() -> void:
	backpack_items = backpack_model.get_display_items()
	queue_redraw()


func _on_equipment_changed() -> void:
	queue_redraw()


func _on_localization_changed() -> void:
	queue_redraw()


func _draw() -> void:
	if not is_open:
		return

	var viewport_size := get_viewport_rect().size
	_update_layout_scale(viewport_size)

	var panel_rect := _panel_rect()
	var equipment_rect := _layout.equipment_rect(panel_rect)
	var backpack_rect := _layout.backpack_rect(panel_rect)
	var weight_rect := _layout.weight_rect(panel_rect)
	var safe_rect := _layout.safe_pocket_rect(panel_rect, _get_safe_pocket_slots())
	var premium_rect := _layout.premium_currency_rect(panel_rect)
	var money_rect := _layout.money_currency_rect(panel_rect)

	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.0, 0.0, 0.0, 0.08))
	_paint_panel_shadow(panel_rect)
	_painter.panel(panel_rect, Color(0.76, 0.77, 0.70, 0.56), Color(1.0, 1.0, 1.0, 0.14), 1, 22)
	_paint_panel_highlight(panel_rect)
	_paint_currency_panel(premium_rect, "D", premium_money)
	_paint_currency_panel(money_rect, "$", money)
	_paint_equipment_panel(equipment_rect)
	_paint_backpack_panel(backpack_rect)
	_paint_weight_panel(weight_rect)
	if _layout.can_show_safe_pocket(safe_rect, viewport_size):
		_paint_safe_pocket_panel(safe_rect)
	if _drop_controller.is_dragging():
		_drop_controller.draw_dragged_item(_scaled_slot_size, Callable(self, "_paint_item_label"))
	_context_menu.draw(backpack_items, _get_backpack_slots())


func _update_layout_scale(viewport_size: Vector2) -> void:
	_layout.update_scale(viewport_size, inventory_ui_scale)
	_ui_scale = _layout.ui_scale
	_painter.set_scale(_ui_scale)
	_context_menu.set_scale(_ui_scale)
	_scaled_slot_size = slot_size * _ui_scale
	_scaled_slot_gap = slot_gap * _ui_scale


func _panel_rect() -> Rect2:
	return _layout.panel_rect()


func _paint_currency_panel(rect: Rect2, icon_text: String, amount: int) -> void:
	_painter.panel(Rect2(rect.position + _v(4.0, 4.0), rect.size).grow(5.0 * _ui_scale), Color(0.0, 0.0, 0.0, 0.10), Color.TRANSPARENT, 0, 10)
	_painter.panel(rect, Color(0.74, 0.78, 0.73, 0.68), Color(1.0, 1.0, 1.0, 0.08), 1, 10)
	_painter.text(icon_text, rect.position + _v(10.0, 30.0), 25, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 28.0 * _ui_scale)
	_painter.text(str(amount), rect.position + _v(50.0, 30.0), 25, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 50.0 * _ui_scale)


func _paint_safe_pocket_panel(rect: Rect2) -> void:
	_painter.panel(Rect2(rect.position + _v(8.0, 8.0), rect.size), Color(0.0, 0.0, 0.0, 0.14), Color.TRANSPARENT, 0, 18)
	_painter.panel(rect, Color(0.76, 0.77, 0.70, 0.56), Color(1.0, 1.0, 1.0, 0.14), 1, 18)
	_paint_header(Rect2(rect.position + _v(12.0, 8.0), Vector2(rect.size.x - 24.0 * _ui_scale, 28.0 * _ui_scale)), _localized_text(&"ui.inventory.safe_pocket", ""))
	for index in range(_get_safe_pocket_slots()):
		var pocket_slot := Rect2(rect.position + _v(47.0, 48.0 + float(index) * 86.0), _v(74.0, 74.0))
		_painter.slot(pocket_slot, Color(0.70, 0.72, 0.66, 0.25), Color(1.0, 1.0, 1.0, 0.28))


func _paint_equipment_panel(rect: Rect2) -> void:
	_paint_header(Rect2(rect.position, Vector2(rect.size.x, 36.0 * _ui_scale)), _localized_text(&"ui.inventory.equipment", ""))
	for index in range(equipment_slot_label_keys.size()):
		var slot_rect := _equipment_slot_rect(rect, index)
		_painter.slot(slot_rect, Color(0.56, 0.58, 0.53, 0.52), Color(1.0, 1.0, 1.0, 0.22))
		_painter.equipment_icon(slot_rect, index)
		var equipped_stack := _get_equipment_stack_at(index)
		if not equipped_stack.is_empty():
			_paint_item_label(slot_rect, equipped_stack)
		_painter.text(_localized_text(equipment_slot_label_keys[index], ""), slot_rect.position + Vector2(0.0, slot_rect.size.y + 22.0 * _ui_scale), 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, slot_rect.size.x)


func _paint_backpack_panel(rect: Rect2) -> void:
	_paint_header(Rect2(rect.position, Vector2(rect.size.x, 50.0 * _ui_scale)), _localized_text(&"ui.inventory.backpack_format", "") % [backpack_model.get_used_slots(), _get_backpack_slots()])
	_organize_button_rect = Rect2(Vector2(rect.end.x - 112.0 * _ui_scale, rect.position.y + 7.0 * _ui_scale), Vector2(96.0 * _ui_scale, 32.0 * _ui_scale))
	_painter.panel(_organize_button_rect.grow(5.0 * _ui_scale), Color(0.25, 0.56, 0.78, 0.24), Color.TRANSPARENT, 0, 10)
	_painter.panel(_organize_button_rect, Color(0.76, 0.93, 1.0, 0.94), Color(0.48, 0.80, 1.0, 0.74), 2, 9)
	_painter.text(_localized_text(&"ui.inventory.sort", ""), _organize_button_rect.position + _v(0.0, 22.0), 16, Color(0.23, 0.42, 0.52, 1.0), HORIZONTAL_ALIGNMENT_CENTER, _organize_button_rect.size.x)

	var total_slots := _get_backpack_slots()
	var visible_rows := 4
	var max_scroll_row := maxi(0, int(ceil(float(total_slots) / float(backpack_columns))) - visible_rows)
	backpack_scroll_row = clampi(backpack_scroll_row, 0, max_scroll_row)

	for slot_index in range(backpack_scroll_row * backpack_columns, mini((backpack_scroll_row + visible_rows) * backpack_columns, total_slots)):
		var slot_rect := _backpack_slot_rect(rect, slot_index)
		_painter.slot(slot_rect, Color(0.74, 0.75, 0.68, 0.24), Color(1.0, 1.0, 1.0, 0.28))
		if slot_index < backpack_items.size():
			_paint_item_label(slot_rect, backpack_items[slot_index])

	if max_scroll_row > 0:
		_painter.scroll_bar(rect, backpack_scroll_row, max_scroll_row, _scaled_slot_size, _scaled_slot_gap)


func _backpack_slot_rect(backpack_rect: Rect2, slot_index: int) -> Rect2:
	var first_slot := backpack_scroll_row * backpack_columns
	var local_index := slot_index - first_slot
	var row := int(floor(float(local_index) / float(backpack_columns)))
	var column := local_index % backpack_columns
	var grid_start := backpack_rect.position + _v(28.0, 64.0)
	var slot_position := grid_start + Vector2(float(column) * (_scaled_slot_size.x + _scaled_slot_gap), float(row) * (_scaled_slot_size.y + _scaled_slot_gap))
	return Rect2(slot_position, _scaled_slot_size)


func _get_backpack_stack_index_at(mouse_position: Vector2) -> int:
	var viewport_size := get_viewport_rect().size
	_update_layout_scale(viewport_size)
	var backpack_rect := _layout.backpack_rect(_panel_rect())
	var total_slots := _get_backpack_slots()
	var visible_rows := 4
	var first_slot := backpack_scroll_row * backpack_columns
	var last_slot := mini(first_slot + backpack_columns * visible_rows, total_slots)

	for slot_index in range(first_slot, last_slot):
		if _backpack_slot_rect(backpack_rect, slot_index).has_point(mouse_position):
			return slot_index
	return -1


func _get_equipment_slot_id_at(mouse_position: Vector2) -> StringName:
	var index := _get_equipment_slot_index_at(mouse_position)
	if index < 0 or index >= equipment_slot_ids.size():
		return &""
	return equipment_slot_ids[index]


func _get_equipment_slot_index_at(mouse_position: Vector2) -> int:
	var viewport_size := get_viewport_rect().size
	_update_layout_scale(viewport_size)
	var equipment_rect := _layout.equipment_rect(_panel_rect())
	for index in range(equipment_slot_ids.size()):
		if _equipment_slot_rect(equipment_rect, index).has_point(mouse_position):
			return index
	return -1


func _equipment_slot_rect(equipment_rect: Rect2, index: int) -> Rect2:
	var slot_size_local := _v(80.0, 80.0)
	var start := equipment_rect.position + _v(20.0, 54.0)
	var step_x := 90.0 * _ui_scale
	var step_y := 132.0 * _ui_scale
	var row := int(floor(float(index) / 5.0))
	var column := index % 5
	return Rect2(start + Vector2(float(column) * step_x, float(row) * step_y), slot_size_local)


func _on_context_drop_requested(stack_index: int, stack: Dictionary, screen_position: Vector2, random_near_player: bool) -> void:
	_drop_controller.drop_stack_at(backpack_model, stack_index, stack, screen_position, player, random_near_player)


func _on_context_equip_requested(stack_index: int, _stack: Dictionary) -> void:
	equip_backpack_stack(stack_index)


func _paint_weight_panel(rect: Rect2) -> void:
	var current_weight := _get_current_weight()
	var weight_limit := _get_carry_weight_limit()
	var ratio := 0.0 if weight_limit <= 0.0 else clampf(current_weight / weight_limit, 0.0, 1.0)
	var label_rect := Rect2(rect.position, _v(220.0, 40.0))
	var value_rect := Rect2(Vector2(label_rect.end.x + 22.0 * _ui_scale, rect.position.y), Vector2(150.0 * _ui_scale, 40.0 * _ui_scale))
	var bar_rect := Rect2(label_rect.position + _v(68.0, 14.0), _v(130.0, 12.0))

	_painter.panel(label_rect, Color(0.74, 0.78, 0.73, 0.66), Color.TRANSPARENT, 0, 10)
	_painter.panel(bar_rect, Color(0.26, 0.30, 0.29, 0.58), Color.TRANSPARENT, 0, 7)
	draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * ratio, bar_rect.size.y)), Color(0.84, 0.88, 0.82, 0.92))
	_painter.text(_localized_text(&"ui.inventory.load", ""), label_rect.position + _v(16.0, 27.0), 19, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 52.0 * _ui_scale)
	_painter.panel(value_rect, Color(0.0, 0.0, 0.0, 0.82), Color.TRANSPARENT, 0, 10)
	var text_color := Color(1.0, 0.48, 0.42, 1.0) if current_weight > weight_limit else Color.WHITE
	_painter.text("%.1f/%.0fkg" % [current_weight, weight_limit], value_rect.position + _v(0.0, 27.0), 19, text_color, HORIZONTAL_ALIGNMENT_CENTER, value_rect.size.x)


func _paint_header(rect: Rect2, text: String) -> void:
	_painter.header(rect, text)


func _paint_panel_shadow(rect: Rect2) -> void:
	_painter.panel_shadow(rect)


func _paint_panel_highlight(rect: Rect2) -> void:
	_painter.panel_highlight(rect)


func _paint_item_label(rect: Rect2, stack: Dictionary) -> void:
	var label := _get_stack_display_name(stack)
	var quantity := int(stack.get("quantity", 1))
	_painter.item_label(rect, label, quantity)


func _get_stack_display_name(stack: Dictionary) -> String:
	var key := StringName(str(stack.get("name_key", "")))
	if str(key) != "":
		return _localized_text(key, str(stack.get("name", "")))
	var fallback := str(stack.get("name", ""))
	if fallback != "":
		return fallback
	return _localized_text(&"item.unknown.name", "")


func _localized_text(key: StringName, fallback: String) -> String:
	var key_text := str(key)
	if key_text == "":
		return fallback
	var translated := tr(key_text)
	if translated == key_text:
		return fallback
	return translated


func _scroll_backpack(direction: int) -> void:
	var total_slots := _get_backpack_slots()
	var max_scroll_row := maxi(0, int(ceil(float(total_slots) / float(backpack_columns))) - 4)
	backpack_scroll_row = clampi(backpack_scroll_row + direction, 0, max_scroll_row)
	queue_redraw()


func _v(x: float, y: float) -> Vector2:
	return Vector2(x, y) * _ui_scale


func _get_backpack_slots() -> int:
	if player != null and player.has_method("get_total_backpack_slots"):
		return player.get_total_backpack_slots()
	return 50


func _get_safe_pocket_slots() -> int:
	if player != null and player.has_method("get_total_safe_pocket_slots"):
		return player.get_total_safe_pocket_slots()
	return 2


func _get_carry_weight_limit() -> float:
	if player != null and player.has_method("get_total_carry_weight_limit"):
		return player.get_total_carry_weight_limit()
	return 45.0


func _get_current_weight() -> float:
	return backpack_model.get_total_weight()


func _can_equip_stack_index(stack_index: int) -> bool:
	if player == null or not player.has_method("can_equip_inventory_stack"):
		return false
	return bool(player.call("can_equip_inventory_stack", stack_index))


func _get_equipment_stack_at(index: int) -> Dictionary:
	if equipment_model == null or index < 0 or index >= equipment_slot_ids.size():
		return {}
	return equipment_model.call("get_slot", equipment_slot_ids[index])


func _get_equipment_slots_state() -> Dictionary:
	if equipment_model == null:
		return {}
	return equipment_model.call("get_slots")


func _get_equipment_slot_rects_state() -> Dictionary:
	var rects: Dictionary = {}
	var equipment_rect := _layout.equipment_rect(_panel_rect())
	for index in range(equipment_slot_ids.size()):
		rects[str(equipment_slot_ids[index])] = _equipment_slot_rect(equipment_rect, index)
	return rects


func _get_equipment_visible_text() -> String:
	var parts: PackedStringArray = []
	for slot_id in equipment_slot_ids:
		if equipment_model == null:
			break
		var stack: Dictionary = equipment_model.call("get_slot", slot_id)
		if not stack.is_empty():
			parts.append(_get_stack_display_name(stack))
	return "\n".join(parts)
