extends CharacterBody3D

# 玩家控制器總入口：
# - 這個檔案負責把生命/體力、背包、安全口袋、裝備、武器、受傷與死亡流程串在一起。
# - 移動數值交給 PlayerStats3D，輸入判斷交給 PlayerInputReader3D，移動實作交給 PlayerLocomotion3D。
# - 背包/裝備操作大多委派給 PlayerInventoryActions3D，這裡主要保留「玩家狀態中心」與對外 API。

# 依賴腳本與固定規則：這些 preload 是此控制器會呼叫的服務/協作者。
const DEFAULT_STARTER_LOADOUT := preload("res://data/inventory/starter_inventory.tres")
const PlayerStatsProfileScript := preload("res://scripts/player/player_stats_profile.gd")
const PlayerStatsScript := preload("res://scripts/player/player_stats_3d.gd")
const PlayerInputReaderScript := preload("res://scripts/player/player_input_reader_3d.gd")
const PlayerLocomotionScript := preload("res://scripts/player/player_locomotion_3d.gd")
const PlayerInventoryActionsScript := preload("res://scripts/player/player_inventory_actions_3d.gd")
const PlayerLoadoutSupportScript := preload("res://scripts/player/player_loadout_support_3d.gd")
const PlayerEquipmentControllerScript := preload("res://scripts/player/player_equipment_controller_3d.gd")
const PlayerQuickSlotModelScript := preload("res://scripts/player/player_quick_slot_model.gd")
const PlayerQuickSlotControllerScript := preload("res://scripts/player/player_quick_slot_controller_3d.gd")
const PlayerTimedActionControllerScript := preload("res://scripts/player/player_timed_action_controller_3d.gd")
const RaidLossRulesScript := preload("res://scripts/raid/raid_loss_rules.gd")
const MeleeAttackServiceScript := preload("res://scripts/combat/melee_attack_service.gd")
const WeaponTuningServiceScript := preload("res://scripts/combat/weapon_tuning_service.gd")
const DEFAULT_RELOAD_DURATION_SECONDS := 0.8

# 對外事件：HUD、背包 UI、裝備 UI、換彈提示等會靠這些 signal 更新畫面。
signal health_changed(current: float, maximum: float)
signal died(event: DamageEvent)
signal stamina_changed(current: float, maximum: float)
signal inventory_changed
signal equipment_changed
signal reload_feedback_changed(result: Dictionary)
signal reload_progress_changed(state: Dictionary)
signal item_use_progress_changed(state: Dictionary)
signal melee_attack_changed(state: Dictionary)

# 統計數值代理：實際計算在 _stats，這裡提供舊 API/其他系統可讀的屬性。
var max_health: float:
	get:
		return _stats.max_health() + _equipment.get_max_health_bonus()

var walk_speed: float:
	get:
		return _stats.walk_speed()

var sprint_speed: float:
	get:
		return _stats.sprint_speed()

var max_stamina: float:
	get:
		return _stats.max_stamina()

var roll_distance: float:
	get:
		return _stats.roll_distance()

var roll_speed: float:
	get:
		return _stats.roll_speed()

var backpack_slots: int:
	get:
		return _stats.backpack_slots()

var carry_weight_limit: float:
	get:
		return _stats.carry_weight_limit()

var safe_pocket_slots: int:
	get:
		return _stats.safe_pocket_slots()

var defense: float:
	get:
		return _stats.defense() + _equipment.get_defense_bonus()

# 玩家即時狀態：會在戰鬥、移動、負重、死亡判定中被更新。
var health: float = 0.0
var stamina: float = 0.0
var current_carry_weight: float = 0.0
var is_exhausted: bool = false
var is_dead := false

# 編輯器可調設定：角色基礎數值、初始背包、換彈時間都從這裡進入。
@export var stats_profile: PlayerStatsProfile = PlayerStatsProfileScript.new()
@export var starter_loadout: Resource = DEFAULT_STARTER_LOADOUT
@export_range(0.05, 5.0, 0.05) var reload_duration_seconds := DEFAULT_RELOAD_DURATION_SECONDS
@export_range(0.1, 4.0, 0.05) var melee_attack_range := 1.45
@export_range(15.0, 180.0, 1.0) var melee_attack_arc_degrees := 115.0
@export_range(0.05, 2.0, 0.01) var melee_attack_cooldown_seconds := 0.42
@export_range(1.0, 500.0, 1.0) var melee_fallback_damage := 18.0

# 三個主要資料模型：背包、安全口袋、裝備欄分開存，UI 和存檔會讀這些模型。
var inventory_model := InventoryModel.new()
var safe_pocket_model := InventoryModel.new()
var _equipment: PlayerEquipmentController3D = PlayerEquipmentControllerScript.new(self)
var equipment_model: RefCounted = _equipment.get_model()
var quick_slot_model: RefCounted = PlayerQuickSlotModelScript.new()
var _quick_slots: PlayerQuickSlotController3D = PlayerQuickSlotControllerScript.new(self, quick_slot_model, inventory_model)

