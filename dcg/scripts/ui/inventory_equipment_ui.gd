extends Control

signal store_all_requested

const InventoryLayoutScript := preload("res://scripts/ui/inventory_equipment_layout.gd")
const InventoryPainterScript := preload("res://scripts/ui/inventory_equipment_painter.gd")
const InventoryItemResolverScript := preload("res://scripts/ui/inventory_item_resolver.gd")
const InventoryDropControllerScript := preload("res://scripts/ui/inventory_drop_controller.gd")
const InventoryContextMenuScript := preload("res://scripts/ui/inventory_context_menu.gd")
const InventoryGridMetricsScript := preload("res://scripts/ui/inventory_grid_metrics.gd")
const PlayerQuickBarLayoutScript := preload("res://scripts/ui/player_quick_bar_layout.gd")
const WeaponModPanelPresenterScript := preload("res://scripts/ui/weapon_mod_panel_presenter.gd")
const InventoryEquipmentDisplaySupportScript := preload("res://scripts/ui/inventory_equipment_display_support.gd")
const InventoryEquipmentPanelPainterScript := preload("res://scripts/ui/inventory_equipment_panel_painter.gd")
const WeaponAttachmentServiceScript := preload("res://scripts/combat/weapon_attachment_service.gd")
const WeaponTuningServiceScript := preload("res://scripts/combat/weapon_tuning_service.gd")
const ItemConsumableServiceScript := preload("res://scripts/items/item_consumable_service.gd")

@export var backpack_columns: int = 5
@export var slot_size: Vector2 = Vector2(75.0, 75.0)
@export var slot_gap: float = 12.0
@export var inventory_ui_scale: float = 1.0

