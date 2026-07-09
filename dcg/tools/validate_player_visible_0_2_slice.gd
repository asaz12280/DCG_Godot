extends SceneTree

const Base3DScene := preload("res://scenes/base/base_3d.tscn")
const LootContainerScript := preload("res://scripts/loot/loot_container_3d.gd")
const ProjectileScript := preload("res://scripts/combat/projectile_3d.gd")
const ShotFeedbackScript := preload("res://scripts/combat/shot_feedback_3d.gd")
const HitFeedbackScript := preload("res://scripts/combat/projectile_hit_feedback_3d.gd")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")
const QuestStateScript := preload("res://scripts/quests/quest_state.gd")
const FirstScavengerHuntQuest := preload("res://data/quests/first_scavenger_hunt.tres")

const BASE_3D_SCENE := "res://scenes/base/base_3d.tscn"
const GAMEPLAY_SCENE := "res://scenes/gameplay/player_test_world_3d.tscn"
const BASE_SCREEN_SCENE := "res://scenes/base/base_screen.tscn"
const PISTOL_PATH := "res://data/items/weapons/pistol_9mm.tres"
const AMMO_PATH := "res://data/items/ammo/ammo_9mm.tres"
const KILL_QUEST_ID := "first_scavenger_hunt"
const VALIDATION_SAVE_ROOT := "user://validation_player_visible_0_2_slice"

var _errors: Array[String] = []
var _save_manager: Node = null
var _created_save_manager := false
var _attack_count := 0
var _hit_count := 0


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	_setup_save_manager()
	_validate_source_boundaries()
	await _validate_full_player_visible_0_2_smoke()
	_cleanup_validation_root(VALIDATION_SAVE_ROOT)
	if _created_save_manager:
		_free_node(_save_manager)

	if _errors.is_empty():
		print("[player_visible_0_2_slice] OK base=3d raid_gate=direct_start raid=enemy_chase_attack loot=equip_reload projectile_hit=enemy_dead quest=result=base")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_source_boundaries() -> void:
	for path in PackedStringArray([
		"res://scripts/ui/difficulty_select_panel.gd",
		"res://scripts/save/save_game_manager.gd",
		"res://scripts/base/base_interaction_controller_3d.gd",
		"res://scripts/ui/raid_result_panel.gd",
	]):
		var source := _read_text(path)
		if source.contains(BASE_SCREEN_SCENE):
			_errors.append("Normal player flow should not route to the old 2D BaseScreen: %s" % path)

	var required_validators := PackedStringArray([
		"res://tools/validate_enemy_visible_in_raid.gd",
		"res://tools/validate_enemy_chase_player.gd",
		"res://tools/validate_enemy_attack_player.gd",
		"res://tools/validate_projectile_hit_enemy.gd",
		"res://tools/validate_pistol_fire_vfx.gd",
		"res://tools/validate_quest_kill_enemy_flow.gd",
		"res://tools/validate_enemy_player_death_result.gd",
		"res://tools/validate_ui_layout_quality_0_2.gd",
	])
	for validator_path in required_validators:
		if not FileAccess.file_exists(validator_path):
			_errors.append("Dev Slice 0.2 standard validator is missing: %s" % validator_path)

	var save_source := _read_text("res://scripts/save/save_game_manager.gd")
	if not save_source.contains("const DEFAULT_BASE_SCENE := \"%s\"" % BASE_3D_SCENE):
		_errors.append("SaveGameManager default base scene should be the 3D Base.")
	var difficulty_source := _read_text("res://scripts/ui/difficulty_select_panel.gd")
	if not difficulty_source.contains("const BASE_SCENE := \"%s\"" % BASE_3D_SCENE):
		_errors.append("New game difficulty flow should enter the 3D Base.")
	var result_source := _read_text("res://scripts/ui/raid_result_panel.gd")
	if not result_source.contains("const BASE_SCENE := \"%s\"" % BASE_3D_SCENE):
		_errors.append("Raid result continue flow should enter the 3D Base.")

	var gameplay_scene := _read_text("res://scenes/gameplay/player_test_world_3d.tscn")
	for required in PackedStringArray(["ScavengerPatrol01", "ContainerInventoryUI", "PlayerHud3D", "QuestTopMenuPanel", "RaidResultPanel"]):
		if not gameplay_scene.contains(required):
			_errors.append("Gameplay scene should keep visible Dev Slice 0.2 node `%s`." % required)
	for forbidden in PackedStringArray([PISTOL_PATH, AMMO_PATH, "weapon_def ="]):
		if gameplay_scene.contains(forbidden):
			_errors.append("Raid scene should not hardwire loadout shortcut `%s`." % forbidden)


