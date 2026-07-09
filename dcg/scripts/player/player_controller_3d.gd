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
const RaidLossRulesScript := preload("res://scripts/raid/raid_loss_rules.gd")
const ItemConsumableServiceScript := preload("res://scripts/items/item_consumable_service.gd")
const MeleeAttackServiceScript := preload("res://scripts/combat/melee_attack_service.gd")
const DEFAULT_RELOAD_DURATION_SECONDS := 0.8
const RELOAD_PROGRESS_EMIT_STEP := 0.05

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

# 執行期協作者與暫存狀態：控制器不直接吃下所有細節，而是把移動/輸入/武器拆給專職物件。
var _stats: PlayerStats3D
var _input_reader := PlayerInputReaderScript.new(self)
var _locomotion: PlayerLocomotion3D
var _weapon_controller: Node = null
var _pistol_visual: Node3D = null
var _knife_visual: Node3D = null
var _melee_mode_active := false
var _selected_quick_item_key := -1
var _melee_attack_cooldown_remaining := 0.0
var _last_melee_attack_state := {
	"active": false,
	"mode_active": false,
	"hit_count": 0,
	"weapon_id": "",
	"progress": 0.0,
}
var _is_reloading := false
var _reload_elapsed := 0.0
var _active_reload_duration_seconds := 0.0
var _pending_reload := {}
var _last_reload_result := {
	"reloaded": false,
	"blocked_reason": "",
	"rounds_loaded": 0,
	"current_ammo": 0,
	"reserve_ammo": 0,
	"backpack_ammo_remaining": 0,
	"source": "",
}
var _last_reload_state := {
	"active": false,
	"progress": 0.0,
	"remaining_time": 0.0,
	"source": "",
	"status": "idle",
}
var _last_reload_emit_active := false
var _last_reload_emit_progress := -1.0
var _last_reload_emit_source := ""
var _last_reload_emit_status := ""
var _is_using_item := false
var _item_use_elapsed := 0.0
var _active_item_use_duration_seconds := 0.0
var _pending_item_use := {}
var _last_item_use_state := {
	"active": false,
	"progress": 0.0,
	"remaining_time": 0.0,
	"stack_index": -1,
	"item_id": "",
	"name_key": "",
	"status": "idle",
}


# 初始化流程：套用難度/基地加成，建立模型容量，掛事件，載入 raid loadout 或 starter loadout。
func _ready() -> void:
	var runtime_stats_profile := stats_profile.duplicate(true) as PlayerStatsProfile
	var difficulty_manager := get_node_or_null("/root/DifficultyManager")
	if difficulty_manager != null and difficulty_manager.has_method("apply_to_player_stats"):
		difficulty_manager.apply_to_player_stats(runtime_stats_profile)
	_stats = PlayerStatsScript.new(runtime_stats_profile)
	_locomotion = PlayerLocomotionScript.new(self, _stats)
	_weapon_controller = get_node_or_null("WeaponController3D")
	_pistol_visual = get_node_or_null("WeaponVisualRoot/PistolVisual") as Node3D
	_knife_visual = get_node_or_null("WeaponVisualRoot/KnifeVisual") as Node3D
	_equipment.set_weapon_controller(_weapon_controller)
	_apply_base_upgrade_effects()
	inventory_model.setup(backpack_slots)
	safe_pocket_model.setup(safe_pocket_slots)
	inventory_model.changed.connect(_on_inventory_changed)
	safe_pocket_model.changed.connect(_on_safe_pocket_changed)
	equipment_model.changed.connect(_on_equipment_changed)
	if not _load_pending_raid_loadout() and not _load_saved_base_equipment():
		_load_starter_inventory()
	_sync_weapon_from_equipment()
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
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
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
	return _last_reload_result.duplicate(true)


func get_reload_state() -> Dictionary:
	return _last_reload_state.duplicate(true)