var is_open: bool = false
var backpack_scroll_row: int = 0
var player: Node = null
var money: int = 0
var backpack_model := InventoryModel.new()
var safe_pocket_model := InventoryModel.new()
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
var _store_all_button_rect: Rect2 = Rect2()
var _store_all_button_visible: bool = false
var _ui_scale: float = 1.0
var _scaled_slot_size: Vector2 = Vector2.ZERO
var _scaled_slot_gap: float = 0.0
var _layout := InventoryLayoutScript.new()
var _painter := InventoryPainterScript.new(self)
var _item_resolver := InventoryItemResolverScript.new()
var _drop_controller := InventoryDropControllerScript.new()
var _context_menu := InventoryContextMenuScript.new()
var _weapon_mod_panel := WeaponModPanelPresenterScript.new()
var _last_mouse_position: Vector2 = Vector2.ZERO
var _layout_viewport_size: Vector2 = Vector2(1920.0, 1080.0)
var _dragging_equipment_slot: StringName = &""
var _dragging_equipment_stack: Dictionary = {}
var _equipment_drag_position: Vector2 = Vector2.ZERO
var _dragging_weapon_mod_slot: StringName = &""
var _dragging_weapon_mod_stack: Dictionary = {}
var _weapon_mod_drag_position: Vector2 = Vector2.ZERO
var _dragging_quick_slot_key: int = -1
var _dragging_quick_slot_stack: Dictionary = {}
var _quick_slot_drag_position: Vector2 = Vector2.ZERO
var _weapon_mod_backpack_stack_index: int = -1


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
	if player != null and player.has_method("get_safe_pocket_model"):
		safe_pocket_model = player.get_safe_pocket_model()
	else:
		safe_pocket_model.setup(_get_safe_pocket_slots())
	if player != null and player.has_method("get_equipment_model"):
		equipment_model = player.get_equipment_model()

	_drop_controller.setup(self, _painter, _item_resolver)
	_context_menu.setup(self, _painter, backpack_model)
	_context_menu.use_requested.connect(_on_context_use_requested)
	_context_menu.mod_requested.connect(_on_context_mod_requested)
	_context_menu.drop_requested.connect(_on_context_drop_requested)
	backpack_model.changed.connect(_on_backpack_changed)
	safe_pocket_model.changed.connect(_on_safe_pocket_changed)
	if equipment_model != null:
		equipment_model.changed.connect(_on_equipment_changed)
	_connect_save_manager()
	_refresh_money()
	_on_backpack_changed()
	_on_safe_pocket_changed()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var quick_key := _quick_slot_key_for_event(event)
		if quick_key >= 3 and _assign_hovered_stack_to_quick_slot(quick_key):
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _weapon_mod_panel.has_point(event.position, _ui_scale, _layout_viewport_size):
				_weapon_mod_panel.scroll_details(1, _ui_scale, _layout_viewport_size)
				queue_redraw()
				get_viewport().set_input_as_handled()
				return
			_scroll_backpack(1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if _weapon_mod_panel.has_point(event.position, _ui_scale, _layout_viewport_size):
				_weapon_mod_panel.scroll_details(-1, _ui_scale, _layout_viewport_size)
				queue_redraw()
				get_viewport().set_input_as_handled()
				return
			_scroll_backpack(-1)
			get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not is_open:
		return

	if event is InputEventMouseMotion:
		_last_mouse_position = event.position
		queue_redraw()
		if _is_dragging_quick_slot():
			_update_quick_slot_drag(event.position)
			accept_event()
			return
		if _is_dragging_weapon_mod():
			_update_weapon_mod_drag(event.position)
			accept_event()
			return
		if _is_dragging_equipment():
			_update_equipment_drag(event.position)
			accept_event()
			return
		if _drop_controller.is_dragging():
			_drop_controller.update_drag(event.position)
			accept_event()
			return
		if _context_menu.handle_mouse_motion(event):
			accept_event()
			return

	if event is InputEventMouseButton:
		_last_mouse_position = event.position
		var hit_stack_index := _get_backpack_stack_index_at(event.position)
		var hit_safe_pocket_index := _get_safe_pocket_slot_index_at(event.position)
		var hit_equipment_slot := _get_equipment_slot_id_at(event.position)
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_drop_controller.clear()
			if _weapon_mod_panel.is_open():
				_context_menu.close_all()
				accept_event()
				return
		if _context_menu.handle_mouse_button(event, hit_stack_index, backpack_items, _get_backpack_slots()):
			accept_event()
			return

		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var quick_key := _get_quick_item_key_at(event.position)
			if quick_key >= 3 and _start_quick_slot_drag(quick_key, event.position):
				accept_event()
				return
			if _store_all_button_visible and _store_all_button_rect.has_point(event.position):
				_context_menu.close_all()
				_drop_controller.clear()
				store_all_requested.emit()
				accept_event()
				return
			if _organize_button_rect.has_point(event.position):
				organize_backpack()
				accept_event()
				return
			if _weapon_mod_panel.hit_close(event.position, _ui_scale, _layout_viewport_size):
				_close_weapon_mod_panel()
				accept_event()
				return
			var hit_weapon_mod_slot := _get_weapon_mod_slot_id_at(event.position)
			if hit_weapon_mod_slot != &"" and _start_weapon_mod_drag(hit_weapon_mod_slot, event.position):
				accept_event()
				return
			if _handle_weapon_mod_panel_click(event.position):
				accept_event()
				return
			if hit_equipment_slot != &"" and event.double_click and _unequip_equipment_slot(hit_equipment_slot):
				accept_event()
				return
			if hit_equipment_slot != &"" and _start_equipment_drag(hit_equipment_slot, event.position):
				accept_event()
				return
			if hit_safe_pocket_index >= 0 and hit_safe_pocket_index < safe_pocket_items.size() and _move_safe_pocket_stack_to_backpack(hit_safe_pocket_index):
				accept_event()
				return
			if hit_stack_index >= 0 and hit_stack_index < backpack_items.size():
				if event.double_click:
					equip_backpack_stack(hit_stack_index)
					accept_event()
					return
				_context_menu.close_all()
				_drop_controller.start_drag(hit_stack_index, backpack_items[hit_stack_index], event.position)
				accept_event()
				return

		if not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _is_dragging_weapon_mod():
			_finish_weapon_mod_drag(event.position)
			accept_event()
			return

		if not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _is_dragging_quick_slot():
			_finish_quick_slot_drag(event.position)
			accept_event()
			return

		if not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _is_dragging_equipment():
			_finish_equipment_drag(event.position)
			accept_event()
			return

		if not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _drop_controller.is_dragging():
			var target_stack_index := _get_backpack_stack_index_at(event.position)
			var target_equipment_slot := _get_equipment_slot_id_at(event.position)
			var target_safe_pocket_slot := _get_safe_pocket_slot_index_at(event.position)
			var target_weapon_mod_slot := _get_weapon_mod_slot_id_at(event.position)
			var target_quick_key := _get_quick_item_key_at(event.position)
			if target_quick_key >= 3 and assign_backpack_stack_to_quick_slot(_drop_controller.dragging_stack_index, target_quick_key):
				_drop_controller.clear()
				accept_event()
				return
			if target_weapon_mod_slot != &"":
				_attach_dragged_stack_to_open_weapon_hardpoint(target_weapon_mod_slot)
				_drop_controller.clear()
				accept_event()
				return
			_drop_controller.finish_drag(backpack_model, event.position, _panel_rect(), target_stack_index, player, target_equipment_slot, target_safe_pocket_slot, not _weapon_mod_panel.is_open())
			accept_event()


func _process(_delta: float) -> void:
	if not is_open:
		return
	var current_position := _current_mouse_position()
	if current_position.distance_squared_to(_last_mouse_position) <= 0.25:
		return
	_last_mouse_position = current_position
	queue_redraw()


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
	_refresh_money()
	queue_redraw()


func close_inventory() -> void:
	if not is_open:
		return
	_reset_interaction_state()
	is_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func organize_backpack(sort_mode: StringName = &"type") -> void:
	var selected_mode := sort_mode if sort_mode != &"" else &"type"
	backpack_model.organize(selected_mode)


func set_store_all_action_visible(should_show: bool) -> void:
	_store_all_button_visible = should_show
	if not _store_all_button_visible:
		_store_all_button_rect = Rect2()
	queue_redraw()


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
	return InventoryEquipmentDisplaySupportScript.build_owner_state(self, viewport_size, _layout, _weapon_mod_panel, backpack_model, safe_pocket_model)


func get_item_tooltip_by_path(item_path: String) -> Dictionary:
	return InventoryEquipmentDisplaySupportScript.tooltip_by_path(self, item_path)


func get_hover_item_tooltip_for_position(screen_position: Vector2) -> Dictionary:
	return _tooltip_state_for_stack(InventoryEquipmentDisplaySupportScript.stack_at_position(self, screen_position))


func _reset_interaction_state() -> void:
	_drop_controller.clear()
	_clear_equipment_drag()
	_clear_weapon_mod_drag()
	_clear_quick_slot_drag()
	_context_menu.close_all()
	_close_weapon_mod_panel()


func _on_backpack_changed() -> void:
	backpack_items = backpack_model.get_display_items()
	_refresh_money()
	queue_redraw()


func _on_safe_pocket_changed() -> void:
	safe_pocket_items = safe_pocket_model.get_display_items()
	_refresh_money()
	queue_redraw()


func _on_equipment_changed() -> void:
	_refresh_weapon_mod_panel_state()
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
	var money_rect := _layout.money_currency_rect(panel_rect)

	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.0, 0.0, 0.0, 0.08))
	InventoryEquipmentPanelPainterScript.paint_shell(self, _painter, panel_rect)
	InventoryEquipmentPanelPainterScript.paint_currency(self, _painter, money_rect, "$", money, _ui_scale)
	_paint_equipment_panel(equipment_rect)
	InventoryEquipmentPanelPainterScript.paint_backpack(self, _painter, backpack_rect, _ui_scale)
	InventoryEquipmentPanelPainterScript.paint_weight(self, _painter, weight_rect, _ui_scale)
	if _layout.can_show_safe_pocket(safe_rect, viewport_size):
		_paint_safe_pocket_panel(safe_rect)
	_draw_weapon_mod_panel()
	if _drop_controller.is_dragging():
		_drop_controller.draw_dragged_item(_scaled_slot_size, Callable(self, "_paint_item_label"))
	if _is_dragging_quick_slot():
		_draw_dragged_quick_slot_item()
	if _is_dragging_equipment():
		_draw_dragged_equipment_item()
	if _is_dragging_weapon_mod():
		_draw_dragged_weapon_mod_item()
	_context_menu.draw(backpack_items, _get_backpack_slots())
	_draw_hover_tooltip(_current_mouse_position())


