extends SceneTree

const ItemStackTooltipPresenterScript := preload("res://scripts/ui/item_stack_tooltip_presenter.gd")
const ItemCodexCatalogScript := preload("res://scripts/ui/item_codex_catalog.gd")
const LocalizationBootstrapScript := preload("res://scripts/localization/localization_bootstrap.gd")
const ItemDurabilityServiceScript := preload("res://scripts/items/item_durability_service.gd")
const WoodItem := preload("res://data/items/crafting/wood.tres")
const PistolItem := preload("res://data/items/weapons/pistol_S.tres")
const SMGItem := preload("res://data/items/weapons/smg_S.tres")
const AmmoItem := preload("res://data/items/ammo/ammo_S.tres")
const LightArmorItem := preload("res://data/items/armor/light_armor.tres")
const DefenseTotemItem := preload("res://data/items/totems/defense_totem.tres")

var _errors: Array[String] = []
var _catalog := ItemCodexCatalogScript.new()


func _initialize() -> void:
	var localization := LocalizationBootstrapScript.new()
	root.add_child(localization)
	await process_frame
	_catalog.reload()
	localization.call("set_game_locale", "en")
	var owner := Control.new()
	root.add_child(owner)
	_validate_material_tooltip(owner)
	_validate_weapon_tooltip(owner)
	_validate_damaged_weapon_tooltip(owner)
	_validate_ammo_tooltip(owner)
	_validate_armor_tooltip(owner)
	localization.call("set_game_locale", "zh_TW")
	_validate_zh_tw_weight_label(owner)
	_validate_zh_tw_defense_label(owner)
	owner.queue_free()
	localization.queue_free()
	if _errors.is_empty():
		print("[item_tooltips] OK shared=container/stash/codex catalog=hash type=category_only compact=total_weight durability=repair_ready needed=sources weapon_mod_slots=hidden")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_material_tooltip(owner: Control) -> void:
	var tooltip: Dictionary = ItemStackTooltipPresenterScript.build(owner, WoodItem.to_stack(3), {
		"needed_sources": [&"quest", &"workbench", &"recipe"],
	})
	var tooltip_text := ItemStackTooltipPresenterScript.tooltip_text(tooltip)
	_expect_contains(tooltip_text, "Wood", "Material tooltip should show localized item name.")
	_expect_contains(tooltip_text, _expected_codex_label(WoodItem), "Material tooltip should show the sorted codex display slot in hash format.")
	_expect_not_contains(tooltip_text, "No.1", "Material tooltip should not show the old No. catalog format.")
	_expect_contains(tooltip_text, "Type: Crafting Material", "Material tooltip should show the codex category on the type row.")
	_expect_not_contains(tooltip_text, "Type: Other", "Material tooltip should not collapse material items into the generic other category.")
	_expect_not_contains(tooltip_text, "Type: Other / Crafting Material", "Material tooltip should not append the item subtype on the type row.")
	_expect_not_contains(tooltip_text, "Codex No.1: Other", "Material tooltip should not show the old codex/category row.")
	_expect_contains(tooltip_text, "Total weight 1.80 kg", "Material tooltip should show total stack weight.")
	_expect_contains(tooltip_text, "Needed: Quest, Workbench, Recipe", "Material tooltip should show needed sources.")
	_expect_not_contains(tooltip_text, "Value 6", "Material tooltip should not show individual value after compacting generic stats.")
	_expect_not_contains(tooltip_text, "Total value 18", "Material tooltip should not show stack value after compacting generic stats.")
	_expect_not_contains(tooltip_text, "Weight 0.60 kg", "Material tooltip should not show individual weight after compacting generic stats.")
	_expect_not_contains(tooltip_text, "Stack 3/20", "Material tooltip should not show stack quantity after compacting generic stats.")
	_expect_not_contains(tooltip_text, "Value/kg 10", "Material tooltip should not show value per weight after compacting generic stats.")


func _validate_weapon_tooltip(owner: Control) -> void:
	_validate_weapon_tooltip_for_item(owner, PistolItem, "Pistol-S", _expected_codex_label(PistolItem), 20, 8, 100)
	_validate_weapon_tooltip_for_item(owner, SMGItem, "SMG-S", _expected_codex_label(SMGItem), 18, 20, 120)


func _validate_weapon_tooltip_for_item(owner: Control, item: ItemDef, expected_name: String, expected_catalog_label: String, expected_damage: int, expected_magazine: int, expected_durability: int) -> void:
	var tooltip_text := ItemStackTooltipPresenterScript.tooltip_text(
		ItemStackTooltipPresenterScript.build(owner, item.to_stack(1))
	)
	_expect_contains(tooltip_text, expected_name, "Weapon tooltip should show localized item name.")
	_expect_contains(tooltip_text, expected_catalog_label, "Weapon tooltip should show the codex number in hash format.")
	_expect_not_contains(tooltip_text, "No.5", "Weapon tooltip should not show the old No. catalog format.")
	_expect_contains(tooltip_text, "Type: Weapon", "Weapon tooltip should show the type once when codex category and item type match.")
	_expect_not_contains(tooltip_text, "Codex No.", "Weapon tooltip should not show the old codex/category row.")
	_expect_contains(tooltip_text, "Total weight", "Weapon tooltip should keep the compact total-weight line.")
	_expect_not_contains(tooltip_text, "Damage %d" % expected_damage, "Weapon tooltip should not show damage in the hover summary.")
	_expect_not_contains(tooltip_text, "Magazine %d" % expected_magazine, "Weapon tooltip should not show magazine capacity in the hover summary.")
	_expect_contains(tooltip_text, "Ammo 0/%d" % expected_magazine, "Weapon tooltip should show compact ammo state after total weight.")
	_expect_not_contains(tooltip_text, "Mod slots:", "Weapon tooltip should not show supported attachment slot categories in compact item summaries.")
	var expected_recoil := "Recoil V%.1f / H%.1f" % [item.weapon_vertical_recoil, item.weapon_horizontal_recoil]
	_expect_not_contains(tooltip_text, expected_recoil, "Weapon tooltip should not show recoil in the hover summary.")
	_expect_not_contains(tooltip_text, "Pierce chance", "Weapon tooltip should not show penetration or pierce details in the hover summary.")
	_expect_contains(tooltip_text, "Durability %d/%d" % [expected_durability, expected_durability], "Weapon tooltip should show current and max durability.")
	_expect_contains(tooltip_text, "Repair wear -%d max durability" % item.repair_max_durability_loss, "Weapon tooltip should show max durability loss on repair.")


