extends SceneTree

const StarterInventory := preload("res://data/inventory/starter_inventory.tres")
const WhiteCrateTable := preload("res://data/loot_tables/crate_white_misc_food.tres")
const RedCrateTable := preload("res://data/loot_tables/crate_red_supplies.tres")
const DarkGreenCrateTable := preload("res://data/loot_tables/crate_dark_green_weapons.tres")
const YellowCrateTable := preload("res://data/loot_tables/crate_yellow_locked_cache.tres")
const BlueLockedCrateTable := preload("res://data/loot_tables/crate_blue_locked_armor.tres")
const Bandage := preload("res://data/items/medical/bandage.tres")
const LifeTotem := preload("res://data/items/totems/life_totem.tres")
const DefenseTotem := preload("res://data/items/totems/defense_totem.tres")
const TacticalHeadset := preload("res://data/items/attachments/tactical_headset.tres")
const TacticalGlasses := preload("res://data/items/attachments/tactical_glasses.tres")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")
const CombatKnife := preload("res://data/items/weapons/combat_knife.tres")
const EquipmentModelScript := preload("res://scripts/equipment/equipment_model.gd")
const PlayerEquipmentControllerScript := preload("res://scripts/player/player_equipment_controller_3d.gd")
const WeaponModPanelPresenterScript := preload("res://scripts/ui/weapon_mod_panel_presenter.gd")
const RaidHudPanelScript := preload("res://scripts/ui/raid_hud_panel.gd")
const LocalizationBootstrapScript := preload("res://scripts/localization/localization_bootstrap.gd")
const PlayerScene := preload("res://scenes/player/player_3d.tscn")

const WAREHOUSE_KEY_PATH := "res://data/items/keys/warehouse_key.tres"
const BANDAGE_PATH := "res://data/items/medical/bandage.tres"
const BOTTLED_WATER_PATH := "res://data/items/food/bottled_water.tres"
const BREAD_PATH := "res://data/items/food/bread.tres"
const AMMO_9MM_PATH := "res://data/items/ammo/ammo_9mm.tres"
const SMG_9MM_PATH := "res://data/items/weapons/smg_9mm.tres"
const COMBAT_KNIFE_PATH := "res://data/items/weapons/combat_knife.tres"
const LIFE_TOTEM_PATH := "res://data/items/totems/life_totem.tres"
const BASIC_HELMET_PATH := "res://data/items/armor/basic_helmet.tres"
const LIGHT_ARMOR_PATH := "res://data/items/armor/light_armor.tres"
const DEFENSE_TOTEM_PATH := "res://data/items/totems/defense_totem.tres"
const TACTICAL_HEADSET_PATH := "res://data/items/attachments/tactical_headset.tres"
const TACTICAL_GLASSES_PATH := "res://data/items/attachments/tactical_glasses.tres"
const SMALL_BACKPACK_PATH := "res://data/items/backpacks/small_backpack.tres"
const INVENTORY_UI_SOURCE := "res://scripts/ui/inventory_equipment_ui.gd"
const WEAPON_MOD_PANEL_SOURCE := "res://scripts/ui/weapon_mod_panel_presenter.gd"
const PLAYER_EQUIPMENT_SOURCE := "res://scripts/player/player_equipment_controller_3d.gd"
const RAID_HUD_SOURCE := "res://scripts/ui/raid_hud_panel.gd"

var _errors: Array[String] = []


func _initialize() -> void:
	_ensure_localization_bootstrap()
	TranslationServer.set_locale("zh_TW")
	_validate_starter_inventory()
	_validate_guaranteed_crate_drops()
	_validate_drag_only_equipment_source()
	_validate_weapon_mod_empty_slot_hit_test()
	_validate_bandage_data()
	_validate_item_use_hud_localization()
	_validate_life_totem_equipment()
	_validate_new_equipment_data()
	_validate_weapon_slot_rules()
	await _validate_direct_slot_runtime_equip()
	await _validate_profile_equipment_runtime_equip()
	await _validate_bandage_runtime_use()
	if _errors.is_empty():
		print("[user_inventory_loot_consumables_totems] OK starter=empty drops=guaranteed drag_only=true bandage=usable totems=stat weapons=slot_rules")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _ensure_localization_bootstrap() -> void:
	var localization := LocalizationBootstrapScript.new()
	localization.name = "ValidationLocalizationBootstrap"
	root.add_child(localization)
	localization.call("_load_csv_translations")