func _validate_full_player_visible_0_2_smoke() -> void:
	var base_scene := Base3DScene.instantiate()
	root.add_child(base_scene)
	current_scene = base_scene
	await _wait_frames(3)

	var gameplay := await _open_base_raid_gate(base_scene)
	if gameplay == null:
		_free_current_scene()
		return

	await _validate_raid_runtime_ui(gameplay)
	await _validate_enemy_chase_and_attack(gameplay)
	await _validate_loot_equip_reload_projectile_kill(gameplay)
	await _validate_extraction_result_return(gameplay)
	_free_current_scene()


func _open_base_raid_gate(base_scene: Node) -> Node:
	if base_scene.scene_file_path != BASE_3D_SCENE:
		_errors.append("Smoke should start in the 3D Base scene.")
	var base_player := base_scene.find_child("Player3D", true, false)
	var controller := base_scene.get_node_or_null("BaseInteractionController3D")
	if base_player == null or controller == null:
		_errors.append("3D Base should include Player3D and BaseInteractionController3D.")
		return null
	if _player_has_catalog(base_player, 5) or _player_has_catalog(base_player, 7):
		_errors.append("3D Base player should not already hold No.5 or No.7 before the raid.")
	if not bool(controller.call("open_interaction_by_id", "raid_gate")):
		_errors.append("Raid gate should directly start the raid.")
		return null
	await _wait_frames(16)
	if current_scene == null:
		_errors.append("Starting raid from the gate should leave a loaded gameplay scene.")
		return null
	if current_scene.scene_file_path != GAMEPLAY_SCENE:
		_errors.append("Starting raid from the gate should load gameplay, got `%s`." % current_scene.scene_file_path)
		return null
	return current_scene


func _validate_raid_runtime_ui(gameplay: Node) -> void:
	var ui_manager := root.get_node_or_null("UIManager")
	var player := gameplay.get_node_or_null("Player3D")
	var player_hud := gameplay.get_node_or_null("HUD/PlayerHud3D")
	var top_menu := gameplay.get_node_or_null("HUD/TopMenuBar")
	var inventory_ui := gameplay.get_node_or_null("HUD/InventoryEquipmentUI")
	var container_ui := gameplay.get_node_or_null("HUD/ContainerInventoryUI")
	var quest_panel := gameplay.get_node_or_null("HUD/QuestTopMenuPanel")
	var status_panel := gameplay.get_node_or_null("HUD/StatusTopMenuPanel")
	var map_panel := gameplay.get_node_or_null("HUD/MapTopMenuPanel")
	var pause_menu := gameplay.get_node_or_null("HUD/PauseMenu")
	var raid_hud := gameplay.get_node_or_null("HUD/RaidHudPanel")
	var result_panel := gameplay.get_node_or_null("HUD/RaidResultPanel")
	if ui_manager == null or player == null or player_hud == null or top_menu == null or inventory_ui == null or container_ui == null or quest_panel == null or status_panel == null or map_panel == null or pause_menu == null or raid_hud == null or result_panel == null:
		_errors.append("Raid should include UIManager, player, HUD, top-menu panels, inventory, container UI, pause menu, hidden legacy HUD, and result panel.")
		return
	if bool(raid_hud.get("visible")):
		_errors.append("Legacy top-left RaidHudPanel should stay hidden in the player-visible 0.2 flow.")
	var hud_state: Dictionary = player_hud.call("get_display_state")
	if not bool(hud_state.get("crosshair_visible", false)):
		_errors.append("PlayerHud3D should keep the mouse crosshair visible.")

	_press_key_on_ui_manager(ui_manager, KEY_TAB)
	await _wait_frames(3)
	if str(ui_manager.call("get_active_ui")) != "backpack":
		_errors.append("TAB should open backpack through UIManager during Raid.")
	if not bool(inventory_ui.get("visible")):
		_errors.append("TAB should make InventoryEquipmentUI visible during Raid.")
	_press_key_on_ui_manager(ui_manager, KEY_ESCAPE)
	await _wait_frames(2)
	_press_key_on_ui_manager(ui_manager, KEY_ESCAPE)
	await _wait_frames(2)
	if str(ui_manager.call("get_active_ui")) != "pause" or not bool(pause_menu.get("visible")):
		_errors.append("ESC should open PauseMenu after closing active Raid UI.")
	paused = false
	if ui_manager.has_method("close_ui"):
		ui_manager.call("close_ui")
	await _wait_frames(2)


