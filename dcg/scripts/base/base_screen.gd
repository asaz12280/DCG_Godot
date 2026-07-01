extends Control
class_name BaseScreen

const BaseUIStyle := preload("res://scripts/ui/ui_style.gd")
const BaseProgressionScript := preload("res://scripts/base/base_progression.gd")
const StashVendorScript := preload("res://scripts/base/stash_vendor.gd")
const WORKBENCH_LEVEL_1 := preload("res://data/base_upgrades/workbench_level_1.tres")
const GAMEPLAY_SCENE := "res://scenes/gameplay/player_test_world_3d.tscn"

@export var current_slot_index: int = 1

@onready var main_panel: PanelContainer = %MainPanel
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var slot_label: Label = %SlotLabel
@onready var difficulty_label: Label = %DifficultyLabel
@onready var money_label: Label = %MoneyLabel
@onready var stash_title_label: Label = %StashTitleLabel
@onready var stash_rows: VBoxContainer = %StashRows
@onready var workbench_title_label: Label = %WorkbenchTitleLabel
@onready var workbench_name_label: Label = %WorkbenchNameLabel
@onready var workbench_description_label: Label = %WorkbenchDescriptionLabel
@onready var workbench_cost_label: Label = %WorkbenchCostLabel
@onready var workbench_status_label: Label = %WorkbenchStatusLabel
@onready var upgrade_workbench_button: Button = %UpgradeWorkbenchButton
@onready var status_label: Label = %StatusLabel
@onready var sell_all_junk_button: Button = %SellAllJunkButton
@onready var start_raid_button: Button = %StartRaidButton

var _current_save_data: Dictionary = {}


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_apply_styles()
	upgrade_workbench_button.pressed.connect(_on_upgrade_workbench_pressed)
	sell_all_junk_button.pressed.connect(_on_sell_all_junk_pressed)
	start_raid_button.pressed.connect(_on_start_raid_pressed)
	resized.connect(_layout_panel)
	_layout_panel()
	refresh()


func refresh() -> void:
	_sync_current_slot_from_save_manager()
	var save_data := _get_current_save_data()
	var has_save := not save_data.is_empty()
	if not has_save:
		save_data = _empty_save_data()
	_current_save_data = save_data.duplicate(true)

	title_label.text = _text(&"ui.base.title", "Base")
	subtitle_label.text = _text(&"ui.base.subtitle", "Stash, prepare, and start the next raid.")
	slot_label.text = _text(&"ui.base.slot_format", "Slot %d") % current_slot_index
	difficulty_label.text = "%s: %s" % [_text(&"ui.base.difficulty", "Difficulty"), _difficulty_name(str(save_data.get("difficulty_id", "normal")))]
	money_label.text = "%s: $%d" % [_text(&"ui.base.money", "Money"), int(save_data.get("money", 0))]
	stash_title_label.text = _text(&"ui.base.stash", "Stash")
	workbench_title_label.text = _text(&"ui.base.workbench", "Workbench")
	workbench_name_label.text = WORKBENCH_LEVEL_1.display_name
	workbench_description_label.text = WORKBENCH_LEVEL_1.description
	workbench_cost_label.text = "%s: %s" % [_text(&"ui.base.upgrade_cost", "Cost"), BaseProgressionScript.describe_cost(WORKBENCH_LEVEL_1)]
	sell_all_junk_button.text = _text(&"ui.base.sell_all_junk", "Sell All Junk")
	upgrade_workbench_button.text = _text(&"ui.base.upgrade", "Upgrade")
	start_raid_button.text = _text(&"ui.base.start_raid", "Start Raid")
	status_label.text = _text(&"ui.base.ready", "Ready for the next run.") if has_save else _text(&"ui.base.no_save", "No save data yet. Start a raid to create progress.")
	_rebuild_stash_rows(save_data.get("stash", []))
	_update_sell_button(save_data.get("stash", []), has_save)
	_update_workbench_state(save_data, has_save)
	_layout_panel.call_deferred()


func get_stash_row_count() -> int:
	return stash_rows.get_child_count()