func _validate_starter_inventory() -> void:
	if StarterInventory.item_paths.size() != 0 or StarterInventory.quantities.size() != 0:
		_errors.append("Starter inventory should not contain initial wood or any other starter item.")


func _validate_guaranteed_crate_drops() -> void:
	var white_roll := WhiteCrateTable.roll(1, 101)
	if white_roll.size() != 1:
		_errors.append("White crate should currently roll only the warehouse key stack.")
	_assert_roll_contains(white_roll, WAREHOUSE_KEY_PATH, "White crate should always include one warehouse key.")
	if _rolled_quantity(white_roll, WAREHOUSE_KEY_PATH) != 2:
		_errors.append("White crate should always include two warehouse keys.")
	var red_roll := RedCrateTable.roll(1, 202)
	_assert_roll_contains(red_roll, BANDAGE_PATH, "Red crate should always include one bandage.")
	_assert_roll_contains(red_roll, BOTTLED_WATER_PATH, "Red crate should always include one bottled water.")
	_assert_roll_contains(red_roll, BREAD_PATH, "Red crate should always include one bread.")
	var dark_green_roll := DarkGreenCrateTable.roll(1, 404)
	_assert_roll_contains(dark_green_roll, AMMO_9MM_PATH, "Dark green crate should always include pistol ammo.")
	_assert_roll_contains(dark_green_roll, SMG_9MM_PATH, "Dark green crate should always include one SMG-S.")
	_assert_roll_contains(dark_green_roll, COMBAT_KNIFE_PATH, "Dark green crate should always include one combat knife.")
	if _rolled_quantity(dark_green_roll, COMBAT_KNIFE_PATH) != 1:
		_errors.append("Dark green crate should roll exactly one combat knife.")
	var yellow_roll := YellowCrateTable.roll(1, 303)
	_assert_roll_contains(yellow_roll, TACTICAL_HEADSET_PATH, "Yellow crate should always include one tactical headset.")
	_assert_roll_contains(yellow_roll, TACTICAL_GLASSES_PATH, "Yellow crate should always include one tactical glasses.")
	_assert_roll_contains(yellow_roll, DEFENSE_TOTEM_PATH, "Yellow crate should always include one Defense Totem.")
	_assert_roll_contains(yellow_roll, SMALL_BACKPACK_PATH, "Yellow crate should always include one small backpack.")
	var blue_roll := BlueLockedCrateTable.roll(1, 505)
	_assert_roll_contains(blue_roll, BASIC_HELMET_PATH, "Blue locked crate should always include one helmet.")
	_assert_roll_contains(blue_roll, LIGHT_ARMOR_PATH, "Blue locked crate should always include one armor.")
	_assert_roll_contains(blue_roll, LIFE_TOTEM_PATH, "Blue locked crate should always include one Life Totem.")


func _validate_drag_only_equipment_source() -> void:
	var source := FileAccess.get_file_as_string(INVENTORY_UI_SOURCE)
	if source.contains("_attach_backpack_stack_to_open_weapon"):
		_errors.append("Inventory UI should not keep click-to-attach helper paths.")
	if source.contains("_unequip_equipment_slot(hit_equipment_slot)") and not source.contains("event.double_click and _unequip_equipment_slot(hit_equipment_slot)"):
		_errors.append("Inventory UI should not unequip equipment from a single equipment-slot click.")
	if not source.contains("attach_inventory_stack_to_weapon_hardpoint"):
		_errors.append("Inventory UI should drag attachments into explicit weapon hardpoint slots.")
	if not source.contains("_start_equipment_drag") or not source.contains("_finish_equipment_drag") or not source.contains("unequip_equipment_slot"):
		_errors.append("Inventory UI should allow equipped items to drag back into the backpack.")
	if not source.contains("_start_weapon_mod_drag") or not source.contains("_finish_weapon_mod_drag") or not source.contains("unequip_weapon_mod_to_inventory"):
		_errors.append("Inventory UI should allow installed weapon mods to drag back into the backpack.")
	if source.contains("_toggle_weapon_mod_panel_for_slot"):
		_errors.append("Inventory UI should not keep equipment-slot double-click weapon mod flow.")
	if not source.contains("can_mod_backpack_stack") or not source.contains("_open_weapon_mod_panel_for_backpack_stack"):
		_errors.append("Inventory UI should open weapon mod panels from the backpack weapon context menu.")
	if not source.contains("_is_usable_stack"):
		_errors.append("Inventory UI should hide the Use context action for non-consumable backpack stacks.")
	if not source.contains("not _weapon_mod_panel.is_open()"):
		_errors.append("Inventory UI should disable world drops while the weapon mod panel is open.")
	var panel_source := FileAccess.get_file_as_string(WEAPON_MOD_PANEL_SOURCE)
	if panel_source.contains("pistol_9mm") or panel_source.contains("Pistol"):
		_errors.append("Weapon mod panel should not be hard-coded to pistol-specific content.")
	var equipment_source := FileAccess.get_file_as_string(PLAYER_EQUIPMENT_SOURCE)
	if not equipment_source.contains("weapon_def.weapon_attachment_slots"):
		_errors.append("Weapon mod state should be built from the equipped weapon's attachment slots.")


