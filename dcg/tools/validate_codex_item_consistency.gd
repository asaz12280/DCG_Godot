extends SceneTree

const ContainerInventoryModelScript := preload("res://scripts/inventory/container_inventory_model.gd")
const ContainerInventoryUIScene := preload("res://scenes/ui/container_inventory_ui.tscn")
const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const ItemCodexCatalogScript := preload("res://scripts/ui/item_codex_catalog.gd")
const ItemCodexPresenterScript := preload("res://scripts/ui/item_codex_presenter.gd")
const ItemCodexSlotScript := preload("res://scripts/ui/components/item_codex_slot.gd")
const ItemStackTooltipPresenterScript := preload("res://scripts/ui/item_stack_tooltip_presenter.gd")
const Pistol := preload("res://data/items/weapons/pistol_S.tres")
const Ammo := preload("res://data/items/ammo/ammo_S.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	_validate_item_def(Pistol, 5, &"pistol_S", "手槍-S")
	_validate_item_def(Ammo, 7, &"ammo_S", "彈藥-S")
	_validate_stack_identity(Pistol, 1)
	_validate_stack_identity(Ammo, 24)
	await _validate_container_surface()
	await _validate_inventory_and_equipment_surface()
	_validate_codex_surface()
	_validate_display_ownership()

	if _errors.is_empty():
		print("[codex_item_consistency] OK no5=手槍-S no7=彈藥-S surfaces=container/backpack/equipment/codex")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_item_def(item: ItemDef, expected_number: int, expected_id: StringName, expected_name: String) -> void:
	if item == null:
		_errors.append("Missing ItemDef for No.%d." % expected_number)
		return
	if item.catalog_number != expected_number:
		_errors.append("Expected No.%d, got No.%d for %s." % [expected_number, item.catalog_number, item.resource_path])
	if item.id != expected_id:
		_errors.append("Expected No.%d id %s, got %s." % [expected_number, expected_id, item.id])
	if _text(item.name_key, item.display_name) != expected_name:
		_errors.append("Expected No.%d visible name %s, got %s." % [expected_number, expected_name, _text(item.name_key, item.display_name)])


func _validate_stack_identity(item: ItemDef, quantity: int) -> void:
	if item == null:
		return
	var stack := item.to_stack(quantity)
	if int(stack.get("catalog_number", 0)) != item.catalog_number:
		_errors.append("Stack catalog number mismatch for %s." % item.resource_path)
	if StringName(str(stack.get("id", ""))) != item.id:
		_errors.append("Stack id mismatch for %s." % item.resource_path)
	if StringName(str(stack.get("name_key", ""))) != item.name_key:
		_errors.append("Stack name_key mismatch for %s." % item.resource_path)
	if str(stack.get("resource_path", "")) != item.resource_path:
		_errors.append("Stack resource path mismatch for %s." % item.resource_path)
	if item.max_durability > 0:
		if not bool(stack.get("has_durability", false)):
			_errors.append("Stack should mark repairable durability for %s." % item.resource_path)
		if int(stack.get("current_durability", 0)) != item.max_durability or int(stack.get("max_durability", 0)) != item.max_durability:
			_errors.append("Stack durability should start full for %s." % item.resource_path)


func _validate_container_surface() -> void:
	var model := ContainerInventoryModelScript.new(4)
	model.add_item(Pistol, 1)
	model.add_item(Ammo, 24)

	var ui := ContainerInventoryUIScene.instantiate()
	root.add_child(ui)
	await process_frame
	ui.open_container(model, "愛心箱")
	await process_frame
	await process_frame

	var state: Dictionary = ui.get_display_state()
	var visible_text := _collect_visible_text(ui)
	_expect_equals(str(state.get("capacity", "")), "2/4", "Container capacity should show used/total slots.")
	_expect_contains(visible_text, "手槍-S", "Container slot should show No.5 pistol name.")
	_expect_contains(visible_text, "彈藥-S", "Container slot should show No.7 ammo name.")
	_expect_not_contains(visible_text, "Pistol", "Container UI should not show English pistol fallback.")
	_expect_not_contains(visible_text, "Ammo", "Container UI should not show English ammo fallback.")
	ui.queue_free()


func _validate_inventory_and_equipment_surface() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame

	var player := scene.get_tree().get_first_node_in_group("player")
	var ui := scene.get_node_or_null("HUD/InventoryEquipmentUI")
	if player == null or ui == null:
		_errors.append("Gameplay scene should expose player and InventoryEquipmentUI.")
		scene.queue_free()
		return

	player.call("add_item_resource", Pistol, 1)
	player.call("add_item_resource", Ammo, 24)
	ui.open_inventory()
	await process_frame
	await process_frame

	var backpack_state: Dictionary = ui.get_display_state()
	var backpack_items: Array = backpack_state.get("backpack_items", [])
	_validate_stack_list_has(backpack_items, 5, "手槍-S", "Backpack")
	_validate_stack_list_has(backpack_items, 7, "彈藥-S", "Backpack")

	var pistol_index := _find_stack_index(backpack_items, 5)
	if pistol_index < 0:
		_errors.append("Cannot equip No.5 because it is missing from backpack display state.")
	elif not bool(ui.call("equip_backpack_stack", pistol_index)):
		_errors.append("Inventory UI could not equip No.5 pistol from backpack.")
	await process_frame

	var equipped_state: Dictionary = ui.get_display_state()
	var equipment_text := str(equipped_state.get("equipment_text", ""))
	var equipment_slots: Dictionary = equipped_state.get("equipment_slots", {})
	_expect_contains(equipment_text, "手槍-S", "Equipment visible text should show equipped No.5 pistol name.")
	_validate_stack_dictionary_has(equipment_slots, 5, "手槍-S", "Equipment")
	scene.queue_free()


func _validate_codex_surface() -> void:
	var catalog := ItemCodexCatalogScript.new()
	catalog.reload()
	if int(catalog.call("item_count")) != 22:
		_errors.append("Codex should contain exactly the 22 active ItemDef resources.")
	_validate_catalog_item(catalog, Pistol, "手槍-S")
	_validate_catalog_item(catalog, Ammo, "彈藥-S")

	var owner := Control.new()
	root.add_child(owner)
	var pistol_slot := ItemCodexSlotScript.new()
	var ammo_slot := ItemCodexSlotScript.new()
	var empty_slot := ItemCodexSlotScript.new()
	owner.add_child(pistol_slot)
	owner.add_child(ammo_slot)
	owner.add_child(empty_slot)
	pistol_slot.setup(5, Pistol)
	ammo_slot.setup(7, Ammo)
	empty_slot.clear_slot(51)

	_expect_not_contains(pistol_slot.text, "No.5", "Codex grid slot should not show pistol catalog number.")
	_expect_not_contains(pistol_slot.text, "#5", "Codex grid slot should not show pistol hash number.")
	_expect_contains(pistol_slot.text, "手槍-S", "Codex slot should show pistol name.")
	_expect_not_contains(ammo_slot.text, "No.7", "Codex grid slot should not show ammo catalog number.")
	_expect_not_contains(ammo_slot.text, "#7", "Codex grid slot should not show ammo hash number.")
	_expect_contains(ammo_slot.text, "彈藥-S", "Codex slot should show ammo name.")
	_expect_equals(ItemCodexPresenterScript.item_name(owner, Pistol), "手槍-S", "Codex presenter should use the pistol localized name.")
	_expect_equals(ItemCodexPresenterScript.item_name(owner, Ammo), "彈藥-S", "Codex presenter should use the ammo localized name.")
	_expect_equals(empty_slot.text, "-", "Empty codex grid slot should only show the empty marker.")
	_expect_equals(ItemCodexPresenterScript.catalog_label(1), "#1", "Codex detail number should use hash format.")
	_expect_equals(ItemCodexPresenterScript.catalog_label(11), "#11", "Codex detail number should keep the selected catalog number.")
	var pistol_tooltip_text := ItemStackTooltipPresenterScript.tooltip_text(ItemStackTooltipPresenterScript.build(owner, Pistol.to_stack(1)))
	_expect_not_contains(
		pistol_tooltip_text,
		_text(&"ui.item.damage_format", "傷害 %d") % Pistol.damage,
		"Shared item tooltip presenter should not expose weapon damage in compact hover summaries."
	)
	_expect_contains(
		pistol_tooltip_text,
		_text(&"ui.weapon_mod.summary_ammo", "彈藥 %d/%d") % [0, Pistol.magazine_capacity],
		"Shared item tooltip presenter should expose compact weapon ammo state."
	)
	var codex_rows := ItemCodexPresenterScript.stat_rows(owner, Pistol)
	if not _stat_row_has(codex_rows, _text(&"ui.codex.durability", "Durability"), str(Pistol.max_durability)):
		_errors.append("Codex presenter should expose static durability for repairable items.")
	owner.queue_free()


func _validate_catalog_item(catalog: RefCounted, expected_item: ItemDef, expected_name: String) -> void:
	var number := int(catalog.call("display_slot_for_item_id", expected_item.id))
	if number <= 0:
		_errors.append("Codex catalog is missing %s." % expected_item.id)
		return
	var item := catalog.call("get_item", number) as ItemDef
	if item == null:
		_errors.append("Codex catalog display slot %d is empty for %s." % [number, expected_item.id])
		return
	if item.resource_path != expected_item.resource_path:
		_errors.append("Codex display slot %d should point to %s, got %s." % [number, expected_item.resource_path, item.resource_path])
	if _text(item.name_key, item.display_name) != expected_name:
		_errors.append("Codex display slot %d visible name should be %s." % [number, expected_name])


func _validate_display_ownership() -> void:
	for path in PackedStringArray([
		"res://scripts/ui/container_inventory_ui.gd",
		"res://scripts/ui/item_codex_presenter.gd",
		"res://scripts/ui/item_inspection_snapshot_builder.gd",
		"res://scripts/ui/components/item_codex_slot.gd",
		"res://scripts/ui/inventory_equipment_display_support.gd",
	]):
		var text := _read_text(path)
		_expect_contains(text, "name_key", "%s should derive item visible names from ItemDef name_key." % path)
		if text.contains("\"Pistol\"") or text.contains("\"Ammo\""):
			_errors.append("%s should not hardcode English item names for No.5/No.7." % path)
	_expect_contains(_read_text("res://scripts/ui/item_stack_tooltip_presenter.gd"), "ItemInspectionSnapshotBuilderScript.build", "Tooltip presenter should delegate display identity and rows to the shared inspection snapshot.")


func _validate_stack_list_has(stacks: Array, number: int, expected_name: String, surface: String) -> void:
	for stack in stacks:
		if typeof(stack) != TYPE_DICTIONARY:
			continue
		var stack_dict := stack as Dictionary
		if int(stack_dict.get("catalog_number", 0)) == number:
			_expect_equals(_stack_name(stack_dict), expected_name, "%s No.%d should display %s." % [surface, number, expected_name])
			return
	_errors.append("%s is missing No.%d." % [surface, number])


func _find_stack_index(stacks: Array, number: int) -> int:
	for index in range(stacks.size()):
		var stack: Variant = stacks[index]
		if typeof(stack) == TYPE_DICTIONARY and int((stack as Dictionary).get("catalog_number", 0)) == number:
			return index
	return -1


func _validate_stack_dictionary_has(stacks: Dictionary, number: int, expected_name: String, surface: String) -> void:
	for key in stacks.keys():
		var value: Variant = stacks[key]
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var stack := value as Dictionary
		if int(stack.get("catalog_number", 0)) == number:
			_expect_equals(_stack_name(stack), expected_name, "%s No.%d should display %s." % [surface, number, expected_name])
			return
	_errors.append("%s is missing No.%d." % [surface, number])


func _stack_name(stack: Dictionary) -> String:
	return _text(StringName(str(stack.get("name_key", ""))), str(stack.get("name", "")))


func _stat_row_has(rows: Array[Dictionary], label: String, value: String) -> bool:
	for row in rows:
		if str(row.get("label", "")) == label and str(row.get("value", "")) == value:
			return true
	return false


func _text(key: StringName, fallback: String) -> String:
	var key_text := str(key)
	if key_text == "":
		return fallback
	var translated := root.tr(key_text)
	if translated == key_text or translated == "":
		return fallback
	return translated


func _collect_visible_text(node: Node) -> String:
	var parts: PackedStringArray = []
	if node is Label:
		parts.append((node as Label).text)
	elif node is Button:
		parts.append((node as Button).text)
	for child in node.get_children():
		parts.append(_collect_visible_text(child))
	return "\n".join(parts)


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_errors.append("Cannot read %s" % path)
		return ""
	return file.get_as_text()


func _expect_contains(content: String, needle: String, message: String) -> void:
	if not content.contains(needle):
		_errors.append(message)


func _expect_not_contains(content: String, needle: String, message: String) -> void:
	if content.contains(needle):
		_errors.append(message)


func _expect_equals(actual: String, expected: String, message: String) -> void:
	if actual != expected:
		_errors.append("%s Expected `%s`, got `%s`." % [message, expected, actual])