func _validate_enemy_chase_and_attack(gameplay: Node) -> void:
	var player := gameplay.get_node_or_null("Player3D")
	var enemy := gameplay.get_node_or_null("SceneProps/ScavengerPatrol01")
	var hud := gameplay.get_node_or_null("HUD/PlayerHud3D")
	if player == null or enemy == null or hud == null:
		_errors.append("Raid should include Player3D, ScavengerPatrol01, and PlayerHud3D.")
		return
	var controller := enemy.get_node_or_null("EnemyController3D")
	var status_label := enemy.get_node_or_null("EnemyStatusDisplay3D/StatusLabel") as Label3D
	if controller == null:
		_errors.append("ScavengerPatrol01 should include EnemyController3D.")
		return
	if not controller.has_signal("attacked"):
		_errors.append("EnemyController3D should expose attacked signal.")
		return
	controller.attacked.connect(_on_enemy_attacked)
	controller.attack_cooldown = 0.85
	player.global_position = Vector3.ZERO
	enemy.global_position = Vector3(0.0, 0.0, 4.0)
	enemy.velocity = Vector3.ZERO
	var start_distance: float = enemy.global_position.distance_to(player.global_position)
	await _wait_physics_frames(18)
	var chase_state: Dictionary = controller.call("get_state")
	var chased: bool = str(chase_state.get("state", "")) == "chase" or enemy.global_position.distance_to(player.global_position) < start_distance - 0.1
	if not chased:
		_errors.append("Visible Scavenger should detect and chase the Raid player.")
	if status_label == null or not status_label.visible or status_label.text.strip_edges() == "":
		_errors.append("Visible Scavenger should show an in-world status label while active.")

	var health_before := float(player.get("health"))
	enemy.global_position = player.global_position + Vector3(0.0, 0.0, 0.85)
	enemy.velocity = Vector3.ZERO
	for _index in range(42):
		await physics_frame
	var health_after := float(player.get("health"))
	var hud_state: Dictionary = hud.call("get_display_state")
	if _attack_count <= 0:
		_errors.append("Visible Scavenger should attack the player when close.")
	if health_after >= health_before:
		_errors.append("Enemy attack should reduce the real Raid player health.")
	if not str(hud_state.get("health_text", "")).contains(str(roundi(health_after))):
		_errors.append("PlayerHud3D should show damaged health after enemy attack.")
	if not bool(hud_state.get("damage_feedback_visible", true)):
		_errors.append("PlayerHud3D should expose visible damage feedback after enemy attack.")
	controller.set_physics_process(false)
	if controller.has_method("_cancel_windup"):
		controller.call("_cancel_windup")


func _validate_loot_equip_reload_projectile_kill(gameplay: Node) -> void:
	var player := gameplay.get_node_or_null("Player3D")
	var enemy := gameplay.get_node_or_null("SceneProps/ScavengerPatrol01")
	var container := _first_loot_container(gameplay)
	var container_ui := gameplay.get_node_or_null("HUD/ContainerInventoryUI") as Control
	var player_hud := gameplay.get_node_or_null("HUD/PlayerHud3D") as Control
	if player == null or enemy == null or container == null or container_ui == null or player_hud == null:
		_errors.append("Loot/equip/combat smoke requires player, enemy, loot container, container UI, and player HUD.")
		return
	var weapon := player.get_node_or_null("WeaponController3D")
	var controller := enemy.get_node_or_null("EnemyController3D")
	if weapon == null or controller == null:
		_errors.append("Loot/equip/combat smoke requires WeaponController3D and EnemyController3D.")
		return
	weapon.hit.connect(_on_weapon_hit)

	var inventory = player.call("get_inventory_model")
	var equipment = player.call("get_equipment_model")
	if _stack_array_has(inventory.get_display_items(), 5) or _stack_array_has(inventory.get_display_items(), 7) or _equipment_has_catalog(equipment, 5):
		_errors.append("Raid player should not spawn with No.5 pistol or No.7 ammo before looting.")
	await _open_container_and_transfer_loot(player, container, container_ui, inventory)
	await _equip_pistol_and_reload(player, inventory, equipment, weapon, player_hud)
	await _kill_enemy_with_visible_projectiles(gameplay, player, enemy, controller, weapon)
	_validate_kill_quest_saved()


