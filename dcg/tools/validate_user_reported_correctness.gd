extends SceneTree

const Base3DScene := preload("res://scenes/base/base_3d.tscn")
const PlayerScene := preload("res://scenes/player/player_3d.tscn")
const ScavengerScene := preload("res://scenes/enemies/scavenger_3d.tscn")
const DamageEventScript := preload("res://scripts/combat/damage_event.gd")
const LootContainerScript := preload("res://scripts/loot/loot_container_3d.gd")
const RaidLossRulesScript := preload("res://scripts/raid/raid_loss_rules.gd")
const RaidResultApplierScript := preload("res://scripts/raid/raid_result_applier.gd")
const RaidResultScript := preload("res://scripts/raid/raid_result.gd")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")

const GAMEPLAY_SCENE := "res://scenes/gameplay/player_test_world_3d.tscn"
const VALIDATION_SAVE_ROOT := "user://validation_user_reported_correctness"
const WoodItem := preload("res://data/items/crafting/wood.tres")
const AmmoItem := preload("res://data/items/ammo/ammo_9mm.tres")
const PistolItem := preload("res://data/items/weapons/pistol_9mm.tres")
const CashItem := preload("res://data/items/currency/cash.tres")
const FirstSalvageQuest := preload("res://data/quests/first_salvage.tres")

var _errors: Array[String] = []
var _save_manager: Node = null
var _created_save_manager := false


class FakeRaidPlayer:
	extends Node3D

	var inventory_model := InventoryModel.new()
	var safe_pocket_model := InventoryModel.new()
	var equipment_model := EquipmentModel.new()

	func _init() -> void:
		inventory_model.setup(12)
		safe_pocket_model.setup(2)

	func get_inventory_model() -> InventoryModel:
		return inventory_model

	func get_safe_pocket_model() -> InventoryModel:
		return safe_pocket_model

	func get_equipment_model() -> RefCounted:
		return equipment_model


class FakeLootPlayer:
	extends CharacterBody3D

	var inventory_model := InventoryModel.new()

	func _init() -> void:
		add_to_group("player")
		inventory_model.setup(24)

	func get_inventory_model() -> InventoryModel:
		return inventory_model


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	_setup_save_manager()
	await _validate_raid_gate_has_no_briefing()
	_validate_english_translations_do_not_fall_back_to_chinese()
	await _validate_enemy_death_creates_f_loot_grid()
	await _validate_equipped_pistol_can_return_to_backpack()
	await _validate_safe_pocket_returns_to_base_on_death()
	await _validate_inventory_money_display_tracks_cash_and_rewards()
	await _validate_extracted_cash_becomes_money()
	_cleanup_validation_root(VALIDATION_SAVE_ROOT)
	if _created_save_manager:
		_free_node(_save_manager)
	if _errors.is_empty():
		print("[user_reported_correctness] OK raid_gate=no_briefing locale=en corpse_loot=F_grid unequip=pistol safe_pocket=returns_to_base money=wallet_sync")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_raid_gate_has_no_briefing() -> void:
	var scene := Base3DScene.instantiate()
	root.add_child(scene)
	current_scene = scene
	await _wait_frames(3)
	if scene.get_node_or_null("HUD/RaidBriefingPanel") != null:
		_errors.append("Raid gate should not mount the removed briefing panel.")
	var controller := scene.get_node_or_null("BaseInteractionController3D")
	if controller == null:
		_errors.append("Base scene should include BaseInteractionController3D.")
		_free_current_scene()
		return
	if not bool(controller.call("open_interaction_by_id", "raid_gate")):
		_errors.append("Raid gate should directly start the raid.")
		_free_current_scene()
		return
	await _wait_frames(14)
	if current_scene == null:
		_errors.append("Raid gate should leave a loaded gameplay scene.")
	elif current_scene.scene_file_path != GAMEPLAY_SCENE:
		_errors.append("Raid gate should load gameplay, got `%s`." % current_scene.scene_file_path)
	_free_current_scene()


