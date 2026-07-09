extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const EquipmentModelScript := preload("res://scripts/equipment/equipment_model.gd")
const WeaponAttachmentServiceScript := preload("res://scripts/combat/weapon_attachment_service.gd")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")
const ExtendedMagazine := preload("res://data/items/attachments/extended_magazine.tres")
const BalancedGrip := preload("res://data/items/attachments/balanced_grip.tres")
const CompactMuzzle := preload("res://data/items/attachments/compact_muzzle.tres")
const ReflexSight := preload("res://data/items/attachments/reflex_sight.tres")
const StabilizingStock := preload("res://data/items/attachments/stabilizing_stock.tres")
const TargetingLaser := preload("res://data/items/attachments/targeting_laser.tres")

const WEAPON_MOD_EQUIPMENT_SLOTS: Array[StringName] = [
	&"weapon_mag",
	&"weapon_grip",
	&"weapon_muzzle",
	&"weapon_scope",
	&"weapon_stock",
	&"weapon_tactic",
]

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	_validate_equipment_model_weapon_mods()
	await _validate_player_weapon_mod_bridge()
	await _validate_inventory_ui_surface()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[weapon_attachment_slots] OK model=weapon_mods player=panel ui=hidden_slots migration=legacy boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_equipment_model_weapon_mods() -> void:
	var model := EquipmentModelScript.new()
	var visible_slots: Array[StringName] = model.get_visible_slot_ids()
	for slot_id in WEAPON_MOD_EQUIPMENT_SLOTS:
		if visible_slots.has(slot_id):
			_errors.append("Visible equipment slots should not expose weapon hardpoint slot: %s." % slot_id)
		if not model.get_slot(slot_id).is_empty():
			_errors.append("Weapon hardpoint compatibility slot should start empty: %s." % slot_id)

	if not model.equip_item(&"primary_weapon", Pistol):
		_errors.append("EquipmentModel should equip Pistol-S before attaching weapon mods.")
	for attachment in [ExtendedMagazine, BalancedGrip, CompactMuzzle, ReflexSight, StabilizingStock, TargetingLaser]:
		if not model.attach_weapon_mod(&"primary_weapon", attachment.to_stack(1)):
			_errors.append("%s should attach into Pistol-S weapon_mods." % attachment.id)

	var mods: Dictionary = model.get_weapon_mods(&"primary_weapon")
	for hardpoint in [&"magazine", &"grip", &"muzzle", &"scope", &"stock", &"tactic"]:
		if not mods.has(str(hardpoint)):
			_errors.append("Pistol-S weapon_mods should contain %s." % hardpoint)
	for slot_id in WEAPON_MOD_EQUIPMENT_SLOTS:
		if not model.get_slot(slot_id).is_empty():
			_errors.append("Legacy %s equipment slot should stay empty after weapon-owned attach." % slot_id)

	var pistol_mods: Dictionary = WeaponAttachmentServiceScript.modifiers_for_weapon_stack(model.get_slot(&"primary_weapon"), Pistol)
	if int(pistol_mods.get("magazine_capacity_bonus", 0)) != 4:
		_errors.append("Weapon stack mods should preserve magazine capacity bonus.")
	if absf(float(pistol_mods.get("horizontal_recoil_multiplier", 0.0)) - 0.684) > 0.001:
		_errors.append("Weapon stack mods should combine grip, muzzle, and stock horizontal recoil modifiers.")
	if absf(float(pistol_mods.get("spread_multiplier", 0.0)) - 0.765) > 0.001:
		_errors.append("Weapon stack mods should combine scope and tactic spread modifiers.")

	var legacy := EquipmentModelScript.new()
	var save_data := {
		"slots": {
			"primary_weapon": Pistol.to_stack(1),
			"charm_1": ExtendedMagazine.to_stack(1),
			"charm_2": BalancedGrip.to_stack(1),
			"weapon_muzzle": CompactMuzzle.to_stack(1),
			"weapon_scope": ReflexSight.to_stack(1),
			"weapon_stock": StabilizingStock.to_stack(1),
			"weapon_tactic": TargetingLaser.to_stack(1),
		},
	}
	if not legacy.load_save_data(save_data):
		_errors.append("Legacy weapon attachment save data should load with migration.")
	var legacy_mods: Dictionary = legacy.get_weapon_mods(&"primary_weapon")
	for hardpoint in [&"magazine", &"grip", &"muzzle", &"scope", &"stock", &"tactic"]:
		if not legacy_mods.has(str(hardpoint)):
			_errors.append("Legacy save should migrate %s into Pistol-S weapon_mods." % hardpoint)
	for slot_id in WEAPON_MOD_EQUIPMENT_SLOTS:
		if not legacy.get_slot(slot_id).is_empty():
			_errors.append("Legacy migration should empty %s after moving it into the weapon." % slot_id)