# 執行期協作者與暫存狀態：控制器不直接吃下所有細節，而是把移動/輸入/武器拆給專職物件。
var _stats: PlayerStats3D
var _input_reader := PlayerInputReaderScript.new(self)
var _locomotion: PlayerLocomotion3D
var _weapon_controller: Node = null
var _melee_vfx_spawner: Node = null
var _pistol_visual: Node3D = null
var _smg_visual: Node3D = null
var _knife_visual: Node3D = null
var _pistol_muzzle_marker: Marker3D = null
var _smg_muzzle_marker: Marker3D = null
var _melee_mode_active := false
var _selected_quick_item_key := -1
var _primary_fire_held := false
var _melee_attack_cooldown_remaining := 0.0
var _last_melee_attack_state := {
	"active": false,
	"mode_active": false,
	"hit_count": 0,
	"weapon_id": "",
	"progress": 0.0,
}
var _timed_actions: PlayerTimedActionController3D = PlayerTimedActionControllerScript.new()


# 初始化流程：套用難度/基地加成，建立模型容量，掛事件，載入 raid loadout 或 starter loadout。
func _ready() -> void:
	var runtime_stats_profile := stats_profile.duplicate(true) as PlayerStatsProfile
	var difficulty_manager := get_node_or_null("/root/DifficultyManager")
	if difficulty_manager != null and difficulty_manager.has_method("apply_to_player_stats"):
		difficulty_manager.apply_to_player_stats(runtime_stats_profile)
	_stats = PlayerStatsScript.new(runtime_stats_profile)
	_locomotion = PlayerLocomotionScript.new(self, _stats)
	_weapon_controller = get_node_or_null("WeaponController3D")
	_melee_vfx_spawner = get_node_or_null("MeleeVfxSpawner3D")
	_pistol_visual = get_node_or_null("WeaponVisualRoot/PistolVisual") as Node3D
	_smg_visual = get_node_or_null("WeaponVisualRoot/SmgVisual") as Node3D
	_knife_visual = get_node_or_null("WeaponVisualRoot/KnifeVisual") as Node3D
	_pistol_muzzle_marker = get_node_or_null("WeaponVisualRoot/PistolVisual/MuzzleMarker3D") as Marker3D
	_smg_muzzle_marker = get_node_or_null("WeaponVisualRoot/SmgVisual/MuzzleMarker3D") as Marker3D
	_equipment.set_weapon_controller(_weapon_controller)
	_timed_actions.setup(self, inventory_model, _equipment, _weapon_controller)
	_timed_actions.reload_feedback_changed.connect(_on_reload_feedback_changed)
	_timed_actions.reload_progress_changed.connect(_on_reload_progress_changed)
	_timed_actions.item_use_progress_changed.connect(_on_item_use_progress_changed)
	_apply_base_upgrade_effects()
	inventory_model.setup(backpack_slots)
	safe_pocket_model.setup(safe_pocket_slots)
	inventory_model.changed.connect(_on_inventory_changed)
	safe_pocket_model.changed.connect(_on_safe_pocket_changed)
	equipment_model.changed.connect(_on_equipment_changed)
	if not _load_pending_raid_loadout() and not _load_saved_base_equipment():
		_load_starter_inventory()
	_sync_weapon_from_equipment()
	current_carry_weight = _get_carried_weight()
	health = get_total_max_health()
	stamina = max_stamina
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	health_changed.emit(health, get_total_max_health())
	stamina_changed.emit(stamina, max_stamina)


# 未處理輸入：只處理玩家直接操作，UIManager 擋住 gameplay 時會先退出。
func _unhandled_input(event: InputEvent) -> void:
	if _input_reader.is_gameplay_blocked():
		return
	var quick_key := _quick_item_key_for_event(event)
	if quick_key >= 3:
		var selected := select_quick_slot(quick_key)
		if not selected and _selected_quick_item_key == quick_key:
			_selected_quick_item_key = -1
			_sync_held_weapon_visuals()
		get_viewport().set_input_as_handled()
		return
	if _has_selected_quick_item() and _is_reload_event(event):
		get_viewport().set_input_as_handled()
		return
	if _is_reload_event(event):
		reload_equipped_weapon()
		get_viewport().set_input_as_handled()
		return
	if _is_melee_toggle_event(event):
		toggle_melee_mode()
		get_viewport().set_input_as_handled()
		return
	if _is_firearm_select_event(event):
		switch_to_firearm_mode()
		get_viewport().set_input_as_handled()
		return
	if _is_sidearm_select_event(event):
		switch_to_weapon_slot(&"sidearm")
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_primary_fire_held = event.pressed
		if event.pressed:
			if _has_selected_quick_item():
				use_selected_quick_item()
				get_viewport().set_input_as_handled()
				return
			_fire_equipped_weapon()


# 對外查詢 API：UI、驗證工具、其他系統用這些函式讀玩家目前總數值。
func get_total_max_health() -> float:
	return max_health


func get_total_backpack_slots() -> int:
	return backpack_slots


func get_total_carry_weight_limit() -> float:
	return carry_weight_limit


func get_total_safe_pocket_slots() -> int:
	return safe_pocket_slots


func get_total_defense() -> float:
	return defense


# 裝備加成查詢：護甲壞掉時不提供防禦/護甲等級，避免破損裝備仍生效。
func get_equipment_defense_bonus() -> float:
	return _equipment.get_defense_bonus()


func get_equipment_armor_protection_level() -> float:
	return _equipment.get_armor_protection_level()


# HUD 狀態包：把護甲名稱、加成、耐久與顯示文字整理成 UI 容易使用的 Dictionary。
func get_armor_effect_state() -> Dictionary:
	return _equipment.get_armor_effect_state()


func set_current_carry_weight(value: float) -> void:
	current_carry_weight = maxf(value, 0.0)