func _validate_english_translations_do_not_fall_back_to_chinese() -> void:
	TranslationServer.set_locale("en")
	var keys := PackedStringArray([
		"ui.base.station.raid_gate",
		"prompt.pickup",
		"prompt.start_raid_format",
		"prompt.loot_corpse",
		"prompt.view_corpse",
		"ui.container.enemy_corpse",
		"ui.inventory.safe_pocket",
		"ui.stash.title_format",
		"ui.stash.store_hint",
		"ui.stash.ready",
		"ui.stash.saved",
		"ui.stash.locked",
		"ui.stash.unlocked",
		"ui.stash.locked_item",
		"ui.stash.needed_marked",
		"ui.stash.needed_unmarked",
		"ui.stash.store_all",
		"ui.stash.store_all_done",
		"ui.stash.store_all_partial",
		"ui.stash.store_all_locked_only",
		"ui.stash.store_all_empty",
		"ui.stash.storage_upgrade",
		"ui.stash.storage_upgrade_owned",
		"ui.stash.storage_upgrade_ready_format",
		"ui.stash.storage_upgrade_owned_format",
		"ui.stash.storage_upgrade_all_owned_format",
		"ui.stash.storage_upgrade_no_save",
		"ui.stash.storage_upgrade_missing_money",
		"ui.stash.storage_upgrade_missing_items",
		"ui.stash.storage_upgrade_done",
		"ui.stash.storage_upgrade_failed",
		"ui.raid_result.safe_pocket_items",
		"ui.raid_result.transfer_dead",
		"ui.raid_result.status_dead",
		"ui.common.close",
		"ui.common.execute",
		"prompt.record_location",
		"prompt.location_recorded",
		"ui.top.status_armor_no_bonus",
		"ui.top.status_armor_bonus_format",
		"ui.top.status_armor_missing",
		"ui.top.status_armor_item_no_bonus_format",
		"ui.top.status_armor_item_bonus_format",
		"ui.raid_hud.reload_ready",
		"ui.raid_hud.reloading",
		"ui.raid_hud.reload_complete",
		"ui.raid_hud.reload_cancelled",
		"ui.raid_hud.weapon_status_using_item",
		"ui.player_hud.loaded_bullets",
		"ui.item_use.using_format",
		"ui.item_use.complete",
		"ui.item_use.cancelled",
		"ui.top.status_slot_weapon_mag",
		"ui.top.status_slot_weapon_grip",
		"ui.top.status_slot_weapon_muzzle",
		"ui.top.status_slot_weapon_scope",
		"ui.top.status_slot_weapon_stock",
		"ui.top.status_slot_weapon_tactic",
		"ui.equipment.weapon_mag",
		"ui.equipment.weapon_grip",
		"ui.equipment.weapon_muzzle",
		"ui.equipment.weapon_scope",
		"ui.equipment.weapon_stock",
		"ui.equipment.weapon_tactic",
		"ui.weapon_mod.slot_format",
		"ui.weapon_mod.empty_slot",
		"ui.weapon_mod.installed_format",
		"ui.item.weapon_attachment_slots_format",
		"ui.top.quest_board_title",
		"ui.top.quest_board_hint",
		"ui.top.quest_tab_available",
		"ui.top.quest_tab_active",
		"ui.top.quest_tab_completed",
		"ui.top.quest_sort_default",
		"ui.top.quest_conditions",
		"ui.top.quest_rewards",
		"ui.top.quest_empty_category",
		"ui.top.quest_empty_category_hint",
		"ui.top.quest_select_hint",
		"ui.top.quest_action_unavailable",
		"ui.top.quest_accept_action",
		"ui.top.quest_submit_action",
		"ui.top.quest_completed_action",
		"ui.top.quest_active_action",
		"ui.top.quest_not_accepted",
		"ui.top.quest_default_description",
		"ui.top.quest_no_reward",
		"ui.top.quest_reward_money",
		"quest.first_salvage.name",
		"quest.first_salvage.desc",
		"quest.first_scavenger_hunt.name",
		"quest.first_scavenger_hunt.desc",
		"quest.radio_tower_scout.name",
		"quest.radio_tower_scout.desc",
		"base_upgrade.storage_expansion_level_1.name",
		"base_upgrade.storage_expansion_level_2.name",
		"item.stabilizing_stock.name",
		"item.stabilizing_stock.desc",
		"item.targeting_laser.name",
		"item.targeting_laser.desc",
		"enemy.scavenger.name",
		"enemy.status.idle",
		"enemy.status.dead",
		"enemy.status.injured",
		"enemy.status.chase",
		"enemy.status.attack",
		"enemy.status.alert",
	])
	for key in keys:
		var translated := TranslationServer.translate(key)
		if translated == key or translated.strip_edges() == "":
			_errors.append("English localization key should be translated: %s." % key)
		elif _contains_cjk(translated):
			_errors.append("English localization key should not show Chinese text: %s -> %s." % [key, translated])
	var pickup_prompt := TranslationServer.translate("prompt.pickup")
	if not pickup_prompt.to_lower().contains("pick up"):
		_errors.append("English pickup prompt should explain the pickup action.")
	TranslationServer.set_locale("zh_TW")


