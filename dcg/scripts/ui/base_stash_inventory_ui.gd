class_name BaseStashInventoryUI
extends Control

const StashModelScript := preload("res://scripts/base/stash_model.gd")
const BaseProgressionScript := preload("res://scripts/base/base_progression.gd")
const StashCurrencyServiceScript := preload("res://scripts/base/stash_currency_service.gd")
const BaseNeededItemServiceScript := preload("res://scripts/base/base_needed_item_service.gd")
const BaseStorageUpgradeServiceScript := preload("res://scripts/base/base_storage_upgrade_service.gd")
const InventoryLayoutScript := preload("res://scripts/ui/inventory_equipment_layout.gd")
const InventoryPainterScript := preload("res://scripts/ui/inventory_equipment_painter.gd")
const ItemStackTooltipPresenterScript := preload("res://scripts/ui/item_stack_tooltip_presenter.gd")
const ItemCodexCatalogScript := preload("res://scripts/ui/item_codex_catalog.gd")
const ItemCodexPresenterScript := preload("res://scripts/ui/item_codex_presenter.gd")
const ItemDetailPanelPresenterScript := preload("res://scripts/ui/item_detail_panel_presenter.gd")
const WeaponModPanelPresenterScript := preload("res://scripts/ui/weapon_mod_panel_presenter.gd")
const ItemStackSorterScript := preload("res://scripts/inventory/item_stack_sorter.gd")
const InventoryGridMetricsScript := preload("res://scripts/ui/inventory_grid_metrics.gd")
const WeaponModPanelStateBuilderScript := preload("res://scripts/ui/weapon_mod_panel_state_builder.gd")
const BaseStashInventoryMarkerSupportScript := preload("res://scripts/ui/base_stash_inventory_marker_support.gd")
const BaseStashInventoryReferenceSupportScript := preload("res://scripts/ui/base_stash_inventory_reference_support.gd")
const BaseStashInventoryLayoutSupportScript := preload("res://scripts/ui/base_stash_inventory_layout_support.gd")
const BaseStashInventoryPainterSupportScript := preload("res://scripts/ui/base_stash_inventory_painter_support.gd")
const BaseStashInventoryCategorySupportScript := preload("res://scripts/ui/base_stash_inventory_category_support.gd")
const BaseStashInventoryTransferSupportScript := preload("res://scripts/ui/base_stash_inventory_transfer_support.gd")
const StashCurrencyTransferDialogScript := preload("res://scripts/ui/stash_currency_transfer_dialog.gd")
const UISurfacePaletteScript := preload("res://scripts/ui/ui_surface_palette.gd")

# 基地倉庫 UI 負責開關狀態、輸入協調與對外 API。
# 標記紀錄、Tab 背包鏡像、版面計算、繪製與物品轉移流程
# 交給共用輔助腳本，避免主面板繼續累積不相干責任。
@export var stash_capacity: int = 250
@export var grid_columns: int = 5
@export var visible_stash_rows: int = 8
@export var visible_backpack_rows: int = 4
@export var slot_size: Vector2 = Vector2(75.0, 75.0)
@export var slot_gap: float = 12.0

var player: Node = null
var save_manager: Node = null
var backpack_model := InventoryModel.new()
var safe_pocket_model := InventoryModel.new()
var equipment_model: RefCounted = null
var stash_model := StashModelScript.new()
var backpack_items: Array[Dictionary] = []
var safe_pocket_items: Array[Dictionary] = []
var stash_items: Array[Dictionary] = []
var filtered_stash_items: Array[Dictionary] = []
var filtered_stash_source_indices: Array[int] = []
var backpack_scroll_row: int = 0
var stash_scroll_row: int = 0
var locked_backpack_slots: Dictionary = {}
var locked_safe_pocket_slots: Dictionary = {}
var locked_equipment_slots: Dictionary = {}
var locked_stash_slots: Dictionary = {}
var _base_stash_capacity: int = 0
var _forwarding_inventory_reference_drag := false
var _storage_upgrade_state: Dictionary = {}
var _needed_item_state: Dictionary = {}
var _needed_item_paths: Dictionary = {}
var _next_sort_mode: StringName = &"value"
var _active_stash_category_id := "all"
var _stash_category_counts: Dictionary = {}
var _stash_money := 0
var _wallet_money := 0

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

var _is_open: bool = false
var _status_key: StringName = &"ui.stash.ready"
var _ui_scale: float = 1.0
var _scaled_slot_size: Vector2 = Vector2.ZERO
var _scaled_slot_gap: float = 0.0
var _last_mouse_position: Vector2 = Vector2.ZERO
var _inventory_layout := InventoryLayoutScript.new()
var _inventory_ui: Control = null
var _opened_inventory_reference := false
var _painter := InventoryPainterScript.new(self)
var _item_codex_catalog := ItemCodexCatalogScript.new()
var _item_detail_panel := ItemDetailPanelPresenterScript.new()
var _weapon_mod_panel := WeaponModPanelPresenterScript.new()
var _weapon_mod_stash_stack_index: int = -1
var _currency_transfer_dialog := StashCurrencyTransferDialogScript.new()