func _validate_weapon_mod_empty_slot_hit_test() -> void:
	var presenter := WeaponModPanelPresenterScript.new()
	var state := {
		"has_weapon": true,
		"weapon_slot_id": "primary_weapon",
		"weapon_stack": {},
		"slots": [{"slot_id": "magazine", "label_key": &"ui.equipment.weapon_mag", "stack": {}}],
	}
	if not presenter.open(&"primary_weapon", state):
		_errors.append("Weapon mod presenter should open from generic weapon mod state.")
		return
	var viewport_size := Vector2(1280.0, 720.0)
	var rect: Rect2 = presenter.panel_rect(1.0, viewport_size)
	var slot_rect: Rect2 = presenter.slot_rect(rect, 0, 1.0)
	var hit: Dictionary = presenter.hit_slot(slot_rect.get_center(), 1.0, viewport_size)
	if StringName(str(hit.get("slot_id", ""))) != &"magazine":
		_errors.append("Weapon mod presenter should return slot_id for empty slots so drag install can work.")


func _validate_bandage_data() -> void:
	if Bandage.heal_amount <= 0.0:
		_errors.append("Bandage should define a positive heal_amount.")
	if Bandage.use_duration_seconds <= 0.0:
		_errors.append("Bandage should define a positive use_duration_seconds.")
	var stack := Bandage.to_stack(1)
	if float(stack.get("heal_amount", 0.0)) <= 0.0 or float(stack.get("use_duration_seconds", 0.0)) <= 0.0:
		_errors.append("Bandage stack data should carry heal/use duration values for runtime UI and use flow.")


func _validate_item_use_hud_localization() -> void:
	var required_keys := [
		"ui.item_use.using_format",
		"ui.item_use.complete",
		"ui.item_use.cancelled",
	]
	for locale in ["zh_TW", "en"]:
		TranslationServer.set_locale(locale)
		for key in required_keys:
			var value := TranslationServer.translate(key)
			if value == key or str(value).strip_edges() == "":
				_errors.append("Item use HUD localization key should exist for %s: %s." % [locale, key])
	TranslationServer.set_locale("en")
	var using_format := str(TranslationServer.translate("ui.item_use.using_format"))
	if not using_format.contains("%s"):
		_errors.append("English item use HUD format should include one item-name placeholder.")
	var hud := RaidHudPanelScript.new()
	var label := str(hud.call("_item_use_progress_label", {"name_key": str(Bandage.name_key)}))
	hud.free()
	if label != "Using Bandage":
		_errors.append("Raid HUD item-use progress should produce localized English label, got: %s." % label)
	var source := FileAccess.get_file_as_string(RAID_HUD_SOURCE)
	for forbidden in ['_text(&"ui.item_use.complete", "")', '_text(&"ui.item_use.cancelled", "")', '_text(&"ui.item_use.using_format", "")']:
		if source.contains(forbidden):
			_errors.append("Raid HUD item-use labels should not depend on empty player-facing fallbacks: %s." % forbidden)
	TranslationServer.set_locale("zh_TW")