func get_current_carry_weight() -> float:
	return _get_carried_weight()


func get_weight_speed_multiplier() -> float:
	return _stats.weight_speed_multiplier(current_carry_weight)


func get_inventory_model() -> InventoryModel:
	return inventory_model


func get_safe_pocket_model() -> InventoryModel:
	return safe_pocket_model


func get_equipment_model() -> RefCounted:
	return equipment_model


func get_player_equipment_controller() -> PlayerEquipmentController3D:
	return _equipment


# 武器/護甲耐久查詢：統一回傳 Dictionary，讓 HUD 與驗證工具不用直接解析裝備格。
func get_active_weapon_durability_state() -> Dictionary:
	return _equipment.get_active_weapon_durability_state()


func get_active_armor_durability_state() -> Dictionary:
	return _equipment.get_active_armor_durability_state()


func get_last_weapon_spread_state() -> Dictionary:
	return _equipment.get_last_weapon_spread_state()


func get_last_weapon_recoil_state() -> Dictionary:
	return _equipment.get_last_weapon_recoil_state()


func get_active_weapon_attachment_state() -> Dictionary:
	return _equipment.get_active_weapon_attachment_state()


func get_weapon_mod_panel_state(weapon_slot_id: StringName = &"") -> Dictionary:
	return _equipment.get_weapon_mod_panel_state(weapon_slot_id)


func get_last_reload_result() -> Dictionary:
	return _timed_actions.get_last_reload_result()


func get_reload_state() -> Dictionary:
	return _timed_actions.get_reload_state()


func get_item_use_state() -> Dictionary:
	return _timed_actions.get_item_use_state()


func is_timed_action_active() -> bool:
	return _timed_actions.is_active()


func get_melee_attack_state() -> Dictionary:
	return _last_melee_attack_state.duplicate(true)


func get_held_weapon_state() -> Dictionary:
	var quick_stack := _selected_quick_item_stack()
	if not quick_stack.is_empty():
		return {
			"mode": "item",
			"mode_active": false,
			"weapon_slot_id": "quick_%d" % _selected_quick_item_key,
			"quick_key": _selected_quick_item_key,
			"has_item": true,
			"item_id": str(quick_stack.get("id", "")),
			"name_key": str(quick_stack.get("name_key", "")),
			"display_name": _stack_display_name(quick_stack),
		}
	var held_item := _equipped_melee_weapon() if _melee_mode_active else _equipment.get_equipped_weapon_item()
	return {
		"mode": "melee" if _melee_mode_active else "firearm",
		"mode_active": _melee_mode_active,
		"weapon_slot_id": "melee" if _melee_mode_active else str(_equipment.get_active_weapon_slot_id()),
		"has_item": held_item != null,
		"item_id": str(held_item.id) if held_item != null else "",
		"name_key": str(held_item.name_key) if held_item != null else "",
		"display_name": _item_display_name(held_item) if held_item != null else "",
	}


func get_quick_bar_state() -> Array[Dictionary]:
	return _quick_slots.get_quick_bar_state()


func get_quick_slot_state(key_number: int) -> Dictionary:
	return _quick_slots.get_quick_slot_state(key_number)


func is_melee_mode_active() -> bool:
	return _melee_mode_active


func get_compatible_backpack_ammo_count() -> int:
	return _count_compatible_backpack_ammo()


# 背包與裝備操作門面：實際規則在 PlayerInventoryActions3D，控制器保留統一入口給 UI 呼叫。
func add_item_resource(item_def: ItemDef, quantity: int = 1) -> bool:
	return inventory_model.add_item(item_def, quantity)


func can_move_inventory_stack_to_safe_pocket(stack_index: int) -> bool:
	return PlayerInventoryActionsScript.can_move_inventory_stack_to_safe_pocket(self, stack_index)


func move_inventory_stack_to_safe_pocket(stack_index: int) -> bool:
	return PlayerInventoryActionsScript.move_inventory_stack_to_safe_pocket(self, stack_index)


func can_move_safe_pocket_stack_to_inventory(stack_index: int) -> bool:
	return PlayerInventoryActionsScript.can_move_safe_pocket_stack_to_inventory(self, stack_index)


func move_safe_pocket_stack_to_inventory(stack_index: int) -> bool:
	return PlayerInventoryActionsScript.move_safe_pocket_stack_to_inventory(self, stack_index)


func can_equip_inventory_stack(stack_index: int, slot_id: StringName = &"") -> bool:
	return _equipment.can_equip_inventory_stack(stack_index, slot_id)


func equip_inventory_stack(stack_index: int, slot_id: StringName = &"") -> bool:
	var resolved_slot := slot_id
	if resolved_slot == &"" and stack_index >= 0 and stack_index < inventory_model.stacks.size():
		resolved_slot = _equipment.default_equipment_slot_for_stack(inventory_model.stacks[stack_index] as Dictionary)
	var equipped := _equipment.equip_inventory_stack(stack_index, slot_id)
	if equipped and resolved_slot == &"melee":
		_selected_quick_item_key = -1
		_set_melee_mode(true)
	return equipped


func can_swap_equipment_slots(source_slot_id: StringName, target_slot_id: StringName) -> bool:
	return _equipment.can_swap_equipment_slots(source_slot_id, target_slot_id)


func swap_equipment_slots(source_slot_id: StringName, target_slot_id: StringName) -> bool:
	return _equipment.swap_equipment_slots(source_slot_id, target_slot_id)