func _validate_player_weapon_mod_bridge() -> void:
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
	var equipment_model: RefCounted = player.call("get_equipment_model")
	backpack_model.clear()
	backpack_model.setup(50)
	equipment_model.call("clear")
	backpack_model.add_stack(Pistol.to_stack(1))
	for attachment in [ExtendedMagazine, BalancedGrip, CompactMuzzle, ReflexSight, StabilizingStock, TargetingLaser]:
		backpack_model.add_stack(attachment.to_stack(1))
	if not bool(player.call("equip_inventory_stack", 0, &"primary_weapon")):
		_errors.append("Player should equip Pistol-S before weapon mod attach.")
	for _i in range(6):
		if not bool(player.call("attach_inventory_stack_to_weapon", 0, &"primary_weapon")):
			_errors.append("Player should attach backpack weapon mod stack into Pistol-S weapon_mods.")
	await process_frame
	for slot_id in WEAPON_MOD_EQUIPMENT_SLOTS:
		if not equipment_model.call("get_slot", slot_id).is_empty():
			_errors.append("Player attach flow should not leave %s as visible/equipped character gear." % slot_id)
	var attachment_state: Dictionary = player.call("get_active_weapon_attachment_state")
	if int(attachment_state.get("magazine_capacity_bonus", 0)) != 4:
		_errors.append("Player active weapon state should read magazine bonus from Pistol-S weapon_mods.")
	if absf(float(attachment_state.get("horizontal_recoil_multiplier", 0.0)) - 0.684) > 0.001:
		_errors.append("Player active weapon state should read combined recoil modifiers from Pistol-S weapon_mods.")
	if int(weapon.get("magazine_size")) != 12:
		_errors.append("WeaponController3D should receive magazine bonus from weapon-owned mods.")
	var panel_state: Dictionary = player.call("get_weapon_mod_panel_state", &"primary_weapon")
	if not bool(panel_state.get("has_weapon", false)):
		_errors.append("Player should expose a weapon mod panel state for Pistol-S.")
	var rows: Array = panel_state.get("slots", []) as Array
	if rows.size() < 6:
		_errors.append("Pistol-S weapon mod panel should expose all declared hardpoints.")
	for row in rows:
		var row_dict := row as Dictionary
		var stack: Dictionary = row_dict.get("stack", {}) as Dictionary
		if stack.is_empty():
			_errors.append("Pistol-S weapon mod panel should show installed stack for %s." % str(row_dict.get("slot_id", "")))
	_free_node(scene)


func _validate_inventory_ui_surface() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var player := scene.get_node_or_null("Player3D")
	var inventory_ui := scene.find_child("InventoryEquipmentUI", true, false) as Control
	if player == null or inventory_ui == null:
		_errors.append("Gameplay scene should include Player3D and InventoryEquipmentUI.")
		_free_node(scene)
		return
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	var equipment_model: RefCounted = player.call("get_equipment_model")
	backpack_model.clear()
	backpack_model.setup(50)
	equipment_model.call("clear")
	var pistol_stack := Pistol.to_stack(1)
	pistol_stack["weapon_mods"] = {"magazine": ExtendedMagazine.to_stack(1)}
	backpack_model.add_stack(pistol_stack)
	inventory_ui.call("open_inventory")
	await process_frame
	var state: Dictionary = inventory_ui.call("get_display_state_for_viewport", Vector2(1920.0, 1080.0))
	var rects: Dictionary = state.get("equipment_slot_rects", {}) as Dictionary
	for slot_id in WEAPON_MOD_EQUIPMENT_SLOTS:
		if rects.has(str(slot_id)):
			_errors.append("InventoryEquipmentUI should not expose visible equipment rect for %s." % slot_id)
	var panel_state: Dictionary = state.get("weapon_mod_panel", {}) as Dictionary
	if not panel_state.is_empty():
		_errors.append("Weapon mod panel should only open after interacting with the weapon, not by default.")
	if not inventory_ui.call("_open_weapon_mod_panel_for_backpack_stack", 0):
		_errors.append("InventoryEquipmentUI should open weapon mod panel from a backpack weapon context action.")
	await process_frame
	state = inventory_ui.call("get_display_state_for_viewport", Vector2(1920.0, 1080.0))
	panel_state = state.get("weapon_mod_panel", {}) as Dictionary
	if panel_state.is_empty():
		_errors.append("InventoryEquipmentUI display state should include weapon_mod_panel after opening Pistol-S.")
	var panel_rect: Rect2 = state.get("weapon_mod_panel_rect", Rect2())
	if panel_rect.size == Vector2.ZERO:
		_errors.append("InventoryEquipmentUI should expose the open weapon mod panel rect for layout validation.")
	else:
		var expected_center := Vector2(960.0, panel_rect.get_center().y)
		if absf(panel_rect.get_center().x - expected_center.x) > 2.0:
			_errors.append("Weapon mod panel should open centered on the viewport, not attached to the left inventory panel.")
		if panel_rect.position.x <= float((state.get("panel_rect", Rect2()) as Rect2).end.x):
			_errors.append("Weapon mod panel should open in the center play area instead of overlapping the left equipment panel.")
	var panel_text := str(state.get("weapon_mod_panel_text", ""))
	if not panel_text.contains(TranslationServer.translate("ui.weapon_mod.slot_format") % TranslationServer.translate("ui.equipment.weapon_mag")):
		_errors.append("Weapon mod panel should show a readable magazine slot label.")
	if not panel_text.contains(TranslationServer.translate("ui.weapon_mod.installed_format") % TranslationServer.translate("item.extended_magazine.name")):
		_errors.append("Weapon mod panel should show the installed attachment by name.")
	if not panel_text.contains(TranslationServer.translate("ui.item.attachment_magazine_bonus_format") % ExtendedMagazine.attachment_magazine_capacity_bonus):
		_errors.append("Weapon mod panel should summarize the installed attachment stat effect.")
	if not panel_text.contains(TranslationServer.translate("ui.weapon_mod.empty_slot")):
		_errors.append("Weapon mod panel should label empty hardpoints as empty slots.")
	_free_node(scene)


