class_name ItemDef
extends Resource

@export var id: StringName
@export var catalog_number: int = 0
@export var display_name: String = ""
@export var name_key: StringName = &""
@export var description_key: StringName = &""
@export_enum("weapon", "ammo", "armor", "backpack", "attachment", "medical", "food", "consumable", "key", "crafting", "electronics", "explosive", "valuable", "intel", "quest", "totem", "recipe", "loot", "currency") var item_type: String = "loot"
@export var weight: float = 0.0
@export var value: int = 0
@export var max_stack: int = 1
# // Gun damage used by the early codex and combat planning slice. Non-gun items keep this at 0. //
@export var damage: int = 0
@export var tags: Array[StringName] = []
@export var is_quest_item: bool = false


func to_stack(quantity: int = 1) -> Dictionary:
	return {
		"id": id,
		"catalog_number": catalog_number,
		"name": display_name,
		"name_key": name_key,
		"description_key": description_key,
		"type": item_type,
		"weight": weight,
		"value": value,
		"quantity": maxi(quantity, 1),
		"max_stack": maxi(max_stack, 1),
		"resource_path": resource_path,
		"damage": maxi(damage, 0),
		"tags": tags.duplicate(),
		"is_quest_item": is_quest_item,
	}