func get_display_state() -> Dictionary:
	return {
		"slot": slot_label.text,
		"difficulty": difficulty_label.text,
		"money": money_label.text,
		"stash_rows": get_stash_row_count(),
		"status": status_label.text,
		"sell_all_junk_disabled": sell_all_junk_button.disabled,
		"sell_all_junk_text": sell_all_junk_button.text,
		"workbench_name": workbench_name_label.text,
		"workbench_cost": workbench_cost_label.text,
		"workbench_status": workbench_status_label.text,
		"upgrade_workbench_disabled": upgrade_workbench_button.disabled,
		"upgrade_workbench_text": upgrade_workbench_button.text,
		"panel_rect": Rect2(main_panel.position, main_panel.size),
		"upgrade_button_rect": Rect2(upgrade_workbench_button.global_position, upgrade_workbench_button.size),
		"sell_button_rect": Rect2(sell_all_junk_button.global_position, sell_all_junk_button.size),
		"start_button_rect": Rect2(start_raid_button.global_position, start_raid_button.size),
	}


func _apply_styles() -> void:
	BaseUIStyle.apply_overlay_panel_style(main_panel)
	BaseUIStyle.apply_font_size(title_label, BaseUIStyle.FONT_PANEL_TITLE)
	BaseUIStyle.apply_font_color(title_label, BaseUIStyle.COLOR_TEXT_PRIMARY)
	BaseUIStyle.apply_font_size(subtitle_label, BaseUIStyle.FONT_BODY)
	BaseUIStyle.apply_font_color(subtitle_label, BaseUIStyle.COLOR_TEXT_HELP)
	BaseUIStyle.apply_font_size(slot_label, BaseUIStyle.FONT_BODY)
	BaseUIStyle.apply_font_size(difficulty_label, BaseUIStyle.FONT_BODY)
	BaseUIStyle.apply_font_size(money_label, BaseUIStyle.FONT_BODY)
	BaseUIStyle.apply_font_size(stash_title_label, BaseUIStyle.FONT_BODY)
	BaseUIStyle.apply_font_color(stash_title_label, BaseUIStyle.COLOR_TEXT_SUBTITLE)
	BaseUIStyle.apply_font_size(workbench_title_label, BaseUIStyle.FONT_BODY)
	BaseUIStyle.apply_font_color(workbench_title_label, BaseUIStyle.COLOR_TEXT_SUBTITLE)
	BaseUIStyle.apply_font_size(workbench_name_label, BaseUIStyle.FONT_BODY)
	BaseUIStyle.apply_font_color(workbench_name_label, BaseUIStyle.COLOR_TEXT_PRIMARY)
	BaseUIStyle.apply_font_size(workbench_description_label, BaseUIStyle.FONT_PLACEHOLDER)
	BaseUIStyle.apply_font_color(workbench_description_label, BaseUIStyle.COLOR_TEXT_HELP)
	BaseUIStyle.apply_font_size(workbench_cost_label, BaseUIStyle.FONT_PLACEHOLDER)
	BaseUIStyle.apply_font_size(workbench_status_label, BaseUIStyle.FONT_PLACEHOLDER)
	BaseUIStyle.apply_font_color(workbench_status_label, BaseUIStyle.COLOR_TEXT_STATUS)
	BaseUIStyle.apply_font_size(upgrade_workbench_button, BaseUIStyle.FONT_BODY)
	BaseUIStyle.apply_font_size(status_label, BaseUIStyle.FONT_PLACEHOLDER)
	BaseUIStyle.apply_font_color(status_label, BaseUIStyle.COLOR_TEXT_MUTED)
	BaseUIStyle.apply_font_size(sell_all_junk_button, BaseUIStyle.FONT_BODY)
	BaseUIStyle.apply_font_size(start_raid_button, BaseUIStyle.FONT_BODY)


func _layout_panel() -> void:
	if main_panel == null:
		return
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size
	var outer_margin := 48.0 if viewport_size.x >= 1280.0 else 32.0
	var panel_size := Vector2(
		minf(980.0, maxf(320.0, viewport_size.x - outer_margin * 2.0)),
		minf(620.0, maxf(320.0, viewport_size.y - outer_margin * 2.0))
	)
	main_panel.position = Vector2(
		floor((viewport_size.x - panel_size.x) * 0.5),
		floor((viewport_size.y - panel_size.y) * 0.5)
	)
	main_panel.size = panel_size