func _open_container_and_transfer_loot(player: Node, container: LootContainer3D, container_ui: Control, inventory: InventoryModel) -> void:
	if not container.try_open(player):
		_errors.append("Loot container should open through normal player interaction.")
		return
	await _wait_frames(3)
	var state: Dictionary = container_ui.call("get_display_state")
	if not bool(state.get("visible", false)):
		_errors.append("Container UI should be visible after opening.")
	if int(state.get("slot_count", 0)) <= 0 or not str(state.get("capacity", "")).contains("/"):
		_errors.append("Container UI should show capacity slots and used/capacity text.")
	var model = container.call("get_container_inventory_model")
	var pistol_slot := _slot_index_with_path(model, PISTOL_PATH)
	var ammo_slot := _slot_index_with_path(model, AMMO_PATH)
	if pistol_slot < 0 or ammo_slot < 0:
		_errors.append("Normal raid container should visibly contain No.5 pistol and No.7 ammo.")
		return
	await _press_container_slot(container_ui, pistol_slot)
	await _press_container_slot(container_ui, ammo_slot)
	if not _stack_array_has(inventory.get_display_items(), 5):
		_errors.append("Clicking No.5 in container UI should move pistol into backpack.")
	if not _stack_array_has(inventory.get_display_items(), 7):
		_errors.append("Clicking No.7 in container UI should move ammo into backpack.")


func _equip_pistol_and_reload(player: Node, inventory: InventoryModel, equipment: RefCounted, weapon: Node, player_hud: Control) -> void:
	var pistol_index := _stack_index_with_catalog(inventory, 5)
	if pistol_index < 0:
		_errors.append("No.5 pistol should be in backpack before equipment.")
		return
	if not bool(player.call("equip_inventory_stack", pistol_index, &"primary_weapon")):
		_errors.append("Player should equip No.5 pistol into the primary weapon slot.")
		return
	await _wait_frames(2)
	var primary_weapon: Dictionary = equipment.call("get_slot", &"primary_weapon")
	if int(primary_weapon.get("catalog_number", 0)) != 5:
		_errors.append("EquipmentModel primary_weapon should show No.5 pistol.")
	if not bool(weapon.call("has_weapon")):
		_errors.append("WeaponController3D should bind to equipped No.5 pistol.")

	var ammo_before := _quantity_by_path(inventory.get_display_items(), AMMO_PATH)
	if ammo_before <= 0:
		_errors.append("No.7 ammo should be in backpack before reload.")
		return
	player.set("reload_duration_seconds", 0.05)
	if not bool(player.call("reload_equipped_weapon", &"validation_smoke")):
		_errors.append("Reload should start when No.5 pistol and No.7 ammo are available.")
		return
	await _wait_frames(2)
	var reload_state: Dictionary = player.call("get_reload_state")
	var hud_state: Dictionary = player_hud.call("get_display_state")
	if not bool(reload_state.get("active", false)) or not bool(hud_state.get("reload_visible", false)):
		_errors.append("Reload should show an active player-visible progress bar.")
	for _frame in range(30):
		await physics_frame
		if not bool((player.call("get_reload_state") as Dictionary).get("active", false)):
			break
	await _wait_frames(2)
	if int(weapon.get("current_ammo")) <= 0:
		_errors.append("Reload should place rounds into the equipped No.5 pistol.")
	var ammo_after := _quantity_by_path(inventory.get_display_items(), AMMO_PATH)
	if ammo_after >= ammo_before:
		_errors.append("Reload should consume compatible No.7 backpack ammo.")
	var loaded_hud: Dictionary = player_hud.call("get_display_state")
	if not str(loaded_hud.get("ammo_text", "")).contains("發子彈"):
		_errors.append("Player HUD ammo text should show loaded bullets and backpack reserve count.")