func get_item_use_state() -> Dictionary:
	return _last_item_use_state.duplicate(true)


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
	var result: Array[Dictionary] = [
		_quick_weapon_slot_state(1, &"primary_weapon"),
		_quick_weapon_slot_state(2, &"sidearm"),
		_quick_weapon_slot_state(0, &"melee", "V"),
	]
	if quick_slot_model == null:
		return result
	var slots_state: Variant = quick_slot_model.call("get_slots_state", inventory_model.stacks)
	if typeof(slots_state) != TYPE_ARRAY:
		return result
	for slot_state in slots_state as Array:
		if typeof(slot_state) != TYPE_DICTIONARY:
			continue
		var state: Dictionary = (slot_state as Dictionary).duplicate(true)
		state["kind"] = "item"
		var key_value := int(state.get("key", -1))
		state["active"] = key_value == _selected_quick_item_key and _is_quick_slot_still_valid(key_value)
		state["display_text"] = _stack_display_name(state.get("stack", {}) as Dictionary)
		result.append(state)
	return result


func get_quick_slot_state(key_number: int) -> Dictionary:
	var quick_state: Variant = quick_slot_model.call("get_slots_state", inventory_model.stacks)
	if typeof(quick_state) != TYPE_ARRAY:
		return {}
	for raw_state in quick_state as Array:
		if typeof(raw_state) != TYPE_DICTIONARY:
			continue
		var state := raw_state as Dictionary
		if int(state.get("key", -1)) == int(key_number):
			return state.duplicate(true)
	return {}


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
	return _equipment.equip_inventory_stack(stack_index, slot_id)


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
	if _is_using_item or _is_reloading or is_dead:
		return false
	if stack_index < 0 or stack_index >= inventory_model.stacks.size():
		return false
	var stack := inventory_model.stacks[stack_index] as Dictionary
	var item_def := _load_item_from_stack(stack)
	return ItemConsumableServiceScript.can_start_use(stack, health, get_total_max_health(), stamina, max_stamina, item_def)


func use_inventory_stack(stack_index: int) -> bool:
	if not can_use_inventory_stack(stack_index):
		return false
	var stack := inventory_model.stacks[stack_index] as Dictionary
	var item_def := _load_item_from_stack(stack)
	_is_using_item = true
	_item_use_elapsed = 0.0
	_active_item_use_duration_seconds = ItemConsumableServiceScript.use_duration_seconds(stack, item_def)
	_pending_item_use = {
		"stack_index": stack_index,
		"item_id": str(stack.get("id", "")),
		"name_key": str(stack.get("name_key", "")),
		"heal_amount": ItemConsumableServiceScript.healing_amount(stack, item_def),
		"stamina_amount": ItemConsumableServiceScript.stamina_restore_amount(stack, item_def),
	}
	_emit_item_use_state(true, 0.0, &"using")
	return true


func assign_quick_slot_for_inventory_stack(key_number: int, stack_index: int) -> bool:
	if not _is_quick_key_number(key_number):
		return false
	if stack_index < 0 or stack_index >= inventory_model.stacks.size():
		return false
	if quick_slot_model == null:
		return false
	var stack := inventory_model.stacks[stack_index] as Dictionary
	if not _is_stack_usable_for_quick_bar(stack):
		return false
	var item_def := _load_item_from_stack(stack)
	if not ItemConsumableServiceScript.is_usable_stack(stack, item_def):
		return false
	var assigned_variant: Variant = quick_slot_model.call("assign_inventory_stack", int(key_number), stack_index, stack)
	if typeof(assigned_variant) != TYPE_BOOL:
		return false
	var assigned := bool(assigned_variant)
	if assigned:
		inventory_changed.emit()
		_sync_selected_quick_slot_after_slot_change(key_number)
	return assigned


func clear_quick_slot_for_key(key_number: int) -> bool:
	var normalized := int(key_number)
	if not _is_quick_key_number(normalized):
		return false
	if quick_slot_model == null:
		return false
	var removed: Variant = quick_slot_model.call("clear_slot", normalized)
	if typeof(removed) != TYPE_BOOL:
		return false
	if bool(removed):
		if _selected_quick_item_key == normalized:
			_selected_quick_item_key = -1
			_sync_held_weapon_visuals()
		inventory_changed.emit()
		return true
	return false