func _rebuild_stash_rows(stash_data: Variant) -> void:
	for child in stash_rows.get_children():
		stash_rows.remove_child(child)
		child.queue_free()

	if typeof(stash_data) != TYPE_ARRAY or (stash_data as Array).is_empty():
		stash_rows.add_child(_make_stash_row(_text(&"ui.base.stash_empty", "Stash is empty."), ""))
		return

	for entry in stash_data as Array:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item_path := str(entry.get("item_path", ""))
		var quantity := int(entry.get("quantity", 0))
		var item_name := _item_name_from_path(item_path)
		stash_rows.add_child(_make_stash_row(item_name, "x%d" % quantity))


func _make_stash_row(item_name: String, quantity_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 38.0)
	row.add_theme_constant_override("separation", 16)

	var name_label := Label.new()
	name_label.text = item_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	BaseUIStyle.apply_font_size(name_label, BaseUIStyle.FONT_PLACEHOLDER)
	row.add_child(name_label)

	var quantity_label := Label.new()
	quantity_label.text = quantity_text
	quantity_label.custom_minimum_size = Vector2(80.0, 0.0)
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	BaseUIStyle.apply_font_size(quantity_label, BaseUIStyle.FONT_PLACEHOLDER)
	row.add_child(quantity_label)
	return row


func sell_all_junk() -> Dictionary:
	var save_manager := _get_save_manager()
	if save_manager == null or not save_manager.has_method("save_slot_data"):
		return {}
	var save_data := _get_current_save_data()
	if save_data.is_empty():
		return {}
	var stash_data: Array = _stash_array_from_variant(save_data.get("stash", []))
	var result: Dictionary = StashVendorScript.sell_all_junk(stash_data, int(save_data.get("money", 0)))
	if int(result.get("money_delta", 0)) <= 0:
		status_label.text = _text(&"ui.base.sell_none", "No junk to sell.")
		_update_sell_button(stash_data, true)
		return result

	save_data["money"] = int(result.get("money", 0))
	save_data["stash"] = (result.get("remaining_stash", []) as Array).duplicate(true)
	if not save_manager.save_slot_data(current_slot_index, save_data):
		status_label.text = _text(&"ui.base.sell_failed", "Could not save sale result.")
		return {}

	_current_save_data = save_data.duplicate(true)
	money_label.text = "%s: $%d" % [_text(&"ui.base.money", "Money"), int(save_data.get("money", 0))]
	_rebuild_stash_rows(save_data.get("stash", []))
	_update_sell_button(save_data.get("stash", []), true)
	_update_workbench_state(save_data, true)
	status_label.text = "%s +$%d" % [_text(&"ui.base.sell_success", "Sold junk"), int(result.get("money_delta", 0))]
	return result


func upgrade_workbench() -> Dictionary:
	var save_manager := _get_save_manager()
	if save_manager == null or not save_manager.has_method("save_slot_data"):
		return {}
	var save_data := _get_current_save_data()
	if save_data.is_empty():
		return {}
	var result: Dictionary = BaseProgressionScript.purchase_upgrade(save_data, WORKBENCH_LEVEL_1)
	if not bool(result.get("success", false)):
		status_label.text = _upgrade_failure_text(str(result.get("reason", "unknown")))
		_update_workbench_state(save_data, true)
		return result

	var updated: Dictionary = result.get("save_data", {}) as Dictionary
	if not save_manager.save_slot_data(current_slot_index, updated):
		status_label.text = _text(&"ui.base.upgrade_save_failed", "Could not save upgrade result.")
		return {}

	_current_save_data = updated.duplicate(true)
	money_label.text = "%s: $%d" % [_text(&"ui.base.money", "Money"), int(updated.get("money", 0))]
	_rebuild_stash_rows(updated.get("stash", []))
	_update_sell_button(updated.get("stash", []), true)
	_update_workbench_state(updated, true)
	status_label.text = _text(&"ui.base.upgrade_success", "Workbench upgraded. Next raid starts with +1 reserve ammo.")
	return result


func _get_current_save_data() -> Dictionary:
	var save_manager := _get_save_manager()
	if save_manager == null or not save_manager.has_method("get_slot_data"):
		return {}

	var data: Dictionary = save_manager.get_slot_data(current_slot_index)
	if not data.is_empty():
		return data

	if save_manager.has_method("list_slots"):
		for summary in save_manager.list_slots():
			if bool(summary.get("exists", false)):
				current_slot_index = int(summary.get("slot_index", current_slot_index))
				if save_manager.has_method("set_current_slot_index"):
					save_manager.set_current_slot_index(current_slot_index)
				return save_manager.get_slot_data(current_slot_index)
	return {}