func can_attach_inventory_stack_to_weapon(stack_index: int, weapon_slot_id: StringName = &"") -> bool:
	return _equipment.can_attach_inventory_stack_to_weapon(stack_index, weapon_slot_id)


func can_attach_inventory_stack_to_weapon_hardpoint(stack_index: int, weapon_slot_id: StringName, hardpoint_slot: StringName) -> bool:
	return _equipment.can_attach_inventory_stack_to_weapon_hardpoint(stack_index, weapon_slot_id, hardpoint_slot)


func attach_inventory_stack_to_weapon(stack_index: int, weapon_slot_id: StringName = &"") -> bool:
	return _equipment.attach_inventory_stack_to_weapon(stack_index, weapon_slot_id)


func attach_inventory_stack_to_weapon_hardpoint(stack_index: int, weapon_slot_id: StringName, hardpoint_slot: StringName) -> bool:
	return _equipment.attach_inventory_stack_to_weapon_hardpoint(stack_index, weapon_slot_id, hardpoint_slot)


func unequip_weapon_mod_to_inventory(weapon_slot_id: StringName, hardpoint_slot: StringName) -> bool:
	return _equipment.unequip_weapon_mod_to_inventory(weapon_slot_id, hardpoint_slot)


func can_unequip_equipment_slot(slot_id: StringName) -> bool:
	return _equipment.can_unequip_equipment_slot(slot_id)


func unequip_equipment_slot(slot_id: StringName) -> bool:
	return _equipment.unequip_equipment_slot(slot_id)


func can_use_inventory_stack(stack_index: int) -> bool:
	return _timed_actions.can_use_inventory_stack(stack_index)


func use_inventory_stack(stack_index: int) -> bool:
	return _timed_actions.use_inventory_stack(stack_index)


func assign_quick_slot_for_inventory_stack(key_number: int, stack_index: int) -> bool:
	return _quick_slots.assign_inventory_stack(key_number, stack_index)


func clear_quick_slot_for_key(key_number: int) -> bool:
	return _quick_slots.clear_slot(key_number)


func move_quick_slot_to_key(from_key: int, to_key: int) -> bool:
	return _quick_slots.move_slot(from_key, to_key)


func select_quick_slot(key_number: int) -> bool:
	return _quick_slots.select_slot(key_number)


func use_selected_quick_item() -> bool:
	return _quick_slots.use_selected()


func _has_selected_quick_item() -> bool:
	return _quick_slots.has_selected_item()


func _selected_quick_item_stack() -> Dictionary:
	return _quick_slots.selected_item_stack()


func use_quick_slot(key_number: int) -> bool:
	return _quick_slots.use_slot(key_number)


func _sync_selected_quick_slot_after_slot_change(key_number: int) -> void:
	_quick_slots.sync_selected_after_slot_change(key_number)


func _is_quick_slot_still_valid(key_number: int) -> bool:
	return _quick_slots.is_slot_still_valid(key_number)


func _is_quick_key_number(key_number: int) -> bool:
	return _quick_slots.is_quick_key_number(key_number)


func _is_stack_usable_for_quick_bar(stack: Dictionary) -> bool:
	return _quick_slots.is_stack_usable(stack)


func reload_equipped_weapon(reload_source: StringName = &"manual") -> bool:
	return _timed_actions.reload_equipped_weapon(reload_source)


func unload_equipped_weapon_ammo_to_backpack() -> Dictionary:
	return _timed_actions.unload_equipped_weapon_ammo_to_backpack()


func get_default_equipment_slot_for_stack(stack: Dictionary) -> StringName:
	return _equipment.default_equipment_slot_for_stack(stack)


func toggle_melee_mode() -> bool:
	if _equipped_melee_weapon() == null and not _equip_first_backpack_melee_weapon():
		return false
	if _equipped_melee_weapon() == null:
		return false
	_selected_quick_item_key = -1
	_set_melee_mode(true)
	return true


func switch_to_firearm_mode() -> bool:
	if _equipment.get_equipped_weapon_item() == null:
		_equip_first_backpack_firearm_weapon()
	return switch_to_weapon_slot(&"primary_weapon")


func switch_to_weapon_slot(slot_id: StringName) -> bool:
	if slot_id == &"primary_weapon" and equipment_model.call("is_empty", slot_id):
		_equip_first_backpack_firearm_weapon()
	_set_melee_mode(false)
	var selected := _equipment.set_active_weapon_slot(slot_id)
	if selected:
		_selected_quick_item_key = -1
	_sync_weapon_from_equipment()
	return selected


func set_active_weapon_slot(slot_id: StringName) -> bool:
	return switch_to_weapon_slot(slot_id)


func get_equipped_weapon_slot_id() -> StringName:
	return _equipment.get_equipped_weapon_slot_id()


# 換彈完成：真正消耗背包彈藥並同步武器彈數，失敗時會記錄阻擋原因。
# 受傷/死亡入口：先套護甲減傷，再磨損護甲耐久，血量歸零時交給 _die。
func apply_damage(event: DamageEvent) -> bool:
	if event == null or event.amount <= 0.0 or is_dead:
		return false
	var mitigated_amount := _equipment.damage_after_armor(event, _stats.defense())
	health = maxf(health - mitigated_amount, 0.0)
	_apply_equipped_armor_durability_wear()
	_apply_equipped_helmet_durability_wear()
	health_changed.emit(health, get_total_max_health())
	if health <= 0.0:
		_die(event)
	return true


