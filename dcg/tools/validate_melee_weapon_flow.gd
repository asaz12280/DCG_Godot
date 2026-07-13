extends SceneTree

const PlayerScene := preload("res://scenes/player/player_3d.tscn")
const ScavengerScene := preload("res://scenes/enemies/scavenger_3d.tscn")
const PlayerHudScript := preload("res://scripts/ui/player_hud_3d.gd")
const CombatKnife := preload("res://data/items/weapons/combat_knife.tres")
const PistolS := preload("res://data/items/weapons/pistol_S.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_combat_knife_balance_data()
	await _validate_v_toggles_melee_and_left_click_slashes()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[melee_weapon_flow] OK equip=activates_melee toggle=V left_click=damage vfx=white_body_glow_core+knife_local_fire_start enemy_hit=anticipation_fire3_white_ring_1_5x_at_resolved_position hold=repeat balance=knife_profile boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_combat_knife_balance_data() -> void:
	if CombatKnife.get_weapon_damage() != 20:
		_errors.append("Combat Knife should use Duckov-relative early knife damage 20.")
	if absf(CombatKnife.get_weapon_fire_rate_per_second() - 1.9) > 0.001:
		_errors.append("Combat Knife should use repeatable melee attack speed 1.9.")
	if absf(CombatKnife.get_weapon_projectile_range() - 145.0) > 0.001:
		_errors.append("Combat Knife should keep authored melee range 145 for a 1.45m slash.")
	var stack := CombatKnife.to_stack(1)
	if int(stack.get("damage", 0)) != 20 or absf(float(stack.get("fire_rate_per_second", 0.0)) - 1.9) > 0.001:
		_errors.append("Combat Knife stack should expose balanced melee damage and attack speed.")


func _validate_v_toggles_melee_and_left_click_slashes() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var player := PlayerScene.instantiate()
	scene.add_child(player)
	var enemy := ScavengerScene.instantiate()
	scene.add_child(enemy)
	var hud := PlayerHudScript.new() as Control
	hud.size = Vector2(1280.0, 720.0)
	scene.add_child(hud)
	await process_frame
	await physics_frame

	player.global_position = Vector3.ZERO
	player.look_at(Vector3(0.0, 0.0, -3.0), Vector3.UP)
	enemy.global_position = Vector3(0.0, 0.0, -1.05)
	enemy.set("max_health", 200.0)
	enemy.set("current_health", 200.0)
	if not bool(player.call("add_item_resource", PistolS, 1)):
		_errors.append("Player should be able to add Pistol-S to backpack for firearm validation.")
		_free_node(scene)
		return
	if not bool(player.call("equip_inventory_stack", 0, &"primary_weapon")):
		_errors.append("Player should be able to equip Pistol-S as primary weapon before melee validation.")
		_free_node(scene)
		return
	if not bool(player.call("add_item_resource", CombatKnife, 1)):
		_errors.append("Player should be able to add Combat Knife to backpack for melee validation.")
		_free_node(scene)
		return
	var pistol_visual := player.get_node_or_null("WeaponVisualRoot/PistolVisual") as Node3D
	var knife_visual := player.get_node_or_null("WeaponVisualRoot/KnifeVisual") as Node3D
	if pistol_visual == null or knife_visual == null:
		_errors.append("Player scene should provide simple pistol and combat knife visual nodes.")
	elif not pistol_visual.visible or knife_visual.visible:
		_errors.append("Player should show pistol visual, not knife visual, before equipping the melee slot.")
	if not bool(player.call("equip_inventory_stack", 0, &"melee")):
		_errors.append("Equipping Combat Knife from inventory should succeed.")
		_free_node(scene)
		return
	await process_frame
	if not bool(player.call("is_melee_mode_active")):
		_errors.append("Equipping a melee-slot weapon should immediately enter melee mode.")
	if pistol_visual != null and knife_visual != null and (pistol_visual.visible or not knife_visual.visible):
		_errors.append("Equipping Combat Knife should show the knife visual and hide the pistol visual.")
	var equipment: RefCounted = player.call("get_equipment_model")
	var melee_stack: Dictionary = equipment.call("get_slot", &"melee")
	if int(melee_stack.get("catalog_number", 0)) != 6:
		_errors.append("Inventory equip should place Combat Knife into the melee slot.")
	var hud_state_after_v: Dictionary = hud.call("get_display_state")
	if hud_state_after_v.has("melee_slash_visible"):
		_errors.append("HUD state should not expose removed knife slash feedback.")
	var held_after_v: Dictionary = hud_state_after_v.get("held_weapon", {})
	if str(held_after_v.get("mode", "")) != "melee":
		_errors.append("HUD held weapon state should report melee mode after pressing V.")
	_press_key(player, KEY_V)
	await process_frame
	var hud_state_after_repeated_v: Dictionary = hud.call("get_display_state")
	if not bool(player.call("is_melee_mode_active")):
		_errors.append("Pressing V repeatedly should keep the melee weapon equipped until another weapon key is selected.")
	if hud_state_after_repeated_v.has("melee_slash_visible"):
		_errors.append("Repeated melee selection should not restore removed slash feedback.")
	var health_before := float(enemy.get("current_health"))
	_press_left_click(player)
	await process_frame
	var health_after := float(enemy.get("current_health"))
	var player_state: Dictionary = player.call("get_melee_attack_state")
	var hud_state: Dictionary = hud.call("get_display_state")
	if health_after >= health_before:
		_errors.append("Left-click melee attack should damage an enemy inside the forward slash arc.")
	if int(player_state.get("hit_count", 0)) <= 0:
		_errors.append("Player melee attack state should report at least one hit.")
	if hud_state.has("melee_slash_visible"):
		_errors.append("Melee attack should not restore removed HUD slash feedback.")
	var crescent_slash := scene.get_node_or_null("MeleeCrescentSlash3D") as Node3D
	if crescent_slash == null:
		_errors.append("Left-click melee attack should spawn one independent GPU trail slash VFX in the world.")
	elif crescent_slash.get_node_or_null("ArcGlow") == null or crescent_slash.get_node_or_null("BladeTrail") == null or crescent_slash.get_node_or_null("BladeCore") == null:
		_errors.append("Melee slash VFX should expose aligned ArcGlow, BladeTrail, and BladeCore layers.")
	elif (crescent_slash.get_node_or_null("BladeTrail") as MeshInstance3D).mesh == null:
		_errors.append("Melee BladeTrail should retain a renderable mesh after successful swing setup.")
	elif Vector2(crescent_slash.global_position.x - player.global_position.x, crescent_slash.global_position.z - player.global_position.z).length() > 0.01:
		_errors.append("Melee GPU trail VFX should stay centered on the attacker so its tip radius matches attack range.")
	elif absf(crescent_slash.global_position.y - player.global_position.y - 0.72) > 0.02:
		_errors.append("Melee trail should play near the player's middle height instead of on the ground.")
	if scene.get_node_or_null("MeleeVendorSlashTrail3D") != null:
		_errors.append("Melee hits should not restore the removed vendor slash-trail VFX.")
	var enemy_hit_vfx := scene.get_node_or_null("MeleeEnemyHitFeedback3D") as Node3D
	if enemy_hit_vfx == null:
		_errors.append("A confirmed melee hit should spawn one enemy-hit VFX at the resolved hit position.")
	elif enemy_hit_vfx.get_node_or_null("VFXAnticipationFire3/torus white simple") == null:
		_errors.append("Melee enemy-hit VFX should retain the approved Anticipation_Fire3 ring layer.")
	elif (enemy_hit_vfx.get_node_or_null("VFXAnticipationFire3/cross") as GPUParticles3D).visible:
		_errors.append("Melee enemy-hit VFX should keep the Anticipation_Fire3 cross layer disabled.")
	elif enemy_hit_vfx.global_position.distance_to(enemy.global_position + Vector3.UP * 0.65) > 0.02:
		_errors.append("Melee enemy-hit VFX should play at the combat service resolved hit position.")
	for removed_impact_name in ["MeleeImpactFlash3D", "LeLuFirearmTargetHitFeedback3D"]:
		if scene.get_node_or_null(removed_impact_name) != null:
			_errors.append("Melee hits should not restore a removed legacy impact VFX: %s." % removed_impact_name)
	if scene.get_node_or_null("MeleeStarHitFeedback3D") != null:
		_errors.append("Melee hits should not spawn the removed PolyBlocks star VFX.")
	if player.get_node_or_null("CombatVfxSpawner3D") == null:
		_errors.append("Player should retain the firearm-only CombatVfxSpawner3D.")
	if player.get_node_or_null("MeleeVfxSpawner3D") == null:
		_errors.append("Player should expose MeleeVfxSpawner3D for presentation-only trail playback.")
	var health_after_click := float(enemy.get("current_health"))
	await _hold_left_click(player, 42)
	var health_after_hold := float(enemy.get("current_health"))
	if health_after_hold >= health_after_click - 19.0:
		_errors.append("Holding left mouse in melee mode should keep swinging after cooldown and deal repeated damage.")
	_press_key(player, KEY_1)
	await process_frame
	if bool(player.call("is_melee_mode_active")):
		_errors.append("Pressing 1 should return from melee mode to firearm mode.")
	var held_after_one: Dictionary = hud.call("get_display_state").get("held_weapon", {})
	if str(held_after_one.get("mode", "")) != "firearm" or str(held_after_one.get("item_id", "")) != "pistol_S":
		_errors.append("HUD held weapon state should report Pistol-S after pressing 1.")
	if pistol_visual != null and knife_visual != null and (not pistol_visual.visible or knife_visual.visible):
		_errors.append("Pressing 1 should show the pistol visual and hide the knife visual.")
	await create_timer(0.9).timeout
	await process_frame
	_free_node(scene)


func _validate_source_boundaries() -> void:
	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	for required in ["toggle_melee_mode", "switch_to_firearm_mode", "_attack_with_melee_weapon", "MeleeAttackServiceScript", "MeleeVfxSpawner3D", "play_crescent_slash", "hit_positions", "resolved_slot == &\"melee\"", "_set_melee_mode(true)", "KEY_V", "KEY_1"]:
		if not player_source.contains(required):
			_errors.append("PlayerController3D should bridge melee input through %s." % required)
	var service_source := FileAccess.get_file_as_string("res://scripts/combat/melee_attack_service.gd")
	for required in ["perform_arc_attack", "DamageEventScript", "apply_damage", "damageable", "hit_positions"]:
		if not service_source.contains(required):
			_errors.append("MeleeAttackService should own melee hit rules through %s." % required)
	for forbidden in ["Control", "PlayerHud", "InputEvent", "InputMap"]:
		if service_source.contains(forbidden):
			_errors.append("MeleeAttackService should stay combat-only and not own UI/input concerns: %s." % forbidden)
	var hud_source := FileAccess.get_file_as_string("res://scripts/ui/player_hud_painter.gd")
	if hud_source.contains("_paint_melee_slash"):
		_errors.append("PlayerHUDPainter should not duplicate world-space knife VFX.")
	for removed_path in [
		"res://data/vfx/weapons/combat_knife_vfx_profile.tres",
		"res://scenes/combat/qstyle_knife_attack_presentation_3d.tscn",
		"res://scenes/combat/qstyle_knife_hit_feedback_3d.tscn",
		"res://scenes/combat/melee_blade_trail_sweep_3d.tscn",
		"res://scenes/combat/melee_impact_card_3d.tscn",
		"res://scripts/combat/melee_impact_flash_3d.gd",
		"res://scenes/combat/vfx/melee_impact_flash_3d.tscn",
		"res://shaders/vfx/melee_impact_flash.gdshader",
	]:
		if FileAccess.file_exists(removed_path):
			_errors.append("Removed knife VFX resource should stay absent: %s." % removed_path)
	for required_path in [
		"res://scripts/combat/melee_vfx_spawner_3d.gd",
		"res://scripts/combat/melee_crescent_slash_3d.gd",
		"res://scripts/combat/melee_enemy_hit_vfx_3d.gd",
		"res://scenes/combat/vfx/melee_crescent_slash_3d.tscn",
		"res://scenes/combat/vfx/knife_hit_fire_2.tscn",
		"res://scenes/combat/vfx/melee_enemy_hit_feedback_3d.tscn",
		"res://scripts/combat/melee_vfx_preview_3d.gd",
		"res://scenes/combat/vfx/melee_vfx_preview_3d.tscn",
		"res://assets/vendor/lelu_vfx_trails/SOURCE.md",
		"res://assets/vendor/lelu_vfx_trails/gpu_trail/LICENSE",
		"res://assets/vendor/lelu_vfx_trails/textures/T_VFX_BlueTRails1.png",
		"res://shaders/vfx/melee_authored_trail.gdshader",
	]:
		if not FileAccess.file_exists(required_path):
			_errors.append("Melee trail VFX dependency is missing: %s." % required_path)
	var preview_source := FileAccess.get_file_as_string("res://scripts/combat/melee_vfx_preview_3d.gd")
	for required in ["@tool", "@export_tool_button", "Preview Slash", "PreviewCamera3D", "PreviewFocus", "_preview_slash", "Engine.is_editor_hint", "_spawn_slash"]:
		if not preview_source.contains(required):
			_errors.append("Melee VFX preview should support direct editor replay through %s." % required)
	var crescent_source := FileAccess.get_file_as_string("res://scripts/combat/melee_crescent_slash_3d.gd")
	for required in ["@tool", "EDITOR_PREVIEW_RANGE", "EDITOR_PREVIEW_ARC_DEGREES", "COUNTERCLOCKWISE_SWEEP := -1.0", "_build_editor_preview", "Engine.is_editor_hint", "segment_count := 128", "ARC_GLOW_OUTER_SCALE := 1.035", "geometry_outer_radius := resolved_range / ARC_GLOW_OUTER_SCALE", "ArcGlow", "BladeTrail", "BladeCore", "[_arc_glow, _blade_trail, _blade_core]", "_materials.size() != 3", "arc_mesh", "Vector3.UP * 0.72", "arc_degrees", "_build_smooth_arc_mesh", "width_envelope", "Mesh.PRIMITIVE_TRIANGLES", "reveal_progress"]:
		if not crescent_source.contains(required):
			_errors.append("Melee smooth trail should bind high-resolution geometry, range, arc, and lifecycle through %s." % required)
	var crescent_scene_source := FileAccess.get_file_as_string("res://scenes/combat/vfx/melee_crescent_slash_3d.tscn")
	for required in ["melee_authored_trail.gdshader", "layer_mode = 0", "layer_mode = 1", "layer_mode = 2", "ArcGlow", "BladeTrail", "BladeCore", "KnifeHitFire2", "knife_hit_fire_2.tscn", "cast_shadow = 0"]:
		if not crescent_scene_source.contains(required):
			_errors.append("Melee trail scene should retain the isolated authored material adaptation through %s." % required)
	var trail_shader_source := FileAccess.get_file_as_string("res://shaders/vfx/melee_authored_trail.gdshader")
	for required in ["reveal_progress", "layer_mode", "leading_progress", "trailing_energy", "moving_glint", "sweep_head", "outer_edge", "trail_alpha"]:
		if not trail_shader_source.contains(required):
			_errors.append("Melee detail shader should retain glow, core, and reveal behavior through %s." % required)
	for forbidden in ["trail_texture", "authored_sample", "authored_brightness", "authored_mask"]:
		if trail_shader_source.contains(forbidden) or crescent_scene_source.contains(forbidden):
			_errors.append("Melee trail should not retain removed texture sampling: %s." % forbidden)
	if FileAccess.file_exists("res://shaders/vfx/melee_crescent_slash.gdshader"):
		_errors.append("Removed code-authored crescent shader should stay absent after the GPU trail replacement.")
	for forbidden in ["D:\\3DMesh\\Godot_Tool", "Demo_Scenes", "sword_anim1c", "WorldEnvironment", "Camera3D"]:
		if crescent_scene_source.contains(forbidden):
			_errors.append("Runtime melee trail scene should exclude source-demo content: %s." % forbidden)
	for forbidden in ["res://VFX/Scenes/VFX_Hit_fire_2.tscn", "EnergyParticles", "OmniLight3D", "CPUParticles3D", "collision_mode"]:
		if crescent_scene_source.contains(forbidden):
			_errors.append("Melee slash scene should use only its dedicated local fire VFX copy and no forbidden presentation nodes: %s." % forbidden)
	var knife_hit_scene_source := FileAccess.get_file_as_string("res://scenes/combat/vfx/knife_hit_fire_2.tscn")
	for required in ["KnifeHitFire2", "torus white simple", "color = Color(1, 1, 1, 0.5)", "AnimationPlayer"]:
		if not knife_hit_scene_source.contains(required):
			_errors.append("Knife-local fire VFX copy should retain its tunable authored layer: %s." % required)
	for required in ["knife_hit_fire_2_assets/shaders", "knife_hit_fire_2_assets/textures"]:
		if not knife_hit_scene_source.contains(required):
			_errors.append("Knife-local fire VFX copy should use its independent asset path: %s." % required)
	if knife_hit_scene_source.contains("res://VFX/"):
		_errors.append("Knife-local fire VFX copy should not reference the firearm VFX asset directory.")
	for forbidden in ["OmniLight3D", "collision_mode", "MuzzleMarker3D", "CombatVfxSpawner3D", "Projectile"]:
		if knife_hit_scene_source.contains(forbidden):
			_errors.append("Knife-local fire VFX copy should remain presentation-only and not inherit firearm ownership: %s." % forbidden)
	var spawner_source := FileAccess.get_file_as_string("res://scripts/combat/melee_vfx_spawner_3d.gd")
	for removed_path in [
		"res://scenes/combat/vfx/melee_star_hit_feedback_3d.tscn",
		"res://scripts/combat/melee_star_hit_feedback_3d.gd",
		"res://assets/vendor/polyblocks_effectblocks/SOURCE.md",
	]:
		if FileAccess.file_exists(removed_path):
			_errors.append("Removed melee star-hit VFX resource should stay absent: %s." % removed_path)
	for required in ["arc_degrees", "CrescentSlashScene", "EnemyHitScene", "attacker.global_position", "range_meters", "hit_positions", "_spawn_enemy_hit"]:
		if not spawner_source.contains(required):
			_errors.append("Melee VFX spawner should retain resolved-hit presentation through %s." % required)
	for forbidden in ["EnemySlashHitScene", "MeleeVendorSlashTrail3D", "ENEMY_HIT_SCALE", "ENEMY_HIT_LIFETIME_SECONDS", "ImpactFlashScene", "_spawn_impact_flash", "MeleeImpactFlash3D", "FirearmTargetHitScene", "_spawn_shared_target_hit", "LeLuFirearmTargetHitFeedback3D", "StarHitScene", "_spawn_star_hit", "MeleeStarHitFeedback3D"]:
		if spawner_source.contains(forbidden):
			_errors.append("Melee VFX spawner should not retain enemy-hit presentation: %s." % forbidden)
	var enemy_hit_source := FileAccess.get_file_as_string("res://scripts/combat/melee_enemy_hit_vfx_3d.gd")
	for required in ["LIFETIME_SECONDS", "setup", "look_at", "create_timer", "queue_free"]:
		if not enemy_hit_source.contains(required):
			_errors.append("Melee enemy-hit VFX should own safe one-shot playback through %s." % required)
	for required in ["_make_vendor_white", "Color.WHITE", "_make_color_ramp_white", "_disable_cross", "cross.visible = false"]:
		if not enemy_hit_source.contains(required):
			_errors.append("Melee enemy-hit VFX should keep its local white ring-only adaptation through %s." % required)
	var enemy_hit_scene_source := FileAccess.get_file_as_string("res://scenes/combat/vfx/melee_enemy_hit_feedback_3d.tscn")
	if not enemy_hit_scene_source.contains("res://VFX/Scenes/VFX_Anticipation_fire_3.tscn"):
		_errors.append("Melee enemy-hit VFX should bind the user-approved Anticipation_Fire3 vendor scene.")
	if not enemy_hit_scene_source.contains("scale = Vector3(0.51, 0.51, 0.51)"):
		_errors.append("Melee enemy-hit VFX should play Anticipation_Fire3 at 1.5x its original compact scale.")


func _press_key(player: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.physical_keycode = keycode
	player.call("_unhandled_input", event)


func _press_left_click(player: Node) -> void:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	player.call("_unhandled_input", event)


func _hold_left_click(player: Node, physics_frames: int) -> void:
	var press := InputEventMouseButton.new()
	press.pressed = true
	press.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(press)
	player.call("_unhandled_input", press)
	for _index in range(maxi(physics_frames, 1)):
		player.look_at(Vector3(0.0, 0.0, -3.0), Vector3.UP)
		await physics_frame
	player.set("_melee_attack_cooldown_remaining", 0.0)
	player.look_at(Vector3(0.0, 0.0, -3.0), Vector3.UP)
	player.call("_update_held_primary_fire")
	var release := InputEventMouseButton.new()
	release.pressed = false
	release.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(release)
	player.call("_unhandled_input", release)


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