func move_quick_slot_to_key(from_key: int, to_key: int) -> bool:
	var normalized_from := int(from_key)
	var normalized_to := int(to_key)
	if not _is_quick_key_number(normalized_from) or not _is_quick_key_number(normalized_to) or normalized_from == normalized_to:
		return false
	if quick_slot_model == null:
		return false
	var resolve_raw: Variant = quick_slot_model.call("resolve_stack_index", normalized_from, inventory_model.stacks)
	if typeof(resolve_raw) != TYPE_INT:
		return false
	var stack_index := int(resolve_raw)
	if stack_index < 0 or stack_index >= inventory_model.stacks.size():
		return false
	var stack := inventory_model.stacks[stack_index] as Dictionary
	var moved_variant: Variant = quick_slot_model.call("assign_inventory_stack", normalized_to, stack_index, stack)
	if typeof(moved_variant) != TYPE_BOOL:
		return false
	var moved := bool(moved_variant)
	if moved:
		if _selected_quick_item_key == normalized_from:
			_selected_quick_item_key = normalized_to
		inventory_changed.emit()
		_sync_selected_quick_slot_after_slot_change(normalized_from)
		_sync_selected_quick_slot_after_slot_change(normalized_to)
	return moved


func select_quick_slot(key_number: int) -> bool:
	if not _is_quick_key_number(key_number):
		return false
	if quick_slot_model == null:
		return false
	var resolve_raw: Variant = quick_slot_model.call("resolve_stack_index", int(key_number), inventory_model.stacks)
	if typeof(resolve_raw) != TYPE_INT:
		return false
	var stack_index := int(resolve_raw)
	if stack_index < 0:
		if _selected_quick_item_key == int(key_number):
			_selected_quick_item_key = -1
			_sync_held_weapon_visuals()
		return false
	_selected_quick_item_key = key_number
	_set_melee_mode(false)
	_sync_held_weapon_visuals()
	return true


func use_selected_quick_item() -> bool:
	if not _has_selected_quick_item():
		return false
	return use_quick_slot(_selected_quick_item_key)


func _has_selected_quick_item() -> bool:
	if not _is_quick_key_number(_selected_quick_item_key):
		return false
	if quick_slot_model == null:
		return false
	var resolve_raw: Variant = quick_slot_model.call("resolve_stack_index", _selected_quick_item_key, inventory_model.stacks)
	if typeof(resolve_raw) != TYPE_INT:
		return false
	return int(resolve_raw) >= 0


func _selected_quick_item_stack() -> Dictionary:
	if not _is_quick_key_number(_selected_quick_item_key):
		return {}
	var slot_state := get_quick_slot_state(_selected_quick_item_key)
	if not bool(slot_state.get("assigned", false)):
		return {}
	var stack: Dictionary = slot_state.get("stack", {}) as Dictionary
	return stack.duplicate(true)


func use_quick_slot(key_number: int) -> bool:
	if not _is_quick_key_number(key_number) or quick_slot_model == null:
		return false
	var resolve_raw: Variant = quick_slot_model.call("resolve_stack_index", int(key_number), inventory_model.stacks)
	if typeof(resolve_raw) != TYPE_INT:
		return false
	var stack_index := int(resolve_raw)
	if stack_index < 0:
		return false
	return use_inventory_stack(stack_index)


func _sync_selected_quick_slot_after_slot_change(key_number: int) -> void:
	var normalized := int(key_number)
	if normalized < 3 or normalized > 8:
		return
	if _selected_quick_item_key != normalized:
		return
	var slot_state := get_quick_slot_state(normalized)
	if not bool(slot_state.get("assigned", false)):
		_selected_quick_item_key = -1
		_sync_held_weapon_visuals()