func restore_health_to_full() -> bool:
	var maximum := get_total_max_health()
	if maximum <= 0.0 or health >= maximum:
		return false
	is_dead = false
	health = maximum
	health_changed.emit(health, maximum)
	return true


func is_alive() -> bool:
	return not is_dead and health > 0.0


# 每幀物理更新：換彈進度、後座力恢復、移動委派、滑動與滑鼠朝向都在這裡串起來。
func _physics_process(delta: float) -> void:
	_melee_attack_cooldown_remaining = maxf(_melee_attack_cooldown_remaining - delta, 0.0)
	_update_held_primary_fire()
	_recover_weapon_recoil(delta)
	var input_blocked := _locomotion.physics_update(delta, _input_reader)

	move_and_slide()
	if not input_blocked:
		_face_mouse_on_ground()
	stamina_changed.emit(stamina, max_stamina)


# 角色朝向：用目前攝影機和滑鼠位置投射到地面，讓角色轉向滑鼠所在點。
func _face_mouse_on_ground() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	if absf(ray_direction.y) < 0.001:
		return

	var distance := -ray_origin.y / ray_direction.y
	if distance < 0.0:
		return

	var look_position := ray_origin + ray_direction * distance
	look_position.y = global_position.y
	if global_position.distance_to(look_position) > 0.1:
		look_at(look_position, Vector3.UP)


# 射擊主流程：同步裝備武器，處理破損/自動換彈，再計算射線、散布、後座力與耐久消耗。
func _fire_equipped_weapon() -> void:
	if _melee_mode_active:
		_attack_with_melee_weapon()
		return
	if _weapon_controller == null or not _weapon_controller.has_method("fire_forward"):
		return
	if _timed_actions.is_active():
		return
	_sync_weapon_from_equipment()
	if _should_block_fire_for_broken_weapon():
		return
	if _should_auto_reload_before_fire():
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	var projectile_origin := _equipped_firearm_muzzle_origin()
	var projectile_direction: Vector3 = _projectile_direction_from_camera_ray(projectile_origin, ray_origin, ray_direction)
	var recoil_result := _projectile_direction_with_recoil(projectile_direction)
	var spread_result := _projectile_direction_with_durability_spread(recoil_result.get("direction", projectile_direction))
	_weapon_controller.fire_forward(projectile_origin, spread_result.get("direction", projectile_direction), get_world_3d().direct_space_state)
	var fire_result: Variant = _weapon_controller.get("last_fire_result")
	if typeof(fire_result) == TYPE_DICTIONARY and bool((fire_result as Dictionary).get("fired", false)):
		_equipment.remember_weapon_fire_result(
			spread_result.get("state", _empty_weapon_spread_state()) as Dictionary,
			recoil_result.get("state", _empty_weapon_recoil_state()) as Dictionary
		)
		_equipment.save_synced_weapon_ammo_state(false)
	else:
		_equipment.clear_weapon_fire_result()


func _attack_with_melee_weapon() -> bool:
	if _timed_actions.is_active() or is_dead:
		return false
	if _melee_attack_cooldown_remaining > 0.0:
		return false
	var melee_weapon := _equipped_melee_weapon()
	if melee_weapon == null:
		_set_melee_mode(false)
		return false
	var attack_rate := melee_weapon.get_weapon_fire_rate_per_second()
	var attack_cooldown := 1.0 / attack_rate if attack_rate > 0.0 else melee_attack_cooldown_seconds
	var attack_range := melee_attack_range
	if melee_weapon.get_weapon_projectile_range() > 0.0:
		attack_range = WeaponTuningServiceScript.authored_range_to_meters(melee_weapon.get_weapon_projectile_range())
	_melee_attack_cooldown_remaining = maxf(attack_cooldown, 0.01)
	var result := MeleeAttackServiceScript.perform_arc_attack(
		self,
		melee_weapon,
		attack_range,
		melee_attack_arc_degrees,
		melee_fallback_damage
	)
	if bool(result.get("attacked", false)) and _melee_vfx_spawner != null and _melee_vfx_spawner.has_method("play_crescent_slash"):
		_melee_vfx_spawner.call(
			"play_crescent_slash",
			self,
			float(result.get("range", attack_range)),
			float(result.get("arc_degrees", melee_attack_arc_degrees)),
			result.get("hit_positions", [])
		)
	_emit_melee_attack_state(true, result)
	return bool(result.get("attacked", false))


func _set_melee_mode(active: bool) -> void:
	_melee_mode_active = active
	_last_melee_attack_state["active"] = false
	_last_melee_attack_state["hit_count"] = 0
	_last_melee_attack_state["progress"] = 0.0
	_last_melee_attack_state["mode_active"] = _melee_mode_active
	_sync_held_weapon_visuals()
	melee_attack_changed.emit(_last_melee_attack_state.duplicate(true))


func _equipped_melee_weapon() -> ItemDef:
	var stack := equipment_model.call("get_slot", &"melee") as Dictionary
	if stack.is_empty():
		return null
	var item_def := _load_item_from_stack(stack)
	if item_def == null or item_def.item_type != "weapon" or not item_def.tags.has(&"melee"):
		return null
	return item_def


func _equip_first_backpack_melee_weapon() -> bool:
	for index in range(inventory_model.stacks.size()):
		var stack := inventory_model.stacks[index] as Dictionary
		var item_def := _load_item_from_stack(stack)
		if item_def == null or item_def.item_type != "weapon" or not item_def.tags.has(&"melee"):
			continue
		return equip_inventory_stack(index, &"melee")
	return false