func _validate_life_totem_equipment() -> void:
	if LifeTotem.max_health_bonus <= 0.0:
		_errors.append("Life Totem should define a positive max_health_bonus.")
	var model := EquipmentModelScript.new()
	if not model.equip_item(&"charm_1", LifeTotem):
		_errors.append("Life Totem should equip into charm_1.")
	var second_model := EquipmentModelScript.new()
	if not second_model.equip_item(&"charm_2", LifeTotem):
		_errors.append("Life Totem should equip into charm_2 even when charm_1 is empty.")
	var controller := PlayerEquipmentControllerScript.new()
	controller.get_model().equip_item(&"charm_1", LifeTotem)
	if controller.get_max_health_bonus() <= 0.0:
		_errors.append("Player equipment controller should report Life Totem max health bonus.")


func _validate_new_equipment_data() -> void:
	var model := EquipmentModelScript.new()
	if TacticalHeadset.catalog_number != 17 or TacticalHeadset.item_type != "attachment" or not TacticalHeadset.tags.has(&"headset"):
		_errors.append("Tactical Headset should be catalog No.17 and use the headset equipment tag.")
	if TacticalGlasses.catalog_number != 18 or TacticalGlasses.item_type != "attachment" or not TacticalGlasses.tags.has(&"glasses"):
		_errors.append("Tactical Glasses should be catalog No.18 and use the glasses equipment tag.")
	if not TacticalHeadset.get_attachment_slot_tags().has(&"headset"):
		_errors.append("Tactical Headset should expose headset through AttachmentProfile slot tags.")
	if not TacticalGlasses.get_attachment_slot_tags().has(&"glasses"):
		_errors.append("Tactical Glasses should expose glasses through AttachmentProfile slot tags.")
	if DefenseTotem.catalog_number != 19 or DefenseTotem.item_type != "totem" or DefenseTotem.defense_bonus <= 0.0:
		_errors.append("Defense Totem should be catalog No.19 with a positive defense bonus.")
	if not model.equip_item(&"headset", TacticalHeadset):
		_errors.append("Tactical Headset should equip into the headset slot.")
	if not model.equip_item(&"glasses", TacticalGlasses):
		_errors.append("Tactical Glasses should equip into the glasses slot.")
	var controller := PlayerEquipmentControllerScript.new()
	controller.get_model().equip_item(&"charm_2", DefenseTotem)
	if controller.get_defense_bonus() < DefenseTotem.defense_bonus:
		_errors.append("Defense Totem should contribute defense from charm_2.")


func _validate_weapon_slot_rules() -> void:
	var model := EquipmentModelScript.new()
	if not model.equip_item(&"primary_weapon", Pistol):
		_errors.append("Non-melee weapons should equip into primary weapon.")
	if not model.equip_item(&"sidearm", Pistol):
		_errors.append("Non-melee weapons should equip into sidearm.")
	if model.equip_item(&"primary_weapon", CombatKnife):
		_errors.append("Melee weapons should not equip into primary weapon.")
	if model.equip_item(&"sidearm", CombatKnife):
		_errors.append("Melee weapons should not equip into sidearm.")
	if not model.equip_item(&"melee", CombatKnife):
		_errors.append("Melee weapons should equip into melee slot.")


func _validate_direct_slot_runtime_equip() -> void:
	var player := PlayerScene.instantiate()
	root.add_child(player)
	await process_frame
	if not player.call("add_item_resource", LifeTotem, 1):
		_errors.append("Player should be able to add Life Totem to backpack for direct slot equip.")
		player.queue_free()
		return
	if not player.call("add_item_resource", Pistol, 1):
		_errors.append("Player should be able to add pistol to backpack for direct slot equip.")
		player.queue_free()
		return
	var totem_index := _find_inventory_stack_index(player, LIFE_TOTEM_PATH)
	if totem_index < 0 or not bool(player.call("equip_inventory_stack", totem_index, &"charm_2")):
		_errors.append("Life Totem should directly equip from backpack into charm_2.")
	var pistol_index := _find_inventory_stack_index(player, "res://data/items/weapons/pistol_9mm.tres")
	if pistol_index < 0 or not bool(player.call("equip_inventory_stack", pistol_index, &"sidearm")):
		_errors.append("Pistol should directly equip from backpack into sidearm.")
	var equipment_model: RefCounted = player.call("get_equipment_model")
	if _slot_item_id(equipment_model, &"charm_2") != LifeTotem.id:
		_errors.append("Direct charm_2 equip should occupy the second totem slot.")
	if _slot_item_id(equipment_model, &"sidearm") != Pistol.id:
		_errors.append("Direct sidearm equip should occupy the sidearm slot.")
	player.queue_free()