func _update_layout_scale(viewport_size: Vector2) -> void:
	_layout_viewport_size = viewport_size
	_layout.update_scale(viewport_size, inventory_ui_scale)
	_ui_scale = _layout.ui_scale
	_painter.set_scale(_ui_scale)
	_context_menu.set_scale(_ui_scale)
	_scaled_slot_size = slot_size * _ui_scale
	_scaled_slot_gap = slot_gap * _ui_scale


func _panel_rect() -> Rect2:
	return _layout.panel_rect()


func _paint_safe_pocket_panel(rect: Rect2) -> void:
	_painter.panel(Rect2(rect.position + _v(8.0, 8.0), rect.size), Color(0.0, 0.0, 0.0, 0.14), Color.TRANSPARENT, 0, 18)
	_painter.panel(rect, Color(0.76, 0.77, 0.70, 0.56), Color(1.0, 1.0, 1.0, 0.14), 1, 18)
	_paint_header(Rect2(rect.position + _v(12.0, 8.0), Vector2(rect.size.x - 24.0 * _ui_scale, 28.0 * _ui_scale)), _localized_text(&"ui.inventory.safe_pocket", ""))
	for index in range(_get_safe_pocket_slots()):
		var pocket_slot := _safe_pocket_slot_rect(rect, index)
		_painter.slot(pocket_slot, Color(0.70, 0.72, 0.66, 0.25), Color(1.0, 1.0, 1.0, 0.28))
		if index < safe_pocket_items.size():
			_paint_item_label(pocket_slot, safe_pocket_items[index])


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


func _draw_weapon_mod_panel() -> void:
	_weapon_mod_panel.draw(self, _painter, _ui_scale, _layout_viewport_size)


func _backpack_slot_rect(backpack_rect: Rect2, slot_index: int) -> Rect2:
	var first_slot := backpack_scroll_row * backpack_columns
	var local_index := slot_index - first_slot
	return InventoryGridMetricsScript.slot_rect(_backpack_grid_rect(backpack_rect), local_index, backpack_columns, _scaled_slot_size, _scaled_slot_gap)


func _get_backpack_stack_index_at(mouse_position: Vector2) -> int:
	var viewport_size := _layout_viewport_size
	_update_layout_scale(viewport_size)
	var backpack_rect := _layout.backpack_rect(_panel_rect())
	var total_slots := _get_backpack_slots()
	var visible_rows := 4
	return InventoryGridMetricsScript.absolute_index_at(mouse_position, _backpack_grid_rect(backpack_rect), backpack_columns, visible_rows, backpack_scroll_row, total_slots, _scaled_slot_size, _scaled_slot_gap)


func _backpack_grid_rect(backpack_rect: Rect2) -> Rect2:
	return Rect2(backpack_rect.position + _v(28.0, 64.0), InventoryGridMetricsScript.grid_size(backpack_columns, 4, _scaled_slot_size, _scaled_slot_gap))


func _get_equipment_slot_id_at(mouse_position: Vector2) -> StringName:
	var index := _get_equipment_slot_index_at(mouse_position)
	if index < 0 or index >= equipment_slot_ids.size():
		return &""
	return equipment_slot_ids[index]


func _get_equipment_slot_index_at(mouse_position: Vector2) -> int:
	var viewport_size := _layout_viewport_size
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


func _get_safe_pocket_slot_index_at(mouse_position: Vector2) -> int:
	var viewport_size := _layout_viewport_size
	_update_layout_scale(viewport_size)
	var safe_rect := _layout.safe_pocket_rect(_panel_rect(), _get_safe_pocket_slots())
	if not _layout.can_show_safe_pocket(safe_rect, viewport_size):
		return -1
	for index in range(_get_safe_pocket_slots()):
		if _safe_pocket_slot_rect(safe_rect, index).has_point(mouse_position):
			return index
	return -1


func _safe_pocket_slot_rect(safe_rect: Rect2, index: int) -> Rect2:
	return Rect2(safe_rect.position + _v(47.0, 48.0 + float(index) * 86.0), _v(74.0, 74.0))


func _on_context_drop_requested(stack_index: int, stack: Dictionary, screen_position: Vector2, random_near_player: bool) -> void:
	if _weapon_mod_panel.is_open():
		return
	_drop_controller.drop_stack_at(backpack_model, stack_index, stack, screen_position, player, random_near_player)