func _equip_first_backpack_firearm_weapon() -> bool:
	for index in range(inventory_model.stacks.size()):
		var stack := inventory_model.stacks[index] as Dictionary
		var item_def := _load_item_from_stack(stack)
		if item_def == null or item_def.item_type != "weapon" or item_def.tags.has(&"melee"):
			continue
		return equip_inventory_stack(index, &"primary_weapon")
	return false


func _quick_weapon_slot_state(key_number: int, slot_id: StringName, key_label: String = "") -> Dictionary:
	var stack := equipment_model.call("get_slot", slot_id) as Dictionary
	var quick_item_active := _has_selected_quick_item()
	return {
		"key": key_number,
		"key_label": key_label if key_label != "" else str(key_number),
		"kind": "weapon",
		"weapon_slot_id": str(slot_id),
		"assigned": not stack.is_empty(),
		"active": not quick_item_active and ((_melee_mode_active and slot_id == &"melee") or (not _melee_mode_active and _equipment.get_active_weapon_slot_id() == slot_id)),
		"stack": stack.duplicate(true),
		"display_text": _stack_display_name(stack),
	}


func _stack_display_name(stack: Dictionary) -> String:
	var item_def := _load_item_from_stack(stack)
	if item_def == null:
		return ""
	return _item_display_name(item_def)


func _emit_melee_attack_state(active: bool, result: Dictionary = {}) -> void:
	_last_melee_attack_state = {
		"active": active,
		"mode_active": _melee_mode_active,
		"hit_count": int(result.get("hit_count", 0)),
		"hit_paths": (result.get("hit_paths", []) as Array).duplicate(),
		"damage": float(result.get("damage", 0.0)),
		"range": float(result.get("range", melee_attack_range)),
		"arc_degrees": float(result.get("arc_degrees", melee_attack_arc_degrees)),
		"weapon_id": str(result.get("weapon_id", "")),
		"progress": 1.0 if active else 0.0,
	}
	melee_attack_changed.emit(_last_melee_attack_state.duplicate(true))


func _sync_held_weapon_visuals() -> void:
	var firearm := _equipment.get_equipped_weapon_item()
	var show_firearm := _selected_quick_item_key < 0 and not _melee_mode_active and firearm != null
	var firearm_id := str(firearm.id) if firearm != null else ""
	if _pistol_visual != null:
		_pistol_visual.visible = show_firearm and firearm_id != "smg_S"
	if _smg_visual != null:
		_smg_visual.visible = show_firearm and firearm_id == "smg_S"
	if _knife_visual != null:
		_knife_visual.visible = _selected_quick_item_key < 0 and _melee_mode_active and _equipped_melee_weapon() != null


func _equipped_firearm_muzzle_origin() -> Vector3:
	var muzzle_marker := _smg_muzzle_marker if _smg_visual != null and _smg_visual.visible else _pistol_muzzle_marker
	if muzzle_marker != null and muzzle_marker.is_inside_tree():
		# Start just beyond the authored barrel tip, never at the player root.
		var barrel_forward := -muzzle_marker.global_transform.basis.z
		barrel_forward.y = 0.0
		barrel_forward = barrel_forward.normalized() if barrel_forward.length() > 0.001 else -global_transform.basis.z.normalized()
		return muzzle_marker.global_position + barrel_forward * 0.06
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.001 else Vector3.FORWARD
	return global_position + Vector3.UP * 0.7 + forward * 0.45


# 彈道方向：從攝影機滑鼠射線推回地面目標，再轉成武器射出的水平方向。
func _projectile_direction_from_camera_ray(origin: Vector3, ray_origin: Vector3, ray_direction: Vector3) -> Vector3:
	if absf(ray_direction.y) < 0.001:
		var fallback := ray_direction
		fallback.y = 0.0
		return fallback.normalized() if fallback != Vector3.ZERO else -global_transform.basis.z.normalized()
	var ground_distance := -ray_origin.y / ray_direction.y
	var ground_position := ray_origin + ray_direction * ground_distance
	var direction := ground_position - origin
	direction.y = 0.0
	if direction.length() < 0.001:
		return -global_transform.basis.z.normalized()
	return direction.normalized()


# 散布與後座力計算：把武器耐久、彈藥倍率、配件倍率合成最後射擊方向與狀態包。
func _projectile_direction_with_durability_spread(direction: Vector3) -> Dictionary:
	# Boundary marker: PlayerEquipmentController3D owns ItemDurabilityServiceScript.combat_penalty_state.
	return _equipment.projectile_direction_with_durability_spread(direction)


func _projectile_direction_with_recoil(direction: Vector3) -> Dictionary:
	return _equipment.projectile_direction_with_recoil(direction)


func _active_weapon_recoil_profile() -> Dictionary:
	return _equipment.active_weapon_recoil_profile()


func _active_weapon_combat_penalty_state() -> Dictionary:
	return _equipment.active_weapon_combat_penalty_state()


func _spread_state_from_penalty(penalty: Dictionary, applied_angle: float, attachment_spread_multiplier: float = 1.0, base_spread_degrees: float = -1.0) -> Dictionary:
	return _equipment.spread_state_from_penalty(penalty, applied_angle, attachment_spread_multiplier, base_spread_degrees)


