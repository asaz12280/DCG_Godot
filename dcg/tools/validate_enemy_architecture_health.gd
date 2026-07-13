extends SceneTree

const RaidScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const EnemyControllerScript := preload("res://scripts/ai/enemy_controller_3d.gd")
const EnemyDamageableScript := preload("res://scripts/ai/enemy_damageable_3d.gd")
const EnemyStatusDisplayScript := preload("res://scripts/ai/enemy_status_display_3d.gd")
const EnemyLootDropScript := preload("res://scripts/ai/enemy_loot_drop_3d.gd")
const QuestKillTrackerScript := preload("res://scripts/quests/quest_kill_tracker_3d.gd")
const NavigationManagerScript := preload("res://scripts/gameplay/navigation_manager_3d.gd")
const RaidSessionScript := preload("res://scripts/raid/raid_session.gd")
const RaidResultApplierScript := preload("res://scripts/raid/raid_result_applier.gd")
const QuestTopMenuPanelScript := preload("res://scripts/ui/quest_top_menu_panel.gd")
const RaidResultPanelScript := preload("res://scripts/ui/raid_result_panel.gd")

var _errors: Array[String] = []


func _initialize() -> void:
	await _validate_raid_enemy_boundaries()
	_validate_source_boundaries()
	_validate_dev_slice_0_2_validator_coverage()
	if _errors.is_empty():
		print("[enemy_architecture_health] OK raid=reachable enemy_boundaries=clean ui_coupling=clean validation=covered slice_0_2=covered")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_raid_enemy_boundaries() -> void:
	var raid := RaidScene.instantiate()
	root.add_child(raid)
	await process_frame

	var player := raid.get_node_or_null("Player3D")
	if player == null or not player.is_in_group("player"):
		_errors.append("Normal Raid should expose Player3D in the player group for enemy targeting.")

	var enemy := _first_raid_enemy(raid)
	if enemy == null:
		_errors.append("Normal Raid should include a reachable enemy instance.")
		_free_node(raid)
		return

	if enemy.get_script() != EnemyDamageableScript:
		_errors.append("Enemy root should own damage/death through EnemyDamageable3D.")

	var controller := enemy.get_node_or_null("EnemyController3D")
	if controller == null or controller.get_script() != EnemyControllerScript:
		_errors.append("Enemy chase/attack should be owned by EnemyController3D.")

	if enemy.get_node_or_null("NavigationAgent3D") == null:
		_errors.append("Enemy pathfinding should use a NavigationAgent3D child.")

	var loot_drop := enemy.get_node_or_null("EnemyLootDrop3D")
	if loot_drop == null or loot_drop.get_script() != EnemyLootDropScript:
		_errors.append("Enemy death loot should be owned by EnemyLootDrop3D.")

	var quest_tracker := enemy.get_node_or_null("QuestKillTracker3D")
	if quest_tracker == null or quest_tracker.get_script() != QuestKillTrackerScript:
		_errors.append("Enemy kill quest progress should be owned by QuestKillTracker3D.")

	var status_display := enemy.get_node_or_null("EnemyStatusDisplay3D")
	if status_display == null or status_display.get_script() != EnemyStatusDisplayScript:
		_errors.append("Enemy in-world state label should be owned by EnemyStatusDisplay3D.")

	if enemy.get_node_or_null("NameLabel") == null:
		_errors.append("Enemy should keep a 3D name label for player readability.")
	if enemy.get_node_or_null("EnemyStatusDisplay3D/HealthBarBack") != null:
		_errors.append("Enemy should remove legacy 3D health bar back because PlayerHud3D owns the visible player-style bar.")
	if enemy.get_node_or_null("EnemyStatusDisplay3D/HealthBarFill") != null:
		_errors.append("Enemy should remove legacy 3D health bar fill because PlayerHud3D owns the visible player-style bar.")
	var player_hud := raid.get_node_or_null("HUD/PlayerHud3D")
	if player_hud == null:
		_errors.append("Normal Raid should include PlayerHud3D for projected enemy health bars.")
	else:
		var hud_state: Dictionary = player_hud.call("get_display_state")
		if int(hud_state.get("enemy_health_bar_count", 0)) <= 0:
			_errors.append("PlayerHud3D should expose visible enemy health bar state in normal Raid.")

	if raid.get_node_or_null("RaidNavigationRegion3D") == null:
		_errors.append("Normal Raid should include a NavigationRegion3D for obstacle-aware enemy chase.")
	var navigation_manager := raid.get_node_or_null("NavigationManager3D")
	if navigation_manager == null or navigation_manager.get_script() != NavigationManagerScript:
		_errors.append("Normal Raid should rebuild navigation through NavigationManager3D.")

	var distance := (enemy as Node3D).global_position.distance_to((player as Node3D).global_position) if player is Node3D else INF
	if distance > 12.0:
		_errors.append("Normal Raid enemy should remain close enough to the player route for the first encounter.")

	var raid_session := raid.get_node_or_null("RaidSession")
	if raid_session == null or raid_session.get_script() != RaidSessionScript:
		_errors.append("Raid death/extraction outcome should be owned by RaidSession.")

	var result_applier := raid.get_node_or_null("RaidResultApplier")
	if result_applier == null or result_applier.get_script() != RaidResultApplierScript:
		_errors.append("Raid result persistence and player inventory cleanup should be owned by RaidResultApplier.")

	var quest_panel := raid.get_node_or_null("HUD/QuestTopMenuPanel")
	if quest_panel == null or quest_panel.get_script() != QuestTopMenuPanelScript:
		_errors.append("Quest display should remain in the HUD QuestTopMenuPanel.")

	var result_panel := raid.get_node_or_null("HUD/RaidResultPanel")
	if result_panel == null or result_panel.get_script() != RaidResultPanelScript:
		_errors.append("Raid result display should remain in the HUD RaidResultPanel.")

	_free_node(raid)