func _update_sell_button(stash_data: Variant, has_save: bool) -> void:
	var stash_array: Array = _stash_array_from_variant(stash_data)
	var sell_value := StashVendorScript.get_sellable_value(stash_array)
	sell_all_junk_button.disabled = not has_save or sell_value <= 0
	if sell_value > 0:
		sell_all_junk_button.text = "%s ($%d)" % [_text(&"ui.base.sell_all_junk", "Sell All Junk"), sell_value]


func _update_workbench_state(save_data: Dictionary, has_save: bool) -> void:
	var is_purchased := BaseProgressionScript.is_upgrade_purchased(save_data, WORKBENCH_LEVEL_1.id)
	var check: Dictionary = BaseProgressionScript.can_purchase_upgrade(save_data, WORKBENCH_LEVEL_1)
	if is_purchased:
		workbench_status_label.text = _text(&"ui.base.workbench_upgraded", "Upgraded: starter ammo +1")
		upgrade_workbench_button.text = _text(&"ui.base.upgraded", "Upgraded")
		upgrade_workbench_button.disabled = true
	elif not has_save:
		workbench_status_label.text = _text(&"ui.base.workbench_no_save", "Create a save to upgrade.")
		upgrade_workbench_button.disabled = true
	else:
		workbench_status_label.text = _upgrade_ready_text(str(check.get("reason", "unknown")))
		upgrade_workbench_button.text = _text(&"ui.base.upgrade", "Upgrade")
		upgrade_workbench_button.disabled = not bool(check.get("can_purchase", false))


func _stash_array_from_variant(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _upgrade_ready_text(reason: String) -> String:
	match reason:
		"ok":
			return _text(&"ui.base.workbench_ready", "Ready to upgrade")
		"missing_money":
			return _text(&"ui.base.workbench_need_money", "Need more money")
		"missing_items":
			return _text(&"ui.base.workbench_need_items", "Need more materials")
		"already_owned":
			return _text(&"ui.base.workbench_upgraded", "Upgraded: starter ammo +1")
		_:
			return _text(&"ui.base.workbench_unavailable", "Upgrade unavailable")


func _upgrade_failure_text(reason: String) -> String:
	match reason:
		"missing_money":
			return _text(&"ui.base.upgrade_missing_money", "Not enough money for upgrade.")
		"missing_items":
			return _text(&"ui.base.upgrade_missing_items", "Not enough materials for upgrade.")
		"already_owned":
			return _text(&"ui.base.upgrade_already_owned", "Workbench is already upgraded.")
		_:
			return _text(&"ui.base.upgrade_failed", "Cannot upgrade workbench.")


func _get_save_manager() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/SaveGameManager")


func _sync_current_slot_from_save_manager() -> void:
	var save_manager := _get_save_manager()
	if save_manager != null and save_manager.has_method("get_current_slot_index"):
		current_slot_index = int(save_manager.get_current_slot_index())


func _empty_save_data() -> Dictionary:
	return {
		"difficulty_id": "normal",
		"money": 0,
		"stash": [],
	}


func _item_name_from_path(item_path: String) -> String:
	if item_path == "" or not ResourceLoader.exists(item_path):
		return _text(&"item.unknown.name", "Unknown item")
	var item_def := load(item_path) as ItemDef
	if item_def == null:
		return _text(&"item.unknown.name", "Unknown item")
	var name_key := str(item_def.name_key)
	if name_key != "":
		var translated := tr(name_key)
		if translated != name_key:
			return translated
	return item_def.display_name if item_def.display_name != "" else str(item_def.id)


func _difficulty_name(difficulty_id: String) -> String:
	match difficulty_id:
		"easy":
			return _text(&"ui.difficulty.easy", "Easy")
		"hard":
			return _text(&"ui.difficulty.hard", "Hard")
		_:
			return _text(&"ui.difficulty.normal", "Normal")


func _text(key: StringName, fallback: String) -> String:
	var key_text := str(key)
	var translated := tr(key_text)
	return fallback if translated == key_text else translated


func _on_start_raid_pressed() -> void:
	if is_inside_tree():
		get_tree().change_scene_to_file(GAMEPLAY_SCENE)


func _on_sell_all_junk_pressed() -> void:
	sell_all_junk()


func _on_upgrade_workbench_pressed() -> void:
	upgrade_workbench()