func _is_quick_slot_still_valid(key_number: int) -> bool:
	var normalized := int(key_number)
	if not _is_quick_key_number(normalized):
		return false
	var slot_state := get_quick_slot_state(normalized)
	if slot_state.is_empty():
		return false
	return bool(slot_state.get("assigned", false))


func _is_quick_key_number(key_number: int) -> bool:
	return key_number >= 3 and key_number <= 8


func _is_stack_usable_for_quick_bar(stack: Dictionary) -> bool:
	if typeof(stack) != TYPE_DICTIONARY:
		return false
	return int(stack.get("quantity", 0)) > 0


# 換彈入口：檢查武器、彈匣、背包彈藥後，建立 pending reload，完成動作由 _update_reload 推進。
func reload_equipped_weapon(reload_source: StringName = &"manual") -> bool:
	if _is_using_item:
		_record_reload_feedback(false, &"using_item", 0, reload_source)
		return false
	if _is_reloading:
		_record_reload_feedback(false, &"reloading", 0, reload_source)
		return false
	if _weapon_controller == null or not _weapon_controller.has_method("reload_from_item"):
		_record_reload_feedback(false, &"no_weapon", 0, reload_source)
		_emit_reload_state(false, 0.0, reload_source, &"blocked")
		return false
	if not _weapon_controller.has_method("has_weapon") or not bool(_weapon_controller.call("has_weapon")):
		_sync_weapon_from_equipment()
	if not _weapon_controller.has_method("has_weapon") or not bool(_weapon_controller.call("has_weapon")):
		_record_reload_feedback(false, &"no_weapon", 0, reload_source)
		_emit_reload_state(false, 0.0, reload_source, &"blocked")
		return false

	var current_rounds := int(_weapon_controller.get("current_ammo"))
	var magazine_capacity := int(_weapon_controller.get("magazine_size"))
	var needed_rounds := magazine_capacity - current_rounds
	if needed_rounds <= 0:
		_record_reload_feedback(false, &"magazine_full", 0, reload_source)
		_emit_reload_state(false, 1.0, reload_source, &"blocked")
		return false

	var ammo_stack := _find_compatible_ammo_stack()
	if ammo_stack.is_empty():
		_record_reload_feedback(false, &"no_compatible_ammo", 0, reload_source)
		_emit_reload_state(false, 0.0, reload_source, &"blocked")
		return false

	var ammo_index := int(ammo_stack.get("index", -1))
	var ammo_def := ammo_stack.get("item_def") as ItemDef
	var available_quantity := int(ammo_stack.get("quantity", 0))
	var quantity_to_load := mini(needed_rounds, available_quantity)
	_start_reload(reload_source, ammo_index, ammo_def, quantity_to_load)
	return true


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


# 換彈完成：真正消耗背包彈藥並同步武器彈數，失敗時會記錄阻擋原因。
func _complete_reload() -> bool:
	if _pending_reload.is_empty() or _weapon_controller == null:
		_cancel_reload(&"cancelled")
		return false
	var reload_source := StringName(str(_pending_reload.get("source", "manual")))
	var ammo_index := int(_pending_reload.get("ammo_index", -1))
	var ammo_def := _pending_reload.get("ammo_def") as ItemDef
	var quantity_to_load := int(_pending_reload.get("quantity_to_load", 0))
	var loaded_rounds := int(_weapon_controller.call("reload_from_item", ammo_def, quantity_to_load))
	if loaded_rounds <= 0:
		var weapon_result: Dictionary = _weapon_controller.get("last_reload_result")
		_record_reload_feedback(false, StringName(str(weapon_result.get("blocked_reason", "no_ammo"))), 0, reload_source)
		_cancel_reload(StringName(str(weapon_result.get("blocked_reason", "no_ammo"))))
		return false

	inventory_model.consume_stack_quantity(ammo_index, loaded_rounds)
	_record_reload_feedback(true, &"", loaded_rounds, reload_source)
	_finish_reload(reload_source)
	return true


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
	_update_reload(delta)
	_update_item_use(delta)
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
	if _is_reloading or _is_using_item:
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
	var projectile_origin: Vector3 = _weapon_controller.global_position + Vector3.UP * 0.72
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
	else:
		_equipment.clear_weapon_fire_result()


