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
const ItemDetailPanelPresenterScript := preload("res://scripts/ui/item_detail_panel_presenter.gd")
const InventoryEquipmentDisplaySupportScript := preload("res://scripts/ui/inventory_equipment_display_support.gd")
const InventoryEquipmentPanelPainterScript := preload("res://scripts/ui/inventory_equipment_panel_painter.gd")
const InventoryEquipmentDragSupportScript := preload("res://scripts/ui/inventory_equipment_drag_support.gd")
const InventoryEquipmentActionSupportScript := preload("res://scripts/ui/inventory_equipment_action_support.gd")
const InventoryEquipmentInputRouterScript := preload("res://scripts/ui/inventory_equipment_input_router.gd")
const WeaponModPanelStateBuilderScript := preload("res://scripts/ui/weapon_mod_panel_state_builder.gd")
const ItemConsumableServiceScript := preload("res://scripts/items/item_consumable_service.gd")
const UISurfacePaletteScript := preload("res://scripts/ui/ui_surface_palette.gd")

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
var _overlay_scrim_visible: bool = true
var _ui_scale: float = 1.0
var _scaled_slot_size: Vector2 = Vector2.ZERO
var _scaled_slot_gap: float = 0.0
var _layout := InventoryLayoutScript.new()
var _painter := InventoryPainterScript.new(self)
var _item_resolver := InventoryItemResolverScript.new()
var _drop_controller := InventoryDropControllerScript.new()
var _context_menu := InventoryContextMenuScript.new()
var _weapon_mod_panel := WeaponModPanelPresenterScript.new()
var _item_detail_panel := ItemDetailPanelPresenterScript.new()
var _last_mouse_position: Vector2 = Vector2.ZERO
var _layout_viewport_size: Vector2 = Vector2(1920.0, 1080.0)
var _drag_support: InventoryEquipmentDragSupport = InventoryEquipmentDragSupportScript.new(self)
var _action_support: InventoryEquipmentActionSupport = InventoryEquipmentActionSupportScript.new(self)
var _input_router: InventoryEquipmentInputRouter = InventoryEquipmentInputRouterScript.new(self)
var _weapon_mod_backpack_stack_index: int = -1
var _item_def_cache_by_path: Dictionary = {}


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
	_context_menu.unload_ammo_requested.connect(_on_context_unload_ammo_requested)
	_context_menu.drop_requested.connect(_on_context_drop_requested)
	_context_menu.equipment_unload_ammo_requested.connect(_on_context_equipment_unload_ammo_requested)
	_context_menu.equipment_drop_requested.connect(_on_context_equipment_drop_requested)
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
			if scroll_weapon_mod_details_at(event.position, 1):
				get_viewport().set_input_as_handled()
				return
			_scroll_backpack(1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if scroll_weapon_mod_details_at(event.position, -1):
				get_viewport().set_input_as_handled()
				return
			_scroll_backpack(-1)
			get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	_input_router.handle_gui_input(event)


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


func set_overlay_scrim_visible(should_show: bool) -> void:
	_overlay_scrim_visible = should_show
	queue_redraw()


func scroll_weapon_mod_details_at(screen_position: Vector2, direction: int) -> bool:
	_update_layout_scale(get_viewport_rect().size if is_inside_tree() else size)
	if not _weapon_mod_panel.has_point(screen_position, _ui_scale, _layout_viewport_size):
		return false
	_weapon_mod_panel.scroll_details(direction, _ui_scale, _layout_viewport_size)
	queue_redraw()
	return true


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
	return InventoryEquipmentDisplaySupportScript.build_owner_state(self, viewport_size, _layout, _weapon_mod_panel, _item_detail_panel, backpack_model, safe_pocket_model)


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
	_close_item_detail_panel()


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

	if _overlay_scrim_visible:
		draw_rect(Rect2(Vector2.ZERO, viewport_size), UISurfacePaletteScript.overlay_scrim())
	InventoryEquipmentPanelPainterScript.paint_shell(self, _painter, panel_rect)
	InventoryEquipmentPanelPainterScript.paint_currency(self, _painter, money_rect, "$", money, _ui_scale)
	_paint_equipment_panel(equipment_rect)
	InventoryEquipmentPanelPainterScript.paint_backpack(self, _painter, backpack_rect, _ui_scale)
	InventoryEquipmentPanelPainterScript.paint_weight(self, _painter, weight_rect, _ui_scale)
	if _layout.can_show_safe_pocket(safe_rect, viewport_size):
		_paint_safe_pocket_panel(safe_rect)
	_draw_item_detail_panel()
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
	_painter.panel(Rect2(rect.position + _v(8.0, 8.0), rect.size), UISurfacePaletteScript.shadow(), UISurfacePaletteScript.TRANSPARENT, 0, 18)
	_painter.panel(rect, UISurfacePaletteScript.panel_fill(), UISurfacePaletteScript.panel_border(), 1, 18)
	_paint_header(Rect2(rect.position + _v(12.0, 8.0), Vector2(rect.size.x - 24.0 * _ui_scale, 28.0 * _ui_scale)), _localized_text(&"ui.inventory.safe_pocket", ""))
	for index in range(_get_safe_pocket_slots()):
		var pocket_slot := _safe_pocket_slot_rect(rect, index)
		_painter.slot(pocket_slot, UISurfacePaletteScript.slot_fill(&"safe"), UISurfacePaletteScript.slot_border())
		if index < safe_pocket_items.size():
			_paint_item_label(pocket_slot, safe_pocket_items[index])


func _paint_equipment_panel(rect: Rect2) -> void:
	_paint_header(Rect2(rect.position, Vector2(rect.size.x, 36.0 * _ui_scale)), _localized_text(&"ui.inventory.equipment", ""))
	for index in range(equipment_slot_label_keys.size()):
		var slot_rect := _equipment_slot_rect(rect, index)
		_painter.slot(slot_rect, UISurfacePaletteScript.slot_fill(&"equipment"), UISurfacePaletteScript.slot_border())
		_painter.equipment_icon(slot_rect, index)
		var equipped_stack := _get_equipment_stack_at(index)
		if not equipped_stack.is_empty():
			_paint_item_label(slot_rect, equipped_stack)
		_painter.text(_localized_text(equipment_slot_label_keys[index], ""), slot_rect.position + Vector2(0.0, slot_rect.size.y + 22.0 * _ui_scale), 18, UISurfacePaletteScript.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_CENTER, slot_rect.size.x)


func _draw_weapon_mod_panel() -> void:
	_weapon_mod_panel.draw(self, _painter, _ui_scale, _layout_viewport_size)


func _draw_item_detail_panel() -> void:
	_item_detail_panel.draw(self, _painter, _ui_scale, _layout_viewport_size)


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
	_action_support.context_drop(stack_index, stack, screen_position, random_near_player)


func _on_context_use_requested(stack_index: int) -> void:
	_action_support.context_use(stack_index)


func _on_context_unload_ammo_requested(stack_index: int) -> void:
	_action_support.context_unload_ammo(stack_index)


func _on_context_equipment_unload_ammo_requested(slot_id: StringName) -> void:
	_action_support.context_equipment_unload_ammo(slot_id)


func _on_context_equipment_drop_requested(slot_id: StringName, screen_position: Vector2) -> void:
	_action_support.context_equipment_drop(slot_id, screen_position)


func _unequip_equipment_slot(slot_id: StringName) -> bool:
	return _action_support.unequip_equipment_slot(slot_id)


func _open_weapon_mod_panel_for_backpack_stack(stack_index: int) -> bool:
	return _action_support.open_weapon_mod_panel_for_backpack_stack(stack_index)


func _open_weapon_mod_panel_for_slot(slot_id: StringName) -> bool:
	return _action_support.open_weapon_mod_panel_for_slot(slot_id)


func _open_item_detail_panel_for_stack(stack: Dictionary) -> bool:
	return _action_support.open_item_detail_panel_for_stack(stack)


func _close_weapon_mod_panel() -> void:
	_action_support.close_weapon_mod_panel()


func _close_item_detail_panel() -> void:
	_action_support.close_item_detail_panel()


func _refresh_weapon_mod_panel_state() -> void:
	_action_support.refresh_weapon_mod_panel_state()


func _attach_dragged_stack_to_open_weapon_hardpoint(hardpoint_slot: StringName) -> bool:
	return _action_support.attach_dragged_stack_to_open_weapon_hardpoint(hardpoint_slot)


func _attach_dragged_stack_to_backpack_weapon_hardpoint(hardpoint_slot: StringName) -> bool:
	return _action_support.attach_dragged_stack_to_backpack_weapon_hardpoint(hardpoint_slot)


func _handle_weapon_mod_panel_click(screen_position: Vector2) -> bool:
	return _action_support.handle_weapon_mod_panel_click(screen_position)


func _unload_backpack_weapon_ammo_to_backpack(weapon_index: int) -> bool:
	return _action_support.unload_backpack_weapon_ammo_to_backpack(weapon_index)


func _unload_equipment_weapon_ammo_to_backpack(slot_id: StringName) -> bool:
	return _action_support.unload_equipment_weapon_ammo_to_backpack(slot_id)


func _get_weapon_mod_slot_id_at(screen_position: Vector2) -> StringName:
	return _action_support.get_weapon_mod_slot_id_at(screen_position)


func _move_safe_pocket_stack_to_backpack(stack_index: int) -> bool:
	return _action_support.move_safe_pocket_stack_to_backpack(stack_index)


func _start_weapon_mod_drag(hardpoint_slot: StringName, mouse_position: Vector2) -> bool:
	return _drag_support.start_weapon_mod_drag(hardpoint_slot, mouse_position)


func _update_weapon_mod_drag(mouse_position: Vector2) -> void:
	_drag_support.update_weapon_mod_drag(mouse_position)


func _finish_weapon_mod_drag(mouse_position: Vector2) -> bool:
	return _drag_support.finish_weapon_mod_drag(mouse_position)


func _unequip_dragged_weapon_mod_to_backpack() -> bool:
	return _drag_support.unequip_dragged_weapon_mod_to_backpack()


func _weapon_mod_stack_for_slot(hardpoint_slot: StringName) -> Dictionary:
	var slots: Array = _weapon_mod_panel.state.get("slots", []) as Array
	for row_value in slots:
		var row := row_value as Dictionary
		if StringName(str(row.get("slot_id", ""))) == hardpoint_slot:
			return row.get("stack", {}) as Dictionary
	return {}


func _is_dragging_weapon_mod() -> bool:
	return _drag_support.is_dragging_weapon_mod()


func _clear_weapon_mod_drag() -> void:
	_drag_support.clear_weapon_mod_drag()


func _draw_dragged_weapon_mod_item() -> void:
	_drag_support.draw_dragged_weapon_mod_item()


func _start_quick_slot_drag(quick_key: int, mouse_position: Vector2) -> bool:
	return _drag_support.start_quick_slot_drag(quick_key, mouse_position)


func _update_quick_slot_drag(mouse_position: Vector2) -> void:
	_drag_support.update_quick_slot_drag(mouse_position)


func _finish_quick_slot_drag(mouse_position: Vector2) -> bool:
	return _drag_support.finish_quick_slot_drag(mouse_position)


func _clear_quick_slot_drag() -> void:
	_drag_support.clear_quick_slot_drag()


func _is_dragging_quick_slot() -> bool:
	return _drag_support.is_dragging_quick_slot()


func _draw_dragged_quick_slot_item() -> void:
	_drag_support.draw_dragged_quick_slot_item()


func _start_equipment_drag(slot_id: StringName, mouse_position: Vector2) -> bool:
	return _drag_support.start_equipment_drag(slot_id, mouse_position)


func _update_equipment_drag(mouse_position: Vector2) -> void:
	_drag_support.update_equipment_drag(mouse_position)


func _finish_equipment_drag(mouse_position: Vector2) -> bool:
	return _drag_support.finish_equipment_drag(mouse_position)


func _unequip_dragged_equipment_to_backpack() -> bool:
	return _drag_support.unequip_dragged_equipment_to_backpack()


func _move_dragged_equipment_to_equipment_slot(target_slot: StringName) -> bool:
	return _drag_support.move_dragged_equipment_to_equipment_slot(target_slot)


func _drop_dragged_equipment_to_world(mouse_position: Vector2) -> bool:
	return _drag_support.drop_dragged_equipment_to_world(mouse_position)


func _is_dragging_equipment() -> bool:
	return _drag_support.is_dragging_equipment()


func _clear_equipment_drag() -> void:
	_drag_support.clear_equipment_drag()


func _draw_dragged_equipment_item() -> void:
	_drag_support.draw_dragged_equipment_item()


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


func is_backpack_weapon_stack(stack_index: int) -> bool:
	if stack_index < 0 or stack_index >= backpack_model.stacks.size():
		return false
	var item_def := _load_item_from_stack(backpack_model.stacks[stack_index])
	return item_def != null and item_def.item_type == "weapon"


func can_unload_backpack_weapon_ammo(stack_index: int) -> bool:
	if stack_index < 0 or stack_index >= backpack_model.stacks.size():
		return false
	var weapon_stack := backpack_model.stacks[stack_index]
	var ammo_state: Dictionary = weapon_stack.get("weapon_ammo_state", {}) as Dictionary
	var loaded_count := maxi(int(ammo_state.get("loaded_ammo", 0)), 0)
	var ammo_item := _load_ammo_item_from_weapon_state(ammo_state)
	return loaded_count > 0 and ammo_item != null and backpack_model.can_accept_stack(ammo_item.to_stack(loaded_count))


func can_unload_equipment_weapon_ammo(slot_id: StringName) -> bool:
	if player == null or not player.has_method("get_weapon_mod_panel_state"):
		return false
	if slot_id != &"primary_weapon" and slot_id != &"sidearm":
		return false
	var state: Dictionary = player.call("get_weapon_mod_panel_state", slot_id)
	return bool(state.get("can_unload_ammo", false)) and int(state.get("loaded_ammo", 0)) > 0


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
	return WeaponModPanelStateBuilderScript.build(weapon_stack, weapon_def, &"backpack_weapon")


func _load_ammo_item_from_weapon_state(ammo_state: Dictionary) -> ItemDef:
	var ammo_path := str(ammo_state.get("ammo_item_path", "")).strip_edges()
	if ammo_path == "" or not ResourceLoader.exists(ammo_path):
		return null
	var item_def := load(ammo_path) as ItemDef
	if item_def == null or item_def.item_type != "ammo":
		return null
	return item_def


func _load_item_from_stack(stack: Dictionary) -> ItemDef:
	var item_path := str(stack.get("resource_path", stack.get("item_path", ""))).strip_edges()
	if item_path == "":
		return null
	if _item_def_cache_by_path.has(item_path):
		return _item_def_cache_by_path.get(item_path, null) as ItemDef
	if not ResourceLoader.exists(item_path):
		return null
	var item_def := load(item_path) as ItemDef
	if item_def != null:
		_item_def_cache_by_path[item_path] = item_def
	return item_def


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
	if player != null and player.has_method("get_current_carry_weight"):
		return float(player.call("get_current_carry_weight"))
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


func _equipment_stack_for_slot(slot_id: StringName) -> Dictionary:
	if equipment_model == null or slot_id == &"" or not equipment_model.has_method("get_slot"):
		return {}
	return equipment_model.call("get_slot", slot_id)


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