func _validate_enemy_death_creates_f_loot_grid() -> void:
	var map_root := Node3D.new()
	root.add_child(map_root)
	var enemy := ScavengerScene.instantiate()
	map_root.add_child(enemy)
	await process_frame
	var lethal := DamageEventScript.new(999.0, null, null, [&"validation"])
	enemy.call("apply_damage", lethal)
	await _wait_frames(2)
	var corpse := _first_loot_container(map_root)
	if corpse == null:
		_errors.append("Enemy death should create a lootable corpse container.")
		_free_node(map_root)
		return
	if int(corpse.get("interact_keycode")) != KEY_F:
		_errors.append("Enemy corpse should use F for looting.")
	var model: RefCounted = corpse.call("get_container_inventory_model")
	if model == null or not model.has_method("get_capacity") or int(model.call("get_capacity")) <= 0:
		_errors.append("Enemy corpse should expose a grid-like container inventory.")
	elif int(model.call("get_used_slots")) <= 0:
		_errors.append("Enemy corpse container should contain dropped item stacks.")
	var player := FakeLootPlayer.new()
	map_root.add_child(player)
	if not bool(corpse.call("try_open", player)):
		_errors.append("Enemy corpse should open through the container loot path.")
	_free_node(map_root)


func _validate_equipped_pistol_can_return_to_backpack() -> void:
	var player := PlayerScene.instantiate()
	root.add_child(player)
	await _wait_frames(3)
	if not player.has_method("add_item_resource") or not player.has_method("equip_inventory_stack") or not player.has_method("unequip_equipment_slot"):
		_errors.append("Player should expose backpack, equipment, and unequip flow.")
		_free_node(player)
		return
	var inventory: InventoryModel = player.call("get_inventory_model")
	inventory.add_stack(_damaged_pistol_stack(37, 81))
	var equipment: RefCounted = player.call("get_equipment_model")
	var pistol_index := _stack_index_with_item(inventory.get_display_items(), PistolItem.resource_path)
	if pistol_index < 0 or not bool(player.call("equip_inventory_stack", pistol_index, &"primary_weapon")):
		_errors.append("Player should equip backpack pistol into equipment.")
		_free_node(player)
		return
	if not bool(player.call("unequip_equipment_slot", &"primary_weapon")):
		_errors.append("Equipped pistol should return to backpack.")
	if not equipment.call("is_empty", &"primary_weapon"):
		_errors.append("Unequipping pistol should clear the equipment slot.")
	if _stack_index_with_item(inventory.get_display_items(), PistolItem.resource_path) < 0:
		_errors.append("Unequipping pistol should restore it to the backpack inventory.")
	var returned_index := _stack_index_with_item(inventory.get_display_items(), PistolItem.resource_path)
	if returned_index >= 0:
		var returned_stack: Dictionary = inventory.get_display_items()[returned_index]
		if int(returned_stack.get("current_durability", 0)) != 37 or int(returned_stack.get("max_durability", 0)) != 81:
			_errors.append("Unequipping pistol should preserve durability in the backpack inventory.")
	_free_node(player)


func _validate_safe_pocket_returns_to_base_on_death() -> void:
	var test_root := Node3D.new()
	root.add_child(test_root)
	var player := FakeRaidPlayer.new()
	player.name = "Player3D"
	player.inventory_model.add_item(WoodItem, 2)
	player.safe_pocket_model.add_item(AmmoItem, 6)
	player.safe_pocket_model.add_stack(_damaged_pistol_stack(39, 80))
	player.equipment_model.equip_stack(&"sidearm", _damaged_pistol_stack(31, 76))
	test_root.add_child(player)

	_save_manager.call("set_current_slot_index", 1)
	_save_manager.call("save_slot_data", 1, {
		"difficulty_id": "normal",
		"money": 5,
		"stash": [{"item_path": AmmoItem.resource_path, "quantity": 2}],
		"base_upgrades": {},
		"quests": {},
	})

	var applier := RaidResultApplierScript.new()
	applier.name = "RaidResultApplier"
	applier.player_path = NodePath("../Player3D")
	test_root.add_child(applier)
	await process_frame

	var context := RaidLossRulesScript.build_death_context_from_player(player)
	var lost_items: Array = context.get("lost_items", []) as Array
	var kept_items: Array = context.get("kept_safe_pocket_items", []) as Array
	if _stack_quantity(lost_items, WoodItem.resource_path) != 2:
		_errors.append("Death should mark backpack items as lost.")
	if _stack_quantity(lost_items, PistolItem.resource_path) != 1:
		_errors.append("Death should mark equipped pistol as lost.")
	if _stack_quantity(kept_items, AmmoItem.resource_path) != 6:
		_errors.append("Death should keep safe pocket items.")
	if not _stack_has_durability(kept_items, PistolItem.resource_path, 39, 80):
		_errors.append("Death should keep safe pocket item durability.")
	var result := RaidResultScript.create(RaidResultScript.OUTCOME_DEAD, context)
	if not bool(applier.call("apply_raid_result", result)):
		_errors.append("Death result should apply through RaidResultApplier.")
	var saved_after: Dictionary = _save_manager.call("get_slot_data", 1)
	var stash: Array = saved_after.get("stash", []) as Array
	if _stack_quantity(stash, AmmoItem.resource_path) != 8:
		_errors.append("Safe pocket items should return to base stash on death.")
	if _stack_quantity(stash, WoodItem.resource_path) != 0 or _stack_quantity(stash, PistolItem.resource_path) != 1:
		_errors.append("Lost backpack and equipped pistol should not return to base stash on death.")
	if not _stack_has_durability(stash, PistolItem.resource_path, 39, 80):
		_errors.append("Safe pocket pistol should return to base stash with durability preserved.")
	if player.inventory_model.get_used_slots() != 0 or player.safe_pocket_model.get_used_slots() != 0 or not player.equipment_model.is_empty(&"sidearm"):
		_errors.append("Death apply should clear temporary raid backpack, safe pocket, and equipment.")
	_free_node(test_root)