func _ready() -> void:
	_base_stash_capacity = stash_capacity
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not stash_model.changed.is_connected(_on_stash_changed):
		stash_model.changed.connect(_on_stash_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _currency_transfer_dialog.is_open():
				_currency_transfer_dialog.close()
				queue_redraw()
				get_viewport().set_input_as_handled()
				return
			_request_managed_close()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_L and toggle_lock_at_position(_current_mouse_position()):
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_N and toggle_needed_item_at_position(_current_mouse_position()):
			get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if _currency_transfer_dialog.is_open():
		if event is InputEventMouseMotion:
			_last_mouse_position = event.position
			if _currency_transfer_dialog.handle_mouse_motion(event):
				queue_redraw()
			accept_event()
			return
		if event is InputEventMouseButton:
			var dialog_mouse_event := event as InputEventMouseButton
			_last_mouse_position = dialog_mouse_event.position
			var dialog_result := _currency_transfer_dialog.handle_mouse_button(dialog_mouse_event)
			if not dialog_result.is_empty():
				_match_currency_transfer_dialog_action(dialog_result)
				accept_event()
				return
			if dialog_mouse_event.button_index == MOUSE_BUTTON_LEFT:
				accept_event()
				return
	if event is InputEventMouseMotion:
		_last_mouse_position = event.position
		_forward_inventory_reference_mouse_event(event)
		if _forwarding_inventory_reference_drag:
			accept_event()
			return
		queue_redraw()
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		_last_mouse_position = mouse_event.position
		if not mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and _forwarding_inventory_reference_drag:
			_forward_inventory_reference_mouse_event(mouse_event)
			_forwarding_inventory_reference_drag = false
			accept_event()
			return
		if mouse_event.pressed and (mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN or mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP):
			_handle_scroll(mouse_event)
			accept_event()
			return
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if _handle_left_click(mouse_event):
				accept_event()


func open_stash(source_player: Node = null, source_save_manager: Node = null) -> bool:
	player = source_player if source_player != null else _find_player()
	save_manager = source_save_manager if source_save_manager != null else _find_save_manager()
	_item_codex_catalog.reload()
	_active_stash_category_id = "all"
	_bind_models()
	_load_stash_from_save()
	_refresh_stash_money()
	backpack_scroll_row = 0
	stash_scroll_row = 0
	_item_detail_panel.close()
	_close_weapon_mod_panel()
	_currency_transfer_dialog.close()
	# 左側使用一般 Tab 背包介面；這個面板只繪製右側倉庫，
	# 並把需要共用的背包操作轉交給該背包 UI。
	_open_inventory_reference()
	_sync_inventory_reference_scroll()
	_configure_inventory_reference_actions(true)
	_status_key = &"ui.stash.ready"
	_is_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	queue_redraw()
	return true


func close_stash(close_inventory_reference: bool = true, update_ui_manager: bool = true) -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_detail_panel.close()
	_close_weapon_mod_panel()
	_currency_transfer_dialog.close()
	_close_inventory_reference(close_inventory_reference)
	queue_redraw()
	if update_ui_manager:
		_sync_managed_close_state()


func is_open() -> bool:
	return _is_open


func store_backpack_stack(stack_index: int) -> bool:
	return BaseStashInventoryTransferSupportScript.store_backpack_stack(self, stack_index)


func store_all_backpack_items() -> Dictionary:
	return BaseStashInventoryTransferSupportScript.store_all_backpack_items(self)


func purchase_storage_expansion() -> Dictionary:
	var result: Dictionary = BaseStorageUpgradeServiceScript.purchase(save_manager)
	if bool(result.get("success", false)):
		_status_key = &"ui.stash.storage_upgrade_done"
		_load_stash_from_save()
	else:
		_status_key = _storage_upgrade_failure_status(str(result.get("reason", "unknown")))
		_refresh_storage_upgrade_state()
		_refresh_needed_item_state()
	queue_redraw()
	return result


func toggle_backpack_lock(stack_index: int) -> bool:
	if stack_index < 0 or stack_index >= backpack_items.size():
		return false
	return _toggle_lock(locked_backpack_slots, stack_index)


func store_safe_pocket_stack(stack_index: int) -> bool:
	return BaseStashInventoryTransferSupportScript.store_safe_pocket_stack(self, stack_index)


func store_equipment_slot(slot_id: StringName) -> bool:
	return BaseStashInventoryTransferSupportScript.store_equipment_slot(self, slot_id)


func withdraw_stash_stack(stack_index: int) -> bool:
	return BaseStashInventoryTransferSupportScript.withdraw_stash_stack(self, stack_index)


func withdraw_stash_stack_to_equipment_or_backpack(stack_index: int) -> bool:
	return BaseStashInventoryTransferSupportScript.withdraw_stash_stack_to_equipment_or_backpack(self, stack_index)


func organize_stash(sort_mode: StringName = &"") -> void:
	var selected_mode := _consume_sort_mode(sort_mode)
	stash_model.organize(selected_mode)
	_save_stash()
	_status_key = _sort_status_key(selected_mode)
	locked_stash_slots.clear()
	_on_stash_changed()


func open_currency_deposit() -> bool:
	return _open_currency_transfer(StashCurrencyTransferDialogScript.MODE_DEPOSIT, _wallet_money)


func open_currency_withdraw() -> bool:
	return _open_currency_transfer(StashCurrencyTransferDialogScript.MODE_WITHDRAW, _stash_money)


func _open_currency_transfer(mode: StringName, source_amount: int) -> bool:
	if not _currency_transfer_dialog.open_transfer(mode, source_amount):
		_status_key = &"ui.stash.money_source_empty"
		queue_redraw()
		return false
	_close_item_detail_panel()
	_close_weapon_mod_panel()
	queue_redraw()
	return true


func _match_currency_transfer_dialog_action(action: Dictionary) -> void:
	match str(action.get("action", "")):
		"confirm":
			var amount := int(action.get("amount", 0))
			var mode := StringName(str(action.get("mode", "")))
			var result := StashCurrencyServiceScript.deposit(save_manager, amount) if mode == StashCurrencyTransferDialogScript.MODE_DEPOSIT else StashCurrencyServiceScript.withdraw(save_manager, amount)
			_apply_stash_currency_result(result, &"ui.stash.money_deposited" if mode == StashCurrencyTransferDialogScript.MODE_DEPOSIT else &"ui.stash.money_withdrawn")
			_currency_transfer_dialog.close()
		"cancel":
			_currency_transfer_dialog.close()
			queue_redraw()


func select_stash_category(category_id: String) -> bool:
	if not BaseStashInventoryCategorySupportScript.category_ids().has(category_id):
		return false
	_active_stash_category_id = category_id
	stash_scroll_row = 0
	_close_item_detail_panel()
	_close_weapon_mod_panel()
	_refresh_stash_filter()
	queue_redraw()
	return true


func toggle_lock_at_position(position: Vector2) -> bool:
	if not _is_open:
		return false
	var viewport_size := get_viewport_rect().size
	_update_layout_scale(viewport_size)
	var left_rect := _left_panel_rect(viewport_size)
	var right_rect := _right_panel_rect(viewport_size)
	var safe_index := _safe_pocket_index_at(position, left_rect)
	if safe_index >= 0 and safe_index < safe_pocket_items.size():
		return _toggle_lock(locked_safe_pocket_slots, safe_index)
	var backpack_index := _backpack_index_at(position, left_rect)
	if backpack_index >= 0 and backpack_index < backpack_items.size():
		return _toggle_lock(locked_backpack_slots, backpack_index)
	var equipment_index := _equipment_index_at(position, left_rect)
	if equipment_index >= 0:
		return _toggle_lock(locked_equipment_slots, str(equipment_slot_ids[equipment_index]))
	var stash_index := _stash_index_at(position, right_rect)
	if stash_index >= 0 and stash_index < stash_items.size():
		return _toggle_lock(locked_stash_slots, stash_index)
	return false


func toggle_needed_item_at_position(position: Vector2) -> bool:
	if not _is_open:
		return false
	var stack := _stack_at_position(position)
	if stack.is_empty():
		return false
	return toggle_needed_item_by_path(BaseStashInventoryMarkerSupportScript.stack_item_path(stack))


func toggle_needed_item_by_path(item_path: String) -> bool:
	var normalized_path := item_path.strip_edges()
	if normalized_path == "":
		return false
	var result: Dictionary = BaseNeededItemServiceScript.toggle_manual_mark(save_manager, normalized_path)
	if not bool(result.get("success", false)):
		_status_key = &"ui.stash.save_failed"
		queue_redraw()
		return false
	_needed_item_state = result.get("state", {}) as Dictionary
	_needed_item_paths = BaseStashInventoryMarkerSupportScript.path_array_to_map(_needed_item_state.get("item_paths", []) as Array)
	_status_key = &"ui.stash.needed_marked" if bool(result.get("is_marked", false)) else &"ui.stash.needed_unmarked"
	queue_redraw()
	return true


func get_display_state() -> Dictionary:
	var viewport_size := get_viewport_rect().size if is_inside_tree() else Vector2(1920.0, 1080.0)
	return get_display_state_for_viewport(viewport_size)


func get_display_state_for_viewport(viewport_size: Vector2) -> Dictionary:
	_update_layout_scale(viewport_size)
	var left_rect := _left_panel_rect(viewport_size)
	var right_rect := _right_panel_rect(viewport_size)
	# 驗證工具與輕量測試會把這份狀態當成穩定 UI 契約。
	# 若之後調整本面板直接繪製的內容，請同步維護這些角色旗標。
	return {
		"visible": visible,
		"is_open": _is_open,
		"title": _stash_title_text(),
		"status_text": _status_text(),
		"backpack_items": backpack_items.duplicate(true),
		"safe_pocket_items": safe_pocket_items.duplicate(true),
		"stash_items": stash_items.duplicate(true),
		"visible_stash_items": filtered_stash_items.duplicate(true),
		"visible_stash_source_indices": filtered_stash_source_indices.duplicate(),
		"stash_category_id": _active_stash_category_id,
		"stash_category_counts": _stash_category_counts.duplicate(true),
		"stash_category_tabs": _stash_category_tabs(right_rect),
		"left_panel_role": "tab_inventory_reference",
		"right_panel_role": "warehouse",
		"uses_tab_inventory_surface": true,
		"draws_left_transfer_panel": false,
		"dims_inventory_surface": false,
		"equipment_surface_visible": true,
		"store_all_button_visible": false,
		"sort_button_visible": true,
		"storage_upgrade_button_visible": false,
		"stash_hint_visible": false,
		"stash_status_visible": false,
		"stash_used": stash_model.get_stack_count(),
		"stash_capacity": stash_capacity,
		"visible_stash_rows": visible_stash_rows,
		"stash_money": _stash_money,
		"wallet_money": _wallet_money,
		"base_stash_capacity": _base_stash_capacity,
		"stash_capacity_bonus": maxi(stash_capacity - _base_stash_capacity, 0),
		"storage_upgrade_state": _storage_upgrade_state.duplicate(true),
		"backpack_used": backpack_model.get_used_slots(),
		"backpack_slots": _get_backpack_slots(),
		"safe_pocket_used": safe_pocket_model.get_used_slots(),
		"safe_pocket_slots": _get_safe_pocket_slots(),
		"equipment_slots": _get_equipment_slots_state(),
		"locked_backpack_slots": BaseStashInventoryMarkerSupportScript.locked_index_array(locked_backpack_slots),
		"locked_safe_pocket_slots": BaseStashInventoryMarkerSupportScript.locked_index_array(locked_safe_pocket_slots),
		"locked_stash_slots": BaseStashInventoryMarkerSupportScript.locked_index_array(locked_stash_slots),
		"locked_equipment_slots": BaseStashInventoryMarkerSupportScript.locked_string_array(locked_equipment_slots),
		"next_sort_mode": str(_next_sort_mode),
		"sort_button_text": _localized_text(&"ui.stash.sort", "Sort"),
		"needed_item_paths": BaseStashInventoryMarkerSupportScript.path_array(_needed_item_state.get("item_paths", []) as Array),
		"automatic_needed_item_paths": BaseStashInventoryMarkerSupportScript.path_array(_needed_item_state.get("automatic_item_paths", []) as Array),
		"upgrade_needed_item_paths": BaseStashInventoryMarkerSupportScript.path_array(_needed_item_state.get("upgrade_item_paths", []) as Array),
		"storage_upgrade_needed_item_paths": BaseStashInventoryMarkerSupportScript.path_array(_needed_item_state.get("storage_upgrade_item_paths", []) as Array),
		"workbench_needed_item_paths": BaseStashInventoryMarkerSupportScript.path_array(_needed_item_state.get("workbench_item_paths", []) as Array),
		"recipe_needed_item_paths": BaseStashInventoryMarkerSupportScript.path_array(_needed_item_state.get("recipe_item_paths", []) as Array),
		"quest_needed_item_paths": BaseStashInventoryMarkerSupportScript.path_array(_needed_item_state.get("quest_item_paths", []) as Array),
		"manual_needed_item_paths": BaseStashInventoryMarkerSupportScript.path_array(_needed_item_state.get("manual_item_paths", []) as Array),
		"weapon_mod_panel": _weapon_mod_panel.state.duplicate(true),
		"weapon_mod_panel_rect": _weapon_mod_panel.panel_rect(_ui_scale, viewport_size) if _weapon_mod_panel.is_open() else Rect2(),
		"weapon_mod_panel_text": _weapon_mod_panel.visible_text(self),
		"item_detail_panel": _item_detail_panel.state.duplicate(true),
		"item_detail_panel_rect": _item_detail_panel.panel_rect(_ui_scale, viewport_size) if _item_detail_panel.is_open() else Rect2(),
		"item_detail_panel_text": _item_detail_panel.visible_text(self),
		"left_panel_rect": left_rect,
		"right_panel_rect": right_rect,
		"stash_grid_rect": _stash_grid_rect(right_rect),
		"stash_scroll_track_rect": _stash_scroll_track_rect(right_rect),
		"stash_currency_panel_rect": _stash_currency_panel_rect(right_rect),
		"stash_currency_balance_rect": _stash_currency_balance_rect(right_rect),
		"stash_currency_deposit_rect": _stash_currency_deposit_rect(right_rect),
		"stash_currency_withdraw_rect": _stash_currency_withdraw_rect(right_rect),
		"currency_transfer_dialog": _currency_transfer_dialog.get_state(viewport_size, _ui_scale),
		"backpack_grid_rect": _backpack_grid_rect(left_rect),
		"safe_pocket_rect": _safe_pocket_panel_rect(left_rect),
		"close_button_rect": Rect2(),
		"sort_button_rect": _sort_button_rect(right_rect),
		"store_all_button_rect": Rect2(),
		"storage_upgrade_button_rect": Rect2(),
	}


func get_item_tooltip_by_path(item_path: String) -> Dictionary:
	var normalized_path := item_path.strip_edges()
	if normalized_path == "" or not ResourceLoader.exists(normalized_path):
		return {}
	var item_def := load(normalized_path) as ItemDef
	if item_def == null:
		return {}
	return ItemStackTooltipPresenterScript.build(self, item_def.to_stack(1), BaseStashInventoryMarkerSupportScript.tooltip_context_for_path(normalized_path, _needed_item_state))


func refresh_localization() -> void:
	queue_redraw()


func _draw() -> void:
	if not _is_open:
		return
	var viewport_size := get_viewport_rect().size
	_update_layout_scale(viewport_size)
	var right_rect := _right_panel_rect(viewport_size)
	# 左側裝備/背包畫面由 Tab 背包參照自行繪製；
	# 這裡只繪製右側倉庫與共用浮動提示。
	_draw_stash_panel(right_rect)
	_draw_item_detail_panel()
	_draw_weapon_mod_panel()
	_draw_hover_tooltip(_current_mouse_position())
	_currency_transfer_dialog.draw(self, _painter, _ui_scale, viewport_size)


func _draw_stash_panel(rect: Rect2) -> void:
	BaseStashInventoryPainterSupportScript.draw_stash_panel(self, rect)


func _draw_item_detail_panel() -> void:
	_item_detail_panel.draw(self, _painter, _ui_scale, get_viewport_rect().size)


func _draw_weapon_mod_panel() -> void:
	_weapon_mod_panel.draw(self, _painter, _ui_scale, get_viewport_rect().size)


func _draw_equipment_grid(rect: Rect2) -> void:
	BaseStashInventoryPainterSupportScript.draw_equipment_grid(self, rect)

func _draw_backpack_grid(rect: Rect2) -> void:
	BaseStashInventoryPainterSupportScript.draw_backpack_grid(self, rect)

func _draw_safe_pocket_grid(rect: Rect2) -> void:
	BaseStashInventoryPainterSupportScript.draw_safe_pocket_grid(self, rect)

func _draw_button(rect: Rect2, label: String, fill: Color) -> void:
	BaseStashInventoryPainterSupportScript.draw_button(self, rect, label, fill)

func _paint_item_label(rect: Rect2, stack: Dictionary) -> void:
	BaseStashInventoryPainterSupportScript.paint_item_label(self, rect, stack)

func _draw_hover_tooltip(position: Vector2) -> void:
	BaseStashInventoryPainterSupportScript.draw_hover_tooltip(self, position)

func _paint_lock_indicator(rect: Rect2) -> void:
	# 給 validate_base_stash_storage_ui.gd 使用的邊界標記：_painter.lock_badge
	BaseStashInventoryPainterSupportScript.paint_lock_indicator(self, rect)

func _paint_needed_indicator(rect: Rect2) -> void:
	# 給 validate_base_stash_storage_ui.gd 使用的邊界標記：_painter.needed_badge
	BaseStashInventoryPainterSupportScript.paint_needed_indicator(self, rect)

func _handle_scroll(event: InputEventMouseButton) -> void:
	var viewport_size := get_viewport_rect().size
	_update_layout_scale(viewport_size)
	var left_rect := _left_panel_rect(viewport_size)
	var right_rect := _right_panel_rect(viewport_size)
	var direction := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
	if _scroll_weapon_mod_details_at(event.position, direction):
		return
	if _scroll_inventory_reference_weapon_mod(event.position, direction):
		return
	if right_rect.has_point(event.position):
		_scroll_stash(direction)
	elif left_rect.has_point(event.position):
		_scroll_backpack(direction)


func _handle_left_click(event: InputEventMouseButton) -> bool:
	var position := event.position
	var viewport_size := get_viewport_rect().size
	_update_layout_scale(viewport_size)
	var left_rect := _left_panel_rect(viewport_size)
	var right_rect := _right_panel_rect(viewport_size)
	if _handle_inventory_reference_action_click(position):
		return true
	if _stash_currency_deposit_rect(right_rect).has_point(position):
		open_currency_deposit()
		return true
	if _stash_currency_withdraw_rect(right_rect).has_point(position):
		open_currency_withdraw()
		return true
	if _sort_button_rect(right_rect).has_point(position):
		organize_stash(&"type")
		return true
	var category_id := _stash_category_id_at(position, right_rect)
	if category_id != "":
		return select_stash_category(category_id)
	var equipment_index := _equipment_index_at(position, left_rect)
	if equipment_index >= 0:
		_close_item_detail_panel()
		var slot_id := equipment_slot_ids[equipment_index]
		if event.double_click:
			store_equipment_slot(slot_id)
			return true
		_open_inventory_reference_weapon_slot(slot_id)
		_forwarding_inventory_reference_drag = true
		_forward_inventory_reference_mouse_event(event)
		return true
	var safe_index := _safe_pocket_index_at(position, left_rect)
	if safe_index >= 0 and safe_index < safe_pocket_items.size():
		_close_item_detail_panel()
		if event.double_click:
			store_safe_pocket_stack(safe_index)
		else:
			_forwarding_inventory_reference_drag = true
			_forward_inventory_reference_mouse_event(event)
		return true
	var backpack_index := _backpack_index_at(position, left_rect)
	if backpack_index >= 0 and backpack_index < backpack_items.size():
		_close_item_detail_panel()
		if event.double_click:
			store_backpack_stack(backpack_index)
		else:
			_forwarding_inventory_reference_drag = true
			_forward_inventory_reference_mouse_event(event)
		return true
	if backpack_index >= 0 and backpack_index < _get_backpack_slots():
		_close_item_detail_panel()
		_forward_inventory_reference_mouse_event(event)
		return true
	var stash_display_index := _stash_display_index_at(position, right_rect)
	var stash_index := _stash_source_index_for_display_index(stash_display_index)
	if stash_index >= 0 and stash_index < stash_items.size():
		if event.double_click:
			_close_item_detail_panel()
			_close_weapon_mod_panel()
			withdraw_stash_stack_to_equipment_or_backpack(stash_index)
		else:
			if not _open_weapon_mod_panel_for_stash_stack(stash_index):
				_open_item_detail_panel_for_stack(stash_items[stash_index])
		return true
	if stash_display_index >= 0 and stash_display_index < _stash_display_slot_count():
		_close_item_detail_panel()
		_close_weapon_mod_panel()
		_close_inventory_reference_detail_panels()
		return true
	return false


func _handle_inventory_reference_action_click(position: Vector2) -> bool:
	if _inventory_ui == null or not _inventory_ui.has_method("get_display_state"):
		return false
	var inventory_state: Dictionary = _inventory_ui.call("get_display_state")
	if not bool(inventory_state.get("store_all_button_visible", false)):
		return false
	# 轉送點擊前，先把本面板座標轉成背包參照 UI 的本地座標。
	var inventory_position := _inventory_reference_local_position(position)
	var store_all_rect: Rect2 = inventory_state.get("store_all_button_rect", Rect2())
	if not store_all_rect.has_point(inventory_position):
		return false
	var event := InputEventMouseButton.new()
	event.position = inventory_position
	event.global_position = _inventory_reference_global_position(inventory_position)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	_inventory_ui.call("_gui_input", event)
	return true


func _scroll_inventory_reference_weapon_mod(position: Vector2, direction: int) -> bool:
	if _inventory_ui == null or not _inventory_ui.has_method("scroll_weapon_mod_details_at"):
		return false
	var inventory_position := _inventory_reference_local_position(position)
	return bool(_inventory_ui.call("scroll_weapon_mod_details_at", inventory_position, direction))


func _scroll_weapon_mod_details_at(position: Vector2, direction: int) -> bool:
	if not _weapon_mod_panel.has_point(position, _ui_scale, get_viewport_rect().size):
		return false
	_weapon_mod_panel.scroll_details(direction, _ui_scale, get_viewport_rect().size)
	queue_redraw()
	return true


func _close_inventory_reference_weapon_mod_panel() -> void:
	if _inventory_ui == null or not _inventory_ui.has_method("_close_weapon_mod_panel"):
		return
	_inventory_ui.call("_close_weapon_mod_panel")


func _close_inventory_reference_detail_panels() -> void:
	if _inventory_ui == null:
		return
	if _inventory_ui.has_method("_close_weapon_mod_panel"):
		_inventory_ui.call("_close_weapon_mod_panel")
	if _inventory_ui.has_method("_close_item_detail_panel"):
		_inventory_ui.call("_close_item_detail_panel")


func _open_item_detail_panel_for_stack(stack: Dictionary) -> bool:
	var state := _tooltip_state_for_stack(stack)
	if state.is_empty():
		return false
	_close_inventory_reference_detail_panels()
	_close_weapon_mod_panel()
	_item_detail_panel.open(state)
	queue_redraw()
	return true


func _open_weapon_mod_panel_for_stash_stack(stack_index: int) -> bool:
	var state := _weapon_mod_panel_state_for_stash_stack(stack_index)
	if not _weapon_mod_panel.open(&"stash_weapon", state):
		return false
	_weapon_mod_stash_stack_index = stack_index
	_item_detail_panel.close()
	_close_inventory_reference_detail_panels()
	queue_redraw()
	return true


func _close_item_detail_panel() -> void:
	if not _item_detail_panel.is_open():
		return
	_item_detail_panel.close()
	queue_redraw()


func _close_weapon_mod_panel() -> void:
	_weapon_mod_stash_stack_index = -1
	_weapon_mod_panel.close()


func _forward_inventory_reference_mouse_event(event: InputEvent) -> void:
	if _inventory_ui == null or not _inventory_ui.has_method("_gui_input"):
		return
	var forwarded := event.duplicate()
	if forwarded is InputEventMouse:
		var mouse_event := forwarded as InputEventMouse
		var local_position := _inventory_reference_local_position(mouse_event.position)
		mouse_event.position = local_position
		mouse_event.global_position = _inventory_reference_global_position(local_position)
	_inventory_ui.call("_gui_input", forwarded)


func _inventory_reference_local_position(position: Vector2) -> Vector2:
	if _inventory_ui == null or not is_inside_tree() or not _inventory_ui.is_inside_tree():
		return position
	var global_position: Vector2 = get_global_transform_with_canvas() * position
	return _inventory_ui.get_global_transform_with_canvas().affine_inverse() * global_position


func _inventory_reference_global_position(position: Vector2) -> Vector2:
	if _inventory_ui == null or not _inventory_ui.is_inside_tree():
		return position
	return _inventory_ui.get_global_transform_with_canvas() * position


func _load_stash_from_save() -> void:
	stash_model.clear()
	var save_data := _ensure_save_data()
	_apply_stash_capacity_from_save(save_data)
	_refresh_storage_upgrade_state()
	_refresh_needed_item_state()
	var stash_data: Variant = save_data.get("stash", [])
	if typeof(stash_data) == TYPE_ARRAY:
		stash_model.load_save_data(stash_data as Array)
	_on_stash_changed()


func _apply_stash_capacity_from_save(save_data: Dictionary) -> void:
	if _base_stash_capacity <= 0:
		_base_stash_capacity = stash_capacity
	stash_capacity = BaseProgressionScript.get_stash_capacity(save_data, _base_stash_capacity)
	stash_scroll_row = clampi(stash_scroll_row, 0, _max_stash_scroll_row())


func _refresh_storage_upgrade_state() -> void:
	_storage_upgrade_state = BaseStorageUpgradeServiceScript.get_state(save_manager, _base_stash_capacity)


func _refresh_needed_item_state() -> void:
	_needed_item_state = BaseNeededItemServiceScript.get_state(save_manager)
	_needed_item_paths = BaseStashInventoryMarkerSupportScript.path_array_to_map(_needed_item_state.get("item_paths", []) as Array)


func _refresh_stash_money() -> void:
	var balance := StashCurrencyServiceScript.get_balance(save_manager)
	_wallet_money = int(balance.get("wallet_money", 0))
	_stash_money = int(balance.get("stash_money", 0))


func _apply_stash_currency_result(result: Dictionary, success_status: StringName) -> void:
	if bool(result.get("success", false)):
		_wallet_money = int(result.get("wallet_money", 0))
		_stash_money = int(result.get("stash_money", 0))
		_status_key = success_status
	else:
		match str(result.get("reason", "")):
			"empty_source", "invalid_amount", "insufficient_source":
				_status_key = &"ui.stash.money_source_empty"
			"save_failed":
				_status_key = &"ui.stash.save_failed"
			_:
				_status_key = &"ui.stash.money_transfer_failed"
	_refresh_stash_money()
	queue_redraw()


func _save_stash() -> bool:
	if save_manager == null or not save_manager.has_method("save_slot_data"):
		return false
	var save_data := _ensure_save_data()
	if save_data.is_empty():
		return false
	save_data["stash"] = stash_model.to_save_data()
	var saved := bool(save_manager.call("save_slot_data", _current_slot_index(), save_data))
	if saved:
		_refresh_storage_upgrade_state()
		_refresh_needed_item_state()
	return saved


func _ensure_save_data() -> Dictionary:
	if save_manager == null or not save_manager.has_method("get_slot_data"):
		return {}
	var slot_index := _current_slot_index()
	var save_data: Dictionary = save_manager.call("get_slot_data", slot_index)
	if save_data.is_empty() and save_manager.has_method("save_new_game"):
		save_manager.call("save_new_game", slot_index, "normal", "res://scenes/base/base_3d.tscn")
		save_data = save_manager.call("get_slot_data", slot_index)
	return save_data


func _current_slot_index() -> int:
	if save_manager != null and save_manager.has_method("get_current_slot_index"):
		return int(save_manager.call("get_current_slot_index"))
	return 1


func _bind_models() -> void:
	# 優先使用玩家身上的實際模型；備用模型讓驗證工具或
	# 單獨 UI 檢查不需要生成完整玩家場景也能運作。
	if player != null and player.has_method("get_inventory_model"):
		backpack_model = player.call("get_inventory_model")
	else:
		backpack_model.setup(_get_backpack_slots())
	if player != null and player.has_method("get_safe_pocket_model"):
		safe_pocket_model = player.call("get_safe_pocket_model")
	else:
		safe_pocket_model.setup(_get_safe_pocket_slots())
	equipment_model = player.call("get_equipment_model") if player != null and player.has_method("get_equipment_model") else null
	_connect_model_signal(backpack_model, "_on_backpack_changed")
	_connect_model_signal(safe_pocket_model, "_on_safe_pocket_changed")
	if equipment_model != null and equipment_model.has_signal("changed"):
		var callable := Callable(self, "_on_equipment_changed")
		if not equipment_model.is_connected("changed", callable):
			equipment_model.connect("changed", callable)
	_refresh_display_items()


func _connect_model_signal(model: RefCounted, method_name: String) -> void:
	if model == null or not model.has_signal("changed"):
		return
	var callable := Callable(self, method_name)
	if not model.is_connected("changed", callable):
		model.connect("changed", callable)


func _on_backpack_changed() -> void:
	backpack_items = backpack_model.get_display_items()
	backpack_scroll_row = clampi(backpack_scroll_row, 0, _max_backpack_scroll_row())
	BaseStashInventoryMarkerSupportScript.cleanup_index_locks(locked_backpack_slots, backpack_items.size())
	queue_redraw()


func _on_safe_pocket_changed() -> void:
	safe_pocket_items = safe_pocket_model.get_display_items()
	BaseStashInventoryMarkerSupportScript.cleanup_index_locks(locked_safe_pocket_slots, safe_pocket_items.size())
	queue_redraw()


func _on_equipment_changed() -> void:
	_cleanup_equipment_locks()
	queue_redraw()


func _on_stash_changed() -> void:
	stash_items = stash_model.get_stacks()
	_refresh_stash_filter()
	stash_scroll_row = clampi(stash_scroll_row, 0, _max_stash_scroll_row())
	BaseStashInventoryMarkerSupportScript.cleanup_index_locks(locked_stash_slots, stash_items.size())
	queue_redraw()


func _refresh_display_items() -> void:
	backpack_items = backpack_model.get_display_items()
	safe_pocket_items = safe_pocket_model.get_display_items()
	stash_items = stash_model.get_stacks()
	_refresh_stash_filter()
	backpack_scroll_row = clampi(backpack_scroll_row, 0, _max_backpack_scroll_row())
	stash_scroll_row = clampi(stash_scroll_row, 0, _max_stash_scroll_row())
	BaseStashInventoryMarkerSupportScript.cleanup_index_locks(locked_backpack_slots, backpack_items.size())
	BaseStashInventoryMarkerSupportScript.cleanup_index_locks(locked_safe_pocket_slots, safe_pocket_items.size())
	BaseStashInventoryMarkerSupportScript.cleanup_index_locks(locked_stash_slots, stash_items.size())
	_cleanup_equipment_locks()


func _refresh_stash_filter() -> void:
	var filter_state := BaseStashInventoryCategorySupportScript.build_filter_state(stash_items, _active_stash_category_id, _item_codex_catalog)
	_active_stash_category_id = str(filter_state.get("active_category_id", "all"))
	filtered_stash_items.assign(filter_state.get("visible_items", []) as Array)
	filtered_stash_source_indices.assign(filter_state.get("source_indices", []) as Array)
	_stash_category_counts = (filter_state.get("counts", {}) as Dictionary).duplicate(true)
	stash_scroll_row = clampi(stash_scroll_row, 0, _max_stash_scroll_row())


func _open_inventory_reference() -> void:
	# 參照輔助腳本會判斷 Tab 背包原本是否已開啟。
	# _opened_inventory_reference 用來避免關閉玩家自己先開著的 UI。
	var result := BaseStashInventoryReferenceSupportScript.open(self)
	_inventory_ui = result.get("inventory_ui") as Control
	_opened_inventory_reference = bool(result.get("opened", false))


func _close_inventory_reference(should_close_reference: bool = true) -> void:
	BaseStashInventoryReferenceSupportScript.close(self, _inventory_ui, _opened_inventory_reference, should_close_reference)
	_inventory_ui = null
	_opened_inventory_reference = false


func _request_managed_close() -> void:
	var ui_manager := get_node_or_null("/root/UIManager") if is_inside_tree() else null
	if ui_manager != null and ui_manager.has_method("get_active_ui") and StringName(ui_manager.call("get_active_ui")) == &"stash" and ui_manager.has_method("close_active_ui"):
		ui_manager.call("close_active_ui")
	else:
		close_stash()


func _sync_managed_close_state() -> void:
	var ui_manager := get_node_or_null("/root/UIManager") if is_inside_tree() else null
	if ui_manager != null and ui_manager.has_method("get_active_ui") and StringName(ui_manager.call("get_active_ui")) == &"stash" and ui_manager.has_method("close_active_ui"):
		ui_manager.call("close_active_ui")


func _find_inventory_ui() -> Control:
	return BaseStashInventoryReferenceSupportScript.find_inventory_ui(self)


func _is_inventory_reference_open() -> bool:
	return BaseStashInventoryReferenceSupportScript.is_open(_inventory_ui)


func _sync_inventory_reference_scroll() -> void:
	BaseStashInventoryReferenceSupportScript.sync_scroll(_inventory_ui, backpack_scroll_row)


func _configure_inventory_reference_actions(is_enabled: bool) -> void:
	BaseStashInventoryReferenceSupportScript.configure_actions(self, _inventory_ui, is_enabled)


func _on_inventory_reference_store_all_requested() -> void:
	if not _is_open:
		return
	store_all_backpack_items()


func _open_inventory_reference_weapon_slot(slot_id: StringName) -> bool:
	return BaseStashInventoryReferenceSupportScript.open_weapon_slot(_inventory_ui, slot_id)


func _update_layout_scale(viewport_size: Vector2) -> void:
	# 使用與 InventoryEquipmentUI 相同的縮放比例，確保兩側介面對齊。
	_inventory_layout.update_scale(viewport_size, 1.0)
	_ui_scale = _inventory_layout.ui_scale
	_scaled_slot_size = slot_size * _ui_scale
	_scaled_slot_gap = slot_gap * _ui_scale
	_painter.set_scale(_ui_scale)


func _left_panel_rect(viewport_size: Vector2) -> Rect2:
	_inventory_layout.update_scale(viewport_size, 1.0)
	return _inventory_layout.panel_rect()


func _right_panel_rect(viewport_size: Vector2) -> Rect2:
	return BaseStashInventoryLayoutSupportScript.right_panel_rect(viewport_size, _inventory_layout.panel_rect(), grid_columns, _scaled_slot_size, _scaled_slot_gap, _ui_scale, _panel_height())


func _panel_height() -> float:
	return BaseStashInventoryLayoutSupportScript.panel_height(visible_stash_rows, visible_backpack_rows, _scaled_slot_size, _scaled_slot_gap, _ui_scale)


func _stash_grid_rect(panel_rect: Rect2) -> Rect2:
	return BaseStashInventoryLayoutSupportScript.stash_grid_rect(panel_rect, grid_columns, visible_stash_rows, _scaled_slot_size, _scaled_slot_gap, _ui_scale)


func _stash_grid_region_rect(panel_rect: Rect2) -> Rect2:
	return BaseStashInventoryLayoutSupportScript.stash_grid_region_rect(panel_rect, _stash_grid_rect(panel_rect), _ui_scale)


func _stash_scroll_track_rect(panel_rect: Rect2) -> Rect2:
	return BaseStashInventoryLayoutSupportScript.stash_scroll_track_rect(panel_rect, _stash_grid_rect(panel_rect), _ui_scale)


func _stash_currency_panel_rect(panel_rect: Rect2) -> Rect2:
	return BaseStashInventoryLayoutSupportScript.stash_currency_panel_rect(panel_rect, _stash_grid_rect(panel_rect), _ui_scale)


func _stash_currency_balance_rect(panel_rect: Rect2) -> Rect2:
	return BaseStashInventoryLayoutSupportScript.stash_currency_balance_rect(_stash_currency_panel_rect(panel_rect), _ui_scale)


func _stash_currency_deposit_rect(panel_rect: Rect2) -> Rect2:
	return BaseStashInventoryLayoutSupportScript.stash_currency_deposit_rect(_stash_currency_panel_rect(panel_rect), _ui_scale)


func _stash_currency_withdraw_rect(panel_rect: Rect2) -> Rect2:
	return BaseStashInventoryLayoutSupportScript.stash_currency_withdraw_rect(_stash_currency_panel_rect(panel_rect), _ui_scale)


func _stash_category_tabs(panel_rect: Rect2) -> Array[Dictionary]:
	var category_ids := BaseStashInventoryCategorySupportScript.category_ids()
	var rects := BaseStashInventoryLayoutSupportScript.category_tab_rects(panel_rect, _stash_grid_rect(panel_rect), category_ids.size(), _ui_scale)
	var tabs: Array[Dictionary] = []
	for index in range(category_ids.size()):
		var category_id := category_ids[index]
		tabs.append({
			"id": category_id,
			"label": _localized_text(ItemCodexPresenterScript.storage_category_label_key(category_id), category_id.capitalize()),
			"short_label": _localized_text(ItemCodexPresenterScript.storage_category_short_label_key(category_id), category_id.left(1).to_upper()),
			"count": int(_stash_category_counts.get(category_id, 0)),
			"selected": category_id == _active_stash_category_id,
			"rect": rects[index],
		})
	return tabs


func _stash_category_id_at(position: Vector2, panel_rect: Rect2) -> String:
	for tab in _stash_category_tabs(panel_rect):
		if (tab.get("rect", Rect2()) as Rect2).has_point(position):
			return str(tab.get("id", ""))
	return ""


func _backpack_grid_rect(panel_rect: Rect2) -> Rect2:
	return BaseStashInventoryLayoutSupportScript.backpack_grid_rect(_inventory_layout, panel_rect, grid_columns, visible_backpack_rows, _scaled_slot_size, _scaled_slot_gap, _ui_scale)


func _safe_pocket_panel_rect(panel_rect: Rect2) -> Rect2:
	return _inventory_layout.safe_pocket_rect(panel_rect, _get_safe_pocket_slots())


func _equipment_slot_rect(panel_rect: Rect2, index: int) -> Rect2:
	return BaseStashInventoryLayoutSupportScript.equipment_slot_rect(_inventory_layout, panel_rect, index, _ui_scale)


func _grid_slot_rect(grid_rect: Rect2, slot_index: int, columns: int) -> Rect2:
	return InventoryGridMetricsScript.slot_rect(grid_rect, slot_index, columns, _scaled_slot_size, _scaled_slot_gap)


func _sort_button_rect(panel_rect: Rect2) -> Rect2:
	return BaseStashInventoryLayoutSupportScript.sort_button_rect(panel_rect, _ui_scale)


func _store_all_button_rect(panel_rect: Rect2) -> Rect2:
	return BaseStashInventoryLayoutSupportScript.store_all_button_rect(_inventory_layout, panel_rect, _ui_scale)


func _storage_upgrade_button_rect(panel_rect: Rect2) -> Rect2:
	return BaseStashInventoryLayoutSupportScript.storage_upgrade_button_rect(panel_rect, _ui_scale)


func _equipment_index_at(position: Vector2, panel_rect: Rect2) -> int:
	return BaseStashInventoryLayoutSupportScript.equipment_index_at(position, panel_rect, equipment_slot_ids, _inventory_layout, _ui_scale)


func _backpack_index_at(position: Vector2, panel_rect: Rect2) -> int:
	return InventoryGridMetricsScript.absolute_index_at(position, _backpack_grid_rect(panel_rect), grid_columns, visible_backpack_rows, backpack_scroll_row, _get_backpack_slots(), _scaled_slot_size, _scaled_slot_gap)


func _safe_pocket_index_at(position: Vector2, panel_rect: Rect2) -> int:
	return BaseStashInventoryLayoutSupportScript.safe_pocket_index_at(position, _safe_pocket_panel_rect(panel_rect), _get_safe_pocket_slots(), _ui_scale)


func _stash_display_index_at(position: Vector2, panel_rect: Rect2) -> int:
	return InventoryGridMetricsScript.absolute_index_at(position, _stash_grid_rect(panel_rect), grid_columns, visible_stash_rows, stash_scroll_row, _stash_display_slot_count(), _scaled_slot_size, _scaled_slot_gap)


func _stash_source_index_for_display_index(display_index: int) -> int:
	if display_index < 0 or display_index >= filtered_stash_source_indices.size():
		return -1
	return filtered_stash_source_indices[display_index]


func _stash_index_at(position: Vector2, panel_rect: Rect2) -> int:
	return _stash_source_index_for_display_index(_stash_display_index_at(position, panel_rect))


func _scroll_stash(direction: int) -> void:
	stash_scroll_row = clampi(stash_scroll_row + direction, 0, _max_stash_scroll_row())
	queue_redraw()


func _scroll_backpack(direction: int) -> void:
	backpack_scroll_row = clampi(backpack_scroll_row + direction, 0, _max_backpack_scroll_row())
	_sync_inventory_reference_scroll()
	queue_redraw()


func _max_stash_scroll_row() -> int:
	return InventoryGridMetricsScript.max_scroll_row(_stash_display_slot_count(), grid_columns, visible_stash_rows)


func _stash_display_slot_count() -> int:
	if _active_stash_category_id == "all":
		return stash_capacity
	return maxi(filtered_stash_items.size(), grid_columns * visible_stash_rows)


func _max_backpack_scroll_row() -> int:
	return InventoryGridMetricsScript.max_scroll_row(_get_backpack_slots(), grid_columns, visible_backpack_rows)


func _get_backpack_slots() -> int:
	if player != null and player.has_method("get_total_backpack_slots"):
		return int(player.call("get_total_backpack_slots"))
	return backpack_model.slot_limit if backpack_model != null else 50


func _get_safe_pocket_slots() -> int:
	if player != null and player.has_method("get_total_safe_pocket_slots"):
		return int(player.call("get_total_safe_pocket_slots"))
	return safe_pocket_model.slot_limit if safe_pocket_model != null else 2


func _get_equipment_stack_at(index: int) -> Dictionary:
	if equipment_model == null or index < 0 or index >= equipment_slot_ids.size():
		return {}
	return equipment_model.call("get_slot", equipment_slot_ids[index])


func _get_equipment_slots_state() -> Dictionary:
	if equipment_model == null or not equipment_model.has_method("get_slots"):
		return {}
	return equipment_model.call("get_slots")


func _toggle_lock(lock_map: Dictionary, key: Variant) -> bool:
	var is_now_locked := BaseStashInventoryMarkerSupportScript.toggle_lock(lock_map, key)
	if is_now_locked:
		_status_key = &"ui.stash.locked"
	else:
		_status_key = &"ui.stash.unlocked"
	queue_redraw()
	return true


func _cleanup_equipment_locks() -> void:
	if equipment_model == null:
		locked_equipment_slots.clear()
		return
	for key in locked_equipment_slots.keys():
		var slot_id := StringName(str(key))
		if not equipment_model.has_method("get_slot"):
			locked_equipment_slots.erase(key)
			continue
		var stack: Dictionary = equipment_model.call("get_slot", slot_id)
		if stack.is_empty():
			locked_equipment_slots.erase(key)


func _stack_at_position(position: Vector2) -> Dictionary:
	var viewport_size := get_viewport_rect().size
	_update_layout_scale(viewport_size)
	var left_rect := _left_panel_rect(viewport_size)
	var right_rect := _right_panel_rect(viewport_size)
	var safe_index := _safe_pocket_index_at(position, left_rect)
	if safe_index >= 0 and safe_index < safe_pocket_items.size():
		return safe_pocket_items[safe_index]
	var backpack_index := _backpack_index_at(position, left_rect)
	if backpack_index >= 0 and backpack_index < backpack_items.size():
		return backpack_items[backpack_index]
	var equipment_index := _equipment_index_at(position, left_rect)
	if equipment_index >= 0:
		return _get_equipment_stack_at(equipment_index)
	var stash_index := _stash_index_at(position, right_rect)
	if stash_index >= 0 and stash_index < stash_items.size():
		return stash_items[stash_index]
	return {}


func _tooltip_stack_at_position(position: Vector2) -> Dictionary:
	var viewport_size := get_viewport_rect().size
	_update_layout_scale(viewport_size)
	var right_rect := _right_panel_rect(viewport_size)
	if not right_rect.has_point(position):
		return {}
	var stash_index := _stash_index_at(position, right_rect)
	if stash_index >= 0 and stash_index < stash_items.size():
		return stash_items[stash_index]
	return {}


func _tooltip_state_for_stack(stack: Dictionary) -> Dictionary:
	if stack.is_empty():
		return {}
	return ItemStackTooltipPresenterScript.build(self, stack, BaseStashInventoryMarkerSupportScript.tooltip_context_for_path(BaseStashInventoryMarkerSupportScript.stack_item_path(stack), _needed_item_state))


func _weapon_mod_panel_state_for_stash_stack(stack_index: int) -> Dictionary:
	if stack_index < 0 or stack_index >= stash_items.size():
		return {"has_weapon": false, "weapon_slot_id": "stash_weapon", "slots": []}
	var weapon_stack := stash_items[stack_index].duplicate(true)
	var weapon_def := _load_item_from_stack(weapon_stack)
	return WeaponModPanelStateBuilderScript.build(weapon_stack, weapon_def, &"stash_weapon")


func _load_item_from_stack(stack: Dictionary) -> ItemDef:
	var item_path := BaseStashInventoryMarkerSupportScript.stack_item_path(stack)
	if item_path == "" or not ResourceLoader.exists(item_path):
		return null
	return load(item_path) as ItemDef


func _get_stack_display_name(stack: Dictionary) -> String:
	var key := str(stack.get("name_key", ""))
	if key != "":
		var translated := tr(key)
		if translated != key and translated != "":
			return translated
	var fallback := str(stack.get("name", ""))
	if fallback != "":
		return fallback
	return _localized_text(&"item.unknown.name", "物品")


func _storage_upgrade_button_color() -> Color:
	if bool(_storage_upgrade_state.get("can_upgrade", false)):
		return UISurfacePaletteScript.button_fill(&"success")
	return UISurfacePaletteScript.button_fill(&"neutral")


func _consume_sort_mode(sort_mode: StringName) -> StringName:
	var selected_mode := sort_mode if sort_mode != &"" else _next_sort_mode
	selected_mode = ItemStackSorterScript.normalized_mode(selected_mode)
	_next_sort_mode = ItemStackSorterScript.next_mode(selected_mode)
	return selected_mode


func _sort_button_text() -> String:
	return _sort_mode_text(_next_sort_mode)


func _sort_mode_text(sort_mode: StringName) -> String:
	return _localized_text(StringName("ui.sort.mode.%s" % str(ItemStackSorterScript.normalized_mode(sort_mode))), str(sort_mode).capitalize())


func _sort_status_key(sort_mode: StringName) -> StringName:
	return StringName("ui.stash.sorted_%s" % str(ItemStackSorterScript.normalized_mode(sort_mode)))


func _storage_upgrade_failure_status(reason: String) -> StringName:
	match reason:
		"missing_money":
			return &"ui.stash.storage_upgrade_missing_money"
		"missing_items":
			return &"ui.stash.storage_upgrade_missing_items"
		"already_owned":
			return &"ui.stash.storage_upgrade_owned"
		"no_save":
			return &"ui.stash.storage_upgrade_no_save"
		"save_failed":
			return &"ui.stash.save_failed"
		_:
			return &"ui.stash.storage_upgrade_failed"


func _stash_title_text() -> String:
	return _localized_text(&"ui.stash.title_format", "倉庫 (%d/%d)") % [stash_model.get_stack_count(), stash_capacity]


func _status_text() -> String:
	return _localized_text(_status_key, "準備存取物品。")


func _current_mouse_position() -> Vector2:
	var viewport := get_viewport()
	if viewport != null:
		return viewport.get_mouse_position()
	return _last_mouse_position


func _localized_text(key: StringName, fallback: String) -> String:
	var key_text := str(key)
	if key_text == "":
		return fallback
	var translated := tr(key_text)
	if translated == key_text or translated == "":
		return fallback
	return translated


func _find_player() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var grouped := tree.get_first_node_in_group("player")
	if grouped != null:
		return grouped
	if tree.current_scene != null:
		return tree.current_scene.find_child("Player3D", true, false)
	return null


func _find_save_manager() -> Node:
	if is_inside_tree():
		var manager := get_node_or_null("/root/SaveGameManager")
		if manager != null:
			return manager
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("SaveGameManager")


func _v(x: float, y: float) -> Vector2:
	return Vector2(x, y) * _ui_scale