func _validate_source_boundaries() -> void:
	_assert_source_excludes(
		"res://scripts/ai/enemy_controller_3d.gd",
		["InventoryEquipmentUI", "ContainerInventoryUI", "RaidResultPanel", "QuestState", "SaveGameManager", "BaseInteractionController3D"]
	)
	_assert_source_excludes(
		"res://scripts/ai/enemy_damageable_3d.gd",
		["InventoryEquipmentUI", "ContainerInventoryUI", "RaidResultPanel", "QuestState", "SaveGameManager", "UIManager"]
	)
	_assert_source_excludes(
		"res://scripts/ai/enemy_status_display_3d.gd",
		["InventoryEquipmentUI", "ContainerInventoryUI", "RaidResultPanel", "QuestState", "SaveGameManager", "UIManager"]
	)
	_assert_source_excludes(
		"res://scripts/ai/enemy_loot_drop_3d.gd",
		["InventoryModel", "StashModel", "SaveGameManager", "QuestState", "RaidResultPanel", "QuestTopMenuPanel", "UIManager"]
	)
	_assert_source_excludes(
		"res://scripts/quests/quest_kill_tracker_3d.gd",
		["QuestTopMenuPanel", "RaidResultPanel", "RaidResultApplier", "EnemyLootDrop3D", "InventoryModel", "StashModel"]
	)
	_assert_source_excludes(
		"res://scripts/raid/raid_loss_rules.gd",
		["QuestTopMenuPanel", "RaidResultPanel", "EnemyController3D", "EnemyDamageable3D", "EnemyLootDrop3D", "QuestState", "SaveGameManager", "StashModel"]
	)
	_assert_source_excludes(
		"res://scripts/raid/raid_result_applier.gd",
		["EnemyController3D", "EnemyDamageable3D", "EnemyLootDrop3D", "QuestKillTracker3D", "QuestTopMenuPanel", "RaidResultPanel", "InventoryEquipmentUI", "ContainerInventoryUI"]
	)
	_assert_source_excludes(
		"res://scripts/ui/quest_top_menu_panel.gd",
		["save_slot_data", "update_from_enemy_killed", "EnemyController3D", "EnemyDamageable3D", "EnemyLootDrop3D", "RaidResultApplier", "register_player_death", "register_extraction", "apply_damage"]
	)
	_assert_source_excludes(
		"res://scripts/ui/raid_result_panel.gd",
		["save_slot_data", "get_inventory_model", "StashModel", "QuestState", "EnemyController3D", "EnemyDamageable3D", "EnemyLootDrop3D", "QuestKillTracker3D"]
	)
	_assert_source_includes(
		"res://scripts/player/player_controller_3d.gd",
		["RaidLossRulesScript", "build_death_context_from_player", "register_player_death"],
		"Player death should route through RaidLossRules and RaidSession."
	)
	_assert_source_excludes(
		"res://scripts/player/player_controller_3d.gd",
		["RaidResultPanel"]
	)
	_assert_source_includes(
		"res://scripts/raid/raid_session.gd",
		["register_player_death", "OUTCOME_DEAD", "raid_completed.emit"],
		"RaidSession should own dead outcome completion."
	)
	_assert_source_includes(
		"res://scripts/ai/enemy_loot_drop_3d.gd",
		["LootContainerScript", "drop_loot", "_spawn_corpse_container", "_on_enemy_died"],
		"Enemy loot should create a corpse container through the loot path."
	)
	_assert_source_includes(
		"res://scripts/quests/quest_kill_tracker_3d.gd",
		["update_from_enemy_killed", "save_slot_data", "_on_enemy_died"],
		"Enemy kill quest progress should be save-backed and event-driven."
	)
	_assert_source_includes(
		"res://scripts/ui/quest_top_menu_panel.gd",
		["refresh", "get_display_state", "slot_saved"],
		"Quest UI should display and refresh saved quest state."
	)
	_assert_source_includes(
		"res://scripts/ui/raid_result_panel.gd",
		["show_result", "lost_items", "kept_safe_pocket_items", "continue_to_base_requested"],
		"Raid result UI should display result data and continue to Base."
	)
	_assert_source_includes(
		"res://scripts/ui/player_hud_3d.gd",
		["PlayerHUDPainterScript", "enemy_health_bar_count", "player_health"],
		"PlayerHud3D should own the player-style enemy health state and delegate painting."
	)
	_assert_source_includes(
		"res://scripts/ui/player_hud_painter.gd",
		["_paint_enemy_health_bars"],
		"PlayerHUDPainter should own the player-style enemy health overlay drawing."
	)
	_assert_source_excludes(
		"res://scripts/raid/raid_result_applier.gd",
		["update_from_enemy_killed"]
	)

	for validator in [
		"res://tools/validate_enemy_visible_in_raid.gd",
		"res://tools/validate_enemy_damageable_3d.gd",
		"res://tools/validate_enemy_chase_player.gd",
		"res://tools/validate_navigation_manager_3d.gd",
		"res://tools/validate_enemy_loot_drop.gd",
		"res://tools/validate_quest_kill_enemy_flow.gd",
		"res://tools/validate_enemy_player_death_result.gd",
		"res://tools/validate_raid_loss_rules.gd",
		"res://tools/validate_raid_return_to_base_3d.gd",
		"res://tools/validate_player_visible_0_2_slice.gd",
		"res://tools/validate_ui_layout_quality_0_2.gd",
		"res://tools/validate_three_raid_loop_0_2.gd",
		"res://tools/validate_projectile_hit_enemy.gd",
	]:
		if not FileAccess.file_exists(validator):
			_errors.append("Enemy-first health requires validator: %s" % validator)