func _empty_weapon_spread_state() -> Dictionary:
	return _equipment.empty_weapon_spread_state()


func _recoil_state_from_profile(profile: Dictionary, applied_angle: float) -> Dictionary:
	return _equipment.recoil_state_from_profile(profile, applied_angle)


func _empty_weapon_recoil_state() -> Dictionary:
	return _equipment.empty_weapon_recoil_state()


func _current_attachment_spread_multiplier() -> float:
	return _equipment.current_attachment_spread_multiplier()


func _apply_weapon_recoil_after_shot(pre_shot_state: Dictionary) -> Dictionary:
	return _equipment.apply_weapon_recoil_after_shot(pre_shot_state)


func _random_weapon_recoil_angle(profile: Dictionary) -> float:
	return _equipment.random_weapon_recoil_angle(profile)


func _recover_weapon_recoil(delta: float) -> void:
	_equipment.recover_weapon_recoil(delta)


# 射擊阻擋與自動換彈：壞武器會阻擋射擊，空彈匣且有相容彈藥時會先換彈。
func _is_equipped_armor_broken() -> bool:
	return _equipment.is_equipped_armor_broken()


func _should_block_fire_for_broken_weapon() -> bool:
	return _equipment.should_block_fire_for_broken_weapon()


func _record_weapon_fire_block(reason: StringName) -> void:
	_equipment.record_weapon_fire_block(reason)


func _should_auto_reload_before_fire() -> bool:
	if _weapon_controller == null or not _weapon_controller.has_method("get_fire_block_reason"):
		return false
	if StringName(str(_weapon_controller.call("get_fire_block_reason"))) != &"no_ammo":
		return false
	if _find_compatible_ammo_stack().is_empty():
		return false
	var started_reload := reload_equipped_weapon(&"empty_fire")
	if started_reload:
		_primary_fire_held = false
	return started_reload


func _update_held_primary_fire() -> void:
	if _input_reader.is_gameplay_blocked() or _timed_actions.is_reloading() or _has_selected_quick_item():
		return
	if not _primary_fire_held and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	if _melee_mode_active:
		_attack_with_melee_weapon()
		return
	if _weapon_controller != null and _weapon_controller.has_method("get_fire_block_reason"):
		var block_reason := StringName(str(_weapon_controller.call("get_fire_block_reason")))
		if block_reason == &"cooldown":
			return
		if block_reason == &"no_ammo" and _find_compatible_ammo_stack().is_empty():
			return
	_fire_equipped_weapon()


func _is_reload_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R or event.physical_keycode == KEY_R:
			return true
	if InputMap.has_action("reload") and event.is_action_pressed("reload"):
		return true
	return false


func _is_melee_toggle_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_V or event.physical_keycode == KEY_V:
			return true
	if InputMap.has_action("toggle_melee") and event.is_action_pressed("toggle_melee"):
		return true
	return false


func _is_firearm_select_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1 or event.physical_keycode == KEY_1:
			return true
	if InputMap.has_action("select_primary_weapon") and event.is_action_pressed("select_primary_weapon"):
		return true
	return false


func _is_sidearm_select_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_2 or event.physical_keycode == KEY_2:
			return true
	if InputMap.has_action("select_sidearm_weapon") and event.is_action_pressed("select_sidearm_weapon"):
		return true
	return false


func _quick_item_key_for_event(event: InputEvent) -> int:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return -1
	var keycode: Key = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
	match keycode:
		KEY_3:
			return 3
		KEY_4:
			return 4
		KEY_5:
			return 5
		KEY_6:
			return 6
		KEY_7:
			return 7
		KEY_8:
			return 8
		_:
			return -1


func _on_reload_feedback_changed(result: Dictionary) -> void:
	reload_feedback_changed.emit(result)


func _on_reload_progress_changed(state: Dictionary) -> void:
	reload_progress_changed.emit(state)


func _on_item_use_progress_changed(state: Dictionary) -> void:
	item_use_progress_changed.emit(state)


func _find_compatible_ammo_stack() -> Dictionary:
	return _timed_actions.call("_find_compatible_ammo_stack") as Dictionary


func _is_stack_compatible_ammo(stack: Dictionary, ammo_model: Variant) -> bool:
	return bool(_timed_actions.call("_is_stack_compatible_ammo", stack, ammo_model))


func _ammo_model_accepts_tag(ammo_model: Variant, ammo_tag: StringName) -> bool:
	return bool(_timed_actions.call("_ammo_model_accepts_tag", ammo_model, ammo_tag))


# 初始裝載來源：優先套用存檔暫存的 raid loadout，沒有才放 starter inventory。
func _load_starter_inventory() -> void:
	PlayerLoadoutSupportScript.load_starter_inventory(self)


func _load_pending_raid_loadout() -> bool:
	# Boundary marker for validate_base_to_raid_loadout.gd: consume_pending_raid_loadout, RaidLoadoutTransferScript.apply_to_player
	return PlayerLoadoutSupportScript.load_pending_raid_loadout(self)


func _load_saved_base_equipment() -> bool:
	return PlayerLoadoutSupportScript.load_saved_base_equipment(self)


func _apply_base_upgrade_effects() -> void:
	PlayerLoadoutSupportScript.apply_base_upgrade_effects(self, _weapon_controller)


# 模型變更事件：背包/安全口袋/裝備改變後，同步負重、武器和對外 signal。
func _on_inventory_changed() -> void:
	current_carry_weight = _get_carried_weight()
	if _selected_quick_item_key >= 3 and not _is_quick_slot_still_valid(_selected_quick_item_key):
		_selected_quick_item_key = -1
		_sync_held_weapon_visuals()
	inventory_changed.emit()