func _attack_with_melee_weapon() -> bool:
	if _is_reloading or _is_using_item or is_dead:
		return false
	if _melee_attack_cooldown_remaining > 0.0:
		return false
	var melee_weapon := _equipped_melee_weapon()
	if melee_weapon == null:
		_set_melee_mode(false)
		return false
	_melee_attack_cooldown_remaining = melee_attack_cooldown_seconds
	var result := MeleeAttackServiceScript.perform_arc_attack(
		self,
		melee_weapon,
		melee_attack_range,
		melee_attack_arc_degrees,
		melee_fallback_damage
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
	if _pistol_visual != null:
		_pistol_visual.visible = _selected_quick_item_key < 0 and not _melee_mode_active and _equipment.get_equipped_weapon_item() != null
	if _knife_visual != null:
		_knife_visual.visible = _selected_quick_item_key < 0 and _melee_mode_active and _equipped_melee_weapon() != null


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


func _spread_state_from_penalty(penalty: Dictionary, applied_angle: float, ammo_spread_multiplier: float = 1.0, attachment_spread_multiplier: float = 1.0, base_spread_degrees: float = -1.0) -> Dictionary:
	return _equipment.spread_state_from_penalty(penalty, applied_angle, ammo_spread_multiplier, attachment_spread_multiplier, base_spread_degrees)


func _empty_weapon_spread_state() -> Dictionary:
	return _equipment.empty_weapon_spread_state()


func _recoil_state_from_profile(profile: Dictionary, applied_angle: float) -> Dictionary:
	return _equipment.recoil_state_from_profile(profile, applied_angle)


func _empty_weapon_recoil_state() -> Dictionary:
	return _equipment.empty_weapon_recoil_state()


func _current_ammo_spread_multiplier() -> float:
	return _equipment.current_ammo_spread_multiplier()


func _current_attachment_spread_multiplier() -> float:
	return _equipment.current_attachment_spread_multiplier()


func _current_ammo_recoil_multiplier() -> float:
	return _equipment.current_ammo_recoil_multiplier()


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
	return reload_equipped_weapon(&"empty_fire")


func _update_held_primary_fire() -> void:
	if _input_reader.is_gameplay_blocked() or _is_reloading or _has_selected_quick_item():
		return
	if _melee_mode_active:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
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


func _find_compatible_ammo_stack() -> Dictionary:
	if _weapon_controller == null or not _weapon_controller.has_method("get_ammo_model"):
		return {}
	var ammo_model: Variant = _weapon_controller.call("get_ammo_model")
	if ammo_model == null:
		return {}
	for index in range(inventory_model.stacks.size()):
		var stack := inventory_model.stacks[index]
		if int(stack.get("quantity", 0)) <= 0:
			continue
		if not _is_stack_compatible_ammo(stack, ammo_model):
			continue
		var item_def := _load_item_from_stack(stack)
		if item_def == null or item_def.item_type != "ammo":
			continue
		return {
			"index": index,
			"item_def": item_def,
			"quantity": int(stack.get("quantity", 1)),
		}
	return {}


func _is_stack_compatible_ammo(stack: Dictionary, ammo_model: Variant) -> bool:
	if ammo_model == null:
		return false
	var stack_type := str(stack.get("type", ""))
	if stack_type != "" and stack_type != "ammo":
		return false
	var ammo_tag := StringName(str(stack.get("ammo_tag", "")))
	if ammo_tag != &"" and _ammo_model_accepts_tag(ammo_model, ammo_tag):
		return true
	var tags: Array = stack.get("tags", []) as Array
	for raw_tag in tags:
		var tag := StringName(str(raw_tag))
		if tag != &"" and _ammo_model_accepts_tag(ammo_model, tag):
			return true
	if not ammo_model.has_method("can_use_ammo"):
		return false
	var item_def := _load_item_from_stack(stack)
	return item_def != null and bool(ammo_model.call("can_use_ammo", item_def))


func _ammo_model_accepts_tag(ammo_model: Variant, ammo_tag: StringName) -> bool:
	if ammo_model == null or ammo_tag == &"":
		return false
	var compatible_tags_variant: Variant = ammo_model.get("compatible_ammo_tags")
	if typeof(compatible_tags_variant) != TYPE_ARRAY:
		return false
	for raw_tag in compatible_tags_variant as Array:
		if StringName(str(raw_tag)) == ammo_tag:
			return true
	return false


# 換彈內部狀態機：開始、推進、完成/取消，並透過 signal 持續回報 UI 進度。
func _start_reload(reload_source: StringName, ammo_index: int, ammo_def: ItemDef, quantity_to_load: int) -> void:
	_is_reloading = true
	_reload_elapsed = 0.0
	_active_reload_duration_seconds = _current_weapon_reload_duration_seconds()
	_pending_reload = {
		"source": str(reload_source),
		"ammo_index": ammo_index,
		"ammo_def": ammo_def,
		"quantity_to_load": quantity_to_load,
		"duration": _active_reload_duration_seconds,
	}
	_emit_reload_state(true, 0.0, reload_source, &"reloading")


func _update_reload(delta: float) -> void:
	if not _is_reloading:
		return
	_reload_elapsed += maxf(delta, 0.0)
	var duration := maxf(_active_reload_duration_seconds, 0.05)
	var progress := clampf(_reload_elapsed / duration, 0.0, 1.0)
	var source := StringName(str(_pending_reload.get("source", "manual")))
	_emit_reload_state(true, progress, source, &"reloading")
	if progress >= 1.0:
		_complete_reload()


func _update_item_use(delta: float) -> void:
	if not _is_using_item:
		return
	_item_use_elapsed += maxf(delta, 0.0)
	var duration := maxf(_active_item_use_duration_seconds, 0.05)
	var progress := clampf(_item_use_elapsed / duration, 0.0, 1.0)
	_emit_item_use_state(true, progress, &"using")
	if progress >= 1.0:
		_complete_item_use()


func _complete_item_use() -> bool:
	if _pending_item_use.is_empty():
		_cancel_item_use(&"cancelled")
		return false
	var stack_index := int(_pending_item_use.get("stack_index", -1))
	if stack_index < 0 or stack_index >= inventory_model.stacks.size():
		_cancel_item_use(&"missing_item")
		return false
	var stack := inventory_model.stacks[stack_index] as Dictionary
	if str(stack.get("id", "")) != str(_pending_item_use.get("item_id", "")):
		_cancel_item_use(&"missing_item")
		return false
	var consumed := inventory_model.consume_stack_quantity(stack_index, 1)
	if consumed <= 0:
		_cancel_item_use(&"missing_item")
		return false
	var max_health := get_total_max_health()
	var max_stamina_value := max_stamina
	var health_gain := maxf(float(_pending_item_use.get("heal_amount", 0.0)), 0.0)
	var stamina_gain := maxf(float(_pending_item_use.get("stamina_amount", 0.0)), 0.0)
	if health_gain <= 0.0 and stamina_gain <= 0.0:
		_cancel_item_use(&"no_effect")
		return false
	if health_gain > 0.0:
		health = minf(health + health_gain, max_health)
		health_changed.emit(health, max_health)
	if stamina_gain > 0.0:
		stamina = minf(stamina + stamina_gain, max_stamina_value)
		stamina_changed.emit(stamina, max_stamina_value)
	_finish_item_use(&"complete")
	return true


func _finish_item_use(status: StringName) -> void:
	_is_using_item = false
	_item_use_elapsed = 0.0
	_active_item_use_duration_seconds = 0.0
	_emit_item_use_state(false, 1.0, status)
	_pending_item_use = {}


func _cancel_item_use(reason: StringName) -> void:
	_is_using_item = false
	_item_use_elapsed = 0.0
	_active_item_use_duration_seconds = 0.0
	_emit_item_use_state(false, 0.0, reason)
	_pending_item_use = {}


func _emit_item_use_state(active: bool, progress: float, status: StringName) -> void:
	var duration := _active_item_use_duration_seconds
	var clamped_progress := clampf(progress, 0.0, 1.0)
	_last_item_use_state = {
		"active": active,
		"progress": clamped_progress,
		"remaining_time": maxf(duration * (1.0 - clamped_progress), 0.0) if active else 0.0,
		"duration": duration,
		"stack_index": int(_pending_item_use.get("stack_index", -1)),
		"item_id": str(_pending_item_use.get("item_id", "")),
		"name_key": str(_pending_item_use.get("name_key", "")),
		"status": str(status),
	}
	item_use_progress_changed.emit(_last_item_use_state.duplicate(true))


func _finish_reload(reload_source: StringName) -> void:
	_is_reloading = false
	_reload_elapsed = 0.0
	_active_reload_duration_seconds = 0.0
	_pending_reload = {}
	_emit_reload_state(false, 1.0, reload_source, &"complete")


func _cancel_reload(reason: StringName) -> void:
	var source := StringName(str(_pending_reload.get("source", "manual"))) if not _pending_reload.is_empty() else &"manual"
	_is_reloading = false
	_reload_elapsed = 0.0
	_active_reload_duration_seconds = 0.0
	_pending_reload = {}
	_emit_reload_state(false, 0.0, source, reason)


func _emit_reload_state(active: bool, progress: float, reload_source: StringName, status: StringName) -> void:
	var duration := _active_reload_duration_seconds if _active_reload_duration_seconds > 0.0 else _current_weapon_reload_duration_seconds()
	var clamped_progress := clampf(progress, 0.0, 1.0)
	var source_text := str(reload_source)
	var status_text := str(status)
	_last_reload_state = {
		"active": active,
		"progress": clamped_progress,
		"remaining_time": maxf(duration * (1.0 - clamped_progress), 0.0) if active else 0.0,
		"source": source_text,
		"status": status_text,
	}
	if not _should_emit_reload_state(active, clamped_progress, source_text, status_text):
		return
	_last_reload_emit_active = active
	_last_reload_emit_progress = clamped_progress
	_last_reload_emit_source = source_text
	_last_reload_emit_status = status_text
	reload_progress_changed.emit(_last_reload_state.duplicate(true))


func _should_emit_reload_state(active: bool, progress: float, source_text: String, status_text: String) -> bool:
	if active != _last_reload_emit_active or source_text != _last_reload_emit_source or status_text != _last_reload_emit_status:
		return true
	if not active:
		return true
	if progress <= 0.0 or progress >= 1.0:
		return true
	return absf(progress - _last_reload_emit_progress) >= RELOAD_PROGRESS_EMIT_STEP


func _current_weapon_reload_duration_seconds() -> float:
	if not is_equal_approx(reload_duration_seconds, DEFAULT_RELOAD_DURATION_SECONDS):
		return maxf(reload_duration_seconds, 0.05)
	var weapon_item := _get_equipped_weapon_item()
	if weapon_item != null and weapon_item.reload_duration_seconds > 0.0:
		return maxf(weapon_item.reload_duration_seconds, 0.05)
	return maxf(reload_duration_seconds, 0.05)


func _record_reload_feedback(did_reload: bool, blocked_reason: StringName, rounds_loaded: int, reload_source: StringName = &"manual") -> void:
	_last_reload_result = {
		"reloaded": did_reload,
		"blocked_reason": str(blocked_reason),
		"rounds_loaded": rounds_loaded,
		"current_ammo": int(_weapon_controller.get("current_ammo")) if _weapon_controller != null else 0,
		"reserve_ammo": int(_weapon_controller.get("reserve_ammo")) if _weapon_controller != null else 0,
		"backpack_ammo_remaining": _count_compatible_backpack_ammo(),
		"source": str(reload_source),
	}
	reload_feedback_changed.emit(_last_reload_result.duplicate(true))


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
