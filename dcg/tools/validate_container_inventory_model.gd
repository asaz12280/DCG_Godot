extends SceneTree

const ContainerInventoryModelScript := preload("res://scripts/inventory/container_inventory_model.gd")
const Wood := preload("res://data/items/crafting/wood.tres")
const Wire := preload("res://data/items/electronics/wire.tres")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_capacity_and_stacking()
	_validate_remove_and_clear()
	_validate_sort_modes()
	_validate_save_round_trip()
	_validate_invalid_entries()
	_validate_responsibility_boundary()
	if _errors.is_empty():
		print("[container_inventory_model] OK capacity=slots stack=merge remove=works save=round_trip coupling=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_capacity_and_stacking() -> void:
	var container := ContainerInventoryModelScript.new(2)
	if container.get_capacity() != 2:
		_errors.append("ContainerInventoryModel should keep the configured capacity.")
	if container.get_slots().size() != 2:
		_errors.append("ContainerInventoryModel should allocate fixed visible slots.")
	if container.get_used_slots() != 0 or container.get_empty_slots() != 2:
		_errors.append("Fresh containers should report empty slots.")

	if not container.add_item(Wood, 23):
		_errors.append("ContainerInventoryModel should accept stackable items that fit.")
	if container.get_used_slots() != 2:
		_errors.append("Wood quantity 23 should use two slots when max_stack is 20.")
	if int(container.get_slot(0).get("quantity", 0)) != 20:
		_errors.append("First wood stack should fill to max_stack 20.")
	if int(container.get_slot(1).get("quantity", 0)) != 3:
		_errors.append("Second wood stack should contain the remaining quantity.")
	if not container.add_item(Wood, 5):
		_errors.append("ContainerInventoryModel should merge into an existing partial stack.")
	if int(container.get_slot(1).get("quantity", 0)) != 8:
		_errors.append("Merged wood stack should increase from 3 to 8.")

	var before_reject := container.get_slots()
	if container.add_item(Wire, 1):
		_errors.append("ContainerInventoryModel should reject full-container additions.")
	if container.get_slots() != before_reject:
		_errors.append("Rejected additions should not mutate existing container slots.")


func _validate_remove_and_clear() -> void:
	var container := ContainerInventoryModelScript.new(3)
	container.add_item(Wood, 7)
	container.add_item(Pistol, 1)

	var removed := container.remove_from_slot(0, 3)
	if int(removed.get("quantity", 0)) != 3:
		_errors.append("remove_from_slot should return the removed partial quantity.")
	if int(container.get_slot(0).get("quantity", 0)) != 4:
		_errors.append("remove_from_slot should decrement the source stack.")
	var removed_rest := container.remove_from_slot(0, 99)
	if int(removed_rest.get("quantity", 0)) != 4:
		_errors.append("remove_from_slot should clamp removal to available quantity.")
	if not container.get_slot(0).is_empty():
		_errors.append("remove_from_slot should clear empty stacks.")
	if not container.clear_slot(1):
		_errors.append("clear_slot should clear occupied slots.")
	if container.clear_slot(1):
		_errors.append("clear_slot should reject already-empty slots.")


func _validate_sort_modes() -> void:
	var container := ContainerInventoryModelScript.new(4)
	container.add_item(Wood, 1)
	container.add_item(Wire, 1)
	container.add_item(Pistol, 1)

	container.organize(&"value")
	if int(container.get_slot(0).get("catalog_number", 0)) != Pistol.catalog_number:
		_errors.append("Container value sort should put the most valuable stack first.")
	if not container.get_slot(3).is_empty():
		_errors.append("Container sort should preserve empty fixed slots at the tail.")

	container.organize(&"weight")
	if int(container.get_slot(1).get("catalog_number", 0)) != Wood.catalog_number:
		_errors.append("Container weight sort should keep the heavier wood stack before wire.")

	container.organize(&"value_weight")
	if int(container.get_slot(1).get("catalog_number", 0)) != Wire.catalog_number:
		_errors.append("Container value/kg sort should put wire after the pistol and before wood.")


func _validate_save_round_trip() -> void:
	var source := ContainerInventoryModelScript.new(4)
	source.add_item(Wood, 23)
	source.add_stack(_damaged_pistol_stack(42, 87))

	var save_data := source.to_save_data()
	if int(save_data.get("capacity", 0)) != 4:
		_errors.append("Container save data should include capacity.")
	var loaded := ContainerInventoryModelScript.new()
	if not loaded.load_save_data(save_data):
		_errors.append("ContainerInventoryModel should load its own save data.")
	if loaded.get_capacity() != 4:
		_errors.append("Round trip should preserve capacity.")
	if int(loaded.get_slot(0).get("catalog_number", 0)) != Wood.catalog_number:
		_errors.append("Round trip should preserve first item identity.")
	if int(loaded.get_slot(1).get("quantity", 0)) != 3:
		_errors.append("Round trip should preserve split stack quantity.")
	if int(loaded.get_slot(2).get("catalog_number", 0)) != Pistol.catalog_number:
		_errors.append("Round trip should preserve unstackable item identity.")
	if int(loaded.get_slot(2).get("current_durability", 0)) != 42 or int(loaded.get_slot(2).get("max_durability", 0)) != 87:
		_errors.append("Round trip should preserve unstackable item durability.")


func _validate_invalid_entries() -> void:
	var container := ContainerInventoryModelScript.new(2)
	if container.add_item(null, 1):
		_errors.append("ContainerInventoryModel should reject null ItemDef.")
	if container.add_item(Wood, 0):
		_errors.append("ContainerInventoryModel should reject zero quantity.")
	if container.add_stack({"resource_path": "res://data/items/missing_item.tres", "quantity": 1}):
		_errors.append("ContainerInventoryModel should reject stacks with missing resources.")
	var loaded_all := container.load_save_data({
		"capacity": 2,
		"slots": [
			{"item_path": "res://data/items/crafting/wood.tres", "quantity": 2},
			{"item_path": "res://data/items/missing_item.tres", "quantity": 1},
		],
	})
	if loaded_all:
		_errors.append("ContainerInventoryModel should report invalid save entries.")
	if int(container.get_slot(0).get("quantity", 0)) != 2:
		_errors.append("Valid save entries should still load when other slots are invalid.")


func _validate_responsibility_boundary() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/inventory/container_inventory_model.gd")
	var forbidden_terms := PackedStringArray([
		"Control",
		"Node",
		"UIManager",
		"InventoryEquipmentUI",
		"PlayerController",
		"WeaponController",
		"LootContainer3D",
		"res://scenes",
	])
	for term in forbidden_terms:
		if source.contains(term):
			_errors.append("ContainerInventoryModel should not depend on %s." % term)


func _damaged_pistol_stack(current: int, maximum: int) -> Dictionary:
	var stack := Pistol.to_stack(1)
	stack["current_durability"] = current
	stack["max_durability"] = maximum
	stack["original_max_durability"] = Pistol.max_durability
	stack["repair_max_durability_loss"] = Pistol.repair_max_durability_loss
	return stack