func _validate_dev_slice_0_2_validator_coverage() -> void:
	var smoke_text := FileAccess.get_file_as_string("res://tools/validate_player_visible_0_2_slice.gd")
	if smoke_text == "":
		_errors.append("Could not read Dev Slice 0.2 player-visible smoke validator.")
	else:
		for required in [
			"validate_enemy_chase_and_attack",
			"validate_loot_equip_reload_projectile_kill",
			"validate_extraction_result_return",
			"validate_kill_quest_saved",
			"crosshair_visible",
			"KEY_TAB",
			"KEY_ESCAPE",
			"ProjectileScript",
			"VALIDATION_SAVE_ROOT",
		]:
			if not smoke_text.contains(required):
				_errors.append("Player-visible 0.2 smoke validator should cover %s." % required)

	var ui_text := FileAccess.get_file_as_string("res://tools/validate_ui_layout_quality_0_2.gd")
	if ui_text == "":
		_errors.append("Could not read Dev Slice 0.2 UI layout validator.")
	else:
		for required in ["1280x720", "1920x1080", "text=zh", "boundaries=clean"]:
			if not ui_text.contains(required):
				_errors.append("UI layout 0.2 validator should report %s." % required)

	var loop_text := FileAccess.get_file_as_string("res://tools/validate_three_raid_loop_0_2.gd")
	if loop_text == "":
		_errors.append("Could not read Dev Slice 0.2 three-raid loop validator.")
	else:
		for required in [
			"Base3DScene",
			"BaseWorkbenchServiceScript",
			"GameplayScene",
			"ScavengerScene",
			"RaidResultApplierScript",
			"VALIDATION_SAVE_ROOT",
		]:
			if not loop_text.contains(required):
				_errors.append("Three-raid 0.2 validator should cover %s." % required)

	var queue_text := FileAccess.get_file_as_string("res://docs/tasks/dev_slice_0_2_enemy_first_task_queue.md")
	if queue_text == "":
		_errors.append("Could not read enemy-first task queue for Health Check G.")
	else:
		for required in [
			"### 任務二十八：Project Health Check G",
			"validate_player_visible_0_2_slice.gd",
			"validate_three_raid_loop_0_2.gd",
			"validate_enemy_architecture_health.gd",
			"validate_player_visibility_v2_health.gd",
		]:
			if not queue_text.contains(required):
				_errors.append("Enemy-first task queue should keep Health Check G term %s." % required)


func _assert_source_excludes(path: String, forbidden_tokens: Array[String]) -> void:
	var source := FileAccess.get_file_as_string(path)
	if source == "":
		_errors.append("Could not read source for boundary check: %s" % path)
		return
	for token in forbidden_tokens:
		if source.contains(token):
			_errors.append("%s should not depend on %s." % [path, token])


func _assert_source_includes(path: String, required_tokens: Array[String], message: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	if source == "":
		_errors.append("Could not read source for boundary check: %s" % path)
		return
	for token in required_tokens:
		if not source.contains(token):
			_errors.append("%s Missing token: %s in %s." % [message, token, path])


func _first_raid_enemy(raid: Node) -> Node3D:
	for enemy in get_nodes_in_group("enemy"):
		var enemy_node := enemy as Node3D
		if enemy_node == null or not _is_descendant_of(enemy_node, raid):
			continue
		return enemy_node
	return null


func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var current := node
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