func _validate_damaged_weapon_tooltip(owner: Control) -> void:
	var damaged_stack := PistolItem.to_stack(1)
	damaged_stack["current_durability"] = 42
	damaged_stack["max_durability"] = 88
	var normalized: Dictionary = ItemDurabilityServiceScript.normalize_stack(damaged_stack, PistolItem)
	if int(normalized.get("current_durability", 0)) != 42 or int(normalized.get("max_durability", 0)) != 88:
		_errors.append("Durability service should preserve save-backed current/max durability values.")
	if not bool(normalized.get("durability_is_low", false)):
		_errors.append("Durability service should flag items at or below the penalty threshold.")
	var tooltip_text := ItemStackTooltipPresenterScript.tooltip_text(
		ItemStackTooltipPresenterScript.build(owner, damaged_stack)
	)
	_expect_contains(tooltip_text, "Durability 42/88", "Damaged weapon tooltip should use save-backed durability values.")


func _validate_ammo_tooltip(owner: Control) -> void:
	var tooltip_text := ItemStackTooltipPresenterScript.tooltip_text(
		ItemStackTooltipPresenterScript.build(owner, AmmoItem.to_stack(6))
	)
	_expect_contains(tooltip_text, "Ammo-S", "Ammo tooltip should show localized item name.")
	_expect_not_contains(tooltip_text, "Penetration Lv.", "Ammo tooltip should not show removed ammo penetration tuning.")
	_expect_not_contains(tooltip_text, "Ammo damage", "Ammo tooltip should not show removed ammo damage tuning.")
	_expect_not_contains(tooltip_text, "Spread", "Ammo tooltip should not show removed ammo spread tuning.")
	_expect_not_contains(tooltip_text, "Weapon wear", "Ammo tooltip should not show removed ammo wear tuning.")
	_expect_not_contains(tooltip_text, "Recoil", "Ammo tooltip should not show removed ammo recoil tuning.")
	_validate_plain_catalog_number_rendering()


func _validate_armor_tooltip(owner: Control) -> void:
	var tooltip_text := ItemStackTooltipPresenterScript.tooltip_text(
		ItemStackTooltipPresenterScript.build(owner, LightArmorItem.to_stack(1))
	)
	_expect_contains(tooltip_text, "Defense 4", "Armor tooltip should show the unified armor defense value.")
	_expect_not_contains(tooltip_text, "Protection Lv.", "Armor tooltip should not show a separate armor protection formula.")


func _validate_zh_tw_weight_label(owner: Control) -> void:
	var tooltip_text := ItemStackTooltipPresenterScript.tooltip_text(
		ItemStackTooltipPresenterScript.build(owner, WoodItem.to_stack(3))
	)
	_expect_contains(tooltip_text, "總重量 1.80 kg", "Traditional Chinese tooltip should use the total weight label.")
	_expect_not_contains(tooltip_text, "整疊重量", "Traditional Chinese tooltip should not use the old stack weight label.")


func _validate_zh_tw_defense_label(owner: Control) -> void:
	var tooltip_text := ItemStackTooltipPresenterScript.tooltip_text(
		ItemStackTooltipPresenterScript.build(owner, DefenseTotemItem.to_stack(1))
	)
	_expect_contains(tooltip_text, "防禦 2", "Traditional Chinese tooltip should localize defense stats.")
	_expect_not_contains(tooltip_text, "Defense 2", "Traditional Chinese tooltip should not show English defense fallback.")


func _expect_contains(content: String, needle: String, message: String) -> void:
	if not content.contains(needle):
		_errors.append("%s Expected `%s` in `%s`." % [message, needle, content])


func _expect_not_contains(content: String, needle: String, message: String) -> void:
	if content.contains(needle):
		_errors.append("%s Did not expect `%s` in `%s`." % [message, needle, content])


func _expected_codex_label(item: ItemDef) -> String:
	var display_slot := int(_catalog.call("display_slot_for_item_id", item.id))
	return "#%d" % display_slot


func _validate_plain_catalog_number_rendering() -> void:
	for source_path in [
		"res://scripts/ui/inventory_equipment_ui.gd",
		"res://scripts/ui/base_stash_inventory_ui.gd",
	]:
		var source := FileAccess.get_file_as_string(source_path)
		if source.contains("Color(0.95, 0.36, 0.06, 0.96)") or source.contains("\"No.%d\""):
			_errors.append("%s should not render tooltip catalog numbers on the old orange badge plate." % source_path)
