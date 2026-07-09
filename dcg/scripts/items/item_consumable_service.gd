class_name ItemConsumableService
extends RefCounted


static func is_usable_stack(stack: Dictionary, item_def: ItemDef = null) -> bool:
	if typeof(stack) != TYPE_DICTIONARY:
		return false
	return use_duration_seconds(stack, item_def) > 0.0 and (healing_amount(stack, item_def) > 0.0 or stamina_restore_amount(stack, item_def) > 0.0)


static func can_start_use(stack: Dictionary, current_health: float, maximum_health: float, current_stamina: float = -1.0, maximum_stamina: float = -1.0, item_def: ItemDef = null) -> bool:
	if typeof(stack) != TYPE_DICTIONARY:
		return false
	if not is_usable_stack(stack, item_def):
		return false
	if maximum_health <= 0.0:
		return false
	var can_heal := healing_amount(stack, item_def) > 0.0 and current_health < maximum_health - 0.05
	if can_heal:
		return true
	if stamina_restore_amount(stack, item_def) <= 0.0:
		return false
	if maximum_stamina <= 0.0 or maximum_stamina < current_stamina:
		return false
	return current_stamina < maximum_stamina - 0.05


static func use_duration_seconds(stack: Dictionary, item_def: ItemDef = null) -> float:
	if typeof(stack) != TYPE_DICTIONARY:
		return 0.0
	if stack.has("use_duration_seconds"):
		return maxf(float(stack.get("use_duration_seconds", 0.0)), 0.0)
	if item_def == null:
		return 0.0
	return maxf(float(item_def.use_duration_seconds), 0.0)


static func healing_amount(stack: Dictionary, item_def: ItemDef = null) -> float:
	if typeof(stack) != TYPE_DICTIONARY:
		return 0.0
	if stack.has("heal_amount"):
		return maxf(float(stack.get("heal_amount", 0.0)), 0.0)
	if item_def == null:
		return 0.0
	return maxf(float(item_def.heal_amount), 0.0)


static func stamina_restore_amount(stack: Dictionary, item_def: ItemDef = null) -> float:
	if typeof(stack) != TYPE_DICTIONARY:
		return 0.0
	if stack.has("stamina_restore"):
		return maxf(float(stack.get("stamina_restore", 0.0)), 0.0)
	if item_def == null:
		return 0.0
	return maxf(float(item_def.stamina_restore), 0.0)