func _validate_profile_equipment_runtime_equip() -> void:
	var player := PlayerScene.instantiate()
	root.add_child(player)
	await process_frame
	if not player.call("add_item_resource", TacticalHeadset, 1):
		_errors.append("Player should be able to add Tactical Headset to backpack.")
		player.queue_free()
		return
	if not player.call("add_item_resource", TacticalGlasses, 1):
		_errors.append("Player should be able to add Tactical Glasses to backpack.")
		player.queue_free()
		return
	var headset_index := _find_inventory_stack_index(player, TACTICAL_HEADSET_PATH)
	if headset_index < 0 or not bool(player.call("equip_inventory_stack", headset_index)):
		_errors.append("Tactical Headset should auto-equip from backpack into the headset slot.")
	var glasses_index := _find_inventory_stack_index(player, TACTICAL_GLASSES_PATH)
	if glasses_index < 0 or not bool(player.call("equip_inventory_stack", glasses_index)):
		_errors.append("Tactical Glasses should auto-equip from backpack into the glasses slot.")
	var equipment_model: RefCounted = player.call("get_equipment_model")
	if _slot_item_id(equipment_model, &"headset") != TacticalHeadset.id:
		_errors.append("Tactical Headset should occupy the headset slot after runtime equip.")
	if _slot_item_id(equipment_model, &"glasses") != TacticalGlasses.id:
		_errors.append("Tactical Glasses should occupy the glasses slot after runtime equip.")
	player.queue_free()


func _validate_bandage_runtime_use() -> void:
	var player := PlayerScene.instantiate()
	root.add_child(player)
	await process_frame
	if not player.has_method("add_item_resource") or not player.call("add_item_resource", Bandage, 1):
		_errors.append("Player should be able to add bandage to backpack.")
		player.queue_free()
		return
	var maximum := float(player.call("get_total_max_health"))
	player.set("health", maxf(maximum - Bandage.heal_amount - 5.0, 1.0))
	var before_health := float(player.get("health"))
	if not player.has_method("use_inventory_stack") or not bool(player.call("use_inventory_stack", 0)):
		_errors.append("Player should start using a damaged-health bandage stack.")
		player.queue_free()
		return
	player.call("_update_item_use", Bandage.use_duration_seconds + 0.25)
	var after_health := float(player.get("health"))
	var inventory_model: RefCounted = player.call("get_inventory_model")
	if after_health <= before_health:
		_errors.append("Bandage completion should restore health.")
	if inventory_model.get("stacks").size() != 0:
		_errors.append("Bandage completion should consume one bandage stack.")
	player.queue_free()


func _find_inventory_stack_index(player: Node, item_path: String) -> int:
	var inventory_model: RefCounted = player.call("get_inventory_model")
	var stacks: Array = inventory_model.get("stacks")
	for index in range(stacks.size()):
		var stack: Dictionary = stacks[index] as Dictionary
		if str(stack.get("item_path", stack.get("resource_path", ""))) == item_path:
			return index
	return -1


func _slot_item_id(equipment_model: RefCounted, slot_id: StringName) -> StringName:
	var item_def := equipment_model.call("get_equipped_item", slot_id) as ItemDef
	if item_def == null:
		return &""
	return item_def.id


func _assert_roll_contains(stacks: Array[Dictionary], item_path: String, message: String) -> void:
	for stack in stacks:
		if str(stack.get("item_path", stack.get("resource_path", ""))) == item_path:
			return
	_errors.append(message)


func _rolled_quantity(stacks: Array[Dictionary], item_path: String) -> int:
	var total := 0
	for stack in stacks:
		if str(stack.get("item_path", stack.get("resource_path", ""))) == item_path:
			total += int(stack.get("quantity", 0))
	return total