func _validate_source_boundaries() -> void:
	var equipment_source := FileAccess.get_file_as_string("res://scripts/equipment/equipment_model.gd")
	for required in ["get_visible_slot_ids", "attach_weapon_mod", "unequip_weapon_mod", "get_weapon_mods", "_migrate_legacy_weapon_mod_slots"]:
		if not equipment_source.contains(required):
			_errors.append("EquipmentModel should own weapon-mounted mod storage: %s." % required)
	for forbidden in ["Control", "InventoryEquipmentUI", "BaseStashInventoryUI", "WeaponController3D", "PlayerController3D"]:
		if equipment_source.contains(forbidden):
			_errors.append("EquipmentModel should stay data-only and independent from %s." % forbidden)
	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	for required in ["attach_inventory_stack_to_weapon", "unequip_weapon_mod_to_inventory", "get_weapon_mod_panel_state", "modifiers_for_weapon_stack"]:
		if not player_source.contains(required):
			_errors.append("PlayerController3D should bridge weapon-mounted mods through %s." % required)
	var inventory_ui_source := FileAccess.get_file_as_string("res://scripts/ui/inventory_equipment_ui.gd")
	if not inventory_ui_source.contains("_draw_weapon_mod_panel"):
		_errors.append("InventoryEquipmentUI should own drawing for the weapon mod panel.")
	var display_source := FileAccess.get_file_as_string("res://scripts/ui/inventory_equipment_display_support.gd")
	for required in ["weapon_mod_panel_rect", "weapon_mod_panel_text"]:
		if not display_source.contains(required):
			_errors.append("InventoryEquipmentDisplaySupport should expose readable weapon-mod panel state through %s." % required)
	var presenter_source := FileAccess.get_file_as_string("res://scripts/ui/weapon_mod_panel_presenter.gd")
	for required in ["slot_label", "installed_text", "effect_summary", "visible_text"]:
		if not presenter_source.contains(required):
			_errors.append("WeaponModPanelPresenter should own readable weapon-mod panel text through %s." % required)
	var text_source := FileAccess.get_file_as_string("res://data/localization/game_text.csv")
	for required_key in ["ui.weapon_mod.slot_format", "ui.weapon_mod.empty_slot", "ui.weapon_mod.installed_format", "ui.inventory.mod"]:
		if not text_source.contains(required_key):
			_errors.append("Weapon mod panel text should live in localization data: %s." % required_key)
	for forbidden in ["ui.equipment.weapon_mag", "ui.equipment.weapon_grip", "ui.equipment.weapon_muzzle", "ui.equipment.weapon_scope", "ui.equipment.weapon_stock", "ui.equipment.weapon_tactic"]:
		if inventory_ui_source.contains(forbidden):
			_errors.append("InventoryEquipmentUI should not localize weapon hardpoints as visible character equipment slots: %s." % forbidden)
	var stash_ui_source := FileAccess.get_file_as_string("res://scripts/ui/base_stash_inventory_ui.gd")
	for forbidden in ["ui.equipment.weapon_mag", "ui.equipment.weapon_grip", "ui.equipment.weapon_muzzle", "ui.equipment.weapon_scope", "ui.equipment.weapon_stock", "ui.equipment.weapon_tactic"]:
		if stash_ui_source.contains(forbidden):
			_errors.append("BaseStashInventoryUI should not localize weapon hardpoints as visible character equipment slots: %s." % forbidden)


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