func _kill_enemy_with_visible_projectiles(gameplay: Node, player: Node, enemy: Node, controller: Node, weapon: Node) -> void:
	player.global_position = Vector3.ZERO
	enemy.global_position = Vector3(0.0, 0.0, 2.4)
	enemy.velocity = Vector3.ZERO
	controller.set_physics_process(false)
	if controller.has_method("_cancel_windup"):
		controller.call("_cancel_windup")
	weapon.set("fire_cooldown_seconds", 0.0)
	await _wait_frames(2)

	var shot_feedback_before := _count_by_script(gameplay, ShotFeedbackScript)
	var projectile_seen := false
	var impact_seen := false
	for _shot in range(2):
		if weapon.has_method("force_cooldown_ready"):
			weapon.call("force_cooldown_ready")
		var origin: Vector3 = player.global_position + Vector3(0.0, 0.72, 0.9)
		var direction: Vector3 = (enemy.global_position + Vector3(0.0, 0.72, 0.0) - origin).normalized()
		var projectile_before := _count_by_script(gameplay, ProjectileScript)
		if not bool(weapon.call("fire_forward", origin, direction, player.get_world_3d().direct_space_state)):
			_errors.append("Equipped and loaded No.5 pistol should fire toward the enemy.")
		await process_frame
		if _count_by_script(gameplay, ProjectileScript) > projectile_before:
			projectile_seen = true
		for _frame in range(35):
			await physics_frame
			await process_frame
			if _count_by_script(gameplay, HitFeedbackScript) > 0:
				impact_seen = true
			if enemy.has_method("is_alive") and not bool(enemy.call("is_alive")):
				break

	if _count_by_script(gameplay, ShotFeedbackScript) <= shot_feedback_before:
		_errors.append("Firing should show muzzle spark/tracer feedback.")
	if not projectile_seen:
		_errors.append("Firing should spawn a visible 3D projectile trajectory.")
	if not impact_seen:
		_errors.append("Projectile hit should spawn visible impact feedback.")
	if _hit_count < 2:
		_errors.append("WeaponController3D should emit hit events when bullets damage the enemy.")
	if enemy.has_method("is_alive") and bool(enemy.call("is_alive")):
		_errors.append("Two No.5 projectile hits should kill the visible Scavenger.")
	if str(controller.state) != "dead":
		_errors.append("EnemyController3D should enter dead state after projectile kill.")


func _validate_kill_quest_saved() -> void:
	var save_data: Dictionary = _save_manager.call("get_slot_data", 1)
	var quests: Dictionary = save_data.get("quests", {}) as Dictionary
	var quest_state: Dictionary = quests.get(KILL_QUEST_ID, {}) as Dictionary
	var progress: Dictionary = quest_state.get("progress", {}) as Dictionary
	if int(progress.get("kill:scavenger", 0)) < 1:
		_errors.append("Killing the visible Scavenger should persist kill quest progress.")
	if str(quest_state.get("state", "")) not in ["ready", "completed"]:
		_errors.append("Killing the visible Scavenger should make the kill quest ready or completed.")


func _validate_extraction_result_return(gameplay: Node) -> void:
	var player := gameplay.get_node_or_null("Player3D")
	var session := gameplay.get_node_or_null("RaidSession")
	var result_panel := gameplay.get_node_or_null("HUD/RaidResultPanel")
	var applier := gameplay.get_node_or_null("RaidResultApplier")
	if player == null or session == null or result_panel == null or applier == null:
		_errors.append("Extraction smoke requires player, RaidSession, RaidResultPanel, and RaidResultApplier.")
		return
	var inventory: InventoryModel = player.call("get_inventory_model")
	if not bool(session.call("register_extraction", {
		"extracted_items": inventory.get_display_items(),
		"money_delta": 0,
	})):
		_errors.append("RaidSession should allow extraction after the combat smoke.")
		return
	await _wait_frames(3)
	if not bool(result_panel.get("visible")):
		_errors.append("RaidResultPanel should be visible after extraction.")
	var apply_result: Dictionary = applier.get("last_apply_result")
	if not bool(apply_result.get("applied", false)):
		_errors.append("RaidResultApplier should persist the extraction result.")
	result_panel.continue_button.pressed.emit()
	await _wait_frames(10)
	if current_scene == null:
		_errors.append("Continuing from result should leave a loaded current scene.")
	elif current_scene.scene_file_path != BASE_3D_SCENE:
		_errors.append("Continuing from result should return to 3D Base, got `%s`." % current_scene.scene_file_path)


func _setup_save_manager() -> void:
	_save_manager = root.get_node_or_null("SaveGameManager")
	if _save_manager == null:
		_save_manager = SaveGameManagerScript.new()
		_save_manager.name = "SaveGameManager"
		root.add_child(_save_manager)
		_created_save_manager = true
	_save_manager.save_root_path = VALIDATION_SAVE_ROOT
	_cleanup_validation_root(VALIDATION_SAVE_ROOT)
	_save_manager.call("set_current_slot_index", 1)
	_save_manager.call("save_slot_data", 1, {
		"difficulty_id": "normal",
		"scene_path": BASE_3D_SCENE,
		"money": 0,
		"stash": [],
		"base_upgrades": {},
		"quests": {
			KILL_QUEST_ID: QuestStateScript.accept(FirstScavengerHuntQuest),
		},
	})