func _validate_inventory_money_display_tracks_cash_and_rewards() -> void:
	_save_manager.call("set_current_slot_index", 1)
	_save_manager.call("save_slot_data", 1, {
		"difficulty_id": "normal",
		"money": 10,
		"stash": [],
		"base_upgrades": {},
		"quests": {},
	})

	var scene := Base3DScene.instantiate()
	root.add_child(scene)
	current_scene = scene
	await _wait_frames(3)

	var player := scene.get_node_or_null("Player3D")
	var inventory_ui := scene.find_child("InventoryEquipmentUI", true, false) as Control
	if player == null or inventory_ui == null:
		_errors.append("Base scene should expose player inventory UI for wallet validation.")
		_free_current_scene()
		return
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	backpack_model.clear()
	backpack_model.add_item(CashItem, 7)
	inventory_ui.call("open_inventory")
	await process_frame
	var cash_state: Dictionary = inventory_ui.call("get_display_state")
	if int(cash_state.get("money", -1)) != 17:
		_errors.append("Inventory wallet should show saved money plus carried cash, expected 17 got %d." % int(cash_state.get("money", -1)))

	var save_data: Dictionary = _save_manager.call("get_slot_data", 1)
	var quests: Dictionary = save_data.get("quests", {}) as Dictionary
	var ready_state := QuestState.accept(FirstSalvageQuest)
	ready_state = QuestState.update_from_extracted_items(ready_state, FirstSalvageQuest, [
		{"item_path": WoodItem.resource_path, "quantity": 2},
	])
	quests[str(FirstSalvageQuest.get("id"))] = ready_state
	save_data["quests"] = quests
	var claim_result: Dictionary = QuestState.claim_reward(save_data, ready_state, FirstSalvageQuest)
	if not bool(claim_result.get("success", false)):
		_errors.append("Wallet validation quest reward setup should be claimable.")
	else:
		var updated_save: Dictionary = claim_result.get("save_data", {}) as Dictionary
		var updated_quests: Dictionary = updated_save.get("quests", {}) as Dictionary
		updated_quests[str(FirstSalvageQuest.get("id"))] = claim_result.get("quest_state", {}) as Dictionary
		updated_save["quests"] = updated_quests
		_save_manager.call("save_slot_data", 1, updated_save)
		await process_frame
		var reward_state: Dictionary = inventory_ui.call("get_display_state")
		var expected_money := 10 + int(FirstSalvageQuest.get("reward_money")) + 7
		if int(reward_state.get("money", -1)) != expected_money:
			_errors.append("Inventory wallet should refresh after quest reward, expected %d got %d." % [expected_money, int(reward_state.get("money", -1))])

	var layout_source := FileAccess.get_file_as_string("res://scripts/ui/inventory_equipment_layout.gd")
	var ui_source := FileAccess.get_file_as_string("res://scripts/ui/inventory_equipment_ui.gd")
	if layout_source.contains("premium_currency_rect") or ui_source.contains("premium_money"):
		_errors.append("Inventory wallet should not keep the removed premium D currency slot.")
	_free_current_scene()


