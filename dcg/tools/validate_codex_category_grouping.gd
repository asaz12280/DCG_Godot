extends SceneTree

const LocalizationBootstrapScript := preload("res://scripts/localization/localization_bootstrap.gd")
const ItemCodexCatalogScript := preload("res://scripts/ui/item_codex_catalog.gd")
const ItemCodexPresenterScript := preload("res://scripts/ui/item_codex_presenter.gd")
const ItemCodexSlotScript := preload("res://scripts/ui/components/item_codex_slot.gd")

const Wood := preload("res://data/items/crafting/wood.tres")
const BottledWater := preload("res://data/items/food/bottled_water.tres")
const Bread := preload("res://data/items/food/bread.tres")
const Bandage := preload("res://data/items/medical/bandage.tres")
const StaminaPotion := preload("res://data/items/consumables/stamina_potion.tres")
const Pistol := preload("res://data/items/weapons/pistol_S.tres")
const CombatKnife := preload("res://data/items/weapons/combat_knife.tres")
const SMG := preload("res://data/items/weapons/smg_S.tres")
const Ammo := preload("res://data/items/ammo/ammo_S.tres")
const LightArmor := preload("res://data/items/armor/light_armor.tres")
const BasicHelmet := preload("res://data/items/armor/basic_helmet.tres")
const SmallBackpack := preload("res://data/items/backpacks/small_backpack.tres")
const WarehouseKey := preload("res://data/items/keys/warehouse_key.tres")
const Junk := preload("res://data/items/loot/junk.tres")
const Cash := preload("res://data/items/currency/cash.tres")
const LifeTotem := preload("res://data/items/totems/life_totem.tres")
const DefenseTotem := preload("res://data/items/totems/defense_totem.tres")
const ExtendedMagazine := preload("res://data/items/attachments/extended_magazine.tres")
const TacticalHeadset := preload("res://data/items/attachments/tactical_headset.tres")
const TacticalGlasses := preload("res://data/items/attachments/tactical_glasses.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	var localization := LocalizationBootstrapScript.new()
	root.add_child(localization)
	await process_frame
	localization.call("set_game_locale", "zh_TW")
	var owner := Control.new()
	root.add_child(owner)

	_expect_group([Pistol, CombatKnife, SMG], "weapon", owner)
	_expect_group([Ammo], "ammo", owner)
	_expect_group([SmallBackpack, BasicHelmet, LightArmor, TacticalHeadset, TacticalGlasses], "equipment", owner)
	_expect_group([ExtendedMagazine], "attachment", owner)
	_expect_group([LifeTotem, DefenseTotem], "totem", owner)
	_expect_group([Bandage, StaminaPotion], "medical", owner)
	_expect_group([BottledWater, Bread], "food", owner)
	_expect_group([Wood], "crafting", owner)
	_expect_group([WarehouseKey], "key", owner)
	_expect_group([Junk], "loot", owner)
	_expect_group([Cash], "currency", owner)
	_expect_category_order_contract()
	_expect_catalog_order()

	owner.queue_free()
	localization.queue_free()
	if _errors.is_empty():
		print("[codex_category_grouping] OK order=weapon/ammo/equipment/attachment/totem/medical/food/item-knowledge/other auto=all_item_defs")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _expect_group(items: Array, expected_id: String, owner: Control) -> void:
	for item in items:
		var item_def := item as ItemDef
		if item_def == null:
			_errors.append("Missing item while validating codex category %s." % expected_id)
			continue
		var actual_id := ItemCodexPresenterScript.codex_category_id(item_def)
		if actual_id != expected_id:
			_errors.append("No.%d %s should be codex category %s, got %s." % [item_def.catalog_number, item_def.id, expected_id, actual_id])
		var expected_label := owner.tr("codex_category.%s" % expected_id)
		var actual_label := ItemCodexPresenterScript.codex_category_name(owner, item_def)
		if actual_label != expected_label:
			_errors.append("No.%d %s should show category %s, got %s." % [item_def.catalog_number, item_def.id, expected_label, actual_label])


func _expect_category_order_contract() -> void:
	var expected_order := ["weapon", "ammo", "equipment", "attachment", "totem", "medical", "food", "crafting", "electronics", "key", "loot", "currency", "valuable", "intel", "quest", "recipe", "explosive", "other"]
	var actual_order := ItemCodexPresenterScript.codex_category_order()
	if actual_order != expected_order:
		_errors.append("Codex category order should be %s, got %s." % [expected_order, actual_order])


func _expect_catalog_order() -> void:
	var catalog := ItemCodexCatalogScript.new()
	catalog.reload()
	if catalog.item_count() != 22:
		_errors.append("Codex should include exactly 22 active ItemDef resources.")

	_expect_slot_tooltip_number(catalog, Wood)

	var previous_order := -1
	for number in range(1, catalog.item_count() + 1):
		var item := catalog.get_item(number)
		var order := ItemCodexPresenterScript.codex_category_sort_order(item)
		if order < previous_order:
			_errors.append("Codex display slot %d breaks the requested category order." % number)
		previous_order = order


func _expect_slot_tooltip_number(catalog: RefCounted, expected_item: ItemDef) -> void:
	var display_slot := int(catalog.call("display_slot_for_item_id", expected_item.id))
	var slot := ItemCodexSlotScript.new()
	root.add_child(slot)
	slot.setup(display_slot, expected_item)
	var expected_label := ItemCodexPresenterScript.catalog_label(display_slot)
	var old_label := ItemCodexPresenterScript.catalog_label(expected_item.catalog_number)
	var tooltip_lines := slot.tooltip_text.split("\n", false)
	if not tooltip_lines.has(expected_label):
		_errors.append("Codex tooltip for %s should show display slot %s." % [expected_item.id, expected_label])
	if display_slot != expected_item.catalog_number and tooltip_lines.has(old_label):
		_errors.append("Codex tooltip for %s should not keep stale item data number %s after sorting." % [expected_item.id, old_label])
	slot.queue_free()