func _press_container_slot(container_ui: Control, slot_index: int) -> void:
	var button := container_ui.find_child("ContainerSlot%d" % slot_index, true, false) as Button
	if button == null:
		_errors.append("Container UI should expose clickable slot button %d." % slot_index)
		return
	button.pressed.emit()
	await _wait_frames(2)


func _press_key_on_ui_manager(ui_manager: Node, keycode: Key) -> void:
	if ui_manager == null:
		return
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	ui_manager.call("_input", event)


func _first_loot_container(scene: Node) -> LootContainer3D:
	for node in scene.find_children("*", "Area3D", true, false):
		if node.get_script() == LootContainerScript:
			return node as LootContainer3D
	return null


func _slot_index_with_path(model: RefCounted, item_path: String) -> int:
	if model == null or not model.has_method("get_slots"):
		return -1
	var slots: Array = model.call("get_slots")
	for index in range(slots.size()):
		var stack: Variant = slots[index]
		if typeof(stack) == TYPE_DICTIONARY and str((stack as Dictionary).get("resource_path", "")) == item_path:
			return index
	return -1


func _stack_index_with_catalog(inventory: InventoryModel, catalog_number: int) -> int:
	if inventory == null:
		return -1
	var stacks := inventory.get_display_items()
	for index in range(stacks.size()):
		var stack := stacks[index]
		if int(stack.get("catalog_number", 0)) == catalog_number:
			return index
	return -1


func _stack_array_has(value: Variant, catalog_number: int) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	for stack_value in value as Array:
		if typeof(stack_value) != TYPE_DICTIONARY:
			continue
		var stack := stack_value as Dictionary
		if int(stack.get("catalog_number", 0)) == catalog_number:
			return true
		var item_path := str(stack.get("resource_path", stack.get("item_path", "")))
		var item := load(item_path) as ItemDef if item_path != "" and ResourceLoader.exists(item_path) else null
		if item != null and item.catalog_number == catalog_number:
			return true
	return false


func _equipment_has_catalog(equipment: RefCounted, catalog_number: int) -> bool:
	if equipment == null or not equipment.has_method("get_slot_ids"):
		return false
	var slot_ids: Array[StringName] = equipment.call("get_slot_ids")
	for slot_name in slot_ids:
		var item: Variant = equipment.call("get_equipped_item", StringName(slot_name))
		if item is ItemDef and int(item.catalog_number) == catalog_number:
			return true
	return false


func _player_has_catalog(player: Node, catalog_number: int) -> bool:
	if player == null or not player.has_method("get_inventory_model") or not player.has_method("get_equipment_model"):
		return false
	var inventory: InventoryModel = player.call("get_inventory_model")
	var equipment: RefCounted = player.call("get_equipment_model")
	return _stack_array_has(inventory.get_display_items(), catalog_number) or _equipment_has_catalog(equipment, catalog_number)


func _quantity_by_path(value: Variant, item_path: String) -> int:
	if typeof(value) != TYPE_ARRAY:
		return 0
	var total := 0
	for stack_value in value as Array:
		if typeof(stack_value) != TYPE_DICTIONARY:
			continue
		var stack := stack_value as Dictionary
		if str(stack.get("resource_path", stack.get("item_path", ""))) == item_path:
			total += int(stack.get("quantity", 0))
	return total


func _count_by_script(parent: Node, script: Script) -> int:
	var count := 0
	for child in parent.get_children():
		if child.get_script() == script:
			count += 1
		count += _count_by_script(child, script)
	return count


func _on_enemy_attacked(_target: Node, _damage: float) -> void:
	_attack_count += 1


func _on_weapon_hit(_target: Node, _event: DamageEvent) -> void:
	_hit_count += 1


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		_errors.append("Missing expected file: %s" % path)
		return ""
	return FileAccess.get_file_as_string(path)


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


func _wait_physics_frames(count: int) -> void:
	for _index in range(count):
		await physics_frame


func _free_current_scene() -> void:
	if current_scene != null:
		_free_node(current_scene)
		current_scene = null


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
