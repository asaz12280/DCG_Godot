extends SceneTree

const WeaponModPanelStateBuilderScript := preload("res://scripts/ui/weapon_mod_panel_state_builder.gd")
const WeaponModPanelPresenterScript := preload("res://scripts/ui/weapon_mod_panel_presenter.gd")
const ItemStackTooltipPresenterScript := preload("res://scripts/ui/item_stack_tooltip_presenter.gd")
const ItemDetailPanelPresenterScript := preload("res://scripts/ui/item_detail_panel_presenter.gd")
const ItemCodexCatalogScript := preload("res://scripts/ui/item_codex_catalog.gd")
const ItemCodexPresenterScript := preload("res://scripts/ui/item_codex_presenter.gd")
const ItemInspectionFieldPolicyScript := preload("res://scripts/ui/item_inspection_field_policy.gd")
const WeaponHardpointLabelsScript := preload("res://scripts/ui/weapon_hardpoint_labels.gd")
const LocalizationBootstrapScript := preload("res://scripts/localization/localization_bootstrap.gd")
const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const Pistol := preload("res://data/items/weapons/pistol_S.tres")
const CombatKnife := preload("res://data/items/weapons/combat_knife.tres")
const BasicHelmet := preload("res://data/items/armor/basic_helmet.tres")
const Bandage := preload("res://data/items/medical/bandage.tres")
const Bread := preload("res://data/items/food/bread.tres")
const BottledWater := preload("res://data/items/food/bottled_water.tres")
const LifeTotem := preload("res://data/items/totems/life_totem.tres")
const DefenseTotem := preload("res://data/items/totems/defense_totem.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	var localization := LocalizationBootstrapScript.new()
	root.add_child(localization)
	localization.call("_load_csv_translations")
	TranslationServer.set_locale("zh_TW")
	_validate_weapon_capabilities()
	_validate_weapon_panel_classification()
	_validate_general_item_classification()
	_validate_authored_effect_coverage()
	_validate_codex_index()
	await _validate_inventory_surface()
	_validate_localization()
	_validate_source_boundaries()
	localization.queue_free()
	if _errors.is_empty():
		print("[item_inspection_framework] OK firearm=mods_ammo melee=weapon_stats_no_slots general=stack_weight codex=id_number_path")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_weapon_capabilities() -> void:
	_expect(Pistol.get_weapon_kind() == "firearm", "Pistol-S should be classified as a firearm by WeaponProfile.")
	_expect(Pistol.weapon_uses_ammo(), "Pistol-S should expose ammo capability.")
	_expect(Pistol.weapon_supports_attachments(), "Pistol-S should expose attachment capability.")
	_expect(CombatKnife.get_weapon_kind() == "melee", "Combat Knife should be classified as melee by WeaponProfile.")
	_expect(not CombatKnife.weapon_uses_ammo(), "Combat Knife should not expose ammo capability.")
	_expect(not CombatKnife.weapon_supports_attachments(), "Combat Knife should not expose attachment capability.")
	var knife_stack := CombatKnife.to_stack(1)
	_expect(str(knife_stack.get("weapon_kind", "")) == "melee", "Weapon stacks should preserve weapon_kind for inspection.")
	_expect(not bool(knife_stack.get("weapon_uses_ammo", true)), "Melee stacks should preserve no-ammo capability.")


func _validate_weapon_panel_classification() -> void:
	var pistol_state := WeaponModPanelStateBuilderScript.build(Pistol.to_stack(1), Pistol, &"backpack_weapon")
	_expect(bool(pistol_state.get("has_weapon", false)), "Pistol-S should open the weapon information panel.")
	_expect(not (pistol_state.get("slots", []) as Array).is_empty(), "Pistol-S should keep attachment slots.")
	_expect(bool((pistol_state.get("summary", {}) as Dictionary).get("uses_ammo", false)), "Pistol-S summary should include ammo information.")

	var knife_state := WeaponModPanelStateBuilderScript.build(CombatKnife.to_stack(1), CombatKnife, &"melee")
	var knife_summary: Dictionary = knife_state.get("summary", {}) as Dictionary
	_expect(bool(knife_state.get("has_weapon", false)), "Combat Knife should open the weapon information panel even without mod slots.")
	_expect((knife_state.get("slots", []) as Array).is_empty(), "Combat Knife should not invent attachment slots.")
	_expect(not bool(knife_summary.get("uses_ammo", true)), "Combat Knife summary should hide ammo information.")
	_expect(not bool(knife_summary.get("supports_attachments", true)), "Combat Knife summary should report no attachment support.")
	var knife_keys := _stat_keys(knife_state.get("stat_rows", []) as Array)
	for required_key in [&"ui.weapon_stat.damage", &"ui.weapon_stat.attack_rate", &"ui.weapon_stat.attack_range"]:
		_expect(knife_keys.has(required_key), "Combat Knife weapon panel should include %s." % required_key)
	for forbidden_key in [&"ui.weapon_stat.magazine_capacity", &"ui.weapon_stat.reload_duration", &"ui.weapon_stat.recoil_angle", &"ui.weapon_stat.projectile_range"]:
		_expect(not knife_keys.has(forbidden_key), "Combat Knife weapon panel should hide firearm-only stat %s." % forbidden_key)
	var presenter := WeaponModPanelPresenterScript.new()
	_expect(presenter.open(&"melee", knife_state), "Weapon panel presenter should open for weapons with zero attachment slots.")
	_expect(presenter.panel_rect(1.0, Vector2(1920.0, 1080.0)).size.y > 0.0, "Melee weapon panel should expose a valid layout rect.")


func _validate_general_item_classification() -> void:
	var owner := Control.new()
	root.add_child(owner)
	var tooltip := ItemStackTooltipPresenterScript.build(owner, Bandage.to_stack(4))
	_expect(str(tooltip.get("item_type", "")) == "medical", "Bandage should stay on the general item information path.")
	_expect((tooltip.get("lines", []) as Array).size() <= ItemInspectionFieldPolicyScript.TOOLTIP_ROW_LIMIT, "Hover tooltip should stay concise and respect the shared row limit.")
	_expect(int(tooltip.get("max_stack", 0)) == 10, "Bandage item information should expose max stack 10.")
	_expect(absf(float(tooltip.get("total_weight", 0.0)) - 0.48) < 0.001, "Bandage item information should expose quantity-based total weight.")
	var detail_lines: Array = tooltip.get("detail_lines", []) as Array
	_expect(not detail_lines.has(TranslationServer.translate("ui.item.type_format") % TranslationServer.translate("codex_category.medical")), "General item detail lines should not repeat the header type.")
	_expect(not detail_lines.has(TranslationServer.translate("ui.item.stack_weight_format") % 0.48), "General item detail lines should not repeat the header weight.")
	var info_lines: Array = tooltip.get("detail_info_lines", []) as Array
	var stat_lines: Array = tooltip.get("detail_stat_lines", []) as Array
	_expect(not info_lines.is_empty(), "General item detail should expose an item-information section.")
	_expect(not stat_lines.is_empty(), "Bandage should expose item-stat lines for its healing effect.")
	var detail_panel := ItemDetailPanelPresenterScript.new()
	detail_panel.open(tooltip)
	var detail_text := detail_panel.visible_text(owner)
	_expect(detail_text.contains(TranslationServer.translate("ui.item_detail.info_title")), "General item panel should show the Item Info heading.")
	_expect(detail_text.contains(TranslationServer.translate("ui.item_detail.stats_title")), "Bandage panel should show the Item Stats heading.")
	_validate_general_item_meta_alignment(detail_panel)
	for consumable in [Bread, BottledWater, Bandage]:
		var consumable_tooltip := ItemStackTooltipPresenterScript.build(owner, consumable.to_stack(1))
		_expect(not (consumable_tooltip.get("detail_stat_lines", []) as Array).is_empty(), "%s should expose item-stat lines when it has an authored effect." % consumable.id)
	var survival_stack := BottledWater.to_stack(1)
	survival_stack["thirst_restore"] = 20.0
	survival_stack["satiety_restore"] = 10.0
	var survival_tooltip := ItemStackTooltipPresenterScript.build(owner, survival_stack)
	var survival_stats: Array = survival_tooltip.get("detail_stat_lines", []) as Array
	_expect(survival_stats.has(TranslationServer.translate("ui.item.thirst_restore_format") % 20.0), "Authored thirst recovery should appear in Item Stats.")
	_expect(survival_stats.has(TranslationServer.translate("ui.item.satiety_restore_format") % 10.0), "Authored satiety recovery should appear in Item Stats.")
	var rows := ItemCodexPresenterScript.stat_rows(owner, Bandage)
	_expect(_row_has_label(rows, TranslationServer.translate("ui.codex.max_stack")), "Bandage codex information should include max stack.")
	_expect(_row_has_label(rows, TranslationServer.translate("ui.item_stat.heal_amount")), "Bandage codex information should include its authored healing effect.")
	_expect(not _row_has_label(rows, TranslationServer.translate("ui.codex.damage")), "Bandage codex information should not include weapon damage.")
	var knife_rows := ItemCodexPresenterScript.stat_rows(owner, CombatKnife)
	_expect(_row_has_label(knife_rows, TranslationServer.translate("ui.codex.damage")), "Combat Knife codex information should include weapon damage.")
	_expect(_row_has_label(knife_rows, TranslationServer.translate("ui.weapon_stat.attack_rate")), "Combat Knife codex information should include attack speed.")
	_expect(_row_has_label(knife_rows, TranslationServer.translate("ui.weapon_stat.attack_range")), "Combat Knife codex information should include attack range.")
	_expect(not _row_has_label(knife_rows, TranslationServer.translate("ui.weapon_stat.magazine_capacity")), "Combat Knife codex information should hide magazine capacity.")
	var pistol_rows := ItemCodexPresenterScript.stat_rows(owner, Pistol)
	_expect(_row_has_label(pistol_rows, TranslationServer.translate("ui.item_stat.compatible_ammo")), "Firearm codex information should include compatible ammo.")
	_expect(_row_has_label(pistol_rows, TranslationServer.translate("ui.item_stat.attachment_slots")), "Moddable firearm codex information should include attachment slots.")
	_expect(_row_has_label(pistol_rows, TranslationServer.translate("ui.weapon_stat.vertical_recoil")), "Firearm codex information should include vertical recoil.")
	_expect(_row_has_label(pistol_rows, TranslationServer.translate("ui.weapon_stat.horizontal_recoil")), "Firearm codex information should include horizontal recoil.")
	_expect(_row_has_label(pistol_rows, TranslationServer.translate("ui.item_stat.durability_penalty_threshold")), "Firearm codex information should include its low-durability threshold.")
	var helmet_rows := ItemCodexPresenterScript.stat_rows(owner, BasicHelmet)
	_expect(_row_has_label(helmet_rows, TranslationServer.translate("ui.item_stat.durability_penalty_threshold")), "Durable armor codex information should include its low-durability threshold.")
	var attachment_rows := _rows_for_field(pistol_rows, &"weapon_attachment_slots")
	var hardpoints := Pistol.get_weapon_attachment_slots()
	_expect(attachment_rows.size() == hardpoints.size(), "Firearm codex should render one localized row per attachment slot.")
	for index in range(mini(attachment_rows.size(), hardpoints.size())):
		var expected_slot_name := str(TranslationServer.translate(WeaponHardpointLabelsScript.label_key(hardpoints[index])))
		_expect(str(attachment_rows[index].get("value", "")) == expected_slot_name, "Attachment slot %s should render as localized value %s." % [hardpoints[index], expected_slot_name])
	var pistol_tooltip := ItemStackTooltipPresenterScript.build(owner, Pistol.to_stack(1))
	var pistol_tooltip_lines: Array = pistol_tooltip.get("lines", []) as Array
	_expect(pistol_tooltip_lines.size() <= ItemInspectionFieldPolicyScript.WEAPON_TOOLTIP_ROW_LIMIT, "Weapon hover tooltip should remain within its concise row limit.")
	_expect(_lines_contain(pistol_tooltip_lines, TranslationServer.translate("ui.codex.durability")), "Weapon hover tooltip should include durability.")
	owner.queue_free()


func _validate_general_item_meta_alignment(detail_panel: RefCounted) -> void:
	var viewport_size := Vector2(1920.0, 1080.0)
	var rect: Rect2 = detail_panel.call("panel_rect", 1.0, viewport_size)
	var meta_origin: Vector2 = detail_panel.call("meta_text_origin", 1.0, viewport_size)
	if absf(meta_origin.x - (rect.position.x + 24.0)) > 1.0:
		_errors.append("General item header metadata should be left-aligned near the detail panel content edge, got %s for %s." % [meta_origin, rect])
	if meta_origin.x > rect.get_center().x:
		_errors.append("General item header metadata should not stay docked to the right side.")


func _validate_authored_effect_coverage() -> void:
	var owner := Control.new()
	root.add_child(owner)
	var life_state := ItemStackTooltipPresenterScript.build(owner, LifeTotem.to_stack(1))
	var life_format := str(TranslationServer.translate("ui.item.max_health_bonus_format"))
	_expect((life_state.get("detail_stat_lines", []) as Array).has(life_format % LifeTotem.max_health_bonus), "Life Totem detail should show its equipped max-health bonus.")
	_expect(_lines_contain(life_state.get("lines", []) as Array, TranslationServer.translate("ui.item_stat.max_health_bonus")), "Life Totem hover tooltip should show its max-health bonus.")
	_expect(_row_has_field(life_state.get("codex_stat_rows", []) as Array, &"max_health_bonus"), "Life Totem codex should show its max-health bonus.")
	var defense_state := ItemStackTooltipPresenterScript.build(owner, DefenseTotem.to_stack(1))
	_expect(_row_has_field(defense_state.get("codex_stat_rows", []) as Array, &"defense"), "Defense Totem codex should show its equipped defense bonus.")

	var catalog := ItemCodexCatalogScript.new()
	catalog.reload()
	for item in catalog.all_items():
		_validate_item_effect_fields(owner, item)
	owner.queue_free()


func _validate_item_effect_fields(owner: Control, item: ItemDef) -> void:
	var stack := item.to_stack(1)
	var state := ItemStackTooltipPresenterScript.build(owner, stack)
	var positive_fields := {
		"heal_amount": &"heal_amount",
		"use_duration_seconds": &"use_duration",
		"max_health_bonus": &"max_health_bonus",
		"stamina_restore": &"stamina_restore",
		"thirst_restore": &"thirst_restore",
		"satiety_restore": &"satiety_restore",
		"attachment_magazine_capacity_bonus": &"attachment_magazine_bonus",
		"repair_max_durability_loss": &"repair_wear",
	}
	for stack_key in positive_fields:
		if float(stack.get(stack_key, 0.0)) > 0.0:
			_expect_effect_field(state, item, positive_fields[stack_key])
	if maxf(float(stack.get("defense_bonus", 0.0)), float(stack.get("armor_protection_level", 0.0))) > 0.0:
		_expect_effect_field(state, item, &"defense")
	if bool(stack.get("has_durability", false)):
		_expect_effect_field(state, item, &"durability")
	var vertical := float(stack.get("attachment_vertical_recoil_multiplier", 1.0))
	var horizontal := float(stack.get("attachment_horizontal_recoil_multiplier", 1.0))
	if not is_equal_approx(vertical, 1.0) or not is_equal_approx(horizontal, 1.0):
		_expect_effect_field(state, item, &"attachment_recoil")
	if not is_equal_approx(float(stack.get("attachment_recoil_recovery_multiplier", 1.0)), 1.0):
		_expect_effect_field(state, item, &"attachment_recoil_recovery")
	if not is_equal_approx(float(stack.get("attachment_spread_multiplier", 1.0)), 1.0):
		_expect_effect_field(state, item, &"attachment_spread")


func _expect_effect_field(state: Dictionary, item: ItemDef, field_id: StringName) -> void:
	var fields: Dictionary = state.get("inspection_fields", {}) as Dictionary
	_expect(fields.has(field_id), "%s should expose authored effect field %s in the shared inspection snapshot." % [item.id, field_id])
	_expect(_row_has_field(state.get("codex_stat_rows", []) as Array, field_id), "%s codex should expose authored effect field %s." % [item.id, field_id])


func _validate_codex_index() -> void:
	var catalog := ItemCodexCatalogScript.new()
	catalog.reload()
	_expect(catalog.item_count() == catalog.item_by_id.size(), "Codex index should reject duplicate stable item ids.")
	_expect(catalog.item_count() == catalog.item_by_catalog_number.size(), "Codex index should reject duplicate authored catalog numbers.")
	_expect(catalog.item_count() == catalog.item_by_path.size(), "Codex index should keep one resource path per indexed item.")
	_expect(catalog.get_item_by_id(CombatKnife.id) == CombatKnife, "Codex index should resolve items by stable id.")
	_expect(catalog.get_item_by_catalog_number(CombatKnife.catalog_number) == CombatKnife, "Codex index should resolve items by authored catalog number.")
	_expect(catalog.get_item_by_path(CombatKnife.resource_path) == CombatKnife, "Codex index should resolve items by resource path.")
	_expect(catalog.all_items().has(Bandage), "Codex index should expose general items in its read-only item list.")


func _validate_inventory_surface() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var player := scene.get_node_or_null("Player3D")
	var inventory_ui := scene.find_child("InventoryEquipmentUI", true, false) as Control
	if player == null or inventory_ui == null:
		_errors.append("Gameplay scene should expose player and inventory UI for item inspection validation.")
		_free_node(scene)
		return
	var backpack: InventoryModel = player.call("get_inventory_model")
	backpack.clear()
	backpack.setup(50)
	backpack.add_stack(CombatKnife.to_stack(1))
	inventory_ui.call("open_inventory")
	await process_frame
	_expect(bool(inventory_ui.call("_open_weapon_mod_panel_for_backpack_stack", 0)), "Clicking a backpack melee weapon should open the weapon information panel.")
	await process_frame
	var display_state: Dictionary = inventory_ui.call("get_display_state")
	_validate_melee_panel_text(str(display_state.get("weapon_mod_panel_text", "")), display_state)
	_expect((display_state.get("item_detail_panel", {}) as Dictionary).is_empty(), "Melee weapons should not fall back to the general item panel.")
	if not bool(player.call("equip_inventory_stack", 0, &"melee")):
		_errors.append("Validation should equip Combat Knife into the melee slot.")
	else:
		await process_frame
		_expect(bool(inventory_ui.call("_open_weapon_mod_panel_for_slot", &"melee")), "Clicking an equipped melee weapon should open the same weapon information panel.")
		await process_frame
		display_state = inventory_ui.call("get_display_state")
		_validate_melee_panel_text(str(display_state.get("weapon_mod_panel_text", "")), display_state)
	_free_node(scene)


func _validate_melee_panel_text(text: String, display_state: Dictionary) -> void:
	var panel_state: Dictionary = display_state.get("weapon_mod_panel", {}) as Dictionary
	_expect(bool(panel_state.get("has_weapon", false)), "Melee weapon surface should expose weapon panel state.")
	for required_key in [&"ui.weapon_mod.summary_title", &"ui.weapon_stat.damage", &"ui.weapon_stat.attack_rate", &"ui.weapon_stat.attack_range"]:
		_expect(text.contains(TranslationServer.translate(required_key)), "Melee weapon panel should show localized %s." % required_key)
	for hidden_key in [&"ui.weapon_mod.summary_ammo", &"ui.weapon_stat.magazine_capacity", &"ui.weapon_stat.reload_duration", &"ui.weapon_stat.recoil_angle"]:
		_expect(not text.contains(TranslationServer.translate(hidden_key)), "Melee weapon panel should hide unsupported %s." % hidden_key)


func _validate_localization() -> void:
	for locale in ["zh_TW", "en"]:
		TranslationServer.set_locale(locale)
		for key in [&"ui.weapon_stat.attack_rate", &"ui.weapon_stat.attack_range", &"ui.item_stat.heal_amount", &"ui.item.total_value", &"ui.item_stat.attachment_slots"]:
			var translated := str(TranslationServer.translate(key))
			_expect(translated != "" and translated != str(key), "%s localization should cover %s." % [locale, key])
		for hardpoint in Pistol.get_weapon_attachment_slots():
			var label_key := WeaponHardpointLabelsScript.label_key(hardpoint)
			var slot_name := str(TranslationServer.translate(label_key))
			_expect(label_key != &"" and slot_name != "" and slot_name != str(label_key), "%s localization should cover weapon hardpoint %s." % [locale, hardpoint])
			_expect(slot_name != str(hardpoint), "%s weapon hardpoint %s should not expose its internal id." % [locale, hardpoint])
	TranslationServer.set_locale("zh_TW")


func _validate_source_boundaries() -> void:
	var profile_source := FileAccess.get_file_as_string("res://scripts/items/weapon_profile.gd")
	_expect(profile_source.contains("weapon_kind"), "WeaponProfile should own firearm/melee classification.")
	var item_source := FileAccess.get_file_as_string("res://scripts/items/item_def.gd")
	for required in ["get_weapon_kind", "weapon_uses_ammo", "weapon_supports_attachments", "weapon_has_durability", "thirst_restore", "satiety_restore"]:
		_expect(item_source.contains(required), "ItemDef should expose weapon inspection capability %s." % required)
	var builder_source := FileAccess.get_file_as_string("res://scripts/ui/weapon_mod_panel_state_builder.gd")
	_expect(not builder_source.contains("weapon_def.get_weapon_attachment_slots().is_empty()"), "Weapon panel routing should not reject weapons only because they have no attachment slots.")
	var detail_panel_source := FileAccess.get_file_as_string("res://scripts/ui/item_detail_panel_presenter.gd")
	_expect(detail_panel_source.contains("HORIZONTAL_ALIGNMENT_LEFT"), "General item title should follow the weapon panel's left-aligned header layout.")
	_expect(detail_panel_source.contains("detail_lines"), "General item detail panel should consume de-duplicated detail lines.")
	for required in ["INSPECTION_HEADER_HEIGHT", "INSPECTION_TITLE_FONT_SIZE", "INSPECTION_SECTION_FONT_SIZE", "INSPECTION_BODY_FONT_SIZE", "INSPECTION_ROW_HEIGHT", "meta_text_origin"]:
		_expect(detail_panel_source.contains(required), "General item panel should use shared inspection typography and left-aligned metadata through %s." % required)
	var weapon_panel_source := FileAccess.get_file_as_string("res://scripts/ui/weapon_mod_panel_presenter.gd")
	for required in ["INSPECTION_HEADER_HEIGHT", "INSPECTION_TITLE_FONT_SIZE", "INSPECTION_SECTION_FONT_SIZE", "INSPECTION_BODY_FONT_SIZE", "INSPECTION_ROW_HEIGHT", "HORIZONTAL_ALIGNMENT_RIGHT"]:
		_expect(weapon_panel_source.contains(required), "Weapon panel should use shared inspection typography and right-aligned stat values through %s." % required)
	var inspection_style_source := FileAccess.get_file_as_string("res://scripts/ui/central_overlay_panel_style.gd")
	for required in ["INSPECTION_HEADER_HEIGHT", "INSPECTION_TITLE_FONT_SIZE", "INSPECTION_CATALOG_FONT_SIZE", "INSPECTION_SECTION_FONT_SIZE", "INSPECTION_BODY_FONT_SIZE", "INSPECTION_ROW_HEIGHT"]:
		_expect(inspection_style_source.contains(required), "Central overlay style should own inspection typography token %s." % required)
	var tooltip_source := FileAccess.get_file_as_string("res://scripts/ui/item_stack_tooltip_presenter.gd")
	_expect(tooltip_source.contains("ItemInspectionSnapshotBuilderScript.build"), "Item tooltip presenter should consume the shared inspection snapshot.")
	_expect(not tooltip_source.contains("_add_consumable_rows"), "Item tooltip presenter should not own item-type field classification.")
	var policy_source := FileAccess.get_file_as_string("res://scripts/ui/item_inspection_field_policy.gd")
	for required in ["FIELD_RULES", "SURFACE_TOOLTIP", "SURFACE_DETAIL", "SURFACE_CODEX", "TOOLTIP_ROW_LIMIT", "WEAPON_TOOLTIP_ROW_LIMIT"]:
		_expect(policy_source.contains(required), "Item inspection field policy should own %s." % required)
	var snapshot_source := FileAccess.get_file_as_string("res://scripts/ui/item_inspection_snapshot_builder.gd")
	for required in ['"detail_lines": detail_lines', '"detail_info_lines": detail_info_lines', '"detail_stat_lines": detail_stat_lines', '"codex_stat_rows"']:
		_expect(snapshot_source.contains(required), "Shared item inspection snapshot should expose %s." % required)
	var weapon_rows_path := "res://scripts/items/item_inspection_weapon_rows.gd"
	var weapon_rows_source := FileAccess.get_file_as_string(weapon_rows_path)
	_expect(weapon_rows_source.contains("weapon_magazine_capacity"), "Shared weapon inspection rows should classify weapon fields.")
	_expect(FileAccess.get_file_as_string("res://scripts/player/player_equipment_controller_3d.gd").contains(weapon_rows_path), "Equipped weapon information should consume shared weapon rows.")
	_expect(FileAccess.get_file_as_string("res://scripts/ui/weapon_mod_panel_state_builder.gd").contains(weapon_rows_path), "Stash weapon information should consume shared weapon rows.")
	var localization_source := FileAccess.get_file_as_string("res://data/localization/game_text.csv")
	for required_key in ["ui.item_detail.info_title", "ui.item_detail.stats_title", "ui.item.heal_amount_format", "ui.item.stamina_restore_format", "ui.item.thirst_restore_format", "ui.item.satiety_restore_format", "ui.item_stat.heal_amount", "ui.item.total_value"]:
		_expect(localization_source.contains(required_key), "Item detail section text should be localized through %s." % required_key)
	var spec_source := FileAccess.get_file_as_string("res://docs/architecture/programming_spec_short.md")
	_expect(spec_source.contains("item type chooses the information panel"), "Short programming spec should preserve the item inspection routing rule.")


func _stat_keys(rows: Array) -> Array[StringName]:
	var keys: Array[StringName] = []
	for value in rows:
		var row := value as Dictionary
		keys.append(StringName(str(row.get("label_key", ""))))
	return keys


func _row_has_label(rows: Array[Dictionary], label: String) -> bool:
	for row in rows:
		if str(row.get("label", "")) == label:
			return true
	return false


func _row_has_field(rows: Array, field_id: StringName) -> bool:
	for value in rows:
		var row := value as Dictionary
		if StringName(str(row.get("field_id", ""))) == field_id:
			return true
	return false


func _rows_for_field(rows: Array[Dictionary], field_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in rows:
		if StringName(str(row.get("field_id", ""))) == field_id:
			result.append(row)
	return result


func _lines_contain(lines: Array, expected: String) -> bool:
	for line in lines:
		if str(line).contains(expected):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
