class_name StashCurrencyTransferDialog
extends RefCounted

const UISurfacePaletteScript := preload("res://scripts/ui/ui_surface_palette.gd")

const MODE_DEPOSIT := &"deposit"
const MODE_WITHDRAW := &"withdraw"

var mode: StringName = &""
var maximum_amount := 0
var selected_amount := 0
var dialog_rect := Rect2()
var slider_rect := Rect2()
var confirm_rect := Rect2()
var cancel_rect := Rect2()
var is_adjusting_slider := false


func open_transfer(transfer_mode: StringName, source_amount: int) -> bool:
	if transfer_mode not in [MODE_DEPOSIT, MODE_WITHDRAW] or source_amount <= 0:
		return false
	mode = transfer_mode
	maximum_amount = source_amount
	selected_amount = clampi(int(ceil(float(source_amount) * 0.5)), 1, source_amount)
	is_adjusting_slider = false
	return true


func close() -> void:
	mode = &""
	maximum_amount = 0
	selected_amount = 0
	dialog_rect = Rect2()
	slider_rect = Rect2()
	confirm_rect = Rect2()
	cancel_rect = Rect2()
	is_adjusting_slider = false


func is_open() -> bool:
	return mode in [MODE_DEPOSIT, MODE_WITHDRAW] and maximum_amount > 0


func update_layout(viewport_size: Vector2, ui_scale: float) -> void:
	if not is_open():
		return
	dialog_rect = Rect2((viewport_size - Vector2(390.0, 220.0) * ui_scale) * 0.5, Vector2(390.0, 220.0) * ui_scale)
	slider_rect = Rect2(dialog_rect.position + _v(ui_scale, 42.0, 126.0), Vector2(dialog_rect.size.x - 84.0 * ui_scale, 18.0 * ui_scale))
	confirm_rect = Rect2(dialog_rect.position + _v(ui_scale, 36.0, 166.0), Vector2(148.0, 36.0) * ui_scale)
	cancel_rect = Rect2(dialog_rect.position + _v(ui_scale, 206.0, 166.0), Vector2(148.0, 36.0) * ui_scale)


func handle_mouse_motion(event: InputEventMouseMotion) -> bool:
	if not is_adjusting_slider:
		return false
	_update_amount(event.position)
	return true


func handle_mouse_button(event: InputEventMouseButton) -> Dictionary:
	if not is_open() or event.button_index != MOUSE_BUTTON_LEFT:
		return {}
	if event.pressed:
		if slider_rect.has_point(event.position):
			is_adjusting_slider = true
			_update_amount(event.position)
			return {"handled": true}
		if confirm_rect.has_point(event.position):
			return {"handled": true, "action": "confirm", "amount": selected_amount, "mode": mode}
		if cancel_rect.has_point(event.position) or not dialog_rect.has_point(event.position):
			return {"handled": true, "action": "cancel"}
	elif is_adjusting_slider:
		is_adjusting_slider = false
		return {"handled": true}
	return {}


func draw(owner: Control, painter: RefCounted, ui_scale: float, viewport_size: Vector2) -> void:
	if not is_open():
		return
	update_layout(viewport_size, ui_scale)
	painter.panel(Rect2(dialog_rect.position + _v(ui_scale, 8.0, 8.0), dialog_rect.size), UISurfacePaletteScript.shadow(), UISurfacePaletteScript.TRANSPARENT, 0, 18)
	painter.panel(dialog_rect, UISurfacePaletteScript.panel_fill(), UISurfacePaletteScript.panel_border(), 1, UISurfacePaletteScript.RADIUS_FLOATING_PANEL)
	painter.text(_text(owner, _title_key(), "Transfer Coins"), dialog_rect.position + _v(ui_scale, 0.0, 42.0), 24, UISurfacePaletteScript.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_CENTER, dialog_rect.size.x)
	painter.text(_text(owner, &"ui.stash.transfer_amount", "Amount"), dialog_rect.position + _v(ui_scale, 0.0, 76.0), 18, UISurfacePaletteScript.TEXT_SECONDARY, HORIZONTAL_ALIGNMENT_CENTER, dialog_rect.size.x)
	painter.text("$ %d / %d" % [selected_amount, maximum_amount], dialog_rect.position + _v(ui_scale, 0.0, 108.0), 20, UISurfacePaletteScript.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_CENTER, dialog_rect.size.x)

	var ratio := float(selected_amount) / float(maximum_amount)
	painter.numeric_slider(slider_rect, ratio)
	_draw_button(owner, painter, confirm_rect, _text(owner, &"ui.stash.transfer_confirm", "Confirm"), UISurfacePaletteScript.button_fill(&"success"), ui_scale)
	_draw_button(owner, painter, cancel_rect, _text(owner, &"ui.stash.transfer_cancel", "Cancel"), UISurfacePaletteScript.button_fill(&"neutral"), ui_scale)


func get_state(viewport_size: Vector2, ui_scale: float) -> Dictionary:
	update_layout(viewport_size, ui_scale)
	return {
		"open": is_open(),
		"mode": str(mode),
		"maximum_amount": maximum_amount,
		"selected_amount": selected_amount,
		"dialog_rect": dialog_rect,
		"slider_rect": slider_rect,
		"confirm_rect": confirm_rect,
		"cancel_rect": cancel_rect,
	}


func _update_amount(position: Vector2) -> void:
	if maximum_amount <= 0 or slider_rect.size.x <= 0.0:
		return
	var ratio := clampf((position.x - slider_rect.position.x) / slider_rect.size.x, 0.0, 1.0)
	selected_amount = clampi(roundi(ratio * float(maximum_amount)), 1, maximum_amount)


func _title_key() -> StringName:
	return &"ui.stash.deposit_title" if mode == MODE_DEPOSIT else &"ui.stash.withdraw_title"


func _draw_button(owner: Control, painter: RefCounted, rect: Rect2, text: String, fill: Color, ui_scale: float) -> void:
	painter.panel(rect, fill, UISurfacePaletteScript.button_border(), 1, 8)
	painter.text(text, rect.position + _v(ui_scale, 8.0, 24.0), 18, UISurfacePaletteScript.button_text(), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 16.0 * ui_scale)


func _text(owner: Control, key: StringName, fallback: String) -> String:
	var translated := owner.tr(str(key))
	return fallback if translated == str(key) or translated == "" else translated


func _v(ui_scale: float, x: float, y: float) -> Vector2:
	return Vector2(x, y) * ui_scale