func _on_context_use_requested(stack_index: int) -> void:
	if player == null or not player.has_method("use_inventory_stack"):
		return
	player.call("use_inventory_stack", stack_index)
	_drop_controller.clear()
	queue_redraw()


func _on_context_mod_requested(stack_index: int) -> void:
	_open_weapon_mod_panel_for_backpack_stack(stack_index)


func _unequip_equipment_slot(slot_id: StringName) -> bool:
	if player == null or not player.has_method("unequip_equipment_slot"):
		return false
	if not bool(player.call("unequip_equipment_slot", slot_id)):
		return false
	_context_menu.close_all()
	_drop_controller.clear()
	queue_redraw()
	return true


func _open_weapon_mod_panel_for_backpack_stack(stack_index: int) -> bool:
	var state := _weapon_mod_panel_state_for_backpack_stack(stack_index)
	if not _weapon_mod_panel.open(&"backpack_weapon", state):
		return false
	_weapon_mod_backpack_stack_index = stack_index
	_context_menu.close_all()
	_drop_controller.clear()
	queue_redraw()
	return true


func _close_weapon_mod_panel() -> void:
	_clear_weapon_mod_drag()
	_weapon_mod_backpack_stack_index = -1
	_weapon_mod_panel.close()
	_clear_equipment_drag()
	_clear_quick_slot_drag()


func _refresh_weapon_mod_panel_state() -> void:
	if _weapon_mod_backpack_stack_index >= 0:
		_weapon_mod_panel.refresh(_weapon_mod_panel_state_for_backpack_stack(_weapon_mod_backpack_stack_index))
		return
	if _weapon_mod_panel.weapon_slot == &"" or player == null or not player.has_method("get_weapon_mod_panel_state"):
		return
	var state: Dictionary = player.call("get_weapon_mod_panel_state", _weapon_mod_panel.weapon_slot)
	_weapon_mod_panel.refresh(state)


func _attach_dragged_stack_to_open_weapon_hardpoint(hardpoint_slot: StringName) -> bool:
	if _weapon_mod_backpack_stack_index >= 0:
		return _attach_dragged_stack_to_backpack_weapon_hardpoint(hardpoint_slot)
	if _weapon_mod_panel.weapon_slot == &"" or player == null or not player.has_method("attach_inventory_stack_to_weapon_hardpoint"):
		return false
	if not bool(player.call("attach_inventory_stack_to_weapon_hardpoint", _drop_controller.dragging_stack_index, _weapon_mod_panel.weapon_slot, hardpoint_slot)):
		return false
	_refresh_weapon_mod_panel_state()
	_context_menu.close_all()
	queue_redraw()
	return true


func _attach_dragged_stack_to_backpack_weapon_hardpoint(hardpoint_slot: StringName) -> bool:
	if hardpoint_slot == &"" or _drop_controller.dragging_stack_index < 0:
		return false
	var weapon_index := _weapon_mod_backpack_stack_index
	if weapon_index < 0 or weapon_index >= backpack_model.stacks.size():
		return false
	if _drop_controller.dragging_stack_index == weapon_index:
		return false
	var weapon_stack := backpack_model.stacks[weapon_index].duplicate(true)
	var weapon_def := _load_item_from_stack(weapon_stack)
	var attachment_stack: Dictionary = backpack_model.stacks[_drop_controller.dragging_stack_index]
	var attachment_def := _load_item_from_stack(attachment_stack)
	if weapon_def == null or attachment_def == null:
		return false
	if attachment_def.item_type != "attachment" or WeaponAttachmentServiceScript.mod_slot_for_attachment(attachment_def, weapon_def) != hardpoint_slot:
		return false
	if not WeaponAttachmentServiceScript.weapon_mod_stack(weapon_stack, hardpoint_slot).is_empty():
		return false
	if _drop_controller.dragging_stack_index < weapon_index:
		weapon_index -= 1
		_weapon_mod_backpack_stack_index = weapon_index
	var removed_stack: Dictionary = backpack_model.remove_stack_at(_drop_controller.dragging_stack_index)
	if removed_stack.is_empty():
		return false
	weapon_stack = backpack_model.stacks[weapon_index].duplicate(true)
	var mods: Dictionary = weapon_stack.get("weapon_mods", {}) as Dictionary
	mods[str(hardpoint_slot)] = removed_stack.duplicate(true)
	weapon_stack["weapon_mods"] = mods.duplicate(true)
	if not backpack_model.replace_stack_at(weapon_index, weapon_stack):
		backpack_model.add_stack(removed_stack)
		return false
	_refresh_weapon_mod_panel_state()
	_context_menu.close_all()
	queue_redraw()
	return true


func _handle_weapon_mod_panel_click(screen_position: Vector2) -> bool:
	if not _weapon_mod_panel.is_open():
		return false
	var hit := _weapon_mod_panel.hit_slot(screen_position, _ui_scale, _layout_viewport_size)
	if not bool(hit.get("handled", false)):
		return false
	return true


func _get_weapon_mod_slot_id_at(screen_position: Vector2) -> StringName:
	if not _weapon_mod_panel.is_open():
		return &""
	var hit := _weapon_mod_panel.hit_slot(screen_position, _ui_scale, _layout_viewport_size)
	if not bool(hit.get("handled", false)):
		return &""
	return StringName(str(hit.get("slot_id", "")))


func _move_safe_pocket_stack_to_backpack(stack_index: int) -> bool:
	if player == null or not player.has_method("move_safe_pocket_stack_to_inventory"):
		return false
	if not bool(player.call("move_safe_pocket_stack_to_inventory", stack_index)):
		return false
	_context_menu.close_all()
	_drop_controller.clear()
	queue_redraw()
	return true


