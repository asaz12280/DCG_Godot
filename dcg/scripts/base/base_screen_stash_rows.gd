class_name BaseScreenStashRows
extends RefCounted

const BaseUIStyle := preload("res://scripts/ui/ui_style.gd")
const BaseScreenViewModelScript := preload("res://scripts/base/base_screen_view_model.gd")


static func rebuild(owner: Object, rows: VBoxContainer, stash_data: Variant) -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()

	if typeof(stash_data) != TYPE_ARRAY or (stash_data as Array).is_empty():
		rows.add_child(_make_row(BaseScreenViewModelScript.text(owner, &"ui.base.stash_empty", "倉庫是空的。"), ""))
		return

	for entry in stash_data as Array:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item_path := str(entry.get("item_path", ""))
		var quantity := int(entry.get("quantity", 0))
		var item_name := BaseScreenViewModelScript.item_name_from_path(owner, item_path)
		rows.add_child(_make_row(item_name, "x%d" % quantity))


static func _make_row(item_name: String, quantity_text: String) -> HBoxContainer:
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
