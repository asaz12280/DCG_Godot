extends SceneTree

const LocalizationBootstrapScript := preload("res://scripts/localization/localization_bootstrap.gd")
const ItemCodexCatalogScript := preload("res://scripts/ui/item_codex_catalog.gd")
const ItemCodexPresenterScript := preload("res://scripts/ui/item_codex_presenter.gd")
const ItemStackTooltipPresenterScript := preload("res://scripts/ui/item_stack_tooltip_presenter.gd")
const WeaponAttachmentServiceScript := preload("res://scripts/combat/weapon_attachment_service.gd")
const WeaponControllerScript := preload("res://scripts/combat/weapon_controller_3d.gd")
const WeaponTuningServiceScript := preload("res://scripts/combat/weapon_tuning_service.gd")
const SMG := preload("res://data/items/weapons/smg_9mm.tres")
const Ammo := preload("res://data/items/ammo/ammo_9mm.tres")
const ExtendedMagazine := preload("res://data/items/attachments/extended_magazine.tres")
const BalancedGrip := preload("res://data/items/attachments/balanced_grip.tres")
const CompactMuzzle := preload("res://data/items/attachments/compact_muzzle.tres")
const ReflexSight := preload("res://data/items/attachments/reflex_sight.tres")
const StabilizingStock := preload("res://data/items/attachments/stabilizing_stock.tres")
const TargetingLaser := preload("res://data/items/attachments/targeting_laser.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	var localization := LocalizationBootstrapScript.new()
	root.add_child(localization)
	await process_frame
	var owner := Control.new()
	root.add_child(owner)
	_validate_item_data()
	_validate_codex(owner, localization)
	_validate_tooltip(owner, localization)
	_validate_weapon_template_coupling()
	_validate_source_boundaries()
	owner.queue_free()
	localization.queue_free()
	if _errors.is_empty():
		print("[smg_codex_entry] OK item=smg_9mm codex=weapon localization=zh_TW/en stats=profile")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_item_data() -> void:
	if SMG.id != &"smg_9mm":
		_errors.append("SMG codex item should use id smg_9mm.")
	if SMG.catalog_number != 20:
		_errors.append("SMG codex item should use catalog number 20.")
	if SMG.item_type != "weapon" or not SMG.tags.has(&"gun") or not SMG.tags.has(&"smg"):
		_errors.append("SMG should be a gun weapon tagged as smg.")
	if SMG.weapon_profile == null:
		_errors.append("SMG should use WeaponProfile.")
	if SMG.get_weapon_damage() != 16:
		_errors.append("SMG WeaponProfile should set damage 16.")
	if SMG.get_weapon_magazine_capacity() != 24:
		_errors.append("SMG WeaponProfile should set magazine capacity 24.")
	if SMG.get_max_durability() != 120:
		_errors.append("SMG should be repairable with 120 durability.")
	if not SMG.get_weapon_compatible_ammo_tags().has(&"S"):
		_errors.append("SMG should use S-tag 9mm ammo.")
	for hardpoint in [&"magazine", &"grip", &"muzzle", &"scope", &"stock", &"tactic"]:
		if not SMG.get_weapon_attachment_slots().has(hardpoint):
			_errors.append("SMG should inherit the pistol weapon-template hardpoint: %s." % hardpoint)


func _validate_codex(owner: Control, localization: Node) -> void:
	localization.call("set_game_locale", "zh_TW")
	var catalog := ItemCodexCatalogScript.new()
	catalog.reload()
	var display_slot := catalog.display_slot_for_item_id(SMG.id)
	if display_slot != 3:
		_errors.append("SMG should appear as the third weapon codex entry, got slot %d." % display_slot)
	var item := catalog.get_item(display_slot)
	if item != SMG:
		_errors.append("SMG codex display slot should point to smg_9mm.")
	if ItemCodexPresenterScript.codex_category_id(SMG) != "weapon":
		_errors.append("SMG should be grouped under the weapon codex category.")
	if ItemCodexPresenterScript.item_name(owner, SMG) != "衝鋒槍-S":
		_errors.append("SMG zh_TW codex name should be localized.")

	localization.call("set_game_locale", "en")
	if ItemCodexPresenterScript.item_name(owner, SMG) != "SMG-S":
		_errors.append("SMG English codex name should be localized.")


func _validate_tooltip(owner: Control, localization: Node) -> void:
	localization.call("set_game_locale", "en")
	var tooltip_text := ItemStackTooltipPresenterScript.tooltip_text(
		ItemStackTooltipPresenterScript.build(owner, SMG.to_stack(1))
	)
	for required in ["SMG-S", "#20", "Type: Weapon", "Damage 16", "Magazine 24", "Durability 120/120"]:
		if not tooltip_text.contains(required):
			_errors.append("SMG tooltip should contain '%s'." % required)
	if tooltip_text.contains("衝鋒槍"):
		_errors.append("SMG English tooltip should not show Traditional Chinese text.")


func _validate_weapon_template_coupling() -> void:
	var weapon_stack := SMG.to_stack(1)
	weapon_stack["weapon_mods"] = {
		"magazine": ExtendedMagazine.to_stack(1),
		"grip": BalancedGrip.to_stack(1),
		"muzzle": CompactMuzzle.to_stack(1),
		"scope": ReflexSight.to_stack(1),
		"stock": StabilizingStock.to_stack(1),
		"tactic": TargetingLaser.to_stack(1),
	}
	var attachment_state: Dictionary = WeaponAttachmentServiceScript.modifiers_for_weapon_stack(weapon_stack, SMG)
	if int(attachment_state.get("magazine_capacity_bonus", 0)) != 4:
		_errors.append("SMG should receive the pistol-template extended magazine bonus.")
	for id in ["extended_magazine", "balanced_grip", "compact_muzzle", "reflex_sight", "stabilizing_stock", "targeting_laser"]:
		if not (attachment_state.get("attachment_ids", []) as Array).has(id):
			_errors.append("SMG should accept weapon-template attachment %s." % id)
	for slot in ["magazine", "grip", "muzzle", "scope", "stock", "tactic"]:
		if not (attachment_state.get("attachment_slots", []) as Array).has(slot):
			_errors.append("SMG should expose applied weapon-template hardpoint %s." % slot)
	var snapshot: Dictionary = WeaponTuningServiceScript.resolve_snapshot(SMG, Ammo, attachment_state, weapon_stack)
	if int(snapshot.get("magazine_capacity", 0)) != 28:
		_errors.append("SMG snapshot should resolve magazine capacity 28 with Extended Magazine-S.")
	if float(snapshot.get("horizontal_recoil", 0.0)) >= SMG.get_weapon_horizontal_recoil():
		_errors.append("SMG snapshot should include recoil-reducing weapon attachments.")
	var controller := WeaponControllerScript.new()
	root.add_child(controller)
	if not controller.equip_weapon(SMG, 0, attachment_state):
		_errors.append("WeaponController3D should equip SMG through the same template bridge as pistol.")
	elif int(controller.get("magazine_size")) != 28:
		_errors.append("WeaponController3D should resolve SMG magazine size 28 from template attachments.")
	controller.queue_free()


func _validate_source_boundaries() -> void:
	var item_source := FileAccess.get_file_as_string("res://data/items/weapons/smg_9mm.tres")
	for required in ["weapon_profile", "name_key", "description_key", "item.smg_9mm.name"]:
		if not item_source.contains(required):
			_errors.append("SMG ItemDef should keep authored data/key boundary: %s." % required)
	for attachment_path in [
		"res://data/items/attachments/extended_magazine.tres",
		"res://data/items/attachments/balanced_grip.tres",
		"res://data/items/attachments/compact_muzzle.tres",
		"res://data/items/attachments/reflex_sight.tres",
		"res://data/items/attachments/stabilizing_stock.tres",
		"res://data/items/attachments/targeting_laser.tres",
	]:
		var attachment_source := FileAccess.get_file_as_string(attachment_path)
		if not attachment_source.contains("&\"smg\""):
			_errors.append("%s should declare SMG compatibility instead of staying pistol-only." % attachment_path)
	var localization_source := FileAccess.get_file_as_string("res://data/localization/game_text.csv")
	for required in ["item.smg_9mm.name", "衝鋒槍-S", "SMG-S", "冲锋枪-S"]:
		if not localization_source.contains(required):
			_errors.append("Localization table should contain SMG key/text: %s." % required)