func _start_weapon_mod_drag(hardpoint_slot: StringName, mouse_position: Vector2) -> bool:
	if _weapon_mod_panel.weapon_slot == &"" or hardpoint_slot == &"":
		return false
	var stack := _weapon_mod_stack_for_slot(hardpoint_slot)
	if stack.is_empty():
		return false
	_dragging_weapon_mod_slot = hardpoint_slot
	_dragging_weapon_mod_stack = stack.duplicate(true)
	_weapon_mod_drag_position = mouse_position
	_context_menu.close_all()
	_drop_controller.clear()
	_clear_equipment_drag()
	queue_redraw()
	return true


func _update_weapon_mod_drag(mouse_position: Vector2) -> void:
	_weapon_mod_drag_position = mouse_position
	queue_redraw()


func _finish_weapon_mod_drag(mouse_position: Vector2) -> bool:
	if not _is_dragging_weapon_mod():
		return false
	var target_stack_index := _get_backpack_stack_index_at(mouse_position)
	var handled := false
	if target_stack_index >= 0:
		handled = _unequip_dragged_weapon_mod_to_backpack()
	_clear_weapon_mod_drag()
	queue_redraw()
	return handled


func _unequip_dragged_weapon_mod_to_backpack() -> bool:
	if _weapon_mod_backpack_stack_index >= 0:
		return _unequip_dragged_backpack_weapon_mod_to_backpack()
	if player == null or not player.has_method("unequip_weapon_mod_to_inventory"):
		return false
	if _weapon_mod_panel.weapon_slot == &"" or _dragging_weapon_mod_slot == &"":
		return false
	if not bool(player.call("unequip_weapon_mod_to_inventory", _weapon_mod_panel.weapon_slot, _dragging_weapon_mod_slot)):
		return false
	_refresh_weapon_mod_panel_state()
	return true


func _unequip_dragged_backpack_weapon_mod_to_backpack() -> bool:
	if _weapon_mod_backpack_stack_index < 0 or _weapon_mod_backpack_stack_index >= backpack_model.stacks.size() or _dragging_weapon_mod_slot == &"":
		return false
	var weapon_stack := backpack_model.stacks[_weapon_mod_backpack_stack_index].duplicate(true)
	var mods: Dictionary = weapon_stack.get("weapon_mods", {}) as Dictionary
	var removed_value: Variant = mods.get(str(_dragging_weapon_mod_slot), mods.get(_dragging_weapon_mod_slot, {}))
	if typeof(removed_value) != TYPE_DICTIONARY or (removed_value as Dictionary).is_empty():
		return false
	var removed_stack := (removed_value as Dictionary).duplicate(true)
	mods.erase(str(_dragging_weapon_mod_slot))
	mods.erase(_dragging_weapon_mod_slot)
	weapon_stack["weapon_mods"] = mods.duplicate(true)
	if not backpack_model.can_accept_stack(removed_stack):
		return false
	if not backpack_model.replace_stack_at(_weapon_mod_backpack_stack_index, weapon_stack):
		return false
	if not backpack_model.add_stack(removed_stack):
		mods[str(_dragging_weapon_mod_slot)] = removed_stack
		weapon_stack["weapon_mods"] = mods.duplicate(true)
		backpack_model.replace_stack_at(_weapon_mod_backpack_stack_index, weapon_stack)
		return false
	_refresh_weapon_mod_panel_state()
	return true


func _weapon_mod_stack_for_slot(hardpoint_slot: StringName) -> Dictionary:
	var slots: Array = _weapon_mod_panel.state.get("slots", []) as Array
	for row_value in slots:
		var row := row_value as Dictionary
		if StringName(str(row.get("slot_id", ""))) == hardpoint_slot:
			var stack: Dictionary = row.get("stack", {}) as Dictionary
			return stack
	return {}


func _is_dragging_weapon_mod() -> bool:
	return _dragging_weapon_mod_slot != &"" and not _dragging_weapon_mod_stack.is_empty()


func _clear_weapon_mod_drag() -> void:
	_dragging_weapon_mod_slot = &""
	_dragging_weapon_mod_stack.clear()
	_weapon_mod_drag_position = Vector2.ZERO


func _draw_dragged_weapon_mod_item() -> void:
	var drag_rect := Rect2(_weapon_mod_drag_position - _scaled_slot_size * 0.5, _scaled_slot_size)
	_painter.slot(drag_rect, Color(0.34, 0.38, 0.52, 0.70), Color(0.86, 0.88, 1.0, 0.74))
	_paint_item_label(drag_rect, _dragging_weapon_mod_stack)


func _start_quick_slot_drag(quick_key: int, mouse_position: Vector2) -> bool:
	var quick_slot_state := _get_quick_slot_state_by_key(quick_key)
	if typeof(quick_slot_state) != TYPE_DICTIONARY or quick_slot_state.is_empty():
		return false
	if int(quick_slot_state.get("key", -1)) < 3 or int(quick_slot_state.get("key", -1)) > 8:
		return false
	if not bool(quick_slot_state.get("assigned", false)):
		return false
	var stack := quick_slot_state.get("stack", {}) as Dictionary
	if stack.is_empty():
		return false
	_dragging_quick_slot_key = int(quick_slot_state.get("key", int(quick_key)))
	_dragging_quick_slot_stack = stack.duplicate(true)
	_quick_slot_drag_position = mouse_position
	_context_menu.close_all()
	_drop_controller.clear()
	_clear_weapon_mod_drag()
	_clear_equipment_drag()
	queue_redraw()
	return true


func _update_quick_slot_drag(mouse_position: Vector2) -> void:
	_quick_slot_drag_position = mouse_position
	queue_redraw()