func _validate_extracted_cash_becomes_money() -> void:
	var test_root := Node3D.new()
	root.add_child(test_root)
	var player := FakeRaidPlayer.new()
	player.name = "Player3D"
	test_root.add_child(player)

	_save_manager.call("set_current_slot_index", 1)
	_save_manager.call("save_slot_data", 1, {
		"difficulty_id": "normal",
		"money": 4,
		"stash": [],
		"base_upgrades": {},
		"quests": {},
	})

	var applier := RaidResultApplierScript.new()
	applier.name = "RaidResultApplier"
	applier.player_path = NodePath("../Player3D")
	test_root.add_child(applier)
	await process_frame

	var result := RaidResultScript.create(RaidResultScript.OUTCOME_EXTRACTED, {
		"money_delta": 3,
		"extracted_items": [
			{"item_path": CashItem.resource_path, "quantity": 9},
			{"item_path": WoodItem.resource_path, "quantity": 1},
		],
	})
	if not bool(applier.call("apply_raid_result", result)):
		_errors.append("Cash extraction result should apply through RaidResultApplier.")
	var saved_after: Dictionary = _save_manager.call("get_slot_data", 1)
	if int(saved_after.get("money", 0)) != 16:
		_errors.append("Extracted cash should convert into saved money, expected 16 got %d." % int(saved_after.get("money", 0)))
	var stash: Array = saved_after.get("stash", []) as Array
	if _stack_quantity(stash, CashItem.resource_path) != 0:
		_errors.append("Extracted cash should not remain as a stash item after wallet conversion.")
	if _stack_quantity(stash, WoodItem.resource_path) != 1:
		_errors.append("Non-cash extracted loot should still move to stash.")
	_free_node(test_root)


func _setup_save_manager() -> void:
	_save_manager = root.get_node_or_null("SaveGameManager")
	if _save_manager == null:
		_save_manager = SaveGameManagerScript.new()
		_save_manager.name = "SaveGameManager"
		root.add_child(_save_manager)
		_created_save_manager = true
	_save_manager.set("save_root_path", VALIDATION_SAVE_ROOT)
	_cleanup_validation_root(VALIDATION_SAVE_ROOT)
	_save_manager.call("set_current_slot_index", 1)
	_save_manager.call("save_slot_data", 1, {
		"difficulty_id": "normal",
		"money": 0,
		"stash": [],
		"base_upgrades": {},
		"quests": {},
	})


func _first_loot_container(parent: Node) -> LootContainer3D:
	for child in parent.find_children("*", "Area3D", true, false):
		if child.get_script() == LootContainerScript:
			return child as LootContainer3D
	return null


func _stack_index_with_item(stacks: Array, item_path: String) -> int:
	for index in range(stacks.size()):
		var value: Variant = stacks[index]
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("resource_path", "")) == item_path:
			return index
	return -1


func _stack_quantity(stacks: Array, item_path: String) -> int:
	var total := 0
	for value in stacks:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var stack := value as Dictionary
		if str(stack.get("item_path", stack.get("resource_path", ""))) == item_path:
			total += int(stack.get("quantity", 0))
	return total


func _stack_has_durability(stacks: Array, item_path: String, current: int, maximum: int) -> bool:
	for value in stacks:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var stack := value as Dictionary
		if str(stack.get("item_path", stack.get("resource_path", ""))) == item_path and int(stack.get("current_durability", -1)) == current and int(stack.get("max_durability", -1)) == maximum:
			return true
	return false


func _damaged_pistol_stack(current: int, maximum: int) -> Dictionary:
	var stack := PistolItem.to_stack(1)
	stack["current_durability"] = current
	stack["max_durability"] = maximum
	stack["original_max_durability"] = PistolItem.max_durability
	stack["repair_max_durability_loss"] = PistolItem.repair_max_durability_loss
	return stack


func _contains_cjk(value: String) -> bool:
	for codepoint in value.to_utf32_buffer():
		if (codepoint >= 0x3400 and codepoint <= 0x9FFF) or (codepoint >= 0xF900 and codepoint <= 0xFAFF):
			return true
	return false


func _cleanup_validation_root(root_path: String) -> void:
	var absolute := ProjectSettings.globalize_path(root_path)
	if DirAccess.dir_exists_absolute(absolute):
		DirAccess.remove_absolute("%s/slot_1.json" % absolute)
		DirAccess.remove_absolute("%s/slot_2.json" % absolute)
		DirAccess.remove_absolute("%s/slot_3.json" % absolute)
		DirAccess.remove_absolute(absolute)


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _free_current_scene() -> void:
	var scene := current_scene
	current_scene = null
	if scene == null or not is_instance_valid(scene):
		return
	_free_node(scene)


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