func can_drop_equipment_slot(slot_id: StringName) -> bool:
	return _equipment.can_drop_equipment_slot(slot_id)


func drop_equipment_slot(slot_id: StringName) -> bool:
	return _equipment.drop_equipment_slot(slot_id)


func _on_safe_pocket_changed() -> void:
	current_carry_weight = _get_carried_weight()
	inventory_changed.emit()


func _on_equipment_changed() -> void:
	current_carry_weight = _get_carried_weight()
	health = minf(health, get_total_max_health())
	if _melee_mode_active and _equipped_melee_weapon() == null:
		_set_melee_mode(false)
	_sync_weapon_from_equipment()
	_sync_held_weapon_visuals()
	health_changed.emit(health, get_total_max_health())
	equipment_changed.emit()


# 裝備到武器控制器的橋：裝備欄改變時，把目前武器與配件彈匣加成推給 WeaponController3D。
func _sync_weapon_from_equipment() -> void:
	_equipment.sync_weapon_from_equipment()
	_sync_held_weapon_visuals()


# 耐久磨損：射擊消耗武器耐久，受傷消耗護甲耐久，最後寫回 equipment_model。
func _apply_equipped_weapon_durability_wear(wear_amount: int = 1) -> bool:
	# Boundary marker: PlayerEquipmentController3D uses ItemDurabilityServiceScript.apply_ammo_use_wear.
	return _equipment.apply_equipped_weapon_durability_wear(wear_amount)


func _apply_equipped_armor_durability_wear(wear_amount: int = 1) -> bool:
	# Boundary marker: PlayerEquipmentController3D uses ItemDurabilityServiceScript.apply_use_wear.
	return _equipment.apply_equipped_armor_durability_wear(wear_amount)


# 裝備/配件查找工具：集中處理目前武器、硬點標籤、配件倍率與背包相容彈藥統計。

func _apply_equipped_helmet_durability_wear(wear_amount: int = 1) -> bool:
	# Boundary marker: PlayerEquipmentController3D uses ItemDurabilityServiceScript.apply_use_wear.
	return _equipment.apply_equipped_helmet_durability_wear(wear_amount)

func _current_loaded_ammo_item() -> ItemDef:
	return _equipment.current_loaded_ammo_item()


func _get_equipped_weapon_slot_id() -> StringName:
	return _equipment.get_equipped_weapon_slot_id()


func _get_equipped_weapon_item() -> ItemDef:
	return _equipment.get_equipped_weapon_item()


func _attachment_state_for_weapon_slot(slot_id: StringName) -> Dictionary:
	# Boundary marker: PlayerEquipmentController3D uses WeaponAttachmentServiceScript.modifiers_for_weapon_stack.
	return _equipment.attachment_state_for_weapon_slot(slot_id)


func _weapon_hardpoint_label_key(hardpoint: StringName) -> StringName:
	return _equipment.weapon_hardpoint_label_key(hardpoint)


func _count_compatible_backpack_ammo() -> int:
	if _weapon_controller == null or not _weapon_controller.has_method("get_ammo_model"):
		return 0
	var ammo_model: Variant = _weapon_controller.call("get_ammo_model")
	if ammo_model == null:
		return 0
	var total := 0
	for stack in inventory_model.stacks:
		if int(stack.get("quantity", 0)) <= 0:
			continue
		if _is_stack_compatible_ammo(stack, ammo_model):
			total += int(stack.get("quantity", 0))
	return total


# 通用顯示/重量工具：從 stack 載入 ItemDef、處理在地化名稱、計算總負重。
func _load_item_from_stack(stack: Dictionary) -> ItemDef:
	return _equipment.load_item_from_stack(stack)


func _item_display_name(item_def: ItemDef) -> String:
	return _equipment.item_display_name(item_def)


func _localized_text(key: StringName, fallback: String) -> String:
	return _equipment.localized_text(key, fallback)


func _get_carried_weight() -> float:
	return PlayerLoadoutSupportScript.carried_weight(self)


func _get_equipment_weight() -> float:
	return PlayerLoadoutSupportScript.equipment_weight(self)


func _stack_weight_with_weapon_mods(stack: Dictionary) -> float:
	return PlayerLoadoutSupportScript.stack_weight_with_weapon_mods(stack)


func _armor_effect_text(item_def: ItemDef, bonus: float) -> String:
	return _equipment.armor_effect_text(item_def, bonus)


# 死亡與 raid 結算：玩家死亡後發 signal，並把死亡上下文登記到 RaidSession。
func _die(event: DamageEvent) -> void:
	if is_dead:
		return
	is_dead = true
	_timed_actions.cancel_all(&"cancelled")
	died.emit(event)
	var raid_session := _find_raid_session()
	if raid_session != null and raid_session.has_method("register_player_death"):
		var context := RaidLossRulesScript.build_death_context_from_player(self)
		context["source"] = "player_death"
		raid_session.call("register_player_death", context)


func _find_raid_session() -> Node:
	var current_scene := get_tree().current_scene if is_inside_tree() else null
	if current_scene != null:
		var session := current_scene.get_node_or_null("RaidSession")
		if session != null:
			return session
	if get_parent() != null:
		return get_parent().get_node_or_null("RaidSession")
	return null