func _finish_quick_slot_drag(mouse_position: Vector2) -> bool:
	if not _is_dragging_quick_slot():
		return false
	var source_key := _dragging_quick_slot_key
	var target_key := _get_quick_item_key_at(mouse_position)
	var handled := false
	if target_key >= 3:
		if target_key == source_key:
			handled = true
		elif player != null and player.has_method("move_quick_slot_to_key"):
			handled = bool(player.call("move_quick_slot_to_key", source_key, target_key))
	elif not _panel_rect().has_point(mouse_position):
		if player != null and player.has_method("clear_quick_slot_for_key"):
			handled = bool(player.call("clear_quick_slot_for_key", source_key))
	_clear_quick_slot_drag()
	queue_redraw()
	return handled


func _clear_quick_slot_drag() -> void:
	_dragging_quick_slot_key = -1
	_dragging_quick_slot_stack.clear()
	_quick_slot_drag_position = Vector2.ZERO


func _is_dragging_quick_slot() -> bool:
	return _dragging_quick_slot_key >= 3 and not _dragging_quick_slot_stack.is_empty()


func _draw_dragged_quick_slot_item() -> void:
	var drag_rect := Rect2(_quick_slot_drag_position - _scaled_slot_size * 0.5, _scaled_slot_size)
	_painter.slot(drag_rect, Color(0.42, 0.38, 0.26, 0.72), Color(0.95, 0.88, 0.76, 0.82))
	_paint_item_label(drag_rect, _dragging_quick_slot_stack)


func _start_equipment_drag(slot_id: StringName, mouse_position: Vector2) -> bool:
	if equipment_model == null or slot_id == &"" or not equipment_model.has_method("get_slot"):
		return false
	var stack: Dictionary = equipment_model.call("get_slot", slot_id)
	if stack.is_empty():
		return false
	_dragging_equipment_slot = slot_id
	_dragging_equipment_stack = stack.duplicate(true)
	_equipment_drag_position = mouse_position
	_context_menu.close_all()
	_drop_controller.clear()
	queue_redraw()
	return true


func _update_equipment_drag(mouse_position: Vector2) -> void:
	_equipment_drag_position = mouse_position
	queue_redraw()


func _finish_equipment_drag(mouse_position: Vector2) -> bool:
	if not _is_dragging_equipment():
		return false
	var target_stack_index := _get_backpack_stack_index_at(mouse_position)
	var target_equipment_slot := _get_equipment_slot_id_at(mouse_position)
	var handled := false
	if target_stack_index >= 0:
		handled = _unequip_dragged_equipment_to_backpack()
	elif target_equipment_slot != &"":
		handled = _move_dragged_equipment_to_equipment_slot(target_equipment_slot)
	elif not _panel_rect().has_point(mouse_position):
		handled = _drop_dragged_equipment_to_world(mouse_position)
	_clear_equipment_drag()
	queue_redraw()
	return handled


func _unequip_dragged_equipment_to_backpack() -> bool:
	if player == null or not player.has_method("unequip_equipment_slot"):
		return false
	if _dragging_equipment_slot == &"":
		return false
	return bool(player.call("unequip_equipment_slot", _dragging_equipment_slot))


func _move_dragged_equipment_to_equipment_slot(target_slot: StringName) -> bool:
	if _dragging_equipment_slot == &"" or target_slot == &"" or _dragging_equipment_slot == target_slot:
		return false
	if player == null or not player.has_method("swap_equipment_slots"):
		return false
	return bool(player.call("swap_equipment_slots", _dragging_equipment_slot, target_slot))


func _drop_dragged_equipment_to_world(mouse_position: Vector2) -> bool:
	if _dragging_equipment_slot == &"" or _dragging_equipment_stack.is_empty():
		return false
	return _drop_controller.drop_equipment_stack_at(_dragging_equipment_slot, _dragging_equipment_stack, mouse_position, player)


func _is_dragging_equipment() -> bool:
	return _dragging_equipment_slot != &"" and not _dragging_equipment_stack.is_empty()


func _clear_equipment_drag() -> void:
	_dragging_equipment_slot = &""
	_dragging_equipment_stack.clear()
	_equipment_drag_position = Vector2.ZERO


func _draw_dragged_equipment_item() -> void:
	var drag_rect := Rect2(_equipment_drag_position - _scaled_slot_size * 0.5, _scaled_slot_size)
	_painter.slot(drag_rect, Color(0.30, 0.45, 0.42, 0.68), Color(0.83, 0.95, 0.90, 0.72))
	_paint_item_label(drag_rect, _dragging_equipment_stack)


func _paint_header(rect: Rect2, text: String) -> void:
	_painter.header(rect, text)


func _paint_item_label(rect: Rect2, stack: Dictionary) -> void:
	var label := _get_stack_display_name(stack)
	var quantity := int(stack.get("quantity", 1))
	_painter.item_label(rect, label, quantity)


func _draw_hover_tooltip(screen_position: Vector2) -> void:
	if _drop_controller.is_dragging() or _is_dragging_equipment() or _is_dragging_weapon_mod() or _is_dragging_quick_slot():
		return
	if _context_menu.is_context_menu_open(backpack_items) or _context_menu.is_split_dialog_open(backpack_items):
		return
	var stack := InventoryEquipmentDisplaySupportScript.stack_at_position(self, screen_position)
	if stack.is_empty():
		return
	InventoryEquipmentDisplaySupportScript.draw_tooltip(self, _painter, screen_position, stack, _ui_scale)


func _current_mouse_position() -> Vector2:
	if not is_inside_tree():
		return _last_mouse_position
	return get_local_mouse_position()


func _tooltip_state_for_stack(stack: Dictionary) -> Dictionary:
	return InventoryEquipmentDisplaySupportScript.tooltip_for_stack(self, stack)


