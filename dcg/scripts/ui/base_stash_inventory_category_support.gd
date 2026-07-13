class_name BaseStashInventoryCategorySupport
extends RefCounted

const ItemCodexPresenterScript := preload("res://scripts/ui/item_codex_presenter.gd")


static func category_ids() -> Array[String]:
	return ItemCodexPresenterScript.storage_category_order()


static func build_filter_state(stacks: Array[Dictionary], active_category_id: String, codex_catalog: RefCounted) -> Dictionary:
	var category_id := active_category_id if category_ids().has(active_category_id) else "all"
	var visible_items: Array[Dictionary] = []
	var source_indices: Array[int] = []
	var counts := {}
	for id in category_ids():
		counts[id] = 0
	counts["all"] = stacks.size()

	for source_index in range(stacks.size()):
		var stack := stacks[source_index]
		var stack_category_id := category_id_for_stack(stack, codex_catalog)
		counts[stack_category_id] = int(counts.get(stack_category_id, 0)) + 1
		if category_id != "all" and category_id != stack_category_id:
			continue
		visible_items.append(stack.duplicate(true))
		source_indices.append(source_index)

	return {
		"active_category_id": category_id,
		"visible_items": visible_items,
		"source_indices": source_indices,
		"counts": counts,
	}


static func category_id_for_stack(stack: Dictionary, codex_catalog: RefCounted) -> String:
	var item_path := str(stack.get("resource_path", stack.get("item_path", "")))
	if codex_catalog == null or item_path == "" or not codex_catalog.has_method("storage_category_id_for_path"):
		return "other"
	return str(codex_catalog.call("storage_category_id_for_path", item_path))
