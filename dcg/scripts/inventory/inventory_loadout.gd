class_name InventoryLoadout
extends Resource

@export var item_paths: PackedStringArray = PackedStringArray()
@export var quantities: PackedInt32Array = PackedInt32Array()


func get_entry_count() -> int:
	return item_paths.size()


func get_item_path(index: int) -> String:
	if index < 0 or index >= item_paths.size():
		return ""
	return item_paths[index]


func get_quantity(index: int) -> int:
	if index < 0 or index >= quantities.size():
		return 1
	return maxi(quantities[index], 1)


func add_to_inventory(inventory_model: InventoryModel) -> void:
	if inventory_model == null:
		return
	for index in range(get_entry_count()):
		var item := load(get_item_path(index)) as ItemDef
		if item != null:
			inventory_model.add_item(item, get_quantity(index))
