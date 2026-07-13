extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const WeaponAttachmentServiceScript := preload("res://scripts/combat/weapon_attachment_service.gd")
const ItemStackTooltipPresenterScript := preload("res://scripts/ui/item_stack_tooltip_presenter.gd")
const WeaponAmmoModelScript := preload("res://scripts/combat/weapon_ammo_model.gd")
const Pistol := preload("res://data/items/weapons/pistol_S.tres")
const Ammo := preload("res://data/items/ammo/ammo_S.tres")
const ExtendedMagazine := preload("res://data/items/attachments/extended_magazine.tres")
const Helmet := preload("res://data/items/armor/basic_helmet.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	_validate_item_data_and_tooltip()
	_validate_attachment_service()
	_validate_ammo_model_capacity_bonus()
	await _validate_player_weapon_capacity_bridge()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[weapon_attachment_capacity] OK data=extended_mag weapon_mods=compatible ammo_model=bonus player=magazine tooltip=visible boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_item_data_and_tooltip() -> void:
	if ExtendedMagazine.item_type != "attachment":
		_errors.append("Extended Magazine-S should remain an attachment item.")
	if not ExtendedMagazine.tags.has(&"magazine") or not ExtendedMagazine.tags.has(&"pistol"):
		_errors.append("Extended Magazine-S should be tagged as a pistol magazine attachment.")
	if int(ExtendedMagazine.attachment_magazine_capacity_bonus) != 4:
		_errors.append("Extended Magazine-S should add +4 magazine capacity.")
	var stack := ExtendedMagazine.to_stack(1)
	if int(stack.get("attachment_magazine_capacity_bonus", 0)) != 4:
		_errors.append("Attachment stacks should expose attachment_magazine_capacity_bonus for UI and save-independent planning.")
	var owner := Control.new()
	root.add_child(owner)
	var tooltip := ItemStackTooltipPresenterScript.build(owner, stack)
	var text := ItemStackTooltipPresenterScript.tooltip_text(tooltip)
	if not text.contains("+4"):
		_errors.append("Attachment tooltip should show the +4 magazine capacity bonus.")
	_free_node(owner)


func _validate_attachment_service() -> void:
	var weapon_stack := _weapon_stack_with_mod(&"magazine", ExtendedMagazine.to_stack(1))
	var pistol_mods: Dictionary = WeaponAttachmentServiceScript.modifiers_for_weapon_stack(weapon_stack, Pistol)
	if int(pistol_mods.get("magazine_capacity_bonus", 0)) != 4:
		_errors.append("WeaponAttachmentService should apply compatible Pistol-S magazine capacity bonus from weapon_mods.")
	if not (pistol_mods.get("attachment_ids", []) as Array).has("extended_magazine"):
		_errors.append("WeaponAttachmentService should expose applied attachment ids for validation/UI planning.")
	var helmet_mods: Dictionary = WeaponAttachmentServiceScript.modifiers_for_weapon_stack(weapon_stack, Helmet)
	if int(helmet_mods.get("magazine_capacity_bonus", 0)) != 0:
		_errors.append("WeaponAttachmentService should not apply weapon magazine bonuses to non-weapon armor.")


func _validate_ammo_model_capacity_bonus() -> void:
	var model := WeaponAmmoModelScript.new()
	model.configure_weapon(Pistol, false, 4)
	var state: Dictionary = model.get_state()
	if int(state.get("base_magazine_capacity", 0)) != 8:
		_errors.append("WeaponAmmoModel should preserve the pistol's base magazine capacity.")
	if int(state.get("magazine_capacity_bonus", 0)) != 4:
		_errors.append("WeaponAmmoModel should expose the active attachment magazine bonus.")
	if int(state.get("magazine_capacity", 0)) != 12:
		_errors.append("WeaponAmmoModel should combine base and attachment capacity into 12 rounds.")
	if not model.set_reserve_ammo(Ammo, 12):
		_errors.append("WeaponAmmoModel should accept compatible ammo with attachment capacity.")
	if model.reload_from_reserve() != 12:
		_errors.append("WeaponAmmoModel should fill the expanded 12-round magazine from reserve ammo.")


func _validate_player_weapon_capacity_bridge() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var player := scene.get_node_or_null("Player3D")
	var weapon := player.get_node_or_null("WeaponController3D") if player != null else null
	if player == null or weapon == null:
		_errors.append("Gameplay scene should include Player3D and WeaponController3D.")
		_free_node(scene)
		return
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	backpack_model.clear()
	backpack_model.setup(50)
	backpack_model.add_stack(_durable_pistol_stack(12, 12))
	backpack_model.add_stack(ExtendedMagazine.to_stack(1))
	if not bool(player.call("equip_inventory_stack", 0, &"primary_weapon")):
		_errors.append("Attachment capacity validation should equip Pistol-S.")
	if not bool(player.call("attach_inventory_stack_to_weapon", 0, &"primary_weapon")):
		_errors.append("Attachment capacity validation should attach Extended Magazine-S into Pistol-S weapon_mods.")
	await process_frame
	var attachment_state: Dictionary = player.call("get_active_weapon_attachment_state")
	if int(attachment_state.get("magazine_capacity_bonus", 0)) != 4:
		_errors.append("Player should expose active weapon attachment capacity bonus from weapon_mods.")
	if int(weapon.get("magazine_capacity_bonus")) != 4:
		_errors.append("WeaponController3D should receive the attachment magazine bonus from player weapon stack.")
	if int(weapon.get("magazine_size")) != 12:
		_errors.append("WeaponController3D magazine_size should expand from 8 to 12 with Extended Magazine-S.")
	var moved := int(weapon.call("reload_from_item", Ammo, 12))
	if moved != 12:
		_errors.append("Expanded weapon magazine should reload 12 rounds, got %d." % moved)
	if int(weapon.get("current_ammo")) != 12:
		_errors.append("Expanded magazine should report 12 loaded rounds after reload.")
	_free_node(scene)


func _validate_source_boundaries() -> void:
	var item_source := FileAccess.get_file_as_string("res://scripts/items/item_def.gd")
	if not item_source.contains("attachment_magazine_capacity_bonus"):
		_errors.append("ItemDef should own attachment_magazine_capacity_bonus data.")
	var service_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_attachment_service.gd")
	for required in ["modifiers_for_weapon_stack", "weapon_mod_stack", "attachment_magazine_capacity_bonus", "_is_compatible_attachment"]:
		if not service_source.contains(required):
			_errors.append("WeaponAttachmentService should own weapon-mounted attachment modifier logic: %s." % required)
	for forbidden in ["Control", "InventoryEquipmentUI", "BaseStashInventoryUI", "SaveGameManager", "WeaponController3D"]:
		if service_source.contains(forbidden):
			_errors.append("WeaponAttachmentService should stay data/model focused and not depend on %s." % forbidden)
	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	if not player_source.contains("WeaponAttachmentServiceScript.modifiers_for_weapon_stack"):
		_errors.append("PlayerController3D should bridge weapon stack attachments through WeaponAttachmentService.")
	if player_source.contains("extended_magazine"):
		_errors.append("PlayerController3D should not hardcode a specific attachment resource.")
	var inspection_source := FileAccess.get_file_as_string("res://scripts/ui/item_inspection_snapshot_builder.gd")
	if not inspection_source.contains("ui.item.attachment_magazine_bonus_format"):
		_errors.append("Shared item inspection builder should show attachment magazine bonus through localization.")


func _weapon_stack_with_mod(slot_id: StringName, mod_stack: Dictionary) -> Dictionary:
	var stack := Pistol.to_stack(1)
	stack["weapon_mods"] = {str(slot_id): mod_stack.duplicate(true)}
	return stack


func _durable_pistol_stack(current: int, maximum: int) -> Dictionary:
	var stack := Pistol.to_stack(1)
	stack["current_durability"] = current
	stack["max_durability"] = maximum
	stack["original_max_durability"] = Pistol.max_durability
	stack["repair_max_durability_loss"] = Pistol.repair_max_durability_loss
	stack["durability_penalty_ratio"] = Pistol.durability_penalty_ratio
	return stack


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
