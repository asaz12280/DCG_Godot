extends SceneTree

func _init() -> void:
	var model := InventoryModel.new()
	model.setup(10)

	var ammo_a := {
		"id": &"ammo_s",
		"catalog_number": 7,
		"quantity": 30,
		"max_stack": 60,
	}
	var ammo_b := {
		"id": &"ammo_s",
		"catalog_number": 7,
		"quantity": 20,
		"max_stack": 60,
	}
	var armor := {
		"id": &"armor",
		"catalog_number": 8,
		"quantity": 1,
		"max_stack": 1,
	}
	var helmet := {
		"id": &"helmet",
		"catalog_number": 9,
		"quantity": 1,
		"max_stack": 1,
	}

	model.stacks = [ammo_a.duplicate(true), ammo_b.duplicate(true)]
	if not model.merge_or_swap_stack(0, 1):
		_fail("stackable same catalog should merge")
	if model.stacks.size() != 1 or int(model.stacks[0].get("quantity", 0)) != 50:
		_fail("merged ammo stack should contain 50")

	model.stacks = [armor.duplicate(true), armor.duplicate(true)]
	if model.merge_or_swap_stack(0, 1):
		_fail("same catalog with max_stack 1 should not merge")

	model.stacks = [armor.duplicate(true), helmet.duplicate(true)]
	if not model.merge_or_swap_stack(0, 1):
		_fail("different catalog should swap")
	if int(model.stacks[0].get("catalog_number", 0)) != 9 or int(model.stacks[1].get("catalog_number", 0)) != 8:
		_fail("different catalog swap order is wrong")

	print("[inventory_drag_rules] OK")
	quit(0)


func _fail(message: String) -> void:
	push_error("[inventory_drag_rules] %s" % message)
	quit(1)
