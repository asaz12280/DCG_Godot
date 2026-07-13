extends SceneTree

const ItemStackTooltipPresenterScript := preload("res://scripts/ui/item_stack_tooltip_presenter.gd")
const LocalizationBootstrapScript := preload("res://scripts/localization/localization_bootstrap.gd")
const PistolItem := preload("res://data/items/weapons/pistol_S.tres")
const KnifeItem := preload("res://data/items/weapons/combat_knife.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	var localization := LocalizationBootstrapScript.new()
	root.add_child(localization)
	await process_frame
	var owner := Control.new()
	root.add_child(owner)
	localization.call("set_game_locale", "en")
	_validate_english_weapon_slots_hidden(owner)
	localization.call("set_game_locale", "zh_TW")
	_validate_localized_weapon_slots_hidden(owner)
	_validate_melee_does_not_show_slots(owner)
	_validate_source_boundaries()
	owner.queue_free()
	localization.queue_free()
	if _errors.is_empty():
		print("[weapon_attachment_slot_tooltip] OK weapon=slots_hidden localized=row_hidden melee=hidden boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_english_weapon_slots_hidden(owner: Control) -> void:
	var text := _tooltip_text(owner, PistolItem.to_stack(1))
	_expect_not_contains(text, "Mod slots:", "Pistol-S tooltip should not list supported weapon mod categories in the compact item summary.")


func _validate_localized_weapon_slots_hidden(owner: Control) -> void:
	var text := _tooltip_text(owner, PistolItem.to_stack(1))
	_expect_not_contains(text, _translated(&"ui.item.weapon_attachment_slots_format").split("%s")[0], "Pistol-S tooltip should not show the localized weapon mod slot row label.")


func _validate_melee_does_not_show_slots(owner: Control) -> void:
	var text := _tooltip_text(owner, KnifeItem.to_stack(1))
	_expect_not_contains(text, "Mod slots:", "Melee tooltip should not show firearm mod slot rows.")
	_expect_not_contains(text, _translated(&"ui.item.weapon_attachment_slots_format").split("%s")[0], "Melee tooltip should not show localized firearm mod slot rows.")


func _validate_source_boundaries() -> void:
	var presenter_source := FileAccess.get_file_as_string("res://scripts/ui/item_stack_tooltip_presenter.gd")
	for forbidden_row in ["ui.item.weapon_attachment_slots_format", "_weapon_attachment_slot_label"]:
		if presenter_source.contains(forbidden_row):
			_errors.append("ItemStackTooltipPresenter should not render weapon slot tooltip rows in compact item summaries: %s." % forbidden_row)
	for forbidden in ["WeaponAttachmentService", "EquipmentModel", "PlayerController3D", "SaveGameManager"]:
		if presenter_source.contains(forbidden):
			_errors.append("ItemStackTooltipPresenter should stay UI-text focused and not depend on %s." % forbidden)
	var localization_source := FileAccess.get_file_as_string("res://data/localization/game_text.csv")
	for required in ["ui.item.weapon_attachment_slots_format", "ui.equipment.weapon_stock", "ui.equipment.weapon_tactic"]:
		if not localization_source.contains(required):
			_errors.append("Localization table should contain %s." % required)


func _tooltip_text(owner: Control, stack: Dictionary) -> String:
	return ItemStackTooltipPresenterScript.tooltip_text(ItemStackTooltipPresenterScript.build(owner, stack))


func _translated(key: StringName) -> String:
	var key_text := str(key)
	var text := TranslationServer.translate(key_text)
	return text if text != key_text else key_text


func _expect_contains(content: String, needle: String, message: String) -> void:
	if not content.contains(needle):
		_errors.append("%s Expected `%s` in `%s`." % [message, needle, content])


func _expect_not_contains(content: String, needle: String, message: String) -> void:
	if content.contains(needle):
		_errors.append("%s Did not expect `%s` in `%s`." % [message, needle, content])