func _get_stack_display_name(stack: Dictionary) -> String:
	return InventoryEquipmentDisplaySupportScript.stack_display_name(self, stack)


func _organize_button_rect_for_backpack(backpack_rect: Rect2) -> Rect2:
	return Rect2(Vector2(backpack_rect.end.x - 112.0 * _ui_scale, backpack_rect.position.y + 7.0 * _ui_scale), Vector2(96.0 * _ui_scale, 32.0 * _ui_scale))


func _store_all_button_rect_for_backpack(backpack_rect: Rect2) -> Rect2:
	var organize_rect := _organize_button_rect_for_backpack(backpack_rect)
	return Rect2(Vector2(organize_rect.position.x - 132.0 * _ui_scale, organize_rect.position.y), Vector2(120.0 * _ui_scale, 32.0 * _ui_scale))


func _sort_button_text() -> String:
	return _localized_text(&"ui.inventory.sort", "整理")


func _store_all_button_text() -> String:
	return _localized_text(&"ui.stash.store_all", "全部存入")


func can_use_backpack_stack(stack_index: int) -> bool:
	if stack_index < 0 or stack_index >= backpack_items.size():
		return false
	return _is_usable_stack(backpack_items[stack_index])


func assign_backpack_stack_to_quick_slot(stack_index: int, key_number: int) -> bool:
	if player == null or not player.has_method("assign_quick_slot_for_inventory_stack"):
		return false
	if stack_index < 0 or stack_index >= backpack_items.size():
		return false
	if not can_use_backpack_stack(stack_index):
		return false
	var assigned := bool(player.call("assign_quick_slot_for_inventory_stack", key_number, stack_index))
	if assigned:
		queue_redraw()
	return assigned


func can_mod_backpack_stack(stack_index: int) -> bool:
	if stack_index < 0 or stack_index >= backpack_items.size():
		return false
	var item_def := _load_item_from_stack(backpack_items[stack_index])
	return item_def != null and item_def.item_type == "weapon" and not item_def.get_weapon_attachment_slots().is_empty()


func _assign_hovered_stack_to_quick_slot(key_number: int) -> bool:
	var stack_index := _get_backpack_stack_index_at(_current_mouse_position())
	return assign_backpack_stack_to_quick_slot(stack_index, key_number)


func _get_quick_slot_state_by_key(key_number: int) -> Dictionary:
	if player == null or not player.has_method("get_quick_bar_state"):
		return {}
	var slots_variant: Variant = player.call("get_quick_bar_state")
	if typeof(slots_variant) != TYPE_ARRAY:
		return {}
	for raw_state in slots_variant as Array:
		if typeof(raw_state) != TYPE_DICTIONARY:
			continue
		var state := raw_state as Dictionary
		if int(state.get("key", -1)) == int(key_number):
			return state
	return {}


func _get_quick_item_key_at(position: Vector2) -> int:
	if player == null or not player.has_method("get_quick_bar_state"):
		return -1
	var slots_variant: Variant = player.call("get_quick_bar_state")
	if typeof(slots_variant) != TYPE_ARRAY:
		return -1
	var slots: Array[Dictionary] = []
	for raw_state in slots_variant as Array:
		if typeof(raw_state) == TYPE_DICTIONARY:
			slots.append(raw_state as Dictionary)
	return PlayerQuickBarLayoutScript.item_key_at_position(size, slots, position)


func _quick_slot_key_for_event(event: InputEventKey) -> int:
	var keycode := event.keycode if event.keycode != KEY_NONE else event.physical_keycode
	match keycode:
		KEY_3:
			return 3
		KEY_4:
			return 4
		KEY_5:
			return 5
		KEY_6:
			return 6
		KEY_7:
			return 7
		KEY_8:
			return 8
		_:
			return -1


func _is_usable_stack(stack: Dictionary) -> bool:
	var item_def := _item_resolver.item_def_from_stack(stack)
	return ItemConsumableServiceScript.is_usable_stack(stack, item_def)


func _weapon_mod_panel_state_for_backpack_stack(stack_index: int) -> Dictionary:
	if stack_index < 0 or stack_index >= backpack_model.stacks.size():
		return {"has_weapon": false, "weapon_slot_id": "backpack_weapon", "slots": []}
	var weapon_stack := backpack_model.stacks[stack_index].duplicate(true)
	var weapon_def := _load_item_from_stack(weapon_stack)
	if weapon_def == null or weapon_def.item_type != "weapon" or weapon_def.get_weapon_attachment_slots().is_empty():
		return {"has_weapon": false, "weapon_slot_id": "backpack_weapon", "slots": []}
	var rows: Array[Dictionary] = []
	for hardpoint in WeaponAttachmentServiceScript.weapon_mod_slot_ids(weapon_def):
		rows.append({
			"slot_id": str(hardpoint),
			"label_key": _weapon_hardpoint_label_key(hardpoint),
			"stack": WeaponAttachmentServiceScript.weapon_mod_stack(weapon_stack, hardpoint),
		})
	var attachment_state := WeaponAttachmentServiceScript.modifiers_for_weapon_stack(weapon_stack, weapon_def)
	return {
		"has_weapon": true,
		"weapon_slot_id": "backpack_weapon",
		"weapon_stack": weapon_stack,
		"description_key": weapon_def.description_key,
		"stat_rows": _weapon_stat_rows_for_stack(weapon_stack, weapon_def, attachment_state),
		"attachment_state": attachment_state.duplicate(true),
		"slots": rows,
	}


