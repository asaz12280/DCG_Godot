extends SceneTree

const Base3DScene := preload("res://scenes/base/base_3d.tscn")
const QuestCatalogScript := preload("res://scripts/quests/quest_catalog.gd")
const BaseQuestBoardProfile := preload("res://data/quests/givers/base_quest_board.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	await _validate_profile_contract()
	await _validate_base_quest_board_binding()
	if _errors.is_empty():
		print("[quest_giver_profile_architecture] OK profile=scoped base_board=npc_entry top_menu=unscoped")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_profile_contract() -> void:
	var catalog_defs := QuestCatalogScript.quest_defs()
	if not bool(BaseQuestBoardProfile.call("is_valid", catalog_defs)):
		_errors.append("Base quest board QuestGiverProfile should validate against QuestCatalog.")
	var scoped_defs: Array = BaseQuestBoardProfile.call("quest_defs_for_catalog", catalog_defs)
	if scoped_defs.size() != 3:
		_errors.append("Base quest board should expose the current three starter quests.")
	for quest_id in ["first_salvage", "first_scavenger_hunt", "radio_tower_scout"]:
		if not bool(BaseQuestBoardProfile.call("allows_quest_id", quest_id, catalog_defs)):
			_errors.append("Base quest board should allow quest id: %s." % quest_id)


func _validate_base_quest_board_binding() -> void:
	var scene := Base3DScene.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	var quest_point := _find_point(scene, "quests")
	if quest_point == null:
		_errors.append("Base scene should include a quests interaction point.")
		_free_node(scene)
		return
	if str(quest_point.get_meta("quest_giver_profile", "")) != "res://data/quests/givers/base_quest_board.tres":
		_errors.append("QuestBoardPoint should bind the base quest board QuestGiverProfile.")
	var controller := scene.get_node_or_null("BaseInteractionController3D")
	if controller == null or not controller.has_method("open_interaction_by_id"):
		_errors.append("Base scene should include BaseInteractionController3D.")
		_free_node(scene)
		return
	if not bool(controller.call("open_interaction_by_id", "quests")):
		_errors.append("Opening the base quest board should succeed.")
		_free_node(scene)
		return
	await process_frame
	var quest_panel := scene.get_node_or_null("HUD/QuestTopMenuPanel")
	if quest_panel == null or not quest_panel.has_method("get_display_state"):
		_errors.append("Base quest board should open QuestTopMenuPanel.")
		_free_node(scene)
		return
	var state: Dictionary = quest_panel.call("get_display_state")
	if str(state.get("quest_giver_id", "")) != "base_quest_board":
		_errors.append("QuestTopMenuPanel should remember the NPC/station quest giver profile.")
	if int(state.get("quest_count", 0)) != 3:
		_errors.append("QuestTopMenuPanel should only list quests from the active quest giver profile.")
	var ui_manager := root.get_node_or_null("UIManager")
	if ui_manager != null and ui_manager.has_method("open_ui"):
		ui_manager.call("open_ui", &"quests")
		await process_frame
		state = quest_panel.call("get_display_state")
		if str(state.get("quest_giver_id", "")) != "":
			_errors.append("Opening the generic top-menu quest view should clear NPC quest giver scope.")
		if int(state.get("available_count", 0)) != 0:
			_errors.append("Generic top-menu quest view should not offer new quest acceptance without a quest giver.")
	_free_node(scene)


func _find_point(scene: Node, interaction_id: String) -> Node:
	for node in scene.get_tree().get_nodes_in_group("base_interaction_point"):
		if str(node.get_meta("interaction_id", "")) == interaction_id:
			return node
	return null


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