func _weapon_stat_rows_for_stack(weapon_stack: Dictionary, weapon_def: ItemDef, attachment_state: Dictionary) -> Array[Dictionary]:
	var snapshot := WeaponTuningServiceScript.resolve_snapshot(weapon_def, null, attachment_state, weapon_stack)
	var durability: Dictionary = snapshot.get("durability", {}) as Dictionary
	var base_capacity := maxi(int(snapshot.get("base_magazine_capacity", 0)), 0)
	var capacity_bonus := maxi(int(snapshot.get("magazine_capacity_bonus", 0)), 0)
	var current_durability := int(durability.get("current_durability", 0))
	var max_durability := int(durability.get("max_durability", 0))
	var capacity_text := str(base_capacity + capacity_bonus)
	if capacity_bonus > 0:
		capacity_text = "%d (%d+%d)" % [base_capacity + capacity_bonus, base_capacity, capacity_bonus]
	return [
		{"label_key": &"ui.weapon_stat.damage", "value": "%.1f" % maxf(float(snapshot.get("damage", 0.0)), 0.0)},
		{"label_key": &"ui.weapon_stat.fire_rate", "value": "%.1f" % maxf(float(snapshot.get("fire_rate_per_second", 0.0)), 0.0)},
		{"label_key": &"ui.weapon_stat.armor_penetration", "value": "%.1f" % maxf(float(snapshot.get("armor_penetration_level", 0.0)), 0.0)},
		{"label_key": &"ui.weapon_stat.critical_chance", "value": "%.0f%%" % clampf(float(snapshot.get("critical_chance", 0.0)), 0.0, 100.0)},
		{"label_key": &"ui.weapon_stat.projectile_pierce_chance", "value": "%.0f%%" % clampf(float(snapshot.get("projectile_pierce_chance", 0.0)), 0.0, 100.0)},
		{"label_key": &"ui.weapon_stat.magazine_capacity", "value": capacity_text},
		{"label_key": &"ui.weapon_stat.reload_duration", "value": "%.2f" % maxf(float(snapshot.get("reload_duration_seconds", 0.0)), 0.0)},
		{"label_key": &"ui.weapon_stat.recoil_angle", "value": "V%.1f / H%.1f" % [maxf(float(snapshot.get("vertical_recoil", 0.0)), 0.0), maxf(float(snapshot.get("horizontal_recoil", 0.0)), 0.0)]},
		{"label_key": &"ui.weapon_stat.projectile_range", "value": "%.1f" % maxf(float(snapshot.get("projectile_range_meters", 0.0)), 0.0)},
		{"label_key": &"ui.weapon_stat.durability_wear", "value": "%.2f" % maxf(float(snapshot.get("durability_wear_per_shot", 0.0)), 0.0)},
		{"label_key": &"ui.weapon_stat.durability", "value": "%d/%d" % [current_durability, max_durability]},
	]


func _weapon_hardpoint_label_key(hardpoint: StringName) -> StringName:
	match hardpoint:
		&"magazine":
			return StringName("ui.equipment.weapon_%s" % "mag")
		&"grip":
			return StringName("ui.equipment.weapon_%s" % "grip")
		&"muzzle":
			return StringName("ui.equipment.weapon_%s" % "muzzle")
		&"scope":
			return StringName("ui.equipment.weapon_%s" % "scope")
		&"stock":
			return StringName("ui.equipment.weapon_%s" % "stock")
		&"tactic":
			return StringName("ui.equipment.weapon_%s" % "tactic")
		_:
			return &""


func _load_item_from_stack(stack: Dictionary) -> ItemDef:
	var item_path := str(stack.get("resource_path", stack.get("item_path", ""))).strip_edges()
	if item_path == "" or not ResourceLoader.exists(item_path):
		return null
	return load(item_path) as ItemDef


func _localized_text(key: StringName, fallback: String) -> String:
	return InventoryEquipmentDisplaySupportScript.localized_text(self, key, fallback)


func _connect_save_manager() -> void:
	var save_manager := _get_save_manager()
	if save_manager == null or not save_manager.has_signal("slot_saved"):
		return
	var callback := Callable(self, "_on_slot_saved")
	if not save_manager.is_connected("slot_saved", callback):
		save_manager.connect("slot_saved", callback)


func _on_slot_saved(_slot_index: int, _save_data: Dictionary) -> void:
	_refresh_money()
	queue_redraw()


func _refresh_money() -> void:
	var save_money := 0
	var save_manager := _get_save_manager()
	if save_manager != null and save_manager.has_method("get_current_slot_index") and save_manager.has_method("get_slot_data"):
		var slot_index := int(save_manager.call("get_current_slot_index"))
		var save_data: Dictionary = save_manager.call("get_slot_data", slot_index)
		save_money = int(save_data.get("money", 0))
	money = maxi(save_money + InventoryEquipmentDisplaySupportScript.cash_value(backpack_items) + InventoryEquipmentDisplaySupportScript.cash_value(safe_pocket_items), 0)


func _get_save_manager() -> Node:
	if not is_inside_tree():
		return null
	var manager := get_node_or_null("/root/SaveGameManager")
	if manager != null:
		return manager
	var tree := get_tree()
	if tree != null:
		return tree.root.get_node_or_null("SaveGameManager")
	return null


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
	var current_weight: Variant = player.get("current_carry_weight") if player != null else null
	if typeof(current_weight) == TYPE_FLOAT or typeof(current_weight) == TYPE_INT:
		return float(current_weight)
	return backpack_model.get_total_weight() + safe_pocket_model.get_total_weight()


func _weight_label_text() -> String:
	return _localized_text(&"ui.inventory.load", "")


func _weight_value_text() -> String:
	return "%.1f/%.0fkg" % [_get_current_weight(), _get_carry_weight_limit()]


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
